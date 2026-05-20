// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 5 — ringtone built-in presets curated default set (Section P).
///
/// Source-level pins protecting the boundary so the next contributor
/// can't accidentally remove the Featured-slice behaviour by reverting
/// to `_builtInPresets.asMap()` style iteration.
void main() {
  group('Featured built-in ringtones', () {
    final ringtoneFile = File('lib/features/settings/ringtone_screen.dart');
    late String source;

    setUpAll(() {
      expect(ringtoneFile.existsSync(), true);
      source = ringtoneFile.readAsStringSync();
    });

    test('reserves _featuredBuiltInCount = 10 (curated essentials)', () {
      // The first 10 entries of _builtInPresets are the universally
      // recognisable classics: Meshtastic Default, Nokia, Zelda Get
      // Item, Mario x3, Morse CQ, Simple Beep, Alert, Ping. Past that
      // the list goes alphabetical by band/song — clearly browse
      // territory.
      expect(
        source.contains('static const int _featuredBuiltInCount = 10;'),
        true,
        reason:
            'The slice point must stay at 10 unless the upstream preset '
            'ordering changes. If it does, this pin should change with it.',
      );
    });

    test('renders visiblePresets, not the full _builtInPresets list', () {
      // The pre-Sprint-5 code iterated _builtInPresets directly. The
      // fix wraps the column in a Builder that computes visiblePresets
      // based on _showAllBuiltIns + _featuredBuiltInCount. Pin the
      // distinctive call-chain fragments rather than the whole
      // expression so dart format can rewrap the ternary freely.
      expect(
        source.contains('final visiblePresets = _showAllBuiltIns'),
        true,
        reason:
            'Local variable `visiblePresets` must be the result of a '
            'ternary on `_showAllBuiltIns` — that is the slice gate.',
      );
      expect(
        source.contains('.take(_featuredBuiltInCount)'),
        true,
        reason:
            'The slice must use take() not skip()/sublist() — take() handles '
            'the case where _featuredBuiltInCount > _builtInPresets.length '
            'gracefully (returns the whole list rather than throwing).',
      );
      expect(
        source.contains('visiblePresets.asMap().entries.map('),
        true,
        reason:
            'The render loop must iterate the sliced list, not the full '
            '_builtInPresets — otherwise the slice is cosmetic-only.',
      );
    });

    test(
      'divider gate uses visiblePresets.length not _builtInPresets.length',
      () {
        // The trailing divider must hide on the LAST visible item, not
        // on what would have been the last item of the full list — if it
        // checks _builtInPresets.length the slice would render a stray
        // divider after the last visible row.
        expect(source.contains('if (index < visiblePresets.length - 1)'), true);
      },
    );

    test('expansion footer renders only when there are hidden presets', () {
      expect(
        source.contains('if (builtInRingtonePresets.length >'),
        true,
        reason:
            'Footer should not render when the curated set already covers '
            'every preset (e.g. if someone trims the master list to 8).',
      );
      expect(
        source.contains('_featuredBuiltInCount) ...['),
        true,
        reason:
            'Slice gate on the footer must use _featuredBuiltInCount, not '
            'a magic number.',
      );
    });

    test('expansion footer uses both ARB keys (expanded + collapsed copy)', () {
      expect(source.contains('context.l10n.ringtoneShowFewerBuiltIn'), true);
      expect(source.contains('context.l10n.ringtoneShowAllBuiltIn('), true);
    });

    test('toggle dispatches haptics + AppLogging marker', () {
      expect(
        source.contains('HapticFeedback.selectionClick()'),
        true,
        reason:
            'Settings toggles in this app fire HapticFeedback.selectionClick '
            '— the expansion footer should match.',
      );
      expect(
        source.contains("'[Ringtone] showAllBuiltIns toggled to"),
        true,
        reason:
            'AppLogging marker required so triage can see when a user has '
            'expanded the full list.',
      );
    });

    test('state is screen-local (no SharedPreferences persistence)', () {
      // The expansion state intentionally does NOT persist across
      // visits — each entry to the ringtone screen starts collapsed so
      // first-time users see the curated set. Returning users who
      // want to find a specific tone tap Show all again.
      expect(source.contains('bool _showAllBuiltIns = false;'), true);
      // No SharedPreferences key for this — confirm we didn't drift.
      expect(
        source.contains("setBool('show_all_builtin_ringtones'"),
        false,
        reason:
            'If this trips, someone added persistence for the expansion '
            'state. Drop it — the collapsed-by-default UX is intentional.',
      );
    });
  });
}
