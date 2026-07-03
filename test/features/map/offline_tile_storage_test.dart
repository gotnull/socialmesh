// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/map/offline_tiles/offline_tile_storage.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.socialmesh/settings');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_tile_storage');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  OfflineTileStorage storage({bool isAndroid = true}) => OfflineTileStorage(
    channel: channel,
    internalDir: () async => Directory(p.join(tempDir.path, 'docs')),
    isAndroid: isAndroid,
  );

  group('removableRoot', () {
    test('joins the cache folder onto the first removable dir', () async {
      final sd = p.join(tempDir.path, 'sd');
      mockChannel((call) async {
        expect(call.method, 'getRemovableStorageDirs');
        return [sd];
      });
      expect(
        await storage().removableRoot(),
        p.join(sd, OfflineTileStorage.cacheFolderName),
      );
    });

    test('returns null when no removable volume is mounted', () async {
      mockChannel((call) async => <String>[]);
      expect(await storage().removableRoot(), isNull);
    });

    test('returns null when the platform call fails', () async {
      mockChannel((call) async => throw PlatformException(code: 'UNAVAILABLE'));
      expect(await storage().removableRoot(), isNull);
    });

    test('returns null off Android without touching the channel', () async {
      mockChannel((call) async => fail('channel must not be invoked'));
      expect(await storage(isAndroid: false).removableRoot(), isNull);
    });
  });

  group('probeWritable', () {
    test('creates the directory and cleans up its probe file', () async {
      final dir = p.join(tempDir.path, 'probe', 'nested');
      expect(await storage().probeWritable(dir), isTrue);
      expect(Directory(dir).existsSync(), isTrue);
      expect(Directory(dir).listSync(), isEmpty);
    });

    test('returns false when the directory cannot be created', () async {
      // A path nested under an existing FILE cannot be created.
      final blocker = File(p.join(tempDir.path, 'blocker'));
      await blocker.writeAsString('x');
      final dir = p.join(blocker.path, 'sub');
      expect(await storage().probeWritable(dir), isFalse);
    });
  });

  group('resolveRoot', () {
    test('internal preference resolves without touching the channel', () async {
      mockChannel((call) async => fail('channel must not be invoked'));
      final root = await storage().resolveRoot(
        OfflineTileStorageLocation.internal,
      );
      expect(root.fellBack, isFalse);
      expect(
        root.path,
        p.join(tempDir.path, 'docs', OfflineTileStorage.cacheFolderName),
      );
    });

    test('sd preference resolves to a writable card', () async {
      final sd = p.join(tempDir.path, 'sd');
      mockChannel((call) async => [sd]);
      final root = await storage().resolveRoot(
        OfflineTileStorageLocation.sdCard,
      );
      expect(root.fellBack, isFalse);
      expect(root.path, p.join(sd, OfflineTileStorage.cacheFolderName));
    });

    test('sd preference falls back to internal when no card', () async {
      mockChannel((call) async => <String>[]);
      final root = await storage().resolveRoot(
        OfflineTileStorageLocation.sdCard,
      );
      expect(root.fellBack, isTrue);
      expect(
        root.path,
        p.join(tempDir.path, 'docs', OfflineTileStorage.cacheFolderName),
      );
    });

    test('sd preference falls back when the card is unwritable', () async {
      final blocker = File(p.join(tempDir.path, 'blocker'));
      await blocker.writeAsString('x');
      mockChannel((call) async => [blocker.path]);
      final root = await storage().resolveRoot(
        OfflineTileStorageLocation.sdCard,
      );
      expect(root.fellBack, isTrue);
      expect(
        root.path,
        p.join(tempDir.path, 'docs', OfflineTileStorage.cacheFolderName),
      );
    });
  });

  group('directorySizeBytes / deleteDirectory', () {
    test('sums nested file sizes and deletes recursively', () async {
      final dir = Directory(p.join(tempDir.path, 'cache', 'fm_cache'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'a.bin')).writeAsBytes(List.filled(10, 0));
      await File(p.join(dir.path, 'b.bin')).writeAsBytes(List.filled(32, 0));

      final root = p.join(tempDir.path, 'cache');
      expect(await storage().directorySizeBytes(root), 42);

      await storage().deleteDirectory(root);
      expect(Directory(root).existsSync(), isFalse);
    });

    test('tolerates a missing directory', () async {
      final missing = p.join(tempDir.path, 'nope');
      expect(await storage().directorySizeBytes(missing), 0);
      await storage().deleteDirectory(missing);
    });
  });

  group('SettingsService SD-card preference', () {
    test('defaults to false and round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();
      expect(settings.offlineMapStorageOnSdCard, isFalse);

      await settings.setOfflineMapStorageOnSdCard(true);
      expect(settings.offlineMapStorageOnSdCard, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(offlineMapStorageOnSdCardKey), isTrue);
    });
  });
}
