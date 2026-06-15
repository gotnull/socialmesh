// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/providers/signal_providers.dart';

// A feed refresh reads the DB then replaces the in-memory map. A mesh signal
// that arrives DURING that async read isn't in the DB snapshot yet, so a plain
// replace clobbers it ("flash then vanish"). mergeRefreshSignals preserves such
// non-expired in-memory arrivals while still dropping expired strays.
void main() {
  final now = DateTime.utc(2026, 1, 1, 12, 0, 0);

  Post signal(String id, {DateTime? expiresAt}) => Post(
    id: id,
    authorId: 'a',
    content: 'c',
    createdAt: now,
    postMode: PostMode.signal,
    expiresAt: expiresAt,
  );

  group('mergeRefreshSignals', () {
    test('keeps all DB signals', () {
      final db = [signal('a'), signal('b')];
      final result = mergeRefreshSignals(db, const [], now);
      expect(result.map((s) => s.id), ['a', 'b']);
    });

    test('preserves a non-expired in-memory signal missing from the DB', () {
      final db = [signal('a')];
      final inMemory = [
        signal('a'),
        signal('arrived', expiresAt: now.add(const Duration(minutes: 30))),
      ];
      final result = mergeRefreshSignals(db, inMemory, now);
      expect(result.map((s) => s.id), containsAll(['a', 'arrived']));
    });

    test('drops an expired in-memory signal missing from the DB', () {
      final db = [signal('a')];
      final inMemory = [
        signal('a'),
        signal('stale', expiresAt: now.subtract(const Duration(seconds: 1))),
      ];
      final result = mergeRefreshSignals(db, inMemory, now);
      expect(result.map((s) => s.id), ['a']);
    });

    test('does not duplicate a signal present in both DB and memory', () {
      final db = [signal('a')];
      final inMemory = [signal('a')];
      final result = mergeRefreshSignals(db, inMemory, now);
      expect(result.where((s) => s.id == 'a').length, 1);
    });

    test('treats a null expiry as non-expired and preserves it', () {
      final db = <Post>[];
      final inMemory = [signal('persistent')];
      final result = mergeRefreshSignals(db, inMemory, now);
      expect(result.map((s) => s.id), ['persistent']);
    });
  });
}
