// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Aggregation buffer for MeshCore advert notifications.
//
// Row 11.c: when the per-event rate limiter blocks a notification fire,
// the suppressed peer is appended here. On the next eligible advert
// (rate limit elapsed), the caller drains the buffer in one shot and
// emits a single "batch summary" notification covering every suppressed
// peer plus the trigger.
//
// No timers, no async scheduling: this is a pure state machine driven
// by the advert event stream. The drain happens exactly when the
// upstream rate limiter says it's allowed to fire again.
class MeshCoreAdvertBatchEntry {
  final String pubKeyHex;
  final String displayName;
  final DateTime heardAt;

  const MeshCoreAdvertBatchEntry({
    required this.pubKeyHex,
    required this.displayName,
    required this.heardAt,
  });
}

class MeshCoreAdvertBatcher {
  final int _maxBuffered;
  final List<MeshCoreAdvertBatchEntry> _pending = [];

  MeshCoreAdvertBatcher({this._maxBuffered = 20});

  int get pendingCount => _pending.length;

  bool get isEmpty => _pending.isEmpty;

  bool get isNotEmpty => _pending.isNotEmpty;

  List<MeshCoreAdvertBatchEntry> get pendingSnapshot =>
      List.unmodifiable(_pending);

  /// Append a suppressed advert to the pending buffer. If the buffer is
  /// already at [maxBuffered], the oldest entry is evicted (FIFO) so
  /// recent peers always win. Duplicate pubKeyHex entries are de-duped
  /// in place: a re-hear of an already-pending peer refreshes its
  /// `heardAt` and moves it to the tail.
  void add(MeshCoreAdvertBatchEntry entry) {
    _pending.removeWhere((e) => e.pubKeyHex == entry.pubKeyHex);
    _pending.add(entry);
    while (_pending.length > _maxBuffered) {
      _pending.removeAt(0);
    }
  }

  /// Drain every pending entry and return them in arrival order. The
  /// buffer is empty after this call.
  List<MeshCoreAdvertBatchEntry> drain() {
    final out = List<MeshCoreAdvertBatchEntry>.from(_pending);
    _pending.clear();
    return out;
  }

  /// Discard every pending entry without surfacing them. Used when the
  /// user toggles advert notifications OFF mid-session so a later
  /// toggle-back-ON doesn't surface stale buffered peers.
  void clear() => _pending.clear();
}
