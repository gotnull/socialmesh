// SPDX-License-Identifier: GPL-3.0-or-later

// Node Summary Engine — deterministic insight generation from encounter data.
//
// Computes time-bucketed activity patterns, streaks, busiest days, and
// a one-line natural-language summary from a NodeDexEntry's encounter
// history. All methods are pure and side-effect-free: the same entry
// always produces the same summary.

import 'package:clock/clock.dart';

import '../models/nodedex_entry.dart';

/// Time-of-day bucket for encounter distribution.
enum TimeOfDayBucket {
  /// 05:00 – 10:59
  dawn,

  /// 11:00 – 16:59
  midday,

  /// 17:00 – 22:59
  evening,

  /// 23:00 – 04:59
  night;

  String get label {
    return switch (this) {
      TimeOfDayBucket.dawn => 'Dawn',
      TimeOfDayBucket.midday => 'Midday',
      TimeOfDayBucket.evening => 'Evening',
      TimeOfDayBucket.night => 'Night',
    };
  }

  String get range {
    return switch (this) {
      TimeOfDayBucket.dawn => '5 AM – 11 AM',
      TimeOfDayBucket.midday => '11 AM – 5 PM',
      TimeOfDayBucket.evening => '5 PM – 11 PM',
      TimeOfDayBucket.night => '11 PM – 5 AM',
    };
  }

  /// Returns the bucket for a given hour (0–23).
  static TimeOfDayBucket fromHour(int hour) {
    if (hour >= 5 && hour < 11) return TimeOfDayBucket.dawn;
    if (hour >= 11 && hour < 17) return TimeOfDayBucket.midday;
    if (hour >= 17 && hour < 23) return TimeOfDayBucket.evening;
    return TimeOfDayBucket.night;
  }
}

/// Computed summary statistics for a single NodeDex entry.
class NodeSummary {
  /// Encounter counts per time-of-day bucket.
  final Map<TimeOfDayBucket, int> timeDistribution;

  /// Current streak: consecutive days (ending today or yesterday)
  /// with at least one encounter.
  final int currentStreak;

  /// Day of the week with the most encounters (1=Mon, 7=Sun).
  /// Null when there are no encounters.
  final int? busiestDayOfWeek;

  /// Number of encounters on the busiest day.
  final int busiestDayCount;

  /// Total number of encounters used for this summary.
  final int totalEncounters;

  /// One-line natural language summary sentence.
  final String summaryText;

  /// Number of unique days with at least one encounter out of the
  /// last 14 calendar days.
  final int activeDaysLast14;

  const NodeSummary({
    required this.timeDistribution,
    required this.currentStreak,
    this.busiestDayOfWeek,
    this.busiestDayCount = 0,
    required this.totalEncounters,
    required this.summaryText,
    required this.activeDaysLast14,
  });

  /// Whether there is enough data to show a meaningful summary.
  bool get hasEnoughData => totalEncounters >= 3;

  /// The dominant time-of-day bucket (highest count).
  TimeOfDayBucket? get dominantBucket {
    if (totalEncounters == 0) return null;
    TimeOfDayBucket? best;
    int bestCount = 0;
    for (final entry in timeDistribution.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
  }
}

/// Deterministic summary engine for NodeDex entries.
///
/// All methods are static, pure, and side-effect-free.
class NodeSummaryEngine {
  NodeSummaryEngine._();

  /// Minimum encounters required for a meaningful summary.
  static const int minEncountersForSummary = 3;

  /// Compute the full summary for a NodeDex entry.
  static NodeSummary compute(NodeDexEntry entry) {
    final encounters = entry.encounters;
    final now = clock.now();

    if (encounters.length < minEncountersForSummary) {
      return NodeSummary(
        timeDistribution: _emptyDistribution(),
        currentStreak: encounters.isEmpty ? 0 : 1,
        totalEncounters: entry.encounterCount,
        summaryText: 'Keep observing to build a profile',
        activeDaysLast14: _activeDaysInWindow(encounters, now, 14),
      );
    }

    final timeDist = _computeTimeDistribution(encounters);
    final streak = _computeStreak(encounters, now);
    final (busiestDay, busiestCount) = _computeBusiestDay(encounters);
    final activeDays = _activeDaysInWindow(encounters, now, 14);

    final summary = _generateSummaryText(
      timeDist: timeDist,
      streak: streak,
      busiestDay: busiestDay,
      activeDays: activeDays,
      totalEncounters: entry.encounterCount,
    );

    return NodeSummary(
      timeDistribution: timeDist,
      currentStreak: streak,
      busiestDayOfWeek: busiestDay,
      busiestDayCount: busiestCount,
      totalEncounters: entry.encounterCount,
      summaryText: summary,
      activeDaysLast14: activeDays,
    );
  }

