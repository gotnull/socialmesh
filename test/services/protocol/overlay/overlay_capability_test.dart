// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the overlay capability TLV codec.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_capability.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

void main() {
  group('OverlayCapabilityCodec roundtrip', () {
    test('supportedFeatures only → 6 bytes on the wire', () {
      final block = OverlayCapabilityBlock(
        supportedFeatures:
            OverlayCapabilityFeature.linkV02 |
            OverlayCapabilityFeature.resourceV02,
      );
      final bytes = OverlayCapabilityCodec.encode(block);
      // TLV: type(1) + len(1) + u32(4) = 6
      expect(bytes.length, 6);
      expect(bytes[0], OverlayCapabilityTlvType.supportedFeatures.code);
      expect(bytes[1], 4);
      expect(bytes.sublist(2), equals(Uint8List.fromList([0x03, 0, 0, 0])));

      final decoded = OverlayCapabilityCodec.decode(bytes).block!;
      expect(decoded.supportsLink, isTrue);
      expect(decoded.supportsResource, isTrue);
      expect(decoded.supportsSecure, isFalse);
      expect(decoded.maxChunkBytes, isNull);
      expect(decoded.maxResourceBytes, isNull);
    });

    test('full block with both limits', () {
      final block = OverlayCapabilityBlock(
        supportedFeatures: OverlayCapabilityFeature.linkV02,
        maxChunkBytes: 128,
        maxResourceBytes: 65535,
      );
      final bytes = OverlayCapabilityCodec.encode(block);
      final decoded = OverlayCapabilityCodec.decode(bytes).block!;
      expect(decoded.supportsLink, isTrue);
      expect(decoded.maxChunkBytes, 128);
      expect(decoded.maxResourceBytes, 65535);
    });
  });

  group('OverlayCapabilityCodec forward compat', () {
    test('unknown TLV types are preserved and do not fail decode', () {
      // Hand-craft: supportedFeatures(known) + unknown TLV(0xFE,len=1,value=1)
      final bytes = Uint8List.fromList(<int>[
        OverlayCapabilityTlvType.supportedFeatures.code,
        4,
        0x01, 0x00, 0x00, 0x00, // supportedFeatures = linkV02
        0xFE,
        1,
        0x42,
      ]);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.isOk, isTrue);
      final block = result.block!;
      expect(block.supportsLink, isTrue);
      expect(block.unknown, hasLength(1));
      expect(block.unknown.first.type, 0xFE);
      expect(block.unknown.first.value.length, 1);
      expect(block.unknown.first.value[0], 0x42);
    });
  });

  group('OverlayCapabilityCodec decode negatives', () {
    test('truncated header → DecodeError.truncatedHeader', () {
      final bytes = Uint8List.fromList(<int>[0x10]); // type byte only
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.truncatedHeader);
    });

    test('truncated value → DecodeError.truncatedValue', () {
      final bytes = Uint8List.fromList(<int>[
        0x10, 4, 0x00, 0x00, // claims 4 bytes, only 2 present
      ]);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.truncatedValue);
    });

    test('block over max size → DecodeError.tooLarge', () {
      final bytes = Uint8List(OverlayCapabilityConstants.maxBlockBytes + 1);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.tooLarge);
    });

    test('supportedFeatures wrong length → DecodeError.badValueLen', () {
      final bytes = Uint8List.fromList(<int>[
        OverlayCapabilityTlvType.supportedFeatures.code,
        2,
        0x00,
        0x00,
      ]);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.badValueLen);
    });

    test('maxChunkBytes wrong length → DecodeError.badValueLen', () {
      final bytes = Uint8List.fromList(<int>[
        OverlayCapabilityTlvType.maxChunkBytes.code,
        4,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.badValueLen);
    });

    test('maxResourceBytes wrong length → DecodeError.badValueLen', () {
      final bytes = Uint8List.fromList(<int>[
        OverlayCapabilityTlvType.maxResourceBytes.code,
        2,
        0x00,
        0x00,
      ]);
      final result = OverlayCapabilityCodec.decode(bytes);
      expect(result.error, OverlayCapabilityDecodeError.badValueLen);
    });
  });

  group('OverlayCapabilityBlock accessors', () {
    test('empty features block reports all false', () {
      const block = OverlayCapabilityBlock(supportedFeatures: 0);
      expect(block.supportsLink, isFalse);
      expect(block.supportsResource, isFalse);
      expect(block.supportsSecure, isFalse);
    });

    test('all three feature bits set', () {
      const block = OverlayCapabilityBlock(
        supportedFeatures: OverlayCapabilityFeature.definedMask,
      );
      expect(block.supportsLink, isTrue);
      expect(block.supportsResource, isTrue);
      expect(block.supportsSecure, isTrue);
    });
  });
}
