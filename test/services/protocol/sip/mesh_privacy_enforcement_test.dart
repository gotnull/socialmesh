// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests proving the mesh privacy enforcement chain:
//
// - Discoverable → SipDiscovery (beacon, rollcall) + MrrpAdvertEngine
// - Profile Sharing → SipIdentityHandler (auto-respond)
// - DM Available → SipHandshakeManager (initiate, incoming HELLO)
//
// Each test traces: flag change → protocol behavior change.

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dedup_cache.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_handler.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_profile.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_identity.dart';
import 'package:socialmesh/services/protocol/sip/sip_identity_store.dart';
import 'package:socialmesh/services/protocol/sip/sip_keypair.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_hs.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_id.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// In-memory fake for [FlutterSecureStorage] (v10.0.0 API).
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.remove(key);
}

/// Create a test keypair backed by in-memory storage.
Future<SipKeypair> _createTestKeypair() async {
  final kp = SipKeypair(storage: _FakeSecureStorage(), algorithm: Ed25519());
  await kp.ensureInitialized();
  return kp;
}

/// Minimal MRRP service handler for registry tests.
class _TestHandler implements MrrpServiceHandler {
  @override
  final int serviceId;

  @override
  final Set<int> supportedActions = const {1};

  _TestHandler({required this.serviceId});

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    return MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      payload: Uint8List(0),
    );
  }
}

/// Build a minimal HS_HELLO frame for testing.
SipFrame _buildHelloFrame() {
  final hello = SipHsHello(
    clientNonce: Uint8List.fromList(List.generate(16, (i) => i)),
    clientEphemeralPub: Uint8List.fromList(List.generate(32, (i) => i + 16)),
    requestedFeatures: SipFeatureBits.allV01,
  );
  final payload = SipHsMessages.encodeHello(hello);
  return SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.hsHello,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: payload.length,
    payload: payload,
  );
}

