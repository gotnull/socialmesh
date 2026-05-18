// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Row 13: regression pins for the marker-opacity helper that drives
// the stale-location fade on the MeshCore map.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_map_marker_staleness.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({required DateTime lastSeen}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
    name: 'TestContact',
    type: 1,
    pathLength: -1,
    path: Uint8List(0),
    latitude: 0,
    longitude: 0,
    lastSeen: lastSeen,
  );
}

void main() {
  group('Row 13 meshCoreContactMarkerOpacity', () {
    final now = DateTime(2026, 5, 18, 12, 0, 0);

    test('fresh (<24h) returns 1.0', () {
      final c = _contact(lastSeen: now.subtract(const Duration(hours: 1)));
      expect(meshCoreContactMarkerOpacity(c, now), 1.0);
    });

    test('just-over 24h returns 0.5', () {
      final c = _contact(
        lastSeen: now.subtract(const Duration(hours: 24, minutes: 1)),
      );
      expect(meshCoreContactMarkerOpacity(c, now), 0.5);
    });

    test('3-day-old (mid-stale band) returns 0.5', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 3)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.5);
    });

    test('7-day-old (at very-stale threshold) returns 0.25', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 7)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.25);
    });

    test('30-day-old returns 0.25 (very stale, clamped)', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 30)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.25);
    });

    test('boundary: exactly 24h treated as stale (not fresh)', () {
      final c = _contact(lastSeen: now.subtract(const Duration(hours: 24)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.5);
    });

    test('future timestamp (clock drift) treated as fresh', () {
      final c = _contact(lastSeen: now.add(const Duration(minutes: 5)));
      expect(meshCoreContactMarkerOpacity(c, now), 1.0);
    });

    test('threshold constants are stable contract values', () {
      expect(kMeshCoreMarkerFreshThreshold, const Duration(hours: 24));
      expect(kMeshCoreMarkerVeryStaleThreshold, const Duration(days: 7));
    });
  });
}
