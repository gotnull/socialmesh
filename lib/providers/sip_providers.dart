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
import '../services/protocol/overlay/overlay_link_models.dart';
import '../services/protocol/overlay/overlay_types.dart';
import '../services/protocol/sip/sip_rate_limiter.dart';
import 'peer_safety_providers.dart';
import '../services/protocol/sip/sip_replay_cache.dart';
import '../services/protocol/sip/sip_types.dart';
import '../services/notifications/notification_service.dart';
import 'app_providers.dart';
import 'app_lifecycle_provider.dart';
import 'mesh_explorer_providers.dart';
import 'overlay_providers.dart';
import 'sip_dm_secure_router.dart';
import 'sip_nodedex_bridge.dart';
import 'sip_play_providers.dart';
import '../services/audio/sip_play_sound_service.dart';

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

  // Auto-open retry queue. When a SIP handshake completes before the
  // peer's overlay capability has been observed (CAP_RESP / CAP_BEACON
  // hasn't arrived yet), `_autoOpenOverlayLink` parks the peer here
  // and the discovery callbacks drain it as soon as caps are observed.
  // Without this, iOS in particular can race: handshake-complete fires
  // before ROLLCALL_RESP populates the cache, auto-open silently noops,
  // and the link only ever opens because the responder side bails us
  // out. See logs.txt for the iOS-side `auto-open skipped: ... not in
  // cache` symptom. Set is closure-scoped so it disposes with the
  // provider.
  final pendingAutoOpens = <int>{};

  // Invalidate peer/count providers when the cache changes so the UI rebuilds.
  // Deferred via microtask: attachSipDiscovery drains early frames
  // synchronously during provider init, which can trigger _upsertPeer.
  // A synchronous bump would modify _SipPeerCacheEpoch while the widget
  // tree is still building — Riverpod forbids that.
  discovery.onPeersChanged = () {
    Future.microtask(() {
      ref.read(sipPeerCacheEpochProvider.notifier).bump();
      _drainPendingAutoOpens(ref, discovery, pendingAutoOpens);
    });
  };

  // Bridge discovered peers into NodeDex as SIP-capable.
  // Also bump the unseen-peer badge counter and fire a local notification.
  // Deferred for the same reason as onPeersChanged above.
  discovery.onPeerDiscovered = (nodeId) {
    Future.microtask(() {
      sipBridgeMarkCapableFromRef(ref, nodeId);
      ref.read(newMeshPeerCountProvider.notifier).bump();
      NotificationService().showSipPeerFoundNotification(peerNodeId: nodeId);
      _drainPendingAutoOpens(ref, discovery, pendingAutoOpens);
    });
  };

  // Resume-safe: set initial timestamps to "now" so we don't burst
  // beacons/rollcalls immediately on provider creation (cold start).
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  discovery.lastBeaconMs = nowMs;
  discovery.lastRollcallReqMs = nowMs;

  // Wire mesh privacy setting so discovery gates beacon/rollcall emission.
  discovery.isDiscoverable = ref.watch(meshPrivacyDiscoverableProvider);

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

  // Share the rate limiter with the protocol service so handshake
  // retransmits (and other non-discovery, non-DM SIP sends routed
  // through it) respect the byte budget instead of bypassing it.
  protocol.attachSipRateLimiter(limiter);

  // Advertise overlay capability bits in CAP_BEACON / CAP_RESP when
  // the overlay flag is on. Evaluated per-emit so a runtime flag flip
  // propagates on the next beacon.
  //
  // Capability dependencies (see OVERLAY_V0_2.md §25.9):
  // - overlayLinkV02 requires OVERLAY_LINK_ENABLED.
  // - overlayResourceV02 requires both link + resource flags
  //   (resource rides on link; encoded in `resourceActive`).
  // - overlaySecureV03 requires link + secure flags (encoded in
  //   `secureActive`). Resource enablement is orthogonal — a peer
  //   may advertise secure without resource, or resource without
  //   secure.
  discovery.localFeaturesOverride = () {
    final flags = ref.read(overlayFlagProvider);
    var bits = SipFeatureBits.allV01;
    if (flags.linkEnabled) bits |= SipFeatureBits.overlayLinkV02;
    if (flags.resourceActive) bits |= SipFeatureBits.overlayResourceV02;
    if (flags.secureActive) bits |= SipFeatureBits.overlaySecureV03;
    // SIP Ink v1 is unconditionally supported by this build; advertise
    // the bit so peers can gate sketch sends on us. See
    // docs/sip/SIP_V0_1.md §6 (v0.2 amendment).
    bits |= SipFeatureBits.dmInkV1;
    // SIP Play v1 (turn-based mini-game framework) is unconditionally
    // supported by this build; advertise the bit so peers can gate
    // dmPlay sends + show the Play CTA.
    bits |= SipFeatureBits.dmPlayV1;
    // SIP Signal v1 (musical phrase + Morse) is unconditionally
    // supported by this build; advertise the bit so peers can gate
    // dmSignal sends + show the Signal tab.
    bits |= SipFeatureBits.dmSignalV1;
    return bits;
  };

  // Overlay v0.2 lifecycle anchor. The attachment providers self-gate
  // on OVERLAY_LINK_ENABLED / OVERLAY_RESOURCE_ENABLED — when off, the
  // futures resolve to null and nothing is wired. When on, listening
  // (without watching) forces the FutureProviders to build so their
  // attach side-effects run, but does NOT rebuild this provider when
  // the AsyncValue transitions Loading → Data. Previously this was
  // ref.watch and caused 4× SipDiscovery rebuilds during startup as
  // each overlay future resolved — see the duplicated `SipDiscovery
  // attached` lines in logs.txt.
  ref.listen(overlayAttachmentProvider, (_, _) {});
  ref.listen(overlayResourceIngressProvider, (_, _) {});

  // Phase 2 secure DM ingress. Self-gates on OVERLAY_SECURE_ENABLED —
  // when off, the future resolves immediately without subscribing.
  // When on, decrypted DM-text / DM-reaction payloads emitted by the
  // secure manager are synthesised into plaintext SIP frames and
  // routed through the existing dm.handleInbound* handlers.
  ref.listen(sipSecureDmIngressProvider, (_, _) {});

  // Wire the handshake-completion hook. On every successful SIP
  // handshake, attempt to auto-open an overlay v0.2 link in the
  // background when both peers support it. Fire-and-forget — failures
  // are logged but never block DM readiness.
  protocol.onSipHandshakeComplete = (peerNodeId) {
    _autoOpenOverlayLink(ref, peerNodeId, discovery, pendingAutoOpens);
    // Audio cue: handshake completed → connection_succeeded.mp3.
    // Fire-and-forget; failures are logged inside the service.
    ref
        .read(sipPlaySoundServiceProvider)
        .play(SipPlaySoundCue.connectionSucceeded);
  };

  // Hook the new SipHandshakeManager failure / decline callbacks
  // (added for the SIP Play SFX layer) onto sound playback. The
  // handshake manager itself suppresses the failure callback for
  // user-initiated cancels (Block / cancelHandshake reason='cancelled')
  // so a Block tap stays silent.
  final hsManager = ref.read(sipHandshakeProvider);
  hsManager?.onHandshakeFailed = (peerNodeId) {
    ref
        .read(sipPlaySoundServiceProvider)
        .play(SipPlaySoundCue.connectionFailed);
  };
  hsManager?.onHandshakeDeclined = (peerNodeId) {
    ref
        .read(sipPlaySoundServiceProvider)
        .play(SipPlaySoundCue.rejectedDeclined);
  };
  // Inbound HS_HELLO needing user consent. Play an audible cue so the
  // user notices the Accept / Decline prompt while they're focused on
  // other work — UX request after handshake-prompt was easy to miss.
  // The handshake manager fires `onHandshakeRequest` from
  // `_handleIncomingHello` after the request is queued in
  // `_pendingRequests`, regardless of whether the app is foreground —
  // the system notification handles background; this audio is the
  // foreground cue.
  hsManager?.onHandshakeRequest = (peerNodeId) {
    ref
        .read(sipPlaySoundServiceProvider)
        .play(SipPlaySoundCue.consentRequested);
  };

  // Fast-path the SIP discovery cap cache from inbound HS_HELLO.
  // Wired here (not inside `sipHandshakeProvider`) so the back-edge
  // discovery → handshake stays one-way and Dart's static analyser
  // doesn't flag a top-level provider cycle. The handshake manager
  // fires this hook from `handleHello` after the request is queued
  // for user consent — the peer's full feature bitmap is on the
  // HS_HELLO wire, so this skips the ~60–300s wait for the next
  // CAP_BEACON / ROLLCALL_RESP. Only fires on the responder side
  // (HS_HELLO is the only handshake message carrying features); the
  // initiator side keeps the slower fallback. See
  // `docs/engineering/SIP_MRRP_ARCHITECTURE.md` §"Cap-cache
  // placeholder pattern" for the full contract.
  hsManager?.onPeerFeaturesObserved = (peerNodeId, features) {
    discovery.recordPeerFeaturesObserved(peerNodeId, features);
  };

  // Start periodic CAP_BEACON broadcast.
  discovery.start();

  // Detach when this provider is disposed (SIP disabled or page torn down).
  // Capture `hsManager` from above by closure — Riverpod 3.x forbids
  // `ref.read` inside lifecycle callbacks, and the manager reference
  // is stable for the lifetime of this provider.
  ref.onDispose(() {
    discovery.dispose();
    protocol.attachSipDiscovery(null);
    protocol.attachSipCounters(null);
    protocol.attachSipRateLimiter(null);
    protocol.onSipHandshakeComplete = null;
    hsManager?.onHandshakeFailed = null;
    hsManager?.onHandshakeDeclined = null;
    hsManager?.onPeerFeaturesObserved = null;
  });

  return discovery;
});

/// Auto-open an overlay v0.2 link for [peerNodeId] when both sides
/// support it. Invoked from [ProtocolService.onSipHandshakeComplete]
/// after the SIP handshake + DM session are ready.
///
/// Policy (strict — all must hold, otherwise no-op):
/// - local `OVERLAY_LINK_ENABLED` is on;
/// - peer's last-seen CAP_RESP advertised [SipFeatureBits.overlayLinkV02];
/// - no non-terminal overlay link already exists for the peer.
///
/// When the peer is not yet in the discovery cache or has not yet
/// advertised overlay support, the peer is parked in [pendingAutoOpens]
/// and retried on the next CAP_RESP / CAP_BEACON observation. This
/// closes a race observed on iOS where handshake-complete fires before
/// ROLLCALL_RESP populates the cache.
///
/// This runs fire-and-forget. Exceptions are logged and counted but
/// never propagate to the SIP layer — chat must remain functional even
/// if overlay misbehaves.
void _autoOpenOverlayLink(
  Ref ref,
  int peerNodeId,
  SipDiscovery discovery,
  Set<int> pendingAutoOpens,
) {
  final flags = ref.read(overlayFlagProvider);
  if (!flags.linkEnabled) return;

  final peer = discovery.getPeer(peerNodeId);
  if (peer == null || !peer.supportsOverlayLinkV02) {
    pendingAutoOpens.add(peerNodeId);
    AppLogging.overlay(
      'auto-open deferred: peer=0x${peerNodeId.toRadixString(16)} '
      '${peer == null ? 'not in cache yet' : 'overlay capability not advertised yet'} '
      '— will retry on peer-cache update',
    );
    return;
  }

  pendingAutoOpens.remove(peerNodeId);

  // Project the peer's SIP-advertised overlay bits onto the overlay
  // link capability bitset. This hint is honoured by `openLocal` when
  // it reuses a stale canonical record whose stored overlay caps are
  // older than the peer's current SIP advertisement — without it, the
  // manager's `_peerSupportsSecure` check runs against yesterday's
  // capabilities and silently skips SECURE_INIT.
  var peerBits = OverlayCapabilityFeature.linkV02;
  if (peer.supportsOverlayResourceV02) {
    peerBits |= OverlayCapabilityFeature.resourceV02;
  }
  if (peer.supportsOverlaySecureV03) {
    peerBits |= OverlayCapabilityFeature.secureV03;
  }
  final peerCapsHint = OverlayLinkCapabilities(supportedFeatures: peerBits);

  // Fire-and-forget. The `ref` object is a Riverpod ProviderRef (alive
  // for the lifetime of sipDiscoveryProvider). No `await` at the call
  // site — we must not block DM completion on overlay.
  Future(() async {
    try {
      final engine = await ref.read(overlayLinkEngineProvider.future);
      final hint = Uint8List(8);
      ByteData.view(hint.buffer).setUint32(0, peerNodeId);
      final record = await engine.openLocal(
        peerPersonaHint: hint,
        peerNodeNum: peerNodeId,
        peerCapabilitiesHint: peerCapsHint,
      );
      AppLogging.overlay(
        'auto-open initiated linkId=0x${record.linkId.toRadixString(16)} '
        'peer=0x${peerNodeId.toRadixString(16)}',
      );
    } catch (e) {
      // StateError from openLocal when an active link already exists
      // is expected and healthy — not a failure to surface.
      AppLogging.overlay(
        'auto-open suppressed for peer=0x${peerNodeId.toRadixString(16)}: $e',
      );
    }
  });
}

/// Drain the [pendingAutoOpens] set against the latest discovery cache.
/// Invoked from `onPeerDiscovered` and `onPeersChanged`: every time a
/// peer's caps land or update, retry any handshakes whose auto-open
/// was deferred because the peer wasn't ready yet.
void _drainPendingAutoOpens(
  Ref ref,
  SipDiscovery discovery,
  Set<int> pendingAutoOpens,
) {
  if (pendingAutoOpens.isEmpty) return;
  // Snapshot — _autoOpenOverlayLink may re-add to the set if still
  // not ready, so iterate over a copy.
  final snapshot = pendingAutoOpens.toList();
  for (final nodeId in snapshot) {
    final peer = discovery.getPeer(nodeId);
    if (peer != null && peer.supportsOverlayLinkV02) {
      AppLogging.overlay(
        'auto-open retry: peer=0x${nodeId.toRadixString(16)} '
        'now advertises overlay link',
      );
      _autoOpenOverlayLink(ref, nodeId, discovery, pendingAutoOpens);
    }
  }
}

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

  // Wire mesh privacy setting so handshake is gated on DM availability.
  manager.isDmAvailable = ref.watch(meshPrivacyDmAvailableProvider);

  // Bump epoch so UI rebuilds when handshake state changes.
  // Deferred via microtask: if a handshake frame arrives in the SIP startup
  // buffer, _drainSipStartupBuffer dispatches it synchronously during
  // provider init, and a synchronous bump would violate Riverpod's
  // no-modify-during-build invariant.
  manager.onStateChanged = () {
    Future.microtask(() {
      ref.read(sipHandshakeEpochProvider.notifier).bump();
    });
  };

  // `onPeerFeaturesObserved` is wired from inside `sipDiscoveryProvider`
  // (the only site that already references both providers) to avoid
  // the top-level provider cycle Dart's static analyser would otherwise
  // flag. See sipDiscoveryProvider for the wiring.

  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipHandshake(manager);

  ref.onDispose(() {
    manager.onStateChanged = null;
    manager.onPeerFeaturesObserved = null;
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

  // Wire mesh privacy setting so identity auto-respond is gated.
  handler.isProfileSharingEnabled = ref.watch(
    meshPrivacyProfileSharingProvider,
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
  // Hot-path Trust + Safety gate: every inbound and outbound DM
  // handler consults this synchronously. Default-safe — returns
  // false (everything allowed) until `peerSafetyManagerProvider`
  // finishes building.
  final safetyGate = ref.watch(peerSafetyGateProvider);
  final manager = SipDmManager(
    rateLimiter: limiter,
    counters: counters,
    safetyGate: safetyGate,
  );

  // Bump epoch so UI rebuilds when sessions are created or messages arrive.
  // Deferred via microtask for the same reason as onPeersChanged above.
  manager.onStateChanged = () {
    Future.microtask(() {
      ref.read(sipDmEpochProvider.notifier).bump();
    });
  };

  // Bump typing epoch so UI shows/hides typing indicator.
  manager.onTypingReceived = (_) {
    Future.microtask(() {
      ref.read(sipDmTypingEpochProvider.notifier).bump();
    });
  };

  // Local notification when an inbound SIP Play move flips the
  // turn to the local side. Field-test request — without this, a
  // backgrounded user has no audible/visible cue that the opponent
  // moved and it's now their turn.
  //
  // Triple-gate before firing:
  //  1. `AppFeatureFlags.isSipEnabled` — env-level kill switch.
  //     SIP Play is a sub-feature of SIP, so when SIP is off the
  //     notification surface is off too. Mirrors the drawer-level
  //     gate on the Handshake hub.
  //  2. `notificationsEnabled` — user's master notification toggle
  //     in Settings → Notifications.
  //  3. `sipPlayTurnNotificationsEnabled` — user's per-feature
  //     toggle for game-turn pings (default true, opt-out only).
  //
  // The settings are read from the synchronously-loaded
  // SettingsService. Default-allow on the .when fallback so a
  // brief "service still loading" window doesn't suppress
  // notifications during cold start.
  manager.onPlayMoveYourTurn = (peerNodeId, _, gameTypeCode, _) {
    Future.microtask(() {
      if (!AppFeatureFlags.isSipEnabled) return;
      final settings = ref.read(settingsServiceProvider).value;
      final masterEnabled = settings?.notificationsEnabled ?? true;
      final turnEnabled = settings?.sipPlayTurnNotificationsEnabled ?? true;
      if (!masterEnabled || !turnEnabled) {
        AppLogging.notifications(
          'sip_play_turn_notif_suppressed master=$masterEnabled '
          'turn=$turnEnabled',
        );
        return;
      }
      NotificationService().showSipPlayTurnNotification(
        peerNodeId: peerNodeId,
        gameTypeCode: gameTypeCode,
      );
    });
  };

  final protocol = ref.read(protocolServiceProvider);
  protocol.attachSipDm(manager);

  ref.onDispose(() {
    manager.onPlayMoveYourTurn = null;
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

// ---------------------------------------------------------------------------
// Mesh privacy settings (persisted to SharedPreferences)
// ---------------------------------------------------------------------------

/// Whether the local node is discoverable on the mesh.
///
/// When false, CAP_BEACON emission, rollcall responses, and SERVICE_ADVERT
/// broadcasts are suppressed. Defaults to true (opt-out).
final meshPrivacyDiscoverableProvider =
    NotifierProvider<MeshPrivacyDiscoverableNotifier, bool>(
      MeshPrivacyDiscoverableNotifier.new,
    );

/// Notifier for mesh discoverability (persisted).
class MeshPrivacyDiscoverableNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settingsAsync = ref.watch(settingsServiceProvider);
    return settingsAsync.maybeWhen(
      data: (s) => s.meshDiscoverable,
      orElse: () => true,
    );
  }

  /// Set discoverability and persist.
  Future<void> setEnabled(bool value) async {
    state = value;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setMeshDiscoverable(value);
  }
}

/// Whether profile sharing is enabled on the mesh.
///
/// When false, identity auto-responses (ID_RESP) and profile.v1 service
/// requests are suppressed. Defaults to true (opt-out).
final meshPrivacyProfileSharingProvider =
    NotifierProvider<MeshPrivacyProfileSharingNotifier, bool>(
      MeshPrivacyProfileSharingNotifier.new,
    );

/// Notifier for mesh profile sharing (persisted).
class MeshPrivacyProfileSharingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settingsAsync = ref.watch(settingsServiceProvider);
    return settingsAsync.maybeWhen(
      data: (s) => s.meshProfileSharing,
      orElse: () => true,
    );
  }

  /// Set profile sharing and persist.
  Future<void> setEnabled(bool value) async {
    state = value;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setMeshProfileSharing(value);
  }
}

/// Whether DMs are available on the mesh.
///
/// When false, handshake initiation and incoming handshake requests are
/// blocked. Defaults to true (opt-out).
final meshPrivacyDmAvailableProvider =
    NotifierProvider<MeshPrivacyDmAvailableNotifier, bool>(
      MeshPrivacyDmAvailableNotifier.new,
    );

/// Notifier for mesh DM availability (persisted).
class MeshPrivacyDmAvailableNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settingsAsync = ref.watch(settingsServiceProvider);
    return settingsAsync.maybeWhen(
      data: (s) => s.meshDmAvailable,
      orElse: () => true,
    );
  }

  /// Set DM availability and persist.
  Future<void> setEnabled(bool value) async {
    state = value;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setMeshDmAvailable(value);
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

/// Node IDs of peers with incoming handshake requests awaiting user consent.
///
/// Rebuilds whenever [sipHandshakeEpochProvider] is bumped, which happens
/// on every handshake state change including new incoming requests.
final sipPendingHandshakeProvider = Provider<List<int>>((ref) {
  ref.watch(sipHandshakeEpochProvider);
  final hs = ref.watch(sipHandshakeProvider);
  return hs?.pendingRequestNodeIds ?? const [];
});

/// 1Hz ticker that drives the live SIP handshake cooldown countdown in
/// peer-tile chips. autoDispose so the timer stops the moment no chip
/// is watching it. Single global timer regardless of peer count — every
/// peer cooldown chip shares this one stream.
final _sipHandshakeCooldownTickerProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  return Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
});

/// Seconds remaining on the per-peer handshake fail cooldown, or 0 when
/// no cooldown is active for [peerNodeId]. Combines the handshake state
/// epoch (which bumps the moment a handshake fails and arms the
/// cooldown) with the 1Hz ticker so the SIP Hub peer-tile chip can
/// live-count down without the chip itself owning a timer.
final sipHandshakeCooldownSecondsProvider = Provider.autoDispose
    .family<int, int>((ref, peerNodeId) {
      ref.watch(sipHandshakeEpochProvider);
      ref.watch(_sipHandshakeCooldownTickerProvider);
      final hs = ref.watch(sipHandshakeProvider);
      if (hs == null) return 0;
      return hs.cooldownRemaining(peerNodeId).inSeconds;
    });
