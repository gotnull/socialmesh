/**
 * Content Moderation System
 *
 * AI content moderation using Google Cloud Vision API
 * for image analysis and custom text filtering.
 *
 * Architecture:
 * 1. Upload-time scanning: Storage triggers scan new uploads
 * 2. Text moderation: Callable function for captions, comments, etc.
 * 3. Automated actions: Auto-reject, flag, or demote based on confidence
 * 4. Strike system: Track violations per user, escalating consequences
 * 5. Human review queue: Borderline content for manual review
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { onObjectFinalized } from 'firebase-functions/v2/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

const db = admin.firestore();

// =============================================================================
// BANNED WORDS CONFIGURATION (loaded from JSON)
// =============================================================================

interface BannedWordsCategory {
  severity: 'low' | 'medium' | 'high' | 'critical';
  words: string[];
  patterns: string[];
}

interface BannedWordsConfig {
  version: string;
  lastUpdated: string;
  categories: Record<string, BannedWordsCategory>;
}

/**
 * Load banned words configuration from JSON file.
 * Compiled patterns are cached for performance.
 */
let cachedBlockedPatterns: Record<string, RegExp[]> | null = null;
let cachedCategorySeverity: Record<string, 'low' | 'medium' | 'high' | 'critical'> | null = null;

function loadBannedWordsConfig(): BannedWordsConfig {
  const configPath = path.join(__dirname, 'banned_words.json');
  const rawData = fs.readFileSync(configPath, 'utf-8');
  return JSON.parse(rawData) as BannedWordsConfig;
}

/**
 * Build regex patterns from banned words config.
 * - Simple words: Convert to word boundary pattern (\bword\b)
 * - Complex patterns: Compile as-is (already regex strings)
 */
function buildBlockedPatterns(): Record<string, RegExp[]> {
  if (cachedBlockedPatterns) {
    return cachedBlockedPatterns;
  }

  const config = loadBannedWordsConfig();
  const patterns: Record<string, RegExp[]> = {};
  cachedCategorySeverity = {};

  for (const [category, categoryConfig] of Object.entries(config.categories)) {
    const categoryPatterns: RegExp[] = [];
    cachedCategorySeverity[category] = categoryConfig.severity;

    // Convert simple words to word boundary patterns
    for (const word of categoryConfig.words) {
      // Escape special regex characters in the word, then wrap with \b
      const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      categoryPatterns.push(new RegExp(`\\b${escaped}\\b`, 'i'));
    }

    // Add complex patterns as-is (they're already regex strings)
    for (const pattern of categoryConfig.patterns) {
      try {
        categoryPatterns.push(new RegExp(pattern, 'i'));
      } catch (e) {
        console.error(`Invalid regex pattern in ${category}: ${pattern}`, e);
      }
    }

    patterns[category] = categoryPatterns;
  }

  cachedBlockedPatterns = patterns;
  console.log(`Loaded banned words config v${config.version}, last updated: ${config.lastUpdated}`);
  return patterns;
}

/**
 * Get category severity map (built alongside patterns)
 */
function getCategorySeverity(): Record<string, 'low' | 'medium' | 'high' | 'critical'> {
  if (!cachedCategorySeverity) {
    buildBlockedPatterns();
  }
  return cachedCategorySeverity!;
}

// =============================================================================
// TYPES & CONSTANTS
// =============================================================================

interface ModerationResult {
  passed: boolean;
  action: 'approve' | 'flag' | 'reject' | 'review';
  confidence: number;
  categories: ModerationCategory[];
  details: string;
}

interface ModerationCategory {
  name: string;
  likelihood: 'VERY_UNLIKELY' | 'UNLIKELY' | 'POSSIBLE' | 'LIKELY' | 'VERY_LIKELY';
  score: number;
}

interface UserStrike {
  id: string;
  userId: string;
  type: 'warning' | 'strike' | 'suspension';
  reason: string;
  contentId?: string;
  contentType?: string;
  createdAt: admin.firestore.Timestamp;
  expiresAt?: admin.firestore.Timestamp;
  acknowledged: boolean;
}

