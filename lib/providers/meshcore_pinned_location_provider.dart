// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q10: Riverpod 3.x state layer for the map pinned-locations
// list. Reads on build, mirrors mutations to SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meshcore_pinned_location.dart';
import '../services/meshcore/storage/meshcore_pinned_location_store.dart';

class MeshCorePinnedLocationNotifier
    extends AsyncNotifier<List<MeshCorePinnedLocation>> {
  MeshCorePinnedLocationStore? _store;

  @override
  Future<List<MeshCorePinnedLocation>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _store = MeshCorePinnedLocationStore(prefs);
    return _store!.read();
  }

  Future<void> addPin({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final current = state.value ?? const <MeshCorePinnedLocation>[];
    final now = DateTime.now();
    final pin = MeshCorePinnedLocation(
      id: now.microsecondsSinceEpoch.toString(),
      latitude: latitude,
      longitude: longitude,
      label: label.trim(),
      createdAt: now,
    );
    final next = MeshCorePinnedLocationStore.addIn(current, pin);
    state = AsyncData(next);
    await _store?.write(next);
  }

  Future<void> removePin(String id) async {
    final current = state.value ?? const <MeshCorePinnedLocation>[];
    final next = MeshCorePinnedLocationStore.removeIn(current, id);
    if (identical(next, current)) return;
    state = AsyncData(next);
    await _store?.write(next);
  }
}

final meshCorePinnedLocationProvider =
    AsyncNotifierProvider<
      MeshCorePinnedLocationNotifier,
      List<MeshCorePinnedLocation>
    >(MeshCorePinnedLocationNotifier.new);
