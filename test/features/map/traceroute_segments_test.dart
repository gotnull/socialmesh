// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:socialmesh/features/map/map_screen.dart';

// Behavioural tests for the Sprint 8 traceroute segmentation helper.
//
// The mesh map renders traceroute paths as a stack of polyline
// segments rather than one polyline so each leg can carry the visual
// pattern that matches its underlying certainty:
//
//   solid  = both endpoints are real, geolocated, adjacent hops
//   dashed = the renderer bridged over one or more hops with no
//            reported position; the line is inferred, not measured
//
// `tracerouteSegmentsFor` is pure so we can pin the contract here
// without spinning up the full map.
void main() {
  group('tracerouteSegmentsFor', () {
    final a = LatLng(1, 1);
    final b = LatLng(2, 2);
    final c = LatLng(3, 3);
    final d = LatLng(4, 4);

    test('returns an empty list when fewer than two known points exist', () {
      expect(tracerouteSegmentsFor(const []), isEmpty);
      expect(tracerouteSegmentsFor([null]), isEmpty);
      expect(tracerouteSegmentsFor([null, null]), isEmpty);
      expect(tracerouteSegmentsFor([a]), isEmpty);
      expect(tracerouteSegmentsFor([a, null]), isEmpty);
      expect(tracerouteSegmentsFor([null, a, null]), isEmpty);
    });

    test('emits a single solid segment for two adjacent known points', () {
      final segments = tracerouteSegmentsFor([a, b]);
      expect(segments.length, 1);
      expect(segments[0].points, [a, b]);
      expect(segments[0].dashed, false);
    });

    test('marks a segment dashed when bridging a single missing hop', () {
      final segments = tracerouteSegmentsFor([a, null, b]);
      expect(segments.length, 1);
      expect(segments[0].points, [a, b]);
      expect(segments[0].dashed, true);
    });

    test('marks a segment dashed when bridging multiple missing hops', () {
      final segments = tracerouteSegmentsFor([a, null, null, b]);
      expect(segments.length, 1);
      expect(segments[0].points, [a, b]);
      expect(
        segments[0].dashed,
        true,
        reason:
            'Any number of consecutive missing hops between two known '
            'endpoints means the line between them is inferred, not '
            'measured.',
      );
    });

    test('walks a longer route and tags each leg independently', () {
      // a -> b: solid (adjacent)
      // b -> d: dashed (c-position missing)
      final segments = tracerouteSegmentsFor([a, b, null, d]);
      expect(segments.length, 2);
      expect(segments[0].points, [a, b]);
      expect(segments[0].dashed, false);
      expect(segments[1].points, [b, d]);
      expect(segments[1].dashed, true);
    });

    test('resets the gap flag after consuming a known point', () {
      // a -> c: dashed (gap)
      // c -> d: solid (no gap was crossed after c)
      final segments = tracerouteSegmentsFor([a, null, c, d]);
      expect(segments.length, 2);
      expect(segments[0].dashed, true);
      expect(segments[1].dashed, false);
    });

    test('leading nulls do not produce a gap from nothing', () {
      // The route starts effectively at b. b -> c is solid because
      // no hop between b and c was lost.
      final segments = tracerouteSegmentsFor([null, b, c]);
      expect(segments.length, 1);
      expect(segments[0].points, [b, c]);
      expect(segments[0].dashed, false);
    });

    test('trailing nulls do not produce ghost segments', () {
      final segments = tracerouteSegmentsFor([a, b, null]);
      expect(segments.length, 1);
      expect(segments[0].points, [a, b]);
      expect(segments[0].dashed, false);
    });

    test('all four points known emits three solid segments', () {
      final segments = tracerouteSegmentsFor([a, b, c, d]);
      expect(segments.length, 3);
      expect(segments.every((s) => !s.dashed), true);
    });
  });

  group('_buildTraceroutePolylines wiring (source pins)', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test('forward path runs through tracerouteSegmentsFor', () {
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'final forwardSegments = tracerouteSegmentsFor(forwardRoute);',
        ),
        true,
        reason:
            'Forward path must use the segmentation helper so a missing '
            'intermediate hop renders as a dashed bridge, not a misleading '
            'solid line that implies a verified direct connection.',
      );
    });

    test('return path runs through tracerouteSegmentsFor', () {
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'final returnSegments = tracerouteSegmentsFor(returnRoute);',
        ),
        true,
        reason:
            'Return path must use the segmentation helper so gap legs '
            'visually distinguish themselves from verified dotted legs.',
      );
    });

    test('failed traceroutes render forward as dashed and skip return', () {
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains('final unverified = !log.response;'),
        true,
        reason:
            'Failed traceroute (response: false) must be treated as fully '
            'unverified so every forward segment is dashed and the return '
            'path is omitted entirely. Otherwise a no-response path renders '
            'as a solid line and reads as a successful direct connection.',
      );
      expect(
        flat.contains('if (unverified) { return polylines; }'),
        true,
        reason:
            'When unverified, the return path must be skipped — there is no '
            'echo back, so there is nothing real to draw.',
      );
    });

    test('dashed segments use StrokePattern.dashed', () {
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains('StrokePattern.dashed(segments: const [12, 8])'),
        true,
        reason:
            'Dashed segments use a 12px dash / 8px gap pattern, distinct '
            'from the dotted return-direction visual so the user can tell '
            'inferred legs from confirmed return legs at a glance.',
      );
    });
  });
}
