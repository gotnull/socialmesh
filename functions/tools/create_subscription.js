const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.resolve(process.cwd(), process.argv[2] || path.join(__dirname, '..', '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json'));
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account file not found at', serviceAccountPath);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(serviceAccountPath)) });
const db = admin.firestore();

const subscriberId = process.argv[3];
const authorId = process.argv[4];

if (!subscriberId || !authorId) {
  console.error('Usage: node create_subscription.js <serviceAccount.json> <subscriberId> <authorId>');
  process.exit(1);
}

async function run() {
  const docRef = db.collection('users').doc(subscriberId).collection('signalSubscriptions').doc(authorId);
  const mirrorRef = db.collection('signal_subscribers').doc(authorId).collection('subscribers').doc(subscriberId);

  const batch = db.batch();
  batch.set(docRef, { authorId: authorId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  batch.set(mirrorRef, { subscriberId: subscriberId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  await batch.commit();

  console.log(`Created subscription (and mirror) for ${subscriberId} -> ${authorId}`);
}

run().catch(err => { console.error(err); process.exit(1); });