  // ---------------------------------------------------------------------------
  // Time-of-day distribution
  // ---------------------------------------------------------------------------

  static Map<TimeOfDayBucket, int> _emptyDistribution() {
    return {for (final bucket in TimeOfDayBucket.values) bucket: 0};
  }

  static Map<TimeOfDayBucket, int> _computeTimeDistribution(
    List<EncounterRecord> encounters,
  ) {
    final dist = _emptyDistribution();
    for (final enc in encounters) {
      final bucket = TimeOfDayBucket.fromHour(enc.timestamp.hour);
      dist[bucket] = dist[bucket]! + 1;
    }
    return dist;
  }

  // ---------------------------------------------------------------------------
  // Activity streak
  // ---------------------------------------------------------------------------

  /// Computes the current consecutive-day streak ending on today or
  /// yesterday. Returns 0 if no encounters occurred today or yesterday.
  static int _computeStreak(List<EncounterRecord> encounters, DateTime now) {
    if (encounters.isEmpty) return 0;

    // Collect unique dates (calendar days, local time).
    final dates = <DateTime>{};
    for (final enc in encounters) {
      dates.add(
        DateTime(enc.timestamp.year, enc.timestamp.month, enc.timestamp.day),
      );
    }

    final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak must start from today or yesterday.
    if (sortedDates.first != today && sortedDates.first != yesterday) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      final expected = sortedDates[i - 1].subtract(const Duration(days: 1));
      if (sortedDates[i] == expected) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  // ---------------------------------------------------------------------------
  // Busiest day of week
  // ---------------------------------------------------------------------------

  /// Returns (dayOfWeek, count) for the day with the most encounters.
  /// dayOfWeek follows Dart convention: 1=Mon, 7=Sun.
  static (int?, int) _computeBusiestDay(List<EncounterRecord> encounters) {
    if (encounters.isEmpty) return (null, 0);

    final dayCounts = <int, int>{};
    for (final enc in encounters) {
      final dow = enc.timestamp.weekday;
      dayCounts[dow] = (dayCounts[dow] ?? 0) + 1;
    }

    int bestDay = 1;
    int bestCount = 0;
    for (final entry in dayCounts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestDay = entry.key;
      }
    }

    return (bestDay, bestCount);
  }

  // ---------------------------------------------------------------------------
  // Active days in window
  // ---------------------------------------------------------------------------

  /// Counts unique calendar days with encounters in the last [windowDays].
  static int _activeDaysInWindow(
    List<EncounterRecord> encounters,
    DateTime now,
    int windowDays,
  ) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: windowDays - 1));

    final days = <DateTime>{};
    for (final enc in encounters) {
      if (enc.timestamp.isAfter(cutoff) ||
          enc.timestamp.isAtSameMomentAs(cutoff)) {
        days.add(
          DateTime(enc.timestamp.year, enc.timestamp.month, enc.timestamp.day),
        );
      }
    }
    return days.length;
  }

  // ---------------------------------------------------------------------------
  // Natural language summary
  // ---------------------------------------------------------------------------

  static String _generateSummaryText({
    required Map<TimeOfDayBucket, int> timeDist,
    required int streak,
    required int? busiestDay,
    required int activeDays,
    required int totalEncounters,
  }) {
    final parts = <String>[];

    // 1. Dominant time bucket.
    final dominant = _dominantBucket(timeDist);
    if (dominant != null) {
      parts.add('Most active in the ${dominant.label.toLowerCase()}');
    }

    // 2. Streak or recent activity.
    if (streak > 1) {
      parts.add('Seen $activeDays of the last 14 days');
    } else if (activeDays > 0) {
      parts.add('Spotted on $activeDays of the last 14 days');
    }

    // 3. Busiest day.
    if (busiestDay != null) {
      parts.add('Usually on ${_dayName(busiestDay)}s');
    }

    if (parts.isEmpty) {
      return '$totalEncounters encounters recorded';
    }

    return '${parts.join('. ')}.';
  }

  static TimeOfDayBucket? _dominantBucket(Map<TimeOfDayBucket, int> dist) {
    TimeOfDayBucket? best;
    int bestCount = 0;
    for (final entry in dist.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  static String _dayName(int weekday) {
    return switch (weekday) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Unknown',
    };
  }
}
