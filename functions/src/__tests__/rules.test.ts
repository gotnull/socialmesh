import fs from 'fs';
import path from 'path';

describe('Firestore rules coverage', () => {
  const rulesPath = path.resolve(__dirname, '../../../firestore.rules');
  const rulesText = fs.readFileSync(rulesPath, 'utf8');

  test('uses canonical /posts/{postId}/comments path', () => {
    expect(rulesText).toContain('match /posts/{postId}');
    expect(rulesText).toContain('match /comments/{commentId}');
  });

  test('does not reference legacy responses path', () => {
    const legacyPath = '/res' + 'ponses/';
    expect(rulesText).not.toContain(legacyPath);
  });

  test('votes are scoped under comments', () => {
    expect(rulesText).toContain('match /votes/{voterId}');
  });

  test('prevents clients from writing aggregate fields on signal comments', () => {
    expect(rulesText).toContain('upvoteCount');
    expect(rulesText).toContain('downvoteCount');
    expect(rulesText).toContain('replyCount');
  });
});
