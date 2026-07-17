// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Port of the canonical reference test matrix
// (meshtastic-ios/MeshtasticTests/MarkdownFormattingTests.swift) plus
// Dart-specific UTF-16 surrogate-boundary cases. The two implementations
// must keep producing identical wire text for identical gestures.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/markdown_formatting.dart';

String _selected(FormattingResult r) =>
    r.text.substring(r.selectionStart, r.selectionEnd);

// Selection helper mirroring Swift's `text.range(of:)`.
(int, int) _rangeOf(String text, String needle) {
  final start = text.indexOf(needle);
  expect(start, greaterThanOrEqualTo(0), reason: 'needle "$needle" not found');
  return (start, start + needle.length);
}

void main() {
  group('wrapSelection', () {
    test('wraps word with bold delimiters', () {
      final (s, e) = _rangeOf('hello world', 'world');
      final r = wrapSelection('hello world', s, e, MarkdownStyle.bold);
      expect(r.text, 'hello **world**');
      expect(_selected(r), '**world**');
    });

    test('wraps word with italic delimiters', () {
      final (s, e) = _rangeOf('hello world', 'world');
      final r = wrapSelection('hello world', s, e, MarkdownStyle.italic);
      expect(r.text, 'hello *world*');
      expect(_selected(r), '*world*');
    });

    test('wraps word with strikethrough delimiters', () {
      final (s, e) = _rangeOf('hello world', 'world');
      final r = wrapSelection('hello world', s, e, MarkdownStyle.strikethrough);
      expect(r.text, 'hello ~~world~~');
      expect(_selected(r), '~~world~~');
    });

    test('wraps word with code delimiters', () {
      final (s, e) = _rangeOf('hello world', 'world');
      final r = wrapSelection('hello world', s, e, MarkdownStyle.code);
      expect(r.text, 'hello `world`');
      expect(_selected(r), '`world`');
    });

    test('toggle off bold removes ** delimiters', () {
      final (s, e) = _rangeOf('hello **world**', 'world');
      final r = wrapSelection('hello **world**', s, e, MarkdownStyle.bold);
      expect(r.text, 'hello world');
      expect(_selected(r), 'world');
    });

    test('toggle off italic removes * delimiters', () {
      final (s, e) = _rangeOf('hello *world*', 'world');
      final r = wrapSelection('hello *world*', s, e, MarkdownStyle.italic);
      expect(r.text, 'hello world');
      expect(_selected(r), 'world');
    });

    test('toggle off strikethrough removes ~~ delimiters', () {
      final (s, e) = _rangeOf('hello ~~world~~', 'world');
      final r = wrapSelection(
        'hello ~~world~~',
        s,
        e,
        MarkdownStyle.strikethrough,
      );
      expect(r.text, 'hello world');
      expect(_selected(r), 'world');
    });

    test('toggle off code removes backtick delimiters', () {
      final (s, e) = _rangeOf('hello `world`', 'world');
      final r = wrapSelection('hello `world`', s, e, MarkdownStyle.code);
      expect(r.text, 'hello world');
      expect(_selected(r), 'world');
    });

    test('wraps at start of string', () {
      final (s, e) = _rangeOf('hello world', 'hello');
      final r = wrapSelection('hello world', s, e, MarkdownStyle.bold);
      expect(r.text, '**hello** world');
      expect(_selected(r), '**hello**');
    });

    test('wraps entire string', () {
      final r = wrapSelection('hello', 0, 5, MarkdownStyle.italic);
      expect(r.text, '*hello*');
      expect(_selected(r), '*hello*');
    });

    test('trailing whitespace in selection moves outside delimiters', () {
      final (s, e) = _rangeOf('no key or a 1-byte', 'or ');
      final r = wrapSelection('no key or a 1-byte', s, e, MarkdownStyle.italic);
      expect(r.text, 'no key *or* a 1-byte');
      expect(_selected(r), '*or*');
    });

    test('leading whitespace in selection moves outside delimiters', () {
      final (s, e) = _rangeOf('hello world end', ' world');
      final r = wrapSelection('hello world end', s, e, MarkdownStyle.bold);
      expect(r.text, 'hello **world** end');
      expect(_selected(r), '**world**');
    });

    test('leading and trailing whitespace both move outside delimiters', () {
      final (s, e) = _rangeOf('hello world end', ' world ');
      final r = wrapSelection('hello world end', s, e, MarkdownStyle.italic);
      expect(r.text, 'hello *world* end');
      expect(_selected(r), '*world*');
    });

    test('whitespace-only selection degrades to delimiter insertion', () {
      final r = wrapSelection('hello world', 5, 6, MarkdownStyle.bold);
      expect(r.text, 'hello**** world');
      expect(r.selectionStart, r.selectionEnd);
      expect(r.selectionStart, 7);
    });
  });

  group('insertDelimiters', () {
    test('inserts bold delimiters at end of string', () {
      final r = insertDelimiters('hello ', 6, MarkdownStyle.bold);
      expect(r.text, 'hello ****');
      expect(r.selectionStart, r.selectionEnd);
      expect(r.selectionStart, 8);
    });

    test('inserts italic delimiters in empty string', () {
      final r = insertDelimiters('', 0, MarkdownStyle.italic);
      expect(r.text, '**');
      expect(r.selectionStart, 1);
      expect(r.selectionEnd, 1);
    });

    test('inserts code delimiters at cursor position', () {
      final r = insertDelimiters('hello world', 6, MarkdownStyle.code);
      expect(r.text, 'hello ``world');
      expect(r.selectionStart, 7);
    });

    test('inserts strikethrough delimiters at end', () {
      final r = insertDelimiters('test', 4, MarkdownStyle.strikethrough);
      expect(r.text, 'test~~~~');
      expect(r.selectionStart, 6);
    });

    test('inserts at beginning of non-empty string', () {
      final r = insertDelimiters('hello', 0, MarkdownStyle.bold);
      expect(r.text, '****hello');
      expect(r.selectionStart, 2);
    });
  });

  group('containsMarkdownSyntax', () {
    test('plain text returns false', () {
      expect(containsMarkdownSyntax('hello world'), isFalse);
    });

    test('empty string returns false', () {
      expect(containsMarkdownSyntax(''), isFalse);
    });

    test('paired italic returns true', () {
      expect(containsMarkdownSyntax('hello *world*'), isTrue);
    });

    test('paired bold returns true', () {
      expect(containsMarkdownSyntax('hello **world**'), isTrue);
    });

    test('paired strikethrough returns true', () {
      expect(containsMarkdownSyntax('hello ~~world~~'), isTrue);
    });

    test('paired backtick returns true', () {
      expect(containsMarkdownSyntax('hello `world`'), isTrue);
    });

    test('numbers and spaces return false', () {
      expect(containsMarkdownSyntax('123 456 789'), isFalse);
    });

    test('unpaired delimiters return false', () {
      expect(containsMarkdownSyntax('S~~e**e*'), isFalse);
    });

    test('single asterisk without pair returns false', () {
      expect(containsMarkdownSyntax('hello * world'), isFalse);
    });

    test('single tilde without pair returns false', () {
      expect(containsMarkdownSyntax('hello ~ world'), isFalse);
    });

    test('link syntax returns true', () {
      expect(
        containsMarkdownSyntax('check [hello](https://example.com) out'),
        isTrue,
      );
    });
  });

  group('bold+italic combinations', () {
    test('italic applied to bold span strips bold and applies italic', () {
      final (s, e) = _rangeOf('hello **world** end', '**world**');
      final r = wrapSelection(
        'hello **world** end',
        s,
        e,
        MarkdownStyle.italic,
      );
      expect(r.text, 'hello *world* end');
    });

    test('bold applied to italic span strips italic and applies bold', () {
      final (s, e) = _rangeOf('hello *world* end', '*world*');
      final r = wrapSelection('hello *world* end', s, e, MarkdownStyle.bold);
      expect(r.text, 'hello **world** end');
    });

    test('strikethrough on mixed delimiters strips all and applies', () {
      final (s, e) = _rangeOf('hello **wo*rld** end', '**wo*rld**');
      final r = wrapSelection(
        'hello **wo*rld** end',
        s,
        e,
        MarkdownStyle.strikethrough,
      );
      expect(r.text, 'hello ~~world~~ end');
    });

    test('toggle bold off from triple-star leaves italic', () {
      final (s, e) = _rangeOf('hello ***world*** end', 'world');
      final r = wrapSelection(
        'hello ***world*** end',
        s,
        e,
        MarkdownStyle.bold,
      );
      expect(r.text, 'hello *world* end');
      expect(_selected(r), 'world');
    });

    test('garbled delimiters cleaned up on format apply', () {
      const text = 'abc****~~~****jd~~';
      final r = wrapSelection(text, 0, text.length, MarkdownStyle.bold);
      expect(r.text, '**abcjd**');
    });

    test('odd count tildes fully stripped', () {
      const text = '~~~hello~~~';
      final r = wrapSelection(text, 0, text.length, MarkdownStyle.italic);
      expect(r.text, '*hello*');
    });

    test('partial selection across delimiter boundary expands', () {
      const text = '**the** rocky';
      final r = wrapSelection(text, 4, 8, MarkdownStyle.strikethrough);
      expect(r.text.contains('**'), isFalse);
      expect(r.text.contains('~~'), isTrue);
    });

    test('selection starting inside delimiters expands left', () {
      const text = 'hello **world** end';
      final r = wrapSelection(text, 7, 12, MarkdownStyle.italic);
      expect(r.text.contains('**'), isFalse);
    });
  });

  group('link formatting', () {
    test('isMarkdownLink true for valid link', () {
      expect(isMarkdownLink('[text](https://example.com)'), isTrue);
    });

    test('isMarkdownLink false for plain text', () {
      expect(isMarkdownLink('hello world'), isFalse);
    });

    test('isMarkdownLink false for partial patterns', () {
      expect(isMarkdownLink('[text]'), isFalse);
      expect(isMarkdownLink('(url)'), isFalse);
      expect(isMarkdownLink('[text]('), isFalse);
    });

    test('wrapSelectionWithLink wraps selected text with URL', () {
      final (s, e) = _rangeOf('hello world', 'hello');
      final r = wrapSelectionWithLink(
        'hello world',
        s,
        e,
        'https://example.com',
      );
      expect(r.text, '[hello](https://example.com) world');
      expect(_selected(r), '[hello](https://example.com)');
    });

    test('wrapSelectionWithLink with collapsed cursor inserts placeholder', () {
      final r = wrapSelectionWithLink(
        'hello world',
        5,
        5,
        'https://example.com',
      );
      expect(r.text, 'hello[link text](https://example.com) world');
      expect(_selected(r), '[link text](https://example.com)');
    });

    test('unwrapLink extracts display text from link', () {
      const text = '[hello](https://example.com)';
      final r = unwrapLink(text, 0, text.length);
      expect(r, isNotNull);
      expect(r!.text, 'hello');
      expect(_selected(r), 'hello');
    });

    test('unwrapLink returns null for plain text', () {
      expect(unwrapLink('hello world', 0, 11), isNull);
    });
  });

  group('UTF-16 safety (Dart-specific)', () {
    test('clampToCharacterBoundary snaps off a low surrogate', () {
      const text = 'a\u{1F525}b'; // 'a' + fire emoji (2 units) + 'b'
      expect(clampToCharacterBoundary(text, 2), 1);
      expect(clampToCharacterBoundary(text, 1), 1);
      expect(clampToCharacterBoundary(text, 3), 3);
    });

    test('clampToCharacterBoundary clamps out-of-range offsets', () {
      expect(clampToCharacterBoundary('abc', -2), 0);
      expect(clampToCharacterBoundary('abc', 99), 3);
    });

    test('wrapping a selection containing emoji preserves the emoji', () {
      const text = 'go \u{1F525}\u{1F44D} now';
      final (s, e) = _rangeOf(text, '\u{1F525}\u{1F44D}');
      final r = wrapSelection(text, s, e, MarkdownStyle.bold);
      expect(r.text, 'go **\u{1F525}\u{1F44D}** now');
      expect(_selected(r), '**\u{1F525}\u{1F44D}**');
    });

    test('selection edge inside a surrogate pair never splits the emoji', () {
      const text = 'go \u{1F525} now'; // emoji occupies units 3-4
      final r = wrapSelection(text, 4, 5, MarkdownStyle.bold);
      // The start edge snaps back to unit 3; the emoji stays intact.
      expect(r.text, contains('\u{1F525}'));
      expect(r.text, 'go **\u{1F525}** now');
    });

    test('insertDelimiters mid-surrogate snaps to the pair start', () {
      const text = '\u{1F525}x';
      final r = insertDelimiters(text, 1, MarkdownStyle.code);
      expect(r.text, '``\u{1F525}x');
      expect(r.selectionStart, 1);
    });
  });
}
