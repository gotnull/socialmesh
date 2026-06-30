// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for position history deduplication and precision filtering.
//
// Verifies distance-based dedupe (~9 m threshold) and low-precision retention
// policy matching meshtastic-ios behaviour.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Haversine helper — mirrors the production _PositionFingerprint logic.
// ---------------------------------------------------------------------------

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Offset a coordinate by approximately [meters] due north.
/// 1 degree latitude ≈ 111,320 m.
double offsetLatByMeters(double lat, double meters) {
  return lat + (meters / 111320.0);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // -------------------------------------------------------------------------
  // Haversine sanity checks
  // -------------------------------------------------------------------------

  group('Haversine distance', () {
    test('identical points → 0 m', () {
      expect(haversineMeters(37.7749, -122.4194, 37.7749, -122.4194), 0.0);
    });

    test('known distance — roughly correct for short span', () {
      // ~5 m offset northward
      final lat2 = offsetLatByMeters(37.7749, 5.0);
      final d = haversineMeters(37.7749, -122.4194, lat2, -122.4194);
      expect(d, closeTo(5.0, 0.5));
    });

    test('offset of 8 m is under 9 m threshold', () {
      final lat2 = offsetLatByMeters(-33.8688, 8.0);
      final d = haversineMeters(-33.8688, 151.2093, lat2, 151.2093);
      expect(d, lessThan(9.0));
    });

    test('offset of 15 m exceeds 9 m threshold', () {
      final lat2 = offsetLatByMeters(-33.8688, 15.0);
      final d = haversineMeters(-33.8688, 151.2093, lat2, 151.2093);
      expect(d, greaterThan(9.0));
    });
  });

  // -------------------------------------------------------------------------
  // Database: clearPositionLogsForNode
  // -------------------------------------------------------------------------

  group('TelemetryDatabase — clearPositionLogsForNode', () {
    late TelemetryDatabase db;

    setUp(() async {
      db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await db.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('clears only the target node, preserves others', () async {
      await db.addPositionLog(
        PositionLog(nodeNum: 1, latitude: 10.0, longitude: 20.0),
      );
      await db.addPositionLog(
        PositionLog(nodeNum: 2, latitude: 30.0, longitude: 40.0),
      );
      await db.addPositionLog(
        PositionLog(nodeNum: 1, latitude: 11.0, longitude: 21.0),
      );

      await db.clearPositionLogsForNode(1);

      final node1 = await db.getPositionLogs(1);
      final node2 = await db.getPositionLogs(2);
      expect(node1, isEmpty);
      expect(node2.length, 1);
    });

    test('no-op on empty table', () async {
      await db.clearPositionLogsForNode(99);
      final logs = await db.getPositionLogs(99);
      expect(logs, isEmpty);
    });

    test('does not affect device metrics for same node', () async {
      await db.addPositionLog(
        PositionLog(nodeNum: 1, latitude: 10.0, longitude: 20.0),
      );
      await db.addDeviceMetrics(DeviceMetricsLog(nodeNum: 1, batteryLevel: 80));

      await db.clearPositionLogsForNode(1);

      final positions = await db.getPositionLogs(1);
      final metrics = await db.getDeviceMetrics(1);
      expect(positions, isEmpty);
      expect(metrics.length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Low-precision replace-and-store pattern
  // -------------------------------------------------------------------------

  group('Low-precision position — latest-only retention', () {
    late TelemetryDatabase db;

    setUp(() async {
      db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await db.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('replacing history keeps only the newest position', () async {
      // Simulate 3 low-precision updates: clear + add each time
      for (var i = 0; i < 3; i++) {
        await db.clearPositionLogsForNode(1);
        await db.addPositionLog(
          PositionLog(
            nodeNum: 1,
            latitude: 10.0 + i,
            longitude: 20.0 + i,
            precisionBits: 13,
          ),
        );
      }

      final logs = await db.getPositionLogs(1);
      expect(logs.length, 1);
      expect(logs.first.latitude, 12.0);
      expect(logs.first.longitude, 22.0);
      expect(logs.first.precisionBits, 13);
    });

    test('low-precision node does not affect high-precision node', () async {
      // High-precision node builds up trail
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          latitude: 10.0,
          longitude: 20.0,
          precisionBits: 32,
        ),
      );
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          latitude: 11.0,
          longitude: 21.0,
          precisionBits: 32,
        ),
      );

      // Low-precision node clears and replaces
      await db.clearPositionLogsForNode(2);
      await db.addPositionLog(
        PositionLog(
          nodeNum: 2,
          latitude: 30.0,
          longitude: 40.0,
          precisionBits: 14,
        ),
      );

      final node1 = await db.getPositionLogs(1);
      final node2 = await db.getPositionLogs(2);
      expect(node1.length, 2);
      expect(node2.length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Precision classification
  // -------------------------------------------------------------------------

  group('Precision classification', () {
    test('bits 32 is high precision', () {
      expect(_isHighPrecision(32), isTrue);
    });

    test('bits 0 is high precision (unset/default)', () {
      expect(_isHighPrecision(0), isTrue);
    });

    test('null bits is high precision (absent field)', () {
      expect(_isHighPrecision(null), isTrue);
    });

    test('bits 13 is low precision', () {
      expect(_isHighPrecision(13), isFalse);
    });

    test('bits 14 is low precision', () {
      expect(_isHighPrecision(14), isFalse);
    });

    test('bits 12 is low precision', () {
      expect(_isHighPrecision(12), isFalse);
    });

    test('bits 15 is low precision', () {
      expect(_isHighPrecision(15), isFalse);
    });

    test('bits 1 is low precision', () {
      expect(_isHighPrecision(1), isFalse);
    });

    test('bits 31 is low precision', () {
      expect(_isHighPrecision(31), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // PositionLog model — precisionBits round-trip
  // -------------------------------------------------------------------------

  group('PositionLog — precisionBits serialisation', () {
    test('precisionBits round-trips through JSON', () {
      final log = PositionLog(
        nodeNum: 42,
        latitude: 37.7749,
        longitude: -122.4194,
        precisionBits: 14,
      );
      final json = log.toJson();
      final restored = PositionLog.fromJson(json);
      expect(restored.precisionBits, 14);
    });

    test('null precisionBits round-trips through JSON', () {
      final log = PositionLog(
        nodeNum: 42,
        latitude: 37.7749,
        longitude: -122.4194,
      );
      final json = log.toJson();
      final restored = PositionLog.fromJson(json);
      expect(restored.precisionBits, isNull);
    });

    test('precisionBits persists through database', () async {
      final db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await db.init();

      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          latitude: 10.0,
          longitude: 20.0,
          precisionBits: 13,
        ),
      );

      final logs = await db.getPositionLogs(1);
      expect(logs.first.precisionBits, 13);

      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // Durable dedupe seeding — cold cache after reconnect must reuse the last
  // stored position so an unchanged fix is not re-logged as a new row.
  // -------------------------------------------------------------------------

  group('Dedupe fingerprint seeded from stored position', () {
    late TelemetryDatabase db;

    setUp(() async {
      db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await db.init();
    });

    tearDown(() async {
      await db.close();
    });

    // Mirrors TelemetryLoggerNotifier._seedPositionFingerprint: seed from the
    // newest stored fix (getPositionLogs returns timestamp ASC, so .last).
    Future<PositionLog?> seedLatest(int nodeNum) async {
      final stored = await db.getPositionLogs(nodeNum);
      if (stored.isEmpty) return null;
      return stored.last;
    }

    test('unchanged position after a cold cache is a near-duplicate', () async {
      const lat = 52.769553;
      const lng = -2.156431;
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          timestamp: DateTime.utc(2024, 6, 1, 8),
          latitude: lat,
          longitude: lng,
          altitude: 163,
          precisionBits: 32,
        ),
      );

      final seed = await seedLatest(1);
      expect(seed, isNotNull);
      // Identical coordinates -> 0 m -> under the 9 m dedupe threshold.
      final d = haversineMeters(seed!.latitude, seed.longitude, lat, lng);
      expect(d, lessThan(9.0));
    });

    test('moved position after a cold cache is not a near-duplicate', () async {
      const lat = 52.769553;
      const lng = -2.156431;
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          timestamp: DateTime.utc(2024, 6, 1, 8),
          latitude: lat,
          longitude: lng,
          precisionBits: 32,
        ),
      );

      final seed = await seedLatest(1);
      final movedLat = offsetLatByMeters(lat, 15.0); // 15 m north
      final d = haversineMeters(seed!.latitude, seed.longitude, movedLat, lng);
      expect(d, greaterThan(9.0));
    });

    test('seed picks the newest fix when several are stored', () async {
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          timestamp: DateTime.utc(2024, 6, 1, 8),
          latitude: 10.0,
          longitude: 20.0,
          precisionBits: 32,
        ),
      );
      await db.addPositionLog(
        PositionLog(
          nodeNum: 1,
          timestamp: DateTime.utc(2024, 6, 2, 8),
          latitude: 11.0,
          longitude: 21.0,
          precisionBits: 32,
        ),
      );

      final seed = await seedLatest(1);
      expect(seed!.latitude, 11.0);
      expect(seed.longitude, 21.0);
    });

    test(
      'no stored history yields a null seed (first sighting logs)',
      () async {
        final seed = await seedLatest(99);
        expect(seed, isNull);
      },
    );
  });
}

/// Mirror of the production precision classification logic.
bool _isHighPrecision(int? bits) => bits == null || bits == 0 || bits == 32;
