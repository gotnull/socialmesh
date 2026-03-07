// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_handler.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

/// Echo handler that returns the request payload.
class _EchoHandler implements MrrpServiceHandler {
  @override
  int get serviceId => MrrpServiceId.echoTest;

  @override
  Set<int> get supportedActions => {EchoAction.echo};

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
      payloadLen: request.payload.length,
      payload: request.payload,
    );
  }
}

MrrpFrame _makeRequest({
  int requestId = 1,
  int serviceId = 0xFFFF0001,
  int actionId = EchoAction.echo,
}) {
  final p = Uint8List.fromList([0x01, 0x02]);
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
  group('MrrpDispatcher timeout handling', () {
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
      registry.register(
        _EchoHandler(),
        MrrpServiceDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
        ),
      );
    });

    tearDown(() {
      dispatcher.dispose();
    });

    test('request times out after mrrpRequestTimeout', () {
      fakeAsync((async) {
        MrrpRequestResult? result;
        dispatcher
            .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
            .then((r) => result = r);

        // Verify request was sent.
        expect(sentFrames.length, 1);
        expect(dispatcher.pendingCount, 1);

        // Advance to just before timeout — should still be pending.
        async.elapse(
          MrrpConstants.mrrpRequestTimeout - const Duration(seconds: 1),
        );
        expect(result, isNull);
        expect(dispatcher.pendingCount, 1);

        // Advance past timeout.
        async.elapse(const Duration(seconds: 2));
        expect(result, isNotNull);
        expect(result!.status, MrrpStatusCode.timeout);
        expect(dispatcher.pendingCount, 0);
      });
    });

    test('multiple pending requests each time out independently', () {
      fakeAsync((async) {
        final results = <int, MrrpRequestResult?>{};

        for (var i = 1; i <= 3; i++) {
          dispatcher
              .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
              .then((r) => results[i] = r);
        }

        expect(dispatcher.pendingCount, 3);

        // Advance past timeout.
        async.elapse(
          MrrpConstants.mrrpRequestTimeout + const Duration(seconds: 1),
        );

        expect(results.length, 3);
        for (final r in results.values) {
          expect(r!.status, MrrpStatusCode.timeout);
        }
        expect(dispatcher.pendingCount, 0);
      });
    });

    test('response before timeout cancels timeout timer', () {
      fakeAsync((async) {
        MrrpRequestResult? result;
        dispatcher
            .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
            .then((r) => result = r);

        // Simulate response arriving before timeout.
        async.elapse(const Duration(seconds: 5));

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
            payloadLen: 2,
            payload: Uint8List.fromList([0x01, 0x02]),
          ),
        );

        // Flush microtasks so the .then() callback runs.
        async.flushMicrotasks();

        expect(result, isNotNull);
        expect(result!.isSuccess, isTrue);
        expect(dispatcher.pendingCount, 0);

        // Advance past what would have been the timeout.
        async.elapse(MrrpConstants.mrrpRequestTimeout);
        // No additional timeout fires; still success.
        expect(result!.isSuccess, isTrue);
      });
    });

    test('cancel before timeout resolves with timeout status', () {
      fakeAsync((async) {
        MrrpRequestResult? result;
        dispatcher
            .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
            .then((r) => result = r);

        async.elapse(const Duration(seconds: 2));
        dispatcher.cancelRequest(1);

        async.elapse(Duration.zero); // Process microtasks.
        expect(result, isNotNull);
        expect(result!.status, MrrpStatusCode.timeout);
        expect(dispatcher.pendingCount, 0);

        // CANCEL frame was sent.
        expect(sentFrames.length, 2); // REQUEST + CANCEL
      });
    });

    test('late response after timeout is silently dropped', () {
      fakeAsync((async) {
        MrrpRequestResult? result;
        dispatcher
            .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
            .then((r) => result = r);

        // Let timeout fire.
        async.elapse(
          MrrpConstants.mrrpRequestTimeout + const Duration(seconds: 1),
        );
        expect(result!.status, MrrpStatusCode.timeout);

        // Late response should not crash.
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
        // No exception — late frame silently dropped.
      });
    });

    test('dispose resolves all pending as timeout', () {
      fakeAsync((async) {
        final results = <MrrpRequestResult?>[];

        for (var i = 0; i < 3; i++) {
          dispatcher
              .sendRequest(_makeRequest(serviceId: MrrpServiceId.echoTest))
              .then((r) => results.add(r));
        }

        expect(dispatcher.pendingCount, 3);
        dispatcher.dispose();
        async.elapse(Duration.zero);

        expect(results.length, 3);
        for (final r in results) {
          expect(r!.status, MrrpStatusCode.timeout);
        }
      });
    });
  });
}
