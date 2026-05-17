// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression for the traceroute polyline assembly pipeline in
// `lib/features/map/map_screen.dart`. The crash class is
// `Crs.checkLatLng (LatLng is not finite)`, which fires when a
// non-finite LatLng reaches `Polyline.points`. The fix routes
// origin / target / per-hop coordinates through `safeLatLng` and
// then through `tracerouteSegmentsFor`, which already drops
// segments when fewer than two known points exist.
//
// This test exercises the composition end-to-end without depending
// on the private `_buildTraceroutePolylines` method. If `safeLatLng`
// returns null for a corrupted hop, the position becomes a null
// entry in the route list, and `tracerouteSegmentsFor` skips it.
// With every hop corrupted the route degenerates to fewer than two
// known points and the segmentation helper returns an empty list,
// so no polyline is rendered.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/core/safe_lat_lng.dart';
import 'package:socialmesh/features/map/map_screen.dart';

void main() {
  group('traceroute pipeline rejects non-finite hop coordinates', () {
    test('all hops NaN — pipeline produces no segments', () {
      final route = <LatLng?>[
        safeLatLng(double.nan, double.nan),
        safeLatLng(double.nan, double.nan),
        safeLatLng(double.nan, double.nan),
      ];
      expect(route, everyElement(isNull));
      expect(tracerouteSegmentsFor(route), isEmpty);
    });

    test('origin valid, every hop and target invalid — pipeline produces no '
        'segments (need at least two known points)', () {
      final route = <LatLng?>[
        safeLatLng(37.0, -122.0),
        safeLatLng(double.nan, 0),
        safeLatLng(double.infinity, 0),
        safeLatLng(0, 200.0), // out of WGS-84 range
      ];
      expect(route.first, isNotNull);
      expect(route.skip(1), everyElement(isNull));
      expect(tracerouteSegmentsFor(route), isEmpty);
    });

    test('origin valid, one mid-hop valid, target invalid — pipeline yields '
        'one solid segment between origin and the valid hop', () {
      final route = <LatLng?>[
        safeLatLng(37.0, -122.0),
        safeLatLng(37.5, -122.5),
        safeLatLng(double.nan, double.nan),
      ];
      final segments = tracerouteSegmentsFor(route);
      expect(segments, hasLength(1));
      expect(segments.single.dashed, isFalse);
    });

    test('origin and target valid, mid-hop NaN — single dashed segment '
        'bridges the invalid hop', () {
      final route = <LatLng?>[
        safeLatLng(37.0, -122.0),
        safeLatLng(double.nan, double.nan),
        safeLatLng(38.0, -123.0),
      ];
      final segments = tracerouteSegmentsFor(route);
      expect(segments, hasLength(1));
      expect(segments.single.dashed, isTrue);
    });
  });
}
