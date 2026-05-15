// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A: per-contact path history (app-local).
//
// Firmware stores at most one active path per contact (the
// `out_path_len` + `out_path` fields on ContactInfo). There is no
// LRU cache, no path history, no read-back of past paths. SocialMesh
// adds an app-local history of paths the user has explicitly saved
// from a Trace Path result. The user can later reactivate any saved
// path with one tap; activation goes through the same wire helper
// the trace-save flow uses, so the activate path is wire-stable.
//
// Eviction policy: LRU at 20 entries per contact, NOT a capacity-
// reject. The reference implementation caps at 100 and silently
// drops new entries when full; SocialMesh ages out the oldest entry
// instead so fresh traces never get lost.
//
// Storage layout (one SharedPreferences key per (device, contact)):
//
//   key:   meshcore_path_history_<8hexDevice>_<8hexContact>
//   value: JSON {
//     "entries": [
//       {
//         "id":            "<stable id>",         // device-prefix-scoped
//         "bytes":         "<base64 path bytes>", // 1..64 raw hop bytes
//         "len":           <int>,                 // hop count
//         "source":        "trace" | "manual",
//         "createdAt":     <ms-epoch>,
//         "lastUsedAt":    <ms-epoch>,
//         "label":         null | "<string>",
//         "successCount":  <int>                  // reserved (0 in D39-A)
//       }
//     ]
//   }
//
// Key shape decisions:
//   - device prefix = first 4 bytes (8 hex chars) of the connected
//     device's pubkey.
//   - contact prefix = first 4 bytes (8 hex chars) of the contact
//     pubkey, mirroring the canonical SocialMesh log fingerprint.
//   - never the full 64-char pubkey hex in the key.
//   - never the contact name in the key (rename-stable).
//
// Privacy: the persisted blob contains base64 path bytes and
// metadata only. Logs use `path_len=<int>` and `source=<...>` only -
// path bytes themselves are NEVER written to AppLogging.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Maximum entries per contact. New entries past this limit evict
/// the oldest by `lastUsedAt` (falling back to `createdAt`).
const int kMeshCorePathHistoryMaxEntriesPerContact = 20;

/// Maximum raw path-bytes length supported by the firmware contact
/// path slot. Mirrors `MAX_PATH_SIZE` in
/// `MeshCore/src/MeshCore.h`. Entries with `bytes.length > 64` are
/// rejected by the store at write time.
const int kMeshCorePathHistoryMaxPathBytes = 64;

/// Source of a recorded path.
///   - `trace`: arrived via a user-triggered Trace Path save (D39-A).
///   - `manual`: reserved for future user-typed N-hop paths. No
///     D39-A entry point produces one yet.
///   - `inbound`: recorded passively after the firmware emitted
///     `PUSH_CODE_PATH_UPDATED 0x81` and we re-fetched the contact
///     via `CMD_GET_CONTACT_BY_KEY 0x1E` (D48-A3).
enum MeshCorePathSource { trace, manual, inbound }

extension MeshCorePathSourceWire on MeshCorePathSource {
  String get wire {
    switch (this) {
      case MeshCorePathSource.trace:
        return 'trace';
      case MeshCorePathSource.manual:
        return 'manual';
      case MeshCorePathSource.inbound:
        return 'inbound';
    }
  }

  static MeshCorePathSource fromWire(String? raw) {
    if (raw == 'manual') return MeshCorePathSource.manual;
    if (raw == 'inbound') return MeshCorePathSource.inbound;
    return MeshCorePathSource.trace;
  }
}

/// D48-A1: default starting weight for a newly-discovered path.
/// Mirrors meshcore-open's `AppSettings.initialRouteWeight = 3.0`.
/// Used by `fromJson` for legacy entries that pre-date D48 and don't
/// carry a `routeWeight` field. New entries take the value from
/// `MeshCoreAutoRouteSettings.initialRouteWeight` at insert time.
const double kMeshCorePathHistoryDefaultRouteWeight = 3.0;

/// A single saved path entry. Immutable; `copyWith` produces a new
/// record for mutation paths (touch / dedup).
class MeshCorePathHistoryEntry {
  final String id;
  final Uint8List bytes;
  final int len;
  final MeshCorePathSource source;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String? label;
  final int successCount;

