// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:typed_data';

import '../../core/logging.dart';

/// TAK Protocol v1 frame types.
enum TakFrameType {
  /// XML CoT event.
  xmlCot(0),

  /// Protobuf CoT event.
  protobufCot(1),

  /// Protocol negotiation message.
  negotiation(2),

  /// Keepalive ping/pong.
  keepalive(3);

  const TakFrameType(this.value);
  final int value;

  static TakFrameType? fromValue(int v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

/// A parsed TAK Protocol v1 frame.
class TakFrame {
  final TakFrameType type;
  final Uint8List payload;

  const TakFrame({required this.type, required this.payload});
}

/// Parses and builds TAK Protocol v1 wire frames.
///
/// Wire format: `[0xBF] [type:1] [varint length] [payload]`
///
/// Handles TCP stream reassembly via internal buffer.
class TakProtocolHandler {
  /// Magic byte identifying a TAK Protocol v1 frame.
  static const int magic = 0xBF;

  /// Keepalive interval.
  static const Duration keepaliveInterval = Duration(seconds: 30);

  /// Keepalive response timeout.
  static const Duration keepaliveTimeout = Duration(seconds: 10);

  /// Maximum consecutive missed keepalive pongs before disconnect.
  static const int maxMissedKeepalives = 3;

  /// Maximum frame payload size (64 KB).
  static const int maxPayloadSize = 65536;

  final _buffer = BytesBuilder(copy: false);

  /// Feeds raw bytes from the TCP stream and returns any complete frames.
  List<TakFrame> feedBytes(Uint8List data) {
    _buffer.add(data);
    final buffered = _buffer.takeBytes();
    final frames = <TakFrame>[];
    var offset = 0;

    while (offset < buffered.length) {
      // Need at least magic + type + 1 varint byte = 3 bytes.
      if (offset + 3 > buffered.length) break;

      if (buffered[offset] != magic) {
        AppLogging.tak(
          'Protocol: invalid magic byte 0x${buffered[offset].toRadixString(16)} at offset $offset, skipping',
        );
        offset++;
        continue;
      }

      final typeValue = buffered[offset + 1];
      final frameType = TakFrameType.fromValue(typeValue);
      if (frameType == null) {
        AppLogging.tak('Protocol: unknown frame type $typeValue, skipping');
        offset += 2;
        continue;
      }

      // Parse varint length.
      final varintResult = _readVarint(buffered, offset + 2);
      if (varintResult == null) break; // Need more bytes for varint.

      final payloadLength = varintResult.value;
      final headerEnd = varintResult.nextOffset;

      if (payloadLength > maxPayloadSize) {
        AppLogging.tak(
          'Protocol: payload too large ($payloadLength > $maxPayloadSize), discarding frame',
        );
        offset = headerEnd;
        continue;
      }

      if (headerEnd + payloadLength > buffered.length) {
        break; // Incomplete payload.
      }

      final payload = Uint8List.fromList(
        buffered.sublist(headerEnd, headerEnd + payloadLength),
      );
      frames.add(TakFrame(type: frameType, payload: payload));
      offset = headerEnd + payloadLength;
    }

    // Put unconsumed bytes back in the buffer.
    if (offset < buffered.length) {
      _buffer.add(buffered.sublist(offset));
    }

    return frames;
  }

  /// Serializes a [TakFrame] to wire bytes.
  static Uint8List buildFrame(TakFrameType type, Uint8List payload) {
    final varint = _encodeVarint(payload.length);
    final result = Uint8List(2 + varint.length + payload.length);
    result[0] = magic;
    result[1] = type.value;
    result.setAll(2, varint);
    result.setAll(2 + varint.length, payload);
    return result;
  }

  /// Builds a negotiation frame advertising protocol version 1.
  static Uint8List buildNegotiation() {
    // Negotiation payload: protocol version as single byte.
    final payload = Uint8List.fromList([1]); // TAK Protocol v1
    return buildFrame(TakFrameType.negotiation, payload);
  }

  /// Builds a keepalive ping frame.
  static Uint8List buildKeepalivePing() {
    return buildFrame(TakFrameType.keepalive, Uint8List(0));
  }

  /// Builds a keepalive pong frame (same as ping for TAK Protocol v1).
  static Uint8List buildKeepalivePong() {
    return buildFrame(TakFrameType.keepalive, Uint8List(0));
  }

  /// Builds a frame for an XML CoT event.
  static Uint8List buildXmlCotFrame(String cotXml) {
    return buildFrame(
      TakFrameType.xmlCot,
      Uint8List.fromList(cotXml.codeUnits),
    );
  }

  /// Builds a frame for a protobuf CoT event.
  static Uint8List buildProtobufCotFrame(Uint8List protobufBytes) {
    return buildFrame(TakFrameType.protobufCot, protobufBytes);
  }

  /// Resets the internal buffer (e.g., on connection close).
  void reset() {
    _buffer.clear();
  }

  // --- Varint helpers ---

  static ({int value, int nextOffset})? _readVarint(
    Uint8List data,
    int offset,
  ) {
    var value = 0;
    var shift = 0;
    var pos = offset;

    while (pos < data.length) {
      final byte = data[pos];
      value |= (byte & 0x7F) << shift;
      pos++;
      if ((byte & 0x80) == 0) {
        return (value: value, nextOffset: pos);
      }
      shift += 7;
      if (shift > 28) return null; // Varint too long.
    }

    return null; // Incomplete varint.
  }

  static Uint8List _encodeVarint(int value) {
    if (value < 0) return Uint8List.fromList([0]);
    final bytes = <int>[];
    var v = value;
    do {
      var byte = v & 0x7F;
      v >>= 7;
      if (v > 0) byte |= 0x80;
      bytes.add(byte);
    } while (v > 0);
    return Uint8List.fromList(bytes);
  }
}
