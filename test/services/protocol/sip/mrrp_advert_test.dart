// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_handler.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

/// Minimal test handler for registry tests.
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

MrrpServiceDescriptor _descriptor(int serviceId, {MrrpServiceType? type}) {
  return MrrpServiceDescriptor(
    serviceId: serviceId,
    serviceType: type ?? MrrpServiceType.app,
  );
}

void main() {
  group('MrrpServiceRegistry', () {
    late MrrpServiceRegistry registry;

    setUp(() {
      registry = MrrpServiceRegistry();
    });

    test('register and getAll', () {
      final handler = _TestHandler(serviceId: MrrpServiceId.echoTest);
      final ok = registry.register(
        handler,
        _descriptor(MrrpServiceId.echoTest, type: MrrpServiceType.test),
      );
      expect(ok, isTrue);
      expect(registry.count, 1);
      expect(registry.getAll().first.serviceId, MrrpServiceId.echoTest);
    });

    test('register rejects beyond max services', () {
      for (var i = 0; i < MrrpConstants.mrrpServiceAdvertMaxServices; i++) {
        final ok = registry.register(
          _TestHandler(serviceId: i + 1),
          _descriptor(i + 1),
        );
        expect(ok, isTrue);
      }
      expect(registry.count, MrrpConstants.mrrpServiceAdvertMaxServices);

      final rejected = registry.register(
        _TestHandler(serviceId: 999),
        _descriptor(999),
      );
      expect(rejected, isFalse);
    });

    test('unregister removes service', () {
      registry.register(
        _TestHandler(serviceId: MrrpServiceId.echoTest),
        _descriptor(MrrpServiceId.echoTest),
      );
      expect(registry.count, 1);
      registry.unregister(MrrpServiceId.echoTest);
      expect(registry.count, 0);
    });

    test('getHandler finds registered handler', () {
      final handler = _TestHandler(serviceId: MrrpServiceId.meetupV1);
      registry.register(handler, _descriptor(MrrpServiceId.meetupV1));
      expect(registry.getHandler(MrrpServiceId.meetupV1), same(handler));
      expect(registry.getHandler(MrrpServiceId.echoTest), isNull);
    });

    test('buildAdvertPayload returns valid payload', () {
      registry.register(
        _TestHandler(serviceId: MrrpServiceId.meetupV1),
        _descriptor(MrrpServiceId.meetupV1),
      );
      registry.register(
        _TestHandler(serviceId: MrrpServiceId.echoTest),
        _descriptor(MrrpServiceId.echoTest, type: MrrpServiceType.test),
      );

      final payload = registry.buildAdvertPayload();
      expect(payload, isNotNull);
      expect(payload![0], 2); // service_count

      // Decode and verify
      final decoded = MrrpMessagesAdvert.decodeAdvertPayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.length, 2);
    });

    test('buildAdvertPayload returns null when empty', () {
      expect(registry.buildAdvertPayload(), isNull);
    });
  });

  group('MrrpMessagesAdvert', () {
    test('decodeAdvertPayload handles empty payload', () {
      expect(MrrpMessagesAdvert.decodeAdvertPayload(Uint8List(0)), isNull);
    });

    test('decodeAdvertPayload handles zero services', () {
      final result = MrrpMessagesAdvert.decodeAdvertPayload(
        Uint8List.fromList([0]),
      );
      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
    });

    test('decodeAdvertPayload rejects truncated descriptor', () {
      // Count says 1 service but only 5 bytes follow
      expect(
        MrrpMessagesAdvert.decodeAdvertPayload(
          Uint8List.fromList([1, 0, 0, 0, 0, 0]),
        ),
        isNull,
      );
    });

    test('decodeAdvertPayload rejects count > max', () {
      final data = Uint8List.fromList([
        MrrpConstants.mrrpServiceAdvertMaxServices + 1,
      ]);
      expect(MrrpMessagesAdvert.decodeAdvertPayload(data), isNull);
    });

    test('encodeDirectoryResponse round-trips with decode', () {
      final descriptors = [
        MrrpAdvertDescriptor(
          serviceId: MrrpServiceId.meetupV1,
          serviceType: MrrpServiceType.app,
          versionMajor: 0,
          versionMinor: 1,
          serviceFlags: MrrpServiceFlags.supportsRequest,
          metadata: Uint8List(0),
        ),
        MrrpAdvertDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          versionMajor: 0,
          versionMinor: 1,
          serviceFlags:
              MrrpServiceFlags.supportsRequest | MrrpServiceFlags.testOnly,
          metadata: Uint8List(0),
        ),
      ];

      final encoded = MrrpMessagesAdvert.encodeDirectoryResponse(descriptors);
      expect(encoded, isNotNull);

      final decoded = MrrpMessagesAdvert.decodeAdvertPayload(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.length, 2);
      expect(decoded[0].serviceId, MrrpServiceId.meetupV1);
      expect(decoded[1].serviceId, MrrpServiceId.echoTest);
      expect(decoded[1].serviceType, MrrpServiceType.test);
    });

    test('encodeDirectoryResponse with metadata round-trips', () {
      final meta = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final descriptors = [
        MrrpAdvertDescriptor(
          serviceId: MrrpServiceId.boardV1,
          serviceType: MrrpServiceType.app,
          versionMajor: 0,
          versionMinor: 1,
          serviceFlags: 0,
          metadata: meta,
        ),
      ];

      final encoded = MrrpMessagesAdvert.encodeDirectoryResponse(descriptors);
      expect(encoded, isNotNull);

      final decoded = MrrpMessagesAdvert.decodeAdvertPayload(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.first.metadata, orderedEquals(meta));
    });
  });

  group('MrrpAdvertEngine', () {
    late MrrpServiceRegistry registry;
    late MrrpAdvertEngine engine;

    setUp(() {
      registry = MrrpServiceRegistry();
      engine = MrrpAdvertEngine(registry: registry, random: Random(42));
      engine.isAdvertisingEnabled = true;
    });

    tearDown(() {
      engine.dispose();
    });

    test('handleServiceAdvert caches services', () {
      final payload = Uint8List.fromList([
        1, // count
        // descriptor: meetupV1
        0x01, 0x00, 0x00, 0x00, // service_id
        0x00, // service_type=app
        0x00, 0x01, // version 0.1
        0x04, 0x00, // flags=supportsRequest
        0x00, // metadata_len=0
      ]);

      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        payload: payload,
      );

      engine.handleServiceAdvert(frame, 0xABCD1234);

      final cached = engine.getServicesForPeer(0xABCD1234);
      expect(cached.length, 1);
      expect(cached.first.descriptor.serviceId, MrrpServiceId.meetupV1);
    });

    test('handleServiceAdvert deduplicates identical payloads', () {
      var cacheChanges = 0;
      engine.onCacheChanged = () => cacheChanges++;

      final payload = Uint8List.fromList([
        1,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
        0x04,
        0x00,
        0x00,
      ]);

      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        payload: payload,
      );

      engine.handleServiceAdvert(frame, 0x1111);
      expect(cacheChanges, 1);

      // Same payload again — dedup should skip.
      engine.handleServiceAdvert(frame, 0x1111);
      expect(cacheChanges, 1); // unchanged
    });

    test('max tracked peers enforced by eviction', () {
      final payload = Uint8List.fromList([
        1,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
        0x04,
        0x00,
        0x00,
      ]);

      for (var i = 0; i < MrrpConstants.mrrpMaxTrackedPeers; i++) {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.serviceAdvert,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0,
          serviceId: 0,
          actionId: 0,
          payloadLen: payload.length,
          payload: payload,
        );
        engine.handleServiceAdvert(frame, 0x1000 + i);
      }

      expect(engine.trackedPeerCount, MrrpConstants.mrrpMaxTrackedPeers);

      // One more peer triggers eviction.
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        payload: payload,
      );
      engine.handleServiceAdvert(frame, 0x9999);

      expect(engine.trackedPeerCount, MrrpConstants.mrrpMaxTrackedPeers);
    });

    test('handleServiceDirReq returns SERVICE_DIR_RESP', () {
      registry.register(
        _TestHandler(serviceId: MrrpServiceId.echoTest),
        _descriptor(MrrpServiceId.echoTest, type: MrrpServiceType.test),
      );

      final req = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceDirReq,
        flags: MrrpFlags.ackRequired,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0x42,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        payload: Uint8List(0),
      );

      final resp = engine.handleServiceDirReq(req, 0xABCD);
      expect(resp, isNotNull);
      expect(resp!.msgType, MrrpMessageType.serviceDirResp);
      expect(resp.requestId, 0x42);
      expect(resp.isResponse, isTrue);

      final decoded = MrrpMessagesAdvert.decodeAdvertPayload(resp.payload);
      expect(decoded, isNotNull);
      expect(decoded!.length, 1);
      expect(decoded.first.serviceId, MrrpServiceId.echoTest);
    });

    test('handleServiceDirResp caches services', () {
      final payload = Uint8List.fromList([
        2,
        // meetup.v1
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x04, 0x00, 0x00,
        // profile.v1
        0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x06, 0x00, 0x00,
      ]);

      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceDirResp,
        flags: MrrpFlags.isResponse,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        payload: payload,
      );

      engine.handleServiceDirResp(frame, 0xBEEF);
      final cached = engine.getServicesForPeer(0xBEEF);
      expect(cached.length, 2);
    });

    test('getAllCachedServices returns grouped services', () {
      final payload = Uint8List.fromList([
        1,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
        0x04,
        0x00,
        0x00,
      ]);

      for (final nodeId in [0xAAAA, 0xBBBB]) {
        final frame = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.serviceAdvert,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 0,
          serviceId: 0,
          actionId: 0,
          payloadLen: payload.length,
          payload: payload,
        );
        engine.handleServiceAdvert(frame, nodeId);
      }

      final all = engine.getAllCachedServices();
      expect(all.length, 2);
      expect(all[0xAAAA]!.length, 1);
      expect(all[0xBBBB]!.length, 1);
    });
  });
}
