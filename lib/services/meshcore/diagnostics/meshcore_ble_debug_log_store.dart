// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q5: pure in-memory ring buffer for BLE-subsystem transport events
// (scan / connect / discover / notify / disconnect / error). Drives the
// `MeshCoreBleDebugLogScreen` viewer. Distinct from D44's app-wide
// `AppLogger` (covers every subsystem) and D28's `MeshCoreFrameCapture`
// (covers wire frames). This is transport-only.
//
// Capacity is 500 entries; older entries are evicted FIFO. Persistence
// is intentionally not provided — the log resets on each session so
// the buffer never grows past a bounded RAM cost. Export to disk is
// out of scope (D-Q6's diagnostics bundle can pull a snapshot if
// extended later).

import 'dart:async';
import 'dart:typed_data';

/// Maximum number of entries kept in the BLE debug log ring buffer.
/// 500 is sized for a single connect cycle (~30 events on a healthy
/// pairing) plus headroom for ~15 reconnect cycles before the oldest
/// trace ages out.
const int kMeshCoreBleDebugLogCapacity = 500;

/// Severity tier for a single BLE debug log entry. Drives the chip
/// colour in the viewer.
enum MeshCoreBleDebugLogSeverity { info, warn, error }

/// Category bucket for grouping in the viewer. Free-form `message`
/// carries the per-event detail; the category is the high-level lane.
enum MeshCoreBleDebugLogCategory {
  scan,
  connect,
  discover,
  notify,
  send,
  disconnect,
  error,
}

class MeshCoreBleDebugLogEntry {
  final DateTime timestamp;
  final MeshCoreBleDebugLogSeverity severity;
  final MeshCoreBleDebugLogCategory category;
  final String message;

  const MeshCoreBleDebugLogEntry({
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.message,
  });
}

/// In-memory ring buffer for BLE debug entries plus a broadcast stream
/// that fires on every append / clear / pause-toggle. UI consumers
/// subscribe through the Riverpod provider; `_streamController` is
/// closed via `dispose()` when the provider tears down.
class MeshCoreBleDebugLogStore {
  final List<MeshCoreBleDebugLogEntry> _entries = [];
  bool _paused = false;
  final StreamController<List<MeshCoreBleDebugLogEntry>> _streamController =
      StreamController<List<MeshCoreBleDebugLogEntry>>.broadcast();

  /// Append a new entry. Drops silently when paused. Evicts the oldest
  /// entry FIFO when capacity is exceeded.
  void append({
    required MeshCoreBleDebugLogSeverity severity,
    required MeshCoreBleDebugLogCategory category,
    required String message,
    DateTime? timestamp,
  }) {
    if (_paused) return;
    _entries.add(
      MeshCoreBleDebugLogEntry(
        timestamp: timestamp ?? DateTime.now(),
        severity: severity,
        category: category,
        message: message,
      ),
    );
    while (_entries.length > kMeshCoreBleDebugLogCapacity) {
      _entries.removeAt(0);
    }
    _emit();
  }

  /// Read-only snapshot. Returned list is a defensive copy so callers
  /// can't mutate the underlying buffer.
  List<MeshCoreBleDebugLogEntry> snapshot() =>
      List<MeshCoreBleDebugLogEntry>.unmodifiable(_entries);

  /// Stream of snapshot updates; fires on append / clear / pause.
  Stream<List<MeshCoreBleDebugLogEntry>> get stream => _streamController.stream;

  /// Whether new entries are currently being dropped. Pause does NOT
  /// clear the existing buffer; resume just re-enables append.
  bool get isPaused => _paused;

  void pause() {
    if (_paused) return;
    _paused = true;
    _emit();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _emit();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _emit();
  }

  /// Test / lifecycle hook to release the broadcast controller.
  Future<void> dispose() async {
    await _streamController.close();
  }

  void _emit() {
    if (_streamController.isClosed) return;
    _streamController.add(snapshot());
  }
}

/// Redact a MAC address (any case, any separator) to the trailing
/// two octets as a short fingerprint. Returns `'XX:XX'` when the
/// input has fewer than two octets so the screen never reveals more
/// than the last 4 hex characters.
///
/// Examples:
/// - `'AA:BB:CC:DD:EE:FF'` → `'EE:FF'`
/// - `'aa-bb-cc-dd-ee-ff'` → `'EE:FF'`
/// - `'AABBCCDDEEFF'` → `'EE:FF'`
/// - `null` / `''` / less than 4 hex → `'XX:XX'`
String redactMacFingerprint(String? mac) {
  if (mac == null) return 'XX:XX';
  final hex = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
  if (hex.length < 4) return 'XX:XX';
  final last4 = hex.substring(hex.length - 4);
  return '${last4.substring(0, 2)}:${last4.substring(2, 4)}';
}

/// Helper: format a list of service UUIDs without exposing the full
/// 128-bit string. Returns the first 8 hex chars of each followed by
/// an ellipsis so the screen reflects which services were found
/// without dumping the full advertisement payload.
String redactServiceUuids(Iterable<String> uuids) {
  return uuids
      .map((u) {
        final cleaned = u.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        if (cleaned.length <= 8) return cleaned.toLowerCase();
        return '${cleaned.substring(0, 8).toLowerCase()}…';
      })
      .join(', ');
}

/// Helper: format a byte count for the "send N bytes" / "recv N bytes"
/// notify event messages. Pure (not redaction) but lives here so the
/// transport layer never has to import a formatter from elsewhere.
String formatByteCount(Uint8List bytes) {
  return '${bytes.length} B';
}
