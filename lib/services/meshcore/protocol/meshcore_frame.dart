// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore protocol frame definition.
//
// MeshCore frames are simple binary packets with a single-byte command code
// followed by variable-length payload. BLE notifications are always complete
// frames (no extra framing needed).
//
// Frame Format:
// ```
// [command: 1 byte][payload: 0-171 bytes]
// ```
//
// - Total max size: 172 bytes (maxFrameSize)
// - Command codes: 0x01-0x7F (commands to device)
// - Response codes: 0x00-0x7F (responses from device)
// - Push codes: 0x80-0xFF (async events from device)
// - Multi-byte integers: little-endian
// - Strings: often null-terminated or with known fixed lengths
//
// BLE vs USB framing:
// - BLE: Each notification IS a complete frame (no extra framing)
// - USB: Uses direction marker + 2-byte length prefix (handled separately)

import 'dart:typed_data';

/// Maximum frame size in bytes (command + payload).
const int meshCoreMaxFrameSize = 172;

/// Size of the public key in bytes.
const int meshCorePubKeySize = 32;

/// Maximum path size in bytes.
const int meshCoreMaxPathSize = 64;

/// Maximum name size in bytes.
const int meshCoreMaxNameSize = 32;

/// MeshCore protocol version.
const int meshCoreAppProtocolVersion = 3;

/// A MeshCore protocol frame.
///
/// Represents a complete frame with command code and payload.
class MeshCoreFrame {
  /// The command/response/push code (first byte of frame).
  final int command;

  /// The payload bytes (everything after command byte).
  ///
  /// May be empty for simple commands like ping.
  final Uint8List payload;

  const MeshCoreFrame({required this.command, required this.payload});

  /// Create a frame with empty payload.
  MeshCoreFrame.simple(this.command) : payload = Uint8List(0);

  /// Create a frame from raw bytes.
  ///
  /// Throws [ArgumentError] if data is empty.
  factory MeshCoreFrame.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      throw ArgumentError('Frame data cannot be empty');
    }
    return MeshCoreFrame(
      command: data[0],
      payload: data.length > 1 ? Uint8List.sublistView(data, 1) : Uint8List(0),
    );
  }

  /// Convert frame to raw bytes [command][payload].
  Uint8List toBytes() {
    final bytes = Uint8List(1 + payload.length);
    bytes[0] = command;
    bytes.setRange(1, bytes.length, payload);
    return bytes;
  }

  /// Total frame size in bytes.
  int get size => 1 + payload.length;

  /// Whether this is a valid-sized frame.
  bool get isValidSize => size <= meshCoreMaxFrameSize;

  /// Whether this is a response code (0x00-0x7F range, but not a command).
  bool get isResponse => command >= 0x00 && command < 0x80;

  /// Whether this is a push code (async event, 0x80+).
  bool get isPush => command >= 0x80;

  @override
  String toString() =>
      'MeshCoreFrame(cmd=0x${command.toRadixString(16).padLeft(2, '0')}, '
      'len=${payload.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreFrame &&
          command == other.command &&
          _bytesEqual(payload, other.payload);

  @override
  int get hashCode => Object.hash(command, Object.hashAll(payload));

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Helper class for reading binary data sequentially.
///
/// Tracks read position automatically and provides little-endian helpers.
class MeshCoreBufferReader {
  int _position = 0;
  final Uint8List _buffer;

  MeshCoreBufferReader(Uint8List data) : _buffer = Uint8List.fromList(data);

  /// Remaining unread bytes.
  int get remaining => _buffer.length - _position;

  /// Whether there are more bytes to read.
  bool get hasRemaining => remaining > 0;

  /// Current read position.
  int get position => _position;

  /// Read a single byte.
  int readByte() => _buffer[_position++];

  /// Read [count] bytes.
  Uint8List readBytes(int count) {
    final data = Uint8List.sublistView(_buffer, _position, _position + count);
    _position += count;
    return Uint8List.fromList(data);
  }

  /// Skip [count] bytes.
  void skip(int count) {
    _position += count;
  }

  /// Read all remaining bytes.
  Uint8List readRemaining() => readBytes(remaining);

  /// Read a null-terminated string with max length.
  ///
  /// Advances position by min(maxLength, remaining) bytes.
  String readCString(int maxLength) {
    final value = <int>[];
    final actualLength = maxLength.clamp(0, remaining);
    final bytes = readBytes(actualLength);
    for (final byte in bytes) {
      if (byte == 0) break;
      value.add(byte);
    }
    return String.fromCharCodes(value);
  }

  /// Read a string from remaining bytes (may contain nulls).
  String readString() {
    final bytes = readRemaining();
    // Trim trailing nulls
    int end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    return String.fromCharCodes(bytes.sublist(0, end));
  }

  /// Read unsigned 8-bit integer.
  int readUint8() => readByte();

  /// Read signed 8-bit integer.
  int readInt8() =>
      readByte() > 127 ? readByte() - 256 : _buffer[_position - 1];

  /// Read unsigned 16-bit little-endian integer.
  int readUint16LE() {
    final low = readByte();
    final high = readByte();
    return (high << 8) | low;
  }

  /// Read signed 16-bit little-endian integer.
  int readInt16LE() {
    final value = readUint16LE();
    return value > 32767 ? value - 65536 : value;
  }

  /// Read unsigned 32-bit little-endian integer.
  int readUint32LE() {
    final b0 = readByte();
    final b1 = readByte();
    final b2 = readByte();
    final b3 = readByte();
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
  }

  /// Read signed 32-bit little-endian integer.
  int readInt32LE() {
    final value = readUint32LE();
    return value > 2147483647 ? value - 4294967296 : value;
  }
}

/// Helper class for building binary data.
///
/// Accumulates bytes and provides little-endian helpers.
class MeshCoreBufferWriter {
  final BytesBuilder _builder = BytesBuilder();

  /// Get accumulated bytes.
  Uint8List toBytes() => _builder.toBytes();

  /// Current accumulated size.
  int get length => _builder.length;

  /// Write a single byte.
  void writeByte(int byte) => _builder.addByte(byte);

  /// Write multiple bytes.
  void writeBytes(Uint8List bytes) => _builder.add(bytes);

  /// Write unsigned 16-bit little-endian integer.
  void writeUint16LE(int value) {
    writeByte(value & 0xFF);
    writeByte((value >> 8) & 0xFF);
  }

  /// Write unsigned 32-bit little-endian integer.
  void writeUint32LE(int value) {
    writeByte(value & 0xFF);
    writeByte((value >> 8) & 0xFF);
    writeByte((value >> 16) & 0xFF);
    writeByte((value >> 24) & 0xFF);
  }

  /// Write signed 32-bit little-endian integer.
  void writeInt32LE(int value) {
    writeUint32LE(value < 0 ? value + 4294967296 : value);
  }

  /// Write a string (without null terminator).
  void writeString(String string) {
    for (final codeUnit in string.codeUnits) {
      writeByte(codeUnit);
    }
  }

  /// Write a null-terminated string padded to [maxLength].
  ///
  /// Writes exactly [maxLength] bytes, truncating or padding as needed.
  void writeCString(String string, int maxLength) {
    final bytes = Uint8List(maxLength);
    final encoded = string.codeUnits;
    for (int i = 0; i < maxLength - 1 && i < encoded.length; i++) {
      bytes[i] = encoded[i];
    }
    writeBytes(bytes);
  }
}
