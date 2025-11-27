import 'dart:convert';
import 'dart:typed_data';

/// Hex encoding utilities
class HexUtils {
  /// Convert bytes to hex string
  static String toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert hex string to bytes
  static Uint8List fromHex(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Hex string must have even length');
    }

    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  /// Format bytes as readable hex string (e.g., "01 23 45 67")
  static String formatHex(List<int> bytes, {String separator = ' '}) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(separator);
  }
}

/// Base64 utilities
class Base64Utils {
  /// Encode bytes to base64 URL-safe string
  static String encode(List<int> bytes) {
    return base64Url.encode(bytes);
  }

  /// Decode base64 URL-safe string to bytes
  static Uint8List decode(String str) {
    return base64Url.decode(str);
  }

  /// Check if string is valid base64
  static bool isValid(String str) {
    try {
      base64Url.decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// CRC utilities for packet validation
class CrcUtils {
  /// Calculate CRC16 checksum (CCITT-FALSE)
  static int crc16(List<int> data) {
    int crc = 0xFFFF;

    for (final byte in data) {
      crc ^= byte << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc = crc << 1;
        }
      }
    }

    return crc & 0xFFFF;
  }

  /// Validate CRC16 checksum
  static bool validateCrc16(List<int> data, int expectedCrc) {
    return crc16(data) == expectedCrc;
  }
}

/// Byte array utilities
class ByteUtils {
  /// Convert int to bytes (big endian)
  static List<int> intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = length - 1; i >= 0; i--) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  /// Convert bytes to int (big endian)
  static int bytesToInt(List<int> bytes) {
    int value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
    }
    return value;
  }

  /// Convert int to bytes (little endian)
  static List<int> intToBytesLE(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  /// Convert bytes to int (little endian)
  static int bytesToIntLE(List<int> bytes) {
    int value = 0;
    for (int i = bytes.length - 1; i >= 0; i--) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }
}
