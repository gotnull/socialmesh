// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceFavoritesService unfavorite tombstones', () {
    late DeviceFavoritesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = DeviceFavoritesService();
      await service.init();
    });

    test('starts empty', () {
      expect(service.unfavoriteTombstones, isEmpty);
      expect(service.isTombstoned(42), isFalse);
    });

    test(
      'addUnfavoriteTombstone persists and isTombstoned reflects it',
      () async {
        await service.addUnfavoriteTombstone(42);
        await service.addUnfavoriteTombstone(7);

        expect(service.unfavoriteTombstones, {42, 7});
        expect(service.isTombstoned(42), isTrue);
        expect(service.isTombstoned(7), isTrue);
        expect(service.isTombstoned(99), isFalse);
      },
    );

    test('clearUnfavoriteTombstone removes only the given node', () async {
      await service.addUnfavoriteTombstone(42);
      await service.addUnfavoriteTombstone(7);

      await service.clearUnfavoriteTombstone(42);

      expect(service.unfavoriteTombstones, {7});
      expect(service.isTombstoned(42), isFalse);
    });

    test('clearUnfavoriteTombstone is a no-op for unknown nodes', () async {
      await service.addUnfavoriteTombstone(7);

      await service.clearUnfavoriteTombstone(99);

      expect(service.unfavoriteTombstones, {7});
    });

    test('tombstones survive a second init against the same prefs', () async {
      await service.addUnfavoriteTombstone(42);

      final second = DeviceFavoritesService();
      await second.init();

      expect(second.unfavoriteTombstones, {42});
    });

    test('tombstones are independent of favorites and ignored sets', () async {
      await service.addFavorite(1);
      await service.addIgnored(2);
      await service.addUnfavoriteTombstone(3);

      expect(service.favorites, {1});
      expect(service.ignored, {2});
      expect(service.unfavoriteTombstones, {3});

      await service.removeFavorite(1);
      await service.removeIgnored(2);

      expect(service.unfavoriteTombstones, {3});
    });

    test('clearAll wipes tombstones too', () async {
      await service.addFavorite(1);
      await service.addUnfavoriteTombstone(3);

      await service.clearAll();

      expect(service.favorites, isEmpty);
      expect(service.unfavoriteTombstones, isEmpty);
    });
  });
}
