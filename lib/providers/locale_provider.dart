// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../l10n/l10n_utils.dart';
import 'app_providers.dart';

/// Provider for the user's preferred locale.
///
/// Returns `null` when "System Default" is selected, meaning the app
/// should use the device locale. Returns a [Locale] when the user has
/// explicitly chosen a language.
///
/// Keeps `l10n_utils.setPreferredLocaleOverride` in sync so utility code
/// (notifications, presence_utils, isolate-bound callbacks) consults the
/// in-app picker instead of falling back to OS locale only.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      setPreferredLocaleOverride(null);
      return null;
    }

    final code = settings.preferredLocale;
    if (code == null) {
      setPreferredLocaleOverride(null);
      return null;
    }

    final locale = Locale(code);
    setPreferredLocaleOverride(locale);
    return locale;
  }

  /// Set the preferred locale. Pass `null` for system default.
  Future<void> setLocale(Locale? locale) async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setPreferredLocale(locale?.languageCode);
    setPreferredLocaleOverride(locale);
    state = locale;
    AppLogging.settings(
      'Locale changed to ${locale?.languageCode ?? "system"}',
    );
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