interface ModerationQueueItem {
  id: string;
  contentType: 'story' | 'post' | 'comment' | 'profile';
  contentId: string;
  userId: string;
  contentUrl?: string;
  textContent?: string;
  moderationResult: ModerationResult;
  status: 'pending' | 'approved' | 'rejected';
  reviewedBy?: string;
  reviewedAt?: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
}

// Thresholds for automated decisions
const MODERATION_THRESHOLDS = {
  // Auto-reject if any category score exceeds this
  AUTO_REJECT: 0.9,
  // Flag for human review if score is between FLAG and AUTO_REJECT
  FLAG_FOR_REVIEW: 0.6,
  // Auto-approve if all scores are below this
  AUTO_APPROVE: 0.3,
};

// Strike escalation rules
const STRIKE_RULES = {
  // Number of warnings before first strike
  WARNINGS_BEFORE_STRIKE: 2,
  // Number of strikes before suspension
  STRIKES_BEFORE_SUSPENSION: 3,
  // Suspension duration in days
  SUSPENSION_DURATION_DAYS: 7,
  // Strikes expire after this many days
  STRIKE_EXPIRY_DAYS: 90,
  // Permanent ban threshold
  PERMANENT_BAN_STRIKES: 5,
};

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Analyze image using Google Cloud Vision Safe Search API
 */
async function analyzeImageWithVision(imageUrl: string): Promise<ModerationResult> {
  // Import Vision API client
  const vision = await import('@google-cloud/vision');
  const client = new vision.ImageAnnotatorClient();

  try {
    const [result] = await client.safeSearchDetection(imageUrl);
    const safeSearch = result.safeSearchAnnotation;

    if (!safeSearch) {
      return {
        passed: true,
        action: 'approve',
        confidence: 1.0,
        categories: [],
        details: 'No safe search annotation returned',
      };
    }

    // Map Vision API likelihoods to scores
    const likelihoodToScore: Record<string, number> = {
      'VERY_UNLIKELY': 0.0,
      'UNLIKELY': 0.2,
      'POSSIBLE': 0.5,
      'LIKELY': 0.8,
      'VERY_LIKELY': 1.0,
    };

    const categories: ModerationCategory[] = [
      {
        name: 'adult',
        likelihood: (safeSearch.adult as ModerationCategory['likelihood']) || 'VERY_UNLIKELY',
        score: likelihoodToScore[safeSearch.adult || 'VERY_UNLIKELY'],
      },
      {
        name: 'violence',
        likelihood: (safeSearch.violence as ModerationCategory['likelihood']) || 'VERY_UNLIKELY',
        score: likelihoodToScore[safeSearch.violence || 'VERY_UNLIKELY'],
      },
      {
        name: 'racy',
        likelihood: (safeSearch.racy as ModerationCategory['likelihood']) || 'VERY_UNLIKELY',
        score: likelihoodToScore[safeSearch.racy || 'VERY_UNLIKELY'],
      },
      {
        name: 'medical',
        likelihood: (safeSearch.medical as ModerationCategory['likelihood']) || 'VERY_UNLIKELY',
        score: likelihoodToScore[safeSearch.medical || 'VERY_UNLIKELY'],
      },
      {
        name: 'spoof',
        likelihood: (safeSearch.spoof as ModerationCategory['likelihood']) || 'VERY_UNLIKELY',
        score: likelihoodToScore[safeSearch.spoof || 'VERY_UNLIKELY'],
      },
    ];

    // Determine action based on highest score
    const maxScore = Math.max(...categories.map(c => c.score));
    const flaggedCategories = categories.filter(c => c.score >= MODERATION_THRESHOLDS.FLAG_FOR_REVIEW);

    let action: ModerationResult['action'] = 'approve';
    let passed = true;

    if (maxScore >= MODERATION_THRESHOLDS.AUTO_REJECT) {
      action = 'reject';
      passed = false;
    } else if (maxScore >= MODERATION_THRESHOLDS.FLAG_FOR_REVIEW) {
      action = 'review';
      passed = true; // Allow but queue for review
    }

    return {
      passed,
      action,
      confidence: maxScore,
      categories: flaggedCategories.length > 0 ? flaggedCategories : categories,
      details: flaggedCategories.length > 0
        ? `Flagged: ${flaggedCategories.map(c => c.name).join(', ')}`
        : 'Content passed moderation',
    };
  } catch (error) {
    console.error('Vision API error:', error);
    // On error, flag for manual review rather than blocking
    return {
      passed: true,
      action: 'review',
      confidence: 0,
      categories: [],
      details: `Vision API error: ${error}`,
    };
  }
}

