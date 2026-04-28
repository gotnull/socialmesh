// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'reticulum_capture_writer.dart';
import 'reticulum_fragment_event.dart';
import 'reticulum_safe_log.dart';

/// Replay mode for [ReticulumCaptureReplay].
enum ReticulumReplayMode {
  /// Emit events at their original wall-clock spacing.
  realtime,

  /// Emit events at original spacing divided by `speedMultiplier`.
  accelerated,

  /// No timers; caller drives emission via [ReticulumCaptureReplay.stepOne].
  step,
}

/// Thrown when a capture file's magic header does not match the
/// supported SMRC v1 layout.
class UnsupportedCaptureVersion implements Exception {
  UnsupportedCaptureVersion({this.version});

  /// The version byte that was found, if the file at least had a
  /// recognizable `SMRC` ASCII prefix. `null` when the magic itself
  /// did not match.
  final int? version;

  @override
  String toString() => 'UnsupportedCaptureVersion(version=$version)';
}

/// Reads an SMRC v1 capture file and replays its records back into the
/// same fragment-event broadcast stream the live handler emits to.
///
/// The replay engine validates the magic header on load, decodes every
/// record into [ReticulumFragmentEvent], and emits them in one of three
/// modes ([ReticulumReplayMode]).
class ReticulumCaptureReplay {
  ReticulumCaptureReplay({
    required this.file,
    required this.mode,
    this.speedMultiplier = 1.0,
  });

  final File file;
  final ReticulumReplayMode mode;
  final double speedMultiplier;

  final StreamController<ReticulumFragmentEvent> _controller =
      StreamController<ReticulumFragmentEvent>.broadcast();

  final List<ReticulumFragmentEvent> _records = <ReticulumFragmentEvent>[];

  int _index = 0;
  Timer? _timer;
  bool _paused = false;
  bool _disposed = false;
  bool _loaded = false;

  Stream<ReticulumFragmentEvent> get stream => _controller.stream;
  int get currentIndex => _index;
  int get totalRecords => _records.length;
  bool get isPaused => _paused;
  bool get isDone => _index >= _records.length && _loaded;

  /// Read and decode the entire capture file into memory.
  ///
  /// Throws [UnsupportedCaptureVersion] when the magic header does not
  /// match `SMRC\x01`.
  Future<void> load() async {
    if (_loaded) return;
    final bytes = await file.readAsBytes();
    _records
      ..clear()
      ..addAll(decodeAll(bytes));
    _loaded = true;
    ReticulumSafeLog.replay(
      action: 'loaded',
      path: file.path,
      totalRecords: _records.length,
      mode: mode.name,
    );
  }

  /// Pure decoder over a complete capture-file byte buffer. Validates
  /// the file magic and yields every well-formed record. Truncated
  /// trailing records (e.g. from an unflushed write) are skipped.
  static List<ReticulumFragmentEvent> decodeAll(Uint8List bytes) {
    if (bytes.length < 5) {
      throw UnsupportedCaptureVersion();
    }
    final magicChars = ReticulumCaptureWriter.magicAscii.codeUnits;
    for (var i = 0; i < magicChars.length; i++) {
      if (bytes[i] != magicChars[i]) {
        throw UnsupportedCaptureVersion();
      }
    }
    if (bytes[4] != ReticulumCaptureWriter.formatVersion) {
      throw UnsupportedCaptureVersion(version: bytes[4]);
    }

    final view = ByteData.sublistView(bytes);
    final out = <ReticulumFragmentEvent>[];
    var offset = 5;
    while (offset + ReticulumCaptureWriter.recordHeaderBytes <= bytes.length) {
      final ts = view.getUint64(offset, Endian.little);
      final from = view.getUint32(offset + 8, Endian.little);
      final to = view.getUint32(offset + 12, Endian.little);
      final pid = view.getUint32(offset + 16, Endian.little);
      final ch = view.getUint8(offset + 20);
      final rssiRaw = view.getInt16(offset + 21, Endian.little);
      final snrRaw = view.getInt16(offset + 23, Endian.little);
      final payloadLen = view.getUint16(offset + 25, Endian.little);
      final payloadStart = offset + ReticulumCaptureWriter.recordHeaderBytes;
      final payloadEnd = payloadStart + payloadLen;
      if (payloadEnd > bytes.length) {
        ReticulumSafeLog.decodeError(
          reason: 'truncated_record',
          offset: offset,
        );
        break;
      }
      final payload = Uint8List.fromList(
        bytes.sublist(payloadStart, payloadEnd),
      );
      final rssi = rssiRaw == ReticulumCaptureWriter.int16AbsentSentinel
          ? null
          : rssiRaw;
      final snr = snrRaw == ReticulumCaptureWriter.int16AbsentSentinel
          ? null
          : snrRaw / 256.0;
      out.add(
        ReticulumFragmentEvent(
          timestampMs: ts,
          fromNode: from,
          toNode: to,
          packetId: pid,
          channel: ch,
          rssi: rssi,
          snr: snr,
          payload: payload,
        ),
      );
      offset = payloadEnd;
    }
    return out;
  }

