// Script to invoke reportBug locally using real SMTP (IMPROVMX) settings from .env
// Usage:
//   node scripts/run_report_bug.js            # uses mocked Firestore (safe)
//   node scripts/run_report_bug.js --live-db  # uses real Firestore (requires GOOGLE_APPLICATION_CREDENTIALS)

require('dotenv').config();

// Provide minimal Firebase config so requiring the compiled functions bundle doesn't
// initialize storage providers which expect a bucket name during import.
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: 'local-test', storageBucket: 'test-bucket' });
process.env.STORAGE_BUCKET = process.env.STORAGE_BUCKET || 'test-bucket';

process.env.IMPROVMX_SMTP_HOST = process.env.IMPROVMX_SMTP_HOST || 'smtp.improvmx.com';
process.env.IMPROVMX_SMTP_PORT = process.env.IMPROVMX_SMTP_PORT || '587';

if (!process.env.IMPROVMX_SMTP_USER || !process.env.IMPROVMX_SMTP_PASS) {
  console.error('Missing IMPROVMX_SMTP_USER or IMPROVMX_SMTP_PASS in environment. Set them in .env or the environment.');
  process.exit(1);
}

const useLiveDb = process.argv.includes('--live-db');

const admin = require('firebase-admin');
if (useLiveDb) {
  // Initialize real Firebase Admin (requires GOOGLE_APPLICATION_CREDENTIALS or ADC)
  if (!admin.apps.length) admin.initializeApp();
  console.log('Using live Firestore (writes will be performed)');
} else {
  // Lightweight mock for Firestore to avoid touching production data by default
  admin.apps = admin.apps || [];
  admin.initializeApp = admin.initializeApp || function () { admin.apps.push(true); };
  admin.firestore = admin.firestore || (() => ({
    collection: () => ({
      add: async (d) => ({ id: 'fake-doc-id', data: () => d }),
    }),
  }));
  admin.firestore.FieldValue = admin.firestore.FieldValue || { serverTimestamp: () => 'SERVER_TIMESTAMP' };
  admin.messaging = admin.messaging || (() => ({ send: async () => ({}) }));
  console.log('Using mocked Firestore (no writes)');
}

// Use real nodemailer (do NOT mock) so SMTP behavior matches scripts/send-email-improvmx.py
const nodemailer = require('nodemailer');

(async () => {
  try {
    // Import the compiled functions bundle
    const { reportBug } = require('../lib/index');

    const request = {
      data: {
        description: 'App crashes when saving (CLI test)',
        screenshotUrl: 'https://example.com/shot.png',
        appVersion: '1.2.3',
        buildNumber: '42',
        platform: 'ios',
        platformVersion: '16.5',
        email: 'reporter@example.com',
      },
      auth: { token: { email: 'auth@example.com' }, uid: 'auth-uid' },
    };

    // reportBug is an onCall handler; call it directly with the request shape
    const res = await reportBug(request);
    console.log('reportBug result:', res);

    // Optionally verify SMTP connectivity
    try {
      const transport = nodemailer.createTransport({
        host: process.env.IMPROVMX_SMTP_HOST,
        port: parseInt(process.env.IMPROVMX_SMTP_PORT || '587', 10),
        secure: process.env.IMPROVMX_SMTP_SECURE === 'true',
        auth: { user: process.env.IMPROVMX_SMTP_USER, pass: process.env.IMPROVMX_SMTP_PASS },
      });
      await transport.verify();
      console.log('SMTP verify succeeded');
    } catch (vErr) {
      console.warn('SMTP verify failed (email still may be attempted by functions code):', vErr.message || vErr);
    }

  } catch (err) {
    console.error('Error invoking reportBug:', err);
    process.exit(1);
  }
})();
