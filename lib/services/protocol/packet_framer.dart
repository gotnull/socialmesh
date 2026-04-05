// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';

/// Meshtastic packet framing
///
/// Packets are framed with a magic byte header and length field:
/// [0x94, 0xC3, msb(length), lsb(length), ...payload...]
class PacketFramer {
  static const int _magicByte1 = 0x94;
  static const int _magicByte2 = 0xC3;
  static const int _headerSize = 4;
  static const int _maxPacketSize = 512;

  final List<int> _buffer = [];

  PacketFramer();

  /// Frame a packet for transmission
  static List<int> frame(List<int> payload) {
    if (payload.length > _maxPacketSize) {
      throw Exception('Payload too large: ${payload.length} > $_maxPacketSize');
    }

    final length = payload.length;
    final msb = (length >> 8) & 0xFF;
    final lsb = length & 0xFF;

    return [_magicByte1, _magicByte2, msb, lsb, ...payload];
  }

  /// Track consecutive invalid frames for abuse detection.
  int _consecutiveInvalidFrames = 0;

  /// Total bytes discarded in this session (security metric).
  int _totalBytesDiscarded = 0;

  /// Number of buffer clears due to overflow.
  int _bufferOverflowCount = 0;

  /// Add received data to buffer and extract complete packets
  List<List<int>> addData(List<int> data) {
    _buffer.addAll(data);

    // --- SECURITY AUDIT LOGGING ---
    AppLogging.protocol(
      'FRAMER SECURITY: addData(${data.length} bytes) '
      'bufferSize=${_buffer.length} '
      'consecutiveInvalid=$_consecutiveInvalidFrames '
      'totalDiscarded=$_totalBytesDiscarded '
      'overflowClears=$_bufferOverflowCount',
    );
    // --- END SECURITY AUDIT LOGGING ---

    final packets = <List<int>>[];

    while (true) {
      final packet = _extractPacket();
      if (packet == null) break;
      _consecutiveInvalidFrames = 0; // Reset on valid packet
      packets.add(packet);
    }

    // Prevent buffer from growing indefinitely
    if (_buffer.length > _maxPacketSize * 2) {
      _bufferOverflowCount++;
      _totalBytesDiscarded += _buffer.length;
      AppLogging.protocol(
        '⚠️ FRAMER SECURITY: Buffer overflow #$_bufferOverflowCount — '
        'clearing ${_buffer.length} bytes '
        '(totalDiscarded=$_totalBytesDiscarded)',
      );
      _buffer.clear();
    }

    return packets;
  }

  /// Try to extract a complete packet from the buffer
  List<int>? _extractPacket() {
    // Need at least header
    if (_buffer.length < _headerSize) {
      return null;
    }

    // Look for magic bytes
    int magicIndex = -1;
    for (int i = 0; i < _buffer.length - 1; i++) {
      if (_buffer[i] == _magicByte1 && _buffer[i + 1] == _magicByte2) {
        magicIndex = i;
        break;
      }
    }

    // No magic bytes found
    if (magicIndex == -1) {
      // Keep last byte in case it's the start of magic
      if (_buffer.length > 1) {
        final discarded = _buffer.length - 1;
        _totalBytesDiscarded += discarded;
        _consecutiveInvalidFrames++;
        AppLogging.protocol(
          '⚠️ FRAMER SECURITY: No magic bytes in ${_buffer.length} bytes — '
          'discarding $discarded bytes '
          'consecutiveInvalid=$_consecutiveInvalidFrames '
          'first8=${_buffer.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        _buffer.removeRange(0, _buffer.length - 1);
      }
      return null;
    }

    // Remove bytes before magic
    if (magicIndex > 0) {
      _totalBytesDiscarded += magicIndex;
      AppLogging.protocol(
        '⚠️ FRAMER SECURITY: Discarding $magicIndex bytes before magic '
        '(totalDiscarded=$_totalBytesDiscarded)',
      );
      _buffer.removeRange(0, magicIndex);
    }

    // Check if we have length bytes
    if (_buffer.length < _headerSize) {
      return null;
    }

    // Parse length
    final msb = _buffer[2];
    final lsb = _buffer[3];
    final length = (msb << 8) | lsb;

    // Validate length
    if (length < 0 || length > _maxPacketSize) {
      _consecutiveInvalidFrames++;
      _totalBytesDiscarded += 2;
      AppLogging.protocol(
        '⚠️ FRAMER SECURITY: Invalid packet length=$length '
        '(max=$_maxPacketSize) — consecutiveInvalid=$_consecutiveInvalidFrames '
        'bufferSize=${_buffer.length} '
        'headerHex=${_buffer.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      _buffer.removeRange(0, 2); // Remove magic and try again
      return null;
    }

    // Check if we have complete packet
    final totalSize = _headerSize + length;
    if (_buffer.length < totalSize) {
      return null;
    }

    // Extract payload
    final payload = _buffer.sublist(_headerSize, totalSize);
    _buffer.removeRange(0, totalSize);

    AppLogging.protocol('Extracted packet: $length bytes');
    return payload;
  }

  /// Clear the buffer
  void clear() {
    _buffer.clear();
  }
}
