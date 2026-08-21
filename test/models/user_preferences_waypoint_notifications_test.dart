// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the `waypointNotificationsEnabled` field on [UserPreferences] — the
/// user-level toggle that gates the inbound shared-waypoint notification.
///
/// The provider-layer gate (in `WaypointsNotifier`) reads this preference via
/// `SettingsService` synchronously, so model round-trips must preserve the
/// field. Cloud sync writes it through `UserProfile.preferences` and the
/// merge in `profile_providers.dart` uses `copyWith` to layer remote changes
/// onto local state.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/user_profile.dart';

void main() {
  group('UserPreferences.waypointNotificationsEnabled', () {
    test('JSON round-trips the field when set', () {
      const prefs = UserPreferences(waypointNotificationsEnabled: false);
      final json = prefs.toJson();
      expect(json['waypointNotificationsEnabled'], equals(false));

      final back = UserPreferences.fromJson(json);
      expect(back.waypointNotificationsEnabled, equals(false));
    });

    test('JSON omits the field when null (sparse encoding)', () {
      const prefs = UserPreferences();
      final json = prefs.toJson();
      expect(
        json.containsKey('waypointNotificationsEnabled'),
        isFalse,
        reason:
            'sparse encoding — null preferences must not be written so '
            'older clients reading the document only see fields the '
            'newer client explicitly set',
      );
    });

    test('copyWith preserves the field when not overridden', () {
      const prefs = UserPreferences(waypointNotificationsEnabled: true);
      final updated = prefs.copyWith(notificationsEnabled: false);
      expect(updated.waypointNotificationsEnabled, isTrue);
      expect(updated.notificationsEnabled, isFalse);
    });

    test('copyWith allows explicit override', () {
      const prefs = UserPreferences(waypointNotificationsEnabled: true);
      final updated = prefs.copyWith(waypointNotificationsEnabled: false);
      expect(updated.waypointNotificationsEnabled, isFalse);
    });

    test('fromJson missing key → null (treated as default-allow upstream)', () {
      // The provider gate defaults this to true when the SettingsService
      // hasn't initialised yet; the model field itself is null when the
      // cloud document doesn't carry it, matching the rest of
      // UserPreferences' nullable surface.
      final back = UserPreferences.fromJson(const {});
      expect(back.waypointNotificationsEnabled, isNull);
    });
  });
}
