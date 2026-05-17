// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q10 pure store + helper pins for the map pinned-locations list.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/meshcore_pinned_location.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_pinned_location_store.dart';

MeshCorePinnedLocation _pin({
  String id = '1',
  double lat = 1.0,
  double lon = 2.0,
  String label = 'Home',
  DateTime? createdAt,
}) {
  return MeshCorePinnedLocation(
    id: id,
    latitude: lat,
    longitude: lon,
    label: label,
    createdAt: createdAt ?? DateTime.utc(2026, 5, 17, 12, 0, 0),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCorePinnedLocationStore read/write round-trip', () {
    test('empty store returns an empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCorePinnedLocationStore(prefs);
      expect(store.read(), isEmpty);
    });

    test('write then read returns the same pins in order', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCorePinnedLocationStore(prefs);
      final a = _pin(id: 'a', lat: 1.0, lon: 2.0, label: 'A');
      final b = _pin(id: 'b', lat: 3.0, lon: 4.0, label: 'B');
      await store.write([a, b]);
      final loaded = store.read();
      expect(loaded.map((p) => p.id), ['a', 'b']);
      expect(loaded.map((p) => p.latitude), [1.0, 3.0]);
      expect(loaded.map((p) => p.label), ['A', 'B']);
    });

    test('malformed JSON entries are silently skipped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'meshcore_pinned_locations_v1': <String>[
          'not json',
          '{"lat":1.0,"lon":2.0,"label":"OK","id":"1",'
              '"createdAt":"2026-05-17T12:00:00Z"}',
          '{"missing":"fields"}',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCorePinnedLocationStore(prefs);
      final loaded = store.read();
      expect(loaded, hasLength(1));
      expect(loaded.first.label, 'OK');
    });
  });

  group('addIn / removeIn pure helpers', () {
    test('addIn appends to the end (newest last)', () {
      final next = MeshCorePinnedLocationStore.addIn([
        _pin(id: 'a'),
      ], _pin(id: 'b'));
      expect(next.map((p) => p.id), ['a', 'b']);
    });

    test('addIn enforces the capacity FIFO eviction', () {
      var current = <MeshCorePinnedLocation>[];
      for (var i = 0; i < kMeshCorePinnedLocationCapacity + 3; i++) {
        current = MeshCorePinnedLocationStore.addIn(current, _pin(id: 'id-$i'));
      }
      expect(current, hasLength(kMeshCorePinnedLocationCapacity));
      expect(current.first.id, 'id-3');
      expect(current.last.id, 'id-${kMeshCorePinnedLocationCapacity + 2}');
    });

    test('removeIn removes the matching id', () {
      final next = MeshCorePinnedLocationStore.removeIn([
        _pin(id: 'a'),
        _pin(id: 'b'),
        _pin(id: 'c'),
      ], 'b');
      expect(next.map((p) => p.id), ['a', 'c']);
    });

    test('removeIn returns the SAME instance when id is absent', () {
      final current = [_pin(id: 'a'), _pin(id: 'b')];
      final next = MeshCorePinnedLocationStore.removeIn(current, 'zzz');
      expect(identical(next, current), isTrue);
    });
  });

  group('MeshCorePinnedLocation JSON', () {
    test('encode / decode round-trip is lossless', () {
      final original = _pin(
        id: 'rt',
        lat: 47.6062,
        lon: -122.3321,
        label: 'Seattle',
      );
      final decoded = MeshCorePinnedLocation.decode(original.encode());
      expect(decoded, isNotNull);
      expect(decoded!.id, 'rt');
      expect(decoded.latitude, closeTo(47.6062, 1e-9));
      expect(decoded.longitude, closeTo(-122.3321, 1e-9));
      expect(decoded.label, 'Seattle');
    });

    test('decode returns null on bad JSON', () {
      expect(MeshCorePinnedLocation.decode('not json'), isNull);
    });

    test('decode returns null on missing fields', () {
      expect(MeshCorePinnedLocation.decode('{"lat":1.0}'), isNull);
    });

    test('decode returns null on wrong-type fields', () {
      expect(
        MeshCorePinnedLocation.decode(
          '{"lat":"oops","lon":2.0,"label":"A","id":"1",'
          '"createdAt":"2026-05-17T12:00:00Z"}',
        ),
        isNull,
      );
    });

    test('decode accepts integer lat/lon (num → double)', () {
      final decoded = MeshCorePinnedLocation.decode(
        '{"lat":47,"lon":-122,"label":"Int","id":"1",'
        '"createdAt":"2026-05-17T12:00:00Z"}',
      );
      expect(decoded, isNotNull);
      expect(decoded!.latitude, 47.0);
      expect(decoded.longitude, -122.0);
    });
  });
}
