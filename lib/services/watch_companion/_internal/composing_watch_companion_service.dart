// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Real WatchCompanionService implementation. Bridges the synchronous
// [watchSnapshotComposerProvider] Provider into a broadcast Stream the
// iOS bridge can subscribe to, and seeds new subscribers with the
// latest known snapshot so the bridge can push the current state to
// the Watch on session activation without waiting for the next rebuild.
//
// handleIntent is intentionally still a no-op in Sub-step 3b — Sub-step
// 3c replaces this body with the real readiness-gated send dispatch.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/watch_companion_intent.dart';
import '../models/watch_companion_intent_result.dart';
import '../models/watch_companion_snapshot.dart';
import '../watch_companion_service.dart';
import 'watch_send_facade.dart';
import 'watch_snapshot_composer.dart';

class ComposingWatchCompanionService implements WatchCompanionService {
  ComposingWatchCompanionService(this._ref) {
    // Seed the latest snapshot synchronously so first subscribers (and
    // anyone calling [latestSnapshot] before a stream rebuild) see real
    // data, not null.
    try {
      _latest = _ref.read(watchSnapshotComposerProvider);
    } catch (e) {
      AppLogging.watchCompanion('initial snapshot read failed: $e');
    }

    // Subscribe to subsequent rebuilds. Riverpod fires this listener
    // each time the composer Provider's value changes.
    _subscription = _ref.listen<WatchCompanionSnapshot>(
      watchSnapshotComposerProvider,
      (previous, next) {
        _latest = next;
        if (!_controller.isClosed) {
          _controller.add(next);
        }
      },
      onError: (Object error, StackTrace st) {
        AppLogging.watchCompanion('composer listener error: $error');
      },
      fireImmediately: false,
    );

    AppLogging.watchCompanion(
      'service activated; initial snapshot status=${_latest?.connection.status.name ?? "<none>"}',
    );
  }

  final Ref _ref;
  late final ProviderSubscription<WatchCompanionSnapshot> _subscription;
  final StreamController<WatchCompanionSnapshot> _controller =
      StreamController<WatchCompanionSnapshot>.broadcast();

  WatchCompanionSnapshot? _latest;
  bool _disposed = false;

  @override
  WatchCompanionSnapshot? get latestSnapshot => _latest;

  @override
  Stream<WatchCompanionSnapshot> get snapshots async* {
    // Replay the latest cached snapshot to the new subscriber, then
    // forward all subsequent updates from the broadcast controller.
    final cached = _latest;
    if (cached != null) yield cached;
    yield* _controller.stream;
  }

  @override
  Future<WatchCompanionIntentResult> handleIntent(
    WatchCompanionIntent intent,
  ) async {
    // Single delegation point. The send facade owns every guard
    // (feature flag, canned key, readiness, channel, protocol) and
    // every protocol-specific send call. Keeping handleIntent thin
    // means a future bridge slice can swap how it calls into the
    // service without touching dispatch logic.
    return _ref.read(watchSendFacadeProvider).dispatch(intent);
  }

  /// Tear down the broadcast controller and the Riverpod subscription.
  /// Wired into [Ref.onDispose] by the service provider so a
  /// ProviderScope rebuild does not leak the subscription.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription.close();
    _controller.close();
    AppLogging.watchCompanion('service disposed');
  }
}
