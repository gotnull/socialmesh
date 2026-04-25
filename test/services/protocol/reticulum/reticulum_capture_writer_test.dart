// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_writer.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';

void main() {
  group('ReticulumCaptureWriter — encodeRecord wire layout', () {
    test('fixed header is 27 bytes', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 0,
        fromNode: 0,
        toNode: 0,
        packetId: 0,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List(0),
      );
      final encoded = ReticulumCaptureWriter.encodeRecord(event);
      expect(encoded.length, 27);
      expect(ReticulumCaptureWriter.recordHeaderBytes, 27);
    });

    test('round-trips packed little-endian fields', () {
      final payload = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final event = ReticulumFragmentEvent(
        timestampMs: 0x0102030405060708,
        fromNode: 0x12345678,
        toNode: 0x9ABCDEF0,
        packetId: 0x11223344,
        channel: 7,
        rssi: -85,
        snr: 6.25,
        payload: payload,
      );
      final encoded = ReticulumCaptureWriter.encodeRecord(event);

      expect(encoded.length, 27 + 4);
      final view = ByteData.sublistView(encoded);
      expect(view.getUint64(0, Endian.little), event.timestampMs);
      expect(view.getUint32(8, Endian.little), event.fromNode);
      expect(view.getUint32(12, Endian.little), event.toNode);
      expect(view.getUint32(16, Endian.little), event.packetId);
      expect(view.getUint8(20), event.channel);
      expect(view.getInt16(21, Endian.little), -85);
      expect(view.getInt16(23, Endian.little), (6.25 * 256).round());
      expect(view.getUint16(25, Endian.little), 4);
      expect(encoded.sublist(27), payload);
    });

    test('absent rssi/snr round-trip as INT16_MIN sentinel', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 1,
        fromNode: 1,
        toNode: 1,
        packetId: 0,
        channel: 0,
        rssi: null,
        snr: null,
        payload: Uint8List(0),
      );
      final encoded = ReticulumCaptureWriter.encodeRecord(event);
      final view = ByteData.sublistView(encoded);
      expect(
        view.getInt16(21, Endian.little),
        ReticulumCaptureWriter.int16AbsentSentinel,
      );
      expect(
        view.getInt16(23, Endian.little),
        ReticulumCaptureWriter.int16AbsentSentinel,
      );
    });

    test('snr clamps below int16 range', () {
      final event = ReticulumFragmentEvent(
        timestampMs: 1,
        fromNode: 1,
        toNode: 1,
        packetId: 0,
        channel: 0,
        rssi: null,
        snr: -300, // -300 * 256 = -76800, well below int16 min
        payload: Uint8List(0),
      );
      final encoded = ReticulumCaptureWriter.encodeRecord(event);
      final view = ByteData.sublistView(encoded);
      expect(view.getInt16(23, Endian.little), -32767);
    });
  });

  group('ReticulumCaptureWriter — magic header', () {
    test('SMRC v1 magic is exactly "SMRC\\x01"', () {
      final magic = ReticulumCaptureWriter.magicHeader();
      expect(magic.length, 5);
      expect(String.fromCharCodes(magic.sublist(0, 4)), 'SMRC');
      expect(magic[4], 0x01);
      expect(ReticulumCaptureWriter.formatVersion, 0x01);
    });
  });

  group('ReticulumCaptureWriter — file lifecycle', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rns_writer_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('disabled writer produces no files', () async {
      final writer = ReticulumCaptureWriter(captureDirOverride: tempDir);
      addTearDown(writer.dispose);
      await writer.write(_event(payload: Uint8List(8)));
      final files = await writer.listCaptureFiles();
      expect(files, isEmpty);
    });

    test('enabled writer emits magic header + at least one record', () async {
      final writer = ReticulumCaptureWriter(captureDirOverride: tempDir);
      addTearDown(writer.dispose);
      await writer.setEnabled(true);
      await writer.write(_event(payload: Uint8List.fromList([1, 2, 3])));
      await writer.dispose();

      final files = await tempDir
          .list()
          .where((e) => e is File && e.path.endsWith('.bin'))
          .cast<File>()
          .toList();
      expect(files, hasLength(1));
      final bytes = await files.first.readAsBytes();
      expect(bytes.length, 5 + 27 + 3);
      expect(bytes.sublist(0, 5), ReticulumCaptureWriter.magicHeader());
    });

    test('disabling closes the active file', () async {
      final writer = ReticulumCaptureWriter(captureDirOverride: tempDir);
      addTearDown(writer.dispose);
      await writer.setEnabled(true);
      await writer.write(_event(payload: Uint8List(2)));
      expect(writer.currentFile, isNotNull);
      await writer.setEnabled(false);
      expect(writer.currentFile, isNull);
      expect(writer.bytesInCurrentFile, 0);
    });
  });
}

ReticulumFragmentEvent _event({required Uint8List payload}) {
  return ReticulumFragmentEvent(
    timestampMs: DateTime.now().millisecondsSinceEpoch,
    fromNode: 0xAABBCCDD,
    toNode: 0xFFFFFFFF,
    packetId: 0x12345678,
    channel: 0,
    rssi: -90,
    snr: 4.0,
    payload: payload,
  );
}
