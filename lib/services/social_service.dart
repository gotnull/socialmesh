// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/logging.dart';
import '../models/social.dart';
import '../models/user_profile.dart';
import 'social_activity_service.dart';

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

  /// Follow a user or send a follow request if the target account is private.
  /// Returns 'followed' if directly followed, 'requested' if request was sent.
  Future<String> followUser(String targetUserId, {int? actorNodeNum}) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to follow users');
    }
    if (currentUserId == targetUserId) {
      throw ArgumentError('Cannot follow yourself');
    }

    // Check if target user has a private account
    final targetProfile = await _getPublicProfile(targetUserId);
    final isPrivate = targetProfile?.isPrivate ?? false;

    if (isPrivate) {
      // Create a follow request instead of directly following
      await _createFollowRequest(targetUserId, actorNodeNum: actorNodeNum);
      return 'requested';
    }

    // Public account - follow directly
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

    // Create activity for the followed user
    try {
      final activityService = SocialActivityService(
        firestore: _firestore,
        auth: _auth,
      );
      await activityService.createFollowActivity(
        followedUserId: targetUserId,
        actorNodeNum: actorNodeNum,
      );
    } catch (e) {
      // Don't fail the follow if activity creation fails
      AppLogging.social('Failed to create follow activity: $e');
    }

    return 'followed';
  }

  /// Create a follow request for a private account.
  Future<void> _createFollowRequest(
    String targetUserId, {
    int? actorNodeNum,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to send follow requests');
    }

    final requestId = '${currentUserId}_$targetUserId';
    final request = FollowRequest(
      id: requestId,
      requesterId: currentUserId,
      targetId: targetUserId,
      status: FollowRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('follow_requests')
        .doc(requestId)
        .set(request.toFirestore());

    // Create activity for target user (they received a follow request)
    try {
      final activityService = SocialActivityService(
        firestore: _firestore,
        auth: _auth,
      );
      await activityService.createFollowRequestActivity(
        targetUserId: targetUserId,
        actorNodeNum: actorNodeNum,
      );
    } catch (e) {
      AppLogging.social('Failed to create follow request activity: $e');
    }
  }

  /// Send a follow request to a private account.
  Future<void> sendFollowRequest(String targetUserId) async {
    await _createFollowRequest(targetUserId);
  }

  /// Cancel a pending follow request.
  Future<void> cancelFollowRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to cancel follow requests');
    }

    final requestId = '${currentUserId}_$targetUserId';
    await _firestore.collection('follow_requests').doc(requestId).delete();
  }

  /// Accept a follow request (creates follow and deletes request).
  /// Creates activity for the requester to notify them their request was accepted.
  Future<void> acceptFollowRequest(
    String requesterId, {
    int? actorNodeNum,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to accept follow requests');
    }

    final requestId = '${requesterId}_$currentUserId';
    final followId = '${requesterId}_$currentUserId';

    // Use a batch to ensure atomicity
    final batch = _firestore.batch();

    // Create the follow relationship
    final follow = Follow(
      id: followId,
      followerId: requesterId,
      followeeId: currentUserId,
      createdAt: DateTime.now(),
    );
    batch.set(
      _firestore.collection('follows').doc(followId),
      follow.toFirestore(),
    );

    // Delete the follow request
    batch.delete(_firestore.collection('follow_requests').doc(requestId));

    await batch.commit();

    // Create activity for the requester (they now follow you, so notify them)
    // This shows as "X started following you" for the requester
    try {
      final activityService = SocialActivityService(
        firestore: _firestore,
        auth: _auth,
      );
      await activityService.createFollowActivity(
        followedUserId: requesterId,
        actorNodeNum: actorNodeNum,
      );
    } catch (e) {
      // Don't fail the accept if activity creation fails
      AppLogging.social('Failed to create follow activity on accept: $e');
    }
  }

  /// Decline a follow request.
  Future<void> declineFollowRequest(String requesterId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to decline follow requests');
    }

    final requestId = '${requesterId}_$currentUserId';
    await _firestore.collection('follow_requests').doc(requestId).delete();
  }

  /// Check if current user has a pending follow request to target.
  Future<bool> hasPendingFollowRequest(String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final requestId = '${currentUserId}_$targetUserId';
    final doc = await _firestore
        .collection('follow_requests')
        .doc(requestId)
        .get();
    return doc.exists && doc.data()?['status'] == 'pending';
  }

  /// Stream of pending follow request status for a target user.
  Stream<bool> watchFollowRequestStatus(String targetUserId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value(false);
    }

    final requestId = '${currentUserId}_$targetUserId';
    return _firestore
        .collection('follow_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists && doc.data()?['status'] == 'pending')
        .handleError((Object e) {
          AppLogging.social('Follow request status stream error: $e');
        });
  }

  /// Get pending follow requests for the current user (requests TO approve).
  Future<PaginatedResult<FollowRequestWithProfile>> getPendingFollowRequests({
    int limit = 20,
    String? startAfterId,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to get follow requests');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('follow_requests')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await _firestore
          .collection('follow_requests')
          .doc(startAfterId)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final items = await Future.wait(
      snapshot.docs.map((doc) async {
        final request = FollowRequest.fromFirestore(doc);
        final profile = await _getPublicProfile(request.requesterId);
        return FollowRequestWithProfile(request: request, profile: profile);
      }),
    );

    return PaginatedResult(
      items: items,
      hasMore: snapshot.docs.length == limit,
      lastId: snapshot.docs.lastOrNull?.id,
    );
  }

  /// Stream of pending follow requests count for the current user.
  Stream<int> watchPendingFollowRequestsCount() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('follow_requests')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((Object e) {
          AppLogging.social('Pending follow requests count stream error: $e');
        });
  }

  /// Stream of pending follow requests for the current user.
  Stream<List<FollowRequestWithProfile>> watchPendingFollowRequests() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('follow_requests')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
          final items = await Future.wait(
            snapshot.docs.map((doc) async {
              final request = FollowRequest.fromFirestore(doc);
              final profile = await _getPublicProfile(request.requesterId);
              return FollowRequestWithProfile(
                request: request,
                profile: profile,
              );
            }),
          );
          return items;
        })
        .handleError((Object e) {
          AppLogging.social('Pending follow requests stream error: $e');
        });
  }

  /// Update current user's account privacy setting.
  Future<void> setAccountPrivacy(bool isPrivate) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to update privacy settings');
    }

    await _firestore.collection('profiles').doc(currentUserId).update({
      'isPrivate': isPrivate,
    });
  }

  /// Remove a follower from the current user's followers list.
  Future<void> removeFollower(String followerId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to remove followers');
    }

    final followId = '${followerId}_$currentUserId';
    await _firestore.collection('follows').doc(followId).delete();
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
        .map((doc) => doc.exists)
        .handleError((Object e) {
          AppLogging.social('Follow status stream error: $e');
        });
  }

  /// Batch check if current user follows multiple target users.
  /// Returns a map of targetUserId -> isFollowing.
  /// Much more efficient than calling isFollowing() for each user individually.
  Future<Map<String, bool>> batchIsFollowing(List<String> targetUserIds) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return {for (final id in targetUserIds) id: false};
    }

    if (targetUserIds.isEmpty) return {};

    // Firestore 'in' queries limited to 30 items, batch if needed
    final results = <String, bool>{};
    final batches = <List<String>>[];

    for (var i = 0; i < targetUserIds.length; i += 30) {
      batches.add(
        targetUserIds.sublist(
          i,
          i + 30 > targetUserIds.length ? targetUserIds.length : i + 30,
        ),
      );
    }

    for (final batch in batches) {
      // Create document IDs for this batch
      final docIds = batch.map((id) => '${currentUserId}_$id').toList();

      // Fetch all documents in parallel using getAll
      final docs = await Future.wait(
        docIds.map(
          (docId) => _firestore.collection('follows').doc(docId).get(),
        ),
      );

      for (var i = 0; i < batch.length; i++) {
        results[batch[i]] = docs[i].exists;
      }
    }

    return results;
  }

  /// Batch check if current user has pending follow requests to multiple users.
  Future<Map<String, bool>> batchHasPendingRequests(
    List<String> targetUserIds,
  ) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return {for (final id in targetUserIds) id: false};
    }

    if (targetUserIds.isEmpty) return {};

    final results = <String, bool>{};
    final batches = <List<String>>[];

    for (var i = 0; i < targetUserIds.length; i += 30) {
      batches.add(
        targetUserIds.sublist(
          i,
          i + 30 > targetUserIds.length ? targetUserIds.length : i + 30,
        ),
      );
    }

    for (final batch in batches) {
      final docIds = batch.map((id) => '${currentUserId}_$id').toList();

      final docs = await Future.wait(
        docIds.map(
          (docId) => _firestore.collection('follow_requests').doc(docId).get(),
        ),
      );

      for (var i = 0; i < batch.length; i++) {
        final doc = docs[i];
        results[batch[i]] = doc.exists && doc.data()?['status'] == 'pending';
      }
    }

    return results;
  }

  /// Subscribe current user to an author's signals
  Future<void> subscribeToAuthorSignals(String authorId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to subscribe');
    }

    final docRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('signalSubscriptions')
        .doc(authorId);

    final batch = _firestore.batch();
    batch.set(docRef, {
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also write mirror doc for fast lookup by author
    final mirrorRef = _firestore
        .collection('signal_subscribers')
        .doc(authorId)
        .collection('subscribers')
        .doc(currentUserId);

    batch.set(mirrorRef, {
      'subscriberId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Unsubscribe current user from an author's signals
  Future<void> unsubscribeFromAuthorSignals(String authorId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unsubscribe');
    }

    final batch = _firestore.batch();
    batch.delete(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('signalSubscriptions')
          .doc(authorId),
    );

    batch.delete(
      _firestore
          .collection('signal_subscribers')
          .doc(authorId)
          .collection('subscribers')
          .doc(currentUserId),
    );

    await batch.commit();
  }

  /// Check if current user is subscribed to an author's signals
  Future<bool> isSubscribedToAuthorSignals(String authorId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('signalSubscriptions')
        .doc(authorId)
        .get();

    return doc.exists;
  }

  /// Watch subscription status for the current user to an author
  Stream<bool> watchSignalSubscription(String authorId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('signalSubscriptions')
        .doc(authorId)
        .snapshots()
        .map((doc) => doc.exists)
        .handleError((Object e) {
          AppLogging.social('Signal subscription stream error: $e');
        });
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
  // USER SEARCH
  // ===========================================================================

  /// Search for users by display name or callsign.
  /// Returns paginated list of public profiles matching the query.
  Future<PaginatedResult<PublicProfile>> searchUsers(
    String query, {
    int limit = 20,
    String? startAfterId,
  }) async {
    if (query.trim().isEmpty) {
      return PaginatedResult(items: [], hasMore: false);
    }

    final queryLower = query.toLowerCase().trim();

    // Search by displayName (case-insensitive prefix search)
    // Note: Firestore doesn't support true case-insensitive search,
    // so we use a searchable field that stores lowercase version
    Query<Map<String, dynamic>> nameQuery = _firestore
        .collection('profiles')
        .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
        .where('displayNameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(limit);

    final nameSnapshot = await nameQuery.get();

    // Also search by callsign
    Query<Map<String, dynamic>> callsignQuery = _firestore
        .collection('profiles')
        .where('callsignLower', isGreaterThanOrEqualTo: queryLower)
        .where('callsignLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(limit);

    final callsignSnapshot = await callsignQuery.get();

    // Combine results and remove duplicates
    final seenIds = <String>{};
    final items = <PublicProfile>[];

    for (final doc in [...nameSnapshot.docs, ...callsignSnapshot.docs]) {
      if (!seenIds.contains(doc.id)) {
        seenIds.add(doc.id);
        items.add(PublicProfile.fromFirestore(doc));
      }
    }

    // Sort by relevance (exact match first, then alphabetically)
    items.sort((a, b) {
      final aName = a.displayName.toLowerCase();
      final bName = b.displayName.toLowerCase();
      final aExact =
          aName == queryLower || a.callsign?.toLowerCase() == queryLower;
      final bExact =
          bName == queryLower || b.callsign?.toLowerCase() == queryLower;

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return aName.compareTo(bName);
    });

    return PaginatedResult(
      items: items.take(limit).toList(),
      hasMore: items.length > limit,
      lastId: items.lastOrNull?.id,
    );
  }

  /// Get suggested users to follow (users the current user doesn't follow yet).
  /// Returns popular users or users followed by the current user's connections.
  Future<List<PublicProfile>> getSuggestedUsers({int limit = 10}) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      // Return popular users for logged-out state
      return _getPopularUsers(limit: limit);
    }

    // Get users the current user already follows
    final followingSnapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .get();

    final followingIds = followingSnapshot.docs
        .map((doc) => doc.data()['followeeId'] as String)
        .toSet();
    followingIds.add(currentUserId); // Exclude self

    // Get popular users that the current user doesn't follow
    final popularUsers = await _getPopularUsers(
      limit: limit + followingIds.length,
    );

    return popularUsers
        .where((user) => !followingIds.contains(user.id))
        .take(limit)
        .toList();
  }

  /// Get popular users by follower count.
  Future<List<PublicProfile>> _getPopularUsers({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('profiles')
        .orderBy('followerCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => PublicProfile.fromFirestore(doc))
        .toList();
  }

  /// Get recently active users.
  Future<List<PublicProfile>> getRecentlyActiveUsers({int limit = 10}) async {
    // Get users who have posted recently
    final postsSnapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .get();

    final authorIds = postsSnapshot.docs
        .map((doc) => doc.data()['authorId'] as String)
        .toSet()
        .take(limit)
        .toList();

    if (authorIds.isEmpty) {
      return _getPopularUsers(limit: limit);
    }

    // Fetch profiles for these users
    final profiles = <PublicProfile>[];
    for (final authorId in authorIds) {
      final profile = await _getPublicProfile(authorId);
      if (profile != null) {
        profiles.add(profile);
      }
    }

    return profiles;
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
    int? actorNodeNum,
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
            nodeNum: profile.primaryNodeId,
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

    // Create the post - Cloud Functions handle postCount increment
    await docRef.set(data);

    // Parse and notify mentions in the post content
    final activityService = SocialActivityService(
      firestore: _firestore,
      auth: _auth,
    );
    await _processMentions(content, post.id, activityService, actorNodeNum);

    return post;
  }

  /// Delete a post. Only the author can delete.
  Future<void> deletePost(String postId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to delete posts');
    }

    final postRef = _firestore.collection('posts').doc(postId);

    // Verify ownership before deleting
    final doc = await postRef.get();
    if (!doc.exists) {
      throw StateError('Post not found');
    }
    if (doc.data()?['authorId'] != currentUserId) {
      throw StateError('Only the author can delete this post');
    }

    // Delete post - Cloud Functions handle postCount decrement
    await postRef.delete();
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
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return null;
          final post = Post.fromFirestore(doc);
          // Enrich with author data if missing
          final enriched = await _enrichPostsWithAuthors([post]);
          return enriched.first;
        })
        .handleError((Object e) {
          AppLogging.social('Post watch stream error: $e');
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
        })
        .handleError((Object e) {
          AppLogging.social('User posts stream error: $e');
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
        })
        .handleError((Object e) {
          AppLogging.social('Explore posts stream error: $e');
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
          nodeNum: profile.primaryNodeId,
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
        )
        .handleError((Object e) {
          AppLogging.social('Feed stream error: $e');
        });
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
    int? actorNodeNum,
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

    final activityService = SocialActivityService(
      firestore: _firestore,
      auth: _auth,
    );
    final preview = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;

    if (parentId == null) {
      // Root comment - notify post owner
      try {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data()!;
          final postOwnerId = postData['authorId'] as String?;

          if (postOwnerId != null && postOwnerId != currentUserId) {
            await activityService.createCommentActivity(
              postId: postId,
              postOwnerId: postOwnerId,
              commentPreview: preview,
              actorNodeNum: actorNodeNum,
            );
          }
        }
      } catch (e) {
        AppLogging.social('Failed to create comment activity: $e');
      }
    } else {
      // Reply - notify original comment author
      try {
        final parentCommentDoc = await _firestore
            .collection('comments')
            .doc(parentId)
            .get();
        if (parentCommentDoc.exists) {
          final parentData = parentCommentDoc.data()!;
          final originalAuthorId = parentData['authorId'] as String?;

          if (originalAuthorId != null && originalAuthorId != currentUserId) {
            await activityService.createCommentReplyActivity(
              postId: postId,
              originalCommentAuthorId: originalAuthorId,
              replyPreview: preview,
              actorNodeNum: actorNodeNum,
            );
          }
        }
      } catch (e) {
        AppLogging.social('Failed to create comment reply activity: $e');
      }
    }

    // Parse and notify mentions in the comment
    await _processMentions(content, postId, activityService, actorNodeNum);

    return comment;
  }

  /// Parse @mentions from text and create activities for mentioned users
  Future<void> _processMentions(
    String content,
    String postId,
    SocialActivityService activityService,
    int? actorNodeNum,
  ) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Match @username patterns (alphanumeric and underscores)
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);

    for (final match in matches) {
      final username = match.group(1);
      if (username == null) continue;

      try {
        // Look up user by displayName (case-insensitive)
        final userQuery = await _firestore
            .collection('profiles')
            .where('displayNameLower', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final mentionedUserId = userQuery.docs.first.id;

          // Don't notify yourself
          if (mentionedUserId != currentUserId) {
            final preview = content.length > 100
                ? '${content.substring(0, 100)}...'
                : content;

            await activityService.createMentionActivity(
              mentionedUserId: mentionedUserId,
              contentId: postId,
              textContent: preview,
              actorNodeNum: actorNodeNum,
            );
          }
        }
      } catch (e) {
        AppLogging.social('Failed to process mention @$username: $e');
      }
    }
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
        })
        .handleError((Object e) {
          AppLogging.social('Comments stream error: $e');
        });
  }

  // ===========================================================================
  // LIKES
  // ===========================================================================

  /// Like a post. Creates a like document with composite ID.
  /// Also creates an activity for the post owner.
  Future<void> likePost(String postId, {int? actorNodeNum}) async {
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

    // Create activity for post owner
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final postData = postDoc.data()!;
        final postOwnerId = postData['authorId'] as String?;
        final mediaUrls = postData['mediaUrls'] as List<dynamic>?;
        final thumbnailUrl = mediaUrls?.isNotEmpty == true
            ? mediaUrls!.first as String
            : null;

        if (postOwnerId != null && postOwnerId != currentUserId) {
          final activityService = SocialActivityService(
            firestore: _firestore,
            auth: _auth,
          );

          // If this post is a signal, create a signal-like activity so it maps correctly
          final postMode = postData['postMode'] as String?;
          if (postMode == 'signal') {
            await activityService.createSignalLikeActivity(
              signalId: postId,
              signalOwnerId: postOwnerId,
              signalThumbnailUrl: thumbnailUrl,
              actorNodeNum: actorNodeNum,
            );
          } else {
            await activityService.createPostLikeActivity(
              postId: postId,
              postOwnerId: postOwnerId,
              postThumbnailUrl: thumbnailUrl,
              actorNodeNum: actorNodeNum,
            );
          }
        }
      }
    } catch (e) {
      // Don't fail the like if activity creation fails
      AppLogging.social('Failed to create post like activity: $e');
    }
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

  /// Like a comment. Creates a like document and activity.
  Future<void> likeComment(String commentId, {int? actorNodeNum}) async {
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

    // Create activity for comment author
    try {
      final commentDoc = await _firestore
          .collection('comments')
          .doc(commentId)
          .get();
      if (commentDoc.exists) {
        final commentData = commentDoc.data()!;
        final commentAuthorId = commentData['authorId'] as String?;
        final postId = commentData['postId'] as String?;

        if (commentAuthorId != null &&
            commentAuthorId != currentUserId &&
            postId != null) {
          final activityService = SocialActivityService(
            firestore: _firestore,
            auth: _auth,
          );
          await activityService.createCommentLikeActivity(
            postId: postId,
            commentAuthorId: commentAuthorId,
            actorNodeNum: actorNodeNum,
          );
        }
      }
    } catch (e) {
      AppLogging.social('Failed to create comment like activity: $e');
    }
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
        .map((doc) => doc.exists)
        .handleError((Object e) {
          AppLogging.social('Like status stream error: $e');
        });
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
        )
        .handleError((Object e) {
          AppLogging.social('Pending reports stream error: $e');
        });
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
    } else if (type == 'story') {
      await _firestore.collection('stories').doc(targetId).delete();
    }

    // Mark report as resolved
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'deleted',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _currentUserId,
    });
  }

  // ===========================================================================
  // AUTO-MODERATION QUEUE
  // ===========================================================================

  /// Get all pending auto-moderated content (admin only).
  Stream<List<Map<String, dynamic>>> watchModerationQueue() {
    return _firestore
        .collection('moderation_queue')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList(),
        )
        .handleError((Object e) {
          AppLogging.social('Moderation queue stream error: $e');
        });
  }

  /// Approve content from moderation queue (admin only).
  /// This keeps the content visible and removes it from the queue.
  /// Uses Cloud Function for proper permissions.
  Future<void> approveModerationItem(String itemId) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('reviewModerationItem');
    await callable.call<dynamic>({'itemId': itemId, 'action': 'approve'});
  }

  /// Reject content from moderation queue and delete it (admin only).
  /// Uses Cloud Function for proper permissions and strike recording.
  Future<void> rejectModerationItem(String itemId) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('reviewModerationItem');
    await callable.call<dynamic>({
      'itemId': itemId,
      'action': 'reject',
      'notes': 'Content violated community guidelines',
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
      var displayName =
          userProfileDisplayName ??
          user.displayName ??
          user.email?.split('@').first ??
          'User';
      final avatarUrl = userProfileAvatarUrl ?? user.photoURL;

      // Ensure display name is unique - append numbers if taken
      displayName = await _generateUniqueDisplayName(displayName, user.uid);

      await docRef.set({
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
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
        // Check if the new display name is available before syncing
        final isTaken = await isDisplayNameTaken(
          userProfileDisplayName,
          user.uid,
        );
        if (!isTaken) {
          // Sync the displayName from users collection to profiles collection
          final updates = <String, dynamic>{
            'displayName': userProfileDisplayName,
            'displayNameLower': userProfileDisplayName.toLowerCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          // Also sync avatar if users collection has one
          if (userProfileAvatarUrl != null && userProfileAvatarUrl.isNotEmpty) {
            updates['avatarUrl'] = userProfileAvatarUrl;
          }
          await docRef.update(updates);
        }
        // If taken, silently skip - user will need to choose a different name manually
      }
    }
  }

  /// Get a user's public profile.
  Future<PublicProfile?> getPublicProfile(String userId) async {
    AppLogging.auth('Social: getPublicProfile() called for userId=$userId');
    return _getPublicProfile(userId);
  }

  /// Find a user by their linked mesh node ID.
  /// Returns null if no user has this node in their linkedNodeIds.
  Future<PublicProfile?> getProfileByNodeId(int nodeId) async {
    AppLogging.auth('Social: getProfileByNodeId() - START for nodeId=$nodeId');
    try {
      // Query using array-contains on linkedNodeIds
      final query = await _firestore
          .collection('profiles')
          .where('linkedNodeIds', arrayContains: nodeId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppLogging.auth(
          'Social: getProfileByNodeId() - ❌ No profile found for nodeId=$nodeId',
        );
        return null;
      }
      final profile = PublicProfile.fromFirestore(query.docs.first);
      AppLogging.auth(
        'Social: getProfileByNodeId() - ✅ Found: userId=${profile.id}, displayName=${profile.displayName}',
      );
      return profile;
    } catch (e) {
      AppLogging.auth('Social: getProfileByNodeId() - ❌ ERROR: $e');
      return null;
    }
  }

  /// Link a mesh node to the current user's profile.
  /// If setPrimary is true, also sets it as the primary node.
  /// Optionally caches node metadata (longName, shortName, avatarColor) for display.
  Future<void> linkNodeToProfile(
    int nodeId, {
    bool setPrimary = false,
    String? longName,
    String? shortName,
    int? avatarColor,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to link nodes');
    }

    await ensureProfileExists();

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw StateError('Profile does not exist');
    }

    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    // Add node if not already linked
    if (!currentLinkedNodes.contains(nodeId)) {
      currentLinkedNodes.add(nodeId);
    }

    final updates = <String, dynamic>{
      'linkedNodeIds': currentLinkedNodes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Also update primary if requested or if this is the first node
    if (setPrimary || currentLinkedNodes.length == 1) {
      updates['primaryNodeId'] = nodeId;
    }

    // Store node metadata for display when node isn't in local cache
    if (longName != null || shortName != null || avatarColor != null) {
      final nodeIdKey = nodeId.toString();
      updates['linkedNodeMetadata.$nodeIdKey'] = {
        'nodeId': nodeId,
        if (longName != null) 'longName': longName,
        if (shortName != null) 'shortName': shortName,
        if (avatarColor != null) 'avatarColor': avatarColor,
      };
    }

    await docRef.update(updates);
  }

  /// Update cached metadata for a linked node.
  Future<void> updateLinkedNodeMetadata(
    int nodeId, {
    String? longName,
    String? shortName,
    int? avatarColor,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final nodeIdKey = nodeId.toString();

    await docRef.update({
      'linkedNodeMetadata.$nodeIdKey': {
        'nodeId': nodeId,
        if (longName != null) 'longName': longName,
        if (shortName != null) 'shortName': shortName,
        if (avatarColor != null) 'avatarColor': avatarColor,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unlink a mesh node from the current user's profile.
  Future<void> unlinkNodeFromProfile(int nodeId) async {
    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Starting for nodeId: $nodeId',
    );

    final currentUserId = _currentUserId;
    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] currentUserId: $currentUserId',
    );
    if (currentUserId == null) {
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] ERROR: Not signed in',
      );
      throw StateError('Must be signed in to unlink nodes');
    }

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Fetching profile doc...',
    );
    final doc = await docRef.get();

    if (!doc.exists) {
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] Profile doc does not exist, returning early',
      );
      return;
    }

    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Profile doc exists, parsing data...',
    );
    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    final currentPrimaryId = doc.data()?['primaryNodeId'] as int?;
    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Current state: '
      'linkedNodes=$currentLinkedNodes, primaryId=$currentPrimaryId',
    );

    // Remove the node
    final removed = currentLinkedNodes.remove(nodeId);
    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Removed nodeId $nodeId: $removed, '
      'remaining: $currentLinkedNodes',
    );

    final updates = <String, dynamic>{
      'linkedNodeIds': currentLinkedNodes,
      'updatedAt': FieldValue.serverTimestamp(),
      // Remove the cached metadata for this node
      'linkedNodeMetadata.${nodeId.toString()}': FieldValue.delete(),
    };

    // If we removed the primary node, set a new one or clear it
    if (currentPrimaryId == nodeId) {
      updates['primaryNodeId'] = currentLinkedNodes.isNotEmpty
          ? currentLinkedNodes.first
          : null;
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] Primary node removed, '
        'new primary: ${updates['primaryNodeId']}',
      );
    }

    AppLogging.social(
      '🔗 [SocialService.unlinkNodeFromProfile] Updating Firestore with: $updates',
    );
    try {
      await docRef.update(updates);
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] Firestore update SUCCESS',
      );
    } catch (e, stackTrace) {
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] Firestore update FAILED: $e',
      );
      AppLogging.social(
        '🔗 [SocialService.unlinkNodeFromProfile] Stack trace: $stackTrace',
      );
      rethrow;
    }
  }

  /// Set a linked node as the primary node.
  Future<void> setPrimaryNode(int nodeId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to set primary node');
    }

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw StateError('Profile does not exist');
    }

    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    // Only allow setting primary if node is already linked
    if (!currentLinkedNodes.contains(nodeId)) {
      throw ArgumentError('Node must be linked before setting as primary');
    }

    await docRef.update({
      'primaryNodeId': nodeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get the current user's linked node IDs.
  Future<List<int>> getLinkedNodeIds() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    final doc = await _firestore
        .collection('profiles')
        .doc(currentUserId)
        .get();
    if (!doc.exists) return [];

    return (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
  }

  /// Check if current user has a specific node linked.
  Future<bool> isNodeLinked(int nodeId) async {
    final linkedNodes = await getLinkedNodeIds();
    return linkedNodes.contains(nodeId);
  }

  /// Watch the current user's linked node IDs with real-time updates.
  Stream<List<int>> watchLinkedNodeIds() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('profiles')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <int>[];
          return (doc.data()?['linkedNodeIds'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              <int>[];
        })
        .handleError((Object e) {
          AppLogging.social('Linked node IDs stream error: $e');
        });
  }

  /// Stream a user's public profile with real-time updates from server.
  Stream<PublicProfile?> watchPublicProfile(String userId) {
    return _firestore
        .collection('profiles')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return PublicProfile.fromFirestore(doc);
        })
        .handleError((Object e) {
          AppLogging.social('Public profile stream error: $e');
        });
  }

  /// Update the current user's public profile.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? callsign,
    String? avatarUrl,
    String? website,
    ProfileSocialLinks? socialLinks,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to update profile');
    }

    // Ensure profile exists first
    await ensureProfileExists();

    // Check display name uniqueness if being changed
    if (displayName != null && displayName.isNotEmpty) {
      final isTaken = await isDisplayNameTaken(displayName, currentUserId);
      if (isTaken) {
        throw DisplayNameTakenException(displayName);
      }
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Always include displayName if provided (even if same as before)
    if (displayName != null && displayName.isNotEmpty) {
      updates['displayName'] = displayName;
      updates['displayNameLower'] = displayName.toLowerCase();
    }
    // Bio can be empty string to clear it
    if (bio != null) updates['bio'] = bio.isEmpty ? null : bio;
    // Callsign can be null to clear it
    if (callsign != null) {
      updates['callsign'] = callsign.isEmpty ? null : callsign;
      updates['callsignLower'] = callsign.isEmpty
          ? null
          : callsign.toLowerCase();
    }
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    // Website can be null to clear it
    if (website != null) {
      updates['website'] = website.isEmpty ? null : website;
    }
    // Social links
    if (socialLinks != null) {
      if (socialLinks.isEmpty) {
        updates['socialLinks'] = null;
      } else {
        updates['socialLinks'] = socialLinks.toJson();
      }
    }

    AppLogging.social('SocialService.updateProfile: updating with $updates');
    await _firestore.collection('profiles').doc(currentUserId).update(updates);
  }

  /// Check if a display name is already taken by another user.
  /// Returns true if the name is taken, false if available.
  Future<bool> isDisplayNameTaken(
    String displayName, [
    String? excludeUserId,
  ]) async {
    final normalizedName = displayName.trim().toLowerCase();
    if (normalizedName.isEmpty) return false;

    // Query for profiles with this display name (case-insensitive via lowercase field)
    // We store displayNameLower for efficient querying
    final query = await _firestore
        .collection('profiles')
        .where('displayNameLower', isEqualTo: normalizedName)
        .limit(2) // Only need to find one other user
        .get();

    // Check if any results belong to a different user
    for (final doc in query.docs) {
      if (excludeUserId == null || doc.id != excludeUserId) {
        return true; // Found another user with this name
      }
    }
    return false;
  }

  /// Generate a unique display name by appending numbers if the base name is taken.
  /// Sanitizes the name to match validation rules (no spaces, valid chars only).
  Future<String> _generateUniqueDisplayName(
    String baseName,
    String excludeUserId,
  ) async {
    // Sanitize: replace spaces with underscores, remove invalid chars
    var sanitized = baseName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');

    // Ensure not empty and meets minimum length
    if (sanitized.length < 2) {
      sanitized = 'user_$sanitized';
    }

    // Truncate to leave room for numbers (max 30 chars)
    if (sanitized.length > 25) {
      sanitized = sanitized.substring(0, 25);
    }

    // Check if base name is available
    if (!await isDisplayNameTaken(sanitized, excludeUserId)) {
      return sanitized;
    }

    // Try appending numbers until we find an available name
    for (var i = 1; i < 1000; i++) {
      final candidate = '$sanitized$i';
      if (!await isDisplayNameTaken(candidate, excludeUserId)) {
        return candidate;
      }
    }

    // Fallback: use timestamp-based unique name
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
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

    // Get the post to include context in the report
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    Map<String, dynamic>? context;
    if (postDoc.exists) {
      final postData = postDoc.data()!;
      context = {
        'content': postData['content'],
        'authorId': postData['authorId'],
        'imageUrl': postData['imageUrl'],
      };
    }

    await _firestore.collection('reports').add({
      'type': 'post',
      'targetId': postId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      if (context != null) 'context': context,
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

  /// Report a signal for moderation.
  Future<void> reportSignal({
    required String signalId,
    required String reason,
    String? authorId,
    String? content,
    String? imageUrl,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to report signals');
    }

    await _firestore.collection('reports').add({
      'type': 'signal',
      'targetId': signalId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'context': {
        if (authorId != null) 'authorId': authorId,
        if (content != null) 'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    });
  }

  /// Report a story for moderation.
  Future<void> reportStory({
    required String storyId,
    required String authorId,
    required String reason,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to report stories');
    }

    await _firestore.collection('reports').add({
      'type': 'story',
      'targetId': storyId,
      'reporterId': currentUserId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'context': {
        'authorId': authorId,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
      },
    });
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  Future<PublicProfile?> _getPublicProfile(String userId) async {
    AppLogging.auth('Social: _getPublicProfile() - START for userId=$userId');
    // Try server first for fresh data, fall back to cache
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      AppLogging.auth('Social: _getPublicProfile() - Fetching from server...');
      doc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      AppLogging.auth('Social: _getPublicProfile() - Server fetch complete');
    } catch (e) {
      // Server fetch failed, try cache
      AppLogging.auth(
        'Social: _getPublicProfile() - Server failed ($e), trying cache...',
      );
      doc = await _firestore.collection('profiles').doc(userId).get();
    }
    if (!doc.exists) {
      AppLogging.auth(
        'Social: _getPublicProfile() - ❌ PROFILE NOT FOUND for userId=$userId',
      );
      return null;
    }
    final profile = PublicProfile.fromFirestore(doc);
    AppLogging.auth(
      'Social: _getPublicProfile() - ✅ Found: displayName=${profile.displayName}, isVerified=${profile.isVerified}',
    );
    return profile;
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

/// Exception thrown when a display name is already taken.
class DisplayNameTakenException implements Exception {
  DisplayNameTakenException(this.displayName);

  final String displayName;

  @override
  String toString() =>
      'The display name "$displayName" is already taken. Please choose a different name.';
}
