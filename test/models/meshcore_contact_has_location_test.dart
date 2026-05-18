// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// hasLocation must reject NaN / Infinity. flutter_map's Crs.checkLatLng
// throws fatally on non-finite LatLngs, so any contact whose latitude or
// longitude is NaN must not pass the location gate that downstream
// marker / camera code relies on.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({double? lat, double? lon}) {
  return MeshCoreContact(
    publicKey: Uint8List(32),
    name: 'test',
    type: MeshCoreAdvType.chat,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 18),
    latitude: lat,
    longitude: lon,
  );
}

void main() {
  group('MeshCoreContact.hasLocation', () {
    test('returns true for finite lat/lon', () {
      expect(_contact(lat: -33.8688, lon: 151.2093).hasLocation, isTrue);
    });

    test('returns false when either coordinate is null', () {
      expect(_contact(lat: null, lon: 151.2093).hasLocation, isFalse);
      expect(_contact(lat: -33.8688, lon: null).hasLocation, isFalse);
      expect(_contact().hasLocation, isFalse);
    });

    test('returns false when either coordinate is NaN', () {
      expect(_contact(lat: double.nan, lon: 151.2093).hasLocation, isFalse);
      expect(_contact(lat: -33.8688, lon: double.nan).hasLocation, isFalse);
      expect(_contact(lat: double.nan, lon: double.nan).hasLocation, isFalse);
    });

    test('returns false for infinite coordinates', () {
      expect(_contact(lat: double.infinity, lon: 0).hasLocation, isFalse);
      expect(
        _contact(lat: 0, lon: double.negativeInfinity).hasLocation,
        isFalse,
      );
    });
  });
}