/**
 * Analyze text content for policy violations using patterns loaded from JSON config.
 */
function analyzeText(text: string): ModerationResult {
  if (!text || text.trim().length === 0) {
    return {
      passed: true,
      action: 'approve',
      confidence: 1.0,
      categories: [],
      details: 'Empty text',
    };
  }

  const flaggedCategories: ModerationCategory[] = [];
  let maxSeverity: 'low' | 'medium' | 'high' | 'critical' = 'low';

  // Load patterns from JSON config (cached after first load)
  const blockedPatterns = buildBlockedPatterns();
  const categorySeverity = getCategorySeverity();

  // Check against all blocked patterns
  for (const [category, patterns] of Object.entries(blockedPatterns)) {
    for (const pattern of patterns) {
      if (pattern.test(text)) {
        const severity = categorySeverity[category] || 'medium';
        if (severityToScore(severity) > severityToScore(maxSeverity)) {
          maxSeverity = severity;
        }

        flaggedCategories.push({
          name: category,
          likelihood: severityToLikelihood(severity),
          score: severityToScore(severity),
        });

        console.log(`[ContentModeration] Pattern matched: category=${category}, pattern=${pattern}, text="${text.substring(0, 100)}..."`);

        // Only add one match per category
        break;
      }
    }
  }

  // Determine action
  const maxScore = Math.max(0, ...flaggedCategories.map(c => c.score));
  let action: ModerationResult['action'] = 'approve';
  let passed = true;

  if (maxScore >= MODERATION_THRESHOLDS.AUTO_REJECT) {
    action = 'reject';
    passed = false;
  } else if (maxScore >= MODERATION_THRESHOLDS.FLAG_FOR_REVIEW) {
    action = 'review';
  } else if (flaggedCategories.length > 0) {
    action = 'flag';
  }

  return {
    passed,
    action,
    confidence: maxScore,
    categories: flaggedCategories,
    details: flaggedCategories.length > 0
      ? `Flagged patterns: ${flaggedCategories.map(c => c.name).join(', ')}`
      : 'Text passed moderation',
  };
}

function severityToScore(severity: 'low' | 'medium' | 'high' | 'critical'): number {
  switch (severity) {
    case 'low': return 0.3;
    case 'medium': return 0.5;
    case 'high': return 0.8;
    case 'critical': return 1.0;
  }
}

function severityToLikelihood(severity: 'low' | 'medium' | 'high' | 'critical'): ModerationCategory['likelihood'] {
  switch (severity) {
    case 'low': return 'POSSIBLE';
    case 'medium': return 'LIKELY';
    case 'high': return 'VERY_LIKELY';
    case 'critical': return 'VERY_LIKELY';
  }
}

/**
 * Add item to moderation queue for human review
 */
async function addToModerationQueue(
  contentType: ModerationQueueItem['contentType'],
  contentId: string,
  userId: string,
  result: ModerationResult,
  contentUrl?: string,
  textContent?: string,
): Promise<string> {
  const queueItem: Omit<ModerationQueueItem, 'id'> = {
    contentType,
    contentId,
    userId,
    moderationResult: result,
    status: 'pending',
    createdAt: admin.firestore.Timestamp.now(),
    ...(contentUrl && { contentUrl }),
    ...(textContent && { textContent }),
  };

  const docRef = await db.collection('moderation_queue').add(queueItem);
  console.log(`Added to moderation queue: ${docRef.id}`);
  return docRef.id;
}

/**
 * Record a strike or warning against a user
 */
async function recordUserStrike(
  userId: string,
  reason: string,
  contentId?: string,
  contentType?: string,
): Promise<UserStrike> {
  // Get current strike count
  const strikesSnap = await db.collection('user_strikes')
    .where('userId', '==', userId)
    .where('expiresAt', '>', admin.firestore.Timestamp.now())
    .get();

  const activeStrikes = strikesSnap.docs.filter(
    doc => doc.data().type === 'strike',
  ).length;

  const activeWarnings = strikesSnap.docs.filter(
    doc => doc.data().type === 'warning',
  ).length;

  // Determine strike type based on history
  let strikeType: UserStrike['type'] = 'warning';

  if (activeWarnings >= STRIKE_RULES.WARNINGS_BEFORE_STRIKE) {
    strikeType = 'strike';
  }

  if (activeStrikes >= STRIKE_RULES.STRIKES_BEFORE_SUSPENSION) {
    strikeType = 'suspension';
  }

  // Calculate expiry
  const expiryDays = strikeType === 'suspension'
    ? STRIKE_RULES.SUSPENSION_DURATION_DAYS
    : STRIKE_RULES.STRIKE_EXPIRY_DAYS;

  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000),
  );

  const strike: Omit<UserStrike, 'id'> = {
    userId,
    type: strikeType,
    reason,
    createdAt: admin.firestore.Timestamp.now(),
    expiresAt,
    acknowledged: false,
    ...(contentId && { contentId }),
    ...(contentType && { contentType }),
  };

  const docRef = await db.collection('user_strikes').add(strike);

  // Update user document with strike count
  await db.collection('users').doc(userId).set({
    moderationStatus: {
      activeStrikes: strikeType === 'strike' ? activeStrikes + 1 : activeStrikes,
      activeWarnings: strikeType === 'warning' ? activeWarnings + 1 : activeWarnings,
      isSuspended: strikeType === 'suspension',
      suspendedUntil: strikeType === 'suspension' ? expiresAt : null,
      lastStrikeAt: admin.firestore.Timestamp.now(),
    },
  }, { merge: true });

  // Check for permanent ban
  if (activeStrikes + 1 >= STRIKE_RULES.PERMANENT_BAN_STRIKES) {
    await triggerPermanentBan(userId, 'Exceeded maximum strike count');
  }

  console.log(`Recorded ${strikeType} for user ${userId}: ${reason}`);

  return {
    id: docRef.id,
    ...strike,
  } as UserStrike;
}

/**
 * Trigger permanent ban for severe violations
 */
async function triggerPermanentBan(userId: string, reason: string): Promise<void> {
  console.log(`Triggering permanent ban for user ${userId}: ${reason}`);

  try {
    // Disable Firebase Auth account
    await admin.auth().updateUser(userId, { disabled: true });

    // Mark user as permanently banned
    await db.collection('users').doc(userId).set({
      moderationStatus: {
        isPermanentlyBanned: true,
        permanentBanReason: reason,
        permanentBanAt: admin.firestore.Timestamp.now(),
      },
    }, { merge: true });

    // Log the action
    await db.collection('adminLogs').add({
      action: 'automatic_permanent_ban',
      targetUserId: userId,
      reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error triggering permanent ban:', error);
  }
}

/**
 * Delete or hide violating content
 */
async function removeViolatingContent(
  contentType: ModerationQueueItem['contentType'],
  contentId: string,
  softDelete: boolean = true,
): Promise<void> {
  const collectionMap: Record<ModerationQueueItem['contentType'], string> = {
    story: 'stories',
    post: 'posts',
    comment: 'comments',
    profile: 'profiles',
  };

  const collection = collectionMap[contentType];
  if (!collection) return;

  const docRef = db.collection(collection).doc(contentId);

  if (softDelete) {
    // Soft delete - hide content but keep for review
    await docRef.update({
      isHidden: true,
      hiddenReason: 'Content policy violation',
      hiddenAt: admin.firestore.Timestamp.now(),
    });
  } else {
    // Hard delete
    await docRef.delete();
  }

  console.log(`${softDelete ? 'Hidden' : 'Deleted'} ${contentType} ${contentId}`);
}

// =============================================================================
// STORAGE TRIGGER: Scan uploaded media
// =============================================================================

/**
 * Triggered when a file is uploaded to Firebase Storage.
 * Scans images in story and profile directories for policy violations.
 */
export const moderateUploadedMedia = onObjectFinalized(
  {
    bucket: process.env.STORAGE_BUCKET,
    memory: '512MiB',
    timeoutSeconds: 120,
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    // Only process images
    if (!contentType?.startsWith('image/')) {
      console.log(`Skipping non-image: ${filePath}`);
      return;
    }

    // Parse file path to determine content type
    // Expected paths: stories/{userId}/{storyId}/media.jpg, profile_avatars/{userId}.jpg
    const pathParts = filePath.split('/');

    let moderationContentType: ModerationQueueItem['contentType'] | null = null;
    let userId: string | null = null;
    let contentId: string | null = null;

    if (pathParts[0] === 'stories' && pathParts.length >= 3) {
      moderationContentType = 'story';
      userId = pathParts[1];
      contentId = pathParts[2];
    } else if (pathParts[0] === 'profile_avatars') {
      moderationContentType = 'profile';
      userId = pathParts[1]?.replace(/\.[^.]+$/, ''); // Remove extension
      contentId = userId;
    } else {
      console.log(`Skipping unmonitored path: ${filePath}`);
      return;
    }

    if (!userId || !contentId) {
      console.log(`Could not parse path: ${filePath}`);
      return;
    }

    // Check if user is allowed to upload (not suspended)
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData?.moderationStatus?.isSuspended) {
      const suspendedUntil = userData.moderationStatus.suspendedUntil?.toDate();
      if (suspendedUntil && suspendedUntil > new Date()) {
        console.log(`User ${userId} is suspended, removing content`);
        // Delete the uploaded file
        const bucket = admin.storage().bucket(event.data.bucket);
        await bucket.file(filePath).delete();
        return;
      }
    }

    // Use GCS URI for Vision API (doesn't require signBlob permission)
    // The Vision API service account has access to read from GCS
    const gcsUri = `gs://${event.data.bucket}/${filePath}`;

    // Analyze image
    console.log(`Analyzing ${moderationContentType}: ${contentId} from ${gcsUri}`);
    const result = await analyzeImageWithVision(gcsUri);

    // Get a public URL for storing in queue (for admin preview)
    const bucket = admin.storage().bucket(event.data.bucket);
    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${event.data.bucket}/o/${encodeURIComponent(filePath)}?alt=media`;

    // Store moderation result
    await db.collection('content_moderation').doc(`${moderationContentType}_${contentId}`).set({
      contentType: moderationContentType,
      contentId,
      userId,
      filePath,
      result,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Take action based on result
    if (result.action === 'reject') {
      console.log(`Auto-rejecting ${moderationContentType} ${contentId}`);

      // Delete the uploaded file
      await bucket.file(filePath).delete();

      // Remove the content document
      await removeViolatingContent(moderationContentType, contentId, false);

      // Record strike against user
      await recordUserStrike(
        userId,
        `Auto-rejected ${moderationContentType}: ${result.details}`,
        contentId,
        moderationContentType,
      );

    } else if (result.action === 'review') {
      console.log(`Flagging ${moderationContentType} ${contentId} for review`);

      // Add to review queue
      await addToModerationQueue(
        moderationContentType,
        contentId,
        userId,
        result,
        publicUrl,
      );

    } else if (result.action === 'flag') {
      // Flag but don't remove - just log
      console.log(`Flagged ${moderationContentType} ${contentId}: ${result.details}`);
    }
  },
);

// =============================================================================
// FIRESTORE TRIGGER: Scan new stories for text content
// =============================================================================

export const moderateNewStory = onDocumentCreated(
  'stories/{storyId}',
  async (event) => {
    const storyData = event.data?.data();
    if (!storyData) return;

    const storyId = event.params.storyId;
    const userId = storyData.authorId as string;

    // Check text content (captions, overlays, hashtags)
    const textToCheck = [
      storyData.textOverlay?.text,
      ...(storyData.hashtags || []),
    ].filter(Boolean).join(' ');

    if (textToCheck.length > 0) {
      const result = analyzeText(textToCheck);

      if (!result.passed) {
        console.log(`Story ${storyId} text violation: ${result.details}`);

        // Remove the story
        await removeViolatingContent('story', storyId, false);

        // Record strike
        await recordUserStrike(
          userId,
          `Story text violation: ${result.details}`,
          storyId,
          'story',
        );
      } else if (result.action === 'review') {
        await addToModerationQueue('story', storyId, userId, result, undefined, textToCheck);
      }
    }
  },
);

// =============================================================================
// FIRESTORE TRIGGER: Scan new posts
// =============================================================================

export const moderateNewPost = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const postData = event.data?.data();
    if (!postData) return;

    const postId = event.params.postId;
    const userId = postData.authorId as string;
    const content = postData.content as string;

    const result = analyzeText(content);

    if (!result.passed) {
      console.log(`Post ${postId} text violation: ${result.details}`);

      await removeViolatingContent('post', postId, false);
      await recordUserStrike(userId, `Post violation: ${result.details}`, postId, 'post');

    } else if (result.action === 'review') {
      await addToModerationQueue('post', postId, userId, result, undefined, content);
    }
  },
);

// =============================================================================
// FIRESTORE TRIGGER: Scan new comments
// =============================================================================

export const moderateNewComment = onDocumentCreated(
  'comments/{commentId}',
  async (event) => {
    const commentData = event.data?.data();
    if (!commentData) return;

    const commentId = event.params.commentId;
    const userId = commentData.authorId as string;
    const content = commentData.content as string;

    const result = analyzeText(content);

    if (!result.passed) {
      console.log(`Comment ${commentId} text violation: ${result.details}`);

      await removeViolatingContent('comment', commentId, false);
      await recordUserStrike(userId, `Comment violation: ${result.details}`, commentId, 'comment');

    } else if (result.action === 'review') {
      await addToModerationQueue('comment', commentId, userId, result, undefined, content);
    }
  },
);

// =============================================================================
// CALLABLE: Manual text moderation check
// =============================================================================

export const checkTextContent = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const { text, contentType, contentId } = request.data as {
      text: string;
      contentType?: string;
      contentId?: string;
    };

    if (!text || typeof text !== 'string') {
      throw new HttpsError('invalid-argument', 'Text is required');
    }

    const result = analyzeText(text);

    // Log the check
    await db.collection('moderation_checks').add({
      userId: request.auth.uid,
      text: text.substring(0, 500), // Truncate for storage
      result,
      contentType,
      contentId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return result;
  },
);

// =============================================================================
// CALLABLE: Get user's moderation status
// =============================================================================

export const getModerationStatus = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const userId = request.auth.uid;

    // Get user's strikes
    const strikesSnap = await db.collection('user_strikes')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    const strikes = strikesSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString(),
      expiresAt: doc.data().expiresAt?.toDate?.()?.toISOString(),
    }));

    // Get user's moderation status
    const userDoc = await db.collection('users').doc(userId).get();
    const moderationStatus = userDoc.data()?.moderationStatus || {};

    return {
      strikes,
      status: {
        activeStrikes: moderationStatus.activeStrikes || 0,
        activeWarnings: moderationStatus.activeWarnings || 0,
        isSuspended: moderationStatus.isSuspended || false,
        suspendedUntil: moderationStatus.suspendedUntil?.toDate?.()?.toISOString(),
        isPermanentlyBanned: moderationStatus.isPermanentlyBanned || false,
      },
    };
  },
);

// =============================================================================
// CALLABLE: Acknowledge strike (user action)
// =============================================================================

export const acknowledgeStrike = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const { strikeId } = request.data as { strikeId: string };

    if (!strikeId) {
      throw new HttpsError('invalid-argument', 'Strike ID required');
    }

    const strikeDoc = await db.collection('user_strikes').doc(strikeId).get();

    if (!strikeDoc.exists) {
      throw new HttpsError('not-found', 'Strike not found');
    }

    if (strikeDoc.data()?.userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Not your strike');
    }

    await strikeDoc.ref.update({
      acknowledged: true,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// =============================================================================
// CALLABLE: Admin - Review moderation queue item
// =============================================================================

export const reviewModerationItem = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    // Check admin status
    const adminDoc = await db.collection('admins').doc(request.auth.uid).get();
    if (!adminDoc.exists) {
      throw new HttpsError('permission-denied', 'Admin access required');
    }

    const { itemId, action, notes } = request.data as {
      itemId: string;
      action: 'approve' | 'reject';
      notes?: string;
    };

    if (!itemId || !action) {
      throw new HttpsError('invalid-argument', 'Item ID and action required');
    }

    const itemDoc = await db.collection('moderation_queue').doc(itemId).get();

    if (!itemDoc.exists) {
      throw new HttpsError('not-found', 'Item not found');
    }

    const item = itemDoc.data() as ModerationQueueItem;

    // Update queue item
    await itemDoc.ref.update({
      status: action === 'approve' ? 'approved' : 'rejected',
      reviewedBy: request.auth.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewNotes: notes || null,
    });

    if (action === 'reject') {
      // Remove the content
      await removeViolatingContent(item.contentType, item.contentId, false);

      // Record strike against user
      await recordUserStrike(
        item.userId,
        `Manual review rejection: ${notes || 'Policy violation'}`,
        item.contentId,
        item.contentType,
      );
    }

    // Log the review
    await db.collection('adminLogs').add({
      action: 'moderation_review',
      adminId: request.auth.uid,
      itemId,
      decision: action,
      notes,
      contentType: item.contentType,
      contentId: item.contentId,
      targetUserId: item.userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// =============================================================================
// CALLABLE: Admin - Get moderation queue
// =============================================================================

export const getModerationQueue = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    // Check admin status
    const adminDoc = await db.collection('admins').doc(request.auth.uid).get();
    if (!adminDoc.exists) {
      throw new HttpsError('permission-denied', 'Admin access required');
    }

    const { status, limit: queryLimit } = request.data as {
      status?: 'pending' | 'approved' | 'rejected';
      limit?: number;
    };

    let query: admin.firestore.Query = db.collection('moderation_queue')
      .orderBy('createdAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    query = query.limit(queryLimit || 50);

    const snapshot = await query.get();

    const items = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString(),
      reviewedAt: doc.data().reviewedAt?.toDate?.()?.toISOString(),
    }));

    return { items };
  },
);

// =============================================================================
// SCHEDULED: Clean up expired strikes
// =============================================================================

export const cleanupExpiredStrikes = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'UTC',
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // Find expired strikes
    const expiredSnap = await db.collection('user_strikes')
      .where('expiresAt', '<', now)
      .get();

    if (expiredSnap.empty) {
      console.log('No expired strikes to clean up');
      return;
    }

    const batch = db.batch();
    const userUpdates: Map<string, { strikes: number; warnings: number }> = new Map();

    for (const doc of expiredSnap.docs) {
      const strike = doc.data();

      // Track user counts to update
      const current = userUpdates.get(strike.userId) || { strikes: 0, warnings: 0 };
      if (strike.type === 'strike') {
        current.strikes++;
      } else if (strike.type === 'warning') {
        current.warnings++;
      }
      userUpdates.set(strike.userId, current);

      // Delete the expired strike
      batch.delete(doc.ref);
    }

    await batch.commit();

    // Update user moderation status
    for (const [userId, counts] of userUpdates) {
      const userRef = db.collection('users').doc(userId);
      await userRef.set({
        moderationStatus: {
          activeStrikes: admin.firestore.FieldValue.increment(-counts.strikes),
          activeWarnings: admin.firestore.FieldValue.increment(-counts.warnings),
        },
      }, { merge: true });
    }

    console.log(`Cleaned up ${expiredSnap.size} expired strikes`);
  },
);

// =============================================================================
// SCHEDULED: Lift expired suspensions
// =============================================================================

export const liftExpiredSuspensions = onSchedule(
  {
    schedule: 'every 1 hours',
    timeZone: 'UTC',
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // Find suspended users whose suspension has expired
    const suspendedSnap = await db.collection('users')
      .where('moderationStatus.isSuspended', '==', true)
      .where('moderationStatus.suspendedUntil', '<', now)
      .get();

    if (suspendedSnap.empty) {
      console.log('No suspensions to lift');
      return;
    }

    const batch = db.batch();

    for (const doc of suspendedSnap.docs) {
      batch.update(doc.ref, {
        'moderationStatus.isSuspended': false,
        'moderationStatus.suspendedUntil': null,
      });
    }

    await batch.commit();
    console.log(`Lifted ${suspendedSnap.size} expired suspensions`);
  },
);
