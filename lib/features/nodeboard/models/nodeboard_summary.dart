// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Lightweight projection for board list views and NodeDex cards.

import '../../../utils/text_sanitizer.dart';
import 'nodeboard.dart';
import 'nodeboard_enums.dart';

class NodeBoardSummary {
  final String id;
  final String slug;
  final String title;
  final String sysopName;
  final String? tagline;
  final BoardVisibility visibility;
  final String? themeId;
  final BoardStats stats;
  final DateTime? lastActivityAt;
  final DateTime createdAt;

  const NodeBoardSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.sysopName,
    this.tagline,
    this.visibility = BoardVisibility.public_,
    this.themeId,
    this.stats = const BoardStats(),
    this.lastActivityAt,
    required this.createdAt,
  });

  factory NodeBoardSummary.fromJson(Map<String, dynamic> json) {
    final rawTagline = json['tagline'] as String?;
    return NodeBoardSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: sanitizeExternalText(json['title'] as String),
      sysopName: sanitizeExternalText(json['sysopName'] as String),
      tagline: rawTagline == null ? null : sanitizeExternalText(rawTagline),
      visibility: BoardVisibility.fromJson(
        json['visibility'] as String? ?? 'public',
      ),
      themeId: json['themeId'] as String?,
      stats: json['stats'] != null
          ? BoardStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const BoardStats(),
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'sysopName': sysopName,
    'tagline': tagline,
    'visibility': visibility.toJson(),
    'themeId': themeId,
    'stats': stats.toJson(),
    'lastActivityAt': lastActivityAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoardSummary && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
