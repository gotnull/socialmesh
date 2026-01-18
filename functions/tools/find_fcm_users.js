const admin = require('firebase-admin');
const fs = require('fs');

const path = require('path');
const serviceAccountPathArg = process.argv[2] || path.join(__dirname, '..', '..', 'social-mesh-app-firebase-adminsdk-fbsvc-3fdee8d0d3.json');
const serviceAccountPath = path.resolve(process.cwd(), serviceAccountPathArg);
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Service account file not found at', serviceAccountPath);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(serviceAccountPath)) });
const db = admin.firestore();

async function find() {
  const snapshot = await db.collection('users').limit(200).get();
  const results = [];
  snapshot.forEach(doc => {
    const data = doc.data();
    if (data && data.fcmTokens && Object.keys(data.fcmTokens).length > 0) {
      results.push({ id: doc.id, tokens: Object.keys(data.fcmTokens).slice(0, 3) });
    }
  });

  console.log('Found', results.length, 'users with tokens');
  console.log(JSON.stringify(results, null, 2));
}

find().catch(err => { console.error(err); process.exit(1); });
