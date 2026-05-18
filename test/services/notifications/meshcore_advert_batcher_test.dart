// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/meshcore_advert_batcher.dart';

void main() {
  MeshCoreAdvertBatchEntry entry(String pubKey, [String? name, DateTime? at]) {
    return MeshCoreAdvertBatchEntry(
      pubKeyHex: pubKey,
      displayName: name ?? pubKey,
      heardAt: at ?? DateTime(2026, 5, 18, 12),
    );
  }

  group('MeshCoreAdvertBatcher', () {
    test('starts empty', () {
      final b = MeshCoreAdvertBatcher();
      expect(b.isEmpty, isTrue);
      expect(b.pendingCount, 0);
      expect(b.drain(), isEmpty);
    });

    test('add appends entries in order', () {
      final b = MeshCoreAdvertBatcher();
      b.add(entry('aa'));
      b.add(entry('bb'));
      b.add(entry('cc'));
      expect(b.pendingCount, 3);
      expect(b.pendingSnapshot.map((e) => e.pubKeyHex).toList(), [
        'aa',
        'bb',
        'cc',
      ]);
    });

    test('re-add of same pubkey moves entry to tail and refreshes heardAt', () {
      final b = MeshCoreAdvertBatcher();
      b.add(entry('aa', 'A', DateTime(2026, 5, 18, 12)));
      b.add(entry('bb', 'B', DateTime(2026, 5, 18, 12, 1)));
      b.add(entry('aa', 'A again', DateTime(2026, 5, 18, 12, 2)));
      expect(b.pendingCount, 2);
      expect(b.pendingSnapshot.map((e) => e.pubKeyHex).toList(), ['bb', 'aa']);
      expect(b.pendingSnapshot.last.displayName, 'A again');
      expect(b.pendingSnapshot.last.heardAt, DateTime(2026, 5, 18, 12, 2));
    });

    test('evicts oldest when over maxBuffered', () {
      final b = MeshCoreAdvertBatcher(maxBuffered: 3);
      b.add(entry('aa'));
      b.add(entry('bb'));
      b.add(entry('cc'));
      b.add(entry('dd'));
      expect(b.pendingCount, 3);
      expect(b.pendingSnapshot.map((e) => e.pubKeyHex).toList(), [
        'bb',
        'cc',
        'dd',
      ]);
    });

    test('drain returns all entries and empties buffer', () {
      final b = MeshCoreAdvertBatcher();
      b.add(entry('aa'));
      b.add(entry('bb'));
      final drained = b.drain();
      expect(drained.map((e) => e.pubKeyHex), ['aa', 'bb']);
      expect(b.isEmpty, isTrue);
    });

    test('drain on empty buffer returns empty list and stays empty', () {
      final b = MeshCoreAdvertBatcher();
      expect(b.drain(), isEmpty);
      expect(b.isEmpty, isTrue);
    });

    test('clear empties buffer without surfacing entries', () {
      final b = MeshCoreAdvertBatcher();
      b.add(entry('aa'));
      b.add(entry('bb'));
      b.clear();
      expect(b.isEmpty, isTrue);
      expect(b.drain(), isEmpty);
    });

    test('pendingSnapshot is unmodifiable', () {
      final b = MeshCoreAdvertBatcher();
      b.add(entry('aa'));
      final snap = b.pendingSnapshot;
      expect(() => snap.add(entry('bb')), throwsUnsupportedError);
    });
  });
}
