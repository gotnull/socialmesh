/**
 * Socialmesh Push Notification Cloud Functions
 *
 * Sends FCM push notifications for social events:
 * - New follower
 * - Follow request (for private accounts)
 * - Follow request accepted
 * - New like on post
 * - New comment on post
 * - New reply to comment
 */

import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

const db = admin.firestore();
const messaging = admin.messaging();

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

interface UserProfile {
  displayName?: string;
  avatarUrl?: string;
  callsign?: string;
}

interface UserData {
  fcmTokens?: Record<string, { platform: string; updatedAt: admin.firestore.Timestamp }>;
  notificationSettings?: {
    follows?: boolean;
    likes?: boolean;
    comments?: boolean;
  };
}

/**
 * Get a user's public profile
 */
async function getProfile(userId: string): Promise<UserProfile | null> {
  const doc = await db.collection('profiles').doc(userId).get();
  if (!doc.exists) return null;
  return doc.data() as UserProfile;
}

/**
 * Get a user's FCM tokens
 */
async function getFcmTokens(userId: string): Promise<string[]> {
  const doc = await db.collection('users').doc(userId).get();
  if (!doc.exists) return [];

  const data = doc.data() as UserData;
  if (!data.fcmTokens) return [];

  return Object.keys(data.fcmTokens);
}

/**
 * Check if user has a specific notification type enabled
 */
async function isNotificationEnabled(
  userId: string,
  type: 'follows' | 'likes' | 'comments'
): Promise<boolean> {
  const doc = await db.collection('users').doc(userId).get();
  if (!doc.exists) return true; // Default to enabled

  const data = doc.data() as UserData;
  if (!data.notificationSettings) return true; // Default to enabled

  return data.notificationSettings[type] !== false;
}

/**
 * Send push notification to a user
 */
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  const tokens = await getFcmTokens(userId);
  if (tokens.length === 0) {
    console.log(`No FCM tokens for user ${userId}`);
    return;
  }

  const message: admin.messaging.MulticastMessage = {
    notification: {
      title,
      body,
    },
    data,
    tokens,
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
    android: {
      notification: {
        sound: 'default',
        channelId: 'social_notifications',
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(`Push sent to ${userId}: ${response.successCount} success, ${response.failureCount} failures`);

    // Remove invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          if (
            error?.code === 'messaging/invalid-registration-token' ||
            error?.code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        const updates: Record<string, admin.firestore.FieldValue> = {};
        invalidTokens.forEach(token => {
          updates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
        });
        await db.collection('users').doc(userId).update(updates);
        console.log(`Removed ${invalidTokens.length} invalid tokens for user ${userId}`);
      }
    }
  } catch (error) {
    console.error(`Error sending push to ${userId}:`, error);
  }
}

// =============================================================================
// FOLLOW NOTIFICATIONS
// =============================================================================

/**
 * Send notification when someone follows a user
 */
export const onFollowCreatedNotification = onDocumentCreated(
  'follows/{followId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { followerId, followeeId } = data;

    // Check if user has follow notifications enabled
    if (!await isNotificationEnabled(followeeId, 'follows')) {
      console.log(`Follow notifications disabled for user ${followeeId}`);
      return;
    }

    // Get follower's profile
    const followerProfile = await getProfile(followerId);
    const followerName = followerProfile?.displayName || 'Someone';

    await sendPushNotification(
      followeeId,
      'New Follower',
      `${followerName} started following you`,
      {
        type: 'new_follower',
        targetId: followerId,
      }
    );
  }
);

/**
 * Send notification when someone requests to follow a private account
 */
export const onFollowRequestCreatedNotification = onDocumentCreated(
  'follow_requests/{requestId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { requesterId, targetId, status } = data;

    // Only notify for pending requests
    if (status !== 'pending') return;

    // Check if user has follow notifications enabled
    if (!await isNotificationEnabled(targetId, 'follows')) {
      console.log(`Follow notifications disabled for user ${targetId}`);
      return;
    }

    // Get requester's profile
    const requesterProfile = await getProfile(requesterId);
    const requesterName = requesterProfile?.displayName || 'Someone';

    await sendPushNotification(
      targetId,
      'Follow Request',
      `${requesterName} wants to follow you`,
      {
        type: 'follow_request',
        targetId: requesterId,
      }
    );
  }
);

/**
 * Send notification when a follow request is accepted
 * Listens for status changes from 'pending' to 'accepted'
 */
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

export const onFollowRequestAcceptedNotification = onDocumentUpdated(
  'follow_requests/{requestId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only notify when status changes from pending to accepted
    if (before.status !== 'pending' || after.status !== 'accepted') return;

    const { requesterId, targetId } = after;

    // Check if requester has follow notifications enabled
    if (!await isNotificationEnabled(requesterId, 'follows')) {
      console.log(`Follow notifications disabled for user ${requesterId}`);
      return;
    }

    // Get accepter's profile
    const accepterProfile = await getProfile(targetId);
    const accepterName = accepterProfile?.displayName || 'Someone';

    await sendPushNotification(
      requesterId,
      'Follow Request Accepted',
      `${accepterName} accepted your follow request`,
      {
        type: 'follow_request_accepted',
        targetId: targetId,
      }
    );
  }
);

