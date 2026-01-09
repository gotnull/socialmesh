#!/usr/bin/env node

/**
 * Script to FIX the corrupted Firebase profile data
 * 
 * The bug caused fcusumano's "gotnull" profile to overwrite foolvo's profile.
 * This script will reset foolvo@gmail.com's profile to clean state.
 * 
 * Usage:
 *   cd /Users/fulvio/development/socialmesh
 *   node scripts/fix_firebase_profiles.js
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

// User to fix
const FOOLVO_EMAIL = 'foolvo@gmail.com';

async function fixFoolvoProfile() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('🔧 Firebase Profile Data Fixer');
  console.log('═══════════════════════════════════════════════════════════════');

  // Get the user
  console.log(`\n🔍 Looking up Firebase Auth user for: ${FOOLVO_EMAIL}`);
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(FOOLVO_EMAIL);
    console.log(`✅ Found user: ${userRecord.uid}`);
  } catch (e) {
    console.error(`❌ User not found: ${e.message}`);
    process.exit(1);
  }

  const uid = userRecord.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  // New clean profile data for foolvo
  const newProfileData = {
    displayName: 'foolvo',
    bio: null,
    callsign: null,
    website: null,
    avatarUrl: null,  // Clear the avatar - it was pointing to fcusumano's storage
    bannerUrl: null,  // Clear the banner too
    socialLinks: null,
    primaryNodeId: null,
    linkedNodeIds: [],
    accentColorIndex: 0,
    email: FOOLVO_EMAIL,
    preferences: null,
    installedWidgetIds: [],
    createdAt: new Date().toISOString(),
    updatedAt: now,
  };

  const newPublicProfileData = {
    displayName: 'foolvo',
    displayNameLower: 'foolvo',
    bio: null,
    callsign: null,
    website: null,
    avatarUrl: null,
    bannerUrl: null,
    socialLinks: null,
    primaryNodeId: null,
    linkedNodeIds: [],
    followerCount: 0,  // Reset counters - they may have been from wrong account
    followingCount: 0,
    postCount: 0,
    createdAt: now,
    updatedAt: now,
  };

  console.log(`\n📝 New profile data for ${FOOLVO_EMAIL}:`);
  console.log(`   - displayName: ${newProfileData.displayName}`);
  console.log(`   - avatarUrl: ${newProfileData.avatarUrl}`);
  console.log(`   - bannerUrl: ${newProfileData.bannerUrl}`);

  // Confirm before proceeding
  console.log('\n⚠️  THIS WILL OVERWRITE THE EXISTING PROFILE DATA');
  console.log('⚠️  Press Ctrl+C within 5 seconds to cancel...\n');

  await new Promise(resolve => setTimeout(resolve, 5000));

  // Update users collection
  console.log(`\n📤 Updating users/${uid}...`);
  await db.collection('users').doc(uid).set(newProfileData, { merge: false });
  console.log('   ✅ users collection updated');

  // Update profiles collection
  console.log(`\n📤 Updating profiles/${uid}...`);
  await db.collection('profiles').doc(uid).set(newPublicProfileData, { merge: false });
  console.log('   ✅ profiles collection updated');

  // Verify the update
  console.log('\n🔍 Verifying the update...');

  const userDoc = await db.collection('users').doc(uid).get();
  const profileDoc = await db.collection('profiles').doc(uid).get();

  console.log(`\n   users/${uid}:`);
  console.log(`      - displayName: ${userDoc.data().displayName}`);
  console.log(`      - avatarUrl: ${userDoc.data().avatarUrl || 'null'}`);

  console.log(`\n   profiles/${uid}:`);
  console.log(`      - displayName: ${profileDoc.data().displayName}`);
  console.log(`      - avatarUrl: ${profileDoc.data().avatarUrl || 'null'}`);

  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('✅ Profile fixed! foolvo@gmail.com now has clean profile data.');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('\n📱 Next steps:');
  console.log('   1. Sign out of the app on your device');
  console.log('   2. Sign back in with foolvo@gmail.com');
  console.log('   3. The profile should now show "foolvo" instead of "gotnull"');
  console.log('   4. Edit your profile to add avatar, bio, etc.');
}

// Run it
fixFoolvoProfile()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });
