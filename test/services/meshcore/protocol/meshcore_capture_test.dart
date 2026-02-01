// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_capture.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

/// Fake transport for testing capture functionality.
class FakeMeshCoreTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rxController =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sentData = [];
  final bool _isConnected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rxController.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    if (!_isConnected) {
      throw StateError('Transport not connected');
    }
    sentData.add(data);
  }

  @override
  bool get isConnected => _isConnected;

  void simulateReceive(Uint8List data) {
    _rxController.add(data);
  }

  void simulateReceiveFrame(MeshCoreFrame frame) {
    _rxController.add(frame.toBytes());
  }

  Future<void> dispose() async {
    await _rxController.close();
  }
}

void main() {
  group('CapturedFrame', () {
    test('fromFrame creates correct captured frame', () {
      final frame = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([0x01, 0x02, 0x03]),
      );

      final captured = CapturedFrame.fromFrame(
        frame,
        CaptureDirection.rx,
        1234,
      );

      expect(captured.direction, equals(CaptureDirection.rx));
      expect(captured.timestampMs, equals(1234));
      expect(captured.code, equals(0x05));
      expect(captured.payload, equals(Uint8List.fromList([0x01, 0x02, 0x03])));
    });

    test('toFrame converts back correctly', () {
      final captured = CapturedFrame(
        direction: CaptureDirection.tx,
        timestampMs: 100,
        code: 0x14,
        payload: Uint8List.fromList([0xAA, 0xBB]),
      );

      final frame = captured.toFrame();

      expect(frame.command, equals(0x14));
      expect(frame.payload, equals(Uint8List.fromList([0xAA, 0xBB])));
    });

    test('toCompactHex formats correctly', () {
      final captured = CapturedFrame(
        direction: CaptureDirection.rx,
        timestampMs: 42,
        code: 0x05,
        payload: Uint8List.fromList([0x01, 0x02, 0x03]),
      );

      final hex = captured.toCompactHex();

      expect(hex, contains('[RX]'));
      expect(hex, contains('@42ms'));
      expect(hex, contains('0x05'));
      expect(hex, contains('01 02 03'));
    });

    test('toCompactHex truncates long payloads', () {
      final captured = CapturedFrame(
        direction: CaptureDirection.tx,
        timestampMs: 100,
        code: 0x02,
        payload: Uint8List.fromList(List.filled(100, 0xAA)),
      );

      final hex = captured.toCompactHex(maxBytes: 10);

      expect(hex, contains('...'));
      expect(hex, contains('100 bytes total'));
    });
  });

  group('MeshCoreFrameCapture', () {
    test('records RX frames', () {
      final capture = MeshCoreFrameCapture();

      capture.recordRx(MeshCoreFrame.simple(0x05));
      capture.recordRx(
        MeshCoreFrame(command: 0x0C, payload: Uint8List.fromList([0x01])),
      );

      expect(capture.frameCount, equals(2));
      expect(capture.rxFrames().length, equals(2));
      expect(capture.txFrames().length, equals(0));
    });

    test('records TX frames', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x16));
      capture.recordTx(MeshCoreFrame.simple(0x01));
      capture.recordTx(MeshCoreFrame.simple(0x14));

      expect(capture.frameCount, equals(3));
      expect(capture.rxFrames().length, equals(0));
      expect(capture.txFrames().length, equals(3));
    });

    test('snapshot returns unmodifiable copy', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x16));
      final snap1 = capture.snapshot();

      capture.recordTx(MeshCoreFrame.simple(0x01));
      final snap2 = capture.snapshot();

      expect(snap1.length, equals(1));
      expect(snap2.length, equals(2));
    });

    test('timestamps increase', () async {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x01));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      capture.recordRx(MeshCoreFrame.simple(0x05));

      final frames = capture.snapshot();
      expect(frames[1].timestampMs, greaterThan(frames[0].timestampMs));
    });

    test('toCompactHexLog formats all frames', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x16));
      capture.recordTx(MeshCoreFrame.simple(0x01));
      capture.recordRx(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0xAA])),
      );

      final log = capture.toCompactHexLog();

      expect(log, contains('[TX]'));
      expect(log, contains('[RX]'));
      expect(log, contains('0x16'));
      expect(log, contains('0x01'));
      expect(log, contains('0x05'));
    });

    test('clear resets capture', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x01));
      capture.recordRx(MeshCoreFrame.simple(0x05));
      expect(capture.frameCount, equals(2));

      capture.clear();

      expect(capture.frameCount, equals(0));
    });

    test('stop/resume controls recording', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x01));
      expect(capture.frameCount, equals(1));

      capture.stop();
      capture.recordTx(MeshCoreFrame.simple(0x02));
      expect(capture.frameCount, equals(1)); // Not recorded

      capture.resume();
      capture.recordTx(MeshCoreFrame.simple(0x03));
      expect(capture.frameCount, equals(2));
    });

    test('empty capture returns placeholder log', () {
      final capture = MeshCoreFrameCapture();
      final log = capture.toCompactHexLog();
      expect(log, equals('(no frames captured)'));
    });
  });

  group('MeshCoreSession capture integration', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;
    late MeshCoreFrameCapture capture;

    setUp(() {
      transport = FakeMeshCoreTransport();
      capture = MeshCoreFrameCapture();
      session = MeshCoreSession.withCapture(transport, capture);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('captures TX frames on send', () async {
      await session.sendCommand(MeshCoreCommands.deviceQuery);
      await session.sendCommand(MeshCoreCommands.appStart);

      expect(capture.txFrames().length, equals(2));
      expect(capture.txFrames()[0].code, equals(MeshCoreCommands.deviceQuery));
      expect(capture.txFrames()[1].code, equals(MeshCoreCommands.appStart));
    });

    test('captures RX frames on receive', () async {
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05));
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x0C, payload: Uint8List.fromList([0x01, 0x02])),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(capture.rxFrames().length, equals(2));
      expect(capture.rxFrames()[0].code, equals(0x05));
      expect(capture.rxFrames()[1].code, equals(0x0C));
    });

    test('getSelfInfo captures full TX/RX sequence', () async {
      // Start getSelfInfo
      final selfInfoFuture = session.getSelfInfo(
        timeout: const Duration(seconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate response
      final responsePayload = Uint8List.fromList([
        0x01, 20, 22, // ADV_TYPE, tx_power, max_lora_tx
        ...List.filled(32, 0xAA), // pub_key (32 bytes)
        0, 0, 0, 0, 0, 0, 0, 0, // lat/lon
        ...List.filled(14, 0), // padding to offset 57
        ...'TestNode'.codeUnits, 0, // node name
      ]);
      transport.simulateReceive(
        Uint8List.fromList([MeshCoreResponses.selfInfo, ...responsePayload]),
      );

      await selfInfoFuture;

      // Verify capture has correct TX sequence
      final txFrames = capture.txFrames();
      expect(txFrames.length, equals(2));
      expect(txFrames[0].code, equals(MeshCoreCommands.deviceQuery));
      expect(txFrames[1].code, equals(MeshCoreCommands.appStart));

      // Verify capture has RX response
      final rxFrames = capture.rxFrames();
      expect(rxFrames.length, equals(1));
      expect(rxFrames[0].code, equals(MeshCoreResponses.selfInfo));
    });

    test('toCompactHexLog contains key elements', () async {
      await session.sendCommand(0x16);

      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0xAB, 0xCD])),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final log = capture.toCompactHexLog();

      // Should contain TX entry
      expect(log, contains('[TX]'));
      expect(log, contains('0x16'));

      // Should contain RX entry
      expect(log, contains('[RX]'));
      expect(log, contains('0x05'));
      expect(log, contains('ab cd')); // Hex payload (lowercase)
    });

    test('setCapture allows enabling/disabling capture', () async {
      // Start with no capture
      final sessionNoCapture = MeshCoreSession(transport);

      await sessionNoCapture.sendCommand(0x01);
      expect(capture.frameCount, equals(0)); // Not captured

      // Enable capture
      sessionNoCapture.setCapture(capture);
      await sessionNoCapture.sendCommand(0x02);
      expect(capture.txFrames().length, equals(1));
      expect(capture.txFrames()[0].code, equals(0x02));

      // Disable capture
      sessionNoCapture.setCapture(null);
      await sessionNoCapture.sendCommand(0x03);
      expect(capture.txFrames().length, equals(1)); // Still 1

      await sessionNoCapture.dispose();
    });
  });

  group('Replay harness', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    /// Replay captured RX frames into the transport.
    void replayCapturedRxFrames(
      FakeMeshCoreTransport transport,
      List<CapturedFrame> frames,
    ) {
      for (final captured in frames) {
        if (captured.direction == CaptureDirection.rx) {
          transport.simulateReceiveFrame(captured.toFrame());
        }
      }
    }

    test('replayed frames resolve waiters', () async {
      // Create some captured frames to replay
      final capturedFrames = [
        CapturedFrame(
          direction: CaptureDirection.rx,
          timestampMs: 100,
          code: 0x05,
          payload: Uint8List.fromList([0x01, 0x02, 0x03]),
        ),
      ];

      // Set up waiter
      final waiterFuture = session.waitForResponse(0x05);

      // Replay the captured frames
      replayCapturedRxFrames(transport, capturedFrames);

      final result = await waiterFuture;

      expect(result, isNotNull);
      expect(result!.command, equals(0x05));
      expect(result.payload, equals(Uint8List.fromList([0x01, 0x02, 0x03])));
    });

    test('replayed push frames do not resolve response waiters', () async {
      // Captured push frame should not resolve response waiter
      final capturedFrames = [
        CapturedFrame(
          direction: CaptureDirection.rx,
          timestampMs: 50,
          code: 0x80, // Push code (advert)
          payload: Uint8List.fromList([0xAA]),
        ),
        CapturedFrame(
          direction: CaptureDirection.rx,
          timestampMs: 100,
          code: 0x05, // Response code (selfInfo)
          payload: Uint8List.fromList([0xBB]),
        ),
      ];

      // Set up waiter for response code
      final waiterFuture = session.waitForResponse(
        0x05,
        timeout: const Duration(seconds: 1),
      );

      // Track all frames received
      final allFrames = <MeshCoreFrame>[];
      session.frameStream.listen(allFrames.add);

      // Replay - push frame comes first
      replayCapturedRxFrames(transport, capturedFrames);

      final result = await waiterFuture;

      // Should have received response, not the push frame
      expect(result, isNotNull);
      expect(result!.command, equals(0x05));
      expect(result.payload[0], equals(0xBB));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // But both frames should be in frameStream
      expect(allFrames.length, equals(2));
    });
  });
}
