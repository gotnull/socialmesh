// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Persistence for the last-applied MeshCore radio parameters per node.
//
// Why this exists: SELF_INFO does not carry frequency or bandwidth. After
// the user applies a Radio Settings change via the in-app sheet, those
// two fields cannot be re-read from the device. Without client-side
// persistence the sheet would re-open showing empty / default values,
// giving the user no way to verify what they previously applied.
//
// Storage: SharedPreferences, keyed by the device's public-key hex
// prefix so two radios don't share a single persisted value. JSON-
// encoded so the schema can grow without a migration.

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of the last radio params the user successfully applied to a
/// MeshCore device.
///
/// Field semantics mirror the wire format used by [setRadioParams]:
/// - [freqKhz] is u32 LE in kHz (e.g. `869618` = 869.618 MHz).
/// - [bandwidthHz] is u32 LE in Hz (e.g. `62500` = 62.5 kHz).
/// - [spreadingFactor] is 5..12.
/// - [codingRate] is 5..8.
/// - [txPowerDbm] is int8 dBm.
class MeshCoreRadioParams {
  final int freqKhz;
  final int bandwidthHz;
  final int spreadingFactor;
  final int codingRate;
  final int txPowerDbm;

  const MeshCoreRadioParams({
    required this.freqKhz,
    required this.bandwidthHz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.txPowerDbm,
  });

  Map<String, dynamic> toJson() => {
    'freqKhz': freqKhz,
    'bandwidthHz': bandwidthHz,
    'spreadingFactor': spreadingFactor,
    'codingRate': codingRate,
    'txPowerDbm': txPowerDbm,
  };

  factory MeshCoreRadioParams.fromJson(Map<String, dynamic> json) {
    return MeshCoreRadioParams(
      freqKhz: json['freqKhz'] as int,
      bandwidthHz: json['bandwidthHz'] as int,
      spreadingFactor: json['spreadingFactor'] as int,
      codingRate: json['codingRate'] as int,
      txPowerDbm: json['txPowerDbm'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreRadioParams &&
          freqKhz == other.freqKhz &&
          bandwidthHz == other.bandwidthHz &&
          spreadingFactor == other.spreadingFactor &&
          codingRate == other.codingRate &&
          txPowerDbm == other.txPowerDbm;

  @override
  int get hashCode => Object.hash(
    freqKhz,
    bandwidthHz,
    spreadingFactor,
    codingRate,
    txPowerDbm,
  );
}

/// SharedPreferences-backed store for [MeshCoreRadioParams] keyed by
/// device public-key hex (first 8 chars: same shape as the visible
/// node id elsewhere in the UI). Two distinct nodes never share a
/// persisted value.
class MeshCoreRadioParamsStore {
  static const String _keyPrefix = 'meshcore_radio_params_';

  /// Optional preferences override for tests.
  final SharedPreferences? _prefs;

  MeshCoreRadioParamsStore({SharedPreferences? preferences})
    : _prefs = preferences;

  Future<SharedPreferences> _resolve() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  String _keyFor(String nodeKey) => '$_keyPrefix${nodeKey.toLowerCase()}';

  /// Save the params last successfully applied to [nodeKey]. Overwrites
  /// any previous entry for the same key.
  Future<void> save(String nodeKey, MeshCoreRadioParams params) async {
    if (nodeKey.isEmpty) return;
    final prefs = await _resolve();
    await prefs.setString(_keyFor(nodeKey), jsonEncode(params.toJson()));
  }

  /// Load the last-applied params for [nodeKey], or `null` if none was
  /// ever saved (or stored JSON failed to decode: defensive, drop the
  /// stale entry rather than blow up the caller).
  Future<MeshCoreRadioParams?> load(String nodeKey) async {
    if (nodeKey.isEmpty) return null;
    final prefs = await _resolve();
    final raw = prefs.getString(_keyFor(nodeKey));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MeshCoreRadioParams.fromJson(json);
    } catch (_) {
      await prefs.remove(_keyFor(nodeKey));
      return null;
    }
  }

  /// Forget any saved params for [nodeKey].
  Future<void> clear(String nodeKey) async {
    if (nodeKey.isEmpty) return;
    final prefs = await _resolve();
    await prefs.remove(_keyFor(nodeKey));
  }
}
