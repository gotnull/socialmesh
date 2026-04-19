// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard section model.

import '../../../utils/text_sanitizer.dart';
import 'nodeboard_enums.dart';

class NodeBoardSection {
  final String id;
  final String nodeBoardId;
  final String key;
  final String title;
  final String? description;
  final int sortOrder;
  final SectionVisibility visibility;
  final PostingPolicy postingPolicy;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NodeBoardSection({
    required this.id,
    required this.nodeBoardId,
    required this.key,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.visibility = SectionVisibility.public_,
    this.postingPolicy = PostingPolicy.authenticatedUsers,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NodeBoardSection.fromJson(Map<String, dynamic> json) =>
      NodeBoardSection(
        id: json['id'] as String,
        nodeBoardId: json['nodeBoardId'] as String,
        key: json['key'] as String,
        title: sanitizeExternalText(json['title'] as String),
        description: json['description'] == null
            ? null
            : sanitizeExternalText(json['description'] as String),
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        visibility: SectionVisibility.fromJson(
          json['visibility'] as String? ?? 'public',
        ),
        postingPolicy: PostingPolicy.fromJson(
          json['postingPolicy'] as String? ?? 'authenticatedUsers',
        ),
        isLocked: json['isLocked'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeBoardId': nodeBoardId,
    'key': key,
    'title': title,
    'description': description,
    'sortOrder': sortOrder,
    'visibility': visibility.toJson(),
    'postingPolicy': postingPolicy.toJson(),
    'isLocked': isLocked,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoardSection && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
