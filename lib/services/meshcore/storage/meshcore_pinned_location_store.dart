// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q10: SharedPreferences-backed store for the per-app pinned
// locations list (map POI annotations). Local-only — no wire
// surface, no copy is shared with the mesh.
//
// Storage shape: a `StringList` of JSON-encoded
// `MeshCorePinnedLocation` records. Order is preserved (newest
// last) so the map renders pins in insertion order.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/meshcore_pinned_location.dart';

const String _kPinnedLocationsKey = 'meshcore_pinned_locations_v1';

/// Cap on the number of pins kept in the store. Older pins evicted
/// FIFO. Sized to keep the JSON blob bounded — at ~120 B per pin,
/// 200 entries is ~24 KB which SharedPreferences handles trivially.
const int kMeshCorePinnedLocationCapacity = 200;

class MeshCorePinnedLocationStore {
  final SharedPreferences _prefs;
  MeshCorePinnedLocationStore(this._prefs);

  List<MeshCorePinnedLocation> read() {
    final raw = _prefs.getStringList(_kPinnedLocationsKey) ?? const [];
    final pins = <MeshCorePinnedLocation>[];
    for (final entry in raw) {
      final pin = MeshCorePinnedLocation.decode(entry);
      if (pin != null) pins.add(pin);
    }
    return pins;
  }

  Future<bool> write(List<MeshCorePinnedLocation> pins) {
    final trimmed = pins.length > kMeshCorePinnedLocationCapacity
        ? pins.sublist(pins.length - kMeshCorePinnedLocationCapacity)
        : pins;
    return _prefs.setStringList(
      _kPinnedLocationsKey,
      trimmed.map((p) => p.encode()).toList(),
    );
  }

  /// Pure helper: append a pin to `current` and return the new
  /// list. Caps at [kMeshCorePinnedLocationCapacity], evicting the
  /// oldest entry FIFO.
  static List<MeshCorePinnedLocation> addIn(
    List<MeshCorePinnedLocation> current,
    MeshCorePinnedLocation pin,
  ) {
    final next = [...current, pin];
    if (next.length <= kMeshCorePinnedLocationCapacity) return next;
    return next.sublist(next.length - kMeshCorePinnedLocationCapacity);
  }

  /// Pure helper: remove a pin by id and return the new list.
  /// Returns the same instance reference when the id is absent.
  static List<MeshCorePinnedLocation> removeIn(
    List<MeshCorePinnedLocation> current,
    String id,
  ) {
    final filtered = current.where((p) => p.id != id).toList();
    if (filtered.length == current.length) return current;
    return filtered;
  }
}
