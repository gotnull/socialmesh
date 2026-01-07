#!/usr/bin/env node
/**
 * Sync Admin UID Script
 * 
 * This script helps you update your admin UID across Firebase after account recreation.
 * Firebase Auth UIDs are immutable - when you delete and recreate an account,
 * you get a new UID that needs to be synced everywhere.
 * 
 * Usage:
 *   node scripts/sync-admin-uid.js <NEW_UID> [--dry-run]
 * 
 * Example:
 *   node scripts/sync-admin-uid.js 9ltxJGViWHW5aj5HhLGmiVwkrLU2
 *   node scripts/sync-admin-uid.js 9ltxJGViWHW5aj5HhLGmiVwkrLU2 --dry-run
 * 
 * Prerequisites:
 *   - Firebase Admin SDK credentials (service account JSON)
 *   - Node.js with firebase-admin package
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Configuration
const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const OLD_UIDS = [
  'rAHv8sx4UeTajyeBurx9ZjjBzWn1', // Original owner UID
];

// Files that contain hardcoded UIDs (relative to project root)
const FILES_TO_UPDATE = [
  {
    path: 'lib/utils/validation.dart',
    pattern: /const String _ownerUid = '[^']+';/,
    replacement: (newUid) => `const String _ownerUid = '${newUid}';`,
  },
  {
    path: 'firestore.rules',
    pattern: /return request\.auth\.uid == '[^']+';/,
    replacement: (newUid) => `return request.auth.uid == '${newUid}';`,
  },
  {
    path: 'functions/src/index.ts',
    pattern: /const ADMIN_UIDS = \[[^\]]*\];/,
    replacement: (newUid) => `const ADMIN_UIDS = ['${newUid}'];`,
  },
];

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const newUid = args.find(arg => !arg.startsWith('--'));

  if (!newUid) {
    console.log(`
╔══════════════════════════════════════════════════════════════════╗
║                    Sync Admin UID Script                         ║
╠══════════════════════════════════════════════════════════════════╣
║ This script updates your admin UID across Firebase and codebase  ║
║ after account recreation.                                        ║
╚══════════════════════════════════════════════════════════════════╝

Usage:
  node scripts/sync-admin-uid.js <NEW_UID> [--dry-run]

Options:
  --dry-run    Show what would be changed without making changes

To find your current UID:
  1. Sign in to the app
  2. Go to Profile screen
  3. Tap your UID to copy it

Example:
  node scripts/sync-admin-uid.js 9ltxJGViWHW5aj5HhLGmiVwkrLU2
`);
    process.exit(1);
  }

  // Validate UID format (Firebase UIDs are 28 characters)
  if (!/^[a-zA-Z0-9]{20,40}$/.test(newUid)) {
    console.error('❌ Invalid UID format. Firebase UIDs are typically 28 alphanumeric characters.');
    process.exit(1);
  }

  console.log(`
╔══════════════════════════════════════════════════════════════════╗
║                    Sync Admin UID Script                         ║
╠══════════════════════════════════════════════════════════════════╣
║ New UID: ${newUid.padEnd(42)} ║
║ Mode: ${dryRun ? 'DRY RUN (no changes will be made)'.padEnd(45) : 'LIVE (changes will be applied)'.padEnd(45)} ║
╚══════════════════════════════════════════════════════════════════╝
`);

  // Step 1: Update local files
  console.log('📁 STEP 1: Updating local files...\n');
  const projectRoot = path.join(__dirname, '..');

  for (const file of FILES_TO_UPDATE) {
    const filePath = path.join(projectRoot, file.path);

    if (!fs.existsSync(filePath)) {
      console.log(`   ⚠️  ${file.path} - File not found, skipping`);
      continue;
    }

    const content = fs.readFileSync(filePath, 'utf8');
    const newContent = content.replace(file.pattern, file.replacement(newUid));

    if (content === newContent) {
      console.log(`   ✓  ${file.path} - Already up to date or pattern not found`);
    } else {
      if (dryRun) {
        console.log(`   📝 ${file.path} - Would update`);
        // Show diff preview
        const match = content.match(file.pattern);
        if (match) {
          console.log(`      Old: ${match[0]}`);
          console.log(`      New: ${file.replacement(newUid)}`);
        }
      } else {
        fs.writeFileSync(filePath, newContent, 'utf8');
        console.log(`   ✅ ${file.path} - Updated`);
      }
    }
  }

  // Step 2: Update Firestore admins collection
  console.log('\n📊 STEP 2: Updating Firestore admins collection...\n');

  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.log(`   ⚠️  Service account file not found at:`);
    console.log(`      ${SERVICE_ACCOUNT_PATH}`);
    console.log(`   ⚠️  Skipping Firestore update. You can manually add the admin document.`);
  } else {
    try {
      // Initialize Firebase Admin
      const serviceAccount = require(SERVICE_ACCOUNT_PATH);

      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }

      const db = admin.firestore();

      // Check if admin document exists
      const adminDoc = await db.collection('admins').doc(newUid).get();

      if (adminDoc.exists) {
        console.log(`   ✓  Admin document already exists for ${newUid}`);
      } else {
        if (dryRun) {
          console.log(`   📝 Would create admin document for ${newUid}`);
        } else {
          await db.collection('admins').doc(newUid).set({
            isAdmin: true,
            role: 'owner',
            email: 'fcusumano@gmail.com',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            note: 'Added by sync-admin-uid script',
          });
          console.log(`   ✅ Created admin document for ${newUid}`);
        }
      }

      // Optionally remove old admin UIDs
      for (const oldUid of OLD_UIDS) {
        if (oldUid === newUid) continue;

        const oldAdminDoc = await db.collection('admins').doc(oldUid).get();
        if (oldAdminDoc.exists) {
          if (dryRun) {
            console.log(`   📝 Would remove old admin document for ${oldUid}`);
          } else {
            await db.collection('admins').doc(oldUid).delete();
            console.log(`   🗑️  Removed old admin document for ${oldUid}`);
          }
        }
      }

    } catch (error) {
      console.error(`   ❌ Firestore error: ${error.message}`);
    }
  }

  // Step 3: Reminder for manual steps
  console.log(`
╔══════════════════════════════════════════════════════════════════╗
║                    Next Steps                                    ║
╠══════════════════════════════════════════════════════════════════╣
║ 1. Deploy Firestore rules:                                       ║
║    firebase deploy --only firestore:rules                        ║
║                                                                  ║
║ 2. Deploy Cloud Functions (if functions/src/index.ts changed):   ║
║    cd functions && npm run build && firebase deploy --only functions ║
║                                                                  ║
║ 3. Restart the app and sign in again                             ║
╚══════════════════════════════════════════════════════════════════╝
`);

  if (dryRun) {
    console.log('🔍 This was a dry run. Run without --dry-run to apply changes.\n');
  } else {
    console.log('✅ All changes applied successfully!\n');
  }

  process.exit(0);
}

main().catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
