// SPDX-License-Identifier: GPL-3.0-or-later
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

  /// Normalize base64 padding and decode.
  ///
  /// Handles both standard base64 (+/) and URL-safe base64 (-_).
  /// Adds missing padding characters (=) if needed.
  static Uint8List decodeWithPadding(String str) {
    // Normalize URL-safe to standard base64
    String normalized = str.replaceAll('-', '+').replaceAll('_', '/');

    // Add padding if needed
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized = normalized.padRight(
        normalized.length + (4 - remainder),
        '=',
      );
    }

    return base64Decode(normalized);
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

/// Channel key utilities for encryption key management
class ChannelKeyUtils {
  /// Encode key bytes to standard base64 string
  static String keyToBase64(List<int> key) {
    if (key.isEmpty) return '';
    if (key.length == 1 && key[0] == 1) return 'AQ=='; // Default key marker
    return base64.encode(key);
  }

  /// Decode base64 string to key bytes, returns null if invalid
  static List<int>? base64ToKey(String base64String) {
    if (base64String.isEmpty) return [];
    try {
      return base64.decode(base64String.trim());
    } catch (e) {
      return null;
    }
  }

  /// Validate if a base64 key has a valid encryption size
  /// Returns the detected key size in bytes, or null if invalid
  static int? validateKeySize(String base64String) {
    final key = base64ToKey(base64String);
    if (key == null) return null;
    final bytes = key.length;
    // Valid sizes: 0 (none), 1 (default), 16 (AES-128), 32 (AES-256)
    if (bytes == 0 || bytes == 1 || bytes == 16 || bytes == 32) {
      return bytes;
    }
    return null;
  }

  /// Check if key matches expected byte length
  static bool isKeyValidForSize(String base64String, int expectedBytes) {
    final key = base64ToKey(base64String);
    if (key == null) return false;
    if (expectedBytes == 0) return key.isEmpty;
    if (expectedBytes == 1) return true; // Any key works for default
    return key.length == expectedBytes;
  }

  /// Get short display name for key size (e.g., "AES-256")
  static String getKeySizeDisplayName(int bytes) {
    switch (bytes) {
      case 0:
        return 'No Encryption';
      case 1:
        return 'Default (Simple)';
      case 16:
        return 'AES-128';
      case 32:
        return 'AES-256';
      default:
        return '$bytes bytes';
    }
  }

  /// Get detailed display string for key size (e.g., "32 bytes · AES-256")
  static String getKeySizeDetailedDisplay(int bytes) {
    switch (bytes) {
      case 0:
        return '';
      case 1:
        return '1 byte · Default PSK';
      case 16:
        return '16 bytes · AES-128';
      case 32:
        return '32 bytes · AES-256';
      default:
        return '$bytes bytes';
    }
  }
}