  /// Begin emitting records. In [ReticulumReplayMode.step] mode this is
  /// a no-op; the caller drives emission via [stepOne].
  Future<void> start() async {
    if (_disposed) return;
    if (!_loaded) await load();
    _paused = false;
    ReticulumSafeLog.replay(
      action: 'start',
      path: file.path,
      totalRecords: _records.length,
      mode: mode.name,
    );
    switch (mode) {
      case ReticulumReplayMode.step:
        return;
      case ReticulumReplayMode.realtime:
        _scheduleNext(effectiveMultiplier: 1.0);
        break;
      case ReticulumReplayMode.accelerated:
        _scheduleNext(effectiveMultiplier: speedMultiplier);
        break;
    }
  }

  void pause() {
    if (mode == ReticulumReplayMode.step) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
    ReticulumSafeLog.replay(action: 'pause', path: file.path);
  }

  void resume() {
    if (mode == ReticulumReplayMode.step) return;
    if (!_paused) return;
    _paused = false;
    final mult = mode == ReticulumReplayMode.realtime ? 1.0 : speedMultiplier;
    ReticulumSafeLog.replay(action: 'resume', path: file.path);
    _scheduleNext(effectiveMultiplier: mult);
  }

  /// Step mode: emit the next record synchronously. Returns `false`
  /// when the cursor has reached the end of the capture.
  bool stepOne() {
    if (mode != ReticulumReplayMode.step) {
      throw StateError('stepOne() is only valid in step mode');
    }
    if (!_loaded) {
      throw StateError('Call load() before stepOne()');
    }
    if (_index >= _records.length) return false;
    _controller.add(_records[_index]);
    _index++;
    return _index < _records.length;
  }

  void _scheduleNext({required double effectiveMultiplier}) {
    if (_disposed || _paused) return;
    if (_index >= _records.length) {
      ReticulumSafeLog.replay(
        action: 'complete',
        path: file.path,
        totalRecords: _records.length,
      );
      return;
    }
    var delay = Duration.zero;
    if (_index > 0) {
      final gapMs =
          _records[_index].timestampMs - _records[_index - 1].timestampMs;
      if (gapMs > 0 && effectiveMultiplier > 0) {
        final scaled = (gapMs / effectiveMultiplier).clamp(0, 60000).toInt();
        delay = Duration(milliseconds: scaled);
      }
    }
    _timer = Timer(delay, () {
      if (_disposed || _paused) return;
      _controller.add(_records[_index]);
      _index++;
      _scheduleNext(effectiveMultiplier: effectiveMultiplier);
    });
  }

  Future<void> stop() async {
    if (_disposed) return;
    _disposed = true;
    _paused = true;
    _timer?.cancel();
    _timer = null;
    ReticulumSafeLog.replay(action: 'stop', path: file.path);
    await _controller.close();
  }
}
