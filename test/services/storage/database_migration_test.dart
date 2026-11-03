// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/storage/database_migration.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// SQLCipher itself is a native lib not present in the host `flutter test`
// runner, so the encrypted round-trip is verified on-device. These tests cover
// the platform-independent, data-safety-critical logic: detecting an
// unencrypted file and recovering an interrupted file swap without data loss.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('migr_test');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('isPlaintextSqlite', () {
    test('returns true for a real unencrypted SQLite file', () async {
      final dbPath = '${tmpDir.path}/plain.db';
      final db = await databaseFactory.openDatabase(dbPath);
      await db.execute('CREATE TABLE t (id INTEGER)');
      await db.insert('t', {'id': 1});
      await db.close();

      expect(await isPlaintextSqlite(dbPath), isTrue);
    });

    test('returns false for a non-existent file', () async {
      expect(await isPlaintextSqlite('${tmpDir.path}/missing.db'), isFalse);
    });

    test('returns false for a file without the SQLite magic header', () async {
      // Stand-in for an already-encrypted file: bytes that do not begin with
      // the SQLite magic header.
      final f = File('${tmpDir.path}/encrypted.db');
      await f.writeAsBytes(List<int>.generate(64, (i) => (i * 7 + 3) % 256));

      expect(await isPlaintextSqlite(f.path), isFalse);
    });
  });

  group('recoverInterruptedMigration', () {
    test(
      'promotes temp file when the original is missing (post-delete swap)',
      () async {
        final dbPath = '${tmpDir.path}/messages.db';
        final tmpPath = '$dbPath.enc.tmp';
        final payload = <int>[9, 8, 7, 6, 5];
        await File(tmpPath).writeAsBytes(payload);
        // Original intentionally absent.

        await recoverInterruptedMigration(dbPath);

        expect(await File(tmpPath).exists(), isFalse);
        expect(await File(dbPath).exists(), isTrue);
        expect(await File(dbPath).readAsBytes(), payload);
      },
    );

    test(
      'discards temp file when the original is present (incomplete export)',
      () async {
        final dbPath = '${tmpDir.path}/messages.db';
        final tmpPath = '$dbPath.enc.tmp';
        final original = <int>[1, 2, 3];
        await File(dbPath).writeAsBytes(original);
        await File(tmpPath).writeAsBytes(<int>[4, 5, 6]);

        await recoverInterruptedMigration(dbPath);

        expect(await File(tmpPath).exists(), isFalse);
        expect(await File(dbPath).readAsBytes(), original);
      },
    );

    test('is a no-op when no temp file exists', () async {
      final dbPath = '${tmpDir.path}/messages.db';
      await File(dbPath).writeAsBytes(<int>[1, 2, 3]);

      await recoverInterruptedMigration(dbPath);

      expect(await File(dbPath).readAsBytes(), <int>[1, 2, 3]);
    });
  });

  group('openAfterSettingAsideUnreadable', () {
    // Stand-in for a file encrypted under a key that no longer exists.
    final unreadable = List<int>.generate(4096, (i) => (i * 13 + 5) % 256);

    // Fails the first [failures] opens, then opens the path for real.
    Future<Database> Function() openFailing(String path, int failures) {
      var calls = 0;
      return () async {
        calls++;
        if (calls <= failures) {
          throw StateError('open_failed $path');
        }
        return databaseFactory.openDatabase(path);
      };
    }

    Future<List<String>> asideFiles() async => tmpDir
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((name) => name.contains('.unreadable-'))
        .toList();

    test('a retry that opens leaves the file where it is', () async {
      final dbPath = '${tmpDir.path}/messages.db';
      final seed = await databaseFactory.openDatabase(dbPath);
      await seed.execute('CREATE TABLE t (id INTEGER)');
      await seed.close();
      var setAside = false;

      final db = await openAfterSettingAsideUnreadable(
        path: dbPath,
        open: openFailing(dbPath, 0),
        error: StateError('open_failed'),
        stackTrace: StackTrace.current,
        onSetAside: () => setAside = true,
        retryDelay: Duration.zero,
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 't'",
      );
      await db.close();

      expect(tables, hasLength(1));
      expect(await asideFiles(), isEmpty);
      expect(setAside, isFalse);
    });

    test('an unreadable file and its sidecars are kept aside and a fresh '
        'database opens in their place', () async {
      final dbPath = '${tmpDir.path}/messages.db';
      await File(dbPath).writeAsBytes(unreadable);
      await File('$dbPath-wal').writeAsBytes(<int>[7, 7, 7]);
      var setAside = false;

      final db = await openAfterSettingAsideUnreadable(
        path: dbPath,
        open: openFailing(dbPath, 1),
        error: StateError('open_failed'),
        stackTrace: StackTrace.current,
        onSetAside: () => setAside = true,
        retryDelay: Duration.zero,
      );
      await db.execute('CREATE TABLE fresh (id INTEGER)');
      await db.close();

      final aside = await asideFiles();
      expect(aside, hasLength(2));
      final main = aside.firstWhere((n) => !n.endsWith('-wal'));
      expect(await File('${tmpDir.path}/$main').readAsBytes(), unreadable);
      expect(aside, contains('$main-wal'));
      expect(await isPlaintextSqlite(dbPath), isTrue);
      expect(setAside, isTrue);
    });

    test(
      'a fresh open that also fails puts the original back and rethrows',
      () async {
        final dbPath = '${tmpDir.path}/messages.db';
        await File(dbPath).writeAsBytes(unreadable);
        final original = StateError('original open_failed');
        var setAside = false;
        var calls = 0;

        await expectLater(
          openAfterSettingAsideUnreadable(
            path: dbPath,
            open: () async {
              calls++;
              // The fresh open (after the retry) leaves a file behind before
              // failing, as a half-created database would.
              if (calls > 1) await File(dbPath).writeAsBytes(<int>[0]);
              throw StateError('open_failed $calls');
            },
            error: original,
            stackTrace: StackTrace.current,
            onSetAside: () => setAside = true,
            retryDelay: Duration.zero,
          ),
          throwsA(same(original)),
        );

        expect(await File(dbPath).readAsBytes(), unreadable);
        expect(await asideFiles(), isEmpty);
        expect(setAside, isFalse);
      },
    );
  });
}
