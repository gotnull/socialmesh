// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for NodeSummaryEngine — verifies correctness and
// determinism of computed summary statistics.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/node_summary_engine.dart';

// =============================================================================
// Test helpers
// =============================================================================

/// Fixed reference time for deterministic tests.
final _now = DateTime(2026, 3, 15, 14, 0); // A Sunday

/// Creates encounter records at the given DateTimes.
List<EncounterRecord> _encounters(List<DateTime> timestamps) {
  return timestamps
      .map((t) => EncounterRecord(timestamp: t, snr: 5, rssi: -90))
      .toList();
}

/// Builds a NodeDexEntry with the given encounters.
NodeDexEntry _entry({
  List<EncounterRecord> encounters = const [],
  int? encounterCount,
}) {
  final sorted = [...encounters]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return NodeDexEntry(
    nodeNum: 42,
    firstSeen: sorted.isNotEmpty ? sorted.first.timestamp : _now,
    lastSeen: sorted.isNotEmpty ? sorted.last.timestamp : _now,
    encounterCount: encounterCount ?? encounters.length,
    encounters: encounters,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('NodeSummaryEngine', () {
    // -----------------------------------------------------------------------
    // Empty / sparse data
    // -----------------------------------------------------------------------

    group('sparse data', () {
      test('empty encounters returns graceful state', () {
        withClock(Clock.fixed(_now), () {
          final summary = NodeSummaryEngine.compute(_entry());

          expect(summary.hasEnoughData, isFalse);
          expect(summary.totalEncounters, 0);
          expect(summary.currentStreak, 0);
          expect(summary.summaryText, 'Keep observing to build a profile');
          expect(summary.busiestDayOfWeek, isNull);
        });
      });

      test('single encounter returns graceful state', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([_now.subtract(const Duration(hours: 1))]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));

          expect(summary.hasEnoughData, isFalse);
          expect(summary.totalEncounters, 1);
          expect(summary.currentStreak, 1);
          expect(summary.summaryText, 'Keep observing to build a profile');
        });
      });

      test('two encounters returns graceful state', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            _now.subtract(const Duration(hours: 2)),
            _now.subtract(const Duration(hours: 1)),
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));

          expect(summary.hasEnoughData, isFalse);
          expect(summary.totalEncounters, 2);
          expect(summary.summaryText, 'Keep observing to build a profile');
        });
      });
    });

    // -----------------------------------------------------------------------
    // Time-of-day distribution
    // -----------------------------------------------------------------------

    group('time distribution', () {
      test('dawn bucket covers 5-10', () {
        expect(TimeOfDayBucket.fromHour(5), TimeOfDayBucket.dawn);
        expect(TimeOfDayBucket.fromHour(10), TimeOfDayBucket.dawn);
      });

      test('midday bucket covers 11-16', () {
        expect(TimeOfDayBucket.fromHour(11), TimeOfDayBucket.midday);
        expect(TimeOfDayBucket.fromHour(16), TimeOfDayBucket.midday);
      });

      test('evening bucket covers 17-22', () {
        expect(TimeOfDayBucket.fromHour(17), TimeOfDayBucket.evening);
        expect(TimeOfDayBucket.fromHour(22), TimeOfDayBucket.evening);
      });

      test('night bucket covers 23-4', () {
        expect(TimeOfDayBucket.fromHour(23), TimeOfDayBucket.night);
        expect(TimeOfDayBucket.fromHour(0), TimeOfDayBucket.night);
        expect(TimeOfDayBucket.fromHour(4), TimeOfDayBucket.night);
      });

      test('correct distribution with mixed times', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 7, 0), // dawn
            DateTime(2026, 3, 14, 8, 0), // dawn
            DateTime(2026, 3, 13, 14, 0), // midday
            DateTime(2026, 3, 12, 20, 0), // evening
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));

          expect(summary.timeDistribution[TimeOfDayBucket.dawn], 2);
          expect(summary.timeDistribution[TimeOfDayBucket.midday], 1);
          expect(summary.timeDistribution[TimeOfDayBucket.evening], 1);
          expect(summary.timeDistribution[TimeOfDayBucket.night], 0);
        });
      });

      test('dominant bucket is correctly identified', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 7, 0), // dawn
            DateTime(2026, 3, 14, 8, 0), // dawn
            DateTime(2026, 3, 13, 9, 0), // dawn
            DateTime(2026, 3, 12, 20, 0), // evening
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.dominantBucket, TimeOfDayBucket.dawn);
        });
      });
    });

    // -----------------------------------------------------------------------
    // Activity streak
    // -----------------------------------------------------------------------

    group('streak', () {
      test('consecutive days ending today', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // today
            DateTime(2026, 3, 14, 10, 0), // yesterday
            DateTime(2026, 3, 13, 10, 0), // 2 days ago
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.currentStreak, 3);
        });
      });

      test('consecutive days ending yesterday', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 14, 10, 0), // yesterday
            DateTime(2026, 3, 13, 10, 0), // 2 days ago
            DateTime(2026, 3, 12, 10, 0), // 3 days ago
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.currentStreak, 3);
        });
      });

      test('gap breaks streak', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // today
            DateTime(2026, 3, 14, 10, 0), // yesterday
            // gap on March 13
            DateTime(2026, 3, 12, 10, 0), // 3 days ago
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.currentStreak, 2);
        });
      });

      test('no recent encounters means zero streak', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 10, 10, 0), // 5 days ago
            DateTime(2026, 3, 9, 10, 0), // 6 days ago
            DateTime(2026, 3, 8, 10, 0), // 7 days ago
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.currentStreak, 0);
        });
      });

      test('multiple encounters same day count as one', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 8, 0), // today morning
            DateTime(2026, 3, 15, 12, 0), // today noon
            DateTime(2026, 3, 15, 18, 0), // today evening
            DateTime(2026, 3, 14, 10, 0), // yesterday
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.currentStreak, 2);
        });
      });
    });

    // -----------------------------------------------------------------------
    // Busiest day
    // -----------------------------------------------------------------------

    group('busiest day', () {
      test('identifies the day with most encounters', () {
        withClock(Clock.fixed(_now), () {
          // 2026-03-15 is Sunday (weekday 7)
          // 2026-03-14 is Saturday (weekday 6)
          // 2026-03-13 is Friday (weekday 5)
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // Sunday
            DateTime(2026, 3, 14, 10, 0), // Saturday
            DateTime(2026, 3, 14, 15, 0), // Saturday
            DateTime(2026, 3, 13, 10, 0), // Friday
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          // Saturday has 2 encounters, most
          expect(summary.busiestDayOfWeek, DateTime.saturday);
          expect(summary.busiestDayCount, 2);
        });
      });

      test('all same day returns that day', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 8, 0), // Sunday
            DateTime(2026, 3, 15, 12, 0), // Sunday
            DateTime(2026, 3, 15, 18, 0), // Sunday
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.busiestDayOfWeek, DateTime.sunday);
          expect(summary.busiestDayCount, 3);
        });
      });
    });

    // -----------------------------------------------------------------------
    // Active days in last 14
    // -----------------------------------------------------------------------

    group('active days', () {
      test('counts unique days within 14-day window', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // today
            DateTime(2026, 3, 14, 10, 0), // yesterday
            DateTime(2026, 3, 10, 10, 0), // 5 days ago
            DateTime(2026, 3, 2, 10, 0), // 13 days ago (within 14-day window)
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.activeDaysLast14, 4);
        });
      });

      test('encounters outside 14-day window excluded', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // today
            DateTime(2026, 2, 20, 10, 0), // 23 days ago
            DateTime(2026, 2, 15, 10, 0), // 28 days ago
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.activeDaysLast14, 1);
        });
      });

      test('multiple encounters same day count as one', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 8, 0),
            DateTime(2026, 3, 15, 12, 0),
            DateTime(2026, 3, 15, 18, 0),
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.activeDaysLast14, 1);
        });
      });
    });

    // -----------------------------------------------------------------------
    // Determinism
    // -----------------------------------------------------------------------

    group('determinism', () {
      test('same entry always produces identical summary', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 7, 0),
            DateTime(2026, 3, 14, 14, 0),
            DateTime(2026, 3, 13, 20, 0),
            DateTime(2026, 3, 12, 3, 0),
            DateTime(2026, 3, 11, 9, 0),
          ]);
          final entry = _entry(encounters: enc);

          final s1 = NodeSummaryEngine.compute(entry);
          final s2 = NodeSummaryEngine.compute(entry);

          expect(s1.summaryText, s2.summaryText);
          expect(s1.currentStreak, s2.currentStreak);
          expect(s1.busiestDayOfWeek, s2.busiestDayOfWeek);
          expect(s1.busiestDayCount, s2.busiestDayCount);
          expect(s1.activeDaysLast14, s2.activeDaysLast14);
          expect(s1.dominantBucket, s2.dominantBucket);

          for (final bucket in TimeOfDayBucket.values) {
            expect(s1.timeDistribution[bucket], s2.timeDistribution[bucket]);
          }
        });
      });
    });

    // -----------------------------------------------------------------------
    // Summary text
    // -----------------------------------------------------------------------

    group('summary text', () {
      test('includes dominant bucket description', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 20, 0), // evening
            DateTime(2026, 3, 14, 21, 0), // evening
            DateTime(2026, 3, 13, 19, 0), // evening
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          expect(summary.summaryText.toLowerCase(), contains('evening'));
        });
      });

      test('includes day pattern', () {
        withClock(Clock.fixed(_now), () {
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0), // Sunday
            DateTime(2026, 3, 14, 10, 0), // Saturday
            DateTime(2026, 3, 13, 10, 0), // Friday
          ]);
          final summary = NodeSummaryEngine.compute(_entry(encounters: enc));
          // Each day has 1 encounter; first one found wins.
          // The summary text should contain a day name.
          expect(
            summary.summaryText,
            matches(
              RegExp(
                r'(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)s',
              ),
            ),
          );
        });
      });

      test('uses encounterCount for totalEncounters', () {
        withClock(Clock.fixed(_now), () {
          // encounterCount can differ from encounters.length (rolling window)
          final enc = _encounters([
            DateTime(2026, 3, 15, 10, 0),
            DateTime(2026, 3, 14, 10, 0),
            DateTime(2026, 3, 13, 10, 0),
          ]);
          final summary = NodeSummaryEngine.compute(
            _entry(encounters: enc, encounterCount: 100),
          );
          expect(summary.totalEncounters, 100);
        });
      });
    });

    // -----------------------------------------------------------------------
    // TimeOfDayBucket
    // -----------------------------------------------------------------------

    group('TimeOfDayBucket', () {
      test('labels are capitalized', () {
        expect(TimeOfDayBucket.dawn.label, 'Dawn');
        expect(TimeOfDayBucket.midday.label, 'Midday');
        expect(TimeOfDayBucket.evening.label, 'Evening');
        expect(TimeOfDayBucket.night.label, 'Night');
      });

      test('ranges are human-readable', () {
        expect(TimeOfDayBucket.dawn.range, '5 AM – 11 AM');
        expect(TimeOfDayBucket.midday.range, '11 AM – 5 PM');
        expect(TimeOfDayBucket.evening.range, '5 PM – 11 PM');
        expect(TimeOfDayBucket.night.range, '11 PM – 5 AM');
      });

      test('all 24 hours map to a bucket', () {
        for (int h = 0; h < 24; h++) {
          final bucket = TimeOfDayBucket.fromHour(h);
          expect(bucket, isNotNull, reason: 'hour $h should map to a bucket');
        }
      });
    });

    // -----------------------------------------------------------------------
    // NodeSummary computed properties
    // -----------------------------------------------------------------------

    group('NodeSummary properties', () {
      test('hasEnoughData reflects threshold', () {
        expect(
          const NodeSummary(
            timeDistribution: {},
            currentStreak: 0,
            totalEncounters: 2,
            summaryText: '',
            activeDaysLast14: 0,
          ).hasEnoughData,
          isFalse,
        );
        expect(
          const NodeSummary(
            timeDistribution: {},
            currentStreak: 0,
            totalEncounters: 3,
            summaryText: '',
            activeDaysLast14: 0,
          ).hasEnoughData,
          isTrue,
        );
      });

      test('dominantBucket returns null when empty', () {
        const summary = NodeSummary(
          timeDistribution: {
            TimeOfDayBucket.dawn: 0,
            TimeOfDayBucket.midday: 0,
            TimeOfDayBucket.evening: 0,
            TimeOfDayBucket.night: 0,
          },
          currentStreak: 0,
          totalEncounters: 0,
          summaryText: '',
          activeDaysLast14: 0,
        );
        expect(summary.dominantBucket, isNull);
      });

      test('dominantBucket returns highest bucket', () {
        const summary = NodeSummary(
          timeDistribution: {
            TimeOfDayBucket.dawn: 1,
            TimeOfDayBucket.midday: 5,
            TimeOfDayBucket.evening: 3,
            TimeOfDayBucket.night: 2,
          },
          currentStreak: 0,
          totalEncounters: 11,
          summaryText: '',
          activeDaysLast14: 0,
        );
        expect(summary.dominantBucket, TimeOfDayBucket.midday);
      });
    });
  });
}
