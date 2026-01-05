/**
 * Socialmesh Social Features Cloud Functions
 *
 * Handles:
 * - Follow system with counters
 * - Posts with fan-out to follower feeds
 * - Comments with threading
 * - Likes
 */

import * as admin from 'firebase-admin';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';

const db = admin.firestore();
const storage = admin.storage();
const FieldValue = admin.firestore.FieldValue;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

/**
 * Verify Firebase Auth token from Authorization header.
 * Exported for potential use in protected social endpoints.
 */
export async function verifyAuth(authHeader: string | undefined): Promise<admin.auth.DecodedIdToken | null> {
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }
  const token = authHeader.split('Bearer ')[1];
  try {
    return await admin.auth().verifyIdToken(token);
  } catch {
    return null;
  }
}

/**
 * Get a user's public profile from the profiles collection
 */
async function getPublicProfile(userId: string): Promise<{
  displayName: string;
  avatarUrl?: string;
  callsign?: string;
} | null> {
  const doc = await db.collection('profiles').doc(userId).get();
  if (!doc.exists) return null;
  const data = doc.data()!;
  return {
    displayName: data.displayName || 'Unknown',
    avatarUrl: data.avatarUrl,
    callsign: data.callsign,
  };
}

// =============================================================================
// FOLLOW SYSTEM
// =============================================================================

/**
 * Triggered when a follow relationship is created.
 * Increments followerCount on followee and followingCount on follower.
 */
export const onFollowCreated = onDocumentCreated(
  'follows/{followId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { followerId, followeeId } = data;

    const batch = db.batch();

    // Increment follower count on the person being followed
    batch.update(db.collection('profiles').doc(followeeId), {
      followerCount: FieldValue.increment(1),
    });

    // Increment following count on the person who followed
    batch.update(db.collection('profiles').doc(followerId), {
      followingCount: FieldValue.increment(1),
    });

    await batch.commit();
    console.log(`Follow created: ${followerId} -> ${followeeId}`);
  }
);

/**
 * Triggered when a follow relationship is deleted.
 * Decrements followerCount on followee and followingCount on follower.
 */
export const onFollowDeleted = onDocumentDeleted(
  'follows/{followId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { followerId, followeeId } = data;

    const batch = db.batch();

    // Decrement follower count
    batch.update(db.collection('profiles').doc(followeeId), {
      followerCount: FieldValue.increment(-1),
    });

    // Decrement following count
    batch.update(db.collection('profiles').doc(followerId), {
      followingCount: FieldValue.increment(-1),
    });

    await batch.commit();
    console.log(`Follow deleted: ${followerId} -> ${followeeId}`);
  }
);

/**
 * Get followers of a user
 */
