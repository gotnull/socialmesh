// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard domain model — a personal BBS.

import '../../../utils/text_sanitizer.dart';
import 'nodeboard_enums.dart';

String? _safe(String? input) =>
    input == null ? null : sanitizeExternalText(input);

class BoardStats {
  final int threadCount;
  final int replyCount;
  final int sectionCount;

  const BoardStats({
    this.threadCount = 0,
    this.replyCount = 0,
    this.sectionCount = 0,
  });

  factory BoardStats.fromJson(Map<String, dynamic> json) => BoardStats(
    threadCount: (json['threadCount'] as num?)?.toInt() ?? 0,
    replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
    sectionCount: (json['sectionCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'threadCount': threadCount,
    'replyCount': replyCount,
    'sectionCount': sectionCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardStats &&
          threadCount == other.threadCount &&
          replyCount == other.replyCount &&
          sectionCount == other.sectionCount;

  @override
  int get hashCode => Object.hash(threadCount, replyCount, sectionCount);
}

class NodeBoard {
  final String id;
  final String ownerUserId;
  final String? ownerNodeId;
  final String slug;
  final String title;
  final String sysopName;
  final String? tagline;
  final String? description;
  final BoardVisibility visibility;
  final String? themeId;
  final String? welcomeText;
  final String? ansiSplash;
  final bool isListedInNodeDex;
  final bool isGuestPostingAllowed;
  final bool isReadOnly;
  final BoardStats stats;
  final DateTime? lastActivityAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NodeBoard({
    required this.id,
    required this.ownerUserId,
    this.ownerNodeId,
    required this.slug,
    required this.title,
    required this.sysopName,
    this.tagline,
    this.description,
    this.visibility = BoardVisibility.public_,
    this.themeId,
    this.welcomeText,
    this.ansiSplash,
    this.isListedInNodeDex = true,
    this.isGuestPostingAllowed = false,
    this.isReadOnly = false,
    this.stats = const BoardStats(),
    this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NodeBoard.fromJson(Map<String, dynamic> json) => NodeBoard(
    id: json['id'] as String,
    ownerUserId: json['ownerUserId'] as String,
    ownerNodeId: json['ownerNodeId'] as String?,
    slug: json['slug'] as String,
    title: sanitizeExternalText(json['title'] as String),
    sysopName: sanitizeExternalText(json['sysopName'] as String),
    tagline: _safe(json['tagline'] as String?),
    description: _safe(json['description'] as String?),
    visibility: BoardVisibility.fromJson(
      json['visibility'] as String? ?? 'public',
    ),
    themeId: json['themeId'] as String?,
    welcomeText: _safe(json['welcomeText'] as String?),
    ansiSplash: _safe(json['ansiSplash'] as String?),
    isListedInNodeDex: json['isListedInNodeDex'] as bool? ?? true,
    isGuestPostingAllowed: json['isGuestPostingAllowed'] as bool? ?? false,
    isReadOnly: json['isReadOnly'] as bool? ?? false,
    stats: json['stats'] != null
        ? BoardStats.fromJson(json['stats'] as Map<String, dynamic>)
        : const BoardStats(),
    lastActivityAt: json['lastActivityAt'] != null
        ? DateTime.parse(json['lastActivityAt'] as String)
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerUserId': ownerUserId,
    'ownerNodeId': ownerNodeId,
    'slug': slug,
    'title': title,
    'sysopName': sysopName,
    'tagline': tagline,
    'description': description,
    'visibility': visibility.toJson(),
    'themeId': themeId,
    'welcomeText': welcomeText,
    'ansiSplash': ansiSplash,
    'isListedInNodeDex': isListedInNodeDex,
    'isGuestPostingAllowed': isGuestPostingAllowed,
    'isReadOnly': isReadOnly,
    'stats': stats.toJson(),
    'lastActivityAt': lastActivityAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  NodeBoard copyWith({
    String? title,
    String? sysopName,
    String? tagline,
    String? description,
    BoardVisibility? visibility,
    String? themeId,
    String? welcomeText,
    String? ansiSplash,
    bool? isListedInNodeDex,
    bool? isGuestPostingAllowed,
    bool? isReadOnly,
    BoardStats? stats,
    DateTime? lastActivityAt,
  }) => NodeBoard(
    id: id,
    ownerUserId: ownerUserId,
    ownerNodeId: ownerNodeId,
    slug: slug,
    title: title ?? this.title,
    sysopName: sysopName ?? this.sysopName,
    tagline: tagline ?? this.tagline,
    description: description ?? this.description,
    visibility: visibility ?? this.visibility,
    themeId: themeId ?? this.themeId,
    welcomeText: welcomeText ?? this.welcomeText,
    ansiSplash: ansiSplash ?? this.ansiSplash,
    isListedInNodeDex: isListedInNodeDex ?? this.isListedInNodeDex,
    isGuestPostingAllowed: isGuestPostingAllowed ?? this.isGuestPostingAllowed,
    isReadOnly: isReadOnly ?? this.isReadOnly,
    stats: stats ?? this.stats,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoard && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
