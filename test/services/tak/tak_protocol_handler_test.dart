// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/tak_protocol_handler.dart';

void main() {
  group('TakProtocolHandler', () {
    late TakProtocolHandler handler;

    setUp(() {
      handler = TakProtocolHandler();
    });

    group('buildFrame / feedBytes round-trip', () {
      test('XML CoT frame', () {
        const xml = '<event version="2.0"/>';
        final wire = TakProtocolHandler.buildXmlCotFrame(xml);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.xmlCot);
        expect(String.fromCharCodes(frames[0].payload), xml);
      });

      test('protobuf CoT frame', () {
        final payload = Uint8List.fromList([0x08, 0x01, 0x10, 0x02]);
        final wire = TakProtocolHandler.buildProtobufCotFrame(payload);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.protobufCot);
        expect(frames[0].payload, payload);
      });

      test('negotiation frame', () {
        final wire = TakProtocolHandler.buildNegotiation();
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.negotiation);
        expect(frames[0].payload, [1]); // Protocol version 1
      });

      test('keepalive frame', () {
        final wire = TakProtocolHandler.buildKeepalivePing();
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.keepalive);
        expect(frames[0].payload, isEmpty);
      });
    });

    group('frame parsing', () {
      test('parses magic byte 0xBF', () {
        // Build a minimal frame: magic + type + varint(0) = [0xBF, 0x03, 0x00]
        final wire = Uint8List.fromList([0xBF, 0x03, 0x00]);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.keepalive);
      });

      test('skips invalid magic byte', () {
        // Invalid magic followed by valid frame.
        final valid = TakProtocolHandler.buildKeepalivePing();
        final wire = Uint8List.fromList([0x00, ...valid]);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.keepalive);
      });

      test('handles empty payload', () {
        final wire = Uint8List.fromList([0xBF, 0x02, 0x00]);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].type, TakFrameType.negotiation);
        expect(frames[0].payload, isEmpty);
      });
    });

    group('varint encoding', () {
      test('single-byte varint (payload < 128 bytes)', () {
        final payload = Uint8List(100);
        final wire = TakProtocolHandler.buildFrame(
          TakFrameType.xmlCot,
          payload,
        );
        // header: magic(1) + type(1) + varint(1) + payload(100) = 103
        expect(wire.length, 103);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].payload.length, 100);
      });

      test('two-byte varint (payload 128-16383 bytes)', () {
        final payload = Uint8List(300);
        final wire = TakProtocolHandler.buildFrame(
          TakFrameType.xmlCot,
          payload,
        );
        // header: magic(1) + type(1) + varint(2) + payload(300) = 304
        expect(wire.length, 304);
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
        expect(frames[0].payload.length, 300);
      });
    });

    group('TCP stream reassembly', () {
      test('handles split frame across two feedBytes calls', () {
        final payload = Uint8List.fromList(List.generate(50, (i) => i));
        final wire = TakProtocolHandler.buildFrame(
          TakFrameType.xmlCot,
          payload,
        );
        final split = wire.length ~/ 2;

        // Feed first half.
        final frames1 = handler.feedBytes(wire.sublist(0, split));
        expect(frames1, isEmpty);

        // Feed second half.
        final frames2 = handler.feedBytes(
          Uint8List.fromList(wire.sublist(split)),
        );
        expect(frames2, hasLength(1));
        expect(frames2[0].type, TakFrameType.xmlCot);
        expect(frames2[0].payload, payload);
      });

      test('handles multiple frames in single feedBytes call', () {
        final frame1 = TakProtocolHandler.buildKeepalivePing();
        final frame2 = TakProtocolHandler.buildNegotiation();
        final combined = Uint8List.fromList([...frame1, ...frame2]);

        final frames = handler.feedBytes(combined);
        expect(frames, hasLength(2));
        expect(frames[0].type, TakFrameType.keepalive);
        expect(frames[1].type, TakFrameType.negotiation);
      });

      test('handles three consecutive partial feeds', () {
        final payload = Uint8List.fromList(List.generate(100, (i) => i));
        final wire = TakProtocolHandler.buildFrame(
          TakFrameType.protobufCot,
          payload,
        );

        // Feed byte by byte for the first 10 bytes, then rest.
        for (var i = 0; i < 10; i++) {
          final frames = handler.feedBytes(Uint8List.fromList([wire[i]]));
          expect(frames, isEmpty);
        }
        final frames = handler.feedBytes(Uint8List.fromList(wire.sublist(10)));
        expect(frames, hasLength(1));
        expect(frames[0].payload, payload);
      });
    });

    group('reset', () {
      test('clears internal buffer', () {
        // Feed partial frame.
        handler.feedBytes(Uint8List.fromList([0xBF, 0x00]));
        handler.reset();

        // Feed complete new frame.
        final wire = TakProtocolHandler.buildKeepalivePing();
        final frames = handler.feedBytes(wire);
        expect(frames, hasLength(1));
      });
    });

    group('TakFrameType', () {
      test('fromValue returns correct type', () {
        expect(TakFrameType.fromValue(0), TakFrameType.xmlCot);
        expect(TakFrameType.fromValue(1), TakFrameType.protobufCot);
        expect(TakFrameType.fromValue(2), TakFrameType.negotiation);
        expect(TakFrameType.fromValue(3), TakFrameType.keepalive);
        expect(TakFrameType.fromValue(99), isNull);
      });
    });
  });
}
