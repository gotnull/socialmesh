// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'reticulum_fragment_event.dart';
import 'reticulum_safe_log.dart';

/// Append-only binary capture writer for port-76 fragments.
///
/// On-disk format is **SMRC v1**:
/// - File magic: ASCII `SMRC` followed by version byte `0x01` (5 bytes total)
/// - Records (little-endian, packed):
///   ```
///   uint64 timestamp_ms
///   uint32 from_node
///   uint32 to_node
///   uint32 packet_id      // 0 if absent
///   uint8  channel
///   int16  rssi           // INT16_MIN (-32768) if absent
///   int16  snr_q8         // snr * 256, INT16_MIN if absent
///   uint16 payload_len
///   uint8  payload[payload_len]
///   ```
///
/// Files rotate at 8 MB and live under `<appDocs>/reticulum_captures/`.
/// Schema is locked — any change requires a new version byte and a
/// matching reader path in the replay engine.
class ReticulumCaptureWriter {
  ReticulumCaptureWriter({this._captureDirOverride});

  final Directory? _captureDirOverride;

  /// Magic identifier prefix written to every capture file.
  static const String magicAscii = 'SMRC';

  /// On-disk format version. Bump only when the record schema changes.
  static const int formatVersion = 0x01;

  /// Fixed header length per record, in bytes.
  static const int recordHeaderBytes = 27;

  /// Sentinel written when an `int16` field is absent.
  static const int int16AbsentSentinel = -32768;

  /// Maximum bytes per capture file before rotation.
  static const int maxFileBytes = 8 * 1024 * 1024;

  /// Capture directory name under the app documents folder.
  static const String captureFolderName = 'reticulum_captures';

  IOSink? _sink;
  File? _currentFile;
  int _bytesInCurrentFile = 0;
  bool _enabled = false;
  bool _disposed = false;

  bool get isEnabled => _enabled;
  File? get currentFile => _currentFile;
  int get bytesInCurrentFile => _bytesInCurrentFile;

  /// Toggle capture on/off. Closes the active file when disabling.
  Future<void> setEnabled(bool enabled) async {
    if (_disposed) return;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) {
      await _closeCurrent();
    }
    ReticulumSafeLog.capture(action: enabled ? 'enabled' : 'disabled');
  }

  /// Append a fragment event to the current capture file. No-op when
  /// disabled. Rotates files transparently when the size cap is reached.
  Future<void> write(ReticulumFragmentEvent event) async {
    if (_disposed) return;
    if (!_enabled) return;

    final estimated = recordHeaderBytes + event.payloadLen;
    try {
      await _ensureSink(estimatedRecordSize: estimated);
      final record = encodeRecord(event);
      _sink!.add(record);
      await _sink!.flush();
      _bytesInCurrentFile += record.length;
    } catch (e) {
      ReticulumSafeLog.capture(action: 'write_error', error: e.toString());
    }
  }

  /// Pure encoder — exposed for unit-testing the wire layout.
  static Uint8List encodeRecord(ReticulumFragmentEvent event) {
    final fixed = ByteData(recordHeaderBytes);
    fixed.setUint64(0, event.timestampMs, Endian.little);
    fixed.setUint32(8, event.fromNode, Endian.little);
    fixed.setUint32(12, event.toNode, Endian.little);
    fixed.setUint32(16, event.packetId, Endian.little);
    fixed.setUint8(20, event.channel & 0xFF);
    fixed.setInt16(21, event.rssi ?? int16AbsentSentinel, Endian.little);
    fixed.setInt16(23, _encodeSnrQ8(event.snr), Endian.little);
    fixed.setUint16(25, event.payloadLen & 0xFFFF, Endian.little);

    final out = Uint8List(recordHeaderBytes + event.payloadLen);
    out.setRange(0, recordHeaderBytes, fixed.buffer.asUint8List());
    out.setRange(
      recordHeaderBytes,
      recordHeaderBytes + event.payloadLen,
      event.payload,
    );
    return out;
  }

  static int _encodeSnrQ8(double? snr) {
    if (snr == null) return int16AbsentSentinel;
    final scaled = (snr * 256).round();
    if (scaled <= int16AbsentSentinel) return int16AbsentSentinel + 1;
    if (scaled > 32767) return 32767;
    if (scaled < -32767) return -32767;
    return scaled;
  }

  /// Build the file magic header (5 bytes: 'SMRC' + version byte).
  static Uint8List magicHeader() {
    return Uint8List.fromList([...magicAscii.codeUnits, formatVersion]);
  }

  Future<Directory> _getCaptureDir() async {
    if (_captureDirOverride != null) return _captureDirOverride;
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$captureFolderName');
  }

  Future<void> _ensureSink({required int estimatedRecordSize}) async {
    if (_sink != null) {
      if (_bytesInCurrentFile + estimatedRecordSize > maxFileBytes) {
        await _closeCurrent();
      } else {
        return;
      }
    }
    final dir = await _getCaptureDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/$ts.bin');
    _sink = file.openWrite(mode: FileMode.writeOnly);
    _currentFile = file;
    final header = magicHeader();
    _sink!.add(header);
    _bytesInCurrentFile = header.length;
    ReticulumSafeLog.capture(action: 'open', path: file.path);
  }

  Future<void> _closeCurrent() async {
    final sink = _sink;
    final file = _currentFile;
    _sink = null;
    _currentFile = null;
    _bytesInCurrentFile = 0;
    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
        ReticulumSafeLog.capture(action: 'close', path: file?.path);
      } catch (e) {
        ReticulumSafeLog.capture(action: 'close_error', error: e.toString());
      }
    }
  }

  /// Permanently shut down. Subsequent calls are no-ops.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    await _closeCurrent();
  }

  /// List every `.bin` capture file in the current capture directory.
  Future<List<File>> listCaptureFiles() async {
    final dir = await _getCaptureDir();
    if (!await dir.exists()) return const [];
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.bin'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
