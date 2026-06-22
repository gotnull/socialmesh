// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/emoji_text.dart';

void main() {
  group('emojiOnlyCount', () {
    test('counts a single emoji', () {
      expect(emojiOnlyCount('😊'), 1);
    });

    test('counts two adjacent emoji', () {
      expect(emojiOnlyCount('😊😉'), 2);
    });

    test('counts emoji separated by whitespace', () {
      expect(emojiOnlyCount('😊 😉 😄'), 3);
    });

    test('counts four in a row', () {
      expect(emojiOnlyCount('😊😉😄😄'), 4);
    });

    test('ignores leading and trailing whitespace', () {
      expect(emojiOnlyCount('  😊😉  '), 2);
    });

    test('treats text with an emoji as not emoji-only', () {
      expect(emojiOnlyCount('Test 😄'), 0);
    });

    test('treats a leading emoji with trailing text as not emoji-only', () {
      expect(emojiOnlyCount('😄 hello'), 0);
    });

    test('returns 0 for plain text', () {
      expect(emojiOnlyCount('hello'), 0);
    });

    test('returns 0 for empty string', () {
      expect(emojiOnlyCount(''), 0);
    });

    test('returns 0 for whitespace only', () {
      expect(emojiOnlyCount('   '), 0);
    });

    test('counts a ZWJ family sequence as one emoji', () {
      expect(emojiOnlyCount('👨‍👩‍👧‍👦'), 1);
    });

    test('counts a regional-indicator flag as one emoji', () {
      expect(emojiOnlyCount('🇩🇪'), 1);
    });

    test('counts a keycap sequence as one emoji', () {
      expect(emojiOnlyCount('1️⃣'), 1);
    });

    test('counts a skin-tone modified emoji as one emoji', () {
      expect(emojiOnlyCount('👍🏽'), 1);
    });

    test('counts mixed emoji families', () {
      expect(emojiOnlyCount('👨‍👩‍👧‍👦🇩🇪👍🏽'), 3);
    });

    test('treats a bare digit as not emoji', () {
      expect(emojiOnlyCount('1'), 0);
    });
  });

  group('isEmojiOnly', () {
    test('is true for emoji-only content', () {
      expect(isEmojiOnly('😊😉'), isTrue);
    });

    test('is false when text is present', () {
      expect(isEmojiOnly('Test 😄'), isFalse);
    });

    test('is false for empty input', () {
      expect(isEmojiOnly(''), isFalse);
    });
  });
}