export const getFollowers = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const userId = req.query.userId as string;
    const limitNum = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const startAfter = req.query.startAfter as string | undefined;

    if (!userId) {
      res.status(400).json({ error: 'userId required' });
      return;
    }

    let query = db.collection('follows')
      .where('followeeId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limitNum);

    if (startAfter) {
      const startDoc = await db.collection('follows').doc(startAfter).get();
      if (startDoc.exists) {
        query = query.startAfter(startDoc);
      }
    }

    const snapshot = await query.get();
    const followers = await Promise.all(
      snapshot.docs.map(async (doc) => {
        const profile = await getPublicProfile(doc.data().followerId);
        return {
          id: doc.id,
          followerId: doc.data().followerId,
          createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
          profile,
        };
      })
    );

    res.json({
      followers,
      hasMore: snapshot.docs.length === limitNum,
      lastId: snapshot.docs[snapshot.docs.length - 1]?.id,
    });
  } catch (error) {
    console.error('getFollowers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get users that a user follows
 */
export const getFollowing = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const userId = req.query.userId as string;
    const limitNum = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const startAfter = req.query.startAfter as string | undefined;

    if (!userId) {
      res.status(400).json({ error: 'userId required' });
      return;
    }

    let query = db.collection('follows')
      .where('followerId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limitNum);

    if (startAfter) {
      const startDoc = await db.collection('follows').doc(startAfter).get();
      if (startDoc.exists) {
        query = query.startAfter(startDoc);
      }
    }

    const snapshot = await query.get();
    const following = await Promise.all(
      snapshot.docs.map(async (doc) => {
        const profile = await getPublicProfile(doc.data().followeeId);
        return {
          id: doc.id,
          followeeId: doc.data().followeeId,
          createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
          profile,
        };
      })
    );

    res.json({
      following,
      hasMore: snapshot.docs.length === limitNum,
      lastId: snapshot.docs[snapshot.docs.length - 1]?.id,
    });
  } catch (error) {
    console.error('getFollowing error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get mutual follows (users who both follow each other)
 */
export const getMutualFollows = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const userId = req.query.userId as string;
    const limitNum = Math.min(parseInt(req.query.limit as string) || 50, 100);

    if (!userId) {
      res.status(400).json({ error: 'userId required' });
      return;
    }

    // Get users this person follows
    const followingSnap = await db.collection('follows')
      .where('followerId', '==', userId)
      .get();

    const followingIds = new Set(followingSnap.docs.map(d => d.data().followeeId));

    // Get users who follow this person
    const followersSnap = await db.collection('follows')
      .where('followeeId', '==', userId)
      .get();

    const followerIds = followersSnap.docs.map(d => d.data().followerId);

    // Find mutual (intersection)
    const mutualIds = followerIds.filter(id => followingIds.has(id)).slice(0, limitNum);

    // Get profiles for mutual follows
    const mutuals = await Promise.all(
      mutualIds.map(async (id) => {
        const profile = await getPublicProfile(id);
        return { userId: id, profile };
      })
    );

    res.json({ mutuals, total: mutualIds.length });
  } catch (error) {
    console.error('getMutualFollows error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Check if current user follows a target user
 */
export const checkFollowStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in');
  }

  const { targetUserId } = request.data;
  if (!targetUserId) {
    throw new HttpsError('invalid-argument', 'targetUserId required');
  }

  const followId = `${request.auth.uid}_${targetUserId}`;
  const doc = await db.collection('follows').doc(followId).get();

  return { isFollowing: doc.exists };
});

// =============================================================================
// POSTS & FEED FAN-OUT
// =============================================================================

/**
 * Triggered when a new post is created.
 * - Increments postCount on author's profile
 * - Fans out post to all followers' feeds
 */
export const onPostCreated = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const postId = event.params.postId;
    const data = event.data?.data();
    if (!data) return;

    const { authorId, content, mediaUrls, location, nodeId, createdAt } = data;

    // Get author's profile for feed item snapshot
    const authorProfile = await getPublicProfile(authorId);
    if (!authorProfile) {
      console.error(`Author profile not found: ${authorId}`);
      return;
    }

    // Increment post count on author's profile
    await db.collection('profiles').doc(authorId).update({
      postCount: FieldValue.increment(1),
    });

    // Get all followers of the author
    const followersSnap = await db.collection('follows')
      .where('followeeId', '==', authorId)
      .get();

    // Prepare feed item data
    const feedItemData = {
      authorId,
      author: authorProfile,
      content,
      mediaUrls: mediaUrls || [],
      location: location || null,
      nodeId: nodeId || null,
      createdAt,
      commentCount: 0,
      likeCount: 0,
    };

    // Fan out to followers' feeds (batched writes for efficiency)
    const batchSize = 500;
    const followerIds = followersSnap.docs.map(d => d.data().followerId);

    // Also add to author's own feed
    followerIds.push(authorId);

    for (let i = 0; i < followerIds.length; i += batchSize) {
      const batch = db.batch();
      const chunk = followerIds.slice(i, i + batchSize);

      for (const followerId of chunk) {
        const feedRef = db.collection('feeds').doc(followerId).collection('items').doc(postId);
        batch.set(feedRef, feedItemData);
      }

      await batch.commit();
    }

    console.log(`Post ${postId} fanned out to ${followerIds.length} feeds`);
  }
);

/**
 * Triggered when a post is deleted.
 * - Decrements postCount on author's profile
 * - Removes post from all followers' feeds
 * - Deletes all comments on the post
 * - Deletes all images from Storage
 */
