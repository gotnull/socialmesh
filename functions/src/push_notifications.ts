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
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

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
    signals?: boolean;
    votes?: boolean;
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
  type: 'follows' | 'likes' | 'comments' | 'signals' | 'votes'
): Promise<boolean> {
  const doc = await db.collection('users').doc(userId).get();
  if (!doc.exists) return true; // Default to enabled

  const data = doc.data() as UserData;
  if (!data.notificationSettings) return true; // Default to enabled

  return data.notificationSettings[type] !== false;
}

export function shouldNotifySignalVote(
  beforeValue?: number,
  afterValue?: number
): boolean {
  return afterValue === 1 && beforeValue !== 1;
}

/**
 * Send push notification to a user
 */
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>,
  imageUrl?: string
): Promise<void> {
  const tokens = await getFcmTokens(userId);
  if (tokens.length === 0) {
    console.log(`No FCM tokens for user ${userId}`);
    return;
  }

  // Include imageUrl in data payload for iOS Notification Service Extension
  const dataWithImage = imageUrl
    ? { ...data, imageUrl }
    : data;

  console.log(`[Push] Sending to ${userId} with imageUrl: ${imageUrl || 'none'}`);
  console.log('[Push] Data payload:', JSON.stringify(dataWithImage));

  const message: admin.messaging.MulticastMessage = {
    notification: {
      title,
      body,
      ...(imageUrl && { imageUrl }),
    },
    data: dataWithImage,
    tokens,
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'mutable-content': 1,
        },
      },
      fcmOptions: imageUrl ? { imageUrl } : undefined,
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'social_notifications',
        priority: 'high',
        ...(imageUrl && { imageUrl }),
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

/**
 * Reserve a notification key to dedupe retries.
 * Returns true if notification should be sent, false if already sent.
 */
export function sanitizeNotificationKey(key: string): string {
  return key.replace(/[^a-zA-Z0-9_-]/g, '_');
}

async function reserveNotificationKey(key: string): Promise<boolean> {
  const safeKey = sanitizeNotificationKey(key);
  try {
    await db.collection('notification_dedupe').doc(safeKey).create({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch {
    console.log(`[Push] Dedupe hit for key ${safeKey}, skipping`);
    return false;
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
      },
      followerProfile?.avatarUrl
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
      },
      requesterProfile?.avatarUrl
    );
  }
);

/**
 * Send notification when a follow request is accepted
 * Listens for status changes from 'pending' to 'accepted'
 */
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
      },
      accepterProfile?.avatarUrl
    );
  }
);

// =============================================================================
// SIGNAL NOTIFICATIONS
// =============================================================================

/**
 * Send notification to followers when someone creates a new signal
 */
export const onSignalCreatedNotification = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    // Only handle signals (not regular social posts)
    const postMode = data.postMode as string;
    if (postMode !== 'signal') {
      console.log('Not a signal, skipping notification');
      return;
    }

    const authorId = data.authorId as string;
    const content = data.content as string;
    const postId = event.params.postId;

    // Truncate content for notification
    const truncatedContent = content.length > 50
      ? `${content.substring(0, 50)}...`
      : content;

    // Get author's profile
    const authorProfile = await getProfile(authorId);
    const authorName = authorProfile?.displayName || 'Someone';

    // Find subscribers for this author's signals via the fast 'signal_subscribers' index
    const subsSnapshot = await db.collection('signal_subscribers')
      .doc(authorId)
      .collection('subscribers')
      .get();

    if (subsSnapshot.empty) {
      console.log(`No subscribers to notify for signal by ${authorId}`);
      return;
    }

    console.log(`Notifying ${subsSnapshot.size} subscribers of new signal by ${authorName}`);

    // Send notification to each subscriber
    const notificationPromises = subsSnapshot.docs.map(async (doc) => {
      const subscriberData = doc.data();
      const subscriberId = subscriberData.subscriberId as string;

      if (subscriberId === authorId) {
        return;
      }

      // Check if subscriber has signal notifications enabled
      if (!await isNotificationEnabled(subscriberId, 'signals')) {
        console.log(`Signal notifications disabled for user ${subscriberId}`);
        return;
      }

      const dedupeKey = `signal_created:${subscriberId}:${postId}`;
      if (!await reserveNotificationKey(dedupeKey)) {
        return;
      }

      return sendPushNotification(
        subscriberId,
        `${authorName} is active 📡`,
        truncatedContent,
        {
          type: 'new_signal',
          targetId: postId,
          authorId: authorId,
        },
        authorProfile?.avatarUrl
      );
    });

    await Promise.all(notificationPromises);
  }
);

// =============================================================================
// LIKE NOTIFICATIONS
// =============================================================================

/**
 * Send notification when someone likes a post or comment
 */
