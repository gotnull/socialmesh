// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/audio/wav_temp_file.dart';

/// Minimal valid WAV header (44 bytes) with zero audio samples.
/// RIFF + fmt chunk + empty data chunk — enough for file-level tests
/// that don't require actual audio playback.
Uint8List _minimalWav() {
  final buffer = ByteData(44);
  var offset = 0;

  // RIFF header
  buffer.setUint8(offset++, 0x52); // R
  buffer.setUint8(offset++, 0x49); // I
  buffer.setUint8(offset++, 0x46); // F
  buffer.setUint8(offset++, 0x46); // F
  buffer.setUint32(offset, 36, Endian.little); // file size - 8
  offset += 4;
  buffer.setUint8(offset++, 0x57); // W
  buffer.setUint8(offset++, 0x41); // A
  buffer.setUint8(offset++, 0x56); // V
  buffer.setUint8(offset++, 0x45); // E

  // fmt sub-chunk
  buffer.setUint8(offset++, 0x66); // f
  buffer.setUint8(offset++, 0x6D); // m
  buffer.setUint8(offset++, 0x74); // t
  buffer.setUint8(offset++, 0x20); // space
  buffer.setUint32(offset, 16, Endian.little); // sub-chunk size
  offset += 4;
  buffer.setUint16(offset, 1, Endian.little); // PCM format
  offset += 2;
  buffer.setUint16(offset, 1, Endian.little); // mono
  offset += 2;
  buffer.setUint32(offset, 44100, Endian.little); // sample rate
  offset += 4;
  buffer.setUint32(offset, 88200, Endian.little); // byte rate
  offset += 4;
  buffer.setUint16(offset, 2, Endian.little); // block align
  offset += 2;
  buffer.setUint16(offset, 16, Endian.little); // bits per sample
  offset += 2;

  // data sub-chunk (empty)
  buffer.setUint8(offset++, 0x64); // d
  buffer.setUint8(offset++, 0x61); // a
  buffer.setUint8(offset++, 0x74); // t
  buffer.setUint8(offset++, 0x61); // a
  buffer.setUint32(offset, 0, Endian.little); // data size = 0

  return buffer.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WavTempFile', () {
    test('write creates a file on disk with correct bytes', () async {
      final wav = _minimalWav();
      final tempFile = await WavTempFile.write(wav, tag: 'test');

      addTearDown(() => tempFile.cleanup());

      final file = File(tempFile.filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), equals(wav));
    });

    test('filePath ends with .wav', () async {
      final tempFile = await WavTempFile.write(_minimalWav(), tag: 'ext');

      addTearDown(() => tempFile.cleanup());

      expect(tempFile.filePath, endsWith('.wav'));
    });

    test('filePath contains the tag for debuggability', () async {
      final tempFile = await WavTempFile.write(_minimalWav(), tag: 'rtttl');

      addTearDown(() => tempFile.cleanup());

      expect(tempFile.filePath, contains('rtttl'));
    });

    test('cleanup deletes the file', () async {
      final tempFile = await WavTempFile.write(_minimalWav(), tag: 'del');
      final path = tempFile.filePath;

      expect(await File(path).exists(), isTrue);

      await tempFile.cleanup();

      expect(await File(path).exists(), isFalse);
    });

    test('cleanup is safe to call multiple times', () async {
      final tempFile = await WavTempFile.write(_minimalWav(), tag: 'multi');

      await tempFile.cleanup();
      // Second and third calls must not throw.
      await tempFile.cleanup();
      await tempFile.cleanup();
    });

    test('cleanup is safe when file was already externally deleted', () async {
      final tempFile = await WavTempFile.write(_minimalWav(), tag: 'gone');

      // Simulate external deletion (e.g. OS temp purge).
      await File(tempFile.filePath).delete();

      // Must not throw.
      await tempFile.cleanup();
    });

    test('successive writes produce distinct file paths', () async {
      final a = await WavTempFile.write(_minimalWav(), tag: 'seq');
      final b = await WavTempFile.write(_minimalWav(), tag: 'seq');

      addTearDown(() async {
        await a.cleanup();
        await b.cleanup();
      });

      expect(a.filePath, isNot(equals(b.filePath)));
      expect(await File(a.filePath).exists(), isTrue);
      expect(await File(b.filePath).exists(), isTrue);
    });

    test('different tags produce distinct file paths', () async {
      final wav = _minimalWav();
      final rtttl = await WavTempFile.write(wav, tag: 'rtttl');
      final voice = await WavTempFile.write(wav, tag: 'voice');

      addTearDown(() async {
        await rtttl.cleanup();
        await voice.cleanup();
      });

      expect(rtttl.filePath, isNot(equals(voice.filePath)));
      expect(rtttl.filePath, contains('rtttl'));
      expect(voice.filePath, contains('voice'));
    });

    test('write with default tag works', () async {
      final tempFile = await WavTempFile.write(_minimalWav());

      addTearDown(() => tempFile.cleanup());

      expect(await File(tempFile.filePath).exists(), isTrue);
      expect(tempFile.filePath, contains('audio'));
    });

    test('handles non-trivial payload sizes', () async {
      // ~1 second of 16-bit mono 44100 Hz = 88200 bytes + 44 header
      final largeWav = Uint8List(88244);
      // Copy the minimal header into the front.
      final header = _minimalWav();
      largeWav.setRange(0, header.length, header);
      // Fix the data chunk size in the header.
      final view = ByteData.sublistView(largeWav);
      view.setUint32(4, largeWav.length - 8, Endian.little); // RIFF size
      view.setUint32(40, largeWav.length - 44, Endian.little); // data size

      final tempFile = await WavTempFile.write(largeWav, tag: 'large');

      addTearDown(() => tempFile.cleanup());

      final written = await File(tempFile.filePath).readAsBytes();
      expect(written.length, equals(largeWav.length));
      expect(written, equals(largeWav));
    });

    test('concurrent writes do not interfere', () async {
      final wav = _minimalWav();
      final futures = List.generate(
        10,
        (i) => WavTempFile.write(wav, tag: 'concurrent'),
      );
      final files = await Future.wait(futures);

      addTearDown(() async {
        for (final f in files) {
          await f.cleanup();
        }
      });

      // All paths must be unique.
      final paths = files.map((f) => f.filePath).toSet();
      expect(paths.length, equals(10));

      // All files must exist with correct content.
      for (final f in files) {
        expect(await File(f.filePath).exists(), isTrue);
        expect(await File(f.filePath).readAsBytes(), equals(wav));
      }
    });

    test('cleanup of one file does not affect another', () async {
      final wav = _minimalWav();
      final a = await WavTempFile.write(wav, tag: 'iso');
      final b = await WavTempFile.write(wav, tag: 'iso');

      addTearDown(() async {
        await a.cleanup();
        await b.cleanup();
      });

      await a.cleanup();

      expect(await File(a.filePath).exists(), isFalse);
      expect(await File(b.filePath).exists(), isTrue);
    });
  });
}
