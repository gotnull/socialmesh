// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_map_marker_staleness.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

void main() {
  MeshCoreContact contactAt(DateTime lastSeen) {
    return MeshCoreContact(
      publicKey: Uint8List.fromList(const [1, 2, 3, 4]),
      name: 'test',
      type: 1,
      pathLength: 0,
      path: Uint8List(0),
      latitude: 0,
      longitude: 0,
      lastSeen: lastSeen,
    );
  }

  group('meshCoreContactMarkerOpacity', () {
    final now = DateTime(2026, 5, 19, 12);

    test('contact heard just now is at full opacity', () {
      expect(meshCoreContactMarkerOpacity(contactAt(now), now), 1.0);
    });

    test('contact heard 1 hour ago is at full opacity (within 24h)', () {
      final c = contactAt(now.subtract(const Duration(hours: 1)));
      expect(meshCoreContactMarkerOpacity(c, now), 1.0);
    });

    test('contact heard 23 hours ago is still at full opacity', () {
      final c = contactAt(now.subtract(const Duration(hours: 23)));
      expect(meshCoreContactMarkerOpacity(c, now), 1.0);
    });

    test('contact heard at exactly 24h boundary drops to stale 0.5', () {
      final c = contactAt(now.subtract(const Duration(hours: 24)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.5);
    });

    test('contact heard 3 days ago renders at stale 0.5', () {
      final c = contactAt(now.subtract(const Duration(days: 3)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.5);
    });

    test('contact heard at exactly 7d boundary drops to very-stale 0.25', () {
      final c = contactAt(now.subtract(const Duration(days: 7)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.25);
    });

    test('contact heard 30 days ago is at very-stale 0.25', () {
      final c = contactAt(now.subtract(const Duration(days: 30)));
      expect(meshCoreContactMarkerOpacity(c, now), 0.25);
    });

    test('future lastSeen (clock skew) returns full opacity', () {
      final c = contactAt(now.add(const Duration(hours: 1)));
      expect(meshCoreContactMarkerOpacity(c, now), 1.0);
    });

    test('threshold constants match the documented values', () {
      expect(kMeshCoreMarkerFreshThreshold, const Duration(hours: 24));
      expect(kMeshCoreMarkerVeryStaleThreshold, const Duration(days: 7));
    });
  });
}
