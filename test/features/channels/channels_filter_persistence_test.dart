// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/channels/channels_screen.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// Channels list filter persistence.
//
// The filter chips (All / Unread / Primary / ...) used to be a plain
// State field, so the choice reset to All on every launch. The chosen
// filter now persists by enum NAME (not index) via SettingsService so
// reordering or extending ChannelFilter never remaps a saved choice.
void main() {
  group('SettingsService - channelsListFilter', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to null for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.channelsListFilter, isNull);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setChannelsListFilter(ChannelFilter.unread.name);

      final b = SettingsService();
      await b.init();
      expect(b.channelsListFilter, 'unread');
    });
  });

  group('channelFilterFromName', () {
    test('resolves every known filter by name', () {
      for (final filter in ChannelFilter.values) {
        expect(channelFilterFromName(filter.name), filter);
      }
    });

    test('null (never chosen) falls back to all', () {
      expect(channelFilterFromName(null), ChannelFilter.all);
    });

    test('unknown name from a newer app version falls back to all', () {
      expect(
        channelFilterFromName('someFutureFilter'),
        ChannelFilter.all,
        reason:
            'A downgrade must not crash or mis-select when the stored name '
            'was written by a build with more filter values.',
      );
    });
  });
}
