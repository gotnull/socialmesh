// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Typed record keys must use value equality so Riverpod family providers
// memoize correctly and invalidation targets the right cache entry.
//
// String-concat keys ("slug|boardId|sectionId") were replaced because a
// pipe character in a slug or id could silently split incorrectly.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/providers/nodeboard_providers.dart';

void main() {
  group('ThreadListKey', () {
    test('equal for same fields', () {
      const a = ThreadListKey(slug: 's1', boardId: 'b1', sectionId: 'sec1');
      const b = ThreadListKey(slug: 's1', boardId: 'b1', sectionId: 'sec1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal for different fields', () {
      const a = ThreadListKey(slug: 's1', boardId: 'b1', sectionId: 'sec1');
      const b = ThreadListKey(slug: 's1', boardId: 'b1', sectionId: 'sec2');
      expect(a, isNot(b));
    });

    test('handles pipe character in fields without collision', () {
      // Former string key "slug|boardId|sectionId" could misparse these.
      const a = ThreadListKey(slug: 'a|b', boardId: 'c', sectionId: 'd');
      const b = ThreadListKey(slug: 'a', boardId: 'b|c', sectionId: 'd');
      expect(a, isNot(b));
    });
  });

  group('ThreadDetailKey', () {
    test('equal for same fields', () {
      const a = ThreadDetailKey(slug: 's1', threadId: 't1');
      const b = ThreadDetailKey(slug: 's1', threadId: 't1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal for different threadIds', () {
      const a = ThreadDetailKey(slug: 's1', threadId: 't1');
      const b = ThreadDetailKey(slug: 's1', threadId: 't2');
      expect(a, isNot(b));
    });

    test('handles pipe character in fields without collision', () {
      const a = ThreadDetailKey(slug: 'a|b', threadId: 'c');
      const b = ThreadDetailKey(slug: 'a', threadId: 'b|c');
      expect(a, isNot(b));
    });
  });
}
