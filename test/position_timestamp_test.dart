// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for position history timestamp correctness.
//
// Verifies that the timestamp selection logic for position logs matches
// the standard Meshtastic timestamp fallback order:
//   1. position.timestamp (GPS solution time)
//   2. position.time (phone-provided time)
//   3. DateTime.now() (local processing time — final fallback)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Replicate the exact production logic from ProtocolService for unit testing.
// This must be kept in sync with ProtocolService._positionSourceTimestamp().
// ---------------------------------------------------------------------------

/// Minimum plausible Unix epoch (2020-01-01 UTC).
const int _minPlausibleEpoch = 1577836800;

/// Maximum clock drift tolerance: 1 day into the future.
const int _maxFutureSlack = 86400;

/// Select the best available timestamp from a Position protobuf.
///
/// Follows the standard Meshtastic timestamp fallback order:
///   1. position.timestamp (GPS solution time, field 7)
///   2. position.time (phone-provided time, field 4)
///   3. DateTime.now() (local fallback)
DateTime positionSourceTimestamp(pb.Position position) {
  final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  if (position.hasTimestamp() && position.timestamp > 0) {
    final ts = position.timestamp;
    if (ts >= _minPlausibleEpoch && ts <= nowEpoch + _maxFutureSlack) {
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
  }

  if (position.hasTime() && position.time > 0) {
    final t = position.time;
    if (t >= _minPlausibleEpoch && t <= nowEpoch + _maxFutureSlack) {
      return DateTime.fromMillisecondsSinceEpoch(t * 1000);
    }
  }

  return DateTime.now();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // -------------------------------------------------------------------------
  // Timestamp selection logic
  // -------------------------------------------------------------------------

  group('positionSourceTimestamp — timestamp selection', () {
    test('uses position.timestamp when valid', () {
      // 2024-06-15 12:00:00 UTC
      const gpsEpoch = 1718452800;
      final position = pb.Position(timestamp: gpsEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(gpsEpoch * 1000));
    });

    test('falls back to position.time when timestamp is absent', () {
      const phoneEpoch = 1718452800;
      final position = pb.Position(time: phoneEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(phoneEpoch * 1000));
    });

    test('prefers timestamp over time when both present', () {
      const gpsEpoch = 1718452800;
      const phoneEpoch = 1718400000; // earlier
      final position = pb.Position(timestamp: gpsEpoch, time: phoneEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(gpsEpoch * 1000));
    });

    test('falls back to time when timestamp is zero', () {
      const phoneEpoch = 1718452800;
      final position = pb.Position(timestamp: 0, time: phoneEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(phoneEpoch * 1000));
    });

    test('falls back to now when both fields are zero', () {
      final position = pb.Position(timestamp: 0, time: 0);
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      final result = positionSourceTimestamp(position);
      expect(result.isAfter(before), isTrue);
    });

    test('falls back to now when both fields are absent', () {
      final position = pb.Position();
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      final result = positionSourceTimestamp(position);
      expect(result.isAfter(before), isTrue);
    });

    test('rejects timestamp before 2020 — falls back to time', () {
      const oldEpoch = 100; // year 1970 (device uptime)
      const phoneEpoch = 1718452800;
      final position = pb.Position(timestamp: oldEpoch, time: phoneEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(phoneEpoch * 1000));
    });

    test('rejects both before 2020 — falls back to now', () {
      final position = pb.Position(timestamp: 100, time: 200);
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      final result = positionSourceTimestamp(position);
      expect(result.isAfter(before), isTrue);
    });

    test('rejects future timestamp beyond tolerance', () {
      final farFuture =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 172800; // +2d
      const phoneEpoch = 1718452800;
      final position = pb.Position(timestamp: farFuture, time: phoneEpoch);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(phoneEpoch * 1000));
    });

    test('rejects both future beyond tolerance — falls back to now', () {
      final farFuture =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 172800;
      final position = pb.Position(timestamp: farFuture, time: farFuture);
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      final result = positionSourceTimestamp(position);
      expect(result.isAfter(before), isTrue);
    });

    test('accepts timestamp within 1-day future tolerance', () {
      final nearFuture =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // +1h
      final position = pb.Position(timestamp: nearFuture);

      final result = positionSourceTimestamp(position);
      expect(result, DateTime.fromMillisecondsSinceEpoch(nearFuture * 1000));
    });
  });

  // -------------------------------------------------------------------------
  // PositionLog model timestamp propagation
  // -------------------------------------------------------------------------

  group('PositionLog — explicit timestamp', () {
    test('constructor accepts explicit timestamp', () {
      final ts = DateTime(2024, 6, 15, 12, 0);
      final log = PositionLog(
        nodeNum: 100,
        timestamp: ts,
        latitude: 37.7749,
        longitude: -122.4194,
      );
      expect(log.timestamp, ts);
    });

    test('constructor defaults to now when timestamp is null', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final log = PositionLog(
        nodeNum: 100,
        latitude: 37.7749,
        longitude: -122.4194,
      );
      expect(log.timestamp.isAfter(before), isTrue);
    });

    test('toJson serialises explicit timestamp as milliseconds', () {
      final ts = DateTime.utc(2024, 6, 15, 12, 0);
      final log = PositionLog(
        nodeNum: 100,
        timestamp: ts,
        latitude: 37.7749,
        longitude: -122.4194,
      );
      final json = log.toJson();
      expect(json['timestamp'], ts.millisecondsSinceEpoch);
    });

    test('fromJson restores explicit timestamp', () {
      final ts = DateTime.utc(2024, 6, 15, 12, 0);
      final json = {
        'id': 'test-id',
        'nodeNum': 100,
        'timestamp': ts.millisecondsSinceEpoch,
        'latitude': 37.7749,
        'longitude': -122.4194,
      };
      final log = PositionLog.fromJson(json);
      expect(log.timestamp.millisecondsSinceEpoch, ts.millisecondsSinceEpoch);
    });
  });

  // -------------------------------------------------------------------------
  // Database round-trip with explicit timestamp
  // -------------------------------------------------------------------------

  group('TelemetryDatabase — PositionLog timestamp propagation', () {
    late TelemetryDatabase db;

    setUp(() async {
      db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await db.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('persisted PositionLog preserves explicit timestamp', () async {
      final ts = DateTime.utc(2024, 6, 15, 12, 0);
      await db.addPositionLog(
        PositionLog(
          nodeNum: 42,
          timestamp: ts,
          latitude: 37.7749,
          longitude: -122.4194,
          altitude: 15,
        ),
      );

      final logs = await db.getPositionLogs(42);
      expect(logs.length, 1);
      expect(
        logs.first.timestamp.millisecondsSinceEpoch,
        ts.millisecondsSinceEpoch,
      );
    });

    test('getAllPositionLogs preserves explicit timestamps', () async {
      final ts1 = DateTime.utc(2024, 1, 1, 10, 0);
      final ts2 = DateTime.utc(2024, 6, 15, 12, 0);
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          timestamp: ts1,
          latitude: 10.0,
          longitude: 20.0,
        ),
      );
      await db.addPositionLog(
        PositionLog(
          nodeNum: 2,
          timestamp: ts2,
          latitude: 30.0,
          longitude: 40.0,
        ),
      );

      final all = await db.getAllPositionLogs();
      expect(all.length, 2);
      // getAllPositionLogs returns DESC order (newest first)
      expect(
        all[0].timestamp.millisecondsSinceEpoch,
        ts2.millisecondsSinceEpoch,
      );
      expect(
        all[1].timestamp.millisecondsSinceEpoch,
        ts1.millisecondsSinceEpoch,
      );
    });

    test('CSV export uses persisted source timestamp', () async {
      final ts = DateTime.utc(2024, 6, 15, 12, 0);
      await db.addPositionLog(
        PositionLog(
          nodeNum: 42,
          timestamp: ts,
          latitude: 37.7749,
          longitude: -122.4194,
          altitude: 15,
          satsInView: 10,
          speed: 5,
          heading: 180,
        ),
      );

      final csv = await db.exportPositionLogsCsv(42);
      // CSV export normalises timestamps to UTC ISO-8601 for unambiguous,
      // timezone-independent output — verify the underlying epoch round-trips
      // and the CSV carries the UTC-formatted representation.
      final logs = await db.getPositionLogs(42);
      expect(
        logs.first.timestamp.millisecondsSinceEpoch,
        ts.millisecondsSinceEpoch,
      );
      expect(csv, contains(logs.first.timestamp.toUtc().toIso8601String()));
    });
  });
}
