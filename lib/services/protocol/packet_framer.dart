import 'package:logger/logger.dart';

/// Meshtastic packet framing
///
/// Packets are framed with a magic byte header and length field:
/// [0x94, 0xC3, msb(length), lsb(length), ...payload...]
class PacketFramer {
  static const int _magicByte1 = 0x94;
  static const int _magicByte2 = 0xC3;
  static const int _headerSize = 4;
  static const int _maxPacketSize = 512;

  final Logger _logger;
  final List<int> _buffer = [];

  PacketFramer({Logger? logger}) : _logger = logger ?? Logger();

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

  /// Add received data to buffer and extract complete packets
  List<List<int>> addData(List<int> data) {
    _buffer.addAll(data);

    final packets = <List<int>>[];

    while (true) {
      final packet = _extractPacket();
      if (packet == null) break;
      packets.add(packet);
    }

    // Prevent buffer from growing indefinitely
    if (_buffer.length > _maxPacketSize * 2) {
      _logger.w('Buffer too large (${_buffer.length}), clearing');
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
        _buffer.removeRange(0, _buffer.length - 1);
      }
      return null;
    }

    // Remove bytes before magic
    if (magicIndex > 0) {
      _logger.w('Discarding $magicIndex bytes before magic');
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
      _logger.e('Invalid packet length: $length');
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

    _logger.d('Extracted packet: $length bytes');
    return payload;
  }

  /// Clear the buffer
  void clear() {
    _buffer.clear();
  }
}
