/**
 * Add admin user to Firestore
 * Run with: node scripts/add-admin.js YOUR_USER_ID
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addAdmin(userId, email, displayName) {
  if (!userId) {
    console.error('❌ Error: User ID is required');
    console.log('\nUsage: node scripts/add-admin.js USER_ID [EMAIL] [DISPLAY_NAME]');
    console.log('\nExample: node scripts/add-admin.js 9ltxJGViWHW5aj5HhLGmiVwkrLU2 admin@socialmesh.app "Admin User"\n');
    process.exit(1);
  }

  try {
    console.log('🔐 Adding admin user...\n');

    // Add to admins collection
    await db.collection('admins').doc(userId).set({
      userId: userId,
      email: email || 'unknown@email.com',
      displayName: displayName || 'Admin User',
      role: 'admin',
      permissions: {
        manageProducts: true,
        manageSellers: true,
        manageReviews: true,
        manageUsers: false,
        viewAnalytics: true,
      },
      addedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Admin user added successfully!\n');
    console.log('User ID:', userId);
    console.log('Email:', email || 'unknown@email.com');
    console.log('Display Name:', displayName || 'Admin User');
    console.log('\n🎉 You can now access the Shop Admin section!\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error adding admin:', error);
    process.exit(1);
  }
}

// Get arguments
const userId = process.argv[2];
const email = process.argv[3];
const displayName = process.argv[4];

addAdmin(userId, email, displayName);
