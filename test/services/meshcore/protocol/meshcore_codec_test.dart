// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_codec.dart';

void main() {
  group('MeshCoreFrame', () {
    test('creates frame with command and payload', () {
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final frame = MeshCoreFrame(command: 0x05, payload: payload);

      expect(frame.command, 0x05);
      expect(frame.payload, payload);
      expect(frame.size, 5);
      expect(frame.isValidSize, isTrue);
    });

    test('creates simple frame with no payload', () {
      final frame = MeshCoreFrame.simple(0x10);

      expect(frame.command, 0x10);
      expect(frame.payload.isEmpty, isTrue);
      expect(frame.size, 1);
    });

    test('creates frame from bytes', () {
      final bytes = Uint8List.fromList([0x05, 0x01, 0x02, 0x03]);
      final frame = MeshCoreFrame.fromBytes(bytes);

      expect(frame.command, 0x05);
      expect(frame.payload.length, 3);
      expect(frame.payload[0], 0x01);
      expect(frame.payload[1], 0x02);
      expect(frame.payload[2], 0x03);
    });

    test('creates frame from single-byte data', () {
      final bytes = Uint8List.fromList([0xFF]);
      final frame = MeshCoreFrame.fromBytes(bytes);

      expect(frame.command, 0xFF);
      expect(frame.payload.isEmpty, isTrue);
    });

    test('throws on empty data', () {
      expect(() => MeshCoreFrame.fromBytes(Uint8List(0)), throwsArgumentError);
    });

    test('converts to bytes correctly', () {
      final payload = Uint8List.fromList([0xAA, 0xBB]);
      final frame = MeshCoreFrame(command: 0x07, payload: payload);
      final bytes = frame.toBytes();

      expect(bytes.length, 3);
      expect(bytes[0], 0x07);
      expect(bytes[1], 0xAA);
      expect(bytes[2], 0xBB);
    });

    test('roundtrip fromBytes/toBytes', () {
      final original = Uint8List.fromList([0x05, 0x01, 0x02, 0x03, 0x04]);
      final frame = MeshCoreFrame.fromBytes(original);
      final restored = frame.toBytes();

      expect(restored, original);
    });

    test('isValidSize returns true for small frames', () {
      final frame = MeshCoreFrame(command: 0x01, payload: Uint8List(100));
      expect(frame.isValidSize, isTrue);
    });

    test('isValidSize returns false for oversized frames', () {
      // 172 bytes max, so 1 + 172 = 173 is invalid
      final frame = MeshCoreFrame(command: 0x01, payload: Uint8List(172));
      expect(frame.isValidSize, isFalse);
    });

    test('isValidSize returns true at exact max size', () {
      // 1 byte command + 171 bytes payload = 172 total = valid
      final frame = MeshCoreFrame(command: 0x01, payload: Uint8List(171));
      expect(frame.isValidSize, isTrue);
    });

    test('isResponse returns true for codes < 0x80', () {
      expect(MeshCoreFrame.simple(0x00).isResponse, isTrue);
      expect(MeshCoreFrame.simple(0x05).isResponse, isTrue);
      expect(MeshCoreFrame.simple(0x7F).isResponse, isTrue);
    });

    test('isPush returns true for codes >= 0x80', () {
      expect(MeshCoreFrame.simple(0x80).isPush, isTrue);
      expect(MeshCoreFrame.simple(0x81).isPush, isTrue);
      expect(MeshCoreFrame.simple(0xFF).isPush, isTrue);
    });

    test('equality works correctly', () {
      final frame1 = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final frame2 = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final frame3 = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 4]),
      );

      expect(frame1, frame2);
      expect(frame1, isNot(frame3));
    });

    test('toString includes command and length', () {
      final frame = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final str = frame.toString();

      expect(str, contains('cmd=0x05'));
      expect(str, contains('len=3'));
    });
  });

  group('MeshCoreBufferReader', () {
    test('reads bytes sequentially', () {
      final reader = MeshCoreBufferReader(Uint8List.fromList([1, 2, 3, 4, 5]));

      expect(reader.readByte(), 1);
      expect(reader.readByte(), 2);
      expect(reader.remaining, 3);
      expect(reader.readBytes(2), Uint8List.fromList([3, 4]));
      expect(reader.remaining, 1);
    });

    test('reads little-endian uint16', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x34, 0x12]),
      ); // 0x1234
      expect(reader.readUint16LE(), 0x1234);
    });

    test('reads little-endian uint32', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x78, 0x56, 0x34, 0x12]), // 0x12345678
      );
      expect(reader.readUint32LE(), 0x12345678);
    });

    test('reads little-endian int32 positive', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x01, 0x00, 0x00, 0x00]),
      );
      expect(reader.readInt32LE(), 1);
    });

    test('reads little-endian int32 negative', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]), // -1
      );
      expect(reader.readInt32LE(), -1);
    });

    test('reads null-terminated string', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x48, 0x69, 0x00, 0x00, 0x00]), // "Hi\0\0\0"
      );
      expect(reader.readCString(5), 'Hi');
    });

    test('reads string trimmed at max length', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]), // "Hello"
      );
      expect(reader.readCString(3), 'Hel');
    });

    test('skip advances position', () {
      final reader = MeshCoreBufferReader(Uint8List.fromList([1, 2, 3, 4, 5]));
      reader.skip(2);
      expect(reader.readByte(), 3);
    });

    test('hasRemaining tracks correctly', () {
      final reader = MeshCoreBufferReader(Uint8List.fromList([1, 2]));
      expect(reader.hasRemaining, isTrue);
      reader.readByte();
      expect(reader.hasRemaining, isTrue);
      reader.readByte();
      expect(reader.hasRemaining, isFalse);
    });
  });

  group('MeshCoreBufferWriter', () {
    test('writes bytes', () {
      final writer = MeshCoreBufferWriter();
      writer.writeByte(0x01);
      writer.writeByte(0x02);
      writer.writeBytes(Uint8List.fromList([0x03, 0x04]));

      expect(writer.toBytes(), Uint8List.fromList([1, 2, 3, 4]));
    });

    test('writes little-endian uint16', () {
      final writer = MeshCoreBufferWriter();
      writer.writeUint16LE(0x1234);
      expect(writer.toBytes(), Uint8List.fromList([0x34, 0x12]));
    });

    test('writes little-endian uint32', () {
      final writer = MeshCoreBufferWriter();
      writer.writeUint32LE(0x12345678);
      expect(writer.toBytes(), Uint8List.fromList([0x78, 0x56, 0x34, 0x12]));
    });

    test('writes little-endian int32 positive', () {
      final writer = MeshCoreBufferWriter();
      writer.writeInt32LE(1);
      expect(writer.toBytes(), Uint8List.fromList([0x01, 0x00, 0x00, 0x00]));
    });

    test('writes little-endian int32 negative', () {
      final writer = MeshCoreBufferWriter();
      writer.writeInt32LE(-1);
      expect(writer.toBytes(), Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
    });

    test('writes string', () {
      final writer = MeshCoreBufferWriter();
      writer.writeString('Hi');
      expect(writer.toBytes(), Uint8List.fromList([0x48, 0x69]));
    });

    test('writes null-padded c-string', () {
      final writer = MeshCoreBufferWriter();
      writer.writeCString('Hi', 5);
      expect(writer.toBytes(), Uint8List.fromList([0x48, 0x69, 0, 0, 0]));
    });

    test('truncates c-string at max length', () {
      final writer = MeshCoreBufferWriter();
      writer.writeCString('Hello', 3);
      // 3 bytes total, last must be null, so only 'He' fits
      expect(writer.toBytes(), Uint8List.fromList([0x48, 0x65, 0]));
    });

    test('length tracks correctly', () {
      final writer = MeshCoreBufferWriter();
      expect(writer.length, 0);
      writer.writeByte(1);
      expect(writer.length, 1);
      writer.writeBytes(Uint8List(4));
      expect(writer.length, 5);
    });
  });

  group('MeshCoreEncoder', () {
    test('encodes frame to bytes', () {
      final encoder = MeshCoreEncoder();
      final frame = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final bytes = encoder.encode(frame);

      expect(bytes, Uint8List.fromList([0x05, 1, 2, 3]));
    });

    test('encodes simple command', () {
      final encoder = MeshCoreEncoder();
      final bytes = encoder.encodeCommand(0x04);

      expect(bytes, Uint8List.fromList([0x04]));
    });

    test('encodes command with byte arg', () {
      final encoder = MeshCoreEncoder();
      final bytes = encoder.encodeCommandWithByte(0x1F, 0x02);

      expect(bytes, Uint8List.fromList([0x1F, 0x02]));
    });

    test('throws on oversized frame', () {
      final encoder = MeshCoreEncoder();
      final frame = MeshCoreFrame(
        command: 0x01,
        payload: Uint8List(172), // 1 + 172 = 173 > 172
      );

      expect(() => encoder.encode(frame), throwsArgumentError);
    });
  });

  group('MeshCoreDecoder', () {
    test('decodes single frame in direct mode', () {
      final frames = <MeshCoreFrame>[];
      final decoder = MeshCoreDecoder(onFrame: frames.add, bufferedMode: false);

      decoder.addData(Uint8List.fromList([0x05, 1, 2, 3]));

      expect(frames.length, 1);
      expect(frames[0].command, 0x05);
      expect(frames[0].payload, Uint8List.fromList([1, 2, 3]));
    });

    test('ignores empty data', () {
      final frames = <MeshCoreFrame>[];
      final decoder = MeshCoreDecoder(onFrame: frames.add, bufferedMode: false);

      decoder.addData(Uint8List(0));

      expect(frames.isEmpty, isTrue);
    });

    test('reports error for oversized frame', () {
      final errors = <String>[];
      final decoder = MeshCoreDecoder(onError: errors.add, bufferedMode: false);

      decoder.addData(Uint8List(200)); // > 172

      expect(errors.length, 1);
      expect(errors[0], contains('exceeds max size'));
    });

    test('decodes multiple notifications as separate frames', () {
      final frames = <MeshCoreFrame>[];
      final decoder = MeshCoreDecoder(onFrame: frames.add, bufferedMode: false);

      decoder.addData(Uint8List.fromList([0x05, 1, 2]));
      decoder.addData(Uint8List.fromList([0x06, 3, 4, 5]));
      decoder.addData(Uint8List.fromList([0x07]));

      expect(frames.length, 3);
      expect(frames[0].command, 0x05);
      expect(frames[1].command, 0x06);
      expect(frames[2].command, 0x07);
    });

    test('buffered mode accumulates partial data', () {
      final frames = <MeshCoreFrame>[];
      final decoder = MeshCoreDecoder(onFrame: frames.add, bufferedMode: true);

      // In buffered mode without explicit size, each addData is one frame
      decoder.addData(Uint8List.fromList([0x05, 1, 2]));

      expect(frames.length, 1);
      expect(frames[0].command, 0x05);
    });

    test('buffered mode with expectFrameSize waits for complete frame', () {
      final frames = <MeshCoreFrame>[];
      final decoder = MeshCoreDecoder(onFrame: frames.add, bufferedMode: true);

      decoder.expectFrameSize(5);
      decoder.addData(Uint8List.fromList([0x05, 1])); // partial

      expect(frames.isEmpty, isTrue);
      expect(decoder.hasPendingData, isTrue);
      expect(decoder.pendingBytes, 2);

      decoder.addData(Uint8List.fromList([2, 3, 4])); // complete

      expect(frames.length, 1);
      expect(frames[0].command, 0x05);
      expect(frames[0].payload.length, 4);
    });

    test('reset clears pending data', () {
      final decoder = MeshCoreDecoder(bufferedMode: true);

      decoder.expectFrameSize(10);
      decoder.addData(Uint8List.fromList([1, 2, 3]));

      expect(decoder.hasPendingData, isTrue);

      decoder.reset();

      expect(decoder.hasPendingData, isFalse);
      expect(decoder.pendingBytes, 0);
    });
  });

  group('MeshCoreCodec', () {
    test('combines encoder and decoder', () {
      final frames = <MeshCoreFrame>[];
      final codec = MeshCoreCodec(onFrame: frames.add);

      // Encode a frame
      final original = MeshCoreFrame(
        command: 0x05,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      final bytes = codec.encode(original);

      // Decode it back
      codec.decode(bytes);

      expect(frames.length, 1);
      expect(frames[0], original);
    });

    test('reset clears decoder state', () {
      final codec = MeshCoreCodec(bufferedMode: true);

      codec.decoder.expectFrameSize(10);
      codec.decode(Uint8List.fromList([1, 2]));

      expect(codec.decoder.hasPendingData, isTrue);

      codec.reset();

      expect(codec.decoder.hasPendingData, isFalse);
    });
  });
}
