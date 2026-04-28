// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// HDLC byte-stuffing codec for the Reticulum TCPInterface wire format
// used by rnsd. Source-anchored to markqvist/Reticulum
// (RNS/Interfaces/TCPInterface.py) and byte-confirmed against
// test/fixtures/reticulum/tcp_capture_v1.bin. Findings doc:
// tools/rns_bridge/tcp_capture/FINDINGS.md.
//
// Wire format: [0x7E] [escape(payload)] [0x7E]
//   0x7D  →  0x7D 0x5D   (ESC ^ 0x20)
//   0x7E  →  0x7D 0x5E   (FLAG ^ 0x20)
//
// Decoder is stateful: persistent buffer across recv() chunks, with
// the closing FLAG of one frame retained as the opener of the next
// (matches upstream `frame_buffer[end:]`).

import 'dart:typed_data';

const int hdlcFlag = 0x7E;
const int hdlcEsc = 0x7D;
const int hdlcEscMask = 0x20;

/// Minimum unescaped body length the upstream RNS `TCPInterface`
/// decoder accepts. Frames at or below this are silently dropped.
const int kReticulumTcpMinFrameSize = 19;

/// Thrown by [HdlcFrameDecoder.feed] when the byte stream contains a
/// malformed escape sequence — either an `0x7D` followed by a byte
/// other than `0x5D` / `0x5E`, or an `0x7D` immediately preceding a
/// closing FLAG (no follower byte).
class HdlcDecodeError implements Exception {
  HdlcDecodeError(this.reason);
  final String reason;
  @override
  String toString() => 'HdlcDecodeError: $reason';
}

/// Pure HDLC encode helper.
class ReticulumTcpFraming {
  const ReticulumTcpFraming._();

  /// Encode [body] as a single HDLC frame:
  /// `0x7E + escape(body) + 0x7E`.
  ///
  /// Escapes `0x7D` before `0x7E`. Byte order matters — see class
  /// docs.
  static Uint8List encodeFrame(List<int> body) {
    final out = BytesBuilder(copy: false);
    out.addByte(hdlcFlag);
    for (final b in body) {
      if (b == hdlcEsc) {
        out.addByte(hdlcEsc);
        out.addByte(hdlcEsc ^ hdlcEscMask);
      } else if (b == hdlcFlag) {
        out.addByte(hdlcEsc);
        out.addByte(hdlcFlag ^ hdlcEscMask);
      } else {
        out.addByte(b);
      }
    }
    out.addByte(hdlcFlag);
    return out.toBytes();
  }
}

/// Stateful HDLC frame decoder.
///
/// Feed raw socket bytes via [feed]; whole frames (already unescaped
/// and size-gated) are returned. The decoder keeps an internal byte
/// buffer so partial frames from short `recv()` calls are stitched
/// across calls.
class HdlcFrameDecoder {
  HdlcFrameDecoder({this.minFrameSize = kReticulumTcpMinFrameSize});

  /// Frames whose unescaped body length is `<= minFrameSize` are
  /// silently dropped and counted in [droppedUndersize]. Default
  /// matches upstream RNS (`HEADER_MINSIZE = 19`).
  final int minFrameSize;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  int _droppedUndersize = 0;

  /// Number of frames that decoded cleanly but failed the
  /// [minFrameSize] gate. Increments silently — caller can surface in
  /// diagnostics.
  int get droppedUndersize => _droppedUndersize;

  /// Bytes buffered awaiting more input or a closing FLAG. Useful for
  /// tests and diagnostics.
  int get bufferedBytes => _buffer.length;

  /// Feed the next chunk from `socket.recv()`. Returns every complete
  /// frame surfaced by this chunk (zero, one, or many).
  ///
  /// Throws [HdlcDecodeError] on a malformed escape sequence inside a
  /// completed frame. The internal buffer is rewound past the bad
  /// frame so subsequent calls can recover.
  List<Uint8List> feed(List<int> chunk) {
    _buffer.add(chunk);
    final frames = <Uint8List>[];
    while (true) {
      final raw = _buffer.toBytes();
      final start = _indexOf(raw, hdlcFlag, 0);
      if (start < 0) {
        // No FLAG at all yet — keep buffering, but discard pre-FLAG
        // junk to bound memory.
        _buffer.clear();
        return frames;
      }
      final end = _indexOf(raw, hdlcFlag, start + 1);
      if (end < 0) {
        // Have an opening FLAG but no closer yet. Keep from `start`
        // onward and wait for more data.
        if (start > 0) {
          _buffer.clear();
          _buffer.add(raw.sublist(start));
        }
        return frames;
      }
      // Bytes between the two FLAGs are the escaped frame body.
      final escaped = raw.sublist(start + 1, end);
      // Slide the buffer so the closing FLAG remains as the next
      // frame's opener (matches upstream `frame_buffer[end:]`).
      _buffer.clear();
      _buffer.add(raw.sublist(end));
      try {
        final decoded = _unescape(escaped);
        if (decoded.length <= minFrameSize) {
          _droppedUndersize++;
          continue;
        }
        frames.add(decoded);
      } on HdlcDecodeError {
        // Re-throw so caller can decide whether to tear the socket
        // down. The buffer has already been advanced past the bad
        // frame so a retry will resume cleanly.
        rethrow;
      }
    }
  }

  /// Reset the internal buffer and counters. Use on socket reconnect.
  void reset() {
    _buffer.clear();
    _droppedUndersize = 0;
  }

  static int _indexOf(Uint8List bytes, int byte, int from) {
    for (var i = from; i < bytes.length; i++) {
      if (bytes[i] == byte) return i;
    }
    return -1;
  }

  static Uint8List _unescape(Uint8List escaped) {
    final out = BytesBuilder(copy: false);
    var i = 0;
    while (i < escaped.length) {
      final b = escaped[i];
      if (b == hdlcEsc) {
        if (i + 1 >= escaped.length) {
          throw HdlcDecodeError('trailing ESC with no follower');
        }
        final nxt = escaped[i + 1];
        if (nxt == (hdlcEsc ^ hdlcEscMask)) {
          out.addByte(hdlcEsc);
        } else if (nxt == (hdlcFlag ^ hdlcEscMask)) {
          out.addByte(hdlcFlag);
        } else {
          throw HdlcDecodeError(
            'invalid escape 0x7D followed by 0x${nxt.toRadixString(16)}',
          );
        }
        i += 2;
      } else {
        out.addByte(b);
        i++;
      }
    }
    return out.toBytes();
  }
}
