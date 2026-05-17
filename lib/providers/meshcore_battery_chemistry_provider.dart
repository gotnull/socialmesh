// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q11: Riverpod 3.x state layer for the per-self-radio battery
// chemistry overrides. Reads on build, mirrors mutations to
// SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meshcore/storage/meshcore_battery_chemistry.dart';
import '../services/meshcore/storage/meshcore_battery_chemistry_store.dart';

class MeshCoreBatteryChemistryNotifier
    extends AsyncNotifier<Map<String, MeshCoreBatteryChemistry>> {
  MeshCoreBatteryChemistryStore? _store;

  @override
  Future<Map<String, MeshCoreBatteryChemistry>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _store = MeshCoreBatteryChemistryStore(prefs);
    return _store!.read();
  }

  Future<void> setChemistry({
    required String pubKeyHex,
    required MeshCoreBatteryChemistry chemistry,
  }) async {
    final current = state.value ?? const <String, MeshCoreBatteryChemistry>{};
    final next = MeshCoreBatteryChemistryStore.setIn(
      current: current,
      pubKeyHex: pubKeyHex,
      chemistry: chemistry,
    );
    if (identical(next, current)) return;
    state = AsyncData(next);
    await _store?.write(next);
  }

  /// Synchronous override lookup. Returns `auto` when not yet
  /// hydrated or when no override exists for [pubKeyHex] — both
  /// cases want the firmware-default LiPo curve.
  MeshCoreBatteryChemistry lookup(String pubKeyHex) {
    final current = state.value;
    if (current == null) return MeshCoreBatteryChemistry.auto;
    return MeshCoreBatteryChemistryStore.lookup(current, pubKeyHex);
  }
}

final meshCoreBatteryChemistryProvider =
    AsyncNotifierProvider<
      MeshCoreBatteryChemistryNotifier,
      Map<String, MeshCoreBatteryChemistry>
    >(MeshCoreBatteryChemistryNotifier.new);
