// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Clear Stale Nodes is off for a fresh install', () async {
    final service = SettingsService();
    await service.init();
    expect(service.purgeStaleNodeDays, 0);
  });

  test('the chosen days persist across SettingsService instances', () async {
    final first = SettingsService();
    await first.init();
    await first.setPurgeStaleNodeDays(30);

    final second = SettingsService();
    await second.init();
    expect(second.purgeStaleNodeDays, 30);

    await second.setPurgeStaleNodeDays(0);
    final third = SettingsService();
    await third.init();
    expect(third.purgeStaleNodeDays, 0);
  });
}
