// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/markdown_inline_parser.dart';

void main() {
  group('parseInlineMarkdown basics', () {
    test('empty string yields no segments', () {
      expect(parseInlineMarkdown(''), isEmpty);
    });

    test('plain text yields one plain segment', () {
      final segs = parseInlineMarkdown('hello world');
      expect(segs, hasLength(1));
      expect(segs.single.text, 'hello world');
      expect(segs.single.isPlain, isTrue);
    });

    test('bold span', () {
      final segs = parseInlineMarkdown('a **b** c');
      expect(segs.map((s) => s.text), ['a ', 'b', ' c']);
      expect(segs[1].bold, isTrue);
      expect(segs[0].isPlain, isTrue);
      expect(segs[2].isPlain, isTrue);
    });

    test('italic span', () {
      final segs = parseInlineMarkdown('a *b* c');
      expect(segs[1].text, 'b');
      expect(segs[1].italic, isTrue);
      expect(segs[1].bold, isFalse);
    });

    test('strikethrough span', () {
      final segs = parseInlineMarkdown('a ~~b~~ c');
      expect(segs[1].text, 'b');
      expect(segs[1].strikethrough, isTrue);
    });

    test('code span renders contents literally', () {
      final segs = parseInlineMarkdown('run `ls **-la**` now');
      expect(segs[1].text, 'ls **-la**');
      expect(segs[1].code, isTrue);
      expect(segs[1].bold, isFalse);
    });

    test('http link is tappable', () {
      final segs = parseInlineMarkdown('see [docs](https://example.com) ok');
      expect(segs[1].text, 'docs');
      expect(segs[1].linkUrl, 'https://example.com');
    });
  });

  group('nesting', () {
    test('triple star is bold italic', () {
      final segs = parseInlineMarkdown('***x***');
      expect(segs.single.text, 'x');
      expect(segs.single.bold, isTrue);
      expect(segs.single.italic, isTrue);
    });

    test('italic inside bold composes', () {
      final segs = parseInlineMarkdown('**a *b* c**');
      expect(segs.map((s) => s.text), ['a ', 'b', ' c']);
      expect(segs.every((s) => s.bold), isTrue);
      expect(segs[1].italic, isTrue);
      expect(segs[0].italic, isFalse);
    });

    test('strikethrough inside bold composes', () {
      final segs = parseInlineMarkdown('**a ~~b~~**');
      expect(segs[1].strikethrough, isTrue);
      expect(segs[1].bold, isTrue);
    });
  });

  group('malformed input renders literally and never throws', () {
    test('unpaired bold marker is literal', () {
      final segs = parseInlineMarkdown('a **b c');
      expect(segs.single.text, 'a **b c');
      expect(segs.single.isPlain, isTrue);
    });

    test('unpaired italic marker is literal', () {
      final segs = parseInlineMarkdown('5 * 3 = 15');
      // "* 3 = 15" contains no closing single asterisk, so all literal.
      expect(segs.map((s) => s.text).join(), '5 * 3 = 15');
      expect(segs.every((s) => s.isPlain), isTrue);
    });

    test('italic closer directly before bold opener is not italic', () {
      final segs = parseInlineMarkdown('*a**b**');
      // Mirrors the canonical (?<!\*)\*[^*]+\*(?!\*) pattern: "*a" has no
      // valid single-star closer, so the leading star stays literal.
      expect(segs.first.text, startsWith('*a'));
      expect(segs.first.italic, isFalse);
    });

    test('empty delimiter pair is literal', () {
      final segs = parseInlineMarkdown('a **** b');
      expect(segs.map((s) => s.text).join(), 'a **** b');
    });

    test('partial link is literal', () {
      final segs = parseInlineMarkdown('[text]( and [more]');
      expect(segs.map((s) => s.text).join(), '[text]( and [more]');
      expect(segs.every((s) => s.linkUrl == null), isTrue);
    });

    test('non-http link scheme renders whole source literally', () {
      final segs = parseInlineMarkdown('[x](javascript:alert(1))');
      expect(segs.every((s) => s.linkUrl == null), isTrue);
      expect(segs.map((s) => s.text).join(), contains('[x]('));
    });

    test('nested bracket display text is not a link', () {
      final segs = parseInlineMarkdown('[[a]](https://example.com)');
      expect(segs.every((s) => s.linkUrl == null), isTrue);
    });

    test('emoji passes through untouched', () {
      final segs = parseInlineMarkdown('**\u{1F525}** ok');
      expect(segs.first.text, '\u{1F525}');
      expect(segs.first.bold, isTrue);
    });

    test('pathological delimiter soup never throws', () {
      const soup = '***~~`[*`~]~(*)`**~~*`~[](';
      expect(() => parseInlineMarkdown(soup), returnsNormally);
      final segs = parseInlineMarkdown(soup);
      expect(segs.map((s) => s.text).join(), isNotEmpty);
    });

    test('deep nesting is bounded', () {
      final deep = '${'**' * 40}x${'**' * 40}';
      expect(() => parseInlineMarkdown(deep), returnsNormally);
    });
  });

  group('round-trip fidelity for unstyled content', () {
    test('literal text is preserved through the parser', () {
      const samples = [
        'plain text with no markup at all',
        'math like 2*3 and 4 ** 2 stays put',
        'tildes ~ here ~ and back`tick',
      ];
      for (final s in samples) {
        final joined = parseInlineMarkdown(s).map((seg) => seg.text).join();
        expect(joined, s);
      }
    });
  });
}