export const onLikeCreatedNotification = onDocumentCreated(
  'likes/{likeId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { userId: likerId, targetType } = data;

    // Handle comment likes separately (they have targetType: 'comment')
    if (targetType === 'comment') {
      const commentId = data.targetId as string;
      if (!commentId) return;

      const commentDoc = await db.collection('comments').doc(commentId).get();
      if (!commentDoc.exists) return;

      const commentData = commentDoc.data()!;
      const authorId = commentData.authorId as string;

      // Don't notify if user liked their own comment
      if (likerId === authorId) return;

      // Check if user has like notifications enabled
      if (!await isNotificationEnabled(authorId, 'likes')) {
        console.log(`Like notifications disabled for user ${authorId}`);
        return;
      }

      const likerProfile = await getProfile(likerId);
      const likerName = likerProfile?.displayName || 'Someone';

      await sendPushNotification(
        authorId,
        'New Like',
        `${likerName} liked your comment`,
        {
          type: 'comment_like',
          targetId: commentData.postId as string,
        },
        likerProfile?.avatarUrl
      );
      return;
    }

    // Handle post likes
    const postId = data.postId as string;
    if (!postId) return;

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

    // If the post is a signal, send a signal-specific payload and label
    const postMode = postData.postMode as string | undefined;
    if (postMode === 'signal') {
      await sendPushNotification(
        authorId,
        'New Like',
        `${likerName} liked your signal`,
        {
          type: 'signal_like',
          targetId: postId,
        },
        likerProfile?.avatarUrl
      );
    } else {
      await sendPushNotification(
        authorId,
        'New Like',
        `${likerName} liked your post`,
        {
          type: 'new_like',
          targetId: postId,
        },
        likerProfile?.avatarUrl
      );
    }
  }
);

// =============================================================================
// STORY LIKE NOTIFICATIONS
// =============================================================================

/**
 * Send notification when someone likes a story
 */
export const onStoryLikeCreatedNotification = onDocumentCreated(
  'stories/{storyId}/likes/{likeId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { userId: likerId } = data;
    const storyId = event.params.storyId;

    // Get the story to find the author
    const storyDoc = await db.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) return;

    const storyData = storyDoc.data()!;
    const authorId = storyData.authorId;

    // Don't notify if user liked their own story
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
      'Story Liked ❤️',
      `${likerName} liked your story`,
      {
        type: 'story_like',
        targetId: storyId,
        likerId: likerId,
      },
      likerProfile?.avatarUrl
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

    // Skip if no text (e.g., moderated comment)
    if (!text) return;

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
              },
              commenterProfile?.avatarUrl
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
          },
          commenterProfile?.avatarUrl
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
          },
          commenterProfile?.avatarUrl
        );
      }
    }
  }
);

// =============================================================================
// SIGNAL COMMENT NOTIFICATIONS (Subcollection)
// =============================================================================

/**
 * Send notification when someone comments on a signal
 * Handles comments in the posts/{postId}/comments/{commentId} subcollection path
 */
export const onSignalCommentNotification = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const postId = event.params.postId;
    const commentId = event.params.commentId;
    const { authorId: commenterId, content, signalId, parentId } = data;

    // Verify this is a signal comment
    if (signalId !== postId) {
      console.log('Not a signal comment, skipping notification');
      return;
    }

    // Skip if no content
    if (!content) return;

    // Get the signal/post to find the author
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;

    const postData = postDoc.data()!;
    const postAuthorId = postData.authorId;

    // Truncate content for notification
    const truncatedContent = content.length > 50
      ? `${content.substring(0, 50)}...`
      : content;

    // Get commenter's profile
    const commenterProfile = await getProfile(commenterId);
    const commenterName = commenterProfile?.displayName || 'Someone';

    const notifiedUsers = new Set<string>();
    notifiedUsers.add(commenterId);

    // Reply: notify parent comment author
    if (parentId) {
      const parentDoc = await db.collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(parentId)
        .get();

      if (parentDoc.exists) {
        const parentAuthorId = parentDoc.data()!.authorId as string;
        if (!notifiedUsers.has(parentAuthorId)) {
          notifiedUsers.add(parentAuthorId);
          if (await isNotificationEnabled(parentAuthorId, 'comments')) {
            const dedupeKey = `signal_reply:${parentAuthorId}:${commentId}`;
            if (await reserveNotificationKey(dedupeKey)) {
              await sendPushNotification(
                parentAuthorId,
                'New reply on your signal',
                `${commenterName}: ${truncatedContent}`,
                {
                  type: 'signal_reply',
                  targetId: postId,
                  commentId: commentId,
                  parentId: parentId,
                },
                commenterProfile?.avatarUrl
              );
            }
          }
        }
      }
    }

    // Notify signal author
    if (!notifiedUsers.has(postAuthorId)) {
      if (!await isNotificationEnabled(postAuthorId, 'comments')) {
        console.log(`Signal comment notifications disabled for user ${postAuthorId}`);
        return;
      }

      console.log(`Notifying signal author ${postAuthorId} of new comment by ${commenterName}`);
      const dedupeKey = `signal_comment:${postAuthorId}:${commentId}`;
      if (!await reserveNotificationKey(dedupeKey)) {
        return;
      }

      await sendPushNotification(
        postAuthorId,
        'New comment on your signal',
        `${commenterName}: ${truncatedContent}`,
        {
          type: 'signal_comment',
          targetId: postId,
          commentId: commentId,
        },
        commenterProfile?.avatarUrl
      );
    }
  }
);

