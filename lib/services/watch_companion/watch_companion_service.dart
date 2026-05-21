// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'models/watch_companion_canned_messages.dart';
import 'models/watch_companion_capabilities.dart';
import 'models/watch_companion_channel_preview.dart';
import 'models/watch_companion_connection_state.dart';
import 'models/watch_companion_inbox_preview.dart';
import 'models/watch_companion_intent.dart';
import 'models/watch_companion_intent_result.dart';
import 'models/watch_companion_node_preview.dart';
import 'models/watch_companion_snapshot.dart';

/// Public, protocol-neutral facade between the iOS watch bridge and the
/// rest of the app. The implementation lives behind a provider and is
/// replaced in Slice 3 with the real composer that reads protocol-neutral
/// adapters from `_internal/`.
///
/// Hard rule: this file MUST NOT import any Meshtastic or MeshCore
/// implementation symbol (`ProtocolService`, `MeshCoreSession`,
/// `messagesProvider`, `meshCoreConversationsProvider`,
/// `channelSettingsProvider`, ...). Those imports are allowed only under
/// `lib/services/watch_companion/_internal/`. The
/// `watch_companion_protocol_isolation_test` fails the build if anyone
/// violates this boundary.
abstract class WatchCompanionService {
  /// Continuous stream of watch snapshots. Emits a new value whenever the
  /// composer decides the Watch view should refresh; the throttle and
  /// debounce policy lives in the implementation.
  Stream<WatchCompanionSnapshot> get snapshots;

  /// Synchronous accessor for the latest snapshot, or null if none has been
  /// emitted yet. Used by the iOS bridge to seed the Watch on session
  /// activation without waiting for the next stream tick.
  WatchCompanionSnapshot? get latestSnapshot;

  /// Handle an intent originating on the Watch. Always returns exactly one
  /// result, even on rejection: no silent drop. Slice 3 wires this into
  /// the real send path; Slice 2 returns a clean
  /// `accepted=false, diagnosticReason="service_not_wired"` placeholder.
  Future<WatchCompanionIntentResult> handleIntent(WatchCompanionIntent intent);
}

/// No-op default. Returned by [watchCompanionServiceProvider] until Slice 3
/// overrides the provider with the real implementation backed by the
/// internal adapters.
///
/// Snapshot reports `unsupported` status with everything zeroed; intents
/// are rejected with `diagnosticReason="service_not_wired"` so any caller
/// that hits this in production gets a unique, greppable signal.
class NoOpWatchCompanionService implements WatchCompanionService {
  NoOpWatchCompanionService();

  WatchCompanionSnapshot? _latest;

  @override
  Stream<WatchCompanionSnapshot> get snapshots async* {
    final snap = _buildEmpty();
    _latest = snap;
    yield snap;
  }

  @override
  WatchCompanionSnapshot? get latestSnapshot => _latest;

  @override
  Future<WatchCompanionIntentResult> handleIntent(
    WatchCompanionIntent intent,
  ) async {
    return WatchCompanionIntentResult(
      requestId: intent.requestId,
      accepted: false,
      diagnosticReason: 'service_not_wired',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  WatchCompanionSnapshot _buildEmpty() {
    return WatchCompanionSnapshot(
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      connection: const WatchCompanionConnectionState(
        status: WatchCompanionConnectionStatus.unsupported,
        readinessReason: 'service_not_wired',
      ),
      inbox: const WatchCompanionInboxPreview(
        unreadCount: 0,
        previews: <WatchCompanionInboxMessage>[],
      ),
      nodes: const <WatchCompanionNodePreview>[],
      channels: const <WatchCompanionChannelPreview>[],
      cannedMessages: const <WatchCompanionCannedMessage>[],
      capabilities: WatchCompanionCapabilities.none,
    );
  }
}
