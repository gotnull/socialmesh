// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/map/map_session_providers.dart';

// MapScreen is rebuilt from scratch on every bottom-nav tab switch, so the
// camera pose and user-dropped pins must live in session-scoped providers to
// survive. These tests pin the notifier behaviour the restore path depends on.
void main() {
  group('mapCameraStateProvider', () {
    test('starts null and retains the last saved pose', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mapCameraStateProvider), isNull);

      container
          .read(mapCameraStateProvider.notifier)
          .save(const LatLng(37.7749, -122.4194), 12.5);

      final saved = container.read(mapCameraStateProvider);
      expect(saved, isNotNull);
      expect(saved!.center.latitude, closeTo(37.7749, 1e-9));
      expect(saved.center.longitude, closeTo(-122.4194, 1e-9));
      expect(saved.zoom, 12.5);
    });

    test('a later save overwrites the earlier pose', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapCameraStateProvider.notifier);
      notifier.save(const LatLng(1, 1), 4);
      notifier.save(const LatLng(2, 2), 9);

      final saved = container.read(mapCameraStateProvider)!;
      expect(saved.center, const LatLng(2, 2));
      expect(saved.zoom, 9);
    });
  });

  group('mapLocalWaypointsProvider', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mapLocalWaypointsProvider), isEmpty);
    });

    test('add appends and remove drops by id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapLocalWaypointsProvider.notifier);
      notifier.add(
        const MapLocalWaypoint(id: 1, position: LatLng(0, 0), label: 'A'),
      );
      notifier.add(
        const MapLocalWaypoint(id: 2, position: LatLng(1, 1), label: 'B'),
      );

      expect(container.read(mapLocalWaypointsProvider).map((w) => w.id), [
        1,
        2,
      ]);

      notifier.remove(1);
      final remaining = container.read(mapLocalWaypointsProvider);
      expect(remaining.map((w) => w.id), [2]);
      expect(remaining.single.label, 'B');
    });

    test('clear empties the list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapLocalWaypointsProvider.notifier);
      notifier.add(
        const MapLocalWaypoint(id: 1, position: LatLng(0, 0), label: 'A'),
      );
      notifier.clear();

      expect(container.read(mapLocalWaypointsProvider), isEmpty);
    });
  });
}
