// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';

RangeTestReading reading({
  int sender = 0x51,
  int packetId = 1,
  int? seq,
  double? snr,
  int? rssi,
  double? distance,
  double? rxLat,
  double? rxLon,
  RangeTestPositionSource? source,
}) => RangeTestReading(
  sessionId: 1,
  receivedAt: DateTime.utc(2026, 11, 24, 9, 0, packetId),
  senderNodeNum: sender,
  senderName: 'Home',
  packetId: packetId,
  sequence: seq,
  payload: seq == null ? 'hello' : 'seq $seq',
  rxSnr: snr,
  rxRssi: rssi,
  viaMqtt: false,
  rxLatitude: rxLat,
  rxLongitude: rxLon,
  rxAltitude: null,
  rxPositionSource: source,
  senderLatitude: null,
  senderLongitude: null,
  distanceMeters: distance,
);

void main() {
  group('RangeTestSummary', () {
    test('counts packets sent from the sequence numbers', () {
      final summary = RangeTestSummary.of([
        reading(packetId: 1, seq: 3),
        reading(packetId: 2, seq: 4),
        reading(packetId: 3, seq: 8),
      ]);
      expect(summary.sequencedCount, 3);
      expect(summary.expectedCount, 6);
      expect(summary.missedBefore, [0, 0, 3]);
    });

    test('a sender reboot starts a new run instead of a negative gap', () {
      final summary = RangeTestSummary.of([
        reading(packetId: 1, seq: 10),
        reading(packetId: 2, seq: 12),
        reading(packetId: 3, seq: 1),
        reading(packetId: 4, seq: 2),
      ]);
      // Run one expects 10..12, run two 1..2.
      expect(summary.expectedCount, 5);
      expect(summary.missedBefore, [0, 1, 0, 0]);
    });

    test('keeps each sender separate', () {
      final summary = RangeTestSummary.of([
        reading(sender: 1, packetId: 1, seq: 1),
        reading(sender: 2, packetId: 2, seq: 50),
        reading(sender: 1, packetId: 3, seq: 3),
        reading(sender: 2, packetId: 4, seq: 51),
      ]);
      expect(summary.expectedCount, 5);
      expect(summary.missedBefore, [0, 0, 1, 0]);
    });

    test('averages and maximum skip readings without the value', () {
      final summary = RangeTestSummary.of([
        reading(packetId: 1, snr: -4, rssi: -100, distance: 1200),
        reading(packetId: 2),
        reading(packetId: 3, snr: 2, rssi: -90, distance: 800),
      ]);
      expect(summary.averageSnr, -1);
      expect(summary.averageRssi, -95);
      expect(summary.maxDistanceMeters, 1200);
    });

    test('reports nothing it cannot know', () {
      final summary = RangeTestSummary.of([reading(packetId: 1)]);
      expect(summary.expectedCount, isNull);
      expect(summary.averageSnr, isNull);
      expect(summary.averageRssi, isNull);
      expect(summary.maxDistanceMeters, isNull);
      expect(summary.missedBefore, [0]);
    });
  });

  test('a reading survives a map round trip', () {
    final original = reading(
      seq: 5,
      snr: -6.5,
      rssi: -110,
      distance: 432.1,
      rxLat: -33.86,
      rxLon: 151.2,
      source: RangeTestPositionSource.phone,
    );
    final copy = RangeTestReading.fromMap(original.toMap());
    expect(copy.toMap(), original.toMap());
    expect(copy.rxPositionSource, RangeTestPositionSource.phone);
    expect(copy.hasRxPosition, isTrue);
  });
}