export const onPostDeleted = onDocumentDeleted(
  'posts/{postId}',
  async (event) => {
    const postId = event.params.postId;
    const data = event.data?.data();
    if (!data) return;

    const { authorId, mediaUrls } = data;

    // Delete images from Storage
    if (mediaUrls && Array.isArray(mediaUrls) && mediaUrls.length > 0) {
      const bucket = storage.bucket();
      for (const url of mediaUrls) {
        try {
          // Extract file path from URL
          // URL format: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?token=...
          // or gs://BUCKET/PATH
          let filePath: string | null = null;

          if (url.includes('firebasestorage.googleapis.com')) {
            const match = url.match(/\/o\/([^?]+)/);
            if (match) {
              filePath = decodeURIComponent(match[1]);
            }
          } else if (url.startsWith('gs://')) {
            filePath = url.replace(/^gs:\/\/[^/]+\//, '');
          }

          if (filePath) {
            await bucket.file(filePath).delete();
            console.log(`Deleted image: ${filePath}`);
          }
        } catch (err) {
          // Log but don't fail - image might already be deleted
          console.warn(`Failed to delete image ${url}:`, err);
        }
      }
    }

    // Decrement post count
    await db.collection('profiles').doc(authorId).update({
      postCount: FieldValue.increment(-1),
    });

    // Get all followers to remove from their feeds
    const followersSnap = await db.collection('follows')
      .where('followeeId', '==', authorId)
      .get();

    const followerIds = followersSnap.docs.map(d => d.data().followerId);
    followerIds.push(authorId); // Also author's own feed

    // Remove from feeds in batches
    const batchSize = 500;
    for (let i = 0; i < followerIds.length; i += batchSize) {
      const batch = db.batch();
      const chunk = followerIds.slice(i, i + batchSize);

      for (const followerId of chunk) {
        const feedRef = db.collection('feeds').doc(followerId).collection('items').doc(postId);
        batch.delete(feedRef);
      }

      await batch.commit();
    }

    // Delete all comments on this post
    const commentsSnap = await db.collection('comments')
      .where('postId', '==', postId)
      .get();

    for (let i = 0; i < commentsSnap.docs.length; i += batchSize) {
      const batch = db.batch();
      const chunk = commentsSnap.docs.slice(i, i + batchSize);

      for (const doc of chunk) {
        batch.delete(doc.ref);
      }

      await batch.commit();
    }

    // Delete all likes on this post
    const likesSnap = await db.collection('likes')
      .where('postId', '==', postId)
      .get();

    for (let i = 0; i < likesSnap.docs.length; i += batchSize) {
      const batch = db.batch();
      const chunk = likesSnap.docs.slice(i, i + batchSize);

      for (const doc of chunk) {
        batch.delete(doc.ref);
      }

      await batch.commit();
    }

    const imageCount = mediaUrls?.length || 0;
    console.log(`Post ${postId} deleted: removed from feeds, deleted ${commentsSnap.size} comments, ${likesSnap.size} likes, ${imageCount} images`);
  }
);

/**
 * Get a user's feed with pagination
 */
export const getFeed = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in');
  }

  const userId = request.auth.uid;
  const limitNum = Math.min(request.data.limit || 20, 50);
  const startAfterTimestamp = request.data.startAfter;

  let query = db.collection('feeds').doc(userId).collection('items')
    .orderBy('createdAt', 'desc')
    .limit(limitNum);

  if (startAfterTimestamp) {
    const startTime = new admin.firestore.Timestamp(
      Math.floor(startAfterTimestamp / 1000),
      (startAfterTimestamp % 1000) * 1000000
    );
    query = query.startAfter(startTime);
  }

  const snapshot = await query.get();

  const items = snapshot.docs.map(doc => {
    const data = doc.data();
    return {
      postId: doc.id,
      authorId: data.authorId,
      author: data.author,
      content: data.content,
      mediaUrls: data.mediaUrls || [],
      location: data.location,
      nodeId: data.nodeId,
      createdAt: data.createdAt?.toMillis?.() || null,
      commentCount: data.commentCount || 0,
      likeCount: data.likeCount || 0,
    };
  });

  return {
    items,
    hasMore: snapshot.docs.length === limitNum,
    lastTimestamp: items[items.length - 1]?.createdAt,
  };
});

