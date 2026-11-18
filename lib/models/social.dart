// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_profile.dart';

/// Cached metadata for a linked mesh node.
///
/// Stored in profile's `linkedNodeMetadata` map to ensure node info
/// is available even when the device isn't actively connected to the mesh.
class LinkedNodeInfo {
  final int nodeId;
  final String? longName;
  final String? shortName;
  final int? avatarColor;

  const LinkedNodeInfo({
    required this.nodeId,
    this.longName,
    this.shortName,
    this.avatarColor,
  });

  factory LinkedNodeInfo.fromJson(Map<String, dynamic> json) {
    return LinkedNodeInfo(
      nodeId: json['nodeId'] as int,
      longName: json['longName'] as String?,
      shortName: json['shortName'] as String?,
      avatarColor: json['avatarColor'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    if (longName != null) 'longName': longName,
    if (shortName != null) 'shortName': shortName,
    if (avatarColor != null) 'avatarColor': avatarColor,
  };

  /// Get the display name (long name or short name or hex ID)
  String get displayName =>
      longName ?? shortName ?? '!${nodeId.toRadixString(16)}';

  /// Get the avatar name (short name first character or hex ID first character)
  String get avatarName {
    if (shortName != null && shortName!.isNotEmpty) {
      return shortName!;
    }
    if (longName != null && longName!.isNotEmpty) {
      return longName![0].toUpperCase();
    }
    return nodeId.toRadixString(16)[0].toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkedNodeInfo &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Public profile data for social features.
///
/// This is the denormalized public view of a user profile.
/// Stored in `profiles/{userId}` collection.
class PublicProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? callsign;
  final String? website;
  final ProfileSocialLinks? socialLinks;
  final int? primaryNodeId;
  final List<int> linkedNodeIds;
  final Map<int, LinkedNodeInfo> linkedNodeMetadata;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool isVerified;
  final bool isPrivate;
  final DateTime? createdAt;

  const PublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.callsign,
    this.website,
    this.socialLinks,
    this.primaryNodeId,
    this.linkedNodeIds = const [],
    this.linkedNodeMetadata = const {},
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.isVerified = false,
    this.isPrivate = false,
    this.createdAt,
  });

  factory PublicProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse linkedNodeMetadata map
    final metadataMap = <int, LinkedNodeInfo>{};
    final rawMetadata = data['linkedNodeMetadata'] as Map<String, dynamic>?;
    if (rawMetadata != null) {
      for (final entry in rawMetadata.entries) {
        final nodeId = int.tryParse(entry.key);
        if (nodeId != null && entry.value is Map<String, dynamic>) {
          metadataMap[nodeId] = LinkedNodeInfo.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return PublicProfile(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Unknown',
      avatarUrl: data['avatarUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      bio: data['bio'] as String?,
      callsign: data['callsign'] as String?,
      website: data['website'] as String?,
      socialLinks: data['socialLinks'] != null
          ? ProfileSocialLinks.fromJson(
              data['socialLinks'] as Map<String, dynamic>,
            )
          : null,
      primaryNodeId: data['primaryNodeId'] as int?,
      linkedNodeIds:
          (data['linkedNodeIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      linkedNodeMetadata: metadataMap,
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      postCount: data['postCount'] as int? ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      isPrivate: data['isPrivate'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Check if this profile has a specific node linked
  bool hasNodeLinked(int nodeId) => linkedNodeIds.contains(nodeId);

  /// Get cached node info for a linked node (if available)
  LinkedNodeInfo? getLinkedNodeInfo(int nodeId) => linkedNodeMetadata[nodeId];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PublicProfile(id: $id, displayName: $displayName)';
}
