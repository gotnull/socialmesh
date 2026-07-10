// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

// The Messages surface compact-view toggle (Contacts + Channels tabs share
// one overflow menu, so one value covers both lists). Persisted as
// messages_view_mode_index using the same 0 = cards / 1 = compact scheme
// as the Nodes screen, so the preference survives app relaunches.
void main() {
  group('SettingsService - messagesViewModeIndex', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to cards (0) for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.messagesViewModeIndex, 0);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setMessagesViewModeIndex(1);

      final b = SettingsService();
      await b.init();
      expect(b.messagesViewModeIndex, 1);
    });
  });
}
