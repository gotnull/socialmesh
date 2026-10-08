// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/presence/presence_encounter_labels.dart';
import 'package:socialmesh/l10n/app_localizations_de.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/l10n/app_localizations_ru.dart';
import 'package:socialmesh/models/node_encounter.dart';

final _en = AppLocalizationsEn();

void main() {
  group('encounterSummaryLabel', () {
    test('first encounter', () {
      expect(encounterSummaryLabel(_en, 1), 'First encounter');
    });

    test('repeat encounters count up', () {
      final now = DateTime(2026, 1, 24, 12);
      var encounter = NodeEncounter.firstEncounter(1, now);
      encounter = encounter.recordEncounter(now);
      encounter = encounter.recordEncounter(now);
      expect(
        encounterSummaryLabel(_en, encounter.encounterCount),
        'Seen 3 times',
      );
    });
  });

  group('relationshipAgeLabel', () {
    String ageFrom(DateTime firstSeen) {
      final now = DateTime(2026, 1, 24, 12);
      final encounter = NodeEncounter.firstEncounter(1, firstSeen);
      return relationshipAgeLabel(_en, encounter.relationshipAgeDays(now));
    }

    test('today', () {
      expect(ageFrom(DateTime(2026, 1, 24, 12)), 'First seen today');
    });

    test('yesterday', () {
      expect(ageFrom(DateTime(2026, 1, 23, 12)), 'First seen yesterday');
    });

    test('days', () {
      expect(ageFrom(DateTime(2026, 1, 20, 12)), 'First seen 4 days ago');
    });

    test('one week covers days 7 to 13', () {
      expect(ageFrom(DateTime(2026, 1, 14, 12)), 'First seen 1 week ago');
      expect(relationshipAgeLabel(_en, 13), 'First seen 1 week ago');
    });

    test('weeks', () {
      expect(ageFrom(DateTime(2026, 1, 1, 12)), 'First seen 3 weeks ago');
    });

    test('one month covers days 30 to 59', () {
      expect(ageFrom(DateTime(2025, 12, 24, 12)), 'First seen 1 month ago');
      expect(relationshipAgeLabel(_en, 59), 'First seen 1 month ago');
    });

    test('months', () {
      expect(ageFrom(DateTime(2025, 9, 24, 12)), 'First seen 4 months ago');
    });

    test('follows the supplied locale', () {
      expect(
        relationshipAgeLabel(AppLocalizationsDe(), 21),
        AppLocalizationsDe().presenceFirstSeenWeeksAgo(3),
      );
      expect(
        relationshipAgeLabel(AppLocalizationsRu(), 5),
        'Впервые замечен 5 дней назад',
      );
    });
  });
}
