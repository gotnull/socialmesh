// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore USB serial framing.
//
// MeshCore USB transport uses direction markers + length prefix framing:
// - App -> Radio: '<' (0x3C) + 2-byte LE length + payload
// - Radio -> App: '>' (0x3E) + 2-byte LE length + payload
//
// BLE transport does NOT use this - each BLE notification is a raw payload.
// This file is ONLY for USB/serial transports.

import 'dart:typed_data';

import 'protocol/meshcore_frame.dart';

/// USB frame direction markers.
class MeshCoreUsbMarkers {
  MeshCoreUsbMarkers._();

  /// Marker for outbound frames (radio -> app).
  /// Frames received from the radio start with this byte.
  static const int radioToApp = 0x3E; // '>'

  /// Marker for inbound frames (app -> radio).
  /// Frames sent to the radio start with this byte.
  static const int appToRadio = 0x3C; // '<'

  /// Header size: marker (1) + length (2).
  static const int headerSize = 3;

  /// Maximum payload size for USB framing.
  /// This is larger than BLE's maxFrameSize to allow for flexibility.
  static const int maxPayloadSize = 250;
}

/// MeshCore USB framing for outbound packets.
///
/// Use this to frame payloads before sending over USB/serial transport.
/// Do NOT use for BLE - BLE sends raw payloads directly.
class MeshCoreUsbEncoder {
  MeshCoreUsbEncoder._();

  /// Frame a payload for sending TO the radio (app -> radio).
  ///
  /// Returns: [0x3C, lengthLSB, lengthMSB, ...payload]
  static Uint8List frame(Uint8List payload) {
    if (payload.isEmpty) {
      throw ArgumentError('Payload cannot be empty');
    }
    if (payload.length > MeshCoreUsbMarkers.maxPayloadSize) {
      throw ArgumentError(
        'Payload too large: ${payload.length} > ${MeshCoreUsbMarkers.maxPayloadSize}',
      );
    }

    final length = payload.length;
    final lsb = length & 0xFF;
    final msb = (length >> 8) & 0xFF;

    final result = Uint8List(MeshCoreUsbMarkers.headerSize + payload.length);
    result[0] = MeshCoreUsbMarkers.appToRadio;
    result[1] = lsb;
    result[2] = msb;
    result.setRange(3, result.length, payload);
    return result;
  }

  /// Frame a MeshCoreFrame for USB transport.
  static Uint8List frameMessage(MeshCoreFrame message) {
    return frame(message.toBytes());
  }
}

/// MeshCore USB deframing for inbound packets.
///
/// Accumulates USB serial data and extracts complete MeshCore payloads.
/// Each extracted payload can be passed to MeshCoreFrame.fromBytes().
class MeshCoreUsbDecoder {
  final List<int> _buffer = [];

  /// Add received USB data and extract complete payloads.
  ///
  /// Returns list of raw payloads (without USB framing).
  /// Each payload is a complete MeshCore message ready for parsing.
  List<Uint8List> addData(List<int> data) {
    _buffer.addAll(data);

    final payloads = <Uint8List>[];

    while (true) {
      final payload = _extractPayload();
      if (payload == null) break;
      payloads.add(payload);
    }

    // Prevent buffer from growing indefinitely with garbage
    if (_buffer.length > meshCoreMaxFrameSize * 2) {
      _buffer.clear();
    }

    return payloads;
  }

  Uint8List? _extractPayload() {
    // Need at least header
    if (_buffer.length < MeshCoreUsbMarkers.headerSize) {
      return null;
    }

    // Find direction marker for incoming (radio -> app)
    int markerIndex = -1;
    for (int i = 0; i < _buffer.length; i++) {
      if (_buffer[i] == MeshCoreUsbMarkers.radioToApp) {
        markerIndex = i;
        break;
      }
    }

    if (markerIndex == -1) {
      // No marker found - clear garbage
      _buffer.clear();
      return null;
    }

    // Discard bytes before marker
    if (markerIndex > 0) {
      _buffer.removeRange(0, markerIndex);
    }

    // Check if we have length bytes
    if (_buffer.length < MeshCoreUsbMarkers.headerSize) {
      return null;
    }

    // Parse length (little-endian)
    final lsb = _buffer[1];
    final msb = _buffer[2];
    final payloadLength = lsb | (msb << 8);

    // Validate length
    if (payloadLength <= 0 ||
        payloadLength > MeshCoreUsbMarkers.maxPayloadSize) {
      // Invalid length - skip marker and continue
      _buffer.removeAt(0);
      return _extractPayload();
    }

    // Check if we have complete frame
    final totalSize = MeshCoreUsbMarkers.headerSize + payloadLength;
    if (_buffer.length < totalSize) {
      return null;
    }

    // Extract payload
    final payload = Uint8List.fromList(
      _buffer.sublist(MeshCoreUsbMarkers.headerSize, totalSize),
    );

    // Remove frame from buffer
    _buffer.removeRange(0, totalSize);

    return payload;
  }

  /// Clear the internal buffer.
  void clear() {
    _buffer.clear();
  }

  /// Get current buffer length (for debugging).
  int get bufferLength => _buffer.length;
}
