// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/messages_view_mode_provider.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

Future<ProviderContainer> _containerWithPrefs(
  Map<String, Object> initialPrefs,
) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final settings = SettingsService();
  await settings.init();
  final container = ProviderContainer(
    overrides: [
      settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contacts and channels view modes toggle independently', () async {
    final container = await _containerWithPrefs({});

    expect(container.read(messagesCompactViewProvider), isFalse);
    expect(container.read(channelsCompactViewProvider), isFalse);

    await container.read(messagesCompactViewProvider.notifier).toggle();

    expect(container.read(messagesCompactViewProvider), isTrue);
    expect(container.read(channelsCompactViewProvider), isFalse);

    await container.read(channelsCompactViewProvider.notifier).toggle();
    await container.read(messagesCompactViewProvider.notifier).toggle();

    expect(container.read(messagesCompactViewProvider), isFalse);
    expect(container.read(channelsCompactViewProvider), isTrue);
  });

  test('channels view mode seeds from the legacy shared key', () async {
    final container = await _containerWithPrefs({
      'messages_view_mode_index': 1,
    });

    // A user who had compact view on keeps it on both tabs.
    expect(container.read(messagesCompactViewProvider), isTrue);
    expect(container.read(channelsCompactViewProvider), isTrue);
  });

  test('channels key wins over the legacy key once set', () async {
    final container = await _containerWithPrefs({
      'messages_view_mode_index': 1,
      'channels_view_mode_index': 0,
    });

    expect(container.read(messagesCompactViewProvider), isTrue);
    expect(container.read(channelsCompactViewProvider), isFalse);
  });

  test('toggling channels does not overwrite the contacts key', () async {
    final container = await _containerWithPrefs({
      'messages_view_mode_index': 1,
    });

    await container.read(channelsCompactViewProvider.notifier).toggle();

    expect(container.read(channelsCompactViewProvider), isFalse);
    expect(container.read(messagesCompactViewProvider), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('messages_view_mode_index'), 1);
    expect(prefs.getInt('channels_view_mode_index'), 0);
  });
}