void main() {
  // =========================================================================
  // Discoverable → SipDiscovery
  // =========================================================================
  group('Discoverable → SipDiscovery', () {
    late SipRateLimiter rateLimiter;
    late SipDiscovery discovery;
    late int nowMs;

    setUp(() {
      nowMs = 1700000000000;
      rateLimiter = SipRateLimiter(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      discovery = SipDiscovery(
        rateLimiter: rateLimiter,
        localNodeId: 0xAAAA,
        clock: () => nowMs,
        beaconJitterMs: 0,
      );
    });

    test('CAP_BEACON suppressed when isDiscoverable=false (default)', () {
      expect(discovery.isDiscoverable, isFalse);
      final beacon = discovery.buildBeacon(force: true);
      expect(beacon, isNull);
    });

    test('CAP_BEACON emitted when isDiscoverable=true', () {
      discovery.isDiscoverable = true;
      final beacon = discovery.buildBeacon(force: true);
      expect(beacon, isNotNull);
      expect(beacon!.encoded.length, greaterThan(0));
    });

    test('ROLLCALL_RESP suppressed when isDiscoverable=false', () {
      expect(discovery.isDiscoverable, isFalse);
      final resp = discovery.buildRollcallResp(0xBBBB);
      expect(resp, isNull);
    });

    test('ROLLCALL_RESP emitted when isDiscoverable=true', () {
      discovery.isDiscoverable = true;
      final resp = discovery.buildRollcallResp(0xBBBB);
      expect(resp, isNotNull);
    });

    test('handleRollcallReq returns null when isDiscoverable=false', () {
      expect(discovery.isDiscoverable, isFalse);
      final resp = discovery.handleRollcallReq(0xBBBB);
      expect(resp, isNull);
    });

    test('handleRollcallReq returns response when isDiscoverable=true', () {
      discovery.isDiscoverable = true;
      final resp = discovery.handleRollcallReq(0xBBBB);
      expect(resp, isNotNull);
    });

    test('toggle discoverable: off→on→off', () {
      expect(discovery.buildBeacon(force: true), isNull);

      discovery.isDiscoverable = true;
      expect(discovery.buildBeacon(force: true), isNotNull);

      discovery.isDiscoverable = false;
      nowMs += 400 * 1000; // Advance past interval
      expect(discovery.buildBeacon(force: true), isNull);
    });

    test('clearPeerCache resets peer state', () {
      discovery.isDiscoverable = true;
      expect(discovery.peerCount, 0);
      discovery.clearPeerCache();
      expect(discovery.peerCount, 0);
    });
  });

  // =========================================================================
  // DM Available → SipHandshakeManager
  // =========================================================================
  group('DM Available → SipHandshakeManager', () {
    late SipHandshakeManager manager;

    setUp(() {
      manager = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xAAAA,
      );
    });

    test(
      'initiateHandshake returns null when isDmAvailable=false (default)',
      () {
        expect(manager.isDmAvailable, isFalse);
        final frame = manager.initiateHandshake(0xBBBB);
        expect(frame, isNull);
      },
    );

    test('initiateHandshake succeeds when isDmAvailable=true', () {
      manager.isDmAvailable = true;
      final frame = manager.initiateHandshake(0xBBBB);
      expect(frame, isNotNull);
      expect(frame!.msgType, SipMessageType.hsHello);
    });

    test('incoming HS_HELLO ignored when isDmAvailable=false', () {
      expect(manager.isDmAvailable, isFalse);
      final helloFrame = _buildHelloFrame();
      manager.handleHello(0xBBBB, helloFrame);
      expect(manager.pendingRequestNodeIds, isEmpty);
    });

    test('incoming HS_HELLO queued when isDmAvailable=true', () {
      manager.isDmAvailable = true;
      final helloFrame = _buildHelloFrame();
      manager.handleHello(0xBBBB, helloFrame);
      expect(manager.pendingRequestNodeIds, contains(0xBBBB));
    });

    test('toggle dmAvailable: off→on→off', () {
      expect(manager.initiateHandshake(0xCCCC), isNull);

      manager.isDmAvailable = true;
      expect(manager.initiateHandshake(0xCCCC), isNotNull);

      manager.isDmAvailable = false;
      expect(manager.initiateHandshake(0xDDDD), isNull);
    });
  });

  // =========================================================================
  // Profile Sharing → SipIdentityHandler
  // =========================================================================
  group('Profile Sharing → SipIdentityHandler', () {
    late SipKeypair keypair;
    late SipIdentityHandler handler;

    setUpAll(() async {
      keypair = await _createTestKeypair();
    });

    setUp(() {
      handler = SipIdentityHandler(
        keypair: keypair,
        store: SipIdentityStore(),
        localNodeId: 0xAAAA,
      );
    });

    test(
      'handleInboundReq returns null when isProfileSharingEnabled=false',
      () async {
        expect(handler.isProfileSharingEnabled, isFalse);
        final reqPayload = SipIdMessages.encodeIdReq(
          SipIdReq(mode: SipIdRequestMode.basic),
        );
        final reqFrame = SipFrame(
          versionMajor: SipConstants.sipVersionMajor,
          versionMinor: SipConstants.sipVersionMinor,
          msgType: SipMessageType.idReq,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: SipCodec.generateNonce(),
          timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          payloadLen: reqPayload.length,
          payload: reqPayload,
        );
        final result = await handler.handleInboundReq(
          frame: reqFrame,
          senderNodeId: 0xBBBB,
        );
        expect(result, isNull);
      },
    );

    test(
      'handleInboundReq succeeds when isProfileSharingEnabled=true',
      () async {
        handler.isProfileSharingEnabled = true;
        final reqPayload = SipIdMessages.encodeIdReq(
          SipIdReq(mode: SipIdRequestMode.basic),
        );
        final reqFrame = SipFrame(
          versionMajor: SipConstants.sipVersionMajor,
          versionMinor: SipConstants.sipVersionMinor,
          msgType: SipMessageType.idReq,
          flags: 0,
          headerLen: SipConstants.sipWrapperMin,
          sessionId: 0,
          nonce: SipCodec.generateNonce(),
          timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          payloadLen: reqPayload.length,
          payload: reqPayload,
        );
        final result = await handler.handleInboundReq(
          frame: reqFrame,
          senderNodeId: 0xBBBB,
        );
        expect(result, isNotNull);
      },
    );
  });

  // =========================================================================
  // Discoverable → MrrpAdvertEngine
  // =========================================================================
  group('Discoverable → MrrpAdvertEngine', () {
    late MrrpServiceRegistry registry;
    late MrrpAdvertEngine engine;

    setUp(() {
      registry = MrrpServiceRegistry();
      final handler = _TestHandler(serviceId: MrrpServiceId.echoTest);
      registry.register(
        handler,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
        ),
      );
      engine = MrrpAdvertEngine(registry: registry, random: Random(42));
    });

    test('SERVICE_DIR_REQ returns null when isAdvertisingEnabled=false', () {
      expect(engine.isAdvertisingEnabled, isFalse);
      final req = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.serviceDirReq,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final resp = engine.handleServiceDirReq(req, 0xBBBB);
      expect(resp, isNull);
    });

    test('SERVICE_DIR_REQ returns response when isAdvertisingEnabled=true', () {
      engine.isAdvertisingEnabled = true;
      final req = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.serviceDirReq,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final resp = engine.handleServiceDirReq(req, 0xBBBB);
      expect(resp, isNotNull);
      expect(resp!.msgType, MrrpMessageType.serviceDirResp);
    });

    test('broadcastNow suppressed when isAdvertisingEnabled=false', () async {
      var sent = false;
      engine.onSend = (_) async {
        sent = true;
        return true;
      };
      engine.start();

      expect(engine.isAdvertisingEnabled, isFalse);
      await engine.broadcastNow();
      expect(sent, isFalse);

      engine.stop();
    });

    test('broadcastNow sends when isAdvertisingEnabled=true', () async {
      var sent = false;
      engine.onSend = (_) async {
        sent = true;
        return true;
      };
      engine.isAdvertisingEnabled = true;
      engine.start();

      await engine.broadcastNow();
      expect(sent, isTrue);

      engine.stop();
    });
  });

  // =========================================================================
  // Discoverable → MrrpEngine (inbound REQUEST gate)
  // =========================================================================
  group('Discoverable → MrrpEngine (inbound REQUEST)', () {
    late MrrpServiceRegistry registry;
    late MrrpAdvertEngine advertEngine;
    late MrrpDispatcher dispatcher;
    late MrrpDedupCache dedupCache;
    late MrrpEngine engine;
    late List<Uint8List> sentFrames;

    setUp(() {
      registry = MrrpServiceRegistry();
      final handler = _TestHandler(serviceId: MrrpServiceId.echoTest);
      registry.register(
        handler,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
        ),
      );

      advertEngine = MrrpAdvertEngine(registry: registry, random: Random(42));
      dispatcher = MrrpDispatcher(registry: registry);
      dedupCache = MrrpDedupCache();
      sentFrames = [];

      Future<bool> onSend(Uint8List payload) async {
        sentFrames.add(payload);
        return true;
      }

      dispatcher.onSend = onSend;
      advertEngine.onSend = onSend;

      engine = MrrpEngine(
        registry: registry,
        advertEngine: advertEngine,
        dispatcher: dispatcher,
        dedupCache: dedupCache,
        onSend: onSend,
      );
      engine.start();
    });

    tearDown(() {
      engine.dispose();
    });

    /// Encode a valid MRRP REQUEST targeting echo.test as wire bytes.
    Uint8List buildRequestPayload() {
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 42,
        serviceId: MrrpServiceId.echoTest,
        actionId: 1,
        payloadLen: 1,
        payload: Uint8List.fromList([0xAB]),
      );
      return MrrpCodec.encode(frame)!;
    }

    test(
      'inbound REQUEST dropped when isServicingEnabled=false (default)',
      () async {
        expect(engine.isServicingEnabled, isFalse);
        engine.handleInboundFrame(0xBBBB, buildRequestPayload());
        // Give async handler a chance to run.
        await Future<void>.delayed(Duration.zero);
        expect(sentFrames, isEmpty);
      },
    );

    test('inbound REQUEST dispatched when isServicingEnabled=true', () async {
      engine.isServicingEnabled = true;
      engine.handleInboundFrame(0xBBBB, buildRequestPayload());
      await Future<void>.delayed(Duration.zero);
      // Dispatcher routes to _TestHandler which builds a response.
      expect(sentFrames, isNotEmpty);
    });

    test('toggle isServicingEnabled: off→on→off', () async {
      final payload = buildRequestPayload();

      // Off — dropped.
      engine.handleInboundFrame(0xCC01, payload);
      await Future<void>.delayed(Duration.zero);
      expect(sentFrames, isEmpty);

      // On — dispatched (use different sender+reqId to avoid dedup).
      engine.isServicingEnabled = true;
      final payload2 = MrrpCodec.encode(
        MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 43,
          serviceId: MrrpServiceId.echoTest,
          actionId: 1,
          payloadLen: 1,
          payload: Uint8List.fromList([0xAB]),
        ),
      )!;
      engine.handleInboundFrame(0xCC02, payload2);
      await Future<void>.delayed(Duration.zero);
      expect(sentFrames, hasLength(1));

      // Off again — dropped.
      engine.isServicingEnabled = false;
      sentFrames.clear();
      final payload3 = MrrpCodec.encode(
        MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 44,
          serviceId: MrrpServiceId.echoTest,
          actionId: 1,
          payloadLen: 1,
          payload: Uint8List.fromList([0xAB]),
        ),
      )!;
      engine.handleInboundFrame(0xCC03, payload3);
      await Future<void>.delayed(Duration.zero);
      expect(sentFrames, isEmpty);
    });
  });

  // =========================================================================
  // Profile Sharing → MrrpServiceProfile
  // =========================================================================
  group('Profile Sharing → MrrpServiceProfile', () {
    late MrrpServiceProfile service;

    setUp(() {
      service = MrrpServiceProfile(
        configProvider: () => const MrrpProfileConfig(
          displayName: 'Test', // lint-allow: hardcoded-string
          statusText: 'Online', // lint-allow: hardcoded-string
        ),
      );
    });

    MrrpFrame buildProfileRequest(int actionId) {
      return MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 99,
        serviceId: MrrpServiceId.profileV1,
        actionId: actionId,
        payloadLen: 0,
        payload: Uint8List(0),
      );
    }

    test('isProfileSharingEnabled defaults to false', () {
      expect(service.isProfileSharingEnabled, isFalse);
    });

    test('get_summary rejected when isProfileSharingEnabled=false', () async {
      final resp = await service.handleRequest(
        buildProfileRequest(ProfileAction.getSummary),
        0xBBBB,
      );
      expect(resp.msgType, MrrpMessageType.error);
      final status = MrrpStatusCode.fromCode(resp.payload[0]);
      expect(status, MrrpStatusCode.unauthorized);
    });

    test('get_summary succeeds when isProfileSharingEnabled=true', () async {
      service.isProfileSharingEnabled = true;
      final resp = await service.handleRequest(
        buildProfileRequest(ProfileAction.getSummary),
        0xBBBB,
      );
      expect(resp.msgType, MrrpMessageType.response);
    });

    test(
      'get_contact_card rejected when isProfileSharingEnabled=false',
      () async {
        final resp = await service.handleRequest(
          buildProfileRequest(ProfileAction.getContactCard),
          0xBBBB,
        );
        expect(resp.msgType, MrrpMessageType.error);
      },
    );

    test(
      'get_capabilities rejected when isProfileSharingEnabled=false',
      () async {
        final resp = await service.handleRequest(
          buildProfileRequest(ProfileAction.getCapabilities),
          0xBBBB,
        );
        expect(resp.msgType, MrrpMessageType.error);
      },
    );

    test('toggle profile sharing: off→on→off', () async {
      final req = buildProfileRequest(ProfileAction.getSummary);

      // Off — rejected.
      final r1 = await service.handleRequest(req, 0xBBBB);
      expect(r1.msgType, MrrpMessageType.error);

      // On — succeeds.
      service.isProfileSharingEnabled = true;
      final r2 = await service.handleRequest(req, 0xBBBB);
      expect(r2.msgType, MrrpMessageType.response);

      // Off again — rejected.
      service.isProfileSharingEnabled = false;
      final r3 = await service.handleRequest(req, 0xBBBB);
      expect(r3.msgType, MrrpMessageType.error);
    });
  });
}
