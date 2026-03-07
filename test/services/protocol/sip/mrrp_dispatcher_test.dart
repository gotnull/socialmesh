// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_handler.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

/// Echo handler that returns the request payload as-is.
class _EchoHandler implements MrrpServiceHandler {
  @override
  int get serviceId => MrrpServiceId.echoTest;

  @override
  Set<int> get supportedActions => {EchoAction.echo, EchoAction.echoError};

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    if (request.actionId == EchoAction.echoError) {
      return MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.error,
        flags: MrrpFlags.isResponse | MrrpFlags.isError,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: request.requestId,
        serviceId: request.serviceId,
        actionId: request.actionId,
        payloadLen: 0,
        payload: Uint8List(0),
      );
    }
    return MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: request.payload.length,
      payload: request.payload,
    );
  }
}

MrrpServiceDescriptor _echoDescriptor() => MrrpServiceDescriptor(
  serviceId: MrrpServiceId.echoTest,
  serviceType: MrrpServiceType.test,
);

MrrpFrame _makeRequest({
  int requestId = 1,
  int serviceId = 0xFFFF0001,
  int actionId = EchoAction.echo,
  Uint8List? payload,
}) {
  final p = payload ?? Uint8List.fromList([0xDE, 0xAD]);
  return MrrpFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: MrrpMessageType.request,
    flags: MrrpFlags.ackRequired,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: requestId,
    serviceId: serviceId,
    actionId: actionId,
    payloadLen: p.length,
    payload: p,
  );
}

