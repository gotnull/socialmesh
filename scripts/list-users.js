/**
 * List all users in Firebase Auth to find your user ID
 * Run with: node scripts/list-users.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function listUsers() {
  try {
    console.log('📋 Listing Firebase users...\n');

    const listUsersResult = await admin.auth().listUsers(1000);

    if (listUsersResult.users.length === 0) {
      console.log('No users found. Sign in to the app first!\n');
      process.exit(0);
    }

    console.log(`Found ${listUsersResult.users.length} user(s):\n`);

    listUsersResult.users.forEach((user, index) => {
      console.log(`${index + 1}. User ID: ${user.uid}`);
      console.log(`   Email: ${user.email || 'N/A'}`);
      console.log(`   Display Name: ${user.displayName || 'N/A'}`);
      console.log(`   Created: ${user.metadata.creationTime}`);
      console.log(`   Last Sign In: ${user.metadata.lastSignInTime || 'Never'}`);
      console.log('');
    });

    console.log('💡 To make a user admin, run:');
    console.log(`   node scripts/add-admin.js USER_ID EMAIL "Display Name"\n`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error listing users:', error);
    process.exit(1);
  }
}

listUsers();
