// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/meshcore_usb_framing.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';

// Tests for MeshCore USB serial framing.
//
// USB transport uses direction markers + length prefix:
// - App -> Radio: '<' (0x3C) + 2-byte LE length + payload
// - Radio -> App: '>' (0x3E) + 2-byte LE length + payload
//
// BLE does NOT use this framing - each BLE notification is raw payload.

void main() {
  group('MeshCoreUsbEncoder', () {
    group('frame()', () {
      test('frames a simple payload for radio', () {
        final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
        final framed = MeshCoreUsbEncoder.frame(payload);

        expect(framed.length, equals(MeshCoreUsbMarkers.headerSize + 3));

        // Check marker (app -> radio = '<')
        expect(framed[0], equals(MeshCoreUsbMarkers.appToRadio));
        expect(framed[0], equals(0x3C));

        // Check length (little-endian)
        expect(framed[1], equals(3)); // LSB
        expect(framed[2], equals(0)); // MSB

        // Check payload
        expect(framed[3], equals(0x01));
        expect(framed[4], equals(0x02));
        expect(framed[5], equals(0x03));
      });

      test('frames a large payload with correct little-endian length', () {
        final payload = Uint8List.fromList(List.generate(200, (i) => i % 256));
        final framed = MeshCoreUsbEncoder.frame(payload);

        expect(framed.length, equals(MeshCoreUsbMarkers.headerSize + 200));

        // Check length encoding (200 = 0xC8)
        expect(framed[1], equals(200)); // LSB
        expect(framed[2], equals(0)); // MSB
      });

      test('correctly encodes length > 255', () {
        final payload = Uint8List.fromList(
          List.generate(MeshCoreUsbMarkers.maxPayloadSize, (i) => i % 256),
        );
        final framed = MeshCoreUsbEncoder.frame(payload);

        // 250 = 0xFA -> LSB=0xFA, MSB=0x00
        expect(framed[1], equals(250)); // LSB
        expect(framed[2], equals(0)); // MSB
      });

      test('throws on empty payload', () {
        expect(
          () => MeshCoreUsbEncoder.frame(Uint8List(0)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on payload exceeding max size', () {
        final oversizedPayload = Uint8List.fromList(
          List.generate(MeshCoreUsbMarkers.maxPayloadSize + 1, (i) => i % 256),
        );

        expect(
          () => MeshCoreUsbEncoder.frame(oversizedPayload),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('frames MeshCoreFrame correctly', () {
        final frame = MeshCoreFrame(
          command: MeshCoreCommands.appStart,
          payload: Uint8List.fromList([0x01, 0x02]),
        );
        final framed = MeshCoreUsbEncoder.frameMessage(frame);

        expect(framed.length, equals(MeshCoreUsbMarkers.headerSize + 3));
        expect(framed[0], equals(MeshCoreUsbMarkers.appToRadio));
        expect(framed[1], equals(3)); // length
        expect(framed[2], equals(0));
        expect(framed[3], equals(MeshCoreCommands.appStart));
        expect(framed[4], equals(0x01));
        expect(framed[5], equals(0x02));
      });
    });
  });

  group('MeshCoreUsbDecoder', () {
    late MeshCoreUsbDecoder decoder;

    setUp(() {
      decoder = MeshCoreUsbDecoder();
    });

    test('extracts a complete frame from single chunk', () {
      // Simulate frame from radio: '>' + length(LE) + payload
      final payload = [0x01, 0x02, 0x03];
      final frame = [
        MeshCoreUsbMarkers.radioToApp, // '>'
        payload.length, 0, // length in little-endian
        ...payload,
      ];

      final extracted = decoder.addData(frame);

      expect(extracted.length, equals(1));
      expect(extracted[0], equals(Uint8List.fromList(payload)));
    });

    test('extracts multiple frames from single chunk', () {
      final payload1 = [0x01, 0x02];
      final payload2 = [0x03, 0x04, 0x05];

      final frame1 = [MeshCoreUsbMarkers.radioToApp, 2, 0, ...payload1];
      final frame2 = [MeshCoreUsbMarkers.radioToApp, 3, 0, ...payload2];

      final combined = [...frame1, ...frame2];
      final extracted = decoder.addData(combined);

      expect(extracted.length, equals(2));
      expect(extracted[0], equals(Uint8List.fromList(payload1)));
      expect(extracted[1], equals(Uint8List.fromList(payload2)));
    });

    test('handles split frames across multiple notifications', () {
      final payload = [0x01, 0x02, 0x03, 0x04];
      final frame = [MeshCoreUsbMarkers.radioToApp, 4, 0, ...payload];

      // Split in the middle
      final part1 = frame.sublist(0, 4);
      final part2 = frame.sublist(4);

      // First part should not produce output
      final extracted1 = decoder.addData(part1);
      expect(extracted1, isEmpty);

      // Second part should complete the frame
      final extracted2 = decoder.addData(part2);
      expect(extracted2.length, equals(1));
      expect(extracted2[0], equals(Uint8List.fromList(payload)));
    });

    test('handles split frames at header boundary', () {
      final payload = [0x10, 0x20];
      final frame = [MeshCoreUsbMarkers.radioToApp, 2, 0, ...payload];

      // Split at header boundary (2 bytes - just marker and LSB)
      final part1 = frame.sublist(0, 2);
      final part2 = frame.sublist(2);

      final extracted1 = decoder.addData(part1);
      expect(extracted1, isEmpty);

      final extracted2 = decoder.addData(part2);
      expect(extracted2.length, equals(1));
      expect(extracted2[0], equals(Uint8List.fromList(payload)));
    });

    test('handles byte-by-byte arrival', () {
      final payload = [0x55, 0xAA];
      final frame = [MeshCoreUsbMarkers.radioToApp, 2, 0, ...payload];

      List<Uint8List> allExtracted = [];
      for (final byte in frame) {
        allExtracted.addAll(decoder.addData([byte]));
      }

      expect(allExtracted.length, equals(1));
      expect(allExtracted[0], equals(Uint8List.fromList(payload)));
    });

    test('rejects frame with invalid length (zero)', () {
      // Frame with length = 0
      final invalidFrame = [
        MeshCoreUsbMarkers.radioToApp,
        0, 0, // Length = 0
      ];

      final extracted = decoder.addData(invalidFrame);
      expect(extracted, isEmpty);
    });

    test('rejects frame with length exceeding max', () {
      // Frame with length > maxPayloadSize
      final invalidFrame = [
        MeshCoreUsbMarkers.radioToApp,
        0xFF, 0xFF, // Length = 65535 (way too large)
      ];

      final extracted = decoder.addData(invalidFrame);
      expect(extracted, isEmpty);
    });

    test('discards garbage bytes before marker', () {
      final payload = [0x77];
      final frame = [MeshCoreUsbMarkers.radioToApp, 1, 0, ...payload];

      // Add garbage before the frame
      final withGarbage = [0xFF, 0xFE, 0xFD, ...frame];

      final extracted = decoder.addData(withGarbage);
      expect(extracted.length, equals(1));
      expect(extracted[0], equals(Uint8List.fromList(payload)));
    });

    test('recovers after invalid length', () {
      // First, an invalid frame
      final invalidFrame = [
        MeshCoreUsbMarkers.radioToApp,
        0xFF, 0xFF, // Invalid length
      ];

      // Then a valid frame
      final payload = [0x99];
      final validFrame = [MeshCoreUsbMarkers.radioToApp, 1, 0, ...payload];

      final combined = [...invalidFrame, ...validFrame];
      final extracted = decoder.addData(combined);

      expect(extracted.length, equals(1));
      expect(extracted[0], equals(Uint8List.fromList(payload)));
    });

    test('clears buffer when it grows too large', () {
      // Fill buffer with garbage
      final garbage = List.generate(meshCoreMaxFrameSize * 3, (i) => i % 256);

      // This should trigger buffer clear
      decoder.addData(garbage);

      // Now a valid frame should still work
      final payload = [0x11, 0x22];
      final validFrame = [MeshCoreUsbMarkers.radioToApp, 2, 0, ...payload];

      final extracted = decoder.addData(validFrame);
      expect(extracted.length, equals(1));
      expect(extracted[0], equals(Uint8List.fromList(payload)));
    });

    test('clear() resets buffer', () {
      // Add partial data
      final partial = [MeshCoreUsbMarkers.radioToApp, 5, 0]; // Length = 5
      decoder.addData(partial);
      expect(decoder.bufferLength, greaterThan(0));

      // Clear and verify
      decoder.clear();
      expect(decoder.bufferLength, equals(0));
    });

    test('ignores frames with wrong direction marker', () {
      // Frame with '<' marker (app -> radio) should not be found
      // when looking for '>' (radio -> app)
      final frame = [MeshCoreUsbMarkers.appToRadio, 2, 0, 0x11, 0x22];

      final extracted = decoder.addData(frame);
      expect(extracted, isEmpty);
    });
  });

  group('MeshCoreFrame integration', () {
    test('roundtrip: frame -> USB encode -> USB decode -> frame', () {
      // Create original frame
      final originalFrame = MeshCoreFrame(
        command: MeshCoreCommands.getContacts,
        payload: Uint8List.fromList([0x00, 0x00, 0x00, 0x00]),
      );

      // Encode for USB (simulating what would be sent)
      final usbEncoded = MeshCoreUsbEncoder.frameMessage(originalFrame);

      // Simulate receiving it back (change marker from '<' to '>')
      final asReceived = Uint8List.fromList([
        MeshCoreUsbMarkers.radioToApp, // Change direction marker
        ...usbEncoded.sublist(1), // Keep length and payload
      ]);

      // Decode USB framing
      final decoder = MeshCoreUsbDecoder();
      final payloads = decoder.addData(asReceived);

      expect(payloads.length, equals(1));

      // Parse back to frame
      final decodedFrame = MeshCoreFrame.fromBytes(payloads[0]);

      expect(decodedFrame.command, equals(originalFrame.command));
      expect(decodedFrame.payload, equals(originalFrame.payload));
    });

    test('BLE vs USB: same payload, different transport framing', () {
      // Create a frame
      final frame = MeshCoreFrame.simple(MeshCoreCommands.appStart);
      final rawPayload = frame.toBytes();

      // BLE: raw payload is sent directly
      expect(rawPayload.length, equals(1));
      expect(rawPayload[0], equals(MeshCoreCommands.appStart));

      // USB: payload is wrapped with header
      final usbFramed = MeshCoreUsbEncoder.frame(rawPayload);
      expect(usbFramed.length, equals(4)); // header (3) + payload (1)
      expect(usbFramed[0], equals(MeshCoreUsbMarkers.appToRadio));
      expect(usbFramed[1], equals(1)); // length
      expect(usbFramed[2], equals(0));
      expect(usbFramed[3], equals(MeshCoreCommands.appStart));

      // Both produce the same inner payload
      final decoder = MeshCoreUsbDecoder();
      final usbReceived = [MeshCoreUsbMarkers.radioToApp, 1, 0, rawPayload[0]];
      final extracted = decoder.addData(usbReceived);

      expect(extracted[0], equals(rawPayload));
    });
  });

  group('Protocol constants', () {
    test('USB markers are correct ASCII', () {
      expect(MeshCoreUsbMarkers.appToRadio, equals(0x3C)); // '<'
      expect(MeshCoreUsbMarkers.radioToApp, equals(0x3E)); // '>'
    });

    test('header size is marker + 2-byte length', () {
      expect(MeshCoreUsbMarkers.headerSize, equals(3));
    });

    test('max payload size is reasonable', () {
      expect(MeshCoreUsbMarkers.maxPayloadSize, equals(250));
      expect(
        MeshCoreUsbMarkers.maxPayloadSize,
        greaterThan(meshCoreMaxFrameSize),
      );
    });
  });
}
