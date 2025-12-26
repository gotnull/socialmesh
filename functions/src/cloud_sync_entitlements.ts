/**
 * Cloud Sync Entitlement Functions
 * 
 * Handles RevenueCat webhooks and user entitlement management for cloud sync feature.
 * 
 * MIGRATION NOTE (functions.config() → process.env):
 * As of March 2026, functions.config() is deprecated. This module now uses
 * process.env for configuration. Set values in functions/.env or Firebase secrets.
 */

import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Configuration from environment variables (replaces functions.config())
const REVENUECAT_WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET;
const ADMIN_KEY = process.env.ADMIN_KEY;

interface RevenueCatWebhookEvent {
  api_version: string;
  event: {
    type: string;
    app_user_id: string;
    product_id: string;
    entitlement_ids: string[];
    expiration_at_ms: number | null;
    purchased_at_ms: number;
    environment: 'SANDBOX' | 'PRODUCTION';
    store: 'APP_STORE' | 'PLAY_STORE';
    period_type: 'NORMAL' | 'TRIAL' | 'INTRO';
    grace_period_expiration_at_ms?: number | null;
  };
}

type CloudSyncStatus = 'active' | 'expired' | 'grandfathered' | 'grace_period';

interface UserEntitlement {
  cloud_sync: CloudSyncStatus;
  source: 'subscription' | 'legacy';
  expires_at: admin.firestore.Timestamp | null;
  grace_period_ends_at: admin.firestore.Timestamp | null;
  product_id: string | null;
  revenuecat_app_user_id: string;
  last_sync_at: admin.firestore.Timestamp | null;
  created_at: admin.firestore.Timestamp;
  updated_at: admin.firestore.Timestamp;
}

/**
 * Verify RevenueCat webhook signature
 */
