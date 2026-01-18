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

const authorId = process.argv[3];
const content = process.argv[4] || 'Test signal -- E2E';

if (!authorId) {
  console.error('Usage: node create_signal_post.js <serviceAccount.json> <authorId> [content]');
  process.exit(1);
}

async function run() {
  const postRef = db.collection('posts').doc();
  await postRef.set({
    authorId: authorId,
    postMode: 'signal',
    content: content,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Created signal post ${postRef.id} by ${authorId}`);
}

run().catch(err => { console.error(err); process.exit(1); });
