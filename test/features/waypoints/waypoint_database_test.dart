// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/waypoints/models/mesh_waypoint.dart';
import 'package:socialmesh/features/waypoints/services/waypoint_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late WaypointDatabase db;

  setUp(() async {
    db = WaypointDatabase(testDbPath: inMemoryDatabasePath);
    await db.init();
  });

  tearDown(() async {
    await db.close();
  });

  MeshWaypoint wp({
    int id = 1,
    int expire = 0,
    int lockedTo = 0,
    String name = 'wp',
    int icon = 0,
    int receivedMs = 1000,
  }) {
    return MeshWaypoint(
      id: id,
      latitude: 1.0,
      longitude: 2.0,
      expire: expire,
      lockedTo: lockedTo,
      name: name,
      icon: icon,
      sourceNodeNum: 0x10,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedMs),
    );
  }

  test('upsert inserts then replaces on same id', () async {
    await db.upsert(wp(id: 5, name: 'first'));
    await db.upsert(wp(id: 5, name: 'second'));

    final all = await db.getAll();
    expect(all.length, 1);
    expect(all.first.name, 'second');
  });

  test('getById returns the row or null', () async {
    await db.upsert(wp(id: 9));
    expect((await db.getById(9))?.id, 9);
    expect(await db.getById(404), isNull);
  });

  test('getAll orders by received time descending', () async {
    await db.upsert(wp(id: 1, receivedMs: 1000));
    await db.upsert(wp(id: 2, receivedMs: 3000));
    await db.upsert(wp(id: 3, receivedMs: 2000));

    final all = await db.getAll();
    expect(all.map((w) => w.id).toList(), [2, 3, 1]);
  });

  test('getAll excludes already-expired waypoints by default', () async {
    final pastSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100;
    final futureSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10000;
    await db.upsert(wp(id: 1, expire: pastSec));
    await db.upsert(wp(id: 2, expire: futureSec));
    await db.upsert(wp(id: 3, expire: 0));

    final visible = (await db.getAll()).map((w) => w.id).toSet();
    expect(visible, {2, 3});
    final all = (await db.getAll(
      includeExpired: true,
    )).map((w) => w.id).toSet();
    expect(all, {1, 2, 3});
  });

  test('deleteById removes a single row', () async {
    await db.upsert(wp(id: 1));
    await db.upsert(wp(id: 2));
    await db.deleteById(1);
    expect((await db.getAll()).map((w) => w.id).toList(), [2]);
  });

  test('cleanupExpired removes past real expiries only', () async {
    final pastSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100;
    final futureSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10000;
    await db.upsert(wp(id: 1, expire: pastSec)); // removed
    await db.upsert(wp(id: 2, expire: futureSec)); // kept
    await db.upsert(wp(id: 3, expire: 0)); // never expires, kept
    await db.upsert(wp(id: 4, expire: 1)); // delete sentinel, not a real expiry

    final removed = await db.cleanupExpired();
    expect(removed, 1);
    final remaining = (await db.getAll(
      includeExpired: true,
    )).map((w) => w.id).toSet();
    expect(remaining, {2, 3, 4});
  });
}