void main() {
  group('MrrpDispatcher', () {
    late MrrpServiceRegistry registry;
    late MrrpDispatcher dispatcher;
    final sentFrames = <Uint8List>[];

    setUp(() {
      sentFrames.clear();
      registry = MrrpServiceRegistry();
      dispatcher = MrrpDispatcher(registry: registry);
      dispatcher.onSend = (payload) async {
        sentFrames.add(payload);
        return true;
      };
    });

    tearDown(() {
      dispatcher.dispose();
    });

    group('inbound dispatch', () {
      test('routes REQUEST to registered handler', () async {
        registry.register(_EchoHandler(), _echoDescriptor());

        final request = _makeRequest();
        final response = await dispatcher.dispatch(request, 0xABCD);

        expect(response.msgType, MrrpMessageType.response);
        expect(response.requestId, request.requestId);
        expect(response.payload, orderedEquals([0xDE, 0xAD]));
      });

      test('returns NOT_FOUND for unknown service', () async {
        // No handlers registered.
        final request = _makeRequest(serviceId: 0xDEAD0000);
        final response = await dispatcher.dispatch(request, 0xABCD);

        expect(response.msgType, MrrpMessageType.error);
        expect(response.isError, isTrue);
        final statusTlv = response.findExtension(MrrpTlvType.statusCode);
        expect(statusTlv, isNotNull);
        expect(statusTlv!.value[0], MrrpStatusCode.notFound.code);
      });

      test('returns UNSUPPORTED for unknown action', () async {
        registry.register(_EchoHandler(), _echoDescriptor());

        final request = _makeRequest(
          serviceId: MrrpServiceId.echoTest,
          actionId: 0xFF, // not in supportedActions
        );
        final response = await dispatcher.dispatch(request, 0xABCD);

        expect(response.msgType, MrrpMessageType.error);
        final statusTlv = response.findExtension(MrrpTlvType.statusCode);
        expect(statusTlv!.value[0], MrrpStatusCode.unsupported.code);
      });

      test('handler error returns INTERNAL', () async {
        final badHandler = _ThrowingHandler();
        registry.register(
          badHandler,
          MrrpServiceDescriptor(
            serviceId: badHandler.serviceId,
            serviceType: MrrpServiceType.test,
          ),
        );

        final request = _makeRequest(serviceId: badHandler.serviceId);
        final response = await dispatcher.dispatch(request, 0xABCD);

        expect(response.msgType, MrrpMessageType.error);
        final statusTlv = response.findExtension(MrrpTlvType.statusCode);
        expect(statusTlv!.value[0], MrrpStatusCode.internal.code);
      });
    });

    group('outbound sendRequest', () {
      test('sends REQUEST and resolves on RESPONSE', () async {
        final future = dispatcher.sendRequest(
          _makeRequest(serviceId: MrrpServiceId.echoTest),
        );

        expect(sentFrames.length, 1);

        // Simulate a RESPONSE arriving.
        dispatcher.handleResponse(
          MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.response,
            flags: MrrpFlags.isResponse,
            headerLen: MrrpConstants.mrrpHeaderMin,
            requestId: 1, // matches allocated ID
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 2,
            payload: Uint8List.fromList([0xBE, 0xEF]),
          ),
        );

        final result = await future;
        expect(result.isSuccess, isTrue);
        expect(result.response, isNotNull);
        expect(result.response!.payload, orderedEquals([0xBE, 0xEF]));
        expect(result.latency, isNotNull);
      });

      test('rejects when max pending reached', () async {
        // Fill up pending slots.
        for (var i = 0; i < MrrpConstants.mrrpMaxPendingRequests; i++) {
          // ignore: unawaited_futures
          dispatcher.sendRequest(
            _makeRequest(serviceId: MrrpServiceId.echoTest),
          );
        }

        expect(dispatcher.pendingCount, MrrpConstants.mrrpMaxPendingRequests);

        final result = await dispatcher.sendRequest(
          _makeRequest(serviceId: MrrpServiceId.echoTest),
        );
        expect(result.status, MrrpStatusCode.busy);
      });

      test('stale RESPONSE dropped silently', () {
        // No pending requests.
        dispatcher.handleResponse(
          MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.response,
            flags: MrrpFlags.isResponse,
            headerLen: MrrpConstants.mrrpHeaderMin,
            requestId: 0x9999,
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 0,
            payload: Uint8List(0),
          ),
        );
        // No exception thrown — stale frame silently dropped.
      });

      test('ERROR response correlates with correct status', () async {
        final future = dispatcher.sendRequest(
          _makeRequest(serviceId: MrrpServiceId.echoTest),
        );

        dispatcher.handleResponse(
          MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.error,
            flags: MrrpFlags.isResponse | MrrpFlags.isError,
            headerLen: MrrpConstants.mrrpHeaderMin + 3,
            requestId: 1,
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 0,
            headerExtensions: [
              MrrpTlvEntry(
                type: MrrpTlvType.statusCode.code,
                value: Uint8List.fromList([MrrpStatusCode.notFound.code]),
              ),
            ],
            payload: Uint8List(0),
          ),
        );

        final result = await future;
        expect(result.status, MrrpStatusCode.notFound);
      });
    });

    group('cancel', () {
      test('cancelRequest sends CANCEL and resolves pending', () async {
        final future = dispatcher.sendRequest(
          _makeRequest(serviceId: MrrpServiceId.echoTest),
        );

        expect(dispatcher.pendingCount, 1);
        await dispatcher.cancelRequest(1);

        expect(dispatcher.pendingCount, 0);
        // CANCEL frame sent.
        expect(sentFrames.length, 2); // REQUEST + CANCEL

        final result = await future;
        expect(result.status, MrrpStatusCode.timeout);
      });

      test('RESPONSE after CANCEL is dropped', () async {
        final future = dispatcher.sendRequest(
          _makeRequest(serviceId: MrrpServiceId.echoTest),
        );

        await dispatcher.cancelRequest(1);
        final result = await future;
        expect(result.status, MrrpStatusCode.timeout);

        // Late RESPONSE should be silently dropped (no crash).
        dispatcher.handleResponse(
          MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.response,
            flags: MrrpFlags.isResponse,
            headerLen: MrrpConstants.mrrpHeaderMin,
            requestId: 1,
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 0,
            payload: Uint8List(0),
          ),
        );
      });
    });

    group('handleInboundCancel', () {
      test('logs inbound CANCEL without error', () {
        dispatcher.handleInboundCancel(
          MrrpFrame(
            versionMajor: 0,
            versionMinor: 1,
            msgType: MrrpMessageType.cancel,
            flags: 0,
            headerLen: MrrpConstants.mrrpHeaderMin,
            requestId: 42,
            serviceId: MrrpServiceId.echoTest,
            actionId: EchoAction.echo,
            payloadLen: 0,
            payload: Uint8List(0),
          ),
        );
      });
    });

    group('dispose', () {
      test('disposes all pending with timeout', () async {
        final futures = <Future<MrrpRequestResult>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(
            dispatcher.sendRequest(
              _makeRequest(serviceId: MrrpServiceId.echoTest),
            ),
          );
        }

        dispatcher.dispose();

        for (final f in futures) {
          final result = await f;
          expect(result.status, MrrpStatusCode.timeout);
        }
      });
    });
  });
}

/// Handler that always throws to test error handling.
class _ThrowingHandler implements MrrpServiceHandler {
  @override
  int get serviceId => 0x12345678;

  @override
  Set<int> get supportedActions => {EchoAction.echo};

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    throw Exception('test handler error'); // lint-allow: hardcoded-string
  }
}
