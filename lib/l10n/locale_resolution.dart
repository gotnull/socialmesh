// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

// Resolves the app locale from the device's preferred locales against the
// locales the app ships translations for.
//
// Flutter's default resolution can hand an unsupported locale (e.g. ro_RO) to
// the AppLocalizations delegate, which throws. Resolve manually: pick the first
// device locale whose language code matches a supported locale, otherwise fall
// back to the first supported locale (English).
//
// The matched language keeps the device's country (and script) subtags so date
// and number formatting follow the device region. The ARB set is language-only,
// so a UK/AU device would otherwise collapse to a bare `en`, which intl treats
// as US ordering (M/d/y). String lookup matches on language code, so `en_GB`
// still resolves to the `en` translations while dates order as dd/MM/y.
Locale resolveAppLocale(
  List<Locale>? deviceLocales,
  Iterable<Locale> supportedLocales,
) {
  if (deviceLocales != null) {
    for (final locale in deviceLocales) {
      for (final supported in supportedLocales) {
        if (supported.languageCode == locale.languageCode) {
          final country = locale.countryCode;
          if (country == null || country.isEmpty) {
            return supported;
          }
          return Locale.fromSubtags(
            languageCode: supported.languageCode,
            scriptCode: locale.scriptCode,
            countryCode: country,
          );
        }
      }
    }
  }
  return supportedLocales.first;
}
