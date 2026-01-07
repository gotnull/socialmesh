#!/usr/bin/env node
/**
 * Sync User Data Script
 * 
 * Copies user document data from old UID to new UID in Firestore.
 */

const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');

const OLD_UID = 'rAHv8sx4UeTajyeBurx9ZjjBzWn1';
const NEW_UID = '9ltxJGViWHW5aj5HhLGmiVwkrLU2';

async function syncUser() {
  // Initialize Firebase Admin
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const db = admin.firestore();

  console.log(`\n📋 Syncing user data from ${OLD_UID} to ${NEW_UID}\n`);

  // Read old user document
  const oldDoc = await db.collection('users').doc(OLD_UID).get();

  if (!oldDoc.exists) {
    console.log('❌ Old user document not found at users/' + OLD_UID);
    process.exit(1);
  }

  const oldData = oldDoc.data();
  console.log('📄 Found old user document:');
  console.log(JSON.stringify(oldData, null, 2));

  // Check if new document exists
  const newDoc = await db.collection('users').doc(NEW_UID).get();
  if (newDoc.exists) {
    console.log('\n⚠️  New user document already exists at users/' + NEW_UID);
    console.log('Existing data:', JSON.stringify(newDoc.data(), null, 2));
  }

  // Copy data to new UID, updating the uid field
  const newData = {
    ...oldData,
    uid: NEW_UID,
    migratedFrom: OLD_UID,
    migratedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('users').doc(NEW_UID).set(newData, { merge: true });
  console.log('\n✅ Copied user data to users/' + NEW_UID);

  console.log('\n✅ Sync complete!');
  process.exit(0);
}

syncUser().catch(e => {
  console.error('❌ Error:', e.message);
  process.exit(1);
});
