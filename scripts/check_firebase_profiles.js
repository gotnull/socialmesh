#!/usr/bin/env node

/**
 * Script to check Firebase Firestore data for user profiles
 * 
 * Usage:
 *   cd /Users/fulvio/development/socialmesh
 *   node scripts/check_firebase_profiles.js
 * 
 * Requires: Firebase Admin SDK credentials
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
  console.error('Make sure the service account file exists at:', serviceAccountPath);
  process.exit(1);
}

const db = admin.firestore();

// Emails to check
const EMAILS_TO_CHECK = [
  'foolvo@gmail.com',
  'fcusumano@gmail.com',
];

async function findUserByEmail(email) {
  console.log(`\n🔍 Looking up Firebase Auth user for: ${email}`);

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`✅ Found user:`);
    console.log(`   - UID: ${userRecord.uid}`);
    console.log(`   - Email: ${userRecord.email}`);
    console.log(`   - Display Name: ${userRecord.displayName || 'not set'}`);
    console.log(`   - Created: ${userRecord.metadata.creationTime}`);
    console.log(`   - Last Sign In: ${userRecord.metadata.lastSignInTime}`);
    return userRecord;
  } catch (e) {
    console.log(`❌ No user found with email: ${email}`);
    console.log(`   Error: ${e.message}`);
    return null;
  }
}

async function getProfileData(uid, email) {
  console.log(`\n📂 Fetching Firestore data for UID: ${uid}`);

  // Check 'users' collection (private profile data)
  console.log(`\n   📁 users/${uid}:`);
  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists) {
    const data = userDoc.data();
    console.log(`   ✅ Document EXISTS`);
    console.log(`      - displayName: ${data.displayName || 'NOT SET'}`);
    console.log(`      - callsign: ${data.callsign || 'NOT SET'}`);
    console.log(`      - bio: ${data.bio || 'NOT SET'}`);
    console.log(`      - avatarUrl: ${data.avatarUrl ? '(has avatar)' : 'NOT SET'}`);
    console.log(`      - isSynced: ${data.isSynced}`);
    console.log(`      - id: ${data.id || 'NOT SET'}`);
    console.log(`      - createdAt: ${data.createdAt?.toDate?.() || data.createdAt || 'NOT SET'}`);
    console.log(`      - updatedAt: ${data.updatedAt?.toDate?.() || data.updatedAt || 'NOT SET'}`);
    console.log(`\n      📋 Full data:`);
    console.log(JSON.stringify(data, null, 2).split('\n').map(l => '      ' + l).join('\n'));
  } else {
    console.log(`   ❌ Document DOES NOT EXIST`);
  }

  // Check 'profiles' collection (public profile data for social features)
  console.log(`\n   📁 profiles/${uid}:`);
  const profileDoc = await db.collection('profiles').doc(uid).get();
  if (profileDoc.exists) {
    const data = profileDoc.data();
    console.log(`   ✅ Document EXISTS`);
    console.log(`      - displayName: ${data.displayName || 'NOT SET'}`);
    console.log(`      - displayNameLower: ${data.displayNameLower || 'NOT SET'}`);
    console.log(`      - callsign: ${data.callsign || 'NOT SET'}`);
    console.log(`      - bio: ${data.bio || 'NOT SET'}`);
    console.log(`      - avatarUrl: ${data.avatarUrl ? '(has avatar)' : 'NOT SET'}`);
    console.log(`      - followerCount: ${data.followerCount ?? 'NOT SET'}`);
    console.log(`      - followingCount: ${data.followingCount ?? 'NOT SET'}`);
    console.log(`      - postCount: ${data.postCount ?? 'NOT SET'}`);
    console.log(`      - isVerified: ${data.isVerified ?? 'NOT SET'}`);
    console.log(`      - createdAt: ${data.createdAt?.toDate?.() || data.createdAt || 'NOT SET'}`);
    console.log(`      - updatedAt: ${data.updatedAt?.toDate?.() || data.updatedAt || 'NOT SET'}`);
    console.log(`\n      📋 Full data:`);
    console.log(JSON.stringify(data, null, 2).split('\n').map(l => '      ' + l).join('\n'));
  } else {
    console.log(`   ❌ Document DOES NOT EXIST`);
  }
}

async function checkAllUsers() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('🔥 Firebase Profile Data Checker');
  console.log('═══════════════════════════════════════════════════════════════');

  for (const email of EMAILS_TO_CHECK) {
    console.log('\n');
    console.log('═══════════════════════════════════════════════════════════════');
    console.log(`📧 Checking: ${email}`);
    console.log('═══════════════════════════════════════════════════════════════');

    const user = await findUserByEmail(email);
    if (user) {
      await getProfileData(user.uid, email);
    }
  }

  console.log('\n\n═══════════════════════════════════════════════════════════════');
  console.log('✅ Done!');
  console.log('═══════════════════════════════════════════════════════════════');
}

// Run it
checkAllUsers()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });
