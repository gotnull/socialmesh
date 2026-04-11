// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the SIP and MRRP startup race condition fix.
///
/// These tests prove that inbound SIP/MRRP frames arriving before
/// [SipDiscovery] / [MrrpEngine] are attached to [ProtocolService] are
/// buffered rather than permanently dropped, and are replayed exactly once
/// once attachment occurs.
///
/// Historical bug: the log line
///   "SIP_RX: no SipDiscovery attached — dropping"
/// was emitted for every packet that arrived in the window between BLE
/// connect and the first SIP-aware screen opening. This prevented passive
/// peer discovery (CAP_BEACON) and MRRP service advertisement caching
/// (SERVICE_ADVERT) from working on fresh app sessions.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dedup_cache.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_echo.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_meetup.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_counters.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_cap.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

// ---------------------------------------------------------------------------
// Helpers / stubs
// ---------------------------------------------------------------------------

/// Minimal no-op transport. No data ever arrives via [dataStream] in these
/// tests; packets are injected directly via [injectSipPacketForTest].
class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  bool get isConnected => false;

  @override
  Future<void> dispose() async {}
}

/// Build a minimal [SipDiscovery] wired to a [ProtocolService] send callback
/// that discards outbound bytes (send direction is not needed for these tests).
SipDiscovery _buildDiscovery({int localNodeId = 0xAABBCCDD}) {
  final limiter = SipRateLimiter();
  final replayCache = SipReplayCache();
  final discovery = SipDiscovery(
    rateLimiter: limiter,
    localNodeId: localNodeId,
    counters: SipCounters(),
    replayCache: replayCache,
  );
  discovery.onSend = (_) async => true; // lint-allow: hardcoded-string
  return discovery;
}

/// Encode a CAP_BEACON SIP frame as raw bytes, as a remote peer would send.
Uint8List _buildBeaconPayload() {
  final beacon = SipCapBeacon(
    features: SipFeatureBits.allV01,
    deviceClass: 1,
    maxProtoMinor: SipConstants.sipVersionMinor,
    mtuHint: SipConstants.sipMaxPayload,
    rxWindowS: 10,
  );
  final beaconPayload = SipCapMessages.encodeCapBeacon(beacon);
  final frame = SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.capBeacon,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: beaconPayload.length,
    payload: beaconPayload,
  );
  return SipCodec.encode(frame)!;
}

/// Build a [pb.MeshPacket] with [from] set to [senderNodeId].
pb.MeshPacket _makePacket(int senderNodeId) {
  final packet = pb.MeshPacket();
  packet.from = senderNodeId;
  return packet;
}

/// Build a minimal [MrrpEngine] with echo.test registered and a discard-send
/// callback. Also returns the [MrrpAdvertEngine] so callers can inspect cache.
({
  MrrpEngine engine,
  MrrpAdvertEngine advertEngine,
  MrrpServiceRegistry registry,
})
_buildMrrpEngine() {
  final registry = MrrpServiceRegistry();
  registry.register(
    MrrpServiceEcho(),
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.echoTest,
      serviceType: MrrpServiceType.test,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.testOnly,
    ),
  );
  registry.register(
    MrrpServiceMeetup(),
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.meetupV1,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.ephemeralOnly |
          MrrpServiceFlags.userVisible,
    ),
  );

  final advertEngine = MrrpAdvertEngine(registry: registry);
  final dispatcher = MrrpDispatcher(registry: registry);
  final dedupCache = MrrpDedupCache();

  Future<bool> discard(Uint8List _) async => true;
  dispatcher.onSend = discard;
  advertEngine.onSend = discard;

  final engine = MrrpEngine(
    registry: registry,
    advertEngine: advertEngine,
    dispatcher: dispatcher,
    dedupCache: dedupCache,
    onSend: discard,
  );

  return (engine: engine, advertEngine: advertEngine, registry: registry);
}

/// Encode a SERVICE_ADVERT MRRP frame wrapped in a SIP mrrpData frame, as a
/// remote peer would send when advertising their services.
Uint8List _buildMrrpServiceAdvertPayload(MrrpServiceRegistry registry) {
  final advertPayload = registry.buildAdvertPayload()!;
  final mrrpFrame = MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.serviceAdvert,
    flags: 0,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: 0,
    serviceId: 0,
    actionId: 0,
    payloadLen: advertPayload.length,
    payload: advertPayload,
  );
  final encodedMrrp = MrrpCodec.encode(mrrpFrame)!;

  // Wrap in SIP mrrpData frame
  final sipFrame = SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.mrrpData,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: encodedMrrp.length,
    payload: encodedMrrp,
  );
  return SipCodec.encode(sipFrame)!;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remotePeer = 0x11223344;

  // ==========================================================================
  // A. SIP startup buffer
  // ==========================================================================

  group('SIP startup buffer', () {
    late ProtocolService protocol;

    setUp(() {
      protocol = ProtocolService(_FakeTransport());
    });

    // A1 — frames received before SipDiscovery is attached are buffered
    // and not permanently lost.
    test(
      'A1: CAP_BEACON before SipDiscovery attachment is not permanently dropped',
      () async {
        final discovery = _buildDiscovery();

        // SipDiscovery is NOT attached yet (simulates startup window).
        expect(
          protocol.sipStartupBufferLength,
          equals(0),
          reason: 'buffer must start empty',
        );

        final beaconPayload = _buildBeaconPayload();
        final packet = _makePacket(remotePeer);

        // Inject beacon while unattached — must buffer, not drop.
        protocol.injectSipPacketForTest(packet, beaconPayload);

        expect(
          protocol.sipStartupBufferLength,
          equals(1),
          reason: 'beacon must be held in startup buffer',
        );

        // Not yet processed — discoverer not attached.
        expect(
          discovery.discoveredPeers.isEmpty,
          isTrue,
          reason: 'peer should not be discovered before drain',
        );

        // Now attach SipDiscovery — drain is deferred to a microtask.
        protocol.attachSipDiscovery(discovery);
        await Future.microtask(() {});

        // Buffer must be cleared after drain.
        expect(
          protocol.sipStartupBufferLength,
          equals(0),
          reason: 'startup buffer must be empty after drain',
        );

        // Peer must have been discovered via the drained beacon.
        expect(
          discovery.discoveredPeers.length,
          equals(1),
          reason: 'buffered CAP_BEACON must be processed exactly once on drain',
        );
        expect(
          discovery.discoveredPeers.first.nodeId,
          equals(remotePeer),
          reason: 'discovered peer must match beacon sender',
        );
      },
    );

    // A2 — multiple frames received before attachment, all drained on attach.
    test(
      'A2: multiple buffered frames all drained on SipDiscovery attachment',
      () async {
        final discovery = _buildDiscovery();
        final beaconPayload = _buildBeaconPayload();

        // Inject 3 beacons from different peers before attachment.
        protocol.injectSipPacketForTest(_makePacket(0x1111), beaconPayload);
        protocol.injectSipPacketForTest(_makePacket(0x2222), beaconPayload);
        protocol.injectSipPacketForTest(_makePacket(0x3333), beaconPayload);

        expect(
          discovery.discoveredPeers.isEmpty,
          isTrue,
          reason: 'no peers until drain',
        );

        protocol.attachSipDiscovery(discovery);
        await Future.microtask(() {});

        expect(
          discovery.discoveredPeers.length,
          equals(3),
          reason: 'all 3 buffered beacons must be drained exactly once',
        );
      },
    );

    // A3 — once attached, frames arrive and are processed immediately (not
    // double-buffered or queued again).
    test(
      'A3: frames after SipDiscovery attachment are processed immediately',
      () {
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        final beaconPayload = _buildBeaconPayload();
        protocol.injectSipPacketForTest(_makePacket(remotePeer), beaconPayload);

        expect(
          discovery.discoveredPeers.length,
          equals(1),
          reason: 'frame after attachment must be processed synchronously',
        );
      },
    );

    // A4 — detaching (null) and re-attaching works; new buffers can be drained.
    test('A4: re-attach after detach drains newly buffered frames', () async {
      final discoveryA = _buildDiscovery(localNodeId: 0xAAAA0000);
      protocol.attachSipDiscovery(discoveryA);
      protocol.attachSipDiscovery(null); // detach

      // Inject a frame while unattached (second startup window).
      final beaconPayload = _buildBeaconPayload();
      protocol.injectSipPacketForTest(_makePacket(remotePeer), beaconPayload);

      final discoveryB = _buildDiscovery(localNodeId: 0xBBBB0000);
      protocol.attachSipDiscovery(discoveryB);
      await Future.microtask(() {});

      expect(
        discoveryB.discoveredPeers.length,
        equals(1),
        reason: 're-attached discovery must receive buffered frame',
      );
      expect(
        discoveryA.discoveredPeers.isEmpty,
        isTrue,
        reason: 'detached discovery must not receive frames',
      );
    });

    // A5 — startup buffer is bounded; frames beyond the cap are discarded.
    test('A5: startup buffer cap prevents unbounded memory growth', () async {
      final beaconPayload = _buildBeaconPayload();

      // Inject more than the cap (16) from distinct peers.
      for (var i = 0; i < 20; i++) {
        protocol.injectSipPacketForTest(_makePacket(0x1000 + i), beaconPayload);
      }

      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);
      await Future.microtask(() {});

      // Only the first 16 must survive; the last 4 are discarded.
      expect(
        discovery.discoveredPeers.length,
        equals(16),
        reason: 'buffer cap must be enforced at 16 frames',
      );
    });

    // A6 — loopback frames received before attachment are silently ignored
    // after drain (self-node beacon must not appear in peer list).
    test(
      'A6: loopback frame buffered before attachment is ignored on drain',
      () async {
        const selfId = 0xAABBCCDD;
        final discovery = _buildDiscovery(localNodeId: selfId);

        final beaconPayload = _buildBeaconPayload();

        // Self broadcasts a beacon (loopback) before attachment.
        protocol.injectSipPacketForTest(_makePacket(selfId), beaconPayload);

        protocol.attachSipDiscovery(discovery);
        await Future.microtask(() {});

        expect(
          discovery.discoveredPeers.isEmpty,
          isTrue,
          reason: 'loopback frame must be dropped even if buffered',
        );
      },
    );
  });

  // ==========================================================================
  // B. MRRP startup buffer
  // ==========================================================================

  group('MRRP startup buffer', () {
    late ProtocolService protocol;
    late MrrpServiceRegistry remoteRegistry;

    setUp(() {
      protocol = ProtocolService(_FakeTransport());

      // Remote registry used to build SERVICE_ADVERT payloads.
      remoteRegistry = MrrpServiceRegistry();
      remoteRegistry.register(
        MrrpServiceMeetup(),
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.meetupV1,
          serviceType: MrrpServiceType.app,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.ephemeralOnly |
              MrrpServiceFlags.userVisible,
        ),
      );
    });

    // B1 — SERVICE_ADVERT before MrrpEngine attached is not permanently dropped.
    test(
      'B1: SERVICE_ADVERT before MrrpEngine attachment is buffered',
      () async {
        // Attach SipDiscovery so the SIP gate is open.
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);
        await Future.microtask(() {});

        // MrrpEngine is NOT attached yet.
        final advertPayload = _buildMrrpServiceAdvertPayload(remoteRegistry);
        protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);

        // Build and attach the MRRP engine AFTER the advert arrived.
        final built = _buildMrrpEngine();
        built.engine.start();
        protocol.attachMrrpEngine(built.engine);

        // The buffered SERVICE_ADVERT must be drained into the engine.
        final cached = built.advertEngine.getAllCachedServices();
        expect(
          cached,
          isNotEmpty,
          reason:
              'SERVICE_ADVERT buffered before engine attachment must be '
              'drained and cached on engine attach',
        );
        expect(
          cached[remotePeer],
          isNotNull,
          reason: 'cached services must be keyed to the remote peer node ID',
        );
      },
    );

    // B2 — SERVICE_ADVERT arriving after MrrpEngine attachment works normally.
    test(
      'B2: SERVICE_ADVERT after MrrpEngine attachment is cached immediately',
      () {
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        final built = _buildMrrpEngine();
        built.engine.start();
        protocol.attachMrrpEngine(built.engine);

        final advertPayload = _buildMrrpServiceAdvertPayload(remoteRegistry);
        protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);

        final cached = built.advertEngine.getAllCachedServices();
        expect(
          cached[remotePeer],
          isNotNull,
          reason:
              'SERVICE_ADVERT must be cached when engine is already attached',
        );
      },
    );

    // B3 — MRRP buffer is bounded; frames beyond cap are discarded.
    test('B3: MRRP startup buffer cap prevents unbounded memory growth', () {
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      final advertPayload = _buildMrrpServiceAdvertPayload(remoteRegistry);
      // Inject 20 SERVICE_ADVERTs from the same peer.
      for (var i = 0; i < 20; i++) {
        protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);
      }

      final built = _buildMrrpEngine();
      built.engine.start();
      protocol.attachMrrpEngine(built.engine);

      // Engine should have processed (up to cap) adverts without crashing.
      expect(
        built.advertEngine.getAllCachedServices(),
        isNotEmpty,
        reason: 'at least one buffered SERVICE_ADVERT must have been cached',
      );
    });
  });

  // ==========================================================================
  // C. Combined startup race: both SIP and MRRP unattached
  // ==========================================================================

  group('Combined SIP + MRRP startup race', () {
    test('C1: SERVICE_ADVERT received while both SipDiscovery and MrrpEngine '
        'unattached survives via two-stage drain', () async {
      final protocol = ProtocolService(_FakeTransport());

      // Neither SipDiscovery nor MrrpEngine is attached yet.
      final remoteReg = MrrpServiceRegistry();
      remoteReg.register(
        MrrpServiceMeetup(),
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.meetupV1,
          serviceType: MrrpServiceType.app,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.userVisible,
        ),
      );

      final advertPayload = _buildMrrpServiceAdvertPayload(remoteReg);
      protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);

      // Step 1: attach SipDiscovery — SIP drain is deferred to a microtask.
      // Once it fires, the mrrpData frame routes to the MRRP engine (which
      // is already attached by step 2, so it processes directly — no MRRP
      // buffer stage needed with the deferred SIP drain).
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // Step 2: attach MrrpEngine — synchronous MRRP drain (no-op here
      // since the SIP drain hasn't fired yet, so the MRRP buffer is empty).
      final built = _buildMrrpEngine();
      built.engine.start();
      protocol.attachMrrpEngine(built.engine);

      // Flush the deferred SIP drain microtask — the SIP frame is processed,
      // decoded as MRRP data, and routed directly to the now-attached engine.
      await Future.microtask(() {});

      final cached = built.advertEngine.getAllCachedServices();
      expect(
        cached[remotePeer],
        isNotNull,
        reason:
            'SERVICE_ADVERT buffered at both SIP and MRRP layers must '
            'survive both drains and be visible in cache',
      );
    });
  });

  // ==========================================================================
  // D. Policy verification: public vs. handshake-gated services
  // ==========================================================================

  group('Service policy: public vs handshake-gated', () {
    test('D1: service without requires_handshake flag is visible in cache '
        'without requiring a handshake', () {
      final protocol = ProtocolService(_FakeTransport());
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // Registry advertising an open (userVisible + no requiresHandshake)
      // service.
      final remoteReg = MrrpServiceRegistry();
      remoteReg.register(
        MrrpServiceMeetup(),
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.meetupV1,
          serviceType: MrrpServiceType.app,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.ephemeralOnly |
              MrrpServiceFlags.userVisible,
          // requiresHandshake is NOT set
        ),
      );

      final built = _buildMrrpEngine();
      built.engine.start();
      protocol.attachMrrpEngine(built.engine);

      final advertPayload = _buildMrrpServiceAdvertPayload(remoteReg);
      protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);

      final cached = built.advertEngine.getAllCachedServices();
      final peerServices = cached[remotePeer] ?? [];

      expect(
        peerServices.any(
          (s) => s.descriptor.serviceId == MrrpServiceId.meetupV1,
        ),
        isTrue,
        reason: 'open service must appear in cache without any handshake',
      );

      // Confirm requiresHandshake is NOT set in the cached descriptor.
      final meetupDescriptor = peerServices
          .firstWhere((s) => s.descriptor.serviceId == MrrpServiceId.meetupV1)
          .descriptor;
      expect(
        meetupDescriptor.serviceFlags & MrrpServiceFlags.requiresHandshake,
        equals(0),
        reason:
            'meetup.v1 must not have requiresHandshake set — '
            'discovery must be possible without a handshake',
      );
    });

    test(
      'D2: service with requiresHandshake flag retains that flag in cache',
      () {
        final protocol = ProtocolService(_FakeTransport());
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        // Registry advertising a handshake-gated profile.v1-equivalent service.
        const kGatedServiceId = 0x00000020;
        final remoteReg = MrrpServiceRegistry();
        remoteReg.register(
          MrrpServiceEcho(), // reuse echo handler as a placeholder
          MrrpServiceDescriptor(
            serviceId: kGatedServiceId,
            serviceType: MrrpServiceType.app,
            serviceFlags:
                MrrpServiceFlags.supportsRequest |
                MrrpServiceFlags.supportsResponse |
                MrrpServiceFlags.requiresHandshake |
                MrrpServiceFlags.userVisible,
          ),
        );

        final built = _buildMrrpEngine();
        built.engine.start();
        protocol.attachMrrpEngine(built.engine);

        final advertPayload = _buildMrrpServiceAdvertPayload(remoteReg);
        protocol.injectSipPacketForTest(_makePacket(remotePeer), advertPayload);

        final cached = built.advertEngine.getAllCachedServices();
        final peerServices = cached[remotePeer] ?? [];
        final gatedDescriptor = peerServices
            .firstWhere((s) => s.descriptor.serviceId == kGatedServiceId)
            .descriptor;

        expect(
          gatedDescriptor.serviceFlags & MrrpServiceFlags.requiresHandshake,
          isNonZero,
          reason:
              'requiresHandshake flag must be preserved in cached descriptor',
        );
      },
    );
  });

  // ==========================================================================
  // E. Regression: existing routing still works after buffer changes
  // ==========================================================================

  group('Regression: existing routing unaffected', () {
    test(
      'E1: CAP_BEACON delivered directly when SipDiscovery already attached',
      () {
        final protocol = ProtocolService(_FakeTransport());
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        final beaconPayload = _buildBeaconPayload();
        protocol.injectSipPacketForTest(_makePacket(remotePeer), beaconPayload);

        expect(
          discovery.discoveredPeers.length,
          equals(1),
          reason: 'pre-attachment code path must still route CAP_BEACON',
        );
      },
    );

    test(
      'E2: invalid SIP magic bytes are still rejected after buffer changes',
      () {
        final protocol = ProtocolService(_FakeTransport());
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        // Corrupt payload — wrong magic bytes.
        final badPayload = Uint8List.fromList([0x00, 0x00, 0x01, 0x00]);
        protocol.injectSipPacketForTest(_makePacket(remotePeer), badPayload);

        expect(
          discovery.discoveredPeers.isEmpty,
          isTrue,
          reason: 'malformed SIP frame must still be rejected',
        );
      },
    );

    test(
      'E3: SipDiscovery receives exactly one event per frame, never double-counted',
      () async {
        final protocol = ProtocolService(_FakeTransport());
        final beaconPayload = _buildBeaconPayload();

        // Buffer one beacon before attach...
        protocol.injectSipPacketForTest(_makePacket(remotePeer), beaconPayload);

        // ... then attach (drain deferred to microtask).
        final discovery = _buildDiscovery();
        protocol.attachSipDiscovery(discovery);

        // ... then send another beacon from same peer AFTER attach (live path).
        protocol.injectSipPacketForTest(_makePacket(remotePeer), beaconPayload);

        // Wait for deferred SIP drain microtask.
        await Future.microtask(() {});

        // The same peer sending two beacons should still result in 1 peer
        // in the cache (SipDiscovery dedups by nodeId).
        expect(
          discovery.discoveredPeers.length,
          equals(1),
          reason:
              'same peer sending two beacons must appear only once in cache',
        );
      },
    );
  });

  // ==========================================================================
  // F. Reconnect isolation — stale frames must not survive a BLE reconnect
  // ==========================================================================
  //
  // Root cause: ProtocolService is a singleton (provider lives for the app
  // lifetime). Both startup buffers survive across BLE connections unless
  // explicitly cleared. start() is the BLE reconnect entry point and must
  // flush both buffers so frames from Device A are never replayed to Device B.
  //
  // clearStartupBuffersForTest() mirrors the exact code path that start()
  // executes, without the async transport/configuration dance that is
  // impractical to drive inside unit tests.

  group('Reconnect isolation', () {
    const deviceAPeer = 0x11223344; // peer node on Device A's mesh
    const deviceBPeer = 0x55667788; // peer node on Device B's mesh

    // F1 — clearStartupBuffersForTest() empties both buffers and the
    // discovery engine is then not reached by stale SIP frames.
    test('F1: clearStartupBuffers empties SIP startup buffer', () {
      final protocol = ProtocolService(_FakeTransport());

      // Simulate frames arriving during Device A session, before attach.
      final payload = _buildBeaconPayload();
      protocol.injectSipPacketForTest(_makePacket(deviceAPeer), payload);
      protocol.injectSipPacketForTest(_makePacket(deviceAPeer), payload);

      expect(
        protocol.sipStartupBufferLength,
        equals(2),
        reason: 'two frames must be buffered',
      );

      // Simulate BLE reconnect (what start() does).
      protocol.clearStartupBuffersForTest();

      expect(
        protocol.sipStartupBufferLength,
        equals(0),
        reason: 'start() must flush SIP buffer before new session',
      );
    });

    // F2 — clearStartupBuffers also empties the MRRP startup buffer.
    test('F2: clearStartupBuffers empties MRRP startup buffer', () {
      final protocol = ProtocolService(_FakeTransport());
      final built = _buildMrrpEngine();

      // Attach SipDiscovery so the SIP gate is open, then inject an
      // mrrpData frame to populate the MRRP buffer (MrrpEngine not yet
      // attached).
      final discovery = _buildDiscovery(localNodeId: deviceAPeer + 1);
      protocol.attachSipDiscovery(discovery);

      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);
      protocol.injectSipPacketForTest(_makePacket(deviceAPeer), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(1),
        reason: 'mrrpData frame must be buffered while MrrpEngine unattached',
      );

      // Detach SipDiscovery (simulates session teardown).
      protocol.attachSipDiscovery(null);

      // Simulate reconnect flush.
      protocol.clearStartupBuffersForTest();

      expect(
        protocol.mrrpStartupBufferLength,
        equals(0),
        reason: 'start() must flush MRRP buffer before new session',
      );
    });

    // F3 — Stale SIP peer from Device A does NOT appear after reconnect.
    //
    // This is the core adversarial test: buffer Device A's beacon, simulate
    // reconnect (clear buffers), inject Device B's beacon, then attach
    // SipDiscovery.  Only Device B's peer must appear; Device A's must not.
    test(
      'F3: stale SIP peer from prior session is not replayed after reconnect',
      () async {
        final protocol = ProtocolService(_FakeTransport());

        // --- Device A session ---
        // Frames from Device A arrive in the startup window (SipDiscovery not
        // yet attached).
        final payload = _buildBeaconPayload();
        protocol.injectSipPacketForTest(_makePacket(deviceAPeer), payload);

        expect(
          protocol.sipStartupBufferLength,
          equals(1),
          reason: 'Device A beacon must be buffered',
        );

        // BLE disconnect + reconnect to Device B; start() clears buffers.
        protocol.clearStartupBuffersForTest();

        // --- Device B session ---
        // Now a new peer from Device B's mesh sends a beacon before
        // SipDiscovery is attached.
        protocol.injectSipPacketForTest(_makePacket(deviceBPeer), payload);

        // Attach SipDiscovery (user opens Mesh Explorer).
        final discovery = _buildDiscovery(localNodeId: deviceBPeer + 1);
        protocol.attachSipDiscovery(discovery);

        // SIP drain is deferred to a microtask — wait for it.
        await Future.microtask(() {});

        // Only Device B's peer must appear.
        expect(
          discovery.discoveredPeers.any((p) => p.nodeId == deviceBPeer),
          isTrue,
          reason: 'Device B peer must be discovered after reconnect',
        );
        expect(
          discovery.discoveredPeers.any((p) => p.nodeId == deviceAPeer),
          isFalse,
          reason: 'stale Device A peer must NOT appear in Device B session',
        );
        expect(
          discovery.discoveredPeers.length,
          equals(1),
          reason: 'exactly one peer must be discovered',
        );
      },
    );

    // F4 — Post-reconnect buffering still works: frames injected after
    // clearStartupBuffers (but before SipDiscovery attaches) are buffered.
    test(
      'F4: post-reconnect buffering works normally after clearStartupBuffers',
      () async {
        final protocol = ProtocolService(_FakeTransport());

        // Simulate reconnect flush.
        protocol.clearStartupBuffersForTest();

        // New-session frames arrive before SipDiscovery attaches.
        final payload = _buildBeaconPayload();
        protocol.injectSipPacketForTest(_makePacket(deviceBPeer), payload);

        expect(
          protocol.sipStartupBufferLength,
          equals(1),
          reason: 'post-reconnect frames must still buffer until attach',
        );

        // Attach — drain is deferred to a microtask.
        final discovery = _buildDiscovery(localNodeId: deviceBPeer + 1);
        protocol.attachSipDiscovery(discovery);

        // SIP drain is deferred to a microtask — wait for it.
        await Future.microtask(() {});

        expect(
          discovery.discoveredPeers.any((p) => p.nodeId == deviceBPeer),
          isTrue,
          reason: 'post-reconnect peer must be discovered on attach',
        );
        expect(
          protocol.sipStartupBufferLength,
          equals(0),
          reason: 'buffer must be empty after drain',
        );
      },
    );

    // F5 — Both-null drain: clear both buffers atomically; partial state
    // (SIP flushed but MRRP not) must be impossible.
    test('F5: clearStartupBuffers clears both buffers atomically', () {
      final protocol = ProtocolService(_FakeTransport());
      final built = _buildMrrpEngine();

      // Populate SIP buffer (no discovery attached).
      final beaconPayload = _buildBeaconPayload();
      protocol.injectSipPacketForTest(_makePacket(deviceAPeer), beaconPayload);

      // Attach SipDiscovery so SIP frames pass through to MRRP gate.
      final discovery = _buildDiscovery(localNodeId: deviceAPeer + 1);
      protocol.attachSipDiscovery(discovery);

      // With SipDiscovery attached, an mrrpData frame routes to MRRP buf.
      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);
      protocol.injectSipPacketForTest(_makePacket(deviceAPeer), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(1),
        reason: 'MRRP buffer must have 1 frame before clear',
      );

      // Detach discovery, then simulate reconnect.
      protocol.attachSipDiscovery(null);
      protocol.clearStartupBuffersForTest();

      expect(
        protocol.sipStartupBufferLength,
        equals(0),
        reason: 'SIP buffer must be empty after clear',
      );
      expect(
        protocol.mrrpStartupBufferLength,
        equals(0),
        reason: 'MRRP buffer must be empty after clear',
      );
    });
  });

  // ==========================================================================
  // G. Engine start order — proves the critical attach/start ordering contract
  // ==========================================================================
  //
  // Root cause (class of bugs): mrrpEngineProvider originally called
  // protocol.attachMrrpEngine(engine) BEFORE engine.start(). The drain in
  // attachMrrpEngine fires synchronously and routes each buffered frame to
  // engine.handleInboundFrame, which checks `if (!_running)` first.
  // With `_running == false`, every drained frame is permanently dropped.
  //
  // Invariant: engine.start() MUST be called before protocol.attachMrrpEngine.
  // These two tests document and protect that invariant.

  group('Engine start order', () {
    const peer = 0x11223344;

    // G1 — the failure mode: attach BEFORE start drops all buffered frames.
    //
    // This test deliberately uses the incorrect ordering (attach → start) and
    // asserts that the buffered SERVICE_ADVERT is NOT cached.  If this test
    // ever starts passing it means handleInboundFrame no longer drops frames
    // when not-running, and the ordering constraint can be revisited.
    test('G1: attaching engine before start() drops all buffered MRRP frames '
        '(documents the failure mode)', () {
      final protocol = ProtocolService(_FakeTransport());
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // Buffer a SERVICE_ADVERT while MrrpEngine is unattached.
      final built = _buildMrrpEngine();
      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);
      protocol.injectSipPacketForTest(_makePacket(peer), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(1),
        reason: 'SERVICE_ADVERT must be in the MRRP startup buffer',
      );

      // WRONG ORDER: attach before start.
      // Engine._running == false when drain fires → handleInboundFrame drops.
      protocol.attachMrrpEngine(built.engine); // drain fires here — drops
      built.engine.start(); // too late

      expect(
        built.advertEngine.getAllCachedServices(),
        isEmpty,
        reason:
            'buffered SERVICE_ADVERT must be dropped when engine is attached '
            'before start() — this documents the failure mode that the '
            'provider-layer fix must avoid',
      );
    });

    // G2 — the required contract: start BEFORE attach delivers all buffered frames.
    //
    // This mirrors the corrected ordering in mrrpEngineProvider and must
    // always pass.  A regression in the provider layer that reverts to
    // "attach before start" will be caught by G1 changing sense AND by B1.
    test('G2: starting engine before attach() delivers all buffered MRRP frames '
        '(required contract)', () {
      final protocol = ProtocolService(_FakeTransport());
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // Buffer a SERVICE_ADVERT while MrrpEngine is unattached.
      final built = _buildMrrpEngine();
      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);
      protocol.injectSipPacketForTest(_makePacket(peer), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(1),
        reason: 'SERVICE_ADVERT must be in the MRRP startup buffer',
      );

      // CORRECT ORDER: start before attach.
      // Engine._running == true when drain fires → handleInboundFrame processes.
      built.engine.start(); // running = true BEFORE drain
      protocol.attachMrrpEngine(built.engine); // drain fires, frame delivered

      expect(
        built.advertEngine.getAllCachedServices(),
        isNotEmpty,
        reason:
            'buffered SERVICE_ADVERT must be cached when engine is started '
            'before attach() — this is the required contract',
      );
      expect(
        built.advertEngine.getAllCachedServices()[peer],
        isNotNull,
        reason: 'cached services must be keyed to the peer node ID',
      );
    });

    // G3 — multiple peers' buffered adverts all delivered with correct ordering.
    test('G3: buffered SERVICE_ADVERTs from multiple peers all delivered when '
        'start() precedes attach()', () {
      final protocol = ProtocolService(_FakeTransport());
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      final built = _buildMrrpEngine();
      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);

      // Three distinct peers all advertise before engine attaches.
      protocol.injectSipPacketForTest(_makePacket(0x1111), mrrpPayload);
      protocol.injectSipPacketForTest(_makePacket(0x2222), mrrpPayload);
      protocol.injectSipPacketForTest(_makePacket(0x3333), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(3),
        reason: 'three frames must be buffered',
      );

      built.engine.start();
      protocol.attachMrrpEngine(built.engine);

      final cached = built.advertEngine.getAllCachedServices();
      expect(
        cached.keys,
        containsAll([0x1111, 0x2222, 0x3333]),
        reason: 'all three peers must be cached after drain',
      );
    });
  });

  // ==========================================================================
  // H. Duplicate early frames — dedup within the startup buffers
  // ==========================================================================
  //
  // Mesh broadcasts hop up to 3 times; the app may receive multiple copies of
  // the same CAP_BEACON or SERVICE_ADVERT from the same peer during the
  // startup window.  The fix must not create phantom peers or double-count
  // cached services.

  group('Duplicate early frames', () {
    const peer = 0x11223344;

    // H1 — duplicate CAP_BEACON nonces in SIP startup buffer: only the first
    // copy of each nonce is processed (SipReplayCache dedup).
    test('H1: duplicate CAP_BEACON nonces in startup buffer — only first copy '
        'reaches discovery cache', () async {
      final protocol = ProtocolService(_FakeTransport());

      // Build a single beacon payload (same nonce throughout).
      final beaconPayload = _buildBeaconPayload();

      // Inject three copies — same bytes, same nonce.
      protocol.injectSipPacketForTest(_makePacket(peer), beaconPayload);
      protocol.injectSipPacketForTest(_makePacket(peer), beaconPayload);
      protocol.injectSipPacketForTest(_makePacket(peer), beaconPayload);

      expect(
        protocol.sipStartupBufferLength,
        equals(3),
        reason: 'all three copies must be held in the startup buffer',
      );

      // Attach with a fresh SipDiscovery.
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // SIP drain is deferred to a microtask — wait for it.
      await Future.microtask(() {});

      // SipReplayCache records the nonce on first processing; subsequent
      // copies are returned as duplicate and skipped by handleBeacon.
      expect(
        discovery.discoveredPeers.length,
        equals(1),
        reason:
            'only one peer must appear — duplicates deduplicated via '
            'SipReplayCache nonce matching',
      );
    });

    // H2 — duplicate SERVICE_ADVERT hashes in MRRP startup buffer: only the
    // first is cached (MrrpAdvertEngine._lastAdvertHash payload-hash dedup).
    test('H2: duplicate SERVICE_ADVERT payloads in MRRP startup buffer — only '
        'first copy cached', () {
      final protocol = ProtocolService(_FakeTransport());
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      final built = _buildMrrpEngine();
      // Same registry → same advertPayload bytes → same payload hash.
      final mrrpPayload = _buildMrrpServiceAdvertPayload(built.registry);

      // Inject three identical SERVICE_ADVERTs.
      protocol.injectSipPacketForTest(_makePacket(peer), mrrpPayload);
      protocol.injectSipPacketForTest(_makePacket(peer), mrrpPayload);
      protocol.injectSipPacketForTest(_makePacket(peer), mrrpPayload);

      expect(
        protocol.mrrpStartupBufferLength,
        equals(3),
        reason: 'all three copies must be held in the MRRP startup buffer',
      );

      built.engine.start();
      protocol.attachMrrpEngine(built.engine);

      // Only the first advert is processed; the other two share the same
      // payload hash and are skipped by handleServiceAdvert._lastAdvertHash.
      final cached = built.advertEngine.getAllCachedServices();
      expect(
        cached[peer],
        isNotNull,
        reason: 'peer must be cached after drain',
      );
      // Regardless of dedup, the peer has exactly one set of services.
      expect(
        cached[peer]!.length,
        greaterThan(0),
        reason: 'at least one service must be cached',
      );
    });

    // H3 — duplicate early beacon + live beacon overlap: drain processes early
    // copy (nonce recorded); live copy with same nonce arrives post-attach and
    // is also deduplicated.  No double-count either way.
    test('H3: buffered beacon + live beacon with same nonce — discovery cache '
        'remains at exactly one peer', () async {
      final protocol = ProtocolService(_FakeTransport());

      final beaconPayload = _buildBeaconPayload();

      // Buffer one copy before attach.
      protocol.injectSipPacketForTest(_makePacket(peer), beaconPayload);

      // Attach — drain deferred to microtask.
      final discovery = _buildDiscovery();
      protocol.attachSipDiscovery(discovery);

      // SIP drain is deferred to a microtask — wait for it.
      await Future.microtask(() {});

      expect(
        discovery.discoveredPeers.length,
        equals(1),
        reason: 'peer must be discovered after drain',
      );

      // Same bytes arrive again after attach (live, same nonce).
      protocol.injectSipPacketForTest(_makePacket(peer), beaconPayload);

      // Nonce is already in the replay cache → duplicate ignored.
      expect(
        discovery.discoveredPeers.length,
        equals(1),
        reason:
            'peer count must remain 1 — live duplicate deduplicated via '
            'SipReplayCache',
      );
    });
  });
}
