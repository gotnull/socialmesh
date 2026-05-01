// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins provider for the NodeDex Map.
//
// Derives [NodeDexMapPin]s from `nodeDexProvider` (Map<int,
// NodeDexEntry>). For each entry, walks `entry.encounters` from
// newest to oldest (encounters list is oldest-first; newest is at
// `.last`) and selects the first record with both latitude and
// longitude non-null. Entries that have no positioned encounter are
// omitted from the result.
//
// The list is sorted ascending by `positionedAt` so flutter_map paints
// the freshest pins last (i.e. on top), matching the canonical map's
// "newest on top" convention.
//
// Time is read from [nodedexMapNowProvider] — overridable in tests so
// staleness assertions are deterministic; production reads the wall
// clock once per build.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import 'nodedex_map_pin.dart';

/// Wall-clock seam. Tests override this with a fixed `DateTime`; the
/// production override returns `DateTime.now()` per consumer build.
final nodedexMapNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// All NodeDex entries whose encounter history contains at least one
/// record with valid latitude + longitude, lifted into pin records.
final nodedexMapPinsProvider = Provider<List<NodeDexMapPin>>((ref) {
  final entries = ref.watch(nodeDexProvider);

  final pins = <NodeDexMapPin>[];
  for (final entry in entries.values) {
    final pin = _pinFromEntry(entry);
    if (pin != null) pins.add(pin);
  }

  // flutter_map paints later children on top of earlier ones, so
  // sorting ascending by positionedAt puts the freshest pins last and
  // therefore on top.
  pins.sort((a, b) => a.positionedAt.compareTo(b.positionedAt));
  return pins;
});

NodeDexMapPin? _pinFromEntry(NodeDexEntry entry) {
  if (entry.encounters.isEmpty) return null;

  // Walk newest -> oldest. The first record with both coords non-null
  // supplies position + positionedAt.
  EncounterRecord? positioned;
  for (var i = entry.encounters.length - 1; i >= 0; i--) {
    final e = entry.encounters[i];
    if (e.latitude != null && e.longitude != null) {
      positioned = e;
      break;
    }
  }
  if (positioned == null) return null;

  final newest = entry.encounters.last;
  return NodeDexMapPin(
    nodeNum: entry.nodeNum,
    position: LatLng(positioned.latitude!, positioned.longitude!),
    positionedAt: positioned.timestamp,
    lastEncounterAt: newest.timestamp,
    encounterCount: entry.encounterCount,
    sigil: entry.sigil,
    socialTag: entry.socialTag,
    displayName: entry.lastKnownName,
  );
}
