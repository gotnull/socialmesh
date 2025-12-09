import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/encoding.dart';

void main() {
  group('HexUtils', () {
    group('toHex', () {
      test('converts empty list to empty string', () {
        expect(HexUtils.toHex([]), '');
      });

      test('converts single byte', () {
        expect(HexUtils.toHex([0]), '00');
        expect(HexUtils.toHex([255]), 'ff');
        expect(HexUtils.toHex([16]), '10');
        expect(HexUtils.toHex([1]), '01');
      });

      test('converts multiple bytes', () {
        expect(HexUtils.toHex([1, 2, 3]), '010203');
        expect(HexUtils.toHex([255, 0, 128]), 'ff0080');
        expect(HexUtils.toHex([0xDE, 0xAD, 0xBE, 0xEF]), 'deadbeef');
      });

      test('pads single digit hex values', () {
        expect(
          HexUtils.toHex([
            0,
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
          ]),
          '000102030405060708090a0b0c0d0e0f',
        );
      });
    });

    group('fromHex', () {
      test('converts empty string to empty bytes', () {
        expect(HexUtils.fromHex(''), Uint8List(0));
      });

      test('converts single byte hex', () {
        expect(HexUtils.fromHex('00'), Uint8List.fromList([0]));
        expect(HexUtils.fromHex('ff'), Uint8List.fromList([255]));
        expect(HexUtils.fromHex('FF'), Uint8List.fromList([255]));
        expect(HexUtils.fromHex('10'), Uint8List.fromList([16]));
      });

      test('converts multiple byte hex', () {
        expect(HexUtils.fromHex('010203'), Uint8List.fromList([1, 2, 3]));
        expect(
          HexUtils.fromHex('deadbeef'),
          Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        );
        expect(
          HexUtils.fromHex('DEADBEEF'),
          Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        );
      });

      test('handles mixed case', () {
        expect(
          HexUtils.fromHex('DeAdBeEf'),
          Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        );
      });

      test('throws for odd length hex string', () {
        expect(() => HexUtils.fromHex('1'), throwsArgumentError);
        expect(() => HexUtils.fromHex('abc'), throwsArgumentError);
      });
    });

    group('formatHex', () {
      test('formats empty list', () {
        expect(HexUtils.formatHex([]), '');
      });

      test('formats single byte with default separator', () {
        expect(HexUtils.formatHex([0xAB]), 'ab');
      });

      test('formats multiple bytes with default separator', () {
        expect(HexUtils.formatHex([0xDE, 0xAD, 0xBE, 0xEF]), 'de ad be ef');
      });

      test('formats with custom separator', () {
        expect(
          HexUtils.formatHex([0xDE, 0xAD, 0xBE, 0xEF], separator: ':'),
          'de:ad:be:ef',
        );
        expect(HexUtils.formatHex([1, 2, 3], separator: '-'), '01-02-03');
        expect(HexUtils.formatHex([1, 2, 3], separator: ''), '010203');
      });
    });

    test('roundtrip conversion', () {
      final original = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF];
      final hex = HexUtils.toHex(original);
      final restored = HexUtils.fromHex(hex);

      expect(restored, Uint8List.fromList(original));
    });
  });

  group('Base64Utils', () {
    group('encode', () {
      test('encodes empty list', () {
        expect(Base64Utils.encode([]), '');
      });

      test('encodes bytes to base64 URL-safe', () {
        expect(Base64Utils.encode([72, 101, 108, 108, 111]), 'SGVsbG8=');
        expect(Base64Utils.encode([0, 1, 2, 3]), 'AAECAw==');
      });

      test('uses URL-safe characters', () {
        // Characters that would be + or / in standard base64
        final bytes = [0xfb, 0xef, 0xbe];
        final encoded = Base64Utils.encode(bytes);
        expect(encoded.contains('+'), isFalse);
        expect(encoded.contains('/'), isFalse);
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        expect(Base64Utils.decode(''), Uint8List(0));
      });

      test('decodes base64 to bytes', () {
        expect(
          Base64Utils.decode('SGVsbG8='),
          Uint8List.fromList([72, 101, 108, 108, 111]),
        );
        expect(
          Base64Utils.decode('AAECAw=='),
          Uint8List.fromList([0, 1, 2, 3]),
        );
      });
    });

    group('isValid', () {
      test('returns true for valid base64', () {
        expect(Base64Utils.isValid('SGVsbG8='), isTrue);
        expect(Base64Utils.isValid('AAECAw=='), isTrue);
        expect(Base64Utils.isValid(''), isTrue);
      });

      test('returns false for invalid base64', () {
        expect(Base64Utils.isValid('not valid!'), isFalse);
        expect(Base64Utils.isValid('!!!'), isFalse);
      });
    });

    test('roundtrip conversion', () {
      final original = [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100];
      final encoded = Base64Utils.encode(original);
      final decoded = Base64Utils.decode(encoded);

      expect(decoded, Uint8List.fromList(original));
    });
  });

  group('CrcUtils', () {
    group('crc16', () {
      test('returns correct CRC for empty data', () {
        expect(CrcUtils.crc16([]), 0xFFFF);
      });

      test('calculates CRC16 for single byte', () {
        final crc = CrcUtils.crc16([0x00]);
        expect(crc, isA<int>());
        expect(crc, lessThanOrEqualTo(0xFFFF));
      });

      test('calculates CRC16 for multiple bytes', () {
        final crc = CrcUtils.crc16([
          0x31,
          0x32,
          0x33,
          0x34,
          0x35,
          0x36,
          0x37,
          0x38,
          0x39,
        ]);
        expect(crc, isA<int>());
        expect(crc, lessThanOrEqualTo(0xFFFF));
      });

      test('different data produces different CRC', () {
        final crc1 = CrcUtils.crc16([1, 2, 3]);
        final crc2 = CrcUtils.crc16([1, 2, 4]);
        expect(crc1, isNot(equals(crc2)));
      });

      test('same data produces same CRC', () {
        final crc1 = CrcUtils.crc16([0xDE, 0xAD, 0xBE, 0xEF]);
        final crc2 = CrcUtils.crc16([0xDE, 0xAD, 0xBE, 0xEF]);
        expect(crc1, crc2);
      });
    });

    group('validateCrc16', () {
      test('validates correct CRC', () {
        final data = [1, 2, 3, 4, 5];
        final crc = CrcUtils.crc16(data);
        expect(CrcUtils.validateCrc16(data, crc), isTrue);
      });

      test('rejects incorrect CRC', () {
        final data = [1, 2, 3, 4, 5];
        expect(CrcUtils.validateCrc16(data, 0x0000), isFalse);
        expect(CrcUtils.validateCrc16(data, 0x1234), isFalse);
      });
    });
  });

  group('ByteUtils', () {
    group('intToBytes (big endian)', () {
      test('converts int to bytes', () {
        expect(ByteUtils.intToBytes(0x12345678, 4), [0x12, 0x34, 0x56, 0x78]);
        expect(ByteUtils.intToBytes(0xFF, 1), [0xFF]);
        expect(ByteUtils.intToBytes(0xFF, 2), [0x00, 0xFF]);
        expect(ByteUtils.intToBytes(0xABCD, 2), [0xAB, 0xCD]);
      });

      test('handles zero', () {
        expect(ByteUtils.intToBytes(0, 4), [0, 0, 0, 0]);
        expect(ByteUtils.intToBytes(0, 1), [0]);
      });
    });

    group('bytesToInt (big endian)', () {
      test('converts bytes to int', () {
        expect(ByteUtils.bytesToInt([0x12, 0x34, 0x56, 0x78]), 0x12345678);
        expect(ByteUtils.bytesToInt([0xFF]), 0xFF);
        expect(ByteUtils.bytesToInt([0x00, 0xFF]), 0xFF);
        expect(ByteUtils.bytesToInt([0xAB, 0xCD]), 0xABCD);
      });

      test('handles empty list', () {
        expect(ByteUtils.bytesToInt([]), 0);
      });

      test('handles zero bytes', () {
        expect(ByteUtils.bytesToInt([0, 0, 0, 0]), 0);
      });
    });

    group('intToBytesLE (little endian)', () {
      test('converts int to bytes little endian', () {
        expect(ByteUtils.intToBytesLE(0x12345678, 4), [0x78, 0x56, 0x34, 0x12]);
        expect(ByteUtils.intToBytesLE(0xABCD, 2), [0xCD, 0xAB]);
        expect(ByteUtils.intToBytesLE(0xFF, 1), [0xFF]);
      });

      test('handles zero', () {
        expect(ByteUtils.intToBytesLE(0, 4), [0, 0, 0, 0]);
      });
    });

    group('bytesToIntLE (little endian)', () {
      test('converts bytes to int little endian', () {
        expect(ByteUtils.bytesToIntLE([0x78, 0x56, 0x34, 0x12]), 0x12345678);
        expect(ByteUtils.bytesToIntLE([0xCD, 0xAB]), 0xABCD);
        expect(ByteUtils.bytesToIntLE([0xFF]), 0xFF);
      });

      test('handles empty list', () {
        expect(ByteUtils.bytesToIntLE([]), 0);
      });
    });

    test('big endian roundtrip', () {
      const original = 0x12345678;
      final bytes = ByteUtils.intToBytes(original, 4);
      final restored = ByteUtils.bytesToInt(bytes);
      expect(restored, original);
    });

    test('little endian roundtrip', () {
      const original = 0x12345678;
      final bytes = ByteUtils.intToBytesLE(original, 4);
      final restored = ByteUtils.bytesToIntLE(bytes);
      expect(restored, original);
    });
  });
}