/**
 * Send notification when someone votes on a signal comment.
 */
export const onSignalVoteNotification = onDocumentWritten(
  'posts/{postId}/comments/{commentId}/votes/{voterId}',
  async (event) => {
    const { postId, commentId, voterId } = event.params;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    const beforeValue = beforeData?.value as number | undefined;
    const afterValue = afterData?.value as number | undefined;

    // Only notify on new upvotes (or changes to upvote)
    if (!shouldNotifySignalVote(beforeValue, afterValue)) {
      return;
    }
    if (afterValue != 1) {
      return;
    }

    const commentDoc = await db.collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId)
      .get();
    if (!commentDoc.exists) return;

    const commentData = commentDoc.data()!;
    if (commentData.signalId !== postId) return;

    const commentAuthorId = commentData.authorId as string;
    if (commentAuthorId === voterId) return;

    if (!await isNotificationEnabled(commentAuthorId, 'votes')) {
      console.log(`Signal vote notifications disabled for user ${commentAuthorId}`);
      return;
    }

    const voterProfile = await getProfile(voterId);
    const voterName = voterProfile?.displayName || 'Someone';

    const dedupeKey = `signal_vote:${commentAuthorId}:${commentId}:${voterId}:up`;
    if (!await reserveNotificationKey(dedupeKey)) {
      return;
    }

    await sendPushNotification(
      commentAuthorId,
      'New vote on your comment',
      `${voterName} upvoted your comment`,
      {
        type: 'signal_vote',
        targetId: postId,
        commentId: commentId,
        value: afterValue.toString(),
      },
      voterProfile?.avatarUrl
    );
  }
);

// =============================================================================
// TEST NOTIFICATION (Debug only)
// =============================================================================

/**
 * Send a test push notification to the calling user
 * Used for debugging FCM setup in the app
 */
export const sendTestPushNotification = onCall(async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;
  const type = request.data?.type as string || 'test';

  // Get user's FCM tokens
  const tokens = await getFcmTokens(userId);
  if (tokens.length === 0) {
    throw new HttpsError('failed-precondition', 'No FCM tokens registered for this user');
  }

  // Get the user's own profile to use their avatar in test notifications
  const userProfile = await getProfile(userId);
  const avatarUrl = userProfile?.avatarUrl;

  // Build notification based on type
  let title: string;
  let body: string;
  let data: Record<string, string>;

  switch (type) {
    case 'follow':
      title = 'New Follower';
      body = 'Debug User started following you';
      data = { type: 'new_follower', targetId: 'debug_user' };
      break;
    case 'like':
      title = 'New Like';
      body = 'Debug User liked your post';
      data = { type: 'new_like', targetId: 'debug_post' };
      break;
    case 'comment':
      title = 'New Comment';
      body = 'Debug User commented: "This is a test comment!"';
      data = { type: 'new_comment', targetId: 'debug_post', commentId: 'debug_comment' };
      break;
    case 'mention':
      title = 'You were mentioned';
      body = 'Debug User mentioned you: "Hey @you check this out!"';
      data = { type: 'mention', targetId: 'debug_post', commentId: 'debug_comment' };
      break;
    case 'signal':
      title = 'Debug User is active 📡';
      body = 'This is a test signal notification!';
      data = { type: 'new_signal', targetId: 'debug_signal', authorId: 'debug_user' };
      break;
    case 'vote':
      title = 'New vote on your comment';
      body = 'Debug User upvoted your comment';
      data = { type: 'signal_vote', targetId: 'debug_signal', commentId: 'debug_comment', value: '1' };
      break;
    default:
      title = 'Test Notification';
      body = 'This is a test push notification from Firebase';
      data = { type: 'test' };
  }

  // Send the notification with avatar if available
  // Include imageUrl in data payload for iOS Notification Service Extension
  const dataWithImage = avatarUrl
    ? { ...data, imageUrl: avatarUrl }
    : data;

  console.log(`[TestPush] Sending to ${userId} with avatarUrl: ${avatarUrl || 'none'}`);
  console.log('[TestPush] Data payload:', JSON.stringify(dataWithImage));

  const message: admin.messaging.MulticastMessage = {
    notification: {
      title,
      body,
      ...(avatarUrl && { imageUrl: avatarUrl }),
    },
    data: dataWithImage,
    tokens,
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'mutable-content': 1,
        },
      },
      fcmOptions: avatarUrl ? { imageUrl: avatarUrl } : undefined,
    },
    android: {
      notification: {
        sound: 'default',
        channelId: 'social_notifications',
        ...(avatarUrl && { imageUrl: avatarUrl }),
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(`Test push sent to ${userId}: ${response.successCount} success, ${response.failureCount} failures`);

    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
      tokenCount: tokens.length,
    };
  } catch (error) {
    console.error(`Error sending test push to ${userId}:`, error);
    throw new HttpsError('internal', 'Failed to send push notification');
  }
});