  /// D48-A1: cumulative failures attributed to this path. Bumped by
  /// the orchestrator's failure path; never decreases.
  final int failureCount;

  /// D48-A1: live route weight for ranking. Initialized at insert
  /// time to `MeshCoreAutoRouteSettings.initialRouteWeight`, bumped
  /// on success, decremented on failure. When ≤ 0 the rotation
  /// orchestrator evicts the entry from the rotation pool (NOT from
  /// the path-history store; the entry stays visible in the
  /// history sheet).
  final double routeWeight;

  /// D48-B: exponentially-smoothed delivery RTT in milliseconds.
  /// `0.0` means "no sample yet"; consumed by the path-selector's
  /// latency component. The orchestrator updates this on each
  /// successful 0x82 push via `recordPathSuccess(tripTimeMs: ...)`
  /// using an EMA with alpha = 0.3 (see [emaAvgTripTimeMs]).
  final double avgTripTimeMs;

  MeshCorePathHistoryEntry({
    required this.id,
    required this.bytes,
    required this.len,
    required this.source,
    required this.createdAt,
    required this.lastUsedAt,
    this.label,
    this.successCount = 0,
    this.failureCount = 0,
    this.routeWeight = kMeshCorePathHistoryDefaultRouteWeight,
    this.avgTripTimeMs = 0.0,
  });

  MeshCorePathHistoryEntry copyWith({
    String? id,
    Uint8List? bytes,
    int? len,
    MeshCorePathSource? source,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    String? label,
    bool clearLabel = false,
    int? successCount,
    int? failureCount,
    double? routeWeight,
    double? avgTripTimeMs,
  }) {
    return MeshCorePathHistoryEntry(
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      len: len ?? this.len,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      label: clearLabel ? null : (label ?? this.label),
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      routeWeight: routeWeight ?? this.routeWeight,
      avgTripTimeMs: avgTripTimeMs ?? this.avgTripTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bytes': base64Encode(bytes),
    'len': len,
    'source': source.wire,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'lastUsedAt': lastUsedAt.millisecondsSinceEpoch,
    'label': label,
    'successCount': successCount,
    'failureCount': failureCount,
    'routeWeight': routeWeight,
    'avgTripTimeMs': avgTripTimeMs,
  };

  static MeshCorePathHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final id = raw['id'] as String?;
      final bytesB64 = raw['bytes'] as String?;
      final len = raw['len'] as int?;
      final sourceStr = raw['source'] as String?;
      final createdMs = raw['createdAt'] as int?;
      final lastUsedMs = raw['lastUsedAt'] as int?;
      if (id == null || bytesB64 == null || len == null) return null;
      if (createdMs == null || lastUsedMs == null) return null;
      final bytes = base64Decode(bytesB64);
      if (bytes.isEmpty || bytes.length > kMeshCorePathHistoryMaxPathBytes) {
        return null;
      }
      if (bytes.length != len) return null;
      // D48-A1: legacy rows pre-date `failureCount` and `routeWeight`;
      // fall through to 0 / default-weight so old data stays readable.
      // D48-B: ditto for `avgTripTimeMs`; legacy rows hydrate to 0
      // (no sample yet), which the latency component reads as
      // neutral.
      return MeshCorePathHistoryEntry(
        id: id,
        bytes: Uint8List.fromList(bytes),
        len: len,
        source: MeshCorePathSourceWire.fromWire(sourceStr),
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
        lastUsedAt: DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
        label: raw['label'] as String?,
        successCount: (raw['successCount'] as int?) ?? 0,
        failureCount: (raw['failureCount'] as int?) ?? 0,
        routeWeight:
            (raw['routeWeight'] as num?)?.toDouble() ??
            kMeshCorePathHistoryDefaultRouteWeight,
        avgTripTimeMs: (raw['avgTripTimeMs'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// D48-B: EMA helper used by [MeshCorePathHistoryStore.recordPathSuccess]
/// to fold a new RTT sample into the entry's running average.
///
/// `alpha = 0.3` is a common middle ground for low-noise smoothing:
/// 3 samples of a new RTT pull the average ~66% of the way there,
/// so the score reacts to mesh-level path changes within a few
/// successful deliveries without being whipsawed by a single outlier.
///
/// First sample (`current <= 0`) replaces verbatim; no warm-up
/// distortion. Negative samples are rejected at the caller.
double emaAvgTripTimeMs(double current, double newSampleMs) {
  if (newSampleMs <= 0) return current;
  if (current <= 0) return newSampleMs;
  return 0.7 * current + 0.3 * newSampleMs;
}

/// SharedPreferences-backed per-contact path history.
class MeshCorePathHistoryStore {
  static const String _keyPrefix = 'meshcore_path_history_';

  final SharedPreferences? _prefs;
  MeshCorePathHistoryStore({SharedPreferences? preferences})
    : _prefs = preferences;

  Future<SharedPreferences> _resolve() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Compose the SharedPreferences key for a (device, contact) pair.
  /// Returns the empty string when either prefix is empty so the
  /// caller can fast-path away from any read/write.
  String _keyFor(String devicePubKeyPrefix, String contactPubKeyPrefix) {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) return '';
    return '$_keyPrefix${devicePubKeyPrefix.toLowerCase()}_'
        '${contactPubKeyPrefix.toLowerCase()}';
  }

  /// Load all entries for [contactPubKeyPrefix] on the device
  /// identified by [devicePubKeyPrefix]. Returns an empty list on
  /// missing key, corrupt JSON, or empty prefix. Entries are sorted
  /// newest-first by `lastUsedAt` (then `createdAt`).
  Future<List<MeshCorePathHistoryEntry>> load(
    String devicePubKeyPrefix,
    String contactPubKeyPrefix,
  ) async {
    final key = _keyFor(devicePubKeyPrefix, contactPubKeyPrefix);
    if (key.isEmpty) return const <MeshCorePathHistoryEntry>[];
    final prefs = await _resolve();
    final raw = prefs.getString(key);
    if (raw == null) return const <MeshCorePathHistoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <MeshCorePathHistoryEntry>[];
      final list = decoded['entries'];
      if (list is! List) return const <MeshCorePathHistoryEntry>[];
      final entries = <MeshCorePathHistoryEntry>[];
      for (final item in list) {
        final parsed = MeshCorePathHistoryEntry.fromJson(item);
        if (parsed != null) entries.add(parsed);
      }
      entries.sort(_byNewestUsageDesc);
      return entries;
    } catch (_) {
      return const <MeshCorePathHistoryEntry>[];
    }
  }

  /// Persist [entries] for the (device, contact) pair. No-op on empty
  /// prefix. Entries are written newest-first by `lastUsedAt`.
  Future<void> save(
    String devicePubKeyPrefix,
    String contactPubKeyPrefix,
    List<MeshCorePathHistoryEntry> entries,
  ) async {
    final key = _keyFor(devicePubKeyPrefix, contactPubKeyPrefix);
    if (key.isEmpty) return;
    final prefs = await _resolve();
    if (entries.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final sorted = List<MeshCorePathHistoryEntry>.from(entries)
      ..sort(_byNewestUsageDesc);
    final json = {'entries': sorted.map((e) => e.toJson()).toList()};
    await prefs.setString(key, jsonEncode(json));
  }

  /// Forget all path history for the (device, contact) pair.
  Future<void> clear(
    String devicePubKeyPrefix,
    String contactPubKeyPrefix,
  ) async {
    final key = _keyFor(devicePubKeyPrefix, contactPubKeyPrefix);
    if (key.isEmpty) return;
    final prefs = await _resolve();
    await prefs.remove(key);
  }

  /// Convenience: record [bytes] under [contactPubKeyPrefix].
  ///
  /// Semantics:
  ///   - Empty / too-long bytes are silently rejected.
  ///   - If an existing entry matches bytes-for-bytes, its
  ///     `lastUsedAt` is bumped to [now] and the `source` is
  ///     preserved (the original source still describes how the
  ///     entry first entered the history).
  ///   - Otherwise a new entry is added at the head with `createdAt`
  ///     == `lastUsedAt` == [now].
  ///   - LRU eviction at [kMeshCorePathHistoryMaxEntriesPerContact]:
  ///     entries with the oldest `lastUsedAt` (then `createdAt`) are
  ///     dropped first.
  ///
  /// Returns the post-save sorted list. Empty when the prefix is
  /// empty (no-op).
  Future<List<MeshCorePathHistoryEntry>> record({
    required String devicePubKeyPrefix,
    required String contactPubKeyPrefix,
    required Uint8List bytes,
    required MeshCorePathSource source,
    required DateTime now,
    double? initialWeight,
  }) async {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) {
      return const <MeshCorePathHistoryEntry>[];
    }
    if (bytes.isEmpty || bytes.length > kMeshCorePathHistoryMaxPathBytes) {
      return load(devicePubKeyPrefix, contactPubKeyPrefix);
    }
    final current = await load(devicePubKeyPrefix, contactPubKeyPrefix);
    final byBytes = current.indexWhere((e) => _bytesEq(e.bytes, bytes));
    final List<MeshCorePathHistoryEntry> next;
    if (byBytes >= 0) {
      final existing = current[byBytes];
      final touched = existing.copyWith(lastUsedAt: now);
      next = List<MeshCorePathHistoryEntry>.from(current)..[byBytes] = touched;
    } else {
      final id = _composeId(devicePubKeyPrefix, contactPubKeyPrefix, now);
      final entry = MeshCorePathHistoryEntry(
        id: id,
        bytes: Uint8List.fromList(bytes),
        len: bytes.length,
        source: source,
        createdAt: now,
        lastUsedAt: now,
        routeWeight: initialWeight ?? kMeshCorePathHistoryDefaultRouteWeight,
      );
      next = [entry, ...current];
    }
    // LRU eviction: drop oldest entries past the cap.
    next.sort(_byNewestUsageDesc);
    if (next.length > kMeshCorePathHistoryMaxEntriesPerContact) {
      next.removeRange(kMeshCorePathHistoryMaxEntriesPerContact, next.length);
    }
    await save(devicePubKeyPrefix, contactPubKeyPrefix, next);
    return next;
  }

  /// Bump the `lastUsedAt` of [entryId] to [now]. No-op when the id
  /// is not present.
  Future<List<MeshCorePathHistoryEntry>> touch({
    required String devicePubKeyPrefix,
    required String contactPubKeyPrefix,
    required String entryId,
    required DateTime now,
  }) async {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) {
      return const <MeshCorePathHistoryEntry>[];
    }
    final current = await load(devicePubKeyPrefix, contactPubKeyPrefix);
    final idx = current.indexWhere((e) => e.id == entryId);
    if (idx < 0) return current;
    final touched = current[idx].copyWith(lastUsedAt: now);
    final next = List<MeshCorePathHistoryEntry>.from(current)..[idx] = touched;
    next.sort(_byNewestUsageDesc);
    await save(devicePubKeyPrefix, contactPubKeyPrefix, next);
    return next;
  }

  /// Remove [entryId] from the history. No-op when missing.
  Future<List<MeshCorePathHistoryEntry>> delete({
    required String devicePubKeyPrefix,
    required String contactPubKeyPrefix,
    required String entryId,
  }) async {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) {
      return const <MeshCorePathHistoryEntry>[];
    }
    final current = await load(devicePubKeyPrefix, contactPubKeyPrefix);
    final next = current.where((e) => e.id != entryId).toList();
    if (next.length == current.length) return current;
    await save(devicePubKeyPrefix, contactPubKeyPrefix, next);
    return next;
  }

  /// D48-A1: record a successful delivery on the saved path matching
  /// [pathBytes] (by full-byte equality). Bumps `successCount` and
  /// writes [newWeight] (caller is responsible for clamping per
  /// `weightAfterSuccess` from the path-selector helper). Also
  /// touches `lastUsedAt` to [now].
  ///
  /// D48-B: when [tripTimeMs] is supplied (and > 0), folds the
  /// sample into the entry's [MeshCorePathHistoryEntry.avgTripTimeMs]
  /// via `emaAvgTripTimeMs`. The orchestrator pulls the value from
  /// `MeshCoreSendConfirmationOutcome.tripTime` on each delivered
  /// attempt.
  ///
  /// No-op when no entry matches. Returns the post-save list.
  Future<List<MeshCorePathHistoryEntry>> recordPathSuccess({
    required String devicePubKeyPrefix,
    required String contactPubKeyPrefix,
    required Uint8List pathBytes,
    required double newWeight,
    required DateTime now,
    double? tripTimeMs,
  }) async {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) {
      return const <MeshCorePathHistoryEntry>[];
    }
    final current = await load(devicePubKeyPrefix, contactPubKeyPrefix);
    final idx = current.indexWhere((e) => _bytesEq(e.bytes, pathBytes));
    if (idx < 0) return current;
    final existing = current[idx];
    final nextAvg = tripTimeMs == null
        ? existing.avgTripTimeMs
        : emaAvgTripTimeMs(existing.avgTripTimeMs, tripTimeMs);
    final updated = existing.copyWith(
      successCount: existing.successCount + 1,
      routeWeight: newWeight,
      lastUsedAt: now,
      avgTripTimeMs: nextAvg,
    );
    final next = List<MeshCorePathHistoryEntry>.from(current)..[idx] = updated;
    next.sort(_byNewestUsageDesc);
    await save(devicePubKeyPrefix, contactPubKeyPrefix, next);
    return next;
  }

  /// D48-A1: record a failed delivery on the saved path matching
  /// [pathBytes]. Bumps `failureCount` and writes [newWeight].
  /// When [newWeight] is ≤ 0 the entry is REMOVED from the history
  /// (rotation pool eviction = history eviction in D48-A1; the
  /// distinction is academic since there's no "show evicted in the
  /// sheet but skip in the orchestrator" surface yet).
  ///
  /// No-op when no entry matches. Returns the post-save list.
  Future<List<MeshCorePathHistoryEntry>> recordPathFailure({
    required String devicePubKeyPrefix,
    required String contactPubKeyPrefix,
    required Uint8List pathBytes,
    required double newWeight,
  }) async {
    if (devicePubKeyPrefix.isEmpty || contactPubKeyPrefix.isEmpty) {
      return const <MeshCorePathHistoryEntry>[];
    }
    final current = await load(devicePubKeyPrefix, contactPubKeyPrefix);
    final idx = current.indexWhere((e) => _bytesEq(e.bytes, pathBytes));
    if (idx < 0) return current;
    final existing = current[idx];
    final List<MeshCorePathHistoryEntry> next;
    if (newWeight <= 0) {
      next = List<MeshCorePathHistoryEntry>.from(current)..removeAt(idx);
    } else {
      final updated = existing.copyWith(
        failureCount: existing.failureCount + 1,
        routeWeight: newWeight,
      );
      next = List<MeshCorePathHistoryEntry>.from(current)..[idx] = updated;
    }
    next.sort(_byNewestUsageDesc);
    await save(devicePubKeyPrefix, contactPubKeyPrefix, next);
    return next;
  }

  static int _byNewestUsageDesc(
    MeshCorePathHistoryEntry a,
    MeshCorePathHistoryEntry b,
  ) {
    final byLastUsed = b.lastUsedAt.compareTo(a.lastUsedAt);
    if (byLastUsed != 0) return byLastUsed;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Compose a stable id from the device + contact prefix + timestamp
  /// + a small per-millisecond suffix. Stable enough that the same
  /// path saved twice in the same millisecond on the same device
  /// still gets two distinct ids (we dedupe by bytes elsewhere; this
  /// just keeps the id collision-safe).
  static int _idCounter = 0;
  static String _composeId(
    String devicePrefix,
    String contactPrefix,
    DateTime now,
  ) {
    _idCounter = (_idCounter + 1) & 0xFFFF;
    final suffix = _idCounter.toRadixString(16).padLeft(4, '0');
    return '${devicePrefix.toLowerCase()}_'
        '${contactPrefix.toLowerCase()}_'
        '${now.millisecondsSinceEpoch.toRadixString(16)}_$suffix';
  }

  static bool _bytesEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
