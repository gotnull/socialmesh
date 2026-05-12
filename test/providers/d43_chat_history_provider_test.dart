// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D43-A2: `meshCoreChatHistoryProvider` state-machine pins.
//
// The provider wraps the D43-A1 store paging API in a Notifier.family
// keyed by `MeshCoreChatHistoryKey`. This file pins:
//   - initial load populates the window + sets `hasMore`.
//   - loadOlder prepends a sorted older block, preserves ordering.
//   - hasMore flips false when a page returns fewer than the size.
//   - loadOlder no-ops while loading older / while loading initial /
//     when hasMore is false / when the cursor is missing.
//   - appendInbound + appendOutbound dedupe by id.
//   - appendInbound during loadOlder is safe (tail append while older
//     page is in flight).
//   - updateMessageStatus rewrites in place, no reorder.
//   - deleteLocal removes by id, no-op when absent.
//   - loadUntilContains pages until the id appears, terminates on
//     hasMore-false, and is bounded by maxPages.
//   - family scoping: contact and channel histories do not bleed.
//   - sealed key equality (Riverpod family lookup).

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

const String _contactAHex =
    'aaaaaaaa00112233445566778899aabbccddeeff00112233445566778899aabb';
const String _contactBHex =
    'bbbbbbbb00112233445566778899aabbccddeeff00112233445566778899aabb';

final Uint8List _senderKey = Uint8List.fromList(List.generate(32, (i) => i));

MeshCoreStoredMessage _storedMsg({
  required String id,
  required DateTime timestamp,
  String text = 'msg',
  bool isOutgoing = false,
  MeshCoreMessageStatus status = MeshCoreMessageStatus.delivered,
}) {
  return MeshCoreStoredMessage(
    id: id,
    senderKey: _senderKey,
    text: text,
    timestamp: timestamp,
    isOutgoing: isOutgoing,
    status: status,
  );
}

MeshCoreMessage _msg({
  required String id,
  required DateTime timestamp,
  String text = 'msg',
  bool isOutgoing = false,
  MeshCoreMessageDeliveryStatus status = MeshCoreMessageDeliveryStatus.pending,
}) {
  return MeshCoreMessage(
    id: id,
    text: text,
    timestamp: timestamp,
    isOutgoing: isOutgoing,
    status: status,
  );
}

Future<void> _seedContact(
  MeshCoreMessageStore store,
  String contactKeyHex, {
  required int count,
  DateTime? startAt,
}) async {
  final t0 = startAt ?? DateTime.utc(2026, 5, 12, 9);
  for (int i = 0; i < count; i++) {
    await store.addContactMessage(
      contactKeyHex,
      _storedMsg(
        id: 'm-${i.toString().padLeft(4, '0')}',
        timestamp: t0.add(Duration(minutes: i)),
        text: 'msg $i',
      ),
    );
  }
}

Future<void> _seedChannel(
  MeshCoreMessageStore store,
  int channelIndex, {
  required int count,
  DateTime? startAt,
}) async {
  final t0 = startAt ?? DateTime.utc(2026, 5, 12, 9);
  for (int i = 0; i < count; i++) {
    await store.addChannelMessage(
      channelIndex,
      _storedMsg(
        id: 'ch-${i.toString().padLeft(4, '0')}',
        timestamp: t0.add(Duration(minutes: i)),
        text: 'ch $i',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreChatHistoryProvider initial load - D43-A2', () {
    test('loadInitial populates window; hasMore false when partition '
        '< page size', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 5);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      expect(
        container.read(meshCoreChatHistoryProvider(key)).messages,
        isEmpty,
      );
      expect(container.read(meshCoreChatHistoryProvider(key)).hasMore, isTrue);

      await notifier.loadInitial();
      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages, hasLength(5));
      expect(s.messages.map((m) => m.id).toList(), [
        'm-0000',
        'm-0001',
        'm-0002',
        'm-0003',
        'm-0004',
      ]);
      expect(s.isInitialLoading, isFalse);
      expect(s.isLoadingOlder, isFalse);
      expect(s.hasMore, isFalse);
      expect(s.lastError, isNull);
      expect(s.oldestCursor, isNotNull);
      expect(s.oldestCursor!.id, 'm-0000');
    });

    test('loadInitial reports isInitialLoading=true while in flight', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 3);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final fut = notifier.loadInitial();
      // Inspect state on the microtask boundary: copyWith with
      // isInitialLoading=true has already been applied before the
      // first `await` returns.
      expect(
        container.read(meshCoreChatHistoryProvider(key)).isInitialLoading,
        isTrue,
      );
      await fut;
      expect(
        container.read(meshCoreChatHistoryProvider(key)).isInitialLoading,
        isFalse,
      );
    });

    test(
      'loadInitial on empty partition: messages=[], hasMore=false',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final key = const MeshCoreChatContactKey(_contactAHex);
        final notifier = container.read(
          meshCoreChatHistoryProvider(key).notifier,
        );

        await notifier.loadInitial();
        final s = container.read(meshCoreChatHistoryProvider(key));
        expect(s.messages, isEmpty);
        expect(s.hasMore, isFalse);
        expect(s.oldestCursor, isNull);
      },
    );

    test(
      'loadInitial: hasMore=true when partition exactly fills page',
      () async {
        final store = MeshCoreMessageStore();
        await store.init();
        // 50 = page size.
        await _seedContact(store, _contactAHex, count: 50);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final key = const MeshCoreChatContactKey(_contactAHex);
        final notifier = container.read(
          meshCoreChatHistoryProvider(key).notifier,
        );

        await notifier.loadInitial();
        final s = container.read(meshCoreChatHistoryProvider(key));
        expect(s.messages, hasLength(50));
        // The store has no more rows but the provider cannot
        // distinguish "exact page fill" from "partial last page" from
        // its own load. hasMore stays true until loadOlder returns
        // strictly less than the page size.
        expect(s.hasMore, isTrue);
      },
    );
  });

  group('meshCoreChatHistoryProvider loadOlder - D43-A2', () {
    test('loadOlder prepends; ordering preserved; cursor advances', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      // 60 messages, page size 50. Page 1 = newest 50, page 2 = oldest 10.
      await _seedContact(store, _contactAHex, count: 60);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      final after1 = container.read(meshCoreChatHistoryProvider(key));
      expect(after1.messages, hasLength(50));
      expect(after1.messages.first.id, 'm-0010');
      expect(after1.messages.last.id, 'm-0059');
      expect(after1.hasMore, isTrue);

      await notifier.loadOlder();
      final after2 = container.read(meshCoreChatHistoryProvider(key));
      expect(after2.messages, hasLength(60));
      expect(after2.messages.first.id, 'm-0000');
      expect(after2.messages.last.id, 'm-0059');
      // Strict ascending sort holds across the prepend boundary.
      for (int i = 1; i < after2.messages.length; i++) {
        expect(
          after2.messages[i].timestamp.isAfter(
                after2.messages[i - 1].timestamp,
              ) ||
              after2.messages[i].timestamp.isAtSameMomentAs(
                after2.messages[i - 1].timestamp,
              ),
          isTrue,
        );
      }
      // Last page returned < page size; hasMore now false.
      expect(after2.hasMore, isFalse);
    });

    test('loadOlder no-op while isLoadingOlder', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 60);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      final fut1 = notifier.loadOlder();
      // Second call must short-circuit while the first is still in
      // flight — no second store hit, no duplicate prepend.
      final fut2 = notifier.loadOlder();
      await Future.wait([fut1, fut2]);

      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages, hasLength(60));
      // No duplicates (would have lengthened the list beyond 60).
      final unique = s.messages.map((m) => m.id).toSet();
      expect(unique.length, 60);
    });

    test('loadOlder no-op when hasMore=false', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 5);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      expect(container.read(meshCoreChatHistoryProvider(key)).hasMore, isFalse);

      // No-op: state unchanged.
      final snap = container.read(meshCoreChatHistoryProvider(key));
      await notifier.loadOlder();
      expect(
        identical(
          container.read(meshCoreChatHistoryProvider(key)).messages,
          snap.messages,
        ),
        isTrue,
        reason: 'loadOlder must be a true no-op once hasMore is false',
      );
    });

    test('loadOlder no-op while isInitialLoading', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 60);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final initialFut = notifier.loadInitial();
      // loadOlder fired before initial completes: should short-circuit
      // because both the loading guard and the empty-cursor guard
      // apply.
      await notifier.loadOlder();
      final mid = container.read(meshCoreChatHistoryProvider(key));
      expect(mid.isLoadingOlder, isFalse);
      await initialFut;
    });

    test('loadOlder no-op when window empty (no cursor)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      // build() initialises to the empty default; cursor null. A
      // direct loadOlder before any loadInitial should not throw.
      await notifier.loadOlder();
      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages, isEmpty);
      expect(s.lastError, isNull);
    });
  });

  group('meshCoreChatHistoryProvider append dedup - D43-A2', () {
    test('appendInbound is a tail append with dedupe by id', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendInbound(_msg(id: 'i1', timestamp: t));
      notifier.appendInbound(
        _msg(id: 'i2', timestamp: t.add(const Duration(minutes: 1))),
      );
      // Repeat id: must be a no-op.
      notifier.appendInbound(_msg(id: 'i1', timestamp: t));

      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages.map((m) => m.id), ['i1', 'i2']);
    });

    test('appendOutbound dedupes by id (retry path is idempotent)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      final pending = _msg(id: 'out-1', timestamp: t, isOutgoing: true);
      notifier.appendOutbound(pending);
      notifier.appendOutbound(pending); // retry-with-same-id is a no-op

      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages, hasLength(1));
      expect(s.messages.single.id, 'out-1');
    });

    test('appendInbound during a pending loadOlder lands at the tail '
        'and does not collide with the older page', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 60);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      // Concurrently: kick off loadOlder + append an inbound.
      final olderFut = notifier.loadOlder();
      final newMsg = _msg(
        id: 'live-1',
        timestamp: DateTime.utc(2026, 5, 12, 10, 30),
        text: 'live',
      );
      notifier.appendInbound(newMsg);
      await olderFut;

      final s = container.read(meshCoreChatHistoryProvider(key));
      // 60 (older) + 1 (live).
      expect(s.messages, hasLength(61));
      expect(s.messages.last.id, 'live-1');
      expect(s.messages.first.id, 'm-0000');
      // No id repeats.
      expect(s.messages.map((m) => m.id).toSet().length, 61);
    });
  });

  group('meshCoreChatHistoryProvider status + delete - D43-A2', () {
    test('updateMessageStatus rewrites in place; preserves index', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendOutbound(_msg(id: 'o1', timestamp: t, isOutgoing: true));
      notifier.appendOutbound(
        _msg(
          id: 'o2',
          timestamp: t.add(const Duration(minutes: 1)),
          isOutgoing: true,
        ),
      );

      notifier.updateMessageStatus(
        'o1',
        MeshCoreMessageDeliveryStatus.delivered,
      );

      final s = container.read(meshCoreChatHistoryProvider(key));
      expect(s.messages.map((m) => m.id), ['o1', 'o2']);
      expect(s.messages[0].status, MeshCoreMessageDeliveryStatus.delivered);
      expect(s.messages[1].status, MeshCoreMessageDeliveryStatus.pending);
    });

    test('updateMessageStatus no-op when id is not loaded', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendOutbound(_msg(id: 'o1', timestamp: t, isOutgoing: true));
      final before = container.read(meshCoreChatHistoryProvider(key));

      notifier.updateMessageStatus(
        'does-not-exist',
        MeshCoreMessageDeliveryStatus.delivered,
      );
      final after = container.read(meshCoreChatHistoryProvider(key));
      expect(
        identical(before.messages, after.messages),
        isTrue,
        reason: 'absent id must be a true no-op',
      );
    });

    test('deleteLocal removes by id; absent id is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendInbound(_msg(id: 'i1', timestamp: t));
      notifier.appendInbound(
        _msg(id: 'i2', timestamp: t.add(const Duration(minutes: 1))),
      );

      notifier.deleteLocal('i1');
      final s1 = container.read(meshCoreChatHistoryProvider(key));
      expect(s1.messages.map((m) => m.id), ['i2']);

      final before = s1;
      notifier.deleteLocal('not-here');
      final after = container.read(meshCoreChatHistoryProvider(key));
      expect(identical(before.messages, after.messages), isTrue);
    });

    test('deleteLocal updates the derived oldestCursor', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendInbound(_msg(id: 'a', timestamp: t));
      notifier.appendInbound(
        _msg(id: 'b', timestamp: t.add(const Duration(minutes: 1))),
      );

      // Cursor follows the head element.
      expect(
        container.read(meshCoreChatHistoryProvider(key)).oldestCursor!.id,
        'a',
      );

      notifier.deleteLocal('a');
      expect(
        container.read(meshCoreChatHistoryProvider(key)).oldestCursor!.id,
        'b',
      );

      notifier.deleteLocal('b');
      expect(
        container.read(meshCoreChatHistoryProvider(key)).oldestCursor,
        isNull,
      );
    });
  });

  group('meshCoreChatHistoryProvider loadUntilContains - D43-A2', () {
    test('returns true immediately when id is already loaded', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      final t = DateTime.utc(2026, 5, 12, 9);
      notifier.appendInbound(_msg(id: 'x', timestamp: t));

      expect(await notifier.loadUntilContains('x'), isTrue);
    });

    test('pages until target appears', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 60);
      // m-0000 is in the older page; loadInitial loads m-0010..m-0059.

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      final found = await notifier.loadUntilContains('m-0000');
      expect(found, isTrue);
      expect(
        container.read(meshCoreChatHistoryProvider(key)).messages.first.id,
        'm-0000',
      );
    });

    test(
      'returns false cleanly when hasMore exhausts before id found',
      () async {
        final store = MeshCoreMessageStore();
        await store.init();
        await _seedContact(store, _contactAHex, count: 5);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final key = const MeshCoreChatContactKey(_contactAHex);
        final notifier = container.read(
          meshCoreChatHistoryProvider(key).notifier,
        );

        await notifier.loadInitial();
        // Target does not exist anywhere; full partition is loaded;
        // hasMore is false. Must return false, not loop.
        final found = await notifier.loadUntilContains('m-9999');
        expect(found, isFalse);
      },
    );

    test('bounded by maxPages', () async {
      // Construct a degenerate scenario: a store with > maxPages*pageSize
      // messages and a target older than the bound's reach. The provider
      // must return false at the bound, not run forever.
      final store = MeshCoreMessageStore();
      await store.init();
      // 250 messages; maxPages=2 will load at most 2 * 50 = 100 from
      // the newest end, never reaching the target at id m-0000.
      await _seedContact(store, _contactAHex, count: 250);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = const MeshCoreChatContactKey(_contactAHex);
      final notifier = container.read(
        meshCoreChatHistoryProvider(key).notifier,
      );

      await notifier.loadInitial();
      final found = await notifier.loadUntilContains('m-0000', maxPages: 2);
      expect(found, isFalse);
      // Window grew by exactly 2 pages-worth.
      expect(
        container.read(meshCoreChatHistoryProvider(key)).messages.length,
        50 + 100,
      );
    });
  });

  group('meshCoreChatHistoryProvider scoping - D43-A2', () {
    test('contact A history does not bleed into contact B', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 4);
      await _seedContact(store, _contactBHex, count: 2);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final keyA = const MeshCoreChatContactKey(_contactAHex);
      final keyB = const MeshCoreChatContactKey(_contactBHex);

      await container
          .read(meshCoreChatHistoryProvider(keyA).notifier)
          .loadInitial();
      await container
          .read(meshCoreChatHistoryProvider(keyB).notifier)
          .loadInitial();

      expect(
        container.read(meshCoreChatHistoryProvider(keyA)).messages,
        hasLength(4),
      );
      expect(
        container.read(meshCoreChatHistoryProvider(keyB)).messages,
        hasLength(2),
      );
      // Mutating A leaves B untouched.
      container
          .read(meshCoreChatHistoryProvider(keyA).notifier)
          .deleteLocal('m-0000');
      expect(
        container.read(meshCoreChatHistoryProvider(keyA)).messages,
        hasLength(3),
      );
      expect(
        container.read(meshCoreChatHistoryProvider(keyB)).messages,
        hasLength(2),
      );
    });

    test('contact and channel keys are distinct family entries', () async {
      final store = MeshCoreMessageStore();
      await store.init();
      await _seedContact(store, _contactAHex, count: 3);
      await _seedChannel(store, 1, count: 2);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final contactKey = const MeshCoreChatContactKey(_contactAHex);
      const channelKey = MeshCoreChatChannelKey(1);

      await container
          .read(meshCoreChatHistoryProvider(contactKey).notifier)
          .loadInitial();
      await container
          .read(meshCoreChatHistoryProvider(channelKey).notifier)
          .loadInitial();

      expect(
        container
            .read(meshCoreChatHistoryProvider(contactKey))
            .messages
            .map((m) => m.id)
            .toList(),
        ['m-0000', 'm-0001', 'm-0002'],
      );
      expect(
        container
            .read(meshCoreChatHistoryProvider(channelKey))
            .messages
            .map((m) => m.id)
            .toList(),
        ['ch-0000', 'ch-0001'],
      );
    });
  });

  group('MeshCoreChatHistoryKey equality - D43-A2', () {
    test('two MeshCoreChatContactKey with same hex compare equal', () {
      const a = MeshCoreChatContactKey(_contactAHex);
      const b = MeshCoreChatContactKey(_contactAHex);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('contact and channel keys never collide', () {
      const c = MeshCoreChatContactKey(_contactAHex);
      const ch = MeshCoreChatChannelKey(0);
      expect(c == ch, isFalse);
    });

    test('two MeshCoreChatChannelKey with same index compare equal', () {
      const a = MeshCoreChatChannelKey(0);
      const b = MeshCoreChatChannelKey(0);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different channel indexes are distinct', () {
      const a = MeshCoreChatChannelKey(0);
      const b = MeshCoreChatChannelKey(1);
      expect(a == b, isFalse);
    });
  });
}
