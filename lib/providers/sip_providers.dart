// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for SIP UI state.
///
/// Exposes SIP discovery, handshake, identity, and DM state to the
/// widget layer. All providers are gated behind [SmFeatureFlag.sipEnabled].
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../services/protocol/sip/sip_constants.dart';
import '../services/protocol/sip/sip_counters.dart';
import '../services/protocol/sip/sip_discovery.dart';
import '../services/protocol/sip/sip_dm.dart';
import '../services/protocol/sip/sip_handshake.dart';
import '../services/protocol/sip/sip_identity.dart';
import '../services/protocol/sip/sip_identity_store.dart';
import '../services/protocol/sip/sip_keypair.dart';
import '../services/protocol/sip/sip_rate_limiter.dart';
import '../services/protocol/sip/sip_replay_cache.dart';
import '../services/protocol/sip/sip_types.dart';
import 'app_providers.dart';
import 'app_lifecycle_provider.dart';
import 'sip_nodedex_bridge.dart';

/// Whether SIP is enabled (sourced from SmFeatureFlag).
///
/// Override this in tests or from the protocol service's feature flag.
/// Default: false.
final sipEnabledProvider = NotifierProvider<SipEnabledNotifier, bool>(
  SipEnabledNotifier.new,
);

/// Notifier controlling SIP enabled state.
class SipEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => AppFeatureFlags.isSipEnabled;

  /// Set the SIP enabled state.
  void setEnabled(bool value) => state = value;
}

/// Shared SIP rate limiter instance.
final sipRateLimiterProvider = Provider<SipRateLimiter>((ref) {
  return SipRateLimiter();
});

/// Shared SIP replay cache instance.
final sipReplayCacheProvider = Provider<SipReplayCache>((ref) {
  return SipReplayCache();
});

/// SIP counters (in-memory, reset on restart).
final sipCountersProvider = Provider<SipCounters>((ref) {
  return SipCounters();
});

/// SIP identity store (in-memory TOFU/pin/CHANGED_KEY).
final sipIdentityStoreProvider = Provider<SipIdentityStore>((ref) {
  return SipIdentityStore();
});

/// SIP keypair — async initialization.
///
/// The keypair is loaded (or generated) on first access, then cached.
/// This provider is [FutureProvider] because keypair init hits secure storage.
final sipKeypairProvider = FutureProvider<SipKeypair?>((ref) async {
  final enabled = ref.watch(sipEnabledProvider);
  if (!enabled) return null;

  final keypair = SipKeypair();
  await keypair.ensureInitialized();
  return keypair;
});

/// Bumped whenever the SIP peer cache changes so downstream providers
/// (peer list, peer count) rebuild. This breaks the top-level cycle that
/// would otherwise occur if sipDiscoveryProvider directly invalidated
/// sipDiscoveredPeersProvider.
final sipPeerCacheEpochProvider = NotifierProvider<_SipPeerCacheEpoch, int>(
  _SipPeerCacheEpoch.new,
);

class _SipPeerCacheEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped whenever DM session state changes (new session, new message, etc.)
final sipDmEpochProvider = NotifierProvider<_SipDmEpoch, int>(_SipDmEpoch.new);

class _SipDmEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped whenever a typing indicator is received for any DM session.
final sipDmTypingEpochProvider = NotifierProvider<_SipDmTypingEpoch, int>(
  _SipDmTypingEpoch.new,
);

class _SipDmTypingEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped whenever handshake state changes so peer tile chips rebuild.
final sipHandshakeEpochProvider = NotifierProvider<_SipHandshakeEpoch, int>(
  _SipHandshakeEpoch.new,
);

class _SipHandshakeEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// SIP discovery engine.
///
/// Uses the connected device's node number so we can ignore our own
/// broadcasts. Attaches to [ProtocolService] so inbound SIP packets
/// are routed to the discovery engine.
final sipDiscoveryProvider = Provider<SipDiscovery?>((ref) {
  final enabled = ref.watch(sipEnabledProvider);
  if (!enabled) return null;

  final nodeNum = ref.watch(myNodeNumProvider) ?? 0;
  final limiter = ref.watch(sipRateLimiterProvider);
  final replayCache = ref.watch(sipReplayCacheProvider);

  final discovery = SipDiscovery(
    rateLimiter: limiter,
    localNodeId: nodeNum,
    counters: ref.read(sipCountersProvider),
    replayCache: replayCache,
  );

  // Invalidate peer/count providers when the cache changes so the UI rebuilds.
  discovery.onPeersChanged = () {
    ref.read(sipPeerCacheEpochProvider.notifier).bump();
  };

  // Bridge discovered peers into NodeDex as SIP-capable.
  discovery.onPeerDiscovered = (nodeId) {
    sipBridgeMarkCapableFromRef(ref, nodeId);
  };

  // Resume-safe: set initial timestamps to "now" so we don't burst
  // beacons/rollcalls immediately on provider creation (cold start).
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  discovery.lastBeaconMs = nowMs;
  discovery.lastRollcallReqMs = nowMs;

  // Wire send callback so periodic beacons reach the mesh transport.
  discovery.onSend = (encoded) async {
    final protocol = ref.read(protocolServiceProvider);
    return protocol.sendSipPacket(encoded);
  };

  // Listen for app lifecycle transitions. Use the rate limiter's resume
  // suppression window to prevent post-resume SIP burst transmissions.
  ref.listen<bool>(appLifecycleProvider, (previous, isForeground) {
    if (isForeground && previous == false) {
      limiter.notifyResume();
      AppLogging.sip(
        'SIP_LIFECYCLE: app resumed, suppression window '
        '${SipConstants.resumeSuppressionWindowS}s started',
      );
    }
  });

  // Attach to the protocol service so inbound SIP frames are dispatched.
  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipDiscovery(discovery);

  // Also attach counters to the protocol service.
  final counters = ref.read(sipCountersProvider);
  protocol.attachSipCounters(counters);

  // Start periodic CAP_BEACON broadcast.
  discovery.start();

  // Detach when this provider is disposed (SIP disabled or page torn down).
  ref.onDispose(() {
    discovery.dispose();
    protocol.attachSipDiscovery(null);
    protocol.attachSipCounters(null);
  });

  return discovery;
});

/// SIP handshake manager — attached to protocol service for dispatch.
final sipHandshakeProvider = Provider<SipHandshakeManager?>((ref) {
  final enabled = ref.watch(sipEnabledProvider);
  if (!enabled) return null;

  final replayCache = ref.watch(sipReplayCacheProvider);
  final counters = ref.watch(sipCountersProvider);
  final nodeNum = ref.watch(myNodeNumProvider) ?? 0;
  final manager = SipHandshakeManager(
    replayCache: replayCache,
    localNodeId: nodeNum,
    counters: counters,
  );

  // Bump epoch so UI rebuilds when handshake state changes.
  manager.onStateChanged = () {
    ref.read(sipHandshakeEpochProvider.notifier).bump();
  };

  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipHandshake(manager);

  ref.onDispose(() {
    manager.onStateChanged = null;
    protocol.attachSipHandshake(null);
  });

  return manager;
});