/**
 * Get posts by a specific user
 */
export const getUserPosts = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const userId = req.query.userId as string;
    const limitNum = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const startAfter = req.query.startAfter as string | undefined;

    if (!userId) {
      res.status(400).json({ error: 'userId required' });
      return;
    }

    let query = db.collection('posts')
      .where('authorId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limitNum);

    if (startAfter) {
      const startDoc = await db.collection('posts').doc(startAfter).get();
      if (startDoc.exists) {
        query = query.startAfter(startDoc);
      }
    }

    const snapshot = await query.get();
    const posts = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        authorId: data.authorId,
        content: data.content,
        mediaUrls: data.mediaUrls || [],
        location: data.location,
        nodeId: data.nodeId,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        commentCount: data.commentCount || 0,
        likeCount: data.likeCount || 0,
      };
    });

    res.json({
      posts,
      hasMore: snapshot.docs.length === limitNum,
      lastId: snapshot.docs[snapshot.docs.length - 1]?.id,
    });
  } catch (error) {
    console.error('getUserPosts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =============================================================================
// COMMENTS
// =============================================================================

/**
 * Triggered when a comment is created.
 * - Increments commentCount on the post
 * - Increments replyCount on parent comment (if reply)
 * - Updates feed items with new count
 */
export const onCommentCreated = onDocumentCreated(
  'comments/{commentId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { postId, parentId } = data;

    const batch = db.batch();

    // Increment comment count on post
    batch.update(db.collection('posts').doc(postId), {
      commentCount: FieldValue.increment(1),
    });

    // If this is a reply, increment parent's reply count
    if (parentId) {
      batch.update(db.collection('comments').doc(parentId), {
        replyCount: FieldValue.increment(1),
      });
    }

    await batch.commit();

    // Update feed items (this is eventually consistent)
    await updateFeedItemCount(postId, 'commentCount', 1);

    console.log(`Comment created on post ${postId}${parentId ? ` (reply to ${parentId})` : ''}`);
  }
);

/**
 * Triggered when a comment is deleted.
 * - Decrements commentCount on the post
 * - Decrements replyCount on parent comment (if reply)
 * - Deletes all replies to this comment
 */
export const onCommentDeleted = onDocumentDeleted(
  'comments/{commentId}',
  async (event) => {
    const commentId = event.params.commentId;
    const data = event.data?.data();
    if (!data) return;

    const { postId, parentId } = data;

    const batch = db.batch();

    // Decrement comment count on post
    batch.update(db.collection('posts').doc(postId), {
      commentCount: FieldValue.increment(-1),
    });

    // If this was a reply, decrement parent's reply count
    if (parentId) {
      batch.update(db.collection('comments').doc(parentId), {
        replyCount: FieldValue.increment(-1),
      });
    }

    await batch.commit();

    // Delete all replies to this comment (cascade delete)
    const repliesSnap = await db.collection('comments')
      .where('parentId', '==', commentId)
      .get();

    if (repliesSnap.size > 0) {
      const deleteBatch = db.batch();
      for (const doc of repliesSnap.docs) {
        deleteBatch.delete(doc.ref);
      }
      await deleteBatch.commit();
    }

    // Update feed items
    await updateFeedItemCount(postId, 'commentCount', -1);

    console.log(`Comment ${commentId} deleted from post ${postId}`);
  }
);

/**
 * Get comments for a post (paginated, supports threading)
 */
export const getComments = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const postId = req.query.postId as string;
    const parentId = req.query.parentId as string | undefined;
    const limitNum = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const startAfter = req.query.startAfter as string | undefined;

    if (!postId) {
      res.status(400).json({ error: 'postId required' });
      return;
    }

    // Query root comments or replies based on parentId
    let query = db.collection('comments')
      .where('postId', '==', postId)
      .where('parentId', '==', parentId || null)
      .orderBy('createdAt', 'asc')
      .limit(limitNum);

    if (startAfter) {
      const startDoc = await db.collection('comments').doc(startAfter).get();
      if (startDoc.exists) {
        query = query.startAfter(startDoc);
      }
    }

    const snapshot = await query.get();

    // Get author profiles for all comments
    const comments = await Promise.all(
      snapshot.docs.map(async (doc) => {
        const data = doc.data();
        const authorProfile = await getPublicProfile(data.authorId);
        return {
          id: doc.id,
          postId: data.postId,
          authorId: data.authorId,
          author: authorProfile,
          parentId: data.parentId,
          content: data.content,
          createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
          replyCount: data.replyCount || 0,
        };
      })
    );

    res.json({
      comments,
      hasMore: snapshot.docs.length === limitNum,
      lastId: snapshot.docs[snapshot.docs.length - 1]?.id,
    });
  } catch (error) {
    console.error('getComments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =============================================================================
// LIKES
// =============================================================================

/**
 * Triggered when a like is created.
 * Handles both post likes and comment likes.
 */
export const onLikeCreated = onDocumentCreated(
  'likes/{likeId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { targetId, targetType, postId } = data;

    // Handle comment likes
    if (targetType === 'comment' && targetId) {
      await db.collection('comments').doc(targetId).update({
        likeCount: FieldValue.increment(1),
      });
      console.log(`Like added to comment ${targetId}`);
      return;
    }

    // Handle post likes (legacy format uses postId directly)
    const actualPostId = postId || targetId;
    if (!actualPostId) return;

    // Increment like count on post
    await db.collection('posts').doc(actualPostId).update({
      likeCount: FieldValue.increment(1),
    });

    // Update feed items
    await updateFeedItemCount(actualPostId, 'likeCount', 1);

    console.log(`Like added to post ${actualPostId}`);
  }
);

/**
 * Triggered when a like is deleted.
 * Handles both post likes and comment likes.
 */
export const onLikeDeleted = onDocumentDeleted(
  'likes/{likeId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { targetId, targetType, postId } = data;

    // Handle comment likes
    if (targetType === 'comment' && targetId) {
      await db.collection('comments').doc(targetId).update({
        likeCount: FieldValue.increment(-1),
      });
      console.log(`Like removed from comment ${targetId}`);
      return;
    }

    // Handle post likes (legacy format uses postId directly)
    const actualPostId = postId || targetId;
    if (!actualPostId) return;

    // Decrement like count on post
    await db.collection('posts').doc(actualPostId).update({
      likeCount: FieldValue.increment(-1),
    });

    // Update feed items
    await updateFeedItemCount(actualPostId, 'likeCount', -1);

    console.log(`Like removed from post ${actualPostId}`);
  }
);

/**
 * Check if current user has liked a post
 */
export const checkLikeStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in');
  }

  const { postId } = request.data;
  if (!postId) {
    throw new HttpsError('invalid-argument', 'postId required');
  }

  const likeId = `${request.auth.uid}_${postId}`;
  const doc = await db.collection('likes').doc(likeId).get();

  return { isLiked: doc.exists };
});

// =============================================================================
// HELPER: Update feed item counts
// =============================================================================

/**
 * Update a specific count field on all feed items for a post.
 * This is eventually consistent - runs in background.
 */
async function updateFeedItemCount(
  postId: string,
  field: 'commentCount' | 'likeCount',
  delta: number
) {
  // Get the post to find the author
  const postDoc = await db.collection('posts').doc(postId).get();
  if (!postDoc.exists) return;

  const authorId = postDoc.data()!.authorId;

  // Get all followers of the author
  const followersSnap = await db.collection('follows')
    .where('followeeId', '==', authorId)
    .get();

  const followerIds = followersSnap.docs.map(d => d.data().followerId);
  followerIds.push(authorId); // Also author's own feed

  // Update feed items in batches
  const batchSize = 500;
  for (let i = 0; i < followerIds.length; i += batchSize) {
    const batch = db.batch();
    const chunk = followerIds.slice(i, i + batchSize);

    for (const followerId of chunk) {
      const feedRef = db.collection('feeds').doc(followerId).collection('items').doc(postId);
      batch.update(feedRef, {
        [field]: FieldValue.increment(delta),
      });
    }

    try {
      await batch.commit();
    } catch {
      // Feed item may not exist for some users (e.g., new followers)
      // This is expected and can be ignored
    }
  }
}

// =============================================================================
// PROFILE UPDATES SYNC TO FEEDS
// =============================================================================

/**
 * When a user updates their profile, update their author snapshots in existing feed items.
 * This keeps feed author info eventually consistent.
 * 
 * Note: This is expensive for users with many followers. Consider running as a scheduled
 * job or limiting to active users only.
 */
export const onProfileUpdated = onDocumentDeleted(
  'profiles/{userId}',
  async (event) => {
    // Note: Using onDocumentUpdated causes issues, so we rely on
    // feed items being refreshed periodically or on view.
    // For MVP, feed author snapshots are set at fan-out time only.
  }
);

// =============================================================================
// ADMIN: RECALCULATE COUNTS
// =============================================================================

/**
 * Recalculate all denormalized counts from actual data.
 * This fixes any inconsistencies between stored counts and actual data.
 * 
 * Recalculates:
 * - Post commentCount from actual comments
 * - Post likeCount from actual likes
 * - Profile postCount from actual posts
 * - Profile followerCount from actual follows
 * - Profile followingCount from actual follows
 */
export const recalculateAllCounts = onCall(async (request) => {
  // Optional: Add admin check here
  // if (!request.auth?.token.admin) {
  //   throw new HttpsError('permission-denied', 'Admin only');
  // }

  const results = {
    postsFixed: 0,
    profilesFixed: 0,
    errors: [] as string[],
  };

  try {
    // 1. Fix all post counts
    const postsSnap = await db.collection('posts').get();

    for (const postDoc of postsSnap.docs) {
      try {
        const postId = postDoc.id;

        // Count actual comments
        const commentsSnap = await db.collection('comments')
          .where('postId', '==', postId)
          .count()
          .get();
        const actualCommentCount = commentsSnap.data().count;

        // Count actual likes
        const likesSnap = await db.collection('likes')
          .where('postId', '==', postId)
          .count()
          .get();
        const actualLikeCount = likesSnap.data().count;

        const currentData = postDoc.data();
        if (currentData.commentCount !== actualCommentCount ||
          currentData.likeCount !== actualLikeCount) {
          await postDoc.ref.update({
            commentCount: actualCommentCount,
            likeCount: actualLikeCount,
          });
          results.postsFixed++;
        }
      } catch (err) {
        results.errors.push(`Post ${postDoc.id}: ${err}`);
      }
    }

    // 2. Fix all profile counts
    const profilesSnap = await db.collection('profiles').get();

    for (const profileDoc of profilesSnap.docs) {
      try {
        const userId = profileDoc.id;

        // Count actual posts
        const postsCountSnap = await db.collection('posts')
          .where('authorId', '==', userId)
          .count()
          .get();
        const actualPostCount = postsCountSnap.data().count;

        // Count actual followers (people following this user)
        const followersSnap = await db.collection('follows')
          .where('followingId', '==', userId)
          .count()
          .get();
        const actualFollowerCount = followersSnap.data().count;

        // Count actual following (people this user follows)
        const followingSnap = await db.collection('follows')
          .where('followerId', '==', userId)
          .count()
          .get();
        const actualFollowingCount = followingSnap.data().count;

        const currentData = profileDoc.data();
        if (currentData.postCount !== actualPostCount ||
          currentData.followerCount !== actualFollowerCount ||
          currentData.followingCount !== actualFollowingCount) {
          await profileDoc.ref.update({
            postCount: actualPostCount,
            followerCount: actualFollowerCount,
            followingCount: actualFollowingCount,
          });
          results.profilesFixed++;
        }
      } catch (err) {
        results.errors.push(`Profile ${profileDoc.id}: ${err}`);
      }
    }

    console.log(`Recalculated counts: ${results.postsFixed} posts, ${results.profilesFixed} profiles fixed`);
    return results;
  } catch (err) {
    console.error('Error recalculating counts:', err);
    throw new HttpsError('internal', `Failed to recalculate: ${err}`);
  }
});
