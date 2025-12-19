/**
 * Socialmesh Firebase Cloud Functions
 *
 * Handles:
 * - Widget Marketplace API
 * - Rich Share Links (Open Graph)
 * - Admin operations
 */

import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { z } from 'zod';

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

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
 * Supports: /share/node/:id, /share/profile/:id, /share/widget/:id, /share/location
 */
export const share = onRequest(async (req, res) => {
  const path = req.path;
  const baseUrl = 'https://socialmesh.app';
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

  // Generate HTML with Open Graph tags
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
  <meta property="al:ios:app_store_id" content="YOUR_APP_STORE_ID">
  <meta property="al:ios:app_name" content="Socialmesh">
  <meta property="al:ios:url" content="${deepLink}">
  <meta property="al:android:package" content="app.socialmesh">
  <meta property="al:android:app_name" content="Socialmesh">
  <meta property="al:android:url" content="${deepLink}">
  
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
      color: white;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      text-align: center;
    }
    .logo { width: 80px; height: 80px; border-radius: 20px; margin-bottom: 24px; }
    h1 { font-size: 24px; margin-bottom: 12px; }
    p { color: rgba(255,255,255,0.7); margin-bottom: 32px; max-width: 400px; }
    .btn {
      display: inline-block;
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      color: white;
      padding: 16px 32px;
      border-radius: 12px;
      text-decoration: none;
      font-weight: 600;
      margin: 8px;
      transition: transform 0.2s;
    }
    .btn:hover { transform: scale(1.05); }
    .btn-secondary {
      background: rgba(255,255,255,0.1);
      border: 1px solid rgba(255,255,255,0.2);
    }
    .stores { margin-top: 24px; display: flex; gap: 16px; flex-wrap: wrap; justify-content: center; }
  </style>
  
  <script>
    // Try to open the app directly
    window.location.href = '${deepLink}';
    
    // Fallback to store after delay
    setTimeout(function() {
      var ua = navigator.userAgent.toLowerCase();
      if (ua.indexOf('iphone') > -1 || ua.indexOf('ipad') > -1) {
        window.location.href = 'https://apps.apple.com/app/socialmesh/idYOUR_APP_ID';
      } else if (ua.indexOf('android') > -1) {
        window.location.href = 'https://play.google.com/store/apps/details?id=app.socialmesh';
      }
    }, 2500);
  </script>
</head>
<body>
  <img src="${appIcon}" alt="Socialmesh" class="logo">
  <h1>${escapeHtml(title)}</h1>
  <p>${escapeHtml(description)}</p>
  
  <a href="${deepLink}" class="btn">Open in Socialmesh</a>
  
  <div class="stores">
    <a href="https://apps.apple.com/app/socialmesh/idYOUR_APP_ID" class="btn btn-secondary">App Store</a>
    <a href="https://play.google.com/store/apps/details?id=app.socialmesh" class="btn btn-secondary">Google Play</a>
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
