// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D43-A1: `MeshCoreMessageStore.loadContactMessagesBefore` /
// `loadChannelMessagesBefore` paging pins.
//
// Pinned invariants (this file):
//   - `before == null` returns the newest [limit] rows ascending.
//   - A three-page walk has no duplicates and the union equals the
//     full partition.
//   - Compound cursor handles duplicate timestamps deterministically
//     (strictly less by id when timestamps collide).
//   - `before != null` with `beforeId == null` throws
//     `ArgumentError`.
//   - `limit` clamps to the partition cap (500) and treats zero /
//     negative as "no rows".
//   - Empty partition returns `[]`.
//   - Partition isolation: contact A's cursor never returns contact
//     B's rows; same for channels.
//   - Channel paging mirrors contact paging.
//   - Existing `loadContactMessages` / `loadChannelMessages` are
//     unchanged (regression pin against the D43-A1 store edit).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

const String _contactAHex =
    'aaaaaaaa00112233445566778899aabbccddeeff00112233445566778899aabb';
const String _contactBHex =
    'bbbbbbbb00112233445566778899aabbccddeeff00112233445566778899aabb';

final Uint8List _senderKey = Uint8List.fromList(List.generate(32, (i) => i));

MeshCoreStoredMessage _msg({
  required String id,
  required DateTime timestamp,
  String text = 'msg',
  bool isOutgoing = false,
}) {
  return MeshCoreStoredMessage(
    id: id,
    senderKey: _senderKey,
    text: text,
    timestamp: timestamp,
    isOutgoing: isOutgoing,
    status: MeshCoreMessageStatus.delivered,
  );
}

Future<void> _seedSequential(
  MeshCoreMessageStore store,
  String contactKeyHex, {
  required int count,
  DateTime? startAt,
}) async {
  final t0 = startAt ?? DateTime.utc(2026, 5, 12, 9);
  for (int i = 0; i < count; i++) {
    await store.addContactMessage(
      contactKeyHex,
      _msg(
        id: 'm-${i.toString().padLeft(4, '0')}',
        timestamp: t0.add(Duration(minutes: i)),
        text: 'message $i',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeshCoreMessageStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = MeshCoreMessageStore();
    await store.init();
  });

  group('loadContactMessagesBefore - D43-A1', () {
    test('before == null returns newest [limit] rows ascending', () async {
      await _seedSequential(store, _contactAHex, count: 12);

      final page = await store.loadContactMessagesBefore(
        _contactAHex,
        limit: 5,
      );

      expect(page, hasLength(5));
      // Ascending order by timestamp.
      for (int i = 1; i < page.length; i++) {
        expect(
          page[i].timestamp.isAfter(page[i - 1].timestamp) ||
              page[i].timestamp.isAtSameMomentAs(page[i - 1].timestamp),
          isTrue,
          reason: 'pages must be ascending: ${page[i - 1].id} -> ${page[i].id}',
        );
      }
      // Newest five of twelve: ids m-0007..m-0011.
      expect(
        page.map((m) => m.id).toList(),
        equals(['m-0007', 'm-0008', 'm-0009', 'm-0010', 'm-0011']),
      );
    });

    test(
      'three-page walk: no duplicates, union equals full partition',
      () async {
        await _seedSequential(store, _contactAHex, count: 9);
        final all = await store.loadContactMessages(_contactAHex);
        expect(all, hasLength(9));

        const pageSize = 3;
        final pages = <List<MeshCoreStoredMessage>>[];

        // Page 1: newest three.
        var page = await store.loadContactMessagesBefore(
          _contactAHex,
          limit: pageSize,
        );
        pages.add(page);

        // Pages 2 and 3 walk older using the oldest of the previous page
        // as the cursor.
        while (page.isNotEmpty && pages.length < 3) {
          final cursor = page.first;
          page = await store.loadContactMessagesBefore(
            _contactAHex,
            before: cursor.timestamp,
            beforeId: cursor.id,
            limit: pageSize,
          );
          if (page.isNotEmpty) pages.add(page);
        }

        expect(pages, hasLength(3));
        final union = <String>{};
        for (final p in pages) {
          for (final m in p) {
            expect(
              union.add(m.id),
              isTrue,
              reason: 'duplicate row across pages: ${m.id}',
            );
          }
        }
        expect(union.length, equals(9));
        expect(union, equals(all.map((m) => m.id).toSet()));
      },
    );

    test(
      'compound cursor: collision-timestamp rows resolve by id strictly less',
      () async {
        // Three messages share the same timestamp. The store has no
        // database-level tiebreaker so the cursor must.
        final t = DateTime.utc(2026, 5, 12, 9);
        await store.addContactMessage(
          _contactAHex,
          _msg(id: 'm-a', timestamp: t),
        );
        await store.addContactMessage(
          _contactAHex,
          _msg(id: 'm-b', timestamp: t),
        );
        await store.addContactMessage(
          _contactAHex,
          _msg(id: 'm-c', timestamp: t),
        );
        // And one strictly newer to anchor the "before" cursor at the
        // collision.
        await store.addContactMessage(
          _contactAHex,
          _msg(id: 'm-d', timestamp: t.add(const Duration(minutes: 1))),
        );

        // First page: newest two -> m-c, m-d (ascending). Cursor for
        // older: m-c.
        final page1 = await store.loadContactMessagesBefore(
          _contactAHex,
          limit: 2,
        );
        expect(page1.map((m) => m.id), equals(['m-c', 'm-d']));

        // Older than m-c: timestamps tied with m-a, m-b — both have
        // ids lexically < 'm-c', so both qualify. Strictly-less by id
        // excludes m-c itself.
        final page2 = await store.loadContactMessagesBefore(
          _contactAHex,
          before: t,
          beforeId: 'm-c',
          limit: 5,
        );
        expect(page2.map((m) => m.id), equals(['m-a', 'm-b']));

        // Older than m-a: tied timestamp, no id strictly less.
        final page3 = await store.loadContactMessagesBefore(
          _contactAHex,
          before: t,
          beforeId: 'm-a',
          limit: 5,
        );
        expect(page3, isEmpty);
      },
    );

    test('before != null without beforeId throws ArgumentError', () async {
      await _seedSequential(store, _contactAHex, count: 3);
      expect(
        () => store.loadContactMessagesBefore(
          _contactAHex,
          before: DateTime.utc(2026, 5, 12, 9, 1),
          limit: 5,
        ),
        throwsArgumentError,
      );
    });

    test('limit clamps: huge value capped at partition cap', () async {
      await _seedSequential(store, _contactAHex, count: 3);

      // The partition cap is 500; a limit larger than that should
      // never expand the result beyond the actual row count.
      final page = await store.loadContactMessagesBefore(
        _contactAHex,
        limit: 100000,
      );
      expect(page, hasLength(3));
    });

    test('limit zero returns empty list', () async {
      await _seedSequential(store, _contactAHex, count: 3);
      final page = await store.loadContactMessagesBefore(
        _contactAHex,
        limit: 0,
      );
      expect(page, isEmpty);
    });

    test('limit negative returns empty list', () async {
      await _seedSequential(store, _contactAHex, count: 3);
      final page = await store.loadContactMessagesBefore(
        _contactAHex,
        limit: -7,
      );
      expect(page, isEmpty);
    });

    test('empty partition returns []', () async {
      final page = await store.loadContactMessagesBefore(
        _contactAHex,
        limit: 5,
      );
      expect(page, isEmpty);
    });

    test(
      'partition isolation: contact A cursor never returns B rows',
      () async {
        await _seedSequential(store, _contactAHex, count: 4);
        await _seedSequential(store, _contactBHex, count: 4);

        final pageA = await store.loadContactMessagesBefore(
          _contactAHex,
          limit: 50,
        );
        final pageB = await store.loadContactMessagesBefore(
          _contactBHex,
          limit: 50,
        );

        // Both partitions seeded with identical id shape; isolation
        // means each load only sees its own four rows.
        expect(pageA, hasLength(4));
        expect(pageB, hasLength(4));

        // And a walked cursor on A never crosses into B.
        final cursor = pageA.first;
        final olderA = await store.loadContactMessagesBefore(
          _contactAHex,
          before: cursor.timestamp,
          beforeId: cursor.id,
          limit: 50,
        );
        expect(olderA, isEmpty);
      },
    );
  });

  group('loadChannelMessagesBefore - D43-A1', () {
    test('three-page channel walk mirrors the contact contract', () async {
      const channelIndex = 2;
      final t0 = DateTime.utc(2026, 5, 12, 9);
      for (int i = 0; i < 9; i++) {
        await store.addChannelMessage(
          channelIndex,
          _msg(
            id: 'ch-${i.toString().padLeft(4, '0')}',
            timestamp: t0.add(Duration(minutes: i)),
            text: 'channel $i',
          ),
        );
      }

      const pageSize = 3;
      final pages = <List<MeshCoreStoredMessage>>[];
      var page = await store.loadChannelMessagesBefore(
        channelIndex,
        limit: pageSize,
      );
      pages.add(page);
      while (page.isNotEmpty && pages.length < 3) {
        final cursor = page.first;
        page = await store.loadChannelMessagesBefore(
          channelIndex,
          before: cursor.timestamp,
          beforeId: cursor.id,
          limit: pageSize,
        );
        if (page.isNotEmpty) pages.add(page);
      }

      expect(pages, hasLength(3));
      final union = <String>{};
      for (final p in pages) {
        for (final m in p) {
          expect(union.add(m.id), isTrue);
        }
      }
      expect(union.length, equals(9));
    });

    test('channel partition isolation across distinct channels', () async {
      final t = DateTime.utc(2026, 5, 12, 9);
      await store.addChannelMessage(0, _msg(id: 'ch0-a', timestamp: t));
      await store.addChannelMessage(0, _msg(id: 'ch0-b', timestamp: t));
      await store.addChannelMessage(1, _msg(id: 'ch1-a', timestamp: t));

      final page0 = await store.loadChannelMessagesBefore(0, limit: 50);
      final page1 = await store.loadChannelMessagesBefore(1, limit: 50);

      expect(page0.map((m) => m.id).toSet(), equals({'ch0-a', 'ch0-b'}));
      expect(page1.map((m) => m.id).toSet(), equals({'ch1-a'}));
    });

    test(
      'channel: before != null without beforeId throws ArgumentError',
      () async {
        await store.addChannelMessage(
          3,
          _msg(id: 'ch3-only', timestamp: DateTime.utc(2026, 5, 12, 9)),
        );
        expect(
          () => store.loadChannelMessagesBefore(
            3,
            before: DateTime.utc(2026, 5, 12, 9),
            limit: 5,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('regression: existing full-load methods unchanged - D43-A1', () {
    test('loadContactMessages still returns the full partition', () async {
      await _seedSequential(store, _contactAHex, count: 5);
      final loaded = await store.loadContactMessages(_contactAHex);
      expect(loaded, hasLength(5));
      // Inserted via addContactMessage; on the no-trim path the
      // returned list is in insertion order (matches existing
      // meshcore_message_store_test pins).
      expect(loaded.map((m) => m.id).toList(), [
        'm-0000',
        'm-0001',
        'm-0002',
        'm-0003',
        'm-0004',
      ]);
    });

    test(
      'loadChannelMessages still returns the full channel partition',
      () async {
        const channelIndex = 7;
        final t0 = DateTime.utc(2026, 5, 12, 9);
        for (int i = 0; i < 4; i++) {
          await store.addChannelMessage(
            channelIndex,
            _msg(
              id: 'ch-$i',
              timestamp: t0.add(Duration(minutes: i)),
            ),
          );
        }
        final loaded = await store.loadChannelMessages(channelIndex);
        expect(loaded, hasLength(4));
        expect(loaded.map((m) => m.id).toList(), [
          'ch-0',
          'ch-1',
          'ch-2',
          'ch-3',
        ]);
      },
    );
  });
}
