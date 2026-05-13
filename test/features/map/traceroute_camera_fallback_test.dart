// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pins for the Sprint 4 traceroute "Show on Map" camera
/// fallback fix (the "Africa bug").
///
/// Pre-fix: when a traceroute had zero valid GPS hops,
/// `_tracerouteBounds` returned null and the `else if` chain that
/// would have fallen back to the user's location was guarded by the
/// outer `if (widget.tracerouteLog != null)` — so the camera landed at
/// `LatLng(0, 0)` (the Gulf of Guinea). The fix introduces a
/// `centerResolved` flag and gates the standard fallback chain on
/// `!centerResolved` so both traceroute-success and traceroute-fail
/// take the same fallback path as the non-traceroute open.
void main() {
  group('Traceroute camera fallback (Africa fix)', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test(
      'introduces a centerResolved gate alongside the LatLng(0,0) default',
      () {
        final flat = source.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          flat.contains('LatLng center = const LatLng(0, 0);'),
          true,
          reason:
              'The 0,0 default stays as a last-resort sentinel — the fix is '
              'about not landing there, not about renaming the default.',
        );
        expect(
          flat.contains('bool centerResolved = false;'),
          true,
          reason:
              'The fallback chain must use an explicit `centerResolved` flag '
              'so the traceroute branch can opt out of the fallback when it '
              'has valid bounds, AND opt INTO the fallback when it does not.',
        );
      },
    );

    test('logs the fallback when traceroute bounds are null', () {
      // The log message is split across adjacent string literals in
      // the source for line-length, so we collapse whitespace before
      // matching.
      final flat = source.replaceAll(RegExp(r"\s+"), ' ');
      expect(
        flat.contains(
          "'[MapScreen] traceroute bounds null - all hops at 0,0; ' "
          "'falling back to user / nodes-with-position chain',",
        ),
        true,
        reason:
            'Triage needs an AppLogging.map marker when this path fires so '
            'a regression (or a real-world repro) leaves a trail.',
      );
    });

    test(
      'locationOnly + nodesWithPosition fallbacks both check !centerResolved',
      () {
        final flat = source.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          flat.contains(
            'if (!centerResolved && widget.locationOnlyMode && '
            'widget.initialLatitude != null && widget.initialLongitude != null)',
          ),
          true,
          reason:
              'The locationOnlyMode branch must be guarded by !centerResolved '
              'so a successful traceroute fit is not overwritten by the '
              'initial-location override.',
        );
        expect(
          flat.contains(
            'else if (!centerResolved && nodesWithPosition.isNotEmpty)',
          ),
          true,
          reason:
              'The nodes-with-position branch must also be guarded by '
              '!centerResolved so a successful traceroute fit survives this '
              'branch. Equally important, when traceroute bounds were null, '
              'this branch must NOW run (it would not have pre-fix because '
              'the outer else-if guarded against it).',
        );
      },
    );

    test('traceroute success path still sets centerResolved = true', () {
      expect(
        source.contains('centerResolved = true;'),
        true,
        reason:
            'When tracerouteBounds is non-null, the fit-to-bounds branch '
            'must mark the center as resolved so the standard fallback '
            'chain does not overwrite it.',
      );
    });

    test('renders no-GPS banner when traceroute has no usable coordinates', () {
      // The Africa fallback fix silently re-centers on the user, but
      // without the banner the user sees a blank map with no route line
      // and no explanation. Pin both halves: (1) the flag derivation,
      // and (2) the StatusBanner.info rendering with the dedicated
      // ARB keys.
      // Whitespace-agnostic so the formatter can rewrap freely.
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'final tracerouteHasNoGps = widget.tracerouteLog != null && '
          '!centerResolved;',
        ),
        true,
        reason:
            'Banner gating flag must be derived from the same '
            '`centerResolved` boolean as the fallback chain so the banner '
            'and the fallback are guaranteed to be in agreement.',
      );
      expect(
        source.contains('if (tracerouteHasNoGps)'),
        true,
        reason: 'Banner must be conditionally rendered.',
      );
      expect(
        source.contains('mapTracerouteNoGpsTitle') &&
            source.contains('mapTracerouteNoGpsSubtitle'),
        true,
        reason:
            'Banner copy must use the dedicated ARB keys, not the older '
            'generic "no data" strings.',
      );
      expect(
        source.contains('StatusBanner.info('),
        true,
        reason:
            'Use the canonical StatusBanner.info factory rather than '
            'hand-rolling a Container so the colour + accessibility are '
            'consistent with other banners.',
      );
    });
  });
}
