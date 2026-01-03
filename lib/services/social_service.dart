import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/social.dart';

/// Service for social features: follows, posts, comments, likes.
///
/// Uses Firestore for direct reads/writes and Cloud Functions for
/// complex operations that need to maintain counters.
class SocialService {
  SocialService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // FOLLOW SYSTEM
  // ===========================================================================

  /// Follow a user. Creates a follow document with composite ID.
  Future<void> followUser(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to follow users');
    }
    if (currentUserId == targetUserId) {
      throw ArgumentError('Cannot follow yourself');
    }

    final followId = '${currentUserId}_$targetUserId';
    final follow = Follow(
      id: followId,
      followerId: currentUserId,
      followeeId: targetUserId,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('follows')
        .doc(followId)
        .set(follow.toFirestore());
  }

  /// Unfollow a user. Deletes the follow document.
  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unfollow users');
    }

    final followId = '${currentUserId}_$targetUserId';
    await _firestore.collection('follows').doc(followId).delete();
  }

  /// Check if current user follows the target user.
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final followId = '${currentUserId}_$targetUserId';
    final doc = await _firestore.collection('follows').doc(followId).get();
    return doc.exists;
  }

  /// Check if target user follows the current user.
  Future<bool> isFollowedBy(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final followId = '${targetUserId}_$currentUserId';
    final doc = await _firestore.collection('follows').doc(followId).get();
    return doc.exists;
  }

  /// Stream of follow status for a target user.
  Stream<bool> watchFollowStatus(String targetUserId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value(false);
    }

    final followId = '${currentUserId}_$targetUserId';
    return _firestore
        .collection('follows')
        .doc(followId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get paginated list of followers for a user.
  Future<PaginatedResult<FollowWithProfile>> getFollowers(
    String userId, {
    int limit = 20,
    String? startAfterId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('follows')
        .where('followeeId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await _firestore
          .collection('follows')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final items = await Future.wait(
      snapshot.docs.map((doc) async {
        final follow = Follow.fromFirestore(doc);
        final profile = await _getPublicProfile(follow.followerId);
        return FollowWithProfile(follow: follow, profile: profile);
      }),
    );

    return PaginatedResult(
      items: items,
      hasMore: snapshot.docs.length == limit,
      lastId: snapshot.docs.lastOrNull?.id,
    );
  }

  /// Get paginated list of users that a user follows.
  Future<PaginatedResult<FollowWithProfile>> getFollowing(
    String userId, {
    int limit = 20,
    String? startAfterId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await _firestore
          .collection('follows')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final items = await Future.wait(
      snapshot.docs.map((doc) async {
        final follow = Follow.fromFirestore(doc);
        final profile = await _getPublicProfile(follow.followeeId);
        return FollowWithProfile(follow: follow, profile: profile);
      }),
    );

    return PaginatedResult(
      items: items,
      hasMore: snapshot.docs.length == limit,
      lastId: snapshot.docs.lastOrNull?.id,
    );
  }

  // ===========================================================================
  // POSTS
  // ===========================================================================

  /// Create a new post. Returns the created post.
  Future<Post> createPost({
    required String content,
    List<String>? imageUrls,
    PostVisibility visibility = PostVisibility.public,
    PostLocation? location,
    String? nodeId,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to create posts');
    }

    // Ensure profile exists and get author snapshot
    await ensureProfileExists();
    final profile = await _getPublicProfile(currentUserId);
    final authorSnapshot = profile != null
        ? PostAuthorSnapshot(
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            isVerified: profile.isVerified,
          )
        : null;

    final docRef = _firestore.collection('posts').doc();
    final post = Post(
      id: docRef.id,
      authorId: currentUserId,
      content: content,
      mediaUrls: imageUrls ?? [],
      location: location,
      nodeId: nodeId,
      createdAt: DateTime.now(),
      commentCount: 0,
      likeCount: 0,
      authorSnapshot: authorSnapshot,
    );

    // Include visibility in the Firestore document
    final data = post.toFirestore();
    data['visibility'] = visibility.name;

    await docRef.set(data);
    return post;
  }

  /// Delete a post. Only the author can delete.
  Future<void> deletePost(String postId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to delete posts');
    }

    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) {
      throw StateError('Post not found');
    }
    if (doc.data()?['authorId'] != currentUserId) {
      throw StateError('Only the author can delete this post');
    }

    await _firestore.collection('posts').doc(postId).delete();
  }

  /// Get a single post by ID.
  Future<Post?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    final post = Post.fromFirestore(doc);
    // Enrich with author data if missing
    final enriched = await _enrichPostsWithAuthors([post]);
    return enriched.first;
  }

  /// Stream a single post by ID for real-time updates.
  Stream<Post?> watchPost(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return null;
      final post = Post.fromFirestore(doc);
      // Enrich with author data if missing
      final enriched = await _enrichPostsWithAuthors([post]);
      return enriched.first;
    });
  }

  /// Get paginated posts by a specific user.
  Future<PaginatedResult<Post>> getUserPosts(
    String userId, {
    int limit = 20,
    String? startAfterId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await _firestore
          .collection('posts')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final items = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    final enrichedItems = await _enrichPostsWithAuthors(items);

    return PaginatedResult(
      items: enrichedItems,
      hasMore: snapshot.docs.length == limit,
      lastId: snapshot.docs.lastOrNull?.id,
    );
  }

  /// Stream of posts by a specific user.
  Stream<List<Post>> watchUserPosts(String userId, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          return _enrichPostsWithAuthors(posts);
        });
  }

  // ===========================================================================
  // EXPLORE (ALL PUBLIC POSTS)
  // ===========================================================================

  /// Get all public posts for exploration/discovery.
  Future<PaginatedResult<Post>> getExplorePosts({
    int limit = 20,
    DateTime? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }

    final snapshot = await query.get();
    final items = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // Enrich posts that are missing author snapshots
    final enrichedItems = await _enrichPostsWithAuthors(items);

    return PaginatedResult(
      items: enrichedItems,
      hasMore: snapshot.docs.length == limit,
      lastTimestamp: enrichedItems.lastOrNull?.createdAt,
    );
  }

  /// Stream of all public posts for explore feed.
  Stream<List<Post>> watchExplorePosts({int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          // Enrich posts that are missing author snapshots
          return _enrichPostsWithAuthors(posts);
        });
  }

  /// Enrich posts with fresh author profile data.
  /// Always uses current profile data to ensure display names stay up-to-date.
  Future<List<Post>> _enrichPostsWithAuthors(List<Post> posts) async {
    if (posts.isEmpty) return posts;

    // Collect all unique author IDs
    final authorIds = posts.map((p) => p.authorId).toSet();

    // Batch fetch profiles
    final profiles = <String, PublicProfile?>{};
    for (final authorId in authorIds) {
      profiles[authorId] = await _getPublicProfile(authorId);
    }

    // Enrich all posts with fresh author data
    return posts.map((post) {
      final profile = profiles[post.authorId];
      if (profile == null) return post;

      return post.copyWith(
        authorSnapshot: PostAuthorSnapshot(
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
          isVerified: profile.isVerified,
        ),
      );
    }).toList();
  }

  // ===========================================================================
  // FEED
  // ===========================================================================

  /// Get the current user's feed.
  Future<PaginatedResult<FeedItem>> getFeed({
    int limit = 20,
    DateTime? startAfter,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to get feed');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('feeds')
        .doc(currentUserId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => FeedItem.fromFirestore(doc))
        .toList();

    return PaginatedResult(
      items: items,
      hasMore: snapshot.docs.length == limit,
      lastTimestamp: items.lastOrNull?.createdAt,
    );
  }

  /// Stream the current user's feed (real-time updates).
  Stream<List<FeedItem>> watchFeed({int limit = 20}) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('feeds')
        .doc(currentUserId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => FeedItem.fromFirestore(doc)).toList(),
        );
  }

  // ===========================================================================
  // COMMENTS
  // ===========================================================================

  /// Create a comment on a post.
  /// Note: commentCount is updated by Cloud Function onCommentCreated
  Future<Comment> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to comment');
    }

    final docRef = _firestore.collection('comments').doc();
    final comment = Comment(
      id: docRef.id,
      postId: postId,
      authorId: currentUserId,
      parentId: parentId,
      content: content,
      createdAt: DateTime.now(),
      replyCount: 0,
    );

    await docRef.set(comment.toFirestore());
    return comment;
  }

  /// Delete a comment. Only the author can delete.
  /// Note: commentCount is updated by Cloud Function onCommentDeleted
  Future<void> deleteComment(String commentId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to delete comments');
    }

    final doc = await _firestore.collection('comments').doc(commentId).get();
    if (!doc.exists) {
      throw StateError('Comment not found');
    }
    final data = doc.data()!;
    if (data['authorId'] != currentUserId) {
      throw StateError('Only the author can delete this comment');
    }

    await doc.reference.delete();
  }

  /// Get paginated comments for a post (root level or replies to a parent).
  Future<PaginatedResult<CommentWithAuthor>> getComments(
    String postId, {
    String? parentId,
    int limit = 20,
    String? startAfterId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .where('parentId', isEqualTo: parentId)
        .orderBy('createdAt')
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await _firestore
          .collection('comments')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final items = await Future.wait(
      snapshot.docs.map((doc) async {
        final comment = Comment.fromFirestore(doc);
        final author = await _getPublicProfile(comment.authorId);
        return CommentWithAuthor(comment: comment, author: author);
      }),
    );

    return PaginatedResult(
      items: items,
      hasMore: snapshot.docs.length == limit,
      lastId: snapshot.docs.lastOrNull?.id,
    );
  }

  /// Stream ALL comments for a post (including nested replies).
  /// Returns a flat list - UI should organize by parentId.
  Stream<List<CommentWithAuthor>> watchComments(
    String postId, {
    int limit = 100,
  }) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt')
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          final items = await Future.wait(
            snapshot.docs.map((doc) async {
              final comment = Comment.fromFirestore(doc);
              final author = await _getPublicProfile(comment.authorId);
              return CommentWithAuthor(comment: comment, author: author);
            }),
          );
          return items;
        });
  }

  // ===========================================================================
  // LIKES
  // ===========================================================================

  /// Like a post. Creates a like document with composite ID.
  Future<void> likePost(String postId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to like posts');
    }

    final likeId = '${currentUserId}_$postId';
    final like = Like(
      id: likeId,
      userId: currentUserId,
      postId: postId,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('likes').doc(likeId).set(like.toFirestore());
  }

  /// Unlike a post. Deletes the like document.
  Future<void> unlikePost(String postId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unlike posts');
    }

    final likeId = '${currentUserId}_$postId';
    await _firestore.collection('likes').doc(likeId).delete();
  }

  /// Check if current user has liked a post.
  Future<bool> hasLikedPost(String postId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final likeId = '${currentUserId}_$postId';
    final doc = await _firestore.collection('likes').doc(likeId).get();
    return doc.exists;
  }

  /// Like a comment. Creates a like document.
  Future<void> likeComment(String commentId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to like comments');
    }

    final likeId = '${currentUserId}_comment_$commentId';
    await _firestore.collection('likes').doc(likeId).set({
      'userId': currentUserId,
      'targetId': commentId,
      'targetType': 'comment',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unlike a comment. Deletes the like document.
  Future<void> unlikeComment(String commentId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unlike comments');
    }

    final likeId = '${currentUserId}_comment_$commentId';
    await _firestore.collection('likes').doc(likeId).delete();
  }

  /// Check if current user has liked a comment.
  Future<bool> isCommentLiked(String commentId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final likeId = '${currentUserId}_comment_$commentId';
    final doc = await _firestore.collection('likes').doc(likeId).get();
    return doc.exists;
  }

  /// Stream of like status for a post.
  Stream<bool> watchLikeStatus(String postId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value(false);
    }

    final likeId = '${currentUserId}_$postId';
    return _firestore
        .collection('likes')
        .doc(likeId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ===========================================================================
  // REPORTS
  // ===========================================================================

  /// Report a comment for review by admins.
  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to report comments');
    }

    // Get the comment to include context in the report
    final commentDoc = await _firestore
        .collection('comments')
        .doc(commentId)
        .get();
    if (!commentDoc.exists) {
      throw StateError('Comment not found');
    }

    final commentData = commentDoc.data()!;

    await _firestore.collection('reports').add({
      'type': 'comment',
      'targetId': commentId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      // Include context for admin review
      'context': {
        'content': commentData['content'],
        'authorId': commentData['authorId'],
        'postId': commentData['postId'],
      },
    });
  }

  /// Get all pending reports (admin only).
  Stream<List<Map<String, dynamic>>> watchPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList(),
        );
  }

  /// Dismiss a report (admin only).
  Future<void> dismissReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _currentUserId,
    });
  }

  /// Delete reported content and resolve the report (admin only).
  Future<void> deleteReportedContent(String reportId) async {
    final reportDoc = await _firestore
        .collection('reports')
        .doc(reportId)
        .get();
    if (!reportDoc.exists) return;

    final data = reportDoc.data()!;
    final type = data['type'] as String;
    final targetId = data['targetId'] as String;

    // Delete the content based on type
    if (type == 'comment') {
      await _firestore.collection('comments').doc(targetId).delete();
    } else if (type == 'post') {
      await _firestore.collection('posts').doc(targetId).delete();
    }

    // Mark report as resolved
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'deleted',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _currentUserId,
    });
  }

  // ===========================================================================
  // PUBLIC PROFILES
  // ===========================================================================

  /// Ensures the current user has a profile document in Firestore.
  /// Creates one if it doesn't exist, using Firebase Auth display name.
  /// Call this before any social interaction (posting, commenting, etc.)
  Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in');
    }

    final docRef = _firestore.collection('profiles').doc(user.uid);

    // Force server check to avoid cache issues
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await docRef.get(const GetOptions(source: Source.server));
    } catch (e) {
      doc = await docRef.get();
    }

    // Try to get the user's app profile (from 'users' collection) to sync displayName
    String? userProfileDisplayName;
    String? userProfileAvatarUrl;
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (userDoc.exists) {
        final userData = userDoc.data();
        userProfileDisplayName = userData?['displayName'] as String?;
        userProfileAvatarUrl = userData?['avatarUrl'] as String?;
      }
    } catch (e) {
      // Ignore - will use OAuth displayName as fallback
    }

    if (!doc.exists) {
      // Create profile - prefer users collection displayName over OAuth name
      final displayName =
          userProfileDisplayName ??
          user.displayName ??
          user.email?.split('@').first ??
          'User';
      final avatarUrl = userProfileAvatarUrl ?? user.photoURL;

      await docRef.set({
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'bio': null,
        'callsign': null,
        'followerCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Profile exists - check if we need to sync displayName from users collection
      final currentDisplayName = doc.data()?['displayName'] as String?;
      if (userProfileDisplayName != null &&
          userProfileDisplayName.isNotEmpty &&
          userProfileDisplayName != currentDisplayName) {
        // Sync the displayName from users collection to profiles collection
        final updates = <String, dynamic>{
          'displayName': userProfileDisplayName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // Also sync avatar if users collection has one
        if (userProfileAvatarUrl != null && userProfileAvatarUrl.isNotEmpty) {
          updates['avatarUrl'] = userProfileAvatarUrl;
        }
        await docRef.update(updates);
      }
    }
  }

  /// Get a user's public profile.
  Future<PublicProfile?> getPublicProfile(String userId) async {
    return _getPublicProfile(userId);
  }

  /// Stream a user's public profile.
  Stream<PublicProfile?> watchPublicProfile(String userId) {
    return _firestore.collection('profiles').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PublicProfile.fromFirestore(doc);
    });
  }

  /// Update the current user's public profile.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? callsign,
    String? avatarUrl,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to update profile');
    }

    // Ensure profile exists first
    await ensureProfileExists();

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Always include displayName if provided (even if same as before)
    if (displayName != null && displayName.isNotEmpty) {
      updates['displayName'] = displayName;
    }
    // Bio can be empty string to clear it
    if (bio != null) updates['bio'] = bio.isEmpty ? null : bio;
    // Callsign can be null to clear it
    if (callsign != null) {
      updates['callsign'] = callsign.isEmpty ? null : callsign;
    }
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    debugPrint('SocialService.updateProfile: updating with $updates');
    await _firestore.collection('profiles').doc(currentUserId).update(updates);
  }

  /// Upload a profile avatar image.
  Future<String> uploadProfileAvatar(String filePath) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to upload avatar');
    }

    final file = File(filePath);
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_avatars')
        .child('$currentUserId.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    // Update profile with new avatar URL
    await updateProfile(avatarUrl: url);

    return url;
  }

  // ===========================================================================
  // BLOCKS
  // ===========================================================================

  /// Block a user.
  Future<void> blockUser(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to block users');
    }

    final blockId = '${currentUserId}_$targetUserId';
    await _firestore.collection('blocks').doc(blockId).set({
      'blockerId': currentUserId,
      'blockedId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also unfollow if following
    final followId = '${currentUserId}_$targetUserId';
    await _firestore.collection('follows').doc(followId).delete();
  }

  /// Unblock a user.
  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unblock users');
    }

    final blockId = '${currentUserId}_$targetUserId';
    await _firestore.collection('blocks').doc(blockId).delete();
  }

  /// Check if current user has blocked a user.
  Future<bool> hasBlocked(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final blockId = '${currentUserId}_$targetUserId';
    final doc = await _firestore.collection('blocks').doc(blockId).get();
    return doc.exists;
  }

  /// Get list of blocked user IDs.
  Future<List<String>> getBlockedUserIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: currentUserId)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['blockedId'] as String)
        .toList();
  }

  // ===========================================================================
  // REPORTS
  // ===========================================================================

  /// Report a post for moderation.
  Future<void> reportPost(String postId, String reason) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to report posts');
    }

    await _firestore.collection('reports').add({
      'type': 'post',
      'targetId': postId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Report a user for moderation.
  Future<void> reportUser(String userId, String reason) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to report users');
    }

    await _firestore.collection('reports').add({
      'type': 'user',
      'targetId': userId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  Future<PublicProfile?> _getPublicProfile(String userId) async {
    // Try server first for fresh data, fall back to cache
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
    } catch (e) {
      // Server fetch failed, try cache
      doc = await _firestore.collection('profiles').doc(userId).get();
    }
    if (!doc.exists) {
      return null;
    }
    return PublicProfile.fromFirestore(doc);
  }
}

// ===========================================================================
// RESULT TYPES
// ===========================================================================

/// Generic paginated result.
class PaginatedResult<T> {
  PaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastId,
    this.lastTimestamp,
  });

  final List<T> items;
  final bool hasMore;
  final String? lastId;
  final DateTime? lastTimestamp;
}

/// Follow with the profile of the followed/follower user.
class FollowWithProfile {
  FollowWithProfile({required this.follow, this.profile});

  final Follow follow;
  final PublicProfile? profile;
}

/// Comment with author profile.
class CommentWithAuthor {
  CommentWithAuthor({required this.comment, this.author});

  final Comment comment;
  final PublicProfile? author;
}