// =============================================================================
// LIKE NOTIFICATIONS
// =============================================================================

/**
 * Send notification when someone likes a post
 */
export const onLikeCreatedNotification = onDocumentCreated(
  'likes/{likeId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { userId: likerId, postId } = data;

    // Get the post to find the author
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;

    const postData = postDoc.data()!;
    const authorId = postData.authorId;

    // Don't notify if user liked their own post
    if (likerId === authorId) return;

    // Check if user has like notifications enabled
    if (!await isNotificationEnabled(authorId, 'likes')) {
      console.log(`Like notifications disabled for user ${authorId}`);
      return;
    }

    // Get liker's profile
    const likerProfile = await getProfile(likerId);
    const likerName = likerProfile?.displayName || 'Someone';

    await sendPushNotification(
      authorId,
      'New Like',
      `${likerName} liked your post`,
      {
        type: 'new_like',
        targetId: postId,
      }
    );
  }
);

// =============================================================================
// COMMENT NOTIFICATIONS
// =============================================================================

/**
 * Extract @mentions from text and resolve to user IDs
 */
async function extractMentions(text: string): Promise<string[]> {
  // Match @username patterns (alphanumeric and underscore)
  const mentionPattern = /@([a-zA-Z0-9_]+)/g;
  const mentions: string[] = [];
  let match;

  while ((match = mentionPattern.exec(text)) !== null) {
    const username = match[1].toLowerCase();
    // Look up user by callsign/username in profiles
    const profilesSnapshot = await db.collection('profiles')
      .where('callsign', '==', username)
      .limit(1)
      .get();

    if (!profilesSnapshot.empty) {
      mentions.push(profilesSnapshot.docs[0].id);
    }
  }

  return mentions;
}

/**
 * Send notification when someone comments on a post
 */
export const onCommentCreatedNotification = onDocumentCreated(
  'comments/{commentId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { authorId: commenterId, postId, parentId, text } = data;

    // Get the post to find the author
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;

    const postData = postDoc.data()!;
    const postAuthorId = postData.authorId;

    // Truncate comment text for notification
    const truncatedText = text.length > 50 ? `${text.substring(0, 50)}...` : text;

    // Get commenter's profile
    const commenterProfile = await getProfile(commenterId);
    const commenterName = commenterProfile?.displayName || 'Someone';

    // Track who we've already notified to avoid duplicates
    const notifiedUsers = new Set<string>();
    notifiedUsers.add(commenterId); // Don't notify the commenter

    // If this is a reply, notify the parent comment author
    if (parentId) {
      const parentDoc = await db.collection('comments').doc(parentId).get();
      if (parentDoc.exists) {
        const parentData = parentDoc.data()!;
        const parentAuthorId = parentData.authorId;

        // Don't notify if replying to own comment
        if (!notifiedUsers.has(parentAuthorId)) {
          notifiedUsers.add(parentAuthorId);
          // Check if user has comment notifications enabled
          if (await isNotificationEnabled(parentAuthorId, 'comments')) {
            await sendPushNotification(
              parentAuthorId,
              'New Reply',
              `${commenterName} replied: ${truncatedText}`,
              {
                type: 'new_reply',
                targetId: postId,
                commentId: event.data!.id,
              }
            );
          }
        }
      }
    }

    // Notify post author (if different from commenter and parent author)
    if (!notifiedUsers.has(postAuthorId)) {
      notifiedUsers.add(postAuthorId);
      // Check if user has comment notifications enabled
      if (await isNotificationEnabled(postAuthorId, 'comments')) {
        await sendPushNotification(
          postAuthorId,
          'New Comment',
          `${commenterName} commented: ${truncatedText}`,
          {
            type: 'new_comment',
            targetId: postId,
            commentId: event.data!.id,
          }
        );
      }
    }

    // Handle @mentions in the comment
    const mentionedUserIds = await extractMentions(text);
    for (const mentionedUserId of mentionedUserIds) {
      // Skip if already notified or if it's the commenter
      if (notifiedUsers.has(mentionedUserId)) continue;
      notifiedUsers.add(mentionedUserId);

      // Check if user has comment notifications enabled (mentions use comments setting)
      if (await isNotificationEnabled(mentionedUserId, 'comments')) {
        await sendPushNotification(
          mentionedUserId,
          'You were mentioned',
          `${commenterName} mentioned you: ${truncatedText}`,
          {
            type: 'mention',
            targetId: postId,
            commentId: event.data!.id,
          }
        );
      }
    }
  }
);
