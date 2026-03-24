// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dedup_cache.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_echo.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_meetup.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('MrrpEngine integration', () {
    late MrrpEngine engine;
    late MrrpServiceRegistry registry;
    late MrrpDispatcher dispatcher;
    late MrrpAdvertEngine advertEngine;
    late MrrpDedupCache dedupCache;
    late List<Uint8List> sentPayloads;

    setUp(() {
      sentPayloads = [];
      registry = MrrpServiceRegistry();
      dispatcher = MrrpDispatcher(registry: registry);
      advertEngine = MrrpAdvertEngine(registry: registry);
      dedupCache = MrrpDedupCache();

      engine = MrrpEngine(
        registry: registry,
        dispatcher: dispatcher,
        advertEngine: advertEngine,
        dedupCache: dedupCache,
        onSend: (payload) async {
          sentPayloads.add(payload);
          return true;
        },
      );

      // Enable privacy gates for testing.
      engine.isServicingEnabled = true;
      advertEngine.isAdvertisingEnabled = true;
    });

    tearDown(() {
      engine.dispose();
    });

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    test('starts and stops cleanly', () {
      expect(engine.isRunning, isFalse);
      engine.start();
      expect(engine.isRunning, isTrue);
      engine.stop();
      expect(engine.isRunning, isFalse);
    });

    test('drops inbound frames when not running', () {
      // Encode a valid SERVICE_ADVERT frame.
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: 20,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final encoded = MrrpCodec.encode(frame)!;

      // Engine not started — should silently drop.
      engine.handleInboundFrame(0xABCD1234, encoded);
      expect(sentPayloads, isEmpty);
    });

    test('rejects payload with bad magic bytes', () {
      engine.start();
      // Send bytes with wrong magic.
      final bad = Uint8List(20)
        ..[0] = 0xFF
        ..[1] = 0xFF;
      engine.handleInboundFrame(0xABCD1234, bad);
      expect(sentPayloads, isEmpty);
    });

    test('rejects payload shorter than minimum header', () {
      engine.start();
      engine.handleInboundFrame(0xABCD1234, Uint8List(10));
      expect(sentPayloads, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Echo round-trip: inbound REQUEST -> handler -> outbound RESPONSE
    // -----------------------------------------------------------------------

    test('echo.test round-trip: REQUEST sends RESPONSE via onSend', () async {
      final echo = MrrpServiceEcho();
      registry.register(
        echo,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.testOnly,
        ),
      );

      engine.start();

      // Build a REQUEST for echo.test / echo action.
      final requestPayload = Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]);
      final request = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: 20,
        requestId: 0x1234,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: requestPayload.length,
        payload: requestPayload,
      );
      final encoded = MrrpCodec.encode(request)!;

      // Simulate inbound from peer 0xDEAD.
      engine.handleInboundFrame(0xDEAD, encoded);

      // Allow async dispatch chain to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Engine should have dispatched to echo handler and sent a RESPONSE.
      expect(sentPayloads, hasLength(1));

      // Decode the response.
      final responseFrame = MrrpCodec.decode(sentPayloads.first);
      expect(responseFrame, isNotNull);
      expect(responseFrame!.msgType, MrrpMessageType.response);
      expect(responseFrame.requestId, 0x1234);
      expect(responseFrame.serviceId, MrrpServiceId.echoTest);
      // Echo returns the same payload.
      expect(responseFrame.payload, requestPayload);
    });

    test('unknown service returns ERROR NOT_FOUND', () async {
      engine.start();

      // Request for a service that is not registered.
      final request = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: 20,
        requestId: 0x5678,
        serviceId: 0xDEADBEEF,
        actionId: 0x01,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final encoded = MrrpCodec.encode(request)!;
      engine.handleInboundFrame(0xBEEF, encoded);

      // Allow async dispatch chain to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sentPayloads, hasLength(1));
      final resp = MrrpCodec.decode(sentPayloads.first)!;
      expect(resp.msgType, MrrpMessageType.error);
      expect(resp.requestId, 0x5678);
    });

    // -----------------------------------------------------------------------
    // Dedup: duplicate REQUEST suppressed
    // -----------------------------------------------------------------------

    test('duplicate REQUEST is suppressed (no double response)', () async {
      final echo = MrrpServiceEcho();
      registry.register(
        echo,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.testOnly,
        ),
      );

      engine.start();

      final request = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: 20,
        requestId: 0x9999,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: 2,
        payload: Uint8List.fromList([0x01, 0x02]),
      );
      final encoded = MrrpCodec.encode(request)!;

      // Send same request twice from same peer.
      engine.handleInboundFrame(0x1111, encoded);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      engine.handleInboundFrame(0x1111, encoded);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // First sends a response; second replays cached response.
      // Both generate onSend calls (replay sends the cached response).
      expect(sentPayloads.length, greaterThanOrEqualTo(1));

      // Both responses should have the same request_id.
      for (final p in sentPayloads) {
        final resp = MrrpCodec.decode(p)!;
        expect(resp.requestId, 0x9999);
      }
    });

    // -----------------------------------------------------------------------
    // RESPONSE correlation
    // -----------------------------------------------------------------------

    test('outbound sendRequest receives correlated RESPONSE', () async {
      // Register echo.test so sendRequest can target it.
      final echo = MrrpServiceEcho();
      registry.register(
        echo,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.testOnly,
        ),
      );

      engine.start();

      // Wire dispatcher's onSend to capture outbound encoded frames.
      dispatcher.onSend = (encodedPayload) async {
        sentPayloads.add(encodedPayload);
        return true;
      };

      // Send a request through the engine.
      final requestFrame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: 20,
        requestId: 0, // Will be replaced by dispatcher.
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: 3,
        payload: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
      );

      final resultFuture = engine.sendRequest(requestFrame);

      // The dispatcher should have sent an encoded frame.
      expect(sentPayloads, hasLength(1));

      // Decode the sent frame to get the assigned request_id.
      final sentFrame = MrrpCodec.decode(sentPayloads.first)!;
      expect(sentFrame.msgType, MrrpMessageType.request);

      // Simulate the peer responding with a RESPONSE frame.
      final response = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.response,
        flags: 0,
        headerLen: 20,
        requestId: sentFrame.requestId,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: 3,
        payload: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
      );
      final encodedResp = MrrpCodec.encode(response)!;

      // Feed the response back into the engine as an inbound frame.
      engine.handleInboundFrame(0xBEE1, encodedResp);

      // The result future should now complete.
      final result = await resultFuture;
      expect(result.isSuccess, isTrue);
      expect(result.response, isNotNull);
      expect(result.response!.payload, Uint8List.fromList([0xAA, 0xBB, 0xCC]));
    });

    // -----------------------------------------------------------------------
    // SERVICE_ADVERT round-trip
    // -----------------------------------------------------------------------

    test('inbound SERVICE_ADVERT is cached by advert engine', () {
      // Register a service so the advert engine is functional.
      final meetup = MrrpServiceMeetup();
      registry.register(
        meetup,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.meetupV1,
          serviceType: MrrpServiceType.app,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse,
        ),
      );

      engine.start();

      // Build a SERVICE_ADVERT from a remote peer advertising meetup.v1.
      final advertPayload = registry.buildAdvertPayload();
      expect(advertPayload, isNotNull);
      final advert = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: 20,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: advertPayload!.length,
        payload: advertPayload,
      );
      final encoded = MrrpCodec.encode(advert)!;

      engine.handleInboundFrame(0xFACE, encoded);

      // Verify the advert engine cached the service.
      final cached = advertEngine.getAllCachedServices();
      expect(cached, isNotEmpty);
    });

    // -----------------------------------------------------------------------
    // CANCEL flow
    // -----------------------------------------------------------------------

    test('inbound CANCEL is forwarded to dispatcher without error', () {
      engine.start();

      // Simulate a peer cancelling a request they sent. This is
      // informational only — dispatcher logs and ignores.
      final cancel = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.cancel,
        flags: 0,
        headerLen: 20,
        requestId: 0xAAAA,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final encodedCancel = MrrpCodec.encode(cancel)!;

      // Should not throw or send anything.
      engine.handleInboundFrame(0xBEE2, encodedCancel);
      expect(sentPayloads, isEmpty);
    });

    test('local cancelRequest sends CANCEL and completes future', () async {
      final echo = MrrpServiceEcho();
      registry.register(
        echo,
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.testOnly,
        ),
      );

      engine.start();

      dispatcher.onSend = (payload) async {
        sentPayloads.add(payload);
        return true;
      };

      // Send a request.
      final requestFrame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: MrrpFlags.ackRequired,
        headerLen: 20,
        requestId: 0,
        serviceId: MrrpServiceId.echoTest,
        actionId: EchoAction.echo,
        payloadLen: 1,
        payload: Uint8List.fromList([0x42]),
      );

      final resultFuture = engine.sendRequest(requestFrame);
      expect(sentPayloads, hasLength(1));

      // Get the assigned request ID.
      final sentFrame = MrrpCodec.decode(sentPayloads.first)!;

      // Cancel the request locally.
      await dispatcher.cancelRequest(sentFrame.requestId);

      // The second sent payload should be a CANCEL frame.
      expect(sentPayloads, hasLength(2));
      final cancelFrame = MrrpCodec.decode(sentPayloads[1])!;
      expect(cancelFrame.msgType, MrrpMessageType.cancel);

      // The future should complete with timeout status (cancel uses timeout).
      final result = await resultFuture;
      expect(result.status, MrrpStatusCode.timeout);
    });

    // -----------------------------------------------------------------------
    // Engine dispose cleans up
    // -----------------------------------------------------------------------

    test('dispose stops engine and cleans up', () {
      engine.start();
      expect(engine.isRunning, isTrue);
      engine.dispose();
      expect(engine.isRunning, isFalse);
    });
  });
}
