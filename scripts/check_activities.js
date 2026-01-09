#!/usr/bin/env node

/**
 * Script to check activity feed data in Firebase
 * 
 * Usage:
 *   node scripts/check_activities.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} catch (e) {
  console.error('❌ Failed to initialize Firebase Admin:', e.message);
  process.exit(1);
}

const db = admin.firestore();

// Users to check
const EMAILS = {
  'gotnull': 'fcusumano@gmail.com',
  'foolvo': 'foolvo@gmail.com',
};

async function getUserByEmail(email) {
  try {
    return await admin.auth().getUserByEmail(email);
  } catch (e) {
    return null;
  }
}

async function checkActivities() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('📬 Activity Feed Checker');
  console.log('═══════════════════════════════════════════════════════════════');

  for (const [name, email] of Object.entries(EMAILS)) {
    console.log(`\n\n📧 ${name} (${email}):`);
    console.log('─────────────────────────────────────────────────────────────');

    const user = await getUserByEmail(email);
    if (!user) {
      console.log('   ❌ User not found');
      continue;
    }

    const uid = user.uid;
    console.log(`   UID: ${uid}`);

    // Get activities
    const activitiesSnapshot = await db
      .collection('users')
      .doc(uid)
      .collection('activities')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    console.log(`\n   📋 Recent Activities (${activitiesSnapshot.size} found):`);

    if (activitiesSnapshot.empty) {
      console.log('      No activities found');
    } else {
      for (const doc of activitiesSnapshot.docs) {
        const data = doc.data();
        const type = data.type;
        const actorName = data.actorSnapshot?.displayName || data.actorId?.substring(0, 8) || '?';
        const createdAt = data.createdAt?.toDate?.() || data.createdAt;
        const isRead = data.isRead ? '✓ read' : '○ unread';

        console.log(`      • [${type}] from "${actorName}" at ${createdAt} (${isRead})`);
        if (data.contentId) {
          console.log(`        contentId: ${data.contentId}`);
        }
        if (data.textContent) {
          console.log(`        text: "${data.textContent.substring(0, 50)}..."`);
        }
      }
    }
  }

  // Also check story likes directly
  console.log('\n\n═══════════════════════════════════════════════════════════════');
  console.log('🔍 Checking Recent Story Likes');
  console.log('═══════════════════════════════════════════════════════════════');

  // Get recent stories from gotnull
  const gotnullUser = await getUserByEmail(EMAILS.gotnull);
  if (gotnullUser) {
    const storiesSnapshot = await db
      .collection('stories')
      .where('authorId', '==', gotnullUser.uid)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    console.log(`\n   📖 gotnull's recent stories: ${storiesSnapshot.size}`);

    for (const storyDoc of storiesSnapshot.docs) {
      const story = storyDoc.data();
      console.log(`\n   Story: ${storyDoc.id}`);
      console.log(`      - createdAt: ${story.createdAt?.toDate?.() || story.createdAt}`);
      console.log(`      - likeCount: ${story.likeCount || 0}`);
      console.log(`      - viewCount: ${story.viewCount || 0}`);

      // Check likes subcollection
      const likesSnapshot = await storyDoc.ref.collection('likes').get();
      console.log(`      - Likes in subcollection: ${likesSnapshot.size}`);

      for (const likeDoc of likesSnapshot.docs) {
        const like = likeDoc.data();
        const likerId = likeDoc.id;
        // Try to get liker's email
        try {
          const liker = await admin.auth().getUser(likerId);
          console.log(`        • ${liker.email || likerId} at ${like.likedAt?.toDate?.() || like.likedAt}`);
        } catch (e) {
          console.log(`        • ${likerId} at ${like.likedAt?.toDate?.() || like.likedAt}`);
        }
      }
    }
  }

  console.log('\n\n═══════════════════════════════════════════════════════════════');
  console.log('✅ Done!');
  console.log('═══════════════════════════════════════════════════════════════');
}

checkActivities()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });
