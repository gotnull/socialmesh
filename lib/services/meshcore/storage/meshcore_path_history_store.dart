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

/// Source of a recorded path. `trace` covers paths that arrived via
/// a Trace Path result. `manual` is reserved for future user-typed
/// N-hop paths and is accepted by the store today but no D39-A entry
/// point produces one.
enum MeshCorePathSource { trace, manual }

extension MeshCorePathSourceWire on MeshCorePathSource {
  String get wire {
    switch (this) {
      case MeshCorePathSource.trace:
        return 'trace';
      case MeshCorePathSource.manual:
        return 'manual';
    }
  }

  static MeshCorePathSource fromWire(String? raw) {
    if (raw == 'manual') return MeshCorePathSource.manual;
    return MeshCorePathSource.trace;
  }
}

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

  MeshCorePathHistoryEntry({
    required this.id,
    required this.bytes,
    required this.len,
    required this.source,
    required this.createdAt,
    required this.lastUsedAt,
    this.label,
    this.successCount = 0,
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
      return MeshCorePathHistoryEntry(
        id: id,
        bytes: Uint8List.fromList(bytes),
        len: len,
        source: MeshCorePathSourceWire.fromWire(sourceStr),
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
        lastUsedAt: DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
        label: raw['label'] as String?,
        successCount: (raw['successCount'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
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
