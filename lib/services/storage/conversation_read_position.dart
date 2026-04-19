// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';

@immutable
class ConversationReadPosition {
  final String conversationKey;
  final String anchorMessageId;
  final DateTime anchorTimestamp;
  final double? anchorAlignment;
  final bool wasNearLatest;
  final DateTime updatedAt;

  const ConversationReadPosition({
    required this.conversationKey,
    required this.anchorMessageId,
    required this.anchorTimestamp,
    required this.wasNearLatest,
    required this.updatedAt,
    this.anchorAlignment,
  });

  ConversationReadPosition copyWith({
    String? conversationKey,
    String? anchorMessageId,
    DateTime? anchorTimestamp,
    double? anchorAlignment,
    bool clearAnchorAlignment = false,
    bool? wasNearLatest,
    DateTime? updatedAt,
  }) {
    return ConversationReadPosition(
      conversationKey: conversationKey ?? this.conversationKey,
      anchorMessageId: anchorMessageId ?? this.anchorMessageId,
      anchorTimestamp: anchorTimestamp ?? this.anchorTimestamp,
      anchorAlignment: clearAnchorAlignment
          ? null
          : anchorAlignment ?? this.anchorAlignment,
      wasNearLatest: wasNearLatest ?? this.wasNearLatest,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationReadPosition &&
        other.conversationKey == conversationKey &&
        other.anchorMessageId == anchorMessageId &&
        other.anchorTimestamp == anchorTimestamp &&
        other.anchorAlignment == anchorAlignment &&
        other.wasNearLatest == wasNearLatest &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    conversationKey,
    anchorMessageId,
    anchorTimestamp,
    anchorAlignment,
    wasNearLatest,
    updatedAt,
  );
}
