// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Row 13: regression pins for the marker staleness helper that drives
// the stale badge on the MeshCore map.

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
  group('Row 13 meshCoreContactMarkerIsStale', () {
    final now = DateTime(2026, 5, 18, 12, 0, 0);

    test('fresh (<24h) is not stale', () {
      final c = _contact(lastSeen: now.subtract(const Duration(hours: 1)));
      expect(meshCoreContactMarkerIsStale(c, now), isFalse);
    });

    test('just-over 24h is stale', () {
      final c = _contact(
        lastSeen: now.subtract(const Duration(hours: 24, minutes: 1)),
      );
      expect(meshCoreContactMarkerIsStale(c, now), isTrue);
    });

    test('3-day-old (mid-stale band) is stale', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 3)));
      expect(meshCoreContactMarkerIsStale(c, now), isTrue);
    });

    test('7-day-old (at very-stale threshold) is stale', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 7)));
      expect(meshCoreContactMarkerIsStale(c, now), isTrue);
    });

    test('30-day-old is stale', () {
      final c = _contact(lastSeen: now.subtract(const Duration(days: 30)));
      expect(meshCoreContactMarkerIsStale(c, now), isTrue);
    });

    test('boundary: exactly 24h is stale', () {
      final c = _contact(lastSeen: now.subtract(const Duration(hours: 24)));
      expect(meshCoreContactMarkerIsStale(c, now), isTrue);
    });

    test('future timestamp (clock drift) is not stale', () {
      final c = _contact(lastSeen: now.add(const Duration(minutes: 5)));
      expect(meshCoreContactMarkerIsStale(c, now), isFalse);
    });

    test('threshold constants are stable contract values', () {
      expect(kMeshCoreMarkerFreshThreshold, const Duration(hours: 24));
      expect(kMeshCoreMarkerVeryStaleThreshold, const Duration(days: 7));
    });
  });
}
