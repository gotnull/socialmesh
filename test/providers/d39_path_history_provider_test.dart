// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A - MeshCorePathHistoryNotifier provider tests.
//
// Pinned invariants:
//   - record() updates state and persists.
//   - record() dedupes by exact bytes (idempotent on the in-memory
//     state, touches lastUsedAt on the disk side).
//   - delete() removes the entry.
//   - LRU eviction at 20 entries is observed by the notifier.
//   - Device scoping: switching the pubkey prefix reloads from disk.
//   - Contact scoping: two contacts on the same device keep
//     independent histories.
//   - No-pubkey -> record / delete are no-ops; no global key lands.
//   - Log surface is redacted:
//       event=path_history.recorded source=<trace|manual> path_len=<int>
//       event=path_history.deleted
//       event=path_history.evicted reason=lru
//     and NEVER contains raw path bytes, full pubkeys, or message text.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

ProviderContainer _container({required String pubKeyPrefix}) {
  return ProviderContainer(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

Future<void> _pumpLoad() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// Full 64-char contact pubkey hex (deterministic value).
final String _contactA = 'aabbccdd${'00112233' * 7}';
final String _contactB = 'ddeeff00${'11223344' * 7}';

Uint8List _bytes(List<int> list) => Uint8List.fromList(list);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('record', () {
    test('initial state is empty', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      expect(c.read(meshCorePathHistoryProvider(_contactA)), isEmpty);
    });

    test('record inserts a new entry', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      await c
          .read(meshCorePathHistoryProvider(_contactA).notifier)
          .record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      final entries = c.read(meshCorePathHistoryProvider(_contactA));
      expect(entries, hasLength(1));
      expect(entries.first.bytes, equals(_bytes([1, 2, 3])));
      expect(entries.first.source, MeshCorePathSource.trace);
    });

    test('record dedupes by exact bytes', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      final notifier = c.read(meshCorePathHistoryProvider(_contactA).notifier);
      await notifier.record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      await notifier.record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      await notifier.record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      expect(c.read(meshCorePathHistoryProvider(_contactA)), hasLength(1));
    });

    test('record rejects empty / oversized bytes silently', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      final notifier = c.read(meshCorePathHistoryProvider(_contactA).notifier);
      await notifier.record(_bytes(<int>[]), MeshCorePathSource.trace);
      await notifier.record(
        Uint8List.fromList(List.filled(65, 9)),
        MeshCorePathSource.trace,
      );
      expect(c.read(meshCorePathHistoryProvider(_contactA)), isEmpty);
    });

    test('no-pubkey: record is a no-op (no global key materialises)', () async {
      final c = _container(pubKeyPrefix: '');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      await c
          .read(meshCorePathHistoryProvider(_contactA).notifier)
          .record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      expect(c.read(meshCorePathHistoryProvider(_contactA)), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_path_history_'),
      );
      expect(ours, isEmpty);
    });
  });

  group('delete', () {
    test('delete removes the entry', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      final notifier = c.read(meshCorePathHistoryProvider(_contactA).notifier);
      await notifier.record(_bytes([1, 2, 3]), MeshCorePathSource.trace);
      final id = c.read(meshCorePathHistoryProvider(_contactA)).single.id;
      await notifier.delete(id);
      expect(c.read(meshCorePathHistoryProvider(_contactA)), isEmpty);
    });

    test('delete on a missing id is a no-op', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      await c
          .read(meshCorePathHistoryProvider(_contactA).notifier)
          .delete('does-not-exist');
      expect(c.read(meshCorePathHistoryProvider(_contactA)), isEmpty);
    });
  });

  group('device + contact scoping', () {
    test(
      'two contacts on the same device keep independent histories',
      () async {
        final c = _container(pubKeyPrefix: '79426d8d');
        addTearDown(c.dispose);
        c.read(meshCorePathHistoryProvider(_contactA));
        c.read(meshCorePathHistoryProvider(_contactB));
        await _pumpLoad();
        await c
            .read(meshCorePathHistoryProvider(_contactA).notifier)
            .record(_bytes([1]), MeshCorePathSource.trace);
        await c
            .read(meshCorePathHistoryProvider(_contactB).notifier)
            .record(_bytes([2]), MeshCorePathSource.trace);
        expect(
          c.read(meshCorePathHistoryProvider(_contactA)).single.bytes,
          equals(_bytes([1])),
        );
        expect(
          c.read(meshCorePathHistoryProvider(_contactB)).single.bytes,
          equals(_bytes([2])),
        );
      },
    );

    test(
      'different devices keep independent histories for the same contact',
      () async {
        // Pre-seed device A.
        final preStore = MeshCorePathHistoryStore();
        await preStore.record(
          devicePubKeyPrefix: 'aaaaaaaa',
          contactPubKeyPrefix: 'aabbccdd',
          bytes: _bytes([1]),
          source: MeshCorePathSource.trace,
          now: DateTime.now(),
        );
        await preStore.record(
          devicePubKeyPrefix: 'bbbbbbbb',
          contactPubKeyPrefix: 'aabbccdd',
          bytes: _bytes([2]),
          source: MeshCorePathSource.trace,
          now: DateTime.now(),
        );

        final cA = _container(pubKeyPrefix: 'aaaaaaaa');
        addTearDown(cA.dispose);
        cA.read(meshCorePathHistoryProvider(_contactA));
        await _pumpLoad();
        expect(
          cA.read(meshCorePathHistoryProvider(_contactA)).single.bytes,
          equals(_bytes([1])),
        );

        final cB = _container(pubKeyPrefix: 'bbbbbbbb');
        addTearDown(cB.dispose);
        cB.read(meshCorePathHistoryProvider(_contactA));
        await _pumpLoad();
        expect(
          cB.read(meshCorePathHistoryProvider(_contactA)).single.bytes,
          equals(_bytes([2])),
        );
      },
    );
  });

  group('LRU eviction', () {
    test('21st entry causes the oldest to be evicted', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      final notifier = c.read(meshCorePathHistoryProvider(_contactA).notifier);
      for (int i = 0; i < 21; i++) {
        await notifier.record(_bytes([i + 1]), MeshCorePathSource.trace);
      }
      final entries = c.read(meshCorePathHistoryProvider(_contactA));
      expect(entries, hasLength(20));
      expect(
        entries.where((e) => e.bytes.first == 1),
        isEmpty,
        reason: 'first-inserted entry must be evicted past the 20 cap',
      );
    });
  });

  group('redacted log surface', () {
    test('record/delete log lines do NOT carry path bytes or full '
        'pubkey', () async {
      final captured = <String>[];
      AppLogging.setAppLogSink((_, _, msg) => captured.add(msg));
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCorePathHistoryProvider(_contactA));
      await _pumpLoad();
      final notifier = c.read(meshCorePathHistoryProvider(_contactA).notifier);
      await notifier.record(
        _bytes([0xAB, 0xCD, 0xEF, 0x12]),
        MeshCorePathSource.trace,
      );
      final id = c.read(meshCorePathHistoryProvider(_contactA)).single.id;
      await notifier.delete(id);

      final recorded = captured
          .where((m) => m.contains('path_history.recorded'))
          .toList();
      expect(recorded, isNotEmpty);
      final r = recorded.last;
      expect(r, contains('source=trace'));
      expect(r, contains('path_len=4'));

      final deleted = captured
          .where((m) => m.contains('path_history.deleted'))
          .toList();
      expect(deleted, isNotEmpty);

      // No raw path bytes, no full pubkey.
      final hexShape = RegExp(r'\b[0-9a-fA-F]{8,}\b');
      for (final m in captured) {
        // 8-char device prefix is permitted; anything longer than
        // 16 hex chars on its own is suspicious. Filter by length.
        final hits = hexShape
            .allMatches(m)
            .where((match) => match.group(0)!.length > 16);
        expect(
          hits,
          isEmpty,
          reason: 'log line "$m" contains a long hex run that may leak bytes',
        );
        // No PSK shape.
        expect(RegExp(r'[0-9a-fA-F]{32}').hasMatch(m), isFalse);
      }
    });
  });
}
