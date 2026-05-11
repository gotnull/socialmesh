// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-A: app-local channel preferences for MeshCore (mute first).
//
// MeshCore firmware exposes only channel slot read/write (CMD_GET_CHANNEL
// 0x1F + CMD_SET_CHANNEL 0x20) carrying name + PSK; it has no concept of
// mute, hide, archive, ordering metadata, or notification preferences.
// Every UX feature in that family must therefore live entirely client-
// side. This store persists those preferences keyed by the firmware
// slot index — the only stable non-secret identifier available.
//
// Why the slot index and not the channel name or PSK:
//   - PSK is secret. Using it as a storage key would leak material into
//     SharedPreferences keyspace and any error log path.
//   - Channel name is user-editable. Keying by name breaks every
//     preference whenever the user renames the channel.
//   - Firmware slot index is wire-stable across renames (CMD_SET_CHANNEL
//     overwrites slot N in place).
//
// Consequence: deleting the channel in slot N and creating a fresh
// channel in the same slot inherits the prefs. This is acceptable —
// the slot IS the identity at the firmware boundary. The alternative
// (any key derived from PSK/code) would either leak secrets or break
// on every edit.
//
// Schema (v0, forward-compatible — JSON can grow without migration):
//   {
//     "muted":  [<int>, <int>...],   // sorted, deduped slot indices
//     "hidden": [],                  // reserved for D37-B
//     "order":  []                   // reserved for D37-C
//   }
//
// D37-A consumes `muted`; D37-B-A also consumes `hidden`; D37-C-A
// also consumes `order`. The three axes are independent: a channel
// can be in any combination of {muted, hidden, ordered-or-not}.
// The notification gate consults muted only; hide only affects
// channel-list visibility; order only affects render position.

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of the per-channel preferences for one MeshCore device.
class MeshCoreChannelPrefs {
  /// Slot indices the user has muted (system notifications suppressed).
  final Set<int> mutedChannelIndices;

  /// D37-B-A: slot indices the user has hidden from the default
  /// channels list. Hide is independent of mute; the notification
  /// gate consults muted only.
  final Set<int> hiddenChannelIndices;

  /// D37-C-A: user-defined channel render order. Listed indices render
  /// first in this exact order; unlisted channels render after, in
  /// firmware slot-index order. Independent of mute and hide.
  final List<int> orderedChannelIndices;

  const MeshCoreChannelPrefs({
    this.mutedChannelIndices = const <int>{},
    this.hiddenChannelIndices = const <int>{},
    this.orderedChannelIndices = const <int>[],
  });

  /// The default empty prefs returned on a cache miss or a corrupt blob.
  static const MeshCoreChannelPrefs empty = MeshCoreChannelPrefs();

  MeshCoreChannelPrefs copyWith({
    Set<int>? mutedChannelIndices,
    Set<int>? hiddenChannelIndices,
    List<int>? orderedChannelIndices,
  }) {
    return MeshCoreChannelPrefs(
      mutedChannelIndices: mutedChannelIndices ?? this.mutedChannelIndices,
      hiddenChannelIndices: hiddenChannelIndices ?? this.hiddenChannelIndices,
      orderedChannelIndices:
          orderedChannelIndices ?? this.orderedChannelIndices,
    );
  }

  Map<String, dynamic> toJson() => {
    'muted': (mutedChannelIndices.toList()..sort()),
    'hidden': (hiddenChannelIndices.toList()..sort()),
    'order': orderedChannelIndices,
  };

  static MeshCoreChannelPrefs fromJson(Map<String, dynamic> json) {
    return MeshCoreChannelPrefs(
      mutedChannelIndices: _readIntSet(json['muted']),
      hiddenChannelIndices: _readIntSet(json['hidden']),
      orderedChannelIndices: _readIntList(json['order']),
    );
  }

  static Set<int> _readIntSet(Object? raw) {
    if (raw is! List) return const <int>{};
    final out = <int>{};
    for (final v in raw) {
      if (v is int && v >= 0 && v <= 255) {
        out.add(v);
      }
    }
    return out;
  }

  static List<int> _readIntList(Object? raw) {
    if (raw is! List) return const <int>[];
    final out = <int>[];
    for (final v in raw) {
      if (v is int && v >= 0 && v <= 255) {
        out.add(v);
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreChannelPrefs &&
          _setEq(mutedChannelIndices, other.mutedChannelIndices) &&
          _setEq(hiddenChannelIndices, other.hiddenChannelIndices) &&
          _listEq(orderedChannelIndices, other.orderedChannelIndices);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(mutedChannelIndices),
    Object.hashAllUnordered(hiddenChannelIndices),
    Object.hashAll(orderedChannelIndices),
  );

  static bool _setEq(Set<int> a, Set<int> b) =>
      a.length == b.length && a.every(b.contains);
  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// SharedPreferences-backed store for [MeshCoreChannelPrefs].
///
/// Keyed by an 8-char hex prefix of the device's public key (same shape
/// used by [MeshCoreRadioParamsStore]) so two radios never share a
/// persisted value. JSON-encoded so the schema can grow without a
/// migration.
class MeshCoreChannelPrefsStore {
  static const String _keyPrefix = 'meshcore_channel_prefs_';

  /// Optional preferences override for tests.
  final SharedPreferences? _prefs;

  MeshCoreChannelPrefsStore({SharedPreferences? preferences})
    : _prefs = preferences;

  Future<SharedPreferences> _resolve() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  String _keyFor(String devicePubKeyPrefix) =>
      '$_keyPrefix${devicePubKeyPrefix.toLowerCase()}';

  /// Load the current preferences blob for [devicePubKeyPrefix].
  ///
  /// Returns [MeshCoreChannelPrefs.empty] on:
  ///   - empty [devicePubKeyPrefix] (no device identified yet),
  ///   - missing key (never written), or
  ///   - corrupt JSON (defensive: never throw to the caller — the
  ///     notification gate must fail-open).
  ///
  /// Corrupt blobs are NOT auto-removed; we leave them so a future bug
  /// fix on the parser can recover the data instead of having silently
  /// erased it.
  Future<MeshCoreChannelPrefs> load(String devicePubKeyPrefix) async {
    if (devicePubKeyPrefix.isEmpty) return MeshCoreChannelPrefs.empty;
    final prefs = await _resolve();
    final raw = prefs.getString(_keyFor(devicePubKeyPrefix));
    if (raw == null) return MeshCoreChannelPrefs.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return MeshCoreChannelPrefs.empty;
      return MeshCoreChannelPrefs.fromJson(decoded);
    } catch (_) {
      return MeshCoreChannelPrefs.empty;
    }
  }

  /// Persist [value] for [devicePubKeyPrefix]. No-op on empty key.
  Future<void> save(
    String devicePubKeyPrefix,
    MeshCoreChannelPrefs value,
  ) async {
    if (devicePubKeyPrefix.isEmpty) return;
    final prefs = await _resolve();
    await prefs.setString(
      _keyFor(devicePubKeyPrefix),
      jsonEncode(value.toJson()),
    );
  }

  /// Forget all preferences for [devicePubKeyPrefix].
  Future<void> clear(String devicePubKeyPrefix) async {
    if (devicePubKeyPrefix.isEmpty) return;
    final prefs = await _resolve();
    await prefs.remove(_keyFor(devicePubKeyPrefix));
  }

  /// Convenience: add a single channel index to the muted set and
  /// persist. Idempotent — repeated mutes are a no-op.
  Future<MeshCoreChannelPrefs> mute(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    final current = await load(devicePubKeyPrefix);
    if (current.mutedChannelIndices.contains(channelIndex)) return current;
    final next = current.copyWith(
      mutedChannelIndices: {...current.mutedChannelIndices, channelIndex},
    );
    await save(devicePubKeyPrefix, next);
    return next;
  }

  /// Convenience: remove a single channel index from the muted set and
  /// persist. Idempotent — repeated unmutes are a no-op.
  Future<MeshCoreChannelPrefs> unmute(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    final current = await load(devicePubKeyPrefix);
    if (!current.mutedChannelIndices.contains(channelIndex)) return current;
    final next = current.copyWith(
      mutedChannelIndices: {...current.mutedChannelIndices}
        ..remove(channelIndex),
    );
    await save(devicePubKeyPrefix, next);
    return next;
  }

  /// D37-B-A: add a single channel index to the hidden set and persist.
  /// Hide is independent of mute — a channel can be hidden + muted,
  /// hidden + unmuted, muted + visible, or neither. Hide only affects
  /// the channel list's default visibility; it never gates
  /// notifications or in-app message persistence. Idempotent.
  Future<MeshCoreChannelPrefs> hide(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    final current = await load(devicePubKeyPrefix);
    if (current.hiddenChannelIndices.contains(channelIndex)) return current;
    final next = current.copyWith(
      hiddenChannelIndices: {...current.hiddenChannelIndices, channelIndex},
    );
    await save(devicePubKeyPrefix, next);
    return next;
  }

  /// D37-B-A: remove a single channel index from the hidden set and
  /// persist. Idempotent.
  Future<MeshCoreChannelPrefs> unhide(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    final current = await load(devicePubKeyPrefix);
    if (!current.hiddenChannelIndices.contains(channelIndex)) return current;
    final next = current.copyWith(
      hiddenChannelIndices: {...current.hiddenChannelIndices}
        ..remove(channelIndex),
    );
    await save(devicePubKeyPrefix, next);
    return next;
  }

  /// D37-C-A: replace the user-defined channel order list atomically.
  ///
  /// The order list is rendered first by the channels screen; channels
  /// not listed here render after, in firmware slot-index order. The
  /// muted and hidden sets are preserved.
  ///
  /// Dedup + sanitise on write:
  ///   - duplicate slot indices are dropped (first occurrence wins),
  ///   - negative or > 255 entries are dropped,
  ///   - any other non-int entry is impossible to reach here (statically
  ///     typed `List<int>`), so no runtime type check.
  ///
  /// Idempotent — passing the same order back is a cheap no-op.
  Future<MeshCoreChannelPrefs> setOrder(
    String devicePubKeyPrefix,
    List<int> order,
  ) async {
    final sanitised = <int>[];
    final seen = <int>{};
    for (final idx in order) {
      if (idx < 0 || idx > 255) continue;
      if (!seen.add(idx)) continue;
      sanitised.add(idx);
    }
    final current = await load(devicePubKeyPrefix);
    final unchanged =
        current.orderedChannelIndices.length == sanitised.length &&
        () {
          for (var i = 0; i < sanitised.length; i++) {
            if (current.orderedChannelIndices[i] != sanitised[i]) return false;
          }
          return true;
        }();
    if (unchanged) return current;
    final next = current.copyWith(orderedChannelIndices: sanitised);
    await save(devicePubKeyPrefix, next);
    return next;
  }
}
