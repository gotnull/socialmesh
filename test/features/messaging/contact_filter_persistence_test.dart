// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/messaging/messaging_screen.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// Contacts list filter persistence.
//
// Mirror of the channels-filter persistence: the chip choice
// (All / Online / Unread / Messaged / Favorites) persists by enum NAME
// via SettingsService and unknown or null names fall back to All.
void main() {
  group('SettingsService - contactsListFilter', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to null for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.contactsListFilter, isNull);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setContactsListFilter(ContactFilter.unread.name);

      final b = SettingsService();
      await b.init();
      expect(b.contactsListFilter, 'unread');
    });
  });

  group('contactFilterFromName', () {
    test('resolves every known filter by name', () {
      for (final filter in ContactFilter.values) {
        expect(contactFilterFromName(filter.name), filter);
      }
    });

    test('null (never chosen) falls back to all', () {
      expect(contactFilterFromName(null), ContactFilter.all);
    });

    test('unknown name from a newer app version falls back to all', () {
      expect(
        contactFilterFromName('someFutureFilter'),
        ContactFilter.all,
        reason:
            'A downgrade must not crash or mis-select when the stored name '
            'was written by a build with more filter values.',
      );
    });
  });
}
