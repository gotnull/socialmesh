// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

import 'app_localizations.dart';

/// Cached preferred locale from the in-app picker.
///
/// Utility code (notifications, isolates, background callbacks) cannot reach
/// the Riverpod container or BuildContext, so the picker selection is cached
/// here. `LocaleNotifier` keeps this in sync via [setPreferredLocaleOverride].
///
/// `null` means "use OS locale" (system default).
Locale? _preferredLocaleOverride;

/// Update the cached picker selection. Called by `LocaleNotifier` whenever
/// the user changes language in Appearance & Accessibility settings, and on
/// app boot when the persisted setting is loaded.
void setPreferredLocaleOverride(Locale? locale) {
  _preferredLocaleOverride = locale;
}

/// Returns [AppLocalizations] for the effective locale.
///
/// Resolution order:
/// 1. In-app picker selection ([_preferredLocaleOverride]) if set.
/// 2. OS locale ([PlatformDispatcher.instance.locale]).
/// 3. Language-only fallback (e.g. `en_US` -> `en`).
/// 4. English.
///
/// Falls back gracefully through unsupported locales (e.g. `pl_PL`) without
/// throwing the [FlutterError] that raw [lookupAppLocalizations] raises.
AppLocalizations safeL10n() {
  final override = _preferredLocaleOverride;
  if (override != null) {
    try {
      return lookupAppLocalizations(override);
    } catch (_) {}
    try {
      return lookupAppLocalizations(Locale(override.languageCode));
    } catch (_) {}
  }
  final locale = PlatformDispatcher.instance.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {}
  try {
    return lookupAppLocalizations(Locale(locale.languageCode));
  } catch (_) {}
  return lookupAppLocalizations(const Locale('en'));
}
