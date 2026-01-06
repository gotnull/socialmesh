/**
 * Socialmesh Firebase Cloud Functions
 *
 * Handles:
 * - Widget Marketplace API
 * - Rich Share Links (Open Graph)
 * - Admin operations
 * 
 * MIGRATION: Uses process.env for config (functions.config() deprecated March 2026)
 */

import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { z } from 'zod';

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

// =============================================================================
// ENVIRONMENT CONFIG - Replaces functions.config()
// =============================================================================
const APP_BASE_URL = process.env.APP_BASE_URL || 'https://socialmesh.app';
const APP_STORE_URL = process.env.APP_STORE_URL || 'https://apps.apple.com/app/id6742694642';
const PLAY_STORE_URL = process.env.PLAY_STORE_URL || 'https://play.google.com/store/apps/details?id=com.gotnull.socialmesh';
const IOS_APP_STORE_ID = process.env.IOS_APP_STORE_ID || '6742694642';
const ANDROID_PACKAGE = process.env.ANDROID_PACKAGE || 'com.gotnull.socialmesh';

// =============================================================================
// TYPES & SCHEMAS
// =============================================================================

const WidgetUploadSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  tags: z.array(z.string()).max(10).optional(),
  category: z.string().optional(),
  root: z.record(z.unknown()),
});

const WidgetSubmitSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  size: z.string().optional(),
  tags: z.array(z.string()).max(10).optional(),
  root: z.record(z.unknown()),
});

const DuplicateCheckSchema = z.object({
  name: z.string().min(1),
  schema: z.record(z.unknown()),
});

const RatingSchema = z.object({
  rating: z.number().int().min(1).max(5),
});

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

async function verifyAuth(authHeader: string | undefined): Promise<admin.auth.DecodedIdToken | null> {
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

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

/**
 * Serialize Firestore document data, converting Timestamps to ISO strings
 */
function serializeDoc(data: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value instanceof admin.firestore.Timestamp) {
      result[key] = value.toDate().toISOString();
    } else if (value && typeof value === 'object' && '_seconds' in value) {
      // Handle already-serialized timestamps
      const ts = value as { _seconds: number; _nanoseconds: number };
      result[key] = new Date(ts._seconds * 1000).toISOString();
    } else if (Array.isArray(value)) {
      result[key] = value.map(item =>
        item && typeof item === 'object' ? serializeDoc(item as Record<string, unknown>) : item
      );
    } else if (value && typeof value === 'object') {
      result[key] = serializeDoc(value as Record<string, unknown>);
    } else {
      result[key] = value;
    }
  }
  return result;
}

// =============================================================================
// WIDGET MARKETPLACE API
// =============================================================================

/**
 * Browse widgets with pagination, filtering, and sorting
 */
export const widgetsBrowse = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const category = req.query.category as string | undefined;
    const sort = (req.query.sort as string) || 'installs';
    const search = req.query.q as string | undefined;

    let query: admin.firestore.Query = db.collection('widgets')
      .where('status', '==', 'published');

    if (category) {
      query = query.where('category', '==', category);
    }

    // Sort
    const sortField = sort === 'newest' ? 'createdAt' :
      sort === 'rating' ? 'averageRating' :
        sort === 'name' ? 'name' : 'installs';
    const sortDir = sort === 'name' ? 'asc' : 'desc';
    query = query.orderBy(sortField, sortDir);

    // Pagination
    query = query.limit(limit).offset((page - 1) * limit);

    const snapshot = await query.get();
    const widgets = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    // Get total count
    const countSnapshot = await db.collection('widgets')
      .where('status', '==', 'published')
      .count()
      .get();

    // Filter by search (client-side for now, could use Algolia for better search)
    let filtered = widgets;
    if (search) {
      const searchLower = search.toLowerCase();
      filtered = widgets.filter((w: Record<string, unknown>) =>
        (w.name as string)?.toLowerCase().includes(searchLower) ||
        (w.description as string)?.toLowerCase().includes(searchLower) ||
        (w.tags as string[])?.some(t => t.toLowerCase().includes(searchLower))
      );
    }

    res.json({
      widgets: filtered,
      page,
      limit,
      total: countSnapshot.data().count,
      hasMore: page * limit < countSnapshot.data().count,
    });
  } catch (error) {
    console.error('Browse error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get featured widgets
 */
export const widgetsFeatured = onRequest({ cors: true }, async (_req, res) => {
  try {
    const snapshot = await db.collection('widgets')
      .where('status', '==', 'published')
      .where('featured', '==', true)
      .orderBy('installs', 'desc')
      .limit(10)
      .get();

    const widgets = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(widgets);
  } catch (error) {
    console.error('Featured error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get widget categories
 */
export const widgetsCategories = onRequest({ cors: true }, async (_req, res) => {
  try {
    const snapshot = await db.collection('categories').orderBy('order').get();
    const categories = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json(categories);
  } catch (error) {
    console.error('Categories error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get widget details
 */
export const widgetsGet = onRequest({ cors: true }, async (req, res) => {
  try {
    const id = req.path.split('/').pop();
    if (!id) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const doc = await db.collection('widgets').doc(id).get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    res.json(serializeDoc({ id: doc.id, ...doc.data() }));
  } catch (error) {
    console.error('Get widget error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get widget schema for preview (does NOT increment install count)
 */
export const widgetsPreview = onRequest({ cors: true }, async (req, res) => {
  try {
    const id = req.query.id as string;
    if (!id) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const docRef = db.collection('widgets').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    const data = doc.data();
    res.json(serializeDoc(data?.schema || {}));
  } catch (error) {
    console.error('Preview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Download/install widget (increments install count)
 */
export const widgetsDownload = onRequest({ cors: true }, async (req, res) => {
  try {
    const id = req.query.id as string;
    if (!id) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const docRef = db.collection('widgets').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    // Increment installs
    await docRef.update({
      installs: admin.firestore.FieldValue.increment(1),
    });

    const data = doc.data();
    res.json(serializeDoc(data?.schema || {}));
  } catch (error) {
    console.error('Download error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Upload a new widget
 */
export const widgetsUpload = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const body = WidgetUploadSchema.parse(req.body);

    const widget = {
      name: body.name,
      description: body.description || '',
      author: user.name || user.email || 'Anonymous',
      authorId: user.uid,
      tags: body.tags || [],
      category: body.category || 'other',
      schema: {
        name: body.name,
        description: body.description,
        tags: body.tags,
        root: body.root,
      },
      status: 'published',
      featured: false,
      installs: 0,
      ratingSum: 0,
      ratingCount: 0,
      averageRating: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('widgets').add(widget);

    res.status(201).json({ id: docRef.id, ...widget });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid widget data', details: error.errors });
    } else {
      console.error('Upload error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Rate a widget
 */
export const widgetsRate = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const widgetId = req.query.id as string;
    if (!widgetId) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const body = RatingSchema.parse(req.body);

    const widgetRef = db.collection('widgets').doc(widgetId);
    const widget = await widgetRef.get();

    if (!widget.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    // Store individual rating
    const ratingRef = db.collection('widgets').doc(widgetId)
      .collection('ratings').doc(user.uid);

    const existingRating = await ratingRef.get();
    const oldRating = existingRating.exists ? existingRating.data()?.rating || 0 : 0;

    await ratingRef.set({
      rating: body.rating,
      userId: user.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update widget aggregate
    const ratingDiff = body.rating - oldRating;
    const countDiff = existingRating.exists ? 0 : 1;

    await widgetRef.update({
      ratingSum: admin.firestore.FieldValue.increment(ratingDiff),
      ratingCount: admin.firestore.FieldValue.increment(countDiff),
    });

    // Recalculate average (done via trigger for consistency)

    res.json({ success: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid rating', details: error.errors });
    } else {
      console.error('Rate error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// =============================================================================
// WIDGET SUBMISSION & APPROVAL FLOW
// =============================================================================

// Admin UIDs - store in environment or Firestore in production
const ADMIN_UIDS = ['fulvio_admin_uid']; // Replace with actual admin UIDs

/**
 * Check if user is admin
 */
async function isAdmin(uid: string): Promise<boolean> {
  // Check hardcoded list first
  if (ADMIN_UIDS.includes(uid)) return true;

  // Check Firestore admins collection
  try {
    const adminDoc = await db.collection('admins').doc(uid).get();
    return adminDoc.exists;
  } catch {
    return false;
  }
}

/**
 * Submit widget for marketplace approval
 */
export const widgetsSubmit = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const body = WidgetSubmitSchema.parse(req.body);

    // Check for existing widget with similar name
    const existingSnapshot = await db.collection('widgets')
      .where('name', '==', body.name)
      .limit(1)
      .get();

    if (!existingSnapshot.empty) {
      const existing = existingSnapshot.docs[0];
      res.status(409).json({
        error: 'A widget with this name already exists',
        duplicateName: existing.data().name,
        duplicateId: existing.id,
      });
      return;
    }

    // Create widget with pending status
    const widget = {
      name: body.name,
      description: body.description || '',
      author: user.name || user.email || 'Anonymous',
      authorId: user.uid,
      tags: body.tags || [],
      category: 'general',
      schema: {
        id: body.id,
        name: body.name,
        description: body.description,
        size: body.size || 'medium',
        tags: body.tags,
        root: body.root,
      },
      status: 'pending', // Requires admin approval
      featured: false,
      installs: 0,
      ratingSum: 0,
      ratingCount: 0,
      averageRating: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = await db.collection('widgets').add(widget);

    res.status(201).json(serializeDoc({
      id: docRef.id,
      ...widget,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }));
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid widget data', details: error.errors });
    } else {
      console.error('Submit error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Check for duplicate/similar widgets before submission
 */
export const widgetsCheckDuplicate = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const body = DuplicateCheckSchema.parse(req.body);
    const nameLower = body.name.toLowerCase().trim();

    // Check for exact name match
    const exactSnapshot = await db.collection('widgets')
      .where('status', 'in', ['published', 'pending'])
      .get();

    let bestMatch: { id: string; name: string; score: number } | null = null;

    for (const doc of exactSnapshot.docs) {
      const data = doc.data();
      const existingName = (data.name as string || '').toLowerCase().trim();

      // Calculate simple similarity score
      let score = 0;

      // Exact match
      if (existingName === nameLower) {
        score = 1.0;
      } else {
        // Check for partial match (contains)
        if (existingName.includes(nameLower) || nameLower.includes(existingName)) {
          score = 0.8;
        } else {
          // Levenshtein-like similarity for short names
          const maxLen = Math.max(existingName.length, nameLower.length);
          const minLen = Math.min(existingName.length, nameLower.length);
          if (maxLen > 0 && minLen / maxLen > 0.7) {
            // Similar length, check character overlap
            const chars1 = new Set(existingName.split(''));
            const chars2 = new Set(nameLower.split(''));
            const intersection = [...chars1].filter(c => chars2.has(c)).length;
            score = intersection / Math.max(chars1.size, chars2.size);
          }
        }
      }

      if (score >= 0.7 && (!bestMatch || score > bestMatch.score)) {
        bestMatch = {
          id: doc.id,
          name: data.name,
          score,
        };
      }
    }

    if (bestMatch) {
      res.json({
        isDuplicate: true,
        duplicateId: bestMatch.id,
        duplicateName: bestMatch.name,
        similarityScore: bestMatch.score,
      });
    } else {
      res.json({
        isDuplicate: false,
      });
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid request', details: error.errors });
    } else {
      console.error('Duplicate check error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Get pending widgets for admin review
 */
export const widgetsAdminPending = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const snapshot = await db.collection('widgets')
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const widgets = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(widgets);
  } catch (error) {
    console.error('Admin pending error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Approve a pending widget
 */
export const widgetsApprove = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const widgetId = req.query.id as string;
    if (!widgetId) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const widgetRef = db.collection('widgets').doc(widgetId);
    const widget = await widgetRef.get();

    if (!widget.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    if (widget.data()?.status !== 'pending') {
      res.status(400).json({ error: 'Widget is not pending approval' });
      return;
    }

    await widgetRef.update({
      status: 'published',
      approvedBy: user.uid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: 'Widget approved' });
  } catch (error) {
    console.error('Approve error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Reject a pending widget
 */
export const widgetsReject = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const widgetId = req.query.id as string;
    if (!widgetId) {
      res.status(400).json({ error: 'Widget ID required' });
      return;
    }

    const reason = req.body?.reason as string;

    const widgetRef = db.collection('widgets').doc(widgetId);
    const widget = await widgetRef.get();

    if (!widget.exists) {
      res.status(404).json({ error: 'Widget not found' });
      return;
    }

    if (widget.data()?.status !== 'pending') {
      res.status(400).json({ error: 'Widget is not pending approval' });
      return;
    }

    await widgetRef.update({
      status: 'rejected',
      rejectedBy: user.uid,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectionReason: reason || 'No reason provided',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: 'Widget rejected' });
  } catch (error) {
    console.error('Reject error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =============================================================================
// FIRESTORE TRIGGERS
// =============================================================================

/**
 * Recalculate average rating when ratings change
 */
export const onRatingChange = onDocumentUpdated('widgets/{widgetId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (!before || !after) return;

  // Only recalculate if rating fields changed
  if (before.ratingSum === after.ratingSum && before.ratingCount === after.ratingCount) {
    return;
  }

  const averageRating = after.ratingCount > 0
    ? after.ratingSum / after.ratingCount
    : 0;

  await event.data?.after.ref.update({ averageRating });
});

/**
 * Initialize categories on first widget creation (one-time setup helper)
 */
export const onFirstWidget = onDocumentCreated('widgets/{widgetId}', async () => {
  const categoriesSnapshot = await db.collection('categories').limit(1).get();

  if (categoriesSnapshot.empty) {
    const defaultCategories = [
      { id: 'device-status', name: 'Device Status', icon: 'phone_android', order: 1 },
      { id: 'metrics', name: 'Metrics', icon: 'analytics', order: 2 },
      { id: 'charts', name: 'Charts', icon: 'bar_chart', order: 3 },
      { id: 'mesh', name: 'Mesh Network', icon: 'hub', order: 4 },
      { id: 'location', name: 'Location', icon: 'location_on', order: 5 },
      { id: 'weather', name: 'Weather', icon: 'cloud', order: 6 },
      { id: 'utility', name: 'Utility', icon: 'build', order: 7 },
      { id: 'other', name: 'Other', icon: 'category', order: 99 },
    ];

    const batch = db.batch();
    for (const cat of defaultCategories) {
      batch.set(db.collection('categories').doc(cat.id), cat);
    }
    await batch.commit();
  }
});

// =============================================================================
// RICH SHARE LINKS (Open Graph)
// =============================================================================

/**
 * Generate HTML page with Open Graph meta tags for rich sharing
 * Supports: /share/node/:id, /share/profile/:id, /share/widget/:id, /share/post/:id, /share/location
 */
export const share = onRequest(async (req, res) => {
  const path = req.path;
  const baseUrl = APP_BASE_URL;
  const appIcon = `${baseUrl}/images/app-icon.png`;

  // Parse the share path
  const parts = path.split('/').filter(Boolean);
  // parts[0] = 'share', parts[1] = type, parts[2] = id

  if (parts.length < 2) {
    res.redirect(baseUrl);
    return;
  }

  const type = parts[1];
  const id = parts[2];

  let title = 'Socialmesh';
  let description = 'The most advanced Meshtastic client for iOS & Android';
  let image = appIcon;
  let deepLink = 'socialmesh://';

  try {
    switch (type) {
      case 'node': {
        // Shared mesh node
        if (id) {
          const nodeDoc = await db.collection('shared_nodes').doc(id).get();
          if (nodeDoc.exists) {
            const node = nodeDoc.data();
            title = `${node?.name || 'Mesh Node'} on Socialmesh`;
            description = node?.description || 'View this mesh node in Socialmesh';
            deepLink = `socialmesh://node/${id}`;
          }
        }
        break;
      }

      case 'profile': {
        // Shared user profile
        if (id) {
          const profileDoc = await db.collection('profiles').doc(id).get();
          if (profileDoc.exists) {
            const profile = profileDoc.data();
            title = `${profile?.displayName || 'User'} on Socialmesh`;
            description = profile?.bio || 'Check out this Socialmesh user';
            if (profile?.avatarUrl) {
              image = profile.avatarUrl;
            }
            deepLink = `socialmesh://profile/${id}`;
          }
        }
        break;
      }

      case 'widget': {
        // Shared widget from marketplace
        if (id) {
          const widgetDoc = await db.collection('widgets').doc(id).get();
          if (widgetDoc.exists) {
            const widget = widgetDoc.data();
            title = `${widget?.name || 'Widget'} - Socialmesh Widget`;
            description = widget?.description || 'A custom widget for Socialmesh';
            deepLink = `socialmesh://widget/${id}`;
          }
        }
        break;
      }

      case 'post': {
        // Shared social post
        if (id) {
          const postDoc = await db.collection('posts').doc(id).get();
          if (postDoc.exists) {
            const post = postDoc.data();
            // Get author name
            let authorName = 'Someone';
            if (post?.authorId) {
              const authorDoc = await db.collection('profiles').doc(post.authorId).get();
              if (authorDoc.exists) {
                authorName = authorDoc.data()?.displayName || 'Someone';
              }
            }
            title = `${authorName} on Socialmesh`;
            // Truncate content for description
            const content = post?.content || '';
            description = content.length > 150 ? content.substring(0, 147) + '...' : content || 'View this post on Socialmesh';
            if (post?.imageUrl) {
              image = post.imageUrl;
            }
            deepLink = `socialmesh://post/${id}`;
          }
        }
        break;
      }

      case 'location': {
        // Shared location/waypoint
        const lat = req.query.lat as string;
        const lng = req.query.lng as string;
        const label = req.query.label as string;

        if (lat && lng) {
          title = label ? `${label} - Socialmesh Location` : 'Location on Socialmesh';
          description = `View this location at ${lat}, ${lng}`;
          deepLink = `socialmesh://location?lat=${lat}&lng=${lng}${label ? `&label=${encodeURIComponent(label)}` : ''}`;
        }
        break;
      }

      default:
        // Unknown type, redirect to app
        break;
    }
  } catch (error) {
    console.error('Share link error:', error);
  }

  // Generate HTML with Open Graph tags - matching socialmesh.app website design
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  
  <!-- Open Graph / Facebook -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="${baseUrl}${req.path}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${image}">
  <meta property="og:site_name" content="Socialmesh">
  
  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${image}">
  
  <!-- App Links -->
  <meta property="al:ios:app_store_id" content="${IOS_APP_STORE_ID}">
  <meta property="al:ios:app_name" content="Socialmesh">
  <meta property="al:ios:url" content="${deepLink}">
  <meta property="al:android:package" content="${ANDROID_PACKAGE}">
  <meta property="al:android:app_name" content="Socialmesh">
  <meta property="al:android:url" content="${deepLink}">
  
  <!-- Fonts (matching main website) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  
  <style>
    :root {
      --bg-primary: #1F2633;
      --accent-magenta: #E91E8C;
      --accent-purple: #8B5CF6;
      --accent-blue: #4F6AF6;
      --accent-glow: rgba(233, 30, 140, 0.4);
      --text-primary: #FFFFFF;
      --text-secondary: #D1D5DB;
      --text-muted: #9CA3AF;
      --gradient-brand: linear-gradient(135deg, #E91E8C 0%, #8B5CF6 50%, #4F6AF6 100%);
    }
    
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    body {
      font-family: 'JetBrains Mono', 'Inter', -apple-system, BlinkMacSystemFont, monospace;
      background: var(--bg-primary);
      color: var(--text-primary);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      text-align: center;
      position: relative;
      overflow: hidden;
    }
    
    /* Animated mesh background */
    .mesh-bg {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      overflow: hidden;
    }
    
    .mesh-bg::before {
      content: '';
      position: absolute;
      top: -50%; left: -50%;
      width: 200%; height: 200%;
      background:
        radial-gradient(circle at 20% 20%, rgba(233, 30, 140, 0.15) 0%, transparent 40%),
        radial-gradient(circle at 80% 80%, rgba(139, 92, 246, 0.12) 0%, transparent 40%),
        radial-gradient(circle at 60% 30%, rgba(79, 106, 246, 0.1) 0%, transparent 35%);
      animation: meshFloat 25s ease-in-out infinite;
    }
    
    .mesh-bg::after {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background:
        radial-gradient(ellipse at 50% 0%, rgba(233, 30, 140, 0.08) 0%, transparent 50%),
        radial-gradient(ellipse at 100% 50%, rgba(139, 92, 246, 0.06) 0%, transparent 40%);
      animation: meshPulse 8s ease-in-out infinite alternate;
    }
    
    @keyframes meshFloat {
      0%, 100% { transform: translate(0, 0) rotate(0deg); }
      25% { transform: translate(3%, 2%) rotate(2deg); }
      50% { transform: translate(1%, -2%) rotate(-1deg); }
      75% { transform: translate(-2%, 1%) rotate(1deg); }
    }
    
    @keyframes meshPulse {
      0% { opacity: 0.6; }
      100% { opacity: 1; }
    }
    
    /* Grid overlay */
    .grid-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: -1;
      background-image:
        linear-gradient(rgba(233, 30, 140, 0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(233, 30, 140, 0.03) 1px, transparent 1px);
      background-size: 80px 80px;
      mask-image: radial-gradient(ellipse at center, black 0%, transparent 75%);
    }
    
    .container {
      position: relative;
      z-index: 1;
      max-width: 480px;
      animation: fadeIn 0.8s ease-out;
    }
    
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }
    
    .logo {
      width: 100px;
      height: 100px;
      border-radius: 24px;
      margin-bottom: 32px;
      box-shadow: 0 8px 40px var(--accent-glow);
      animation: logoGlow 3s ease-in-out infinite alternate;
    }
    
    @keyframes logoGlow {
      0% { box-shadow: 0 8px 40px rgba(233, 30, 140, 0.3); }
      100% { box-shadow: 0 8px 60px rgba(233, 30, 140, 0.5); }
    }
    
    h1 {
      font-size: 28px;
      font-weight: 700;
      margin-bottom: 12px;
      letter-spacing: -0.5px;
    }
    
    .subtitle {
      font-size: 14px;
      color: var(--text-muted);
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    
    p {
      color: var(--text-secondary);
      margin-bottom: 40px;
      max-width: 400px;
      line-height: 1.6;
      font-size: 15px;
    }
    
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      background: var(--gradient-brand);
      color: white;
      padding: 18px 40px;
      border-radius: 14px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
      margin-bottom: 32px;
      box-shadow: 0 4px 24px var(--accent-glow);
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
    }
    
    .btn::before {
      content: '';
      position: absolute;
      top: 0; left: -100%;
      width: 100%; height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
      transition: left 0.5s;
    }
    
    .btn:hover {
      transform: translateY(-3px);
      box-shadow: 0 8px 40px var(--accent-glow);
    }
    
    .btn:hover::before {
      left: 100%;
    }
    
    .store-badges {
      display: flex;
      gap: 16px;
      justify-content: center;
      flex-wrap: wrap;
    }
    
    .store-badge {
      transition: transform 0.3s ease, opacity 0.3s ease;
    }
    
    .store-badge:hover {
      transform: translateY(-3px);
      opacity: 0.9;
    }
    
    .store-badge img {
      height: 44px;
      width: auto;
    }
    
    .divider {
      width: 60px;
      height: 1px;
      background: linear-gradient(90deg, transparent, var(--accent-magenta), transparent);
      margin: 0 auto 24px;
    }
    
    .footer-text {
      margin-top: 48px;
      font-size: 13px;
      color: var(--text-muted);
    }
    
    .footer-text a {
      color: var(--accent-magenta);
      text-decoration: none;
    }
    
    .footer-text a:hover {
      text-decoration: underline;
    }
  </style>
  
  <script>
    // Only attempt deep link redirect on mobile devices
    var ua = navigator.userAgent.toLowerCase();
    var isMobile = ua.indexOf('iphone') > -1 || ua.indexOf('ipad') > -1 || ua.indexOf('android') > -1;
    
    if (isMobile) {
      // Try to open the app directly on mobile
      window.location.href = '${deepLink}';
      
      // Fallback to app store after delay if app didn't open
      setTimeout(function() {
        if (ua.indexOf('iphone') > -1 || ua.indexOf('ipad') > -1) {
          window.location.href = '${APP_STORE_URL}';
        } else if (ua.indexOf('android') > -1) {
          window.location.href = '${PLAY_STORE_URL}';
        }
      }, 2500);
    }
  </script>
</head>
<body>
  <div class="mesh-bg"></div>
  <div class="grid-overlay"></div>
  
  <div class="container">
    <img src="${appIcon}" alt="Socialmesh" class="logo">
    <h1>${escapeHtml(title)}</h1>
    <p class="subtitle">${type === 'node' ? 'MESH NODE' : type === 'profile' ? 'USER PROFILE' : type === 'widget' ? 'CUSTOM WIDGET' : type === 'post' ? 'SOCIAL POST' : type === 'location' ? 'SHARED LOCATION' : 'SOCIALMESH'}</p>
    <p>${escapeHtml(description)}</p>
    
    <a href="${deepLink}" class="btn">Open in Socialmesh</a>
    
    <div class="divider"></div>
    
    <div class="store-badges">
      <a href="${APP_STORE_URL}" class="store-badge" target="_blank" rel="noopener">
        <img src="${baseUrl}/images/app-store-badge.svg" alt="Download on the App Store">
      </a>
      <a href="${PLAY_STORE_URL}" class="store-badge" target="_blank" rel="noopener">
        <img src="${baseUrl}/images/google-play-badge.svg" alt="Get it on Google Play">
      </a>
    </div>
    
    <p class="footer-text">
      The most advanced Meshtastic client<br>
      <a href="${baseUrl}">socialmesh.app</a>
    </p>
  </div>
</body>
</html>`;

  res.set('Content-Type', 'text/html');
  res.send(html);
});

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// =============================================================================
// DEVICE SHOP API
// =============================================================================

const ProductSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().min(1).max(5000),
  shortDescription: z.string().max(500).optional(),
  category: z.enum(['node', 'antenna', 'enclosure', 'accessory', 'solar', 'module', 'kit']),
  price: z.number().positive(),
  compareAtPrice: z.number().optional(),
  currency: z.string().default('USD'),
  sellerId: z.string().min(1),
  sellerName: z.string().min(1),
  imageUrls: z.array(z.string().url()).min(1),
  frequencyBands: z.array(z.string()).optional(),
  chipset: z.string().optional(),
  loraChip: z.string().optional(),
  hasGps: z.boolean().optional(),
  hasWifi: z.boolean().optional(),
  hasBluetooth: z.boolean().optional(),
  hasDisplay: z.boolean().optional(),
  batteryMah: z.number().optional(),
  antennaConnector: z.string().optional(),
  externalUrl: z.string().url(),
  tags: z.array(z.string()).optional(),
  isFeatured: z.boolean().default(false),
  isInStock: z.boolean().default(true),
  stockQuantity: z.number().optional(),
  weight: z.number().optional(),
  dimensions: z.string().optional(),
});

const SellerSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(1000).optional(),
  logoUrl: z.string().url().optional(),
  websiteUrl: z.string().url(),
  contactEmail: z.string().email().optional(),
  isVerified: z.boolean().default(false),
  isOfficialPartner: z.boolean().default(false),
  countries: z.array(z.string()).optional(),
});

/**
 * Browse shop products with pagination and filtering
 */
export const shopBrowse = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
    const category = req.query.category as string | undefined;
    const sellerId = req.query.seller as string | undefined;
    const sort = (req.query.sort as string) || 'newest';
    const search = req.query.q as string | undefined;
    const featured = req.query.featured === 'true';
    const onSale = req.query.sale === 'true';

    let query: admin.firestore.Query = db.collection('shopProducts')
      .where('isActive', '==', true);

    if (category) {
      query = query.where('category', '==', category);
    }

    if (sellerId) {
      query = query.where('sellerId', '==', sellerId);
    }

    if (featured) {
      query = query.where('isFeatured', '==', true);
    }

    // Sort
    const sortField = sort === 'newest' ? 'createdAt' :
      sort === 'price-low' ? 'price' :
        sort === 'price-high' ? 'price' :
          sort === 'rating' ? 'rating' :
            sort === 'popular' ? 'salesCount' : 'createdAt';
    const sortDir = sort === 'price-low' ? 'asc' : 'desc';
    query = query.orderBy(sortField, sortDir);

    // Pagination
    query = query.limit(limit).offset((page - 1) * limit);

    const snapshot = await query.get();
    let products = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    // Client-side filters
    if (search) {
      const searchLower = search.toLowerCase();
      products = products.filter((p: Record<string, unknown>) =>
        (p.name as string)?.toLowerCase().includes(searchLower) ||
        (p.description as string)?.toLowerCase().includes(searchLower) ||
        (p.sellerName as string)?.toLowerCase().includes(searchLower) ||
        (p.tags as string[])?.some(t => t.toLowerCase().includes(searchLower))
      );
    }

    if (onSale) {
      products = products.filter((p: Record<string, unknown>) =>
        p.compareAtPrice && (p.compareAtPrice as number) > (p.price as number)
      );
    }

    // Get total count for pagination
    const countQuery = db.collection('shopProducts').where('isActive', '==', true);
    const countSnapshot = await countQuery.count().get();

    res.json({
      products,
      page,
      limit,
      total: countSnapshot.data().count,
      hasMore: page * limit < countSnapshot.data().count,
    });
  } catch (error) {
    console.error('Shop browse error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get featured products
 */
export const shopFeatured = onRequest({ cors: true }, async (_req, res) => {
  try {
    const snapshot = await db.collection('shopProducts')
      .where('isActive', '==', true)
      .where('isFeatured', '==', true)
      .orderBy('salesCount', 'desc')
      .limit(10)
      .get();

    const products = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(products);
  } catch (error) {
    console.error('Featured products error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get product details
 */
export const shopProduct = onRequest({ cors: true }, async (req, res) => {
  try {
    const id = req.query.id as string;
    if (!id) {
      res.status(400).json({ error: 'Product ID required' });
      return;
    }

    const doc = await db.collection('shopProducts').doc(id).get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    // Increment view count
    await doc.ref.update({
      viewCount: admin.firestore.FieldValue.increment(1),
    });

    res.json(serializeDoc({ id: doc.id, ...doc.data() }));
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get all sellers
 */
export const shopSellers = onRequest({ cors: true }, async (_req, res) => {
  try {
    const snapshot = await db.collection('shopSellers')
      .where('isActive', '==', true)
      .orderBy('isOfficialPartner', 'desc')
      .orderBy('rating', 'desc')
      .get();

    const sellers = snapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(sellers);
  } catch (error) {
    console.error('Get sellers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get seller details with their products
 */
export const shopSeller = onRequest({ cors: true }, async (req, res) => {
  try {
    const id = req.query.id as string;
    if (!id) {
      res.status(400).json({ error: 'Seller ID required' });
      return;
    }

    const sellerDoc = await db.collection('shopSellers').doc(id).get();
    if (!sellerDoc.exists) {
      res.status(404).json({ error: 'Seller not found' });
      return;
    }

    const productsSnapshot = await db.collection('shopProducts')
      .where('sellerId', '==', id)
      .where('isActive', '==', true)
      .orderBy('salesCount', 'desc')
      .limit(50)
      .get();

    const products = productsSnapshot.docs.map(doc => serializeDoc({
      id: doc.id,
      ...doc.data(),
    }));

    res.json({
      seller: serializeDoc({ id: sellerDoc.id, ...sellerDoc.data() }),
      products,
    });
  } catch (error) {
    console.error('Get seller error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Admin: Create a new product
 */
export const shopAdminCreateProduct = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const body = ProductSchema.parse(req.body);

    const product = {
      ...body,
      isActive: true,
      viewCount: 0,
      salesCount: 0,
      favoriteCount: 0,
      rating: 0,
      reviewCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: user.uid,
    };

    const docRef = await db.collection('shopProducts').add(product);

    // Update seller's product count
    await db.collection('shopSellers').doc(body.sellerId).update({
      productCount: admin.firestore.FieldValue.increment(1),
    });

    res.status(201).json({ id: docRef.id, ...product });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid product data', details: error.errors });
    } else {
      console.error('Create product error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Admin: Update a product
 */
export const shopAdminUpdateProduct = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const productId = req.query.id as string;
    if (!productId) {
      res.status(400).json({ error: 'Product ID required' });
      return;
    }

    const productRef = db.collection('shopProducts').doc(productId);
    const existingProduct = await productRef.get();

    if (!existingProduct.exists) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    const body = ProductSchema.partial().parse(req.body);

    await productRef.update({
      ...body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: user.uid,
    });

    res.json({ success: true, id: productId });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid product data', details: error.errors });
    } else {
      console.error('Update product error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Admin: Delete a product
 */
export const shopAdminDeleteProduct = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const productId = req.query.id as string;
    if (!productId) {
      res.status(400).json({ error: 'Product ID required' });
      return;
    }

    const productRef = db.collection('shopProducts').doc(productId);
    const product = await productRef.get();

    if (!product.exists) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    const sellerId = product.data()?.sellerId;

    // Soft delete
    await productRef.update({
      isActive: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: user.uid,
    });

    // Update seller's product count
    if (sellerId) {
      await db.collection('shopSellers').doc(sellerId).update({
        productCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Admin: Create a new seller
 */
export const shopAdminCreateSeller = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const body = SellerSchema.parse(req.body);

    const seller = {
      ...body,
      isActive: true,
      rating: 0,
      reviewCount: 0,
      productCount: 0,
      salesCount: 0,
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: user.uid,
    };

    const docRef = await db.collection('shopSellers').add(seller);

    res.status(201).json({ id: docRef.id, ...seller });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid seller data', details: error.errors });
    } else {
      console.error('Create seller error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Admin: Update a seller
 */
export const shopAdminUpdateSeller = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const sellerId = req.query.id as string;
    if (!sellerId) {
      res.status(400).json({ error: 'Seller ID required' });
      return;
    }

    const sellerRef = db.collection('shopSellers').doc(sellerId);
    const existingSeller = await sellerRef.get();

    if (!existingSeller.exists) {
      res.status(404).json({ error: 'Seller not found' });
      return;
    }

    const body = SellerSchema.partial().parse(req.body);

    await sellerRef.update({
      ...body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: user.uid,
    });

    res.json({ success: true, id: sellerId });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ error: 'Invalid seller data', details: error.errors });
    } else {
      console.error('Update seller error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

/**
 * Admin: Get shop statistics
 */
export const shopAdminStats = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const [productsCount, sellersCount, reviewsCount] = await Promise.all([
      db.collection('shopProducts').where('isActive', '==', true).count().get(),
      db.collection('shopSellers').where('isActive', '==', true).count().get(),
      db.collection('productReviews').count().get(),
    ]);

    // Get products for sales calculation
    const productsSnapshot = await db.collection('shopProducts')
      .where('isActive', '==', true)
      .select('salesCount', 'viewCount')
      .get();

    let totalSales = 0;
    let totalViews = 0;
    for (const doc of productsSnapshot.docs) {
      totalSales += doc.data().salesCount || 0;
      totalViews += doc.data().viewCount || 0;
    }

    res.json({
      totalProducts: productsCount.data().count,
      totalSellers: sellersCount.data().count,
      totalReviews: reviewsCount.data().count,
      totalSales,
      totalViews,
    });
  } catch (error) {
    console.error('Shop stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Firestore trigger: Update product rating when review is added
 */
export const onShopReviewCreated = onDocumentCreated('productReviews/{reviewId}', async (event) => {
  const review = event.data?.data();
  if (!review) return;

  const productId = review.productId;
  if (!productId) return;

  try {
    // Get all reviews for this product
    const reviewsSnapshot = await db.collection('productReviews')
      .where('productId', '==', productId)
      .get();

    if (reviewsSnapshot.empty) return;

    let totalRating = 0;
    for (const doc of reviewsSnapshot.docs) {
      totalRating += doc.data().rating || 0;
    }

    const avgRating = totalRating / reviewsSnapshot.size;

    await db.collection('shopProducts').doc(productId).update({
      rating: avgRating,
      reviewCount: reviewsSnapshot.size,
    });
  } catch (error) {
    console.error('Error updating product rating:', error);
  }
});

/**
 * Generate signed URL for image upload (admin only)
 */
export const shopGetUploadUrl = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  try {
    const user = await verifyAuth(req.headers.authorization);
    if (!user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!await isAdmin(user.uid)) {
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    const { type, id, filename } = req.body as { type: string; id: string; filename: string };
    if (!type || !id || !filename) {
      res.status(400).json({ error: 'type, id, and filename are required' });
      return;
    }

    const bucket = admin.storage().bucket();
    const path = type === 'product'
      ? `shop_products/${id}/${filename}`
      : `shop_sellers/${id}/${filename}`;

    const file = bucket.file(path);
    const [signedUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
      contentType: 'image/jpeg',
    });

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${path}`;

    res.json({ uploadUrl: signedUrl, publicUrl });
  } catch (error) {
    console.error('Get upload URL error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Increment product view count
 * This is a lightweight endpoint that doesn't require authentication
 * Rate limiting is handled by Firebase's built-in protections
 */
export const shopIncrementViewCount = onRequest({ cors: true }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders()).status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { productId } = req.body as { productId: string };

    if (!productId || typeof productId !== 'string') {
      res.status(400).json({ error: 'productId is required' });
      return;
    }

    // Check if product exists
    const productRef = db.collection('shopProducts').doc(productId);
    const productDoc = await productRef.get();

    if (!productDoc.exists) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }

    // Increment view count
    await productRef.update({
      viewCount: admin.firestore.FieldValue.increment(1),
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Increment view count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =============================================================================
// CLOUD SYNC ENTITLEMENTS
// =============================================================================

export {
  onRevenueCatWebhook,
  checkCloudSyncEntitlement,
  grandfatherExistingUsers,
} from './cloud_sync_entitlements';

// =============================================================================
// SOCIAL FEATURES
// =============================================================================

export {
  // Follow system
  onFollowCreated,
  onFollowDeleted,
  getFollowers,
  getFollowing,
  getMutualFollows,
  checkFollowStatus,
  // Posts & Feed
  onPostCreated,
  onPostDeleted,
  getFeed,
  getUserPosts,
  // Comments
  onCommentCreated,
  onCommentDeleted,
  getComments,
  // Likes
  onLikeCreated,
  onLikeDeleted,
  checkLikeStatus,
  // Admin
  recalculateAllCounts,
} from './social';

// =============================================================================
// PUSH NOTIFICATIONS
// =============================================================================

export {
  onFollowCreatedNotification,
  onFollowRequestCreatedNotification,
  onFollowRequestAcceptedNotification,
  onLikeCreatedNotification,
  onCommentCreatedNotification,
  sendTestPushNotification,
} from './push_notifications';