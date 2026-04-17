// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard thread model.

import '../../../utils/text_sanitizer.dart';
import 'nodeboard_enums.dart';

class NodeBoardThread {
  final String id;
  final String nodeBoardId;
  final String sectionId;
  final String? authorUserId;
  final String? authorNodeId;
  final String authorDisplayName;
  final String title;
  final String body;
  final BodyFormat bodyFormat;
  final bool isPinned;
  final bool isLocked;
  final bool isDeleted;
  final int replyCount;
  final DateTime? lastReplyAt;
  final String? lastReplyUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NodeBoardThread({
    required this.id,
    required this.nodeBoardId,
    required this.sectionId,
    this.authorUserId,
    this.authorNodeId,
    required this.authorDisplayName,
    required this.title,
    required this.body,
    this.bodyFormat = BodyFormat.plaintext,
    this.isPinned = false,
    this.isLocked = false,
    this.isDeleted = false,
    this.replyCount = 0,
    this.lastReplyAt,
    this.lastReplyUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NodeBoardThread.fromJson(Map<String, dynamic> json) =>
      NodeBoardThread(
        id: json['id'] as String,
        nodeBoardId: json['nodeBoardId'] as String,
        sectionId: json['sectionId'] as String,
        authorUserId: json['authorUserId'] as String?,
        authorNodeId: json['authorNodeId'] as String?,
        authorDisplayName: sanitizeExternalText(
          json['authorDisplayName'] as String,
        ),
        title: sanitizeExternalText(json['title'] as String),
        body: sanitizeExternalText(json['body'] as String),
        bodyFormat: BodyFormat.fromJson(
          json['bodyFormat'] as String? ?? 'plaintext',
        ),
        isPinned: json['isPinned'] as bool? ?? false,
        isLocked: json['isLocked'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
        replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
        lastReplyAt: json['lastReplyAt'] != null
            ? DateTime.parse(json['lastReplyAt'] as String)
            : null,
        lastReplyUserId: json['lastReplyUserId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeBoardId': nodeBoardId,
    'sectionId': sectionId,
    'authorUserId': authorUserId,
    if (authorNodeId != null) 'authorNodeId': authorNodeId,
    'authorDisplayName': authorDisplayName,
    'title': title,
    'body': body,
    'bodyFormat': bodyFormat.toJson(),
    'isPinned': isPinned,
    'isLocked': isLocked,
    'isDeleted': isDeleted,
    'replyCount': replyCount,
    'lastReplyAt': lastReplyAt?.toIso8601String(),
    'lastReplyUserId': lastReplyUserId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoardThread && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