/// SIP identity handler — attached to protocol service for dispatch.
final sipIdentityHandlerProvider = Provider<SipIdentityHandler?>((ref) {
  final enabled = ref.watch(sipEnabledProvider);
  if (!enabled) return null;

  final keypairAsync = ref.watch(sipKeypairProvider);
  final keypair = keypairAsync.asData?.value;
  if (keypair == null) return null;

  final store = ref.watch(sipIdentityStoreProvider);
  final nodeNum = ref.watch(myNodeNumProvider) ?? 0;

  final handler = SipIdentityHandler(
    keypair: keypair,
    store: store,
    localNodeId: nodeNum,
  );

  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipIdentity(handler);

  // Bridge verified identity claims into NodeDex.
  protocol.onSipIdentityVerified =
      ({
        required int nodeId,
        required Uint8List pubkey,
        required Uint8List personaId,
        required SipIdentityState identityState,
        String? displayName,
      }) {
        sipBridgeApplyIdentity(
          ref: ref,
          nodeId: nodeId,
          pubkey: pubkey,
          personaId: personaId,
          identityState: identityState,
          displayName: displayName,
        );
      };

  ref.onDispose(() {
    protocol.onSipIdentityVerified = null;
    protocol.attachSipIdentity(null);
  });

  return handler;
});

/// SIP DM manager — attached to protocol service for dispatch.
final sipDmManagerProvider = Provider<SipDmManager?>((ref) {
  final enabled = ref.watch(sipEnabledProvider);
  if (!enabled) return null;

  final limiter = ref.watch(sipRateLimiterProvider);
  final counters = ref.watch(sipCountersProvider);
  final manager = SipDmManager(rateLimiter: limiter, counters: counters);

  // Bump epoch so UI rebuilds when sessions are created or messages arrive.
  manager.onStateChanged = () {
    ref.read(sipDmEpochProvider.notifier).bump();
  };

  // Bump typing epoch so UI shows/hides typing indicator.
  manager.onTypingReceived = (_) {
    ref.read(sipDmTypingEpochProvider.notifier).bump();
  };

  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipDm(manager);

  ref.onDispose(() {
    protocol.attachSipDm(null);
  });

  return manager;
});

/// Whether SIP auto-scan is persisted across restarts.
final sipAutoScanProvider = NotifierProvider<SipAutoScanNotifier, bool>(
  SipAutoScanNotifier.new,
);

/// Notifier for SIP auto-scan state (persisted to SharedPreferences).
class SipAutoScanNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Read initial value from SettingsService (sync — already initialised).
    final settingsAsync = ref.watch(settingsServiceProvider);
    return settingsAsync.maybeWhen(
      data: (s) => s.sipAutoScanEnabled,
      orElse: () => false,
    );
  }

  /// Toggle auto-scan and persist the new value.
  Future<void> toggle() async {
    final next = !state;
    state = next;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setSipAutoScanEnabled(next);
  }

  /// Explicitly set auto-scan state and persist.
  Future<void> setEnabled(bool value) async {
    state = value;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setSipAutoScanEnabled(value);
  }
}

/// Number of discovered SIP peers (for UI badge).
final sipPeerCountProvider = Provider<int>((ref) {
  ref.watch(sipPeerCacheEpochProvider); // rebuild on cache changes
  final discovery = ref.watch(sipDiscoveryProvider);
  return discovery?.peerCount ?? 0;
});

/// All discovered SIP peers.
final sipDiscoveredPeersProvider = Provider<List<SipPeerCapability>>((ref) {
  ref.watch(sipPeerCacheEpochProvider); // rebuild on cache changes
  final discovery = ref.watch(sipDiscoveryProvider);
  if (discovery == null) return [];
  return discovery.discoveredPeers.toList();
});

/// Active DM sessions.
final sipActiveSessionsProvider = Provider<List<SipDmSession>>((ref) {
  ref.watch(sipDmEpochProvider); // rebuild on DM state changes
  final dm = ref.watch(sipDmManagerProvider);
  return dm?.activeSessions ?? [];
});

/// Handshake state for a specific peer (by node ID).
final sipHandshakeStateProvider = Provider.family<SipHandshakeState, int>((
  ref,
  nodeId,
) {
  ref.watch(sipHandshakeEpochProvider); // rebuild on handshake state changes
  final hs = ref.watch(sipHandshakeProvider);
  return hs?.getState(nodeId) ?? SipHandshakeState.idle;
});
