// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_capability_store.dart';

void main() {
  group('SmCapabilityStore', () {
    test('new store has no supported nodes', () {
      final store = SmCapabilityStore();
      expect(store.supportedNodeCount, 0);
      expect(store.isNodeSupported(0x12345678), isFalse);
      expect(store.lastSeenBinary(0x12345678), isNull);
      expect(store.supportedNodes, isEmpty);
    });

    test('markNodeSupported adds node', () async {
      final store = SmCapabilityStore();
      await store.markNodeSupported(0x12345678);

      expect(store.isNodeSupported(0x12345678), isTrue);
      expect(store.supportedNodeCount, 1);
      expect(store.supportedNodes, contains(0x12345678));
      expect(store.lastSeenBinary(0x12345678), isNotNull);
    });

    test('markNodeSupported updates timestamp on re-mark', () async {
      var now = DateTime(2026, 1, 1, 12, 0);
      final store = SmCapabilityStore(clock: () => now);

      await store.markNodeSupported(0xAA);
      final firstSeen = store.lastSeenBinary(0xAA)!;

      now = DateTime(2026, 1, 1, 12, 30);
      await store.markNodeSupported(0xAA);
      final secondSeen = store.lastSeenBinary(0xAA)!;

      expect(secondSeen.isAfter(firstSeen), isTrue);
      expect(store.supportedNodeCount, 1);
    });

    test('multiple nodes tracked independently', () async {
      final store = SmCapabilityStore();
      await store.markNodeSupported(0x01);
      await store.markNodeSupported(0x02);
      await store.markNodeSupported(0x03);

      expect(store.supportedNodeCount, 3);
      expect(store.isNodeSupported(0x01), isTrue);
      expect(store.isNodeSupported(0x02), isTrue);
      expect(store.isNodeSupported(0x03), isTrue);
      expect(store.isNodeSupported(0x04), isFalse);
    });

    test('clear removes all nodes', () async {
      final store = SmCapabilityStore();
      await store.markNodeSupported(0x01);
      await store.markNodeSupported(0x02);
      expect(store.supportedNodeCount, 2);

      await store.clear();
      expect(store.supportedNodeCount, 0);
      expect(store.isNodeSupported(0x01), isFalse);
    });

    group('recentBinaryNodeCount', () {
      test('counts nodes within recentThreshold', () async {
        var now = DateTime(2026, 1, 1, 12, 0);
        final store = SmCapabilityStore(clock: () => now);

        await store.markNodeSupported(0x01);
        await store.markNodeSupported(0x02);

        expect(store.recentBinaryNodeCount, 2);
      });

      test('excludes nodes older than recentThreshold', () async {
        var now = DateTime(2026, 1, 1, 12, 0);
        final store = SmCapabilityStore(clock: () => now);

        await store.markNodeSupported(0x01); // seen at 12:00

        // Advance past 24h threshold
        now = DateTime(2026, 1, 2, 13, 0); // 25h later
        await store.markNodeSupported(0x02); // seen at 13:00 next day

        expect(store.supportedNodeCount, 2);
        expect(store.recentBinaryNodeCount, 1); // only 0x02
      });

      test('edge case: exactly at threshold boundary', () async {
        var now = DateTime(2026, 1, 1, 12, 0);
        final store = SmCapabilityStore(clock: () => now);

        await store.markNodeSupported(0x01);

        // Advance exactly 24h
        now = DateTime(2026, 1, 2, 12, 0);

        // Node marked at 12:00, cutoff is 12:00 - 24h = 12:00 yesterday
        // isAfter(cutoff) → not after, equal → excluded
        expect(store.recentBinaryNodeCount, 0);
      });
    });

    group('isMeshBinaryReady', () {
      test('false when no peers', () {
        final store = SmCapabilityStore();
        expect(store.isMeshBinaryReady, isFalse);
      });

      test('false when only one recent peer', () async {
        final store = SmCapabilityStore();
        await store.markNodeSupported(0x01);
        expect(store.isMeshBinaryReady, isFalse);
      });

      test('true when threshold peers reached', () async {
        final store = SmCapabilityStore();
        await store.markNodeSupported(0x01);
        await store.markNodeSupported(0x02);
        expect(store.isMeshBinaryReady, isTrue);
      });

      test('becomes false when peers age out', () async {
        var now = DateTime(2026, 1, 1, 12, 0);
        final store = SmCapabilityStore(clock: () => now);

        await store.markNodeSupported(0x01);
        await store.markNodeSupported(0x02);
        expect(store.isMeshBinaryReady, isTrue);

        // Age out both
        now = DateTime(2026, 1, 2, 13, 0);
        expect(store.isMeshBinaryReady, isFalse);
      });
    });

    group('persistence', () {
      test('round-trips through persistence interface', () async {
        Map<int, int>? savedData;

        final persistence = _TestPersistence(
          onLoad: () async => {},
          onSave: (data) async => savedData = Map.of(data),
        );

        final store = SmCapabilityStore(persistence: persistence);
        await store.init();

        await store.markNodeSupported(0x01);
        await store.markNodeSupported(0x02);

        expect(savedData, isNotNull);
        expect(savedData!.length, 2);
        expect(savedData!.containsKey(0x01), isTrue);
        expect(savedData!.containsKey(0x02), isTrue);

        // Create new store from persisted data
        final persistence2 = _TestPersistence(
          onLoad: () async => savedData!,
          onSave: (data) async => savedData = Map.of(data),
        );

        final store2 = SmCapabilityStore(persistence: persistence2);
        await store2.init();

        expect(store2.supportedNodeCount, 2);
        expect(store2.isNodeSupported(0x01), isTrue);
        expect(store2.isNodeSupported(0x02), isTrue);
      });

      test('handles empty persistence', () async {
        final persistence = _TestPersistence(
          onLoad: () async => {},
          onSave: (data) async {},
        );

        final store = SmCapabilityStore(persistence: persistence);
        await store.init();

        expect(store.supportedNodeCount, 0);
      });

      test('clear persists empty map', () async {
        Map<int, int>? savedData = {0x01: 12345};

        final persistence = _TestPersistence(
          onLoad: () async => savedData!,
          onSave: (data) async => savedData = Map.of(data),
        );

        final store = SmCapabilityStore(persistence: persistence);
        await store.init();
        expect(store.supportedNodeCount, 1);

        await store.clear();
        expect(savedData, isEmpty);
      });
    });
  });

  group('JsonStringCapabilityPersistence', () {
    test('round-trips through JSON string', () async {
      String? stored;

      final persistence = JsonStringCapabilityPersistence(
        load: () async => stored,
        save: (s) async => stored = s,
      );

      // Write
      await persistence.save({0x01: 1000, 0x02: 2000});
      expect(stored, isNotNull);

      // Read back
      final loaded = await persistence.load();
      expect(loaded.length, 2);
      expect(loaded[0x01], 1000);
      expect(loaded[0x02], 2000);
    });

    test('handles null stored value', () async {
      final persistence = JsonStringCapabilityPersistence(
        load: () async => null,
        save: (s) async {},
      );

      final loaded = await persistence.load();
      expect(loaded, isEmpty);
    });

    test('handles corrupt JSON', () async {
      final persistence = JsonStringCapabilityPersistence(
        load: () async => 'not valid json {{{',
        save: (s) async {},
      );

      final loaded = await persistence.load();
      expect(loaded, isEmpty);
    });
  });
}

/// Test persistence implementation using closures.
class _TestPersistence implements SmCapabilityPersistence {
  final Future<Map<int, int>> Function() _onLoad;
  final Future<void> Function(Map<int, int>) _onSave;

  _TestPersistence({
    required Future<Map<int, int>> Function() onLoad,
    required Future<void> Function(Map<int, int>) onSave,
  }) : _onLoad = onLoad,
       _onSave = onSave;

  @override
  Future<Map<int, int>> load() => _onLoad();

  @override
  Future<void> save(Map<int, int> data) => _onSave(data);
}
