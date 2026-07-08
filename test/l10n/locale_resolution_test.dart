// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:socialmesh/l10n/locale_resolution.dart';

void main() {
  // Mirrors AppLocalizations.supportedLocales: language-only entries.
  const supported = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
    Locale('ru'),
    Locale('uk'),
  ];

  group('resolveAppLocale', () {
    test('carries the device country onto a matched language', () {
      final result = resolveAppLocale(const [Locale('en', 'GB')], supported);
      expect(result.languageCode, 'en');
      expect(result.countryCode, 'GB');
      expect(result.toString(), 'en_GB');
    });

    test('preserves region for a non-English language', () {
      final result = resolveAppLocale(const [Locale('de', 'AT')], supported);
      expect(result.toString(), 'de_AT');
    });

    test('returns the bare supported locale when device has no country', () {
      final result = resolveAppLocale(const [Locale('en')], supported);
      expect(result.countryCode, isNull);
      expect(result.toString(), 'en');
    });

    test('the first matching device locale wins', () {
      final result = resolveAppLocale(const [
        Locale('fr', 'CA'),
        Locale('en', 'GB'),
      ], supported);
      expect(result.toString(), 'fr_CA');
    });

    test('skips unsupported languages and matches the next device locale', () {
      final result = resolveAppLocale(const [
        Locale('ro', 'RO'),
        Locale('en', 'GB'),
      ], supported);
      expect(result.toString(), 'en_GB');
    });

    test('falls back to the first supported locale when nothing matches', () {
      final result = resolveAppLocale(const [Locale('ro', 'RO')], supported);
      expect(result, supported.first);
    });

    test(
      'falls back to the first supported locale when device list is null',
      () {
        expect(resolveAppLocale(null, supported), supported.first);
      },
    );

    test('preserves the script subtag alongside the country', () {
      final result = resolveAppLocale(
        [
          const Locale.fromSubtags(
            languageCode: 'sr',
            scriptCode: 'Cyrl',
            countryCode: 'RS',
          ),
        ],
        const [Locale('sr')],
      );
      expect(result.languageCode, 'sr');
      expect(result.scriptCode, 'Cyrl');
      expect(result.countryCode, 'RS');
    });
  });

  group('resolved locale drives date ordering (the reported bug)', () {
    setUpAll(initializeDateFormatting);

    test('en_GB device orders dates day-first (dd/MM/y)', () {
      final locale = resolveAppLocale(const [Locale('en', 'GB')], supported);
      expect(DateFormat.yMd(locale.toString()).pattern, 'dd/MM/y');
    });

    test('en_AU device orders dates day-first (dd/MM/y)', () {
      final locale = resolveAppLocale(const [Locale('en', 'AU')], supported);
      expect(DateFormat.yMd(locale.toString()).pattern, 'dd/MM/y');
    });

    test('en_US device orders dates month-first (M/d/y)', () {
      final locale = resolveAppLocale(const [Locale('en', 'US')], supported);
      expect(DateFormat.yMd(locale.toString()).pattern, 'M/d/y');
    });
  });
}
