// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

/// Copy regression tests for the BLE pairing-refresh card.
///
/// The previous copy ("Your phone removed the stored pairing info for
/// this device …") implied an unexplained phone-side failure. The
/// real cause is almost always radio-side: a factory reset, region
/// reset, or BLE-identity reset on the device clears the bond, so the
/// phone's saved pairing no longer matches.
///
/// These tests pin the user-facing requirements:
///
/// 1. The card title is the reset-aware form ("Pairing needs to be
///    refreshed").
/// 2. The body explains the radio-side causes and the user-side
///    recovery (forget then re-pair).
/// 3. Action labels use the imperative form ("Open Bluetooth
///    Settings" / "Scan again").
/// 4. None of the public-facing strings blame the phone or the app.
/// 5. The same neutral framing is mirrored across the region-selection
///    flow and across all shipped locales (en, it, pt).

const _bannedPhrases = <String>[
  'Your phone removed',
  'your phone removed',
  // Italian "Il telefono ha rimosso" — pre-fix copy.
  'Il telefono ha rimosso',
  'il telefono ha rimosso',
  // Portuguese "Seu telefone removeu" — pre-fix copy.
  'Seu telefone removeu',
  'seu telefone removeu',
];

Future<AppLocalizations> _load(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  test('English: scannerPairingRefresh* copy is reset-aware', () async {
    final l = await _load(const Locale('en'));

    expect(l.scannerPairingRefreshTitle, 'Pairing needs to be refreshed');
    expect(
      l.scannerPairingRefreshOpenBluetoothSettings,
      'Open Bluetooth Settings',
    );
    expect(l.scannerPairingRefreshScanAgain, 'Scan again');

    final body = l.scannerPairingRefreshBody;
    // Reset-aware framing: at least one of the radio-side causes the
    // user might recognize (factory / region / device reset) appears.
    expect(
      body,
      anyOf(
        contains('factory reset'),
        contains('region'),
        contains('device reset'),
      ),
      reason:
          'Body must explain the radio-side reasons (factory / '
          'region / device reset) so the user understands the cause.',
    );
    // Recovery instruction is present.
    expect(
      body.toLowerCase(),
      contains('bluetooth'),
      reason:
          'Body must direct the user to Bluetooth settings to '
          'remove the stale pairing.',
    );
    expect(
      body.toLowerCase(),
      anyOf(contains('pair with'), contains('pair again'), contains('re-pair')),
      reason: 'Body must instruct the user to pair the device again.',
    );
  });

  test(
    'English: scannerPairingInvalidatedError no longer blames the phone',
    () async {
      final l = await _load(const Locale('en'));
      expect(
        l.scannerPairingInvalidatedError,
        isNot(matches(RegExp(_bannedPhrases.join('|')))),
        reason:
            'The inline pairing-invalidated error must not imply '
            'a phone-side failure ("Your phone removed …" was the '
            'pre-fix wording).',
      );
      expect(
        l.scannerPairingInvalidatedError.toLowerCase(),
        anyOf(
          contains('refreshed'),
          contains('identity has changed'),
          contains('forget the device'),
        ),
        reason: 'The inline error should reuse the reset-aware framing.',
      );
    },
  );

  test(
    'English: regionSelection pairing copy no longer blames the phone',
    () async {
      final l = await _load(const Locale('en'));
      for (final s in <String>[
        l.regionSelectionPairingHintMessage,
        l.regionSelectionPairingInvalidation,
      ]) {
        expect(
          s,
          isNot(matches(RegExp(_bannedPhrases.join('|')))),
          reason:
              'Region-selection pairing copy must not blame the phone '
              'either — it is the same recovery scenario reached via the '
              'region apply path.',
        );
      }
    },
  );

  test('all shipped locales (en, it, pt) carry the reset-aware refresh keys '
      'and none of them contain the banned phone-blaming phrasing', () async {
    // Russian (ru) is community-managed by skrashevich and is
    // intentionally not asserted here — translators pick keys up
    // from en.arb at their own cadence.
    const locales = <Locale>[Locale('en'), Locale('it'), Locale('pt')];
    for (final locale in locales) {
      final l = await _load(locale);
      final all = <String>[
        l.scannerPairingRefreshTitle,
        l.scannerPairingRefreshBody,
        l.scannerPairingRefreshOpenBluetoothSettings,
        l.scannerPairingRefreshScanAgain,
        l.scannerPairingInvalidatedError,
        l.regionSelectionPairingHintMessage,
        l.regionSelectionPairingInvalidation,
      ];
      for (final s in all) {
        expect(
          s,
          isNotEmpty,
          reason:
              'Locale ${locale.languageCode}: pairing-refresh keys '
              'must be populated (Flutter falls back to en for '
              'missing values, so an empty string indicates a typo).',
        );
        for (final banned in _bannedPhrases) {
          expect(
            s.contains(banned),
            isFalse,
            reason:
                'Locale ${locale.languageCode}: copy contains '
                'banned phone-blaming phrase "$banned" in: $s',
          );
        }
      }
    }
  });
}
