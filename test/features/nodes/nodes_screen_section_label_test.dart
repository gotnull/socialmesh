// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

// Pins the renamed section-header / per-card sub-label keys across every
// shipped locale. The old keys (nodesScreenSectionInactive,
// presenceStatusInactive) were renamed to *Quiet because rendering
// "Inactive" for a node heard 10-60 minutes ago felt wrong. Singular form
// across every locale so the section header and per-card sub-label match.
Future<AppLocalizations> _load(Locale locale) =>
    AppLocalizations.delegate.load(locale);

const _expectedQuietSection = <String, String>{
  'en': 'Quiet',
  'de': 'Ruhig',
  'es': 'En calma',
  'fr': 'Calme',
  'it': 'Tranquillo',
  'pt': 'Calmo',
  'ru': 'Тихий',
  'uk': 'Тихий',
};

// Words that, if they appear as the *whole* value for either renamed
// key, indicate a regression to the old "Inactive" wording. Loose
// matches like "calma" (es) intentionally allowed — the banned list is
// for the literal pre-rename strings.
const _bannedExactValues = <String>{
  'Inactive',
  'Inaktiv',
  'Inactivo',
  'Inactif',
  'Inattivi',
  'Inattivo',
  'Inativos',
  'Inativo',
  'Неактивные',
  'Неактивен',
  'Неактивні',
  'Неактивний',
};

void main() {
  group('nodesScreenSectionQuiet — section header for stale band', () {
    for (final entry in _expectedQuietSection.entries) {
      test('${entry.key} resolves to "${entry.value}"', () async {
        final l = await _load(Locale(entry.key));
        expect(l.nodesScreenSectionQuiet, entry.value);
        expect(_bannedExactValues, isNot(contains(l.nodesScreenSectionQuiet)));
      });
    }
  });

  group('presenceStatusQuiet — per-card sub-label for stale band', () {
    for (final entry in _expectedQuietSection.entries) {
      test('${entry.key} resolves to "${entry.value}"', () async {
        final l = await _load(Locale(entry.key));
        expect(l.presenceStatusQuiet, entry.value);
        expect(_bannedExactValues, isNot(contains(l.presenceStatusQuiet)));
      });
    }
  });

  test('section header and per-card sub-label agree per locale', () async {
    for (final lang in _expectedQuietSection.keys) {
      final l = await _load(Locale(lang));
      expect(
        l.nodesScreenSectionQuiet,
        l.presenceStatusQuiet,
        reason:
            'Locale $lang: section header must match per-card sub-label so '
            'the user sees the same word in both places.',
      );
    }
  });
}
