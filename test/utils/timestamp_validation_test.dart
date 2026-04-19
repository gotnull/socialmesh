// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/timestamp_validation.dart';

void main() {
  // Fixed reference time for deterministic tests.
  final refTime = DateTime.utc(2025, 6, 15, 12, 0, 0);

  group('TimestampValidation.isPlausible', () {
    test('null is not plausible', () {
      expect(
        TimestampValidation.isPlausible(null, referenceTime: refTime),
        isFalse,
      );
    });

    test('epoch zero is not plausible', () {
      final epoch0 = DateTime.fromMillisecondsSinceEpoch(0);
      expect(
        TimestampValidation.isPlausible(epoch0, referenceTime: refTime),
        isFalse,
      );
    });

    test('negative epoch is not plausible', () {
      final negative = DateTime.fromMillisecondsSinceEpoch(-1000);
      expect(
        TimestampValidation.isPlausible(negative, referenceTime: refTime),
        isFalse,
      );
    });

    test('pre-2020 timestamp is not plausible', () {
      final old = DateTime.utc(2019, 12, 31, 23, 59, 59);
      expect(
        TimestampValidation.isPlausible(old, referenceTime: refTime),
        isFalse,
      );
    });

    test('exactly 2020-01-01 00:00:00 UTC is plausible (lower boundary)', () {
      final boundary = DateTime.fromMillisecondsSinceEpoch(
        TimestampValidation.minPlausibleEpochSeconds * 1000,
      );
      expect(
        TimestampValidation.isPlausible(boundary, referenceTime: refTime),
        isTrue,
      );
    });

    test('valid historical timestamp is plausible', () {
      final valid = DateTime.utc(2024, 3, 15, 10, 30, 0);
      expect(
        TimestampValidation.isPlausible(valid, referenceTime: refTime),
        isTrue,
      );
    });

    test('timestamp at reference time is plausible', () {
      expect(
        TimestampValidation.isPlausible(refTime, referenceTime: refTime),
        isTrue,
      );
    });

    test('timestamp slightly in the future within skew is plausible', () {
      final slightlyAhead = refTime.add(const Duration(hours: 12));
      expect(
        TimestampValidation.isPlausible(slightlyAhead, referenceTime: refTime),
        isTrue,
      );
    });

    test('timestamp exactly at future boundary is plausible', () {
      final atBoundary = refTime.add(
        const Duration(seconds: TimestampValidation.maxFutureSkewSeconds),
      );
      expect(
        TimestampValidation.isPlausible(atBoundary, referenceTime: refTime),
        isTrue,
      );
    });

    test('timestamp beyond future skew is not plausible', () {
      final tooFar = refTime.add(
        const Duration(seconds: TimestampValidation.maxFutureSkewSeconds + 1),
      );
      expect(
        TimestampValidation.isPlausible(tooFar, referenceTime: refTime),
        isFalse,
      );
    });

    test('timestamp 1 year in the future is not plausible', () {
      final farFuture = refTime.add(const Duration(days: 365));
      expect(
        TimestampValidation.isPlausible(farFuture, referenceTime: refTime),
        isFalse,
      );
    });

    test('uses DateTime.now() when no referenceTime provided', () {
      // A recent timestamp should be plausible against real clock.
      final recent = DateTime.now().subtract(const Duration(hours: 1));
      expect(TimestampValidation.isPlausible(recent), isTrue);
    });
  });

  group('TimestampValidation.validated', () {
    test('returns DateTime for plausible value', () {
      final valid = DateTime.utc(2024, 6, 1, 8, 0, 0);
      expect(
        TimestampValidation.validated(valid, referenceTime: refTime),
        valid,
      );
    });

    test('returns null for null input', () {
      expect(
        TimestampValidation.validated(null, referenceTime: refTime),
        isNull,
      );
    });

    test('returns null for epoch zero', () {
      final epoch0 = DateTime.fromMillisecondsSinceEpoch(0);
      expect(
        TimestampValidation.validated(epoch0, referenceTime: refTime),
        isNull,
      );
    });

    test('returns null for absurd future timestamp', () {
      final farFuture = refTime.add(const Duration(days: 365));
      expect(
        TimestampValidation.validated(farFuture, referenceTime: refTime),
        isNull,
      );
    });

    test('returns DateTime for timestamp slightly ahead within skew', () {
      final slightlyAhead = refTime.add(const Duration(hours: 6));
      expect(
        TimestampValidation.validated(slightlyAhead, referenceTime: refTime),
        slightlyAhead,
      );
    });
  });

  group('TimestampValidation.isPlausibleEpochSeconds', () {
    test('zero is not plausible', () {
      expect(
        TimestampValidation.isPlausibleEpochSeconds(0, referenceTime: refTime),
        isFalse,
      );
    });

    test('negative is not plausible', () {
      expect(
        TimestampValidation.isPlausibleEpochSeconds(
          -100,
          referenceTime: refTime,
        ),
        isFalse,
      );
    });

    test('pre-2020 epoch seconds is not plausible', () {
      expect(
        TimestampValidation.isPlausibleEpochSeconds(
          TimestampValidation.minPlausibleEpochSeconds - 1,
          referenceTime: refTime,
        ),
        isFalse,
      );
    });

    test('valid epoch seconds is plausible', () {
      // 2024-01-15 epoch seconds
      const validEpoch = 1705276800;
      expect(
        TimestampValidation.isPlausibleEpochSeconds(
          validEpoch,
          referenceTime: refTime,
        ),
        isTrue,
      );
    });

    test('epoch seconds beyond future skew is not plausible', () {
      final futureEpoch =
          refTime.millisecondsSinceEpoch ~/ 1000 +
          TimestampValidation.maxFutureSkewSeconds +
          1;
      expect(
        TimestampValidation.isPlausibleEpochSeconds(
          futureEpoch,
          referenceTime: refTime,
        ),
        isFalse,
      );
    });
  });

  group('No blanket correction', () {
    test('validated preserves exact DateTime value for plausible input', () {
      final original = DateTime.utc(2025, 3, 10, 14, 30, 45, 123);
      final result = TimestampValidation.validated(
        original,
        referenceTime: refTime,
      );
      expect(result, same(original));
    });

    test('constants match protocol service values', () {
      // Mirrors ProtocolService._minPlausibleEpoch
      expect(TimestampValidation.minPlausibleEpochSeconds, 1577836800);
      // Mirrors ProtocolService._maxFutureSlack
      expect(TimestampValidation.maxFutureSkewSeconds, 86400);
    });
  });
}
