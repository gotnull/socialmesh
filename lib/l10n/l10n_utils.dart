// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

import 'app_localizations.dart';

/// Returns [AppLocalizations] for the current device locale, falling back
/// through language-only then English for any locale not in
/// [AppLocalizations.supportedLocales]. This avoids the [FlutterError] that
/// [lookupAppLocalizations] throws for unsupported locales (e.g. pl_PL).
AppLocalizations safeL10n() {
  final locale = PlatformDispatcher.instance.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {}
  try {
    return lookupAppLocalizations(Locale(locale.languageCode));
  } catch (_) {}
  return lookupAppLocalizations(const Locale('en'));
}
