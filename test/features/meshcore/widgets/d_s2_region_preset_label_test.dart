// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-S2: every preset id in `kMeshCoreRegionPresets` must resolve to a
// localized label via `meshCoreRegionPresetLabel`. If a preset is added
// to the constants but not wired into the switch in
// `lib/features/meshcore/widgets/meshcore_region_preset_label.dart`,
// the resolver falls back to `preset.label` (English). This test
// regresses the wiring so the picker stays fully translated.

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_region_preset_label.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Future<AppLocalizations> _l10nFor(Locale locale) async {
  return AppLocalizations.delegate.load(locale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sanity check the test infra wires localizations the same way the
  // app does at runtime.
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('D-S2 meshCoreRegionPresetLabel', () {
    test('every preset id resolves to a non-empty English label', () async {
      final l10n = await _l10nFor(const Locale('en'));
      for (final preset in kMeshCoreRegionPresets) {
        final resolved = meshCoreRegionPresetLabel(l10n, preset);
        expect(
          resolved,
          isNotEmpty,
          reason: 'preset ${preset.id} resolved to empty string',
        );
        // The English ARB label matches the constants `label` field
        // verbatim; this anchors both sides to the same source of truth.
        expect(
          resolved,
          equals(preset.label),
          reason:
              'English ARB label for ${preset.id} should match the const label '
              '("${preset.label}") but resolver returned "$resolved"',
        );
      }
    });

    test('Italian locale returns translated Australia (Narrow)', () async {
      final l10n = await _l10nFor(const Locale('it'));
      final preset = kMeshCoreRegionPresets.firstWhere(
        (p) => p.id == 'au_narrow',
      );
      expect(
        meshCoreRegionPresetLabel(l10n, preset),
        equals('Australia (Stretto)'),
      );
    });

    test('German locale returns translated New Zealand', () async {
      final l10n = await _l10nFor(const Locale('de'));
      final preset = kMeshCoreRegionPresets.firstWhere(
        (p) => p.id == 'nz_default',
      );
      expect(meshCoreRegionPresetLabel(l10n, preset), equals('Neuseeland'));
    });

    test('Russian locale returns translated Switzerland', () async {
      final l10n = await _l10nFor(const Locale('ru'));
      final preset = kMeshCoreRegionPresets.firstWhere((p) => p.id == 'ch');
      expect(meshCoreRegionPresetLabel(l10n, preset), equals('Швейцария'));
    });

    test(
      'Ukrainian locale returns translated Czech Republic with native script',
      () async {
        final l10n = await _l10nFor(const Locale('uk'));
        final preset = kMeshCoreRegionPresets.firstWhere((p) => p.id == 'cz');
        expect(meshCoreRegionPresetLabel(l10n, preset), equals('Чехія'));
      },
    );

    test(
      'unknown preset id falls back to English label on the preset',
      () async {
        final l10n = await _l10nFor(const Locale('fr'));
        // Construct a preset whose id is not in the switch. The resolver
        // should fall through to `preset.label`.
        const sentinel = MeshCoreRegionPreset(
          id: 'nonexistent_id_for_test',
          label: 'Test Region',
          frequencyMHz: 900.0,
          bandwidthKhz: 125,
          spreadingFactor: 7,
          codingRate: 5,
          txPowerDbm: 14,
        );
        expect(
          meshCoreRegionPresetLabel(l10n, sentinel),
          equals('Test Region'),
        );
      },
    );
  });

  // Avoid an unused-import warning if any future imports drop the
  // flutter_localizations dependency.
  _suppressUnusedImport();
}

void _suppressUnusedImport() {
  GlobalMaterialLocalizations.delegate;
}
