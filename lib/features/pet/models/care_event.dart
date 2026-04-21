// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';

import 'pet_enums.dart';

@immutable
class CareEvent {
  final DateTime at;
  final CareEventKind kind;
  final String? detail;

  const CareEvent({required this.at, required this.kind, this.detail});

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().millisecondsSinceEpoch,
    'kind': kind.index,
    if (detail != null) 'detail': detail,
  };

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    final kindIndex = (json['kind'] as num?)?.toInt() ?? 0;
    final safeIndex = kindIndex.clamp(0, CareEventKind.values.length - 1);
    return CareEvent(
      at: DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      kind: CareEventKind.values[safeIndex],
      detail: json['detail'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CareEvent &&
          at == other.at &&
          kind == other.kind &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(at, kind, detail);
}
