import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
// In production, use service account credentials from environment variable
// Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON

let firebaseInitialized = false;

export function initializeFirebase(): void {
  if (firebaseInitialized) return;

  try {
    // Check for service account JSON in environment
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

    if (serviceAccountJson) {
      // Parse JSON from environment variable
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log('Firebase initialized with service account from environment');
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Use default credentials file
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      console.log('Firebase initialized with application default credentials');
    } else {
      // Development mode - skip authentication
      console.warn('⚠️  Firebase credentials not configured. Running in development mode without auth validation.');
      firebaseInitialized = true;
      return;
    }

    firebaseInitialized = true;
  } catch (error) {
    console.error('Failed to initialize Firebase:', error);
    console.warn('⚠️  Running in development mode without auth validation.');
    firebaseInitialized = true;
  }
}

export function isFirebaseInitialized(): boolean {
  return firebaseInitialized && admin.apps.length > 0;
}

export interface DecodedUser {
  uid: string;
  email?: string;
  name?: string;
  picture?: string;
  emailVerified?: boolean;
}

/**
 * Verify a Firebase ID token and extract user information
 */
export async function verifyIdToken(idToken: string): Promise<DecodedUser | null> {
  if (!isFirebaseInitialized()) {
    // Development mode - return mock user from token
    return {
      uid: `dev-${idToken.slice(0, 8)}`,
      email: 'dev@example.com',
      name: 'Dev User',
    };
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name,
      picture: decodedToken.picture,
      emailVerified: decodedToken.email_verified,
    };
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}

/**
 * Get user info from Firebase Auth
 */
export async function getUserInfo(uid: string): Promise<admin.auth.UserRecord | null> {
  if (!isFirebaseInitialized()) {
    return null;
  }

  try {
    return await admin.auth().getUser(uid);
  } catch {
    return null;
  }
}
