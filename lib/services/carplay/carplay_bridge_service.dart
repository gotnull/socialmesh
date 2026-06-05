// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import 'carplay_drain_processor.dart';
import 'carplay_feature_flags.dart';
import 'carplay_payload_builder.dart';

/// Main-app writer for the CarPlay communication surface.
///
/// Mirrors recent direct-message history and resolvable peers into the App
/// Group container so the (separate-process) SiriKit Intents extension can read
/// them. The extension cannot reach `ProtocolService` or `messages.db`; the
/// shared JSON files are the only bridge. See
/// `docs/engineering/CARPLAY_COMMUNICATION_V0_1.md` sections 4 and 9.2.
///
/// The actual container write happens natively (`SharedContainer` is the single
/// Swift writer authority); this service builds the payloads and hands JSON
/// strings to the `com.socialmesh/carplay` channel. iOS-only and gated behind
/// [CarPlayFeatureFlags.enabled]; a no-op everywhere else.
class CarPlayBridgeService {
  CarPlayBridgeService(this._ref, this._flags);

  static const MethodChannel _channel = MethodChannel('com.socialmesh/carplay');

  /// Coalesce bursts of message/node updates into one write.
  static const Duration _debounce = Duration(seconds: 2);

  final Ref _ref;
  final CarPlayFeatureFlags _flags;

  Timer? _debounceTimer;
  ProviderSubscription<List<Message>>? _messagesSub;
  ProviderSubscription<Map<int, MeshNode>>? _nodesSub;
  ProviderSubscription<bool>? _connSub;
  AppLifecycleListener? _lifecycleListener;
  bool _started = false;

  /// Idempotency ledger: ids sent in a prior drain whose container removal may
  /// not have landed. Prevents re-sending the same queued message.
  final Set<String> _drainedIds = <String>{};
  bool _draining = false;

  /// Start mirroring. Idempotent and safe under hot restart. Resolves to a
  /// no-op on non-iOS platforms or when the feature flag is off.
  void start() {
    if (_started) return;
    if (!Platform.isIOS) return;
    if (!_flags.enabled) {
      AppLogging.carplay('Bridge disabled by feature flag; not starting.');
      return;
    }
    _started = true;
    AppLogging.carplay('Bridge starting; performing initial sync.');

    // Receive native -> Dart calls (the extension's outbox-changed signal).
    _channel.setMethodCallHandler(_handleNativeCall);

    // Initial snapshot, then debounced re-syncs on message / node changes.
    unawaited(syncNow());
    _messagesSub = _ref.listen<List<Message>>(
      messagesProvider,
      (_, _) => _scheduleSync(),
    );
    _nodesSub = _ref.listen<Map<int, MeshNode>>(
      nodesProvider,
      (_, _) => _scheduleSync(),
    );

    // Drain triggers: on start, when the app returns to the foreground, and
    // when the radio reconnects (queued sends flush as soon as a link exists).
    unawaited(drainOutbox());
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(drainOutbox()),
    );
    _connSub = _ref.listen<bool>(isLinkConnectedProvider, (prev, next) {
      if (next && prev != true) unawaited(drainOutbox());
    });
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'outboxChanged') {
      await drainOutbox();
      return null;
    }
    throw MissingPluginException('Unknown CarPlay method ${call.method}');
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Build both payloads and write them to the shared container. Public so the
  /// initial sync and tests can drive it directly.
  Future<void> syncNow() async {
    if (!_flags.enabled) return;
    final myNodeNum = _ref.read(myNodeNumProvider);
    if (myNodeNum == null) {
      AppLogging.carplay('Sync skipped: no local node num yet.');
      return;
    }

    final messages = _ref.read(messagesProvider);
    final nodes = _ref.read(nodesProvider);

    final recent = CarPlayPayloadBuilder.buildRecentMessages(
      messages: messages,
      nodes: nodes,
      myNodeNum: myNodeNum,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final peers = CarPlayPayloadBuilder.buildPeers(
      nodes: nodes,
      myNodeNum: myNodeNum,
    );

    final convoCount = (recent['conversations'] as List).length;
    final peerCount = (peers['peers'] as List).length;

    try {
      await _channel.invokeMethod<void>(
        'writeRecentMessages',
        jsonEncode(recent),
      );
      await _channel.invokeMethod<void>('writePeers', jsonEncode(peers));
      AppLogging.carplay(
        'Synced $convoCount conversation(s), $peerCount peer(s) to container.',
      );
    } on PlatformException catch (e) {
      // Best-effort: a write failure (e.g. App Group unavailable on an older
      // binary) must never crash the app or block messaging.
      AppLogging.carplay('Container write failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Native handler not present (older build / non-iOS). Harmless.
      AppLogging.carplay('CarPlay channel handler missing; skipping write.');
    }
  }

  /// Drain the outbox: read queued items from the container, send each via the
  /// normal protocol path, then remove the ones that landed. Sends are
  /// optimistic-queue semantics — a disconnected radio throws, the item stays
  /// queued, and the next trigger retries. Re-entrancy guarded so overlapping
  /// triggers (resume + reconnect) do not double-send.
  Future<void> drainOutbox() async {
    if (!_flags.enabled || _draining) return;
    _draining = true;
    try {
      final String? raw = await _channel.invokeMethod<String>('readOutbox');
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items =
          (decoded['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];
      if (items.isEmpty) return;

      final protocol = _ref.read(protocolServiceProvider);
      final drained = await CarPlayDrainProcessor.process(
        items: items,
        alreadyDrained: _drainedIds,
        send: (peerId, text, itemId) async {
          await protocol.sendMessage(
            text: text,
            to: peerId,
            messageId: itemId,
            source: MessageSource.siri,
          );
        },
      );

      if (drained.isEmpty) return;
      _drainedIds.addAll(drained);
      await _channel.invokeMethod<void>('removeDrainedItems', drained);
      // Container removal succeeded: the ledger no longer needs these ids.
      _drainedIds.removeAll(drained);
      AppLogging.carplay('Drained ${drained.length} outbox item(s).');
    } on PlatformException catch (e) {
      AppLogging.carplay('Drain failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Native handler absent (older build / non-iOS). Harmless.
    } finally {
      _draining = false;
    }
  }

  /// Tear down listeners and pending timers.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _messagesSub?.close();
    _messagesSub = null;
    _nodesSub?.close();
    _nodesSub = null;
    _connSub?.close();
    _connSub = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    if (_started) _channel.setMethodCallHandler(null);
    _started = false;
  }
}

/// Provider for the CarPlay bridge service. The flag snapshot is read once at
/// construction from the current dotenv environment.
final carPlayBridgeServiceProvider = Provider<CarPlayBridgeService>((ref) {
  final service = CarPlayBridgeService(ref, CarPlayFeatureFlags.fromEnv());
  ref.onDispose(service.dispose);
  return service;
});
