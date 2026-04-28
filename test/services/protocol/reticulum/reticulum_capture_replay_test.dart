// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_replay.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_writer.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';

void main() {
  group('ReticulumCaptureReplay — decodeAll', () {
    test('throws UnsupportedCaptureVersion on missing magic', () {
      final junk = Uint8List.fromList([0, 1, 2, 3, 4]);
      expect(
        () => ReticulumCaptureReplay.decodeAll(junk),
        throwsA(isA<UnsupportedCaptureVersion>()),
      );
    });

    test('throws UnsupportedCaptureVersion on non-SMRC magic', () {
      final wrong = Uint8List.fromList([
        ...'XXXX'.codeUnits,
        ReticulumCaptureWriter.formatVersion,
      ]);
      expect(
        () => ReticulumCaptureReplay.decodeAll(wrong),
        throwsA(isA<UnsupportedCaptureVersion>()),
      );
    });

    test('throws UnsupportedCaptureVersion on unsupported version', () {
      final wrong = Uint8List.fromList([
        ...ReticulumCaptureWriter.magicAscii.codeUnits,
        0x99,
      ]);
      expect(
        () => ReticulumCaptureReplay.decodeAll(wrong),
        throwsA(
          isA<UnsupportedCaptureVersion>().having(
            (e) => e.version,
            'version',
            0x99,
          ),
        ),
      );
    });

    test('round-trips events through encode -> decodeAll', () {
      final events = [
        ReticulumFragmentEvent(
          timestampMs: 100,
          fromNode: 0x11,
          toNode: 0xFFFFFFFF,
          packetId: 0xAA,
          channel: 0,
          rssi: -80,
          snr: 3.5,
          payload: Uint8List.fromList([1, 2, 3, 4]),
        ),
        ReticulumFragmentEvent(
          timestampMs: 250,
          fromNode: 0x22,
          toNode: 0x33,
          packetId: 0xBB,
          channel: 1,
          rssi: null,
          snr: null,
          payload: Uint8List.fromList([0xDE, 0xAD]),
        ),
      ];
      final builder = BytesBuilder()..add(ReticulumCaptureWriter.magicHeader());
      for (final e in events) {
        builder.add(ReticulumCaptureWriter.encodeRecord(e));
      }
      final decoded = ReticulumCaptureReplay.decodeAll(builder.toBytes());
      expect(decoded, hasLength(2));

      expect(decoded[0].timestampMs, 100);
      expect(decoded[0].fromNode, 0x11);
      expect(decoded[0].rssi, -80);
      expect(decoded[0].snr, closeTo(3.5, 0.01));
      expect(decoded[0].payload, [1, 2, 3, 4]);

      expect(decoded[1].rssi, isNull);
      expect(decoded[1].snr, isNull);
      expect(decoded[1].payload, [0xDE, 0xAD]);
    });

    test('skips trailing truncated records', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 1,
        fromNode: 1,
        toNode: 1,
        packetId: 1,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List.fromList([0xAB]),
      );
      final builder = BytesBuilder()
        ..add(ReticulumCaptureWriter.magicHeader())
        ..add(ReticulumCaptureWriter.encodeRecord(event))
        ..add(Uint8List(10)); // partial header — not a full record
      final decoded = ReticulumCaptureReplay.decodeAll(builder.toBytes());
      expect(decoded, hasLength(1));
    });
  });

  group('ReticulumCaptureReplay — step mode', () {
    late Directory tempDir;
    late File captureFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rns_replay_test_');
      captureFile = File('${tempDir.path}/test.bin');
      final builder = BytesBuilder()..add(ReticulumCaptureWriter.magicHeader());
      for (var i = 0; i < 5; i++) {
        builder.add(
          ReticulumCaptureWriter.encodeRecord(
            ReticulumFragmentEvent(
              timestampMs: 100 + i * 10,
              fromNode: i,
              toNode: 0xFFFFFFFF,
              packetId: i + 1,
              channel: 0,
              rssi: null,
              snr: null,
              payload: Uint8List.fromList([i]),
            ),
          ),
        );
      }
      await captureFile.writeAsBytes(builder.toBytes());
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('stepOne emits exactly one record per call', () async {
      final replay = ReticulumCaptureReplay(
        file: captureFile,
        mode: ReticulumReplayMode.step,
      );
      addTearDown(replay.stop);

      final received = <int>[];
      final sub = replay.stream.listen((e) => received.add(e.fromNode));
      addTearDown(sub.cancel);

      await replay.load();
      expect(replay.totalRecords, 5);
      expect(replay.currentIndex, 0);

      replay.stepOne();
      replay.stepOne();
      replay.stepOne();
      // Allow microtasks for stream delivery.
      await Future<void>.delayed(Duration.zero);

      expect(received, [0, 1, 2]);
      expect(replay.currentIndex, 3);
    });

    test('stepOne returns false when exhausted', () async {
      final replay = ReticulumCaptureReplay(
        file: captureFile,
        mode: ReticulumReplayMode.step,
      );
      addTearDown(replay.stop);
      await replay.load();
      // 5 records — first 4 returns true (more remaining), 5th returns false.
      for (var i = 0; i < 4; i++) {
        expect(replay.stepOne(), isTrue, reason: 'after step ${i + 1}');
      }
      expect(replay.stepOne(), isFalse);
      expect(replay.stepOne(), isFalse);
    });

    test('stepOne in non-step mode throws StateError', () async {
      final replay = ReticulumCaptureReplay(
        file: captureFile,
        mode: ReticulumReplayMode.realtime,
      );
      addTearDown(replay.stop);
      await replay.load();
      expect(replay.stepOne, throwsStateError);
    });
  });

  group('ReticulumCaptureReplay — accelerated mode', () {
    late Directory tempDir;
    late File captureFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rns_replay_acc_');
      captureFile = File('${tempDir.path}/test.bin');
      final builder = BytesBuilder()..add(ReticulumCaptureWriter.magicHeader());
      // 3 records 100ms apart. With 1000x speedup, gap becomes <1ms.
      for (var i = 0; i < 3; i++) {
        builder.add(
          ReticulumCaptureWriter.encodeRecord(
            ReticulumFragmentEvent(
              timestampMs: 1000 + i * 100,
              fromNode: i,
              toNode: 0xFFFFFFFF,
              packetId: i + 1,
              channel: 0,
              rssi: null,
              snr: null,
              payload: Uint8List.fromList([i]),
            ),
          ),
        );
      }
      await captureFile.writeAsBytes(builder.toBytes());
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('completes in bounded time at 1000x', () async {
      final replay = ReticulumCaptureReplay(
        file: captureFile,
        mode: ReticulumReplayMode.accelerated,
        speedMultiplier: 1000,
      );
      addTearDown(replay.stop);

      final received = <int>[];
      final sub = replay.stream.listen((e) => received.add(e.fromNode));
      addTearDown(sub.cancel);

      await replay.start();
      // 3 records at 100ms gap / 1000x = ~0ms each. Allow generous slack.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received, [0, 1, 2]);
    });
  });
}
