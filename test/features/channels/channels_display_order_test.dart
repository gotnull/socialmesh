// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/channels_display_order_provider.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// App-side display order for the Channels list. Purely presentational:
// the radio's slot assignment (and therefore routing) never changes, so
// the order is a plain persisted list of slot indices applied at build.
void main() {
  ChannelConfig channel(int index) =>
      ChannelConfig(index: index, name: 'ch$index', psk: const []);

  group('SettingsService - channelsDisplayOrder', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to empty (slot order) for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.channelsDisplayOrder, isEmpty);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setChannelsDisplayOrder([2, 0, 1]);

      final b = SettingsService();
      await b.init();
      expect(b.channelsDisplayOrder, [2, 0, 1]);
    });
  });

  group('applyChannelDisplayOrder', () {
    test('empty order is a passthrough preserving slot order', () {
      final channels = [channel(0), channel(1), channel(2)];
      expect(applyChannelDisplayOrder(channels, const []), same(channels));
    });

    test('sorts by the saved order', () {
      final channels = [channel(0), channel(1), channel(2)];
      final sorted = applyChannelDisplayOrder(channels, const [2, 0, 1]);
      expect(sorted.map((c) => c.index), [2, 0, 1]);
    });

    test('slots missing from the order follow it in slot order', () {
      // Channels 3 and 5 were added after the last reorder.
      final channels = [channel(0), channel(1), channel(3), channel(5)];
      final sorted = applyChannelDisplayOrder(channels, const [1, 0]);
      expect(sorted.map((c) => c.index), [1, 0, 3, 5]);
    });

    test('order entries for deleted slots are ignored harmlessly', () {
      final channels = [channel(0), channel(2)];
      final sorted = applyChannelDisplayOrder(channels, const [7, 2, 0]);
      expect(sorted.map((c) => c.index), [2, 0]);
    });
  });
}
