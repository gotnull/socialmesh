// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/range_test/range_test_database.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RangeTestReading _reading(int sessionId, int packetId, DateTime at) =>
    RangeTestReading(
      sessionId: sessionId,
      receivedAt: at,
      senderNodeNum: 0x51,
      senderName: 'Home',
      packetId: packetId,
      sequence: packetId,
      payload: 'seq $packetId',
      rxSnr: -3.5,
      rxRssi: -98,
      viaMqtt: false,
      rxLatitude: -33.86,
      rxLongitude: 151.2,
      rxAltitude: 40,
      rxPositionSource: RangeTestPositionSource.radio,
      senderLatitude: -33.87,
      senderLongitude: 151.21,
      distanceMeters: 1400,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late RangeTestDatabase db;

  setUp(() async {
    db = RangeTestDatabase(testDbPath: inMemoryDatabasePath);
    await db.init();
  });

  tearDown(() => db.close());

  test('readings round-trip in the order received', () async {
    final session = await db.createSession(DateTime(2026, 11, 24, 9));
    final second = _reading(session.id, 2, DateTime(2026, 11, 24, 9, 2));
    final first = _reading(session.id, 1, DateTime(2026, 11, 24, 9, 1));
    expect(await db.insertReading(second), isTrue);
    expect(await db.insertReading(first), isTrue);

    final stored = await db.readings(session.id);
    expect(stored.map((r) => r.packetId), [1, 2]);
    expect(stored.first.toMap(), first.toMap());
  });

  test('the same packet is stored once per session', () async {
    final session = await db.createSession(DateTime(2026, 11, 24, 9));
    final r = _reading(session.id, 7, DateTime(2026, 11, 24, 9, 1));
    expect(await db.insertReading(r), isTrue);
    expect(await db.insertReading(r), isFalse);
    expect(await db.readings(session.id), hasLength(1));
  });

  test('sessions list newest first with their counts', () async {
    final older = await db.createSession(DateTime(2026, 11, 23, 9));
    final newer = await db.createSession(DateTime(2026, 11, 24, 9));
    await db.insertReading(_reading(older.id, 1, DateTime(2026, 11, 23, 9)));
    await db.insertReading(_reading(older.id, 2, DateTime(2026, 11, 23, 9)));

    final sessions = await db.sessions();
    expect(sessions.map((s) => s.id), [newer.id, older.id]);
    expect(sessions.map((s) => s.readingCount), [0, 2]);
  });

  test('an interrupted session ends at its last reading', () async {
    final start = DateTime(2026, 11, 24, 9);
    final last = DateTime(2026, 11, 24, 9, 40);
    final withReadings = await db.createSession(start);
    final empty = await db.createSession(start.add(const Duration(hours: 1)));
    await db.insertReading(_reading(withReadings.id, 1, last));

    await db.endOpenSessions();

    final sessions = {for (final s in await db.sessions()) s.id: s};
    expect(sessions[withReadings.id]!.endedAt, last);
    expect(sessions[empty.id]!.endedAt, empty.startedAt);
  });

  test('deleting a session removes its readings', () async {
    final keep = await db.createSession(DateTime(2026, 11, 23, 9));
    final drop = await db.createSession(DateTime(2026, 11, 24, 9));
    await db.insertReading(_reading(keep.id, 1, DateTime(2026, 11, 23, 9)));
    await db.insertReading(_reading(drop.id, 1, DateTime(2026, 11, 24, 9)));

    await db.deleteSession(drop.id);

    expect((await db.sessions()).map((s) => s.id), [keep.id]);
    expect(await db.readings(drop.id), isEmpty);
    expect(await db.readings(keep.id), hasLength(1));
  });
}
