// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../core/logging.dart';

/// Logging wrapper for the Reticulum tunnel subsystem.
///
/// Enforces the logging contract by accepting **only** metadata fields
/// (node IDs, packet IDs, sizes, counts). No method on this class accepts
/// `Uint8List` or any other byte-buffer type — capture files are the
/// single sanctioned destination for raw fragment payloads.
class ReticulumSafeLog {
  const ReticulumSafeLog._();

  /// Generic structured log line. Caller must produce a metadata-only
  /// string; payload bytes must never appear in [message].
  static void event(String message) {
    AppLogging.reticulum(message);
  }

  /// Fragment received. Logs metadata only.
  static void fragmentReceived({
    required int fromNode,
    required int toNode,
    required int packetId,
    required int channel,
    required int payloadLen,
    int? rssi,
    double? snr,
  }) {
    AppLogging.reticulum(
      'fragment rx '
      'from=0x${fromNode.toRadixString(16)} '
      'to=0x${toNode.toRadixString(16)} '
      'pid=$packetId '
      'ch=$channel '
      'len=$payloadLen '
      'rssi=${rssi ?? '-'} '
      'snr=${snr ?? '-'}',
    );
  }

  /// Capture writer state changes (rotation, enable/disable, error).
  static void capture({
    required String action,
    String? path,
    int? bytesWritten,
    String? error,
  }) {
    final buf = StringBuffer('capture $action');
    if (path != null) buf.write(' path=$path');
    if (bytesWritten != null) buf.write(' bytes=$bytesWritten');
    if (error != null) buf.write(' error=$error');
    AppLogging.reticulum(buf.toString());
  }

  /// Replay engine progress + state changes.
  static void replay({
    required String action,
    String? path,
    int? recordIndex,
    int? totalRecords,
    String? mode,
    String? error,
  }) {
    final buf = StringBuffer('replay $action');
    if (path != null) buf.write(' path=$path');
    if (mode != null) buf.write(' mode=$mode');
    if (recordIndex != null && totalRecords != null) {
      buf.write(' record=$recordIndex/$totalRecords');
    }
    if (error != null) buf.write(' error=$error');
    AppLogging.reticulum(buf.toString());
  }

  /// Decode error during capture-record header parsing.
  static void decodeError({required String reason, int? offset}) {
    final buf = StringBuffer('decode_error reason=$reason');
    if (offset != null) buf.write(' offset=$offset');
    AppLogging.reticulum(buf.toString());
  }

  /// Fragment header successfully parsed. Surfaces the wire-level view
  /// (raw signed `position`, derived `fragmentNumber`, `isLast` flag)
  /// before the reassembler decides what to do with it.
  static void header({
    required int fromNode,
    required int index,
    required int position,
    required bool isLast,
    required int fragmentNumber,
    required int bodyLen,
  }) {
    AppLogging.reticulum(
      'frag_header '
      'from=0x${fromNode.toRadixString(16)} '
      'index=$index '
      'position=$position '
      'fragNum=$fragmentNumber '
      'isLast=$isLast '
      'body_len=$bodyLen',
    );
  }

  /// First fragment of a frame created a fresh reassembly buffer.
  static void bufferOpen({
    required int key,
    required int fromNode,
    required int index,
    required int fragNum,
    required int bodyLen,
  }) {
    AppLogging.reticulum(
      'reasm_buffer_open '
      'key=0x${key.toRadixString(16)} '
      'from=0x${fromNode.toRadixString(16)} '
      'index=$index '
      'fragNum=$fragNum '
      'body_len=$bodyLen',
    );
  }

  /// Subsequent fragment merged into an existing buffer. `have` is the
  /// fragment count after this insert; `totalN` is the known frame size
  /// (`null` until the last-fragment marker is seen).
  static void bufferAdd({
    required int key,
    required int fragNum,
    required int bodyLen,
    required int have,
    int? totalN,
    required bool duplicate,
  }) {
    final buf = StringBuffer('reasm_buffer_add ')
      ..write('key=0x${key.toRadixString(16)} ')
      ..write('fragNum=$fragNum ')
      ..write('body_len=$bodyLen ')
      ..write('have=$have/');
    if (totalN == null) {
      buf.write('?');
    } else {
      buf.write(totalN);
    }
    buf.write(' duplicate=$duplicate');
    AppLogging.reticulum(buf.toString());
  }
}
