// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard reply model.

import '../../../utils/text_sanitizer.dart';
import 'nodeboard_enums.dart';

class NodeBoardReply {
  final String id;
  final String threadId;
  final String nodeBoardId;
  final String sectionId;
  final String? authorUserId;
  final String? authorNodeId;
  final String authorDisplayName;
  final String body;
  final BodyFormat bodyFormat;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NodeBoardReply({
    required this.id,
    required this.threadId,
    required this.nodeBoardId,
    required this.sectionId,
    this.authorUserId,
    this.authorNodeId,
    required this.authorDisplayName,
    required this.body,
    this.bodyFormat = BodyFormat.plaintext,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NodeBoardReply.fromJson(Map<String, dynamic> json) => NodeBoardReply(
    id: json['id'] as String,
    threadId: json['threadId'] as String,
    nodeBoardId: json['nodeBoardId'] as String,
    sectionId: json['sectionId'] as String,
    authorUserId: json['authorUserId'] as String?,
    authorNodeId: json['authorNodeId'] as String?,
    authorDisplayName: sanitizeExternalText(
      json['authorDisplayName'] as String,
    ),
    body: sanitizeExternalText(json['body'] as String),
    bodyFormat: BodyFormat.fromJson(
      json['bodyFormat'] as String? ?? 'plaintext',
    ),
    isDeleted: json['isDeleted'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'nodeBoardId': nodeBoardId,
    'sectionId': sectionId,
    'authorUserId': authorUserId,
    if (authorNodeId != null) 'authorNodeId': authorNodeId,
    'authorDisplayName': authorDisplayName,
    'body': body,
    'bodyFormat': bodyFormat.toJson(),
    'isDeleted': isDeleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeBoardReply && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
