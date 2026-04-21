// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Hidden per-stage accumulators that drive evolution branch selection.
// Reset at every stage transition; never exposed to the user as a stat bar.

import 'package:flutter/foundation.dart';

@immutable
class CareAccumulators {
  final int mistakes;
  final int surges;
  final int answeredCalls;
  final int totalCalls;
  final int disciplineCorrections;

  const CareAccumulators({
    this.mistakes = 0,
    this.surges = 0,
    this.answeredCalls = 0,
    this.totalCalls = 0,
    this.disciplineCorrections = 0,
  });

  const CareAccumulators.empty() : this();

  CareAccumulators copyWith({
    int? mistakes,
    int? surges,
    int? answeredCalls,
    int? totalCalls,
    int? disciplineCorrections,
  }) {
    return CareAccumulators(
      mistakes: mistakes ?? this.mistakes,
      surges: surges ?? this.surges,
      answeredCalls: answeredCalls ?? this.answeredCalls,
      totalCalls: totalCalls ?? this.totalCalls,
      disciplineCorrections:
          disciplineCorrections ?? this.disciplineCorrections,
    );
  }

  /// Fraction of calls that were answered in time. 1.0 if no calls yet.
  double get attentionScore {
    if (totalCalls == 0) return 1.0;
    return answeredCalls / totalCalls;
  }

  Map<String, dynamic> toJson() => {
    'mistakes': mistakes,
    'surges': surges,
    'answeredCalls': answeredCalls,
    'totalCalls': totalCalls,
    'disciplineCorrections': disciplineCorrections,
  };

  factory CareAccumulators.fromJson(Map<String, dynamic> json) =>
      CareAccumulators(
        mistakes: (json['mistakes'] as num?)?.toInt() ?? 0,
        surges: (json['surges'] as num?)?.toInt() ?? 0,
        answeredCalls: (json['answeredCalls'] as num?)?.toInt() ?? 0,
        totalCalls: (json['totalCalls'] as num?)?.toInt() ?? 0,
        disciplineCorrections:
            (json['disciplineCorrections'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CareAccumulators &&
          mistakes == other.mistakes &&
          surges == other.surges &&
          answeredCalls == other.answeredCalls &&
          totalCalls == other.totalCalls &&
          disciplineCorrections == other.disciplineCorrections;

  @override
  int get hashCode => Object.hash(
    mistakes,
    surges,
    answeredCalls,
    totalCalls,
    disciplineCorrections,
  );
}
