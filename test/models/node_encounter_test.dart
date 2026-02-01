// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/models/node_encounter.dart';

void main() {
  group('NodeEncounter', () {
    group('firstEncounter factory', () {
      test('creates encounter with correct initial values', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(42, now);

        expect(encounter.nodeId, 42);
        expect(encounter.firstSeen, now);
        expect(encounter.lastSeen, now);
        expect(encounter.encounterCount, 1);
        expect(encounter.uniqueDaysSeen, 1);
      });
    });

    group('recordEncounter', () {
      test('increments encounterCount', () {
        final start = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        final later = start.add(const Duration(hours: 1));
        final updated = encounter.recordEncounter(later);

        expect(updated.encounterCount, 2);
      });

      test('updates lastSeen', () {
        final start = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        final later = start.add(const Duration(hours: 5));
        final updated = encounter.recordEncounter(later);

        expect(updated.lastSeen, later);
        expect(updated.firstSeen, start); // unchanged
      });

      test('same day does not increment uniqueDaysSeen', () {
        final start = DateTime(2026, 1, 24, 8, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        final later = DateTime(2026, 1, 24, 20, 0, 0); // same day
        final updated = encounter.recordEncounter(later);

        expect(updated.uniqueDaysSeen, 1);
        expect(updated.encounterCount, 2);
      });

      test('new day increments uniqueDaysSeen', () {
        final day1 = DateTime(2026, 1, 24, 23, 59, 0);
        final encounter = NodeEncounter.firstEncounter(1, day1);

        final day2 = DateTime(2026, 1, 25, 0, 1, 0); // next day
        final updated = encounter.recordEncounter(day2);

        expect(updated.uniqueDaysSeen, 2);
        expect(updated.encounterCount, 2);
      });

      test('multiple days accumulate uniqueDaysSeen correctly', () {
        final day1 = DateTime(2026, 1, 1, 12, 0, 0);
        var encounter = NodeEncounter.firstEncounter(1, day1);

        // Same day encounter
        encounter = encounter.recordEncounter(DateTime(2026, 1, 1, 18, 0, 0));
        expect(encounter.uniqueDaysSeen, 1);
        expect(encounter.encounterCount, 2);

        // Day 2
        encounter = encounter.recordEncounter(DateTime(2026, 1, 2, 12, 0, 0));
        expect(encounter.uniqueDaysSeen, 2);
        expect(encounter.encounterCount, 3);

        // Day 2 again
        encounter = encounter.recordEncounter(DateTime(2026, 1, 2, 14, 0, 0));
        expect(encounter.uniqueDaysSeen, 2);
        expect(encounter.encounterCount, 4);

        // Day 5 (skip days)
        encounter = encounter.recordEncounter(DateTime(2026, 1, 5, 12, 0, 0));
        expect(encounter.uniqueDaysSeen, 3);
        expect(encounter.encounterCount, 5);
      });
    });

    group('isFamiliar', () {
      test('false for <=5 encounters', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        var encounter = NodeEncounter.firstEncounter(1, now);

        for (var i = 0; i < 4; i++) {
          encounter = encounter.recordEncounter(now);
        }
        expect(encounter.encounterCount, 5);
        expect(encounter.isFamiliar, isFalse);
      });

      test('true for >5 encounters', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        var encounter = NodeEncounter.firstEncounter(1, now);

        for (var i = 0; i < 5; i++) {
          encounter = encounter.recordEncounter(now);
        }
        expect(encounter.encounterCount, 6);
        expect(encounter.isFamiliar, isTrue);
      });
    });

    group('seenRecently', () {
      test('true within 24 hours', () {
        final start = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        final now = start.add(const Duration(hours: 23));
        expect(encounter.seenRecently(now), isTrue);
      });

      test('false after 24 hours', () {
        final start = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        final now = start.add(const Duration(hours: 24));
        expect(encounter.seenRecently(now), isFalse);
      });
    });

    group('relationshipAgeDays', () {
      test('0 for same day', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, now);
        expect(encounter.relationshipAgeDays(now), 0);
      });

      test('calculates days correctly', () {
        final start = DateTime(2026, 1, 1, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);

        expect(
          encounter.relationshipAgeDays(DateTime(2026, 1, 8, 12, 0, 0)),
          7,
        );
        expect(
          encounter.relationshipAgeDays(DateTime(2026, 2, 1, 12, 0, 0)),
          31,
        );
      });
    });

    group('encounterSummary', () {
      test('first encounter text', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, now);
        expect(encounter.encounterSummary, 'First encounter');
      });

      test('multiple encounters text', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        var encounter = NodeEncounter.firstEncounter(1, now);
        encounter = encounter.recordEncounter(now);
        encounter = encounter.recordEncounter(now);

        expect(encounter.encounterSummary, 'Seen 3 times');
      });
    });

    group('relationshipAgeText', () {
      test('today text', () {
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, now);
        expect(encounter.relationshipAgeText(now), 'First seen today');
      });

      test('yesterday text', () {
        final start = DateTime(2026, 1, 23, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen yesterday');
      });

      test('days text', () {
        final start = DateTime(2026, 1, 20, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen 4 days ago');
      });

      test('week text', () {
        final start = DateTime(2026, 1, 14, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen 1 week ago');
      });

      test('weeks text', () {
        final start = DateTime(2026, 1, 1, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen 3 weeks ago');
      });

      test('month text', () {
        final start = DateTime(2025, 12, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen 1 month ago');
      });

      test('months text', () {
        final start = DateTime(2025, 9, 24, 12, 0, 0);
        final encounter = NodeEncounter.firstEncounter(1, start);
        final now = DateTime(2026, 1, 24, 12, 0, 0);
        expect(encounter.relationshipAgeText(now), 'First seen 4 months ago');
      });
    });

    group('JSON serialization', () {
      test('toJson produces compact format', () {
        final encounter = NodeEncounter(
          nodeId: 123,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(2000),
          encounterCount: 5,
          uniqueDaysSeen: 3,
        );

        final json = encounter.toJson();
        expect(json['n'], 123);
        expect(json['f'], 1000);
        expect(json['l'], 2000);
        expect(json['c'], 5);
        expect(json['d'], 3);
      });

      test('fromJson parses correctly', () {
        final json = {'n': 456, 'f': 3000, 'l': 4000, 'c': 10, 'd': 7};

        final encounter = NodeEncounter.fromJson(json);
        expect(encounter.nodeId, 456);
        expect(encounter.firstSeen.millisecondsSinceEpoch, 3000);
        expect(encounter.lastSeen.millisecondsSinceEpoch, 4000);
        expect(encounter.encounterCount, 10);
        expect(encounter.uniqueDaysSeen, 7);
      });

      test('fromJson uses defaults for missing optional fields', () {
        final json = {
          'n': 789,
          'f': 5000,
          'l': 6000,
          // 'c' and 'd' missing
        };

        final encounter = NodeEncounter.fromJson(json);
        expect(encounter.encounterCount, 1);
        expect(encounter.uniqueDaysSeen, 1);
      });

      test('roundtrip preserves data', () {
        final original = NodeEncounter(
          nodeId: 999,
          firstSeen: DateTime(2026, 1, 1, 0, 0, 0),
          lastSeen: DateTime(2026, 1, 15, 12, 30, 45),
          encounterCount: 42,
          uniqueDaysSeen: 8,
        );

        final json = original.toJson();
        final restored = NodeEncounter.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('equality', () {
      test('equal for same values', () {
        final a = NodeEncounter(
          nodeId: 1,
          firstSeen: DateTime(2026, 1, 1),
          lastSeen: DateTime(2026, 1, 2),
          encounterCount: 5,
          uniqueDaysSeen: 2,
        );
        final b = NodeEncounter(
          nodeId: 1,
          firstSeen: DateTime(2026, 1, 1),
          lastSeen: DateTime(2026, 1, 2),
          encounterCount: 5,
          uniqueDaysSeen: 2,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal for different values', () {
        final a = NodeEncounter.firstEncounter(1, DateTime(2026, 1, 1));
        final b = NodeEncounter.firstEncounter(2, DateTime(2026, 1, 1));

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('NodeEncounterService', () {
    late Map<String, String> storage;
    late NodeEncounterService service;

    setUp(() {
      storage = {};
      service = NodeEncounterService(
        read: (key) async => storage[key],
        write: (key, value) async {
          storage[key] = value;
          return true;
        },
      );
    });

    test('init loads empty cache', () async {
      await service.init();
      expect(service.getAllEncounters(), isEmpty);
    });

    test('recordObservation creates first encounter', () async {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      final encounter = await service.recordObservation(42, now: now);

      expect(encounter.nodeId, 42);
      expect(encounter.encounterCount, 1);
      expect(encounter.firstSeen, now);
    });

    test('recordObservation updates existing encounter', () async {
      final time1 = DateTime(2026, 1, 24, 12, 0, 0);
      await service.recordObservation(42, now: time1);

      final time2 = DateTime(2026, 1, 24, 14, 0, 0);
      final updated = await service.recordObservation(42, now: time2);

      expect(updated.encounterCount, 2);
      expect(updated.lastSeen, time2);
      expect(updated.firstSeen, time1);
    });

    test('getEncounter returns null for unknown node', () async {
      await service.init();
      expect(service.getEncounter(999), isNull);
    });

    test('getEncounter returns recorded encounter', () async {
      await service.recordObservation(42);
      final encounter = service.getEncounter(42);

      expect(encounter, isNotNull);
      expect(encounter!.nodeId, 42);
    });

    test('getFrequentNodes returns sorted list', () async {
      final now = DateTime(2026, 1, 24, 12, 0, 0);

      // Node 1: 3 encounters
      await service.recordObservation(1, now: now);
      await service.recordObservation(1, now: now);
      await service.recordObservation(1, now: now);

      // Node 2: 5 encounters
      await service.recordObservation(2, now: now);
      await service.recordObservation(2, now: now);
      await service.recordObservation(2, now: now);
      await service.recordObservation(2, now: now);
      await service.recordObservation(2, now: now);

      // Node 3: 1 encounter
      await service.recordObservation(3, now: now);

      final frequent = service.getFrequentNodes();

      expect(frequent.length, 3);
      expect(frequent[0].nodeId, 2); // Most encounters
      expect(frequent[1].nodeId, 1);
      expect(frequent[2].nodeId, 3); // Least encounters
    });

    test('getFrequentNodes respects limit', () async {
      final now = DateTime(2026, 1, 24, 12, 0, 0);

      for (var i = 1; i <= 10; i++) {
        await service.recordObservation(i, now: now);
      }

      final frequent = service.getFrequentNodes(limit: 5);
      expect(frequent.length, 5);
    });

    test('save and reload preserves data', () async {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      await service.recordObservation(42, now: now);
      await service.recordObservation(42, now: now);
      await service.save();

      // Create new service with same storage
      final service2 = NodeEncounterService(
        read: (key) async => storage[key],
        write: (key, value) async {
          storage[key] = value;
          return true;
        },
      );
      await service2.init();

      final encounter = service2.getEncounter(42);
      expect(encounter, isNotNull);
      expect(encounter!.encounterCount, 2);
    });

    test('handles corrupted cache gracefully', () async {
      storage['node_encounters_v1'] = 'not valid json';

      await service.init();
      expect(service.getAllEncounters(), isEmpty);
    });

    test('handles malformed entries gracefully', () async {
      storage['node_encounters_v1'] = '[{"invalid": true}]';

      // Should not throw, but may lose data
      expect(() async => await service.init(), returnsNormally);
    });
  });
}
