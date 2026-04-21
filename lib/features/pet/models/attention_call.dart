// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';

import 'pet_enums.dart';

@immutable
class AttentionCall {
  final DateTime startedAt;
  final DateTime deadline;
  final CallReason reason;

  const AttentionCall({
    required this.startedAt,
    required this.deadline,
    required this.reason,
  });

  bool hasExpired(DateTime now) => now.isAfter(deadline);

  Duration remaining(DateTime now) {
    final d = deadline.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toUtc().millisecondsSinceEpoch,
    'deadline': deadline.toUtc().millisecondsSinceEpoch,
    'reason': reason.index,
  };

  factory AttentionCall.fromJson(Map<String, dynamic> json) {
    final reasonIndex = (json['reason'] as num?)?.toInt() ?? 0;
    final safeIndex = reasonIndex.clamp(0, CallReason.values.length - 1);
    return AttentionCall(
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['startedAt'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      deadline: DateTime.fromMillisecondsSinceEpoch(
        (json['deadline'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      reason: CallReason.values[safeIndex],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttentionCall &&
          startedAt == other.startedAt &&
          deadline == other.deadline &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(startedAt, deadline, reason);
}
