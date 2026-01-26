// Mock firebase-functions providers before importing module to avoid provider initialization errors
jest.mock('firebase-functions/v2/https', () => ({
  onCall: jest.fn((opts: unknown, handler: (...args: unknown[]) => unknown) => handler),
  onRequest: jest.fn((opts: unknown, handler: (...args: unknown[]) => unknown) => handler),
  HttpsError: class HttpsError extends Error {
    constructor(public code: string, message: string) {
      super(message);
      this.name = 'HttpsError';
    }
  },
}));

// Mock firebase-admin Firestore to avoid network calls
jest.mock('firebase-admin', () => {
  const mockDoc = (data: unknown, exists = true) => ({
    exists,
    data: () => data as Record<string, unknown>,
    id: 'mock-id',
    ref: {
      update: jest.fn().mockResolvedValue(undefined),
      delete: jest.fn().mockResolvedValue(undefined),
      set: jest.fn().mockResolvedValue(undefined),
    },
  });

  const mockCollection = {
    doc: jest.fn(() => ({
      get: jest.fn().mockResolvedValue(mockDoc({ role: 'admin' })),
      set: jest.fn().mockResolvedValue(undefined),
      update: jest.fn().mockResolvedValue(undefined),
      delete: jest.fn().mockResolvedValue(undefined),
    })),
    add: jest.fn().mockResolvedValue({ id: 'new-doc-id' }),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({ docs: [], empty: true }),
  };

  const firestoreMock = jest.fn(() => ({ collection: () => mockCollection })) as unknown as jest.Mock;
  type FirestoreWithField = { FieldValue?: { serverTimestamp: jest.Mock } };
  (firestoreMock as unknown as FirestoreWithField).FieldValue = { serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP') };

  return {
    apps: [],
    initializeApp: jest.fn(),
    credential: { cert: jest.fn() },
    firestore: firestoreMock,
    auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
    messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue({}) })),
    storage: jest.fn(() => ({ bucket: jest.fn(() => ({ file: jest.fn(() => ({ delete: jest.fn().mockResolvedValue(undefined) })) })) })),
  };
});

// Mock nodemailer so we can control sendMail behavior
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(),
}));


// Provide env vars required during module initialization
process.env.STORAGE_BUCKET = process.env.STORAGE_BUCKET || 'test-bucket';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: 'test' });

// Ensure SMTP env vars are present for getBugReportTransport
process.env.IMPROVMX_SMTP_USER = process.env.IMPROVMX_SMTP_USER || 'test-user';
process.env.IMPROVMX_SMTP_PASS = process.env.IMPROVMX_SMTP_PASS || 'test-pass';
process.env.IMPROVMX_SMTP_TO = process.env.IMPROVMX_SMTP_TO || 'support@example.com';
process.env.IMPROVMX_SMTP_FROM = process.env.IMPROVMX_SMTP_FROM || 'no-reply@example.com';

import { reportBug } from '../index';

describe('reportBug callable', () => {
  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should reject invalid payload', async () => {
    const request: { data: unknown; auth: unknown } = { data: {}, auth: null };

    await expect((reportBug as unknown as (req: unknown) => Promise<unknown>)(request)).rejects.toThrow('Invalid bug report payload');
  });

  it('BugReport schema should validate and reject invalid payloads', async () => {
    const { BugReportSchema } = await import('../index');
    const valid = BugReportSchema.safeParse({ description: 'a valid description' });
    expect(valid.success).toBe(true);

    const invalid = BugReportSchema.safeParse({});
    expect(invalid.success).toBe(false);
  });

  it('buildBugReportEmailHtml should escape HTML and include expected fields', async () => {
    const { buildBugReportEmailHtml } = await import('../index');
    const html = buildBugReportEmailHtml({
      reportId: 'r1',
      userEmail: 'u@example.com',
      userId: 'uid1',
      appVersion: '1.0.0',
      buildNumber: '1',
      platform: 'ios',
      screenshotUrl: 'https://example.com/s.png',
      description: '<script>alert(1)</script>\nNew line',
    });

    expect(html).toContain('Report r1');
    expect(html).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
    expect(html).toContain('View screenshot');
    expect(html).toContain('uid1');
  });

  it('getBugReportTransport should throw if SMTP creds missing', async () => {
    const { getBugReportTransport } = await import('../index');
    // Temporarily unset env vars
    const origUser = process.env.IMPROVMX_SMTP_USER;
    const origPass = process.env.IMPROVMX_SMTP_PASS;
    delete process.env.IMPROVMX_SMTP_USER;
    delete process.env.IMPROVMX_SMTP_PASS;

    await expect(getBugReportTransport()).rejects.toThrow('Missing IMPROVMX_SMTP_USER or IMPROVMX_SMTP_PASS');

    // restore
    process.env.IMPROVMX_SMTP_USER = origUser;
    process.env.IMPROVMX_SMTP_PASS = origPass;
  });
});
