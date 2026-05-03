// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('publicKeyFingerprint', () {
    test('null and empty render as 0B:none', () {
      expect(AppLogging.publicKeyFingerprint(null), '0B:none');
      expect(AppLogging.publicKeyFingerprint(const []), '0B:none');
    });

    test('keys ≤8 bytes render full hex with length prefix', () {
      expect(
        AppLogging.publicKeyFingerprint([0x01, 0x02, 0x03, 0x04]),
        '4B:01020304',
      );
      expect(
        AppLogging.publicKeyFingerprint([
          0xaa,
          0xbb,
          0xcc,
          0xdd,
          0xee,
          0xff,
          0x00,
          0x11,
        ]),
        '8B:aabbccddeeff0011',
      );
    });

    test('larger keys are truncated to first4…last4', () {
      // 32-byte canonical Ed25519 public key
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final fp = AppLogging.publicKeyFingerprint(key);
      expect(fp, '32B:00010203…1c1d1e1f');
    });

    test('full key never appears in output for keys > 8 bytes', () {
      final key = List.generate(32, (i) => 0xff);
      final fullHex = key
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final fp = AppLogging.publicKeyFingerprint(key);
      expect(fp.contains(fullHex), isFalse);
    });
  });

  group('nodeIdShort', () {
    test('null renders as none', () {
      expect(AppLogging.nodeIdShort(null), 'none');
    });

    test('zero pads to 8 hex digits', () {
      expect(AppLogging.nodeIdShort(0), '0x00000000');
      expect(AppLogging.nodeIdShort(0x12), '0x00000012');
    });

    test('large node id formatted uppercase 0xAABBCCDD', () {
      expect(AppLogging.nodeIdShort(0xaabbccdd), '0xAABBCCDD');
    });
  });

  group('coordRedact', () {
    setUp(() {
      AppLogging.reset();
    });
    tearDown(() {
      AppLogging.reset();
    });

    test('returns "redacted" when location flag is off (default)', () {
      // Flag defaults to false in test env.
      expect(AppLogging.coordRedact(37.7749, -122.4194), 'redacted');
    });
  });

  group('framePreview', () {
    test('null renders as len=0 head=()', () {
      expect(AppLogging.framePreview(null), 'len=0 head=()');
    });

    test('short frame fits within head', () {
      expect(
        AppLogging.framePreview([0x01, 0x02, 0x03]),
        'len=3 head=01 02 03',
      );
    });

    test('long frame is bounded with ellipsis', () {
      final bytes = List<int>.generate(64, (i) => i);
      final preview = AppLogging.framePreview(bytes);
      expect(preview.startsWith('len=64 head='), isTrue);
      expect(preview.endsWith('…'), isTrue);
      // Should only contain hex for the first 16 bytes, not all 64.
      // Each byte = 2 hex chars + 1 space = 3 chars; 16 bytes = 48 - 1 = 47.
      expect(preview.split('head=').last.length, lessThan(60));
    });

    test('max parameter clamps preview length', () {
      final bytes = List<int>.generate(64, (i) => i);
      final preview = AppLogging.framePreview(bytes, max: 4);
      expect(preview, 'len=64 head=00 01 02 03 …');
    });

    test('max parameter is hard-capped at 32', () {
      final bytes = List<int>.generate(64, (i) => i);
      final preview = AppLogging.framePreview(bytes, max: 1024);
      // Should still cap at 32 bytes.
      final headPart = preview.split('head=').last;
      // 32 bytes worth = 32 hex pairs, 31 spaces between them, plus " …"
      // = 32*2 + 31 = 95 chars, then ' …' = 97 total.
      expect(headPart.length, lessThanOrEqualTo(100));
    });
  });
}
