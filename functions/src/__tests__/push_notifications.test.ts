import { sanitizeNotificationKey } from '../push_notifications';

describe('Push notification helpers', () => {
  test('sanitizeNotificationKey removes illegal characters', () => {
    const key = 'signal_vote:user/123:comment#1';
    const sanitized = sanitizeNotificationKey(key);
    expect(sanitized).not.toContain('/');
    expect(sanitized).not.toContain('#');
    expect(sanitized).toBe('signal_vote_user_123_comment_1');
  });
});
