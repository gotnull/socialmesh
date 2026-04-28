// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/observed_radio_preset.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Helpers
  // ===========================================================================

  NodeDexEntry makeEntry({
    required int nodeNum,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int encounterCount = 1,
    double? maxDistanceSeen,
    int? bestSnr,
    int? bestRssi,
    int messageCount = 0,
    NodeSocialTag? socialTag,
    String? userNote,
    List<EncounterRecord> encounters = const [],
    List<SeenRegion> seenRegions = const [],
    Map<int, CoSeenRelationship> coSeenNodes = const {},
    SigilData? sigil,
    int? lastObservedOnPreset,
  }) {
    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: firstSeen ?? DateTime(2024, 1, 1),
      lastSeen: lastSeen ?? DateTime(2024, 6, 1),
      encounterCount: encounterCount,
      maxDistanceSeen: maxDistanceSeen,
      bestSnr: bestSnr,
      bestRssi: bestRssi,
      messageCount: messageCount,
      socialTag: socialTag,
      userNote: userNote,
      encounters: encounters,
      seenRegions: seenRegions,
      coSeenNodes: coSeenNodes,
      sigil: sigil ?? SigilGenerator.generate(nodeNum),
      lastObservedOnPreset: lastObservedOnPreset,
    );
  }

  EncounterRecord makeEncounter({
    required DateTime timestamp,
    double? distance,
    int? snr,
    int? rssi,
    double? lat,
    double? lon,
    int? observedOnPreset,
  }) {
    return EncounterRecord(
      timestamp: timestamp,
      distanceMeters: distance,
      snr: snr,
      rssi: rssi,
      latitude: lat,
      longitude: lon,
      observedOnPreset: observedOnPreset,
    );
  }

  // ===========================================================================
  // 1. ObservedRadioPreset enum
  // ===========================================================================

  group('ObservedRadioPreset enum', () {
    test('all 14 values exist', () {
      expect(ObservedRadioPreset.values.length, equals(14));
      expect(
        ObservedRadioPreset.values.map((v) => v.name).toSet(),
        equals({
          'longFast',
          'longSlow',
          'veryLongSlow',
          'mediumSlow',
          'mediumFast',
          'shortSlow',
          'shortFast',
          'longModerate',
          'shortTurbo',
          'longTurbo',
          'liteFast',
          'liteSlow',
          'narrowFast',
          'narrowSlow',
        }),
      );
    });

    test('each enum has the correct protobufValue', () {
      expect(ObservedRadioPreset.longFast.protobufValue, equals(0));
      expect(ObservedRadioPreset.longSlow.protobufValue, equals(1));
      expect(ObservedRadioPreset.veryLongSlow.protobufValue, equals(2));
      expect(ObservedRadioPreset.mediumSlow.protobufValue, equals(3));
      expect(ObservedRadioPreset.mediumFast.protobufValue, equals(4));
      expect(ObservedRadioPreset.shortSlow.protobufValue, equals(5));
      expect(ObservedRadioPreset.shortFast.protobufValue, equals(6));
      expect(ObservedRadioPreset.longModerate.protobufValue, equals(7));
      expect(ObservedRadioPreset.shortTurbo.protobufValue, equals(8));
      expect(ObservedRadioPreset.longTurbo.protobufValue, equals(9));
      expect(ObservedRadioPreset.liteFast.protobufValue, equals(10));
      expect(ObservedRadioPreset.liteSlow.protobufValue, equals(11));
      expect(ObservedRadioPreset.narrowFast.protobufValue, equals(12));
      expect(ObservedRadioPreset.narrowSlow.protobufValue, equals(13));
    });

    test(
      'fromProtobufValue returns correct enum for each valid int (0-13)',
      () {
        expect(
          ObservedRadioPreset.fromProtobufValue(0),
          equals(ObservedRadioPreset.longFast),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(1),
          equals(ObservedRadioPreset.longSlow),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(2),
          equals(ObservedRadioPreset.veryLongSlow),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(3),
          equals(ObservedRadioPreset.mediumSlow),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(4),
          equals(ObservedRadioPreset.mediumFast),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(5),
          equals(ObservedRadioPreset.shortSlow),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(6),
          equals(ObservedRadioPreset.shortFast),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(7),
          equals(ObservedRadioPreset.longModerate),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(8),
          equals(ObservedRadioPreset.shortTurbo),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(9),
          equals(ObservedRadioPreset.longTurbo),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(10),
          equals(ObservedRadioPreset.liteFast),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(11),
          equals(ObservedRadioPreset.liteSlow),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(12),
          equals(ObservedRadioPreset.narrowFast),
        );
        expect(
          ObservedRadioPreset.fromProtobufValue(13),
          equals(ObservedRadioPreset.narrowSlow),
        );
      },
    );

    test('fromProtobufValue returns null for null input', () {
      expect(ObservedRadioPreset.fromProtobufValue(null), isNull);
    });

    test('fromProtobufValue returns null for out-of-range values', () {
      expect(ObservedRadioPreset.fromProtobufValue(-1), isNull);
      expect(ObservedRadioPreset.fromProtobufValue(14), isNull);
      expect(ObservedRadioPreset.fromProtobufValue(999), isNull);
    });

    test('_byValue mapping covers all 14 values with no gaps', () {
      // Verify round-trip: every enum value can be recovered via
      // fromProtobufValue using its own protobufValue.
      for (final preset in ObservedRadioPreset.values) {
        expect(
          ObservedRadioPreset.fromProtobufValue(preset.protobufValue),
          equals(preset),
          reason:
              '${preset.name} (${preset.protobufValue}) '
              'should round-trip through fromProtobufValue',
        );
      }
      // Verify the values form a contiguous range 0-13.
      final allValues =
          ObservedRadioPreset.values.map((p) => p.protobufValue).toList()
            ..sort();
      expect(allValues, equals(List.generate(14, (i) => i)));
    });
  });

  // ===========================================================================
  // 2. EncounterRecord with observedOnPreset
  // ===========================================================================

  group('EncounterRecord observedOnPreset', () {
    test('can be created with observedOnPreset set', () {
      final enc = makeEncounter(
        timestamp: DateTime(2024, 3, 15),
        observedOnPreset: 6,
      );
      expect(enc.observedOnPreset, equals(6));
    });

    test('can be created with observedOnPreset null (default)', () {
      final enc = makeEncounter(timestamp: DateTime(2024, 3, 15));
      expect(enc.observedOnPreset, isNull);
    });

    test('toJson includes "op" key when preset is set', () {
      final enc = makeEncounter(
        timestamp: DateTime(2024, 3, 15),
        observedOnPreset: 6,
      );
      final json = enc.toJson();
      expect(json.containsKey('op'), isTrue);
      expect(json['op'], equals(6));
    });

    test('toJson omits "op" key when preset is null', () {
      final enc = makeEncounter(timestamp: DateTime(2024, 3, 15));
      final json = enc.toJson();
      expect(json.containsKey('op'), isFalse);
    });

    test('fromJson reads "op" key correctly', () {
      final json = {
        'ts': DateTime(2024, 3, 15).millisecondsSinceEpoch,
        'op': 4,
      };
      final enc = EncounterRecord.fromJson(json);
      expect(enc.observedOnPreset, equals(4));
    });

    test('fromJson handles missing "op" key', () {
      final json = {'ts': DateTime(2024, 3, 15).millisecondsSinceEpoch};
      final enc = EncounterRecord.fromJson(json);
      expect(enc.observedOnPreset, isNull);
    });

    test('copyWith(observedOnPreset: 3) works', () {
      final enc = makeEncounter(
        timestamp: DateTime(2024, 3, 15),
        observedOnPreset: 6,
      );
      final updated = enc.copyWith(observedOnPreset: 3);
      expect(updated.observedOnPreset, equals(3));
    });

    test('copyWith(clearObservedOnPreset: true) sets it to null', () {
      final enc = makeEncounter(
        timestamp: DateTime(2024, 3, 15),
        observedOnPreset: 6,
      );
      final cleared = enc.copyWith(clearObservedOnPreset: true);
      expect(cleared.observedOnPreset, isNull);
    });

    test('toJson/fromJson round-trip preserves observedOnPreset', () {
      final enc = makeEncounter(
        timestamp: DateTime(2024, 3, 15),
        observedOnPreset: 8,
        snr: 10,
        rssi: -60,
      );
      final json = enc.toJson();
      final restored = EncounterRecord.fromJson(json);
      expect(restored.observedOnPreset, equals(8));
      expect(restored.snr, equals(10));
      expect(restored.rssi, equals(-60));
    });
  });

  // ===========================================================================
  // 3. NodeDexEntry with lastObservedOnPreset
  // ===========================================================================

  group('NodeDexEntry lastObservedOnPreset', () {
    test('constructor accepts lastObservedOnPreset', () {
      final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      expect(entry.lastObservedOnPreset, equals(6));
    });

    test('constructor defaults lastObservedOnPreset to null', () {
      final entry = makeEntry(nodeNum: 100);
      expect(entry.lastObservedOnPreset, isNull);
    });

    test('discovered() with observedOnPreset sets both fields', () {
      final entry = NodeDexEntry.discovered(
        nodeNum: 100,
        observedOnPreset: 6,
        timestamp: DateTime(2024, 5, 1),
      );
      expect(entry.lastObservedOnPreset, equals(6));
      expect(entry.encounters.length, equals(1));
      expect(entry.encounters.first.observedOnPreset, equals(6));
    });

    test('discovered() without observedOnPreset leaves both null', () {
      final entry = NodeDexEntry.discovered(
        nodeNum: 100,
        timestamp: DateTime(2024, 5, 1),
      );
      expect(entry.lastObservedOnPreset, isNull);
      expect(entry.encounters.first.observedOnPreset, isNull);
    });

    test(
      'recordEncounter(observedOnPreset: 4) updates lastObservedOnPreset',
      () {
        final entry = makeEntry(nodeNum: 100);
        final updated = entry.recordEncounter(
          timestamp: DateTime(2024, 7, 1),
          observedOnPreset: 4,
        );
        expect(updated.lastObservedOnPreset, equals(4));
      },
    );

    test(
      'recordEncounter() without preset keeps existing lastObservedOnPreset',
      () {
        final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
        final updated = entry.recordEncounter(timestamp: DateTime(2024, 7, 1));
        // observedOnPreset param is null, so falls back to existing via
        // `observedOnPreset ?? lastObservedOnPreset` in copyWith.
        expect(updated.lastObservedOnPreset, equals(6));
      },
    );

    test(
      'recordEncounter(observedOnPreset: null) does NOT overwrite known preset',
      () {
        final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
        final updated = entry.recordEncounter(
          timestamp: DateTime(2024, 7, 1),
          observedOnPreset: null,
        );
        // Null-safety behavior: `observedOnPreset ?? lastObservedOnPreset`
        // means null param falls back to existing value.
        expect(updated.lastObservedOnPreset, equals(6));
      },
    );

    test('copyWith(lastObservedOnPreset: 7) works', () {
      final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 3);
      final updated = entry.copyWith(lastObservedOnPreset: 7);
      expect(updated.lastObservedOnPreset, equals(7));
    });

    test('copyWith(clearLastObservedOnPreset: true) sets to null', () {
      final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 3);
      final updated = entry.copyWith(clearLastObservedOnPreset: true);
      expect(updated.lastObservedOnPreset, isNull);
    });

    test('toJson includes "lorp" when set', () {
      final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final json = entry.toJson();
      expect(json.containsKey('lorp'), isTrue);
      expect(json['lorp'], equals(6));
    });

    test('toJson omits "lorp" when null', () {
      final entry = makeEntry(nodeNum: 100);
      final json = entry.toJson();
      expect(json.containsKey('lorp'), isFalse);
    });

    test('fromJson reads "lorp" correctly', () {
      final entry = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final json = entry.toJson();
      final restored = NodeDexEntry.fromJson(json);
      expect(restored.lastObservedOnPreset, equals(6));
    });

    test('fromJson handles missing "lorp" (returns null for legacy data)', () {
      // Build a minimal JSON without the 'lorp' key to simulate legacy data.
      final json = <String, dynamic>{
        'nn': 100,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        'ec': 1,
        'mc': 0,
        'enc': <dynamic>[],
        'sr': <dynamic>[],
        'csn': <String, dynamic>{},
      };
      final restored = NodeDexEntry.fromJson(json);
      expect(restored.lastObservedOnPreset, isNull);
    });

    test('operator == includes lastObservedOnPreset in comparison', () {
      final a = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final b = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final c = makeEntry(nodeNum: 100, lastObservedOnPreset: 3);
      final d = makeEntry(nodeNum: 100);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode includes lastObservedOnPreset', () {
      final a = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final b = makeEntry(nodeNum: 100, lastObservedOnPreset: 6);
      final c = makeEntry(nodeNum: 100, lastObservedOnPreset: 3);
      expect(a.hashCode, equals(b.hashCode));
      // Different preset values should (very likely) produce different hashes.
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });
  });

  // ===========================================================================
  // 4. mergeWith radio preset
  // ===========================================================================

  group('mergeWith radio preset', () {
    test('prefers more recently seen preset (later lastSeen wins)', () {
      final older = makeEntry(
        nodeNum: 100,
        lastSeen: DateTime(2024, 3, 1),
        lastObservedOnPreset: 0,
      );
      final newer = makeEntry(
        nodeNum: 100,
        lastSeen: DateTime(2024, 6, 1),
        lastObservedOnPreset: 6,
      );

      // Merge: newer's lastSeen is later, so newer's preset wins.
      final mergedFromOlder = older.mergeWith(newer);
      expect(mergedFromOlder.lastObservedOnPreset, equals(6));

      // Symmetric check: merging in opposite direction should give same result.
      final mergedFromNewer = newer.mergeWith(older);
      expect(mergedFromNewer.lastObservedOnPreset, equals(6));
    });

    test('falls back to the other preset if local is null', () {
      final local = makeEntry(
        nodeNum: 100,
        lastSeen: DateTime(2024, 6, 1),
        lastObservedOnPreset: null,
      );
      final remote = makeEntry(
        nodeNum: 100,
        lastSeen: DateTime(2024, 3, 1),
        lastObservedOnPreset: 4,
      );

      // local is newer but has null preset -> falls back to remote's preset.
      final merged = local.mergeWith(remote);
      expect(merged.lastObservedOnPreset, equals(4));
    });

    test('handles both null gracefully', () {
      final a = makeEntry(nodeNum: 100, lastSeen: DateTime(2024, 3, 1));
      final b = makeEntry(nodeNum: 100, lastSeen: DateTime(2024, 6, 1));
      final merged = a.mergeWith(b);
      expect(merged.lastObservedOnPreset, isNull);
    });

    test('fallback works when newer has null and older has value', () {
      final newer = makeEntry(nodeNum: 100, lastSeen: DateTime(2024, 6, 1));
      final older = makeEntry(
        nodeNum: 100,
        lastSeen: DateTime(2024, 3, 1),
        lastObservedOnPreset: 8,
      );
      // newer.lastObservedOnPreset is null, so it should fall back to older's.
      final merged = newer.mergeWith(older);
      expect(merged.lastObservedOnPreset, equals(8));
    });
  });

  // ===========================================================================
  // 5. SQLite round-trip
  // ===========================================================================

  group('SQLite round-trip', () {
    late NodeDexDatabase database;
    late NodeDexSqliteStore store;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      store = NodeDexSqliteStore(database);
      await store.init();
    });

    tearDown(() async {
      await store.dispose();
    });

    test('store entry with lastObservedOnPreset, load it back', () async {
      final entry = makeEntry(nodeNum: 200, lastObservedOnPreset: 6);
      await store.saveEntryImmediate(entry);

      final loaded = await store.getEntry(200);
      expect(loaded, isNotNull);
      expect(loaded!.lastObservedOnPreset, equals(6));
    });

    test('store entry with null preset, load it back', () async {
      final entry = makeEntry(nodeNum: 201);
      await store.saveEntryImmediate(entry);

      final loaded = await store.getEntry(201);
      expect(loaded, isNotNull);
      expect(loaded!.lastObservedOnPreset, isNull);
    });

    test('store entry with encounter that has observedOnPreset', () async {
      final encounters = [
        makeEncounter(
          timestamp: DateTime(2024, 5, 1),
          observedOnPreset: 4,
          snr: 8,
        ),
      ];
      final entry = makeEntry(
        nodeNum: 202,
        encounters: encounters,
        lastObservedOnPreset: 4,
      );
      await store.saveEntryImmediate(entry);

      final loaded = await store.getEntry(202);
      expect(loaded, isNotNull);
      expect(loaded!.encounters.length, equals(1));
      expect(loaded.encounters.first.observedOnPreset, equals(4));
      expect(loaded.lastObservedOnPreset, equals(4));
    });

    test('update entry with new preset, load back, verify updated', () async {
      final entry = makeEntry(nodeNum: 203, lastObservedOnPreset: 0);
      await store.saveEntryImmediate(entry);

      final updated = entry.copyWith(lastObservedOnPreset: 9);
      await store.saveEntryImmediate(updated);

      final loaded = await store.getEntry(203);
      expect(loaded, isNotNull);
      expect(loaded!.lastObservedOnPreset, equals(9));
    });

    test(
      'entry stored without preset loads with null (legacy compat)',
      () async {
        // Store an entry with no preset, simulating legacy data.
        final entry = makeEntry(nodeNum: 204);
        await store.saveEntryImmediate(entry);

        final loaded = await store.getEntry(204);
        expect(loaded, isNotNull);
        expect(loaded!.lastObservedOnPreset, isNull);
      },
    );
  });

  // ===========================================================================
  // 6. Radio preset filter logic
  // ===========================================================================

  group('Radio preset filter logic', () {
    late List<NodeDexEntry> entries;

    setUp(() {
      entries = [
        makeEntry(nodeNum: 1, lastObservedOnPreset: 0),
        makeEntry(nodeNum: 2, lastObservedOnPreset: 4),
        makeEntry(nodeNum: 3, lastObservedOnPreset: 6),
        makeEntry(nodeNum: 4), // null preset
      ];
    });

    List<NodeDexEntry> applyFilter(
      List<NodeDexEntry> source,
      Set<int> radioPresetFilter,
    ) {
      if (radioPresetFilter.isEmpty) return source;
      return source.where((entry) {
        return entry.lastObservedOnPreset != null &&
            radioPresetFilter.contains(entry.lastObservedOnPreset);
      }).toList();
    }

    test('when filter is empty set, all entries pass', () {
      final filtered = applyFilter(entries, <int>{});
      expect(filtered.length, equals(4));
    });

    test('when filter is {6}, only entries with preset 6 pass', () {
      final filtered = applyFilter(entries, {6});
      expect(filtered.length, equals(1));
      expect(filtered.first.nodeNum, equals(3));
      expect(filtered.first.lastObservedOnPreset, equals(6));
    });

    test('when filter is {0, 4}, entries with 0 or 4 pass, others do not', () {
      final filtered = applyFilter(entries, {0, 4});
      expect(filtered.length, equals(2));
      final nodeNums = filtered.map((e) => e.nodeNum).toSet();
      expect(nodeNums, equals({1, 2}));
    });

    test('entry with null preset never matches a non-empty filter', () {
      // Filter that would match some presets.
      final filtered = applyFilter(entries, {0, 4, 6});
      // 3 out of 4 entries match — the null one does not.
      expect(filtered.length, equals(3));
      expect(filtered.every((e) => e.lastObservedOnPreset != null), isTrue);
      // Specifically, node 4 (null preset) is excluded.
      expect(filtered.any((e) => e.nodeNum == 4), isFalse);
    });

    test('filter with value not present in any entry returns empty', () {
      final filtered = applyFilter(entries, {9});
      expect(filtered, isEmpty);
    });

    test('filter works with all ObservedRadioPreset protobuf values', () {
      // Build entries for every preset value 0-9.
      final allEntries = List.generate(10, (i) {
        return makeEntry(nodeNum: 100 + i, lastObservedOnPreset: i);
      });

      // Filter for medium presets (3, 4).
      final filtered = applyFilter(allEntries, {3, 4});
      expect(filtered.length, equals(2));
      expect(
        filtered.map((e) => e.lastObservedOnPreset).toSet(),
        equals({3, 4}),
      );
    });
  });
}
