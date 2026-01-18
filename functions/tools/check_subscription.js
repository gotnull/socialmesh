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

async function run() {
  const doc = await db.collection('users').doc(subscriberId).collection('signalSubscriptions').doc(authorId).get();
  console.log('exists:', doc.exists, 'data:', doc.data());
}

run().catch(err => { console.error(err); process.exit(1); });