function verifyWebhookSignature(
  payload: string,
  signature: string | undefined
): boolean {
  if (!REVENUECAT_WEBHOOK_SECRET || !signature) {
    console.warn('Webhook signature verification skipped - no secret configured');
    return true; // Skip verification if not configured (dev mode)
  }

  const expectedSignature = crypto
    .createHmac('sha256', REVENUECAT_WEBHOOK_SECRET)
    .update(payload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

/**
 * RevenueCat webhook handler
 * Processes subscription events and updates user entitlements
 */
export const onRevenueCatWebhook = onRequest(
  { cors: false },
  async (req, res) => {
    // Only accept POST requests
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Verify signature
    const signature = req.headers['x-revenuecat-signature'] as string | undefined;
    const rawBody = JSON.stringify(req.body);

    if (!verifyWebhookSignature(rawBody, signature)) {
      console.error('Invalid webhook signature');
      res.status(401).send('Unauthorized');
      return;
    }

    try {
      const webhookData = req.body as RevenueCatWebhookEvent;
      const event = webhookData.event;

      console.log(`Processing RevenueCat event: ${event.type} for user ${event.app_user_id}`);

      // Only process cloud_sync entitlement
      if (!event.entitlement_ids?.includes('cloud_sync')) {
        console.log('Event does not include cloud_sync entitlement, skipping');
        res.status(200).send('OK');
        return;
      }

      const uid = event.app_user_id;
      const userEntitlementRef = db.collection('user_entitlements').doc(uid);

      // Check if user is grandfathered (don't override)
      const existingDoc = await userEntitlementRef.get();
      if (existingDoc.exists) {
        const existingData = existingDoc.data() as UserEntitlement;
        if (existingData.cloud_sync === 'grandfathered') {
          console.log(`User ${uid} is grandfathered, not updating`);
          res.status(200).send('OK');
          return;
        }
      }

      let newStatus: CloudSyncStatus;
      let expiresAt: admin.firestore.Timestamp | null = null;
      let gracePeriodEndsAt: admin.firestore.Timestamp | null = null;

      switch (event.type) {
        case 'INITIAL_PURCHASE':
        case 'RENEWAL':
        case 'PRODUCT_CHANGE':
        case 'UNCANCELLATION':
          newStatus = 'active';
          if (event.expiration_at_ms) {
            expiresAt = admin.firestore.Timestamp.fromMillis(event.expiration_at_ms);
          }
          break;

        case 'BILLING_ISSUE':
          newStatus = 'grace_period';
          if (event.expiration_at_ms) {
            expiresAt = admin.firestore.Timestamp.fromMillis(event.expiration_at_ms);
          }
          if (event.grace_period_expiration_at_ms) {
            gracePeriodEndsAt = admin.firestore.Timestamp.fromMillis(
              event.grace_period_expiration_at_ms
            );
          }
          break;

        case 'EXPIRATION':
        case 'CANCELLATION':
          newStatus = 'expired';
          if (event.expiration_at_ms) {
            expiresAt = admin.firestore.Timestamp.fromMillis(event.expiration_at_ms);
          }
          break;

        default:
          console.log(`Unhandled event type: ${event.type}`);
          res.status(200).send('OK');
          return;
      }

      const updateData: Partial<UserEntitlement> = {
        cloud_sync: newStatus,
        source: 'subscription',
        expires_at: expiresAt,
        grace_period_ends_at: gracePeriodEndsAt,
        product_id: event.product_id,
        revenuecat_app_user_id: uid,
        updated_at: admin.firestore.FieldValue.serverTimestamp() as admin.firestore.Timestamp,
      };

      await userEntitlementRef.set(
        {
          ...updateData,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log(`Updated entitlement for ${uid}: ${newStatus}`);
      res.status(200).send('OK');
    } catch (error) {
      console.error('Error processing webhook:', error);
      res.status(500).send('Internal Server Error');
    }
  }
);

/**
 * Cloud Function to enforce sync writes
 * Triggered before any write to synced data collections
 */
export const onSyncWrite = onDocumentCreated(
  'sync_data/{userId}/{collection}/{docId}',
  async (event) => {
    const userId = event.params.userId;
    const snap = event.data;

    if (!snap) {
      console.log('No document data');
      return;
    }

    try {
      // Check entitlement
      const entitlementDoc = await db
        .collection('user_entitlements')
        .doc(userId)
        .get();

      if (!entitlementDoc.exists) {
        console.log(`No entitlement for user ${userId}, rejecting write`);
        await snap.ref.delete();
        return;
      }

      const entitlement = entitlementDoc.data() as UserEntitlement;

      // Check if user can write
      const canWrite =
        entitlement.cloud_sync === 'active' ||
        entitlement.cloud_sync === 'grace_period' ||
        entitlement.cloud_sync === 'grandfathered';

      if (!canWrite) {
        console.log(`User ${userId} does not have write access, rejecting`);
        await snap.ref.delete();
        return;
      }

      // Update last sync timestamp
      await db.collection('user_entitlements').doc(userId).update({
        last_sync_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Sync write allowed for user ${userId}`);
    } catch (error) {
      console.error('Error checking entitlement:', error);
      // On error, reject the write to be safe
      await snap.ref.delete();
    }
  }
);

/**
 * Firestore security rules enforcement helper
 * Call this from security rules to check entitlement
 */
export const checkCloudSyncEntitlement = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const uid = request.auth.uid;

    try {
      const entitlementDoc = await db
        .collection('user_entitlements')
        .doc(uid)
        .get();

      if (!entitlementDoc.exists) {
        return { canWrite: false, canRead: false, status: 'none' };
      }

      const entitlement = entitlementDoc.data() as UserEntitlement;

      const canWrite =
        entitlement.cloud_sync === 'active' ||
        entitlement.cloud_sync === 'grace_period' ||
        entitlement.cloud_sync === 'grandfathered';

      const canRead = entitlement.cloud_sync != null;

      return {
        canWrite,
        canRead,
        status: entitlement.cloud_sync,
        expiresAt: entitlement.expires_at?.toDate().toISOString() || null,
      };
    } catch (error) {
      console.error('Error checking entitlement:', error);
      throw new HttpsError('internal', 'Error checking entitlement');
    }
  }
);

/**
 * Migration function to grandfather existing cloud sync users
 * Run this ONCE before enabling subscription enforcement
 */
export const grandfatherExistingUsers = onRequest(
  { cors: false },
  async (req, res) => {
    // Require admin authentication (use a secret key)
    const adminKey = req.headers['x-admin-key'];
    if (!ADMIN_KEY || adminKey !== ADMIN_KEY) {
      res.status(401).send('Unauthorized');
      return;
    }

    const CUTOFF_DATE = new Date('2025-02-01T00:00:00Z');
    let grandfatheredCount = 0;

    try {
      // Find users who have used cloud sync before cutoff
      const usersSnapshot = await db
        .collection('users')
        .where('cloud_sync_used_at', '<', admin.firestore.Timestamp.fromDate(CUTOFF_DATE))
        .get();

      const batch = db.batch();

      for (const userDoc of usersSnapshot.docs) {
        const entitlementRef = db.collection('user_entitlements').doc(userDoc.id);

        batch.set(
          entitlementRef,
          {
            cloud_sync: 'grandfathered',
            source: 'legacy',
            expires_at: null,
            grace_period_ends_at: null,
            product_id: null,
            revenuecat_app_user_id: userDoc.id,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        grandfatheredCount++;
      }

      await batch.commit();

      console.log(`Grandfathered ${grandfatheredCount} users`);
      res.status(200).json({
        success: true,
        grandfatheredCount,
      });
    } catch (error) {
      console.error('Error grandfathering users:', error);
      res.status(500).send('Internal Server Error');
    }
  }
);

/**
 * Rate limiting for sync writes (per user)
 * Prevents abuse of sync feature
 */
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const MAX_WRITES_PER_WINDOW = 100;

export const rateLimitSyncWrite = onDocumentCreated(
  'sync_data/{userId}/{collection}/{docId}',
  async (event) => {
    const userId = event.params.userId;
    const snap = event.data;

    if (!snap) {
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const windowStart = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - RATE_LIMIT_WINDOW_MS
    );

    try {
      // Count recent writes
      const recentWritesSnapshot = await db
        .collection('sync_data')
        .doc(userId)
        .collection('_rate_limit')
        .where('timestamp', '>', windowStart)
        .get();

      if (recentWritesSnapshot.size >= MAX_WRITES_PER_WINDOW) {
        console.log(`Rate limit exceeded for user ${userId}`);
        await snap.ref.delete();
        return;
      }

      // Log this write for rate limiting
      await db
        .collection('sync_data')
        .doc(userId)
        .collection('_rate_limit')
        .add({
          timestamp: now,
        });
    } catch (error) {
      console.error('Error checking rate limit:', error);
    }
  }
);
