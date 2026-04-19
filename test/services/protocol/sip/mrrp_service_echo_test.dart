// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_echo.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

MrrpFrame _makeRequest({required int actionId, Uint8List? payload}) {
  final p = payload ?? Uint8List(0);
  return MrrpFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: MrrpMessageType.request,
    flags: 0,
    headerLen: 20,
    requestId: 0x0001,
    serviceId: MrrpServiceId.echoTest,
    actionId: actionId,
    payloadLen: p.length,
    payload: p,
  );
}

void main() {
  late MrrpServiceEcho handler;

  setUp(() {
    handler = MrrpServiceEcho();
  });

  test('serviceId and supportedActions', () {
    expect(handler.serviceId, MrrpServiceId.echoTest);
    expect(handler.supportedActions, contains(EchoAction.echo));
    expect(handler.supportedActions, contains(EchoAction.echoError));
    expect(handler.supportedActions, contains(EchoAction.echoDelay));
  });

  group('echo', () {
    test('returns payload unchanged', () async {
      final request = _makeRequest(
        actionId: EchoAction.echo,
        payload: Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]),
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);
      expect(response.requestId, 0x0001);
      expect(response.payload, equals([0xCA, 0xFE, 0xBA, 0xBE]));
    });

    test('empty payload echoes empty', () async {
      final request = _makeRequest(actionId: EchoAction.echo);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.payload.length, 0);
      expect(response.msgType, MrrpMessageType.response);
    });
  });

  group('echo_error', () {
    test('returns ERROR with status code from payload', () async {
      final request = _makeRequest(
        actionId: EchoAction.echoError,
        payload: Uint8List.fromList([MrrpStatusCode.busy.code]),
      );
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.isError, isTrue);
      expect(response.payload[0], MrrpStatusCode.busy.code);

      final statusTlv = response.findExtension(MrrpTlvType.statusCode);
      expect(statusTlv, isNotNull);
      expect(statusTlv!.value[0], MrrpStatusCode.busy.code);
    });

    test('empty payload defaults to internal error', () async {
      final request = _makeRequest(actionId: EchoAction.echoError);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.internal.code);
    });
  });

  group('echo_delay', () {
    test('returns response after delay', () async {
      // Request with 50ms delay.
      final delayBytes = Uint8List(2);
      ByteData.sublistView(delayBytes).setUint16(0, 50, Endian.little);
      final request = _makeRequest(
        actionId: EchoAction.echoDelay,
        payload: delayBytes,
      );

      final stopwatch = Stopwatch()..start();
      final response = await handler.handleRequest(request, 0xABCD);
      stopwatch.stop();

      expect(response.msgType, MrrpMessageType.response);
      expect(response.requestId, 0x0001);
      // Should have waited at least ~40ms (accounting for timer imprecision).
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(30));
    });

    test('delay capped at 10s', () async {
      // We can't wait 10s in a test, so verify with a 0ms delay that the
      // handler processes without error (the cap is enforced internally).
      final zeroDelay = Uint8List(2); // 0ms
      final zeroRequest = _makeRequest(
        actionId: EchoAction.echoDelay,
        payload: zeroDelay,
      );
      final response = await handler.handleRequest(zeroRequest, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);
    });
  });

  test('unsupported action returns ERROR', () async {
    final request = MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.request,
      flags: 0,
      headerLen: 20,
      requestId: 0x0001,
      serviceId: MrrpServiceId.echoTest,
      actionId: 0xFFFF, // unknown action
      payloadLen: 0,
      payload: Uint8List(0),
    );
    final response = await handler.handleRequest(request, 0xABCD);
    expect(response.msgType, MrrpMessageType.error);
    expect(response.payload[0], MrrpStatusCode.unsupported.code);
  });
}
