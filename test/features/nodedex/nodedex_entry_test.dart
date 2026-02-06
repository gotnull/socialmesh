// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';

void main() {
  // ===========================================================================
  // CoSeenRelationship
  // ===========================================================================

  group('CoSeenRelationship', () {
    group('construction', () {
      test('initial factory creates relationship with count 1', () {
        final now = DateTime.now();
        final rel = CoSeenRelationship.initial(timestamp: now);

        expect(rel.count, equals(1));
        expect(rel.firstSeen, equals(now));
        expect(rel.lastSeen, equals(now));
        expect(rel.messageCount, equals(0));
      });

      test('initial factory defaults to DateTime.now when no timestamp', () {
        final before = DateTime.now();
        final rel = CoSeenRelationship.initial();
        final after = DateTime.now();

        expect(rel.count, equals(1));
        expect(
          rel.firstSeen.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          rel.firstSeen.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('constructor sets all fields', () {
        final fs = DateTime(2024, 1, 1);
        final ls = DateTime(2024, 6, 1);
        final rel = CoSeenRelationship(
          count: 5,
          firstSeen: fs,
          lastSeen: ls,
          messageCount: 3,
        );

        expect(rel.count, equals(5));
        expect(rel.firstSeen, equals(fs));
        expect(rel.lastSeen, equals(ls));
        expect(rel.messageCount, equals(3));

        final rel2 = CoSeenRelationship(
          count: 10,
          firstSeen: fs,
          lastSeen: ls,
          messageCount: 7,
        );
        expect(rel2.firstSeen, equals(fs));
        expect(rel2.lastSeen, equals(ls));
      });
    });

    group('recordSighting', () {
      test('increments count and updates lastSeen', () {
        final t1 = DateTime(2024, 1, 1);
        final t2 = DateTime(2024, 2, 1);
        final rel = CoSeenRelationship.initial(timestamp: t1);
        final updated = rel.recordSighting(timestamp: t2);

        expect(updated.count, equals(2));
        expect(updated.firstSeen, equals(t1));
        expect(updated.lastSeen, equals(t2));
        expect(updated.messageCount, equals(0));
      });

      test('preserves messageCount across sightings', () {
        final t1 = DateTime(2024, 1, 1);
        final rel = CoSeenRelationship(
          count: 3,
          firstSeen: t1,
          lastSeen: t1,
          messageCount: 5,
        );
        final t2 = DateTime(2024, 3, 1);
        final updated = rel.recordSighting(timestamp: t2);

        expect(updated.count, equals(4));
        expect(updated.messageCount, equals(5));
      });

      test('does not modify firstSeen', () {
        final t1 = DateTime(2024, 1, 1);
        final rel = CoSeenRelationship.initial(timestamp: t1);

        final t2 = DateTime(2024, 6, 1);
        final updated = rel.recordSighting(timestamp: t2);

        expect(updated.firstSeen, equals(t1));
      });
    });

    group('incrementMessages', () {
      test('increments message count by 1', () {
        final rel = CoSeenRelationship.initial(timestamp: DateTime(2024));
        final updated = rel.incrementMessages();

        expect(updated.messageCount, equals(1));
        expect(updated.count, equals(1));
      });

      test('increments message count by arbitrary amount', () {
        final rel = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
          messageCount: 10,
        );
        final updated = rel.incrementMessages(by: 3);

        expect(updated.messageCount, equals(13));
      });

      test('does not modify count, firstSeen, or lastSeen', () {
        final fs = DateTime(2024, 1, 1);
        final ls = DateTime(2024, 6, 1);
        final rel = CoSeenRelationship(
          count: 7,
          firstSeen: fs,
          lastSeen: ls,
          messageCount: 2,
        );
        final updated = rel.incrementMessages(by: 5);

        expect(updated.count, equals(7));
        expect(updated.firstSeen, equals(fs));
        expect(updated.lastSeen, equals(ls));
      });
    });

    group('computed properties', () {
      test('relationshipAge returns duration between first and last seen', () {
        final fs = DateTime(2024, 1, 1);
        final ls = DateTime(2024, 1, 31);
        final rel = CoSeenRelationship(count: 5, firstSeen: fs, lastSeen: ls);

        expect(rel.relationshipAge, equals(const Duration(days: 30)));
      });

      test('timeSinceLastSeen returns duration since last seen', () {
        final recent = DateTime.now().subtract(const Duration(hours: 2));
        final rel = CoSeenRelationship(
          count: 1,
          firstSeen: recent,
          lastSeen: recent,
        );

        expect(rel.timeSinceLastSeen.inHours, greaterThanOrEqualTo(2));
        expect(rel.timeSinceLastSeen.inHours, lessThan(3));
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        final original = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 3,
        );
        final copy = original.copyWith();

        expect(copy.count, equals(original.count));
        expect(copy.firstSeen, equals(original.firstSeen));
        expect(copy.lastSeen, equals(original.lastSeen));
        expect(copy.messageCount, equals(original.messageCount));
      });

      test('overrides specified fields', () {
        final original = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 3,
        );
        final newLs = DateTime(2024, 12, 1);
        final copy = original.copyWith(count: 10, lastSeen: newLs);

        expect(copy.count, equals(10));
        expect(copy.lastSeen, equals(newLs));
        expect(copy.firstSeen, equals(original.firstSeen));
        expect(copy.messageCount, equals(original.messageCount));
      });
    });

    group('merge', () {
      test('takes broadest time span and highest counts', () {
        final a = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 3, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 2,
        );
        final b = CoSeenRelationship(
          count: 8,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 5, 1),
          messageCount: 7,
        );

        final merged = a.merge(b);

        expect(merged.count, equals(8));
        expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
        expect(merged.lastSeen, equals(DateTime(2024, 6, 1)));
        expect(merged.messageCount, equals(7));
      });

      test('merge is symmetric for time range', () {
        final a = CoSeenRelationship(
          count: 3,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 12, 1),
          messageCount: 1,
        );
        final b = CoSeenRelationship(
          count: 10,
          firstSeen: DateTime(2024, 6, 1),
          lastSeen: DateTime(2024, 8, 1),
          messageCount: 5,
        );

        final ab = a.merge(b);
        final ba = b.merge(a);

        expect(ab.firstSeen, equals(ba.firstSeen));
        expect(ab.lastSeen, equals(ba.lastSeen));
        expect(ab.count, equals(ba.count));
        expect(ab.messageCount, equals(ba.messageCount));
      });
    });

    group('serialization', () {
      test('toJson produces correct structure', () {
        final rel = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          messageCount: 3,
        );
        final json = rel.toJson();

        expect(json['c'], equals(5));
        expect(json['fs'], equals(1700000000000));
        expect(json['ls'], equals(1700100000000));
        expect(json['mc'], equals(3));
      });

      test('toJson omits messageCount when zero', () {
        final rel = CoSeenRelationship(
          count: 1,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
        );
        final json = rel.toJson();

        expect(json.containsKey('mc'), isFalse);
      });

      test('v2 round-trip: toJson -> fromJson', () {
        final original = CoSeenRelationship(
          count: 7,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700200000000),
          messageCount: 4,
        );
        final json = original.toJson();
        final restored = CoSeenRelationship.fromJson(json);

        expect(restored.count, equals(original.count));
        expect(restored.firstSeen, equals(original.firstSeen));
        expect(restored.lastSeen, equals(original.lastSeen));
        expect(restored.messageCount, equals(original.messageCount));
      });

      test('v1 migration: fromJson handles plain int value', () {
        final fallback = DateTime(2024, 1, 1);
        final rel = CoSeenRelationship.fromJson(5, fallbackFirstSeen: fallback);

        expect(rel.count, equals(5));
        expect(rel.firstSeen, equals(fallback));
        expect(rel.lastSeen, equals(fallback));
        expect(rel.messageCount, equals(0));
      });

      test('v1 migration: defaults to DateTime.now when no fallback', () {
        final before = DateTime.now();
        final rel = CoSeenRelationship.fromJson(3);
        final after = DateTime.now();

        expect(rel.count, equals(3));
        expect(
          rel.firstSeen.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          rel.firstSeen.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('v2 fromJson handles missing optional fields', () {
        final json = <String, dynamic>{
          'c': 3,
          'fs': 1700000000000,
          'ls': 1700100000000,
        };
        final rel = CoSeenRelationship.fromJson(json);

        expect(rel.count, equals(3));
        expect(rel.messageCount, equals(0));
      });

      test('v2 fromJson handles missing count defaults to 1', () {
        final json = <String, dynamic>{
          'fs': 1700000000000,
          'ls': 1700100000000,
        };
        final rel = CoSeenRelationship.fromJson(json);

        expect(rel.count, equals(1));
      });

      test('v2 fromJson uses fallback when timestamps missing', () {
        final fallback = DateTime(2024, 3, 15);
        final json = <String, dynamic>{'c': 2};
        final rel = CoSeenRelationship.fromJson(
          json,
          fallbackFirstSeen: fallback,
        );

        expect(rel.firstSeen, equals(fallback));
        expect(rel.lastSeen, equals(fallback));
      });
    });

    group('toString', () {
      test('includes count, first, last, messages', () {
        final rel = CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 3,
        );
        final str = rel.toString();

        expect(str, contains('count: 5'));
        expect(str, contains('messages: 3'));
      });
    });
  });

  // ===========================================================================
  // NodeDexEntry
  // ===========================================================================

  group('NodeDexEntry', () {
    group('construction', () {
      test('default constructor sets required fields and defaults', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 42, firstSeen: now, lastSeen: now);

        expect(entry.nodeNum, equals(42));
        expect(entry.firstSeen, equals(now));
        expect(entry.lastSeen, equals(now));
        expect(entry.encounterCount, equals(1));
        expect(entry.maxDistanceSeen, isNull);
        expect(entry.bestSnr, isNull);
        expect(entry.bestRssi, isNull);
        expect(entry.messageCount, equals(0));
        expect(entry.socialTag, isNull);
        expect(entry.userNote, isNull);
        expect(entry.encounters, isEmpty);
        expect(entry.seenRegions, isEmpty);
        expect(entry.coSeenNodes, isEmpty);
        expect(entry.sigil, isNull);
      });

      test('discovered factory creates initial entry with encounter', () {
        final entry = NodeDexEntry.discovered(
          nodeNum: 100,
          distance: 1500.0,
          snr: 10,
          rssi: -90,
          latitude: 37.7749,
          longitude: -122.4194,
        );

        expect(entry.nodeNum, equals(100));
        expect(entry.encounterCount, equals(1));
        expect(entry.maxDistanceSeen, equals(1500.0));
        expect(entry.bestSnr, equals(10));
        expect(entry.bestRssi, equals(-90));
        expect(entry.encounters.length, equals(1));
        expect(entry.encounters.first.distanceMeters, equals(1500.0));
        expect(entry.encounters.first.latitude, equals(37.7749));
        expect(entry.encounters.first.longitude, equals(-122.4194));
      });

      test('discovered factory uses provided timestamp', () {
        final ts = DateTime(2024, 6, 15, 10, 30);
        final entry = NodeDexEntry.discovered(nodeNum: 1, timestamp: ts);

        expect(entry.firstSeen, equals(ts));
        expect(entry.lastSeen, equals(ts));
        expect(entry.encounters.first.timestamp, equals(ts));
      });

      test('discovered factory defaults timestamp to now', () {
        final before = DateTime.now();
        final entry = NodeDexEntry.discovered(nodeNum: 1);
        final after = DateTime.now();

        expect(
          entry.firstSeen.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          entry.firstSeen.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('discovered factory accepts sigil', () {
        const sigil = SigilData(
          vertices: 5,
          rotation: 1.0,
          innerRings: 2,
          drawRadials: true,
          centerDot: false,
          symmetryFold: 3,
          primaryColor: Color(0xFF0EA5E9),
          secondaryColor: Color(0xFF8B5CF6),
          tertiaryColor: Color(0xFFF97316),
        );
        final entry = NodeDexEntry.discovered(nodeNum: 1, sigil: sigil);

        expect(entry.sigil, equals(sigil));
      });
    });

    group('computed properties', () {
      test('isRecentlyDiscovered is true within 24 hours', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(hours: 12)),
          lastSeen: DateTime.now(),
        );

        expect(entry.isRecentlyDiscovered, isTrue);
      });

      test('isRecentlyDiscovered is false after 24 hours', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(hours: 25)),
          lastSeen: DateTime.now(),
        );

        expect(entry.isRecentlyDiscovered, isFalse);
      });

      test('age returns correct duration', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(days: 5)),
          lastSeen: DateTime.now(),
        );

        expect(entry.age.inDays, equals(5));
      });

      test('timeSinceLastSeen returns correct duration', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(days: 10)),
          lastSeen: DateTime.now().subtract(const Duration(hours: 3)),
        );

        expect(entry.timeSinceLastSeen.inHours, greaterThanOrEqualTo(3));
        expect(entry.timeSinceLastSeen.inHours, lessThan(4));
      });

      test('regionCount returns number of seen regions', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          seenRegions: [
            SeenRegion(
              regionId: 'a',
              label: 'A',
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              encounterCount: 1,
            ),
            SeenRegion(
              regionId: 'b',
              label: 'B',
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              encounterCount: 1,
            ),
          ],
        );

        expect(entry.regionCount, equals(2));
      });

      test('coSeenCount returns number of co-seen relationships', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          coSeenNodes: {
            2: CoSeenRelationship.initial(timestamp: now),
            3: CoSeenRelationship.initial(timestamp: now),
            4: CoSeenRelationship.initial(timestamp: now),
          },
        );

        expect(entry.coSeenCount, equals(3));
      });

      test('topCoSeenWeight returns highest co-seen count', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          coSeenNodes: {
            2: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
            3: CoSeenRelationship(count: 10, firstSeen: now, lastSeen: now),
            4: CoSeenRelationship(count: 7, firstSeen: now, lastSeen: now),
          },
        );

        expect(entry.topCoSeenWeight, equals(10));
      });

      test('topCoSeenWeight returns 0 when no co-seen nodes', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        expect(entry.topCoSeenWeight, equals(0));
      });

      test('distinctPositionCount counts unique positions', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          encounters: [
            EncounterRecord(
              timestamp: now,
              latitude: 37.7749,
              longitude: -122.4194,
            ),
            // Same position (within ~100m precision)
            EncounterRecord(
              timestamp: now.add(const Duration(minutes: 10)),
              latitude: 37.7749,
              longitude: -122.4194,
            ),
            // Different position
            EncounterRecord(
              timestamp: now.add(const Duration(minutes: 20)),
              latitude: 37.79,
              longitude: -122.40,
            ),
            // No position
            EncounterRecord(timestamp: now.add(const Duration(minutes: 30))),
          ],
        );

        expect(entry.distinctPositionCount, equals(2));
      });

      test('distinctPositionCount is 0 when no positions available', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          encounters: [
            EncounterRecord(timestamp: now),
            EncounterRecord(timestamp: now.add(const Duration(minutes: 10))),
          ],
        );

        expect(entry.distinctPositionCount, equals(0));
      });

      test('hasEnoughDataForTrait is true with 3+ encounters', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          encounterCount: 3,
        );

        expect(entry.hasEnoughDataForTrait, isTrue);
      });

      test('hasEnoughDataForTrait is true when age >= 1 day', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
          lastSeen: DateTime.now(),
          encounterCount: 1,
        );

        expect(entry.hasEnoughDataForTrait, isTrue);
      });

      test('hasEnoughDataForTrait is false with low encounters and young', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now().subtract(const Duration(hours: 12)),
          lastSeen: DateTime.now(),
          encounterCount: 2,
        );

        expect(entry.hasEnoughDataForTrait, isFalse);
      });
    });

    group('recordEncounter', () {
      test('increments encounter count when cooldown has passed', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final t2 = DateTime(2024, 1, 1, 10, 10); // 10 min later (> 5 min)
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          encounterCount: 1,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final updated = entry.recordEncounter(timestamp: t2, snr: 5);

        expect(updated.encounterCount, equals(2));
        expect(updated.lastSeen, equals(t2));
        expect(updated.encounters.length, equals(2));
      });

      test('does not increment encounter count within cooldown', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final t2 = DateTime(2024, 1, 1, 10, 3); // 3 min later (< 5 min)
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          encounterCount: 1,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final updated = entry.recordEncounter(timestamp: t2);

        expect(updated.encounterCount, equals(1));
        expect(updated.lastSeen, equals(t2));
        expect(updated.encounters.length, equals(2));
      });

      test('updates maxDistanceSeen when new distance is greater', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          maxDistanceSeen: 500.0,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final t2 = DateTime(2024, 1, 1, 10, 10);
        final updated = entry.recordEncounter(timestamp: t2, distance: 1200.0);

        expect(updated.maxDistanceSeen, equals(1200.0));
      });

      test('does not lower maxDistanceSeen', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          maxDistanceSeen: 5000.0,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final t2 = DateTime(2024, 1, 1, 10, 10);
        final updated = entry.recordEncounter(timestamp: t2, distance: 200.0);

        expect(updated.maxDistanceSeen, equals(5000.0));
      });

      test('updates bestSnr when new SNR is higher', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          bestSnr: 5,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final t2 = DateTime(2024, 1, 1, 10, 10);
        final updated = entry.recordEncounter(timestamp: t2, snr: 12);

        expect(updated.bestSnr, equals(12));
      });

      test('does not lower bestSnr', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          bestSnr: 15,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final t2 = DateTime(2024, 1, 1, 10, 10);
        final updated = entry.recordEncounter(timestamp: t2, snr: 3);

        expect(updated.bestSnr, equals(15));
      });

      test('updates bestRssi when new RSSI is higher (closer to 0)', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          bestRssi: -100,
          encounters: [EncounterRecord(timestamp: t1)],
        );

        final t2 = DateTime(2024, 1, 1, 10, 10);
        final updated = entry.recordEncounter(timestamp: t2, rssi: -75);

        expect(updated.bestRssi, equals(-75));
      });

      test('maintains rolling window of encounters', () {
        final t0 = DateTime(2024, 1, 1);
        final encounters = List.generate(
          NodeDexEntry.maxEncounterRecords,
          (i) => EncounterRecord(timestamp: t0.add(Duration(minutes: i * 10))),
        );

        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t0,
          lastSeen: encounters.last.timestamp,
          encounterCount: encounters.length,
          encounters: encounters,
        );

        // Add one more encounter
        final tNew = t0.add(Duration(minutes: encounters.length * 10));
        final updated = entry.recordEncounter(timestamp: tNew);

        expect(
          updated.encounters.length,
          equals(NodeDexEntry.maxEncounterRecords),
        );
        // Oldest encounter should have been removed
        expect(updated.encounters.first.timestamp, isNot(equals(t0)));
        // Newest encounter should be the one we just added
        expect(updated.encounters.last.timestamp, equals(tNew));
      });

      test('first encounter on empty encounters list always counts', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          encounterCount: 0,
        );

        final updated = entry.recordEncounter(timestamp: now);

        expect(updated.encounterCount, equals(1));
      });

      test('sets initial maxDistanceSeen from null', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final updated = entry.recordEncounter(
          timestamp: now.add(const Duration(minutes: 10)),
          distance: 750.0,
        );

        expect(updated.maxDistanceSeen, equals(750.0));
      });
    });

    group('addCoSeen', () {
      test('creates new CoSeenRelationship for first co-sighting', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final updated = entry.addCoSeen(2, timestamp: now);

        expect(updated.coSeenNodes.containsKey(2), isTrue);
        expect(updated.coSeenNodes[2]!.count, equals(1));
        expect(updated.coSeenNodes[2]!.firstSeen, equals(now));
      });

      test('increments existing relationship on subsequent co-sighting', () {
        final t1 = DateTime(2024, 1, 1);
        final t2 = DateTime(2024, 2, 1);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          coSeenNodes: {2: CoSeenRelationship.initial(timestamp: t1)},
        );

        final updated = entry.addCoSeen(2, timestamp: t2);

        expect(updated.coSeenNodes[2]!.count, equals(2));
        expect(updated.coSeenNodes[2]!.firstSeen, equals(t1));
        expect(updated.coSeenNodes[2]!.lastSeen, equals(t2));
      });

      test('does not add self as co-seen', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final updated = entry.addCoSeen(1);

        expect(updated.coSeenNodes.isEmpty, isTrue);
      });

      test('preserves other co-seen relationships when adding new one', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          coSeenNodes: {2: CoSeenRelationship.initial(timestamp: now)},
        );

        final updated = entry.addCoSeen(3, timestamp: now);

        expect(updated.coSeenNodes.containsKey(2), isTrue);
        expect(updated.coSeenNodes.containsKey(3), isTrue);
        expect(updated.coSeenNodes[2]!.count, equals(1));
        expect(updated.coSeenNodes[3]!.count, equals(1));
      });
    });

    group('incrementCoSeenMessages', () {
      test('increments message count on existing relationship', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          coSeenNodes: {
            2: CoSeenRelationship(
              count: 5,
              firstSeen: now,
              lastSeen: now,
              messageCount: 3,
            ),
          },
        );

        final updated = entry.incrementCoSeenMessages(2, by: 2);

        expect(updated.coSeenNodes[2]!.messageCount, equals(5));
        expect(updated.coSeenNodes[2]!.count, equals(5)); // unchanged
      });

      test('is no-op for non-existent relationship', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final updated = entry.incrementCoSeenMessages(99);

        expect(updated.coSeenNodes.isEmpty, isTrue);
      });

      test('is no-op for self', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          coSeenNodes: {1: CoSeenRelationship.initial(timestamp: now)},
        );

        final updated = entry.incrementCoSeenMessages(1);

        // Should not modify (self-reference blocked)
        expect(updated.coSeenNodes[1]!.messageCount, equals(0));
      });
    });

    group('addRegion', () {
      test('adds new region', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final updated = entry.addRegion('g37_-122', '37\u00B0N 122\u00B0W');

        expect(updated.seenRegions.length, equals(1));
        expect(updated.seenRegions.first.regionId, equals('g37_-122'));
        expect(updated.seenRegions.first.encounterCount, equals(1));
      });

      test('updates existing region counter and lastSeen', () {
        final t1 = DateTime(2024, 1, 1);
        final t2 = DateTime(2024, 6, 1);
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: t1,
          lastSeen: t1,
          seenRegions: [
            SeenRegion(
              regionId: 'g37_-122',
              label: '37\u00B0N 122\u00B0W',
              firstSeen: t1,
              lastSeen: t1,
              encounterCount: 3,
            ),
          ],
        );

        final updated = entry.addRegion(
          'g37_-122',
          '37\u00B0N 122\u00B0W',
          timestamp: t2,
        );

        expect(updated.seenRegions.length, equals(1));
        expect(updated.seenRegions.first.encounterCount, equals(4));
        expect(updated.seenRegions.first.lastSeen, equals(t2));
        expect(updated.seenRegions.first.firstSeen, equals(t1));
      });

      test('adds second distinct region', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: now,
          lastSeen: now,
          seenRegions: [
            SeenRegion(
              regionId: 'g37_-122',
              label: 'A',
              firstSeen: now,
              lastSeen: now,
              encounterCount: 1,
            ),
          ],
        );

        final updated = entry.addRegion('g38_-121', 'B');

        expect(updated.seenRegions.length, equals(2));
      });
    });

    group('incrementMessages', () {
      test('increments by 1 by default', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          messageCount: 5,
        );

        final updated = entry.incrementMessages();

        expect(updated.messageCount, equals(6));
      });

      test('increments by arbitrary amount', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          messageCount: 10,
        );

        final updated = entry.incrementMessages(by: 5);

        expect(updated.messageCount, equals(15));
      });
    });

    group('copyWith', () {
      test('copies all fields when no overrides', () {
        final now = DateTime.now();
        const sigil = SigilData(
          vertices: 5,
          rotation: 1.0,
          innerRings: 2,
          drawRadials: true,
          centerDot: false,
          symmetryFold: 3,
          primaryColor: Color(0xFF0EA5E9),
          secondaryColor: Color(0xFF8B5CF6),
          tertiaryColor: Color(0xFFF97316),
        );
        final entry = NodeDexEntry(
          nodeNum: 42,
          firstSeen: now,
          lastSeen: now,
          encounterCount: 5,
          maxDistanceSeen: 1500.0,
          bestSnr: 10,
          bestRssi: -80,
          messageCount: 3,
          socialTag: NodeSocialTag.contact,
          userNote: 'test note',
          sigil: sigil,
        );

        final copy = entry.copyWith();

        expect(copy.nodeNum, equals(42));
        expect(copy.encounterCount, equals(5));
        expect(copy.maxDistanceSeen, equals(1500.0));
        expect(copy.bestSnr, equals(10));
        expect(copy.bestRssi, equals(-80));
        expect(copy.messageCount, equals(3));
        expect(copy.socialTag, equals(NodeSocialTag.contact));
        expect(copy.userNote, equals('test note'));
        expect(copy.sigil, equals(sigil));
      });

      test('overrides specified fields', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          encounterCount: 1,
          messageCount: 0,
        );

        final copy = entry.copyWith(encounterCount: 10, messageCount: 5);

        expect(copy.encounterCount, equals(10));
        expect(copy.messageCount, equals(5));
        expect(copy.nodeNum, equals(1));
      });

      test('clearSocialTag clears the social tag', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          socialTag: NodeSocialTag.trustedNode,
        );

        final copy = entry.copyWith(clearSocialTag: true);

        expect(copy.socialTag, isNull);
      });

      test('clearUserNote clears the user note', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          userNote: 'some note',
        );

        final copy = entry.copyWith(clearUserNote: true);

        expect(copy.userNote, isNull);
      });

      test('can set new socialTag via copyWith', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        final copy = entry.copyWith(socialTag: NodeSocialTag.knownRelay);

        expect(copy.socialTag, equals(NodeSocialTag.knownRelay));
      });

      test('can override coSeenNodes', () {
        final now = DateTime.now();
        final entry = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);

        final newCoSeen = {2: CoSeenRelationship.initial(timestamp: now)};
        final copy = entry.copyWith(coSeenNodes: newCoSeen);

        expect(copy.coSeenNodes.containsKey(2), isTrue);
      });
    });

    group('equality', () {
      test('entries with identical fields are equal', () {
        final now = DateTime(2024, 1, 1);
        final a = NodeDexEntry(
          nodeNum: 42,
          firstSeen: now,
          lastSeen: now,
          encounterCount: 5,
        );
        final b = NodeDexEntry(
          nodeNum: 42,
          firstSeen: now,
          lastSeen: now,
          encounterCount: 5,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test(
        'entries with same nodeNum but different encounterCount are not equal',
        () {
          final now = DateTime(2024, 1, 1);
          final a = NodeDexEntry(
            nodeNum: 42,
            firstSeen: now,
            lastSeen: now,
            encounterCount: 1,
          );
          final b = NodeDexEntry(
            nodeNum: 42,
            firstSeen: now,
            lastSeen: now,
            encounterCount: 100,
          );

          expect(a, isNot(equals(b)));
        },
      );

      test(
        'entries with same nodeNum but different socialTag are not equal',
        () {
          final now = DateTime(2024, 1, 1);
          final a = NodeDexEntry(nodeNum: 42, firstSeen: now, lastSeen: now);
          final b = NodeDexEntry(
            nodeNum: 42,
            firstSeen: now,
            lastSeen: now,
            socialTag: NodeSocialTag.frequentPeer,
          );

          expect(a, isNot(equals(b)));
        },
      );

      test(
        'entries with same nodeNum but different userNote are not equal',
        () {
          final now = DateTime(2024, 1, 1);
          final a = NodeDexEntry(
            nodeNum: 42,
            firstSeen: now,
            lastSeen: now,
            userNote: 'hello',
          );
          final b = NodeDexEntry(
            nodeNum: 42,
            firstSeen: now,
            lastSeen: now,
            userNote: 'world',
          );

          expect(a, isNot(equals(b)));
        },
      );

      test('entries with different nodeNum are not equal', () {
        final now = DateTime.now();
        final a = NodeDexEntry(nodeNum: 1, firstSeen: now, lastSeen: now);
        final b = NodeDexEntry(nodeNum: 2, firstSeen: now, lastSeen: now);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('includes nodeNum, encounters, regions, and tag', () {
        final entry = NodeDexEntry(
          nodeNum: 42,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          encounterCount: 5,
          socialTag: NodeSocialTag.frequentPeer,
          seenRegions: [
            SeenRegion(
              regionId: 'a',
              label: 'A',
              firstSeen: DateTime.now(),
              lastSeen: DateTime.now(),
              encounterCount: 1,
            ),
          ],
        );

        final str = entry.toString();

        expect(str, contains('42'));
        expect(str, contains('5'));
        expect(str, contains('Frequent Peer'));
      });

      test('shows none when no social tag', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        expect(entry.toString(), contains('none'));
      });
    });

    group('serialization', () {
      test('full round-trip: toJson -> fromJson', () {
        final now = DateTime.now();
        // Truncate to milliseconds for clean comparison
        final firstSeen = DateTime.fromMillisecondsSinceEpoch(
          now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        );
        final lastSeen = DateTime.fromMillisecondsSinceEpoch(
          now.millisecondsSinceEpoch,
        );

        const sigil = SigilData(
          vertices: 6,
          rotation: 1.5,
          innerRings: 1,
          drawRadials: true,
          centerDot: true,
          symmetryFold: 4,
          primaryColor: Color(0xFF0EA5E9),
          secondaryColor: Color(0xFF8B5CF6),
          tertiaryColor: Color(0xFFF97316),
        );

        final original = NodeDexEntry(
          nodeNum: 12345,
          firstSeen: firstSeen,
          lastSeen: lastSeen,
          encounterCount: 15,
          maxDistanceSeen: 3500.5,
          bestSnr: 12,
          bestRssi: -85,
          messageCount: 7,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'Test node for testing',
          encounters: [
            EncounterRecord(
              timestamp: firstSeen,
              distanceMeters: 1000.0,
              snr: 8,
              rssi: -90,
              latitude: 37.7749,
              longitude: -122.4194,
            ),
            EncounterRecord(
              timestamp: lastSeen,
              distanceMeters: 3500.5,
              snr: 12,
              rssi: -85,
            ),
          ],
          seenRegions: [
            SeenRegion(
              regionId: 'g37_-122',
              label: '37\u00B0N 122\u00B0W',
              firstSeen: firstSeen,
              lastSeen: lastSeen,
              encounterCount: 5,
            ),
          ],
          coSeenNodes: {
            2: CoSeenRelationship(
              count: 3,
              firstSeen: firstSeen,
              lastSeen: lastSeen,
              messageCount: 2,
            ),
            3: CoSeenRelationship(
              count: 1,
              firstSeen: lastSeen,
              lastSeen: lastSeen,
            ),
          },
          sigil: sigil,
        );

        final json = original.toJson();
        final restored = NodeDexEntry.fromJson(json);

        expect(restored.nodeNum, equals(original.nodeNum));
        expect(restored.firstSeen, equals(original.firstSeen));
        expect(restored.lastSeen, equals(original.lastSeen));
        expect(restored.encounterCount, equals(original.encounterCount));
        expect(restored.maxDistanceSeen, equals(original.maxDistanceSeen));
        expect(restored.bestSnr, equals(original.bestSnr));
        expect(restored.bestRssi, equals(original.bestRssi));
        expect(restored.messageCount, equals(original.messageCount));
        expect(restored.socialTag, equals(original.socialTag));
        expect(restored.userNote, equals(original.userNote));
        expect(restored.encounters.length, equals(original.encounters.length));
        expect(
          restored.encounters.first.timestamp,
          equals(original.encounters.first.timestamp),
        );
        expect(
          restored.encounters.first.distanceMeters,
          equals(original.encounters.first.distanceMeters),
        );
        expect(
          restored.encounters.first.latitude,
          equals(original.encounters.first.latitude),
        );
        expect(restored.seenRegions.length, equals(1));
        expect(restored.seenRegions.first.regionId, equals('g37_-122'));
        expect(restored.seenRegions.first.encounterCount, equals(5));
        expect(restored.coSeenNodes.length, equals(2));
        expect(restored.coSeenNodes[2]!.count, equals(3));
        expect(restored.coSeenNodes[2]!.messageCount, equals(2));
        expect(restored.coSeenNodes[2]!.firstSeen, equals(firstSeen));
        expect(restored.coSeenNodes[3]!.count, equals(1));
        expect(restored.sigil, isNotNull);
        expect(restored.sigil!.vertices, equals(6));
        expect(restored.sigil!.primaryColor, equals(const Color(0xFF0EA5E9)));
      });

      test('toJson omits null optional fields', () {
        final entry = NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        final json = entry.toJson();

        expect(json.containsKey('md'), isFalse);
        expect(json.containsKey('bs'), isFalse);
        expect(json.containsKey('br'), isFalse);
        expect(json.containsKey('st'), isFalse);
        expect(json.containsKey('un'), isFalse);
        expect(json.containsKey('sig'), isFalse);
      });

      test('fromJson handles missing optional fields gracefully', () {
        final json = <String, dynamic>{
          'nn': 42,
          'fs': DateTime.now().millisecondsSinceEpoch,
          'ls': DateTime.now().millisecondsSinceEpoch,
        };
        final entry = NodeDexEntry.fromJson(json);

        expect(entry.nodeNum, equals(42));
        expect(entry.encounterCount, equals(1));
        expect(entry.maxDistanceSeen, isNull);
        expect(entry.bestSnr, isNull);
        expect(entry.bestRssi, isNull);
        expect(entry.messageCount, equals(0));
        expect(entry.socialTag, isNull);
        expect(entry.userNote, isNull);
        expect(entry.encounters, isEmpty);
        expect(entry.seenRegions, isEmpty);
        expect(entry.coSeenNodes, isEmpty);
        expect(entry.sigil, isNull);
      });

      test('v1 legacy migration: csn with int values', () {
        final firstSeenMs = DateTime(2024, 1, 1).millisecondsSinceEpoch;
        final json = <String, dynamic>{
          'nn': 42,
          'fs': firstSeenMs,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'csn': {'100': 5, '200': 3},
        };

        final entry = NodeDexEntry.fromJson(json);

        expect(entry.coSeenNodes.length, equals(2));
        expect(entry.coSeenNodes[100]!.count, equals(5));
        expect(entry.coSeenNodes[200]!.count, equals(3));
        // Fallback timestamps should be the entry's firstSeen
        expect(
          entry.coSeenNodes[100]!.firstSeen,
          equals(DateTime.fromMillisecondsSinceEpoch(firstSeenMs)),
        );
        expect(entry.coSeenNodes[100]!.messageCount, equals(0));
      });

      test('v2 format: csn with object values', () {
        final json = <String, dynamic>{
          'nn': 42,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'csn': {
            '100': {
              'c': 5,
              'fs': DateTime(2024, 1, 15).millisecondsSinceEpoch,
              'ls': DateTime(2024, 5, 1).millisecondsSinceEpoch,
              'mc': 2,
            },
            '200': {
              'c': 3,
              'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
              'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
            },
          },
        };

        final entry = NodeDexEntry.fromJson(json);

        expect(entry.coSeenNodes.length, equals(2));
        expect(entry.coSeenNodes[100]!.count, equals(5));
        expect(entry.coSeenNodes[100]!.messageCount, equals(2));
        expect(
          entry.coSeenNodes[100]!.firstSeen,
          equals(DateTime(2024, 1, 15)),
        );
        expect(entry.coSeenNodes[200]!.count, equals(3));
        expect(entry.coSeenNodes[200]!.messageCount, equals(0));
      });

      test('mixed v1/v2 csn values migrate correctly', () {
        // This shouldn't happen in practice but tests robustness.
        final json = <String, dynamic>{
          'nn': 42,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'csn': {
            '100': 5, // v1 int
            '200': {
              'c': 3,
              'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
              'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
            }, // v2 object
          },
        };

        final entry = NodeDexEntry.fromJson(json);

        expect(entry.coSeenNodes[100]!.count, equals(5));
        expect(entry.coSeenNodes[200]!.count, equals(3));
      });

      test('encodeList and decodeList round-trip', () {
        final now = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
        );
        final entries = [
          NodeDexEntry(
            nodeNum: 1,
            firstSeen: now,
            lastSeen: now,
            encounterCount: 5,
          ),
          NodeDexEntry(
            nodeNum: 2,
            firstSeen: now,
            lastSeen: now,
            encounterCount: 10,
            socialTag: NodeSocialTag.contact,
          ),
        ];

        final encoded = NodeDexEntry.encodeList(entries);
        final decoded = NodeDexEntry.decodeList(encoded);

        expect(decoded.length, equals(2));
        expect(decoded[0].nodeNum, equals(1));
        expect(decoded[0].encounterCount, equals(5));
        expect(decoded[1].nodeNum, equals(2));
        expect(decoded[1].encounterCount, equals(10));
        expect(decoded[1].socialTag, equals(NodeSocialTag.contact));
      });

      test('encodeList produces valid JSON', () {
        final entries = [
          NodeDexEntry(
            nodeNum: 1,
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        ];

        final encoded = NodeDexEntry.encodeList(entries);
        final parsed = jsonDecode(encoded);

        expect(parsed, isA<List>());
        expect((parsed as List).length, equals(1));
      });

      test('v2 csn serialization round-trip preserves all fields', () {
        final fs = DateTime.fromMillisecondsSinceEpoch(1700000000000);
        final ls = DateTime.fromMillisecondsSinceEpoch(1700200000000);
        final entry = NodeDexEntry(
          nodeNum: 42,
          firstSeen: fs,
          lastSeen: ls,
          coSeenNodes: {
            10: CoSeenRelationship(
              count: 7,
              firstSeen: fs,
              lastSeen: ls,
              messageCount: 4,
            ),
          },
        );

        final json = entry.toJson();
        final restored = NodeDexEntry.fromJson(json);

        final rel = restored.coSeenNodes[10]!;
        expect(rel.count, equals(7));
        expect(rel.firstSeen, equals(fs));
        expect(rel.lastSeen, equals(ls));
        expect(rel.messageCount, equals(4));
      });
    });

    group('social tags', () {
      test('all social tags have display labels', () {
        for (final tag in NodeSocialTag.values) {
          expect(tag.displayLabel, isNotEmpty);
        }
      });

      test('all social tags have icons', () {
        for (final tag in NodeSocialTag.values) {
          expect(tag.icon, isNotEmpty);
        }
      });

      test('social tag round-trips through index serialization', () {
        for (final tag in NodeSocialTag.values) {
          final json = <String, dynamic>{
            'nn': 1,
            'fs': DateTime.now().millisecondsSinceEpoch,
            'ls': DateTime.now().millisecondsSinceEpoch,
            'st': tag.index,
          };
          final entry = NodeDexEntry.fromJson(json);
          expect(entry.socialTag, equals(tag));
        }
      });
    });
  });

  // ===========================================================================
  // EncounterRecord
  // ===========================================================================

  group('EncounterRecord', () {
    test('construction with all fields', () {
      final now = DateTime.now();
      final record = EncounterRecord(
        timestamp: now,
        distanceMeters: 1500.0,
        snr: 10,
        rssi: -85,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(record.timestamp, equals(now));
      expect(record.distanceMeters, equals(1500.0));
      expect(record.snr, equals(10));
      expect(record.rssi, equals(-85));
      expect(record.latitude, equals(37.7749));
      expect(record.longitude, equals(-122.4194));
    });

    test('construction with only required fields', () {
      final now = DateTime.now();
      final record = EncounterRecord(timestamp: now);

      expect(record.distanceMeters, isNull);
      expect(record.snr, isNull);
      expect(record.rssi, isNull);
      expect(record.latitude, isNull);
      expect(record.longitude, isNull);
    });

    test('toJson omits null fields', () {
      final now = DateTime.now();
      final record = EncounterRecord(timestamp: now, snr: 5);
      final json = record.toJson();

      expect(json.containsKey('ts'), isTrue);
      expect(json.containsKey('s'), isTrue);
      expect(json.containsKey('d'), isFalse);
      expect(json.containsKey('r'), isFalse);
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lon'), isFalse);
    });

    test('round-trip: toJson -> fromJson', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final original = EncounterRecord(
        timestamp: now,
        distanceMeters: 2500.0,
        snr: 12,
        rssi: -70,
        latitude: 48.8566,
        longitude: 2.3522,
      );

      final json = original.toJson();
      final restored = EncounterRecord.fromJson(json);

      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.distanceMeters, equals(original.distanceMeters));
      expect(restored.snr, equals(original.snr));
      expect(restored.rssi, equals(original.rssi));
      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
    });

    test('copyWith preserves unspecified fields', () {
      final now = DateTime.now();
      final record = EncounterRecord(
        timestamp: now,
        distanceMeters: 1000.0,
        snr: 8,
      );

      final copy = record.copyWith(rssi: -90);

      expect(copy.timestamp, equals(now));
      expect(copy.distanceMeters, equals(1000.0));
      expect(copy.snr, equals(8));
      expect(copy.rssi, equals(-90));
    });
  });

  // ===========================================================================
  // SeenRegion
  // ===========================================================================

  group('SeenRegion', () {
    test('construction', () {
      final fs = DateTime(2024, 1, 1);
      final ls = DateTime(2024, 6, 1);
      final region = SeenRegion(
        regionId: 'g37_-122',
        label: '37\u00B0N 122\u00B0W',
        firstSeen: fs,
        lastSeen: ls,
        encounterCount: 5,
      );

      expect(region.regionId, equals('g37_-122'));
      expect(region.label, equals('37\u00B0N 122\u00B0W'));
      expect(region.firstSeen, equals(fs));
      expect(region.lastSeen, equals(ls));
      expect(region.encounterCount, equals(5));
    });

    test('copyWith updates specified fields', () {
      final fs = DateTime(2024, 1, 1);
      final region = SeenRegion(
        regionId: 'a',
        label: 'A',
        firstSeen: fs,
        lastSeen: fs,
        encounterCount: 1,
      );

      final newLs = DateTime(2024, 6, 1);
      final copy = region.copyWith(lastSeen: newLs, encounterCount: 5);

      expect(copy.regionId, equals('a'));
      expect(copy.label, equals('A'));
      expect(copy.firstSeen, equals(fs));
      expect(copy.lastSeen, equals(newLs));
      expect(copy.encounterCount, equals(5));
    });

    test('round-trip: toJson -> fromJson', () {
      final fs = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final ls = DateTime.fromMillisecondsSinceEpoch(1700100000000);
      final original = SeenRegion(
        regionId: 'g37_-122',
        label: '37\u00B0N 122\u00B0W',
        firstSeen: fs,
        lastSeen: ls,
        encounterCount: 10,
      );

      final json = original.toJson();
      final restored = SeenRegion.fromJson(json);

      expect(restored.regionId, equals(original.regionId));
      expect(restored.label, equals(original.label));
      expect(restored.firstSeen, equals(original.firstSeen));
      expect(restored.lastSeen, equals(original.lastSeen));
      expect(restored.encounterCount, equals(original.encounterCount));
    });
  });

  // ===========================================================================
  // SigilData
  // ===========================================================================

  group('SigilData', () {
    test('round-trip: toJson -> fromJson', () {
      const original = SigilData(
        vertices: 7,
        rotation: 2.0,
        innerRings: 3,
        drawRadials: false,
        centerDot: true,
        symmetryFold: 5,
        primaryColor: Color(0xFFEF4444),
        secondaryColor: Color(0xFFFBBF24),
        tertiaryColor: Color(0xFF10B981),
      );

      final json = original.toJson();
      final restored = SigilData.fromJson(json);

      expect(restored.vertices, equals(original.vertices));
      expect(restored.rotation, equals(original.rotation));
      expect(restored.innerRings, equals(original.innerRings));
      expect(restored.drawRadials, equals(original.drawRadials));
      expect(restored.centerDot, equals(original.centerDot));
      expect(restored.symmetryFold, equals(original.symmetryFold));
      expect(restored.primaryColor, equals(original.primaryColor));
      expect(restored.secondaryColor, equals(original.secondaryColor));
      expect(restored.tertiaryColor, equals(original.tertiaryColor));
    });
  });

  // ===========================================================================
  // ExplorerTitle
  // ===========================================================================

  group('ExplorerTitle', () {
    test('all titles have display labels', () {
      for (final title in ExplorerTitle.values) {
        expect(title.displayLabel, isNotEmpty);
      }
    });

    test('all titles have descriptions', () {
      for (final title in ExplorerTitle.values) {
        expect(title.description, isNotEmpty);
      }
    });
  });

  // ===========================================================================
  // NodeDexStats
  // ===========================================================================

  group('NodeDexStats', () {
    test('default constructor has zero values', () {
      const stats = NodeDexStats();

      expect(stats.totalNodes, equals(0));
      expect(stats.totalRegions, equals(0));
      expect(stats.longestDistance, isNull);
      expect(stats.totalEncounters, equals(0));
      expect(stats.oldestDiscovery, isNull);
      expect(stats.newestDiscovery, isNull);
      expect(stats.traitDistribution, isEmpty);
      expect(stats.socialTagDistribution, isEmpty);
      expect(stats.bestSnrOverall, isNull);
      expect(stats.bestRssiOverall, isNull);
    });

    group('explorerTitle', () {
      test('newcomer for < 5 nodes', () {
        const stats = NodeDexStats(totalNodes: 3);
        expect(stats.explorerTitle, equals(ExplorerTitle.newcomer));
      });

      test('observer for 5-19 nodes', () {
        const stats = NodeDexStats(totalNodes: 10);
        expect(stats.explorerTitle, equals(ExplorerTitle.observer));
      });

      test('explorer for 20-49 nodes', () {
        const stats = NodeDexStats(totalNodes: 30);
        expect(stats.explorerTitle, equals(ExplorerTitle.explorer));
      });

      test('cartographer for 50-99 nodes', () {
        const stats = NodeDexStats(totalNodes: 75);
        expect(stats.explorerTitle, equals(ExplorerTitle.cartographer));
      });

      test('signalHunter for 100-199 nodes', () {
        const stats = NodeDexStats(totalNodes: 150);
        expect(stats.explorerTitle, equals(ExplorerTitle.signalHunter));
      });

      test('meshVeteran for 200+ nodes', () {
        const stats = NodeDexStats(totalNodes: 250);
        expect(stats.explorerTitle, equals(ExplorerTitle.meshVeteran));
      });

      test('meshCartographer for 200+ nodes and 5+ regions', () {
        const stats = NodeDexStats(totalNodes: 250, totalRegions: 6);
        expect(stats.explorerTitle, equals(ExplorerTitle.meshCartographer));
      });

      test('longRangeRecordHolder for 50+ nodes with > 10km distance', () {
        const stats = NodeDexStats(totalNodes: 60, longestDistance: 15000.0);
        expect(
          stats.explorerTitle,
          equals(ExplorerTitle.longRangeRecordHolder),
        );
      });

      test('longRangeRecordHolder takes priority over meshVeteran', () {
        const stats = NodeDexStats(totalNodes: 300, longestDistance: 15000.0);
        expect(
          stats.explorerTitle,
          equals(ExplorerTitle.longRangeRecordHolder),
        );
      });
    });

    group('daysExploring', () {
      test('returns 0 when no oldest discovery', () {
        const stats = NodeDexStats();
        expect(stats.daysExploring, equals(0));
      });

      test('returns correct number of days', () {
        final stats = NodeDexStats(
          oldestDiscovery: DateTime.now().subtract(const Duration(days: 30)),
        );
        expect(stats.daysExploring, equals(30));
      });
    });
  });

  // ===========================================================================
  // SeenRegion.merge
  // ===========================================================================

  group('SeenRegion.merge', () {
    test('keeps broadest time span', () {
      final a = SeenRegion(
        regionId: 'g37_-122',
        label: '37°N 122°W',
        firstSeen: DateTime(2024, 3, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: 5,
      );
      final b = SeenRegion(
        regionId: 'g37_-122',
        label: '37°N 122°W',
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 5, 1),
        encounterCount: 8,
      );

      final merged = a.merge(b);

      expect(merged.regionId, equals('g37_-122'));
      expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(merged.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(merged.encounterCount, equals(8));
    });

    test('merge is symmetric for time range and count', () {
      final a = SeenRegion(
        regionId: 'r1',
        label: 'A',
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 12, 1),
        encounterCount: 3,
      );
      final b = SeenRegion(
        regionId: 'r1',
        label: 'B',
        firstSeen: DateTime(2024, 6, 1),
        lastSeen: DateTime(2024, 8, 1),
        encounterCount: 10,
      );

      final ab = a.merge(b);
      final ba = b.merge(a);

      expect(ab.firstSeen, equals(ba.firstSeen));
      expect(ab.lastSeen, equals(ba.lastSeen));
      expect(ab.encounterCount, equals(ba.encounterCount));
    });

    test('prefers non-empty label from this entry', () {
      final a = SeenRegion(
        regionId: 'r1',
        label: 'Good Label',
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 1),
        encounterCount: 1,
      );
      final b = SeenRegion(
        regionId: 'r1',
        label: 'Other Label',
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 1),
        encounterCount: 1,
      );

      final merged = a.merge(b);

      expect(merged.label, equals('Good Label'));
    });

    test('identical regions merge cleanly', () {
      final region = SeenRegion(
        regionId: 'r1',
        label: 'X',
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: 5,
      );

      final merged = region.merge(region);

      expect(merged.firstSeen, equals(region.firstSeen));
      expect(merged.lastSeen, equals(region.lastSeen));
      expect(merged.encounterCount, equals(region.encounterCount));
    });
  });

  // ===========================================================================
  // NodeDexEntry.mergeWith
  // ===========================================================================

  group('NodeDexEntry.mergeWith', () {
    NodeDexEntry makeEntry({
      int nodeNum = 42,
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
        sigil: sigil,
      );
    }

    group('scalar metrics', () {
      test('takes earliest firstSeen', () {
        final a = makeEntry(firstSeen: DateTime(2024, 3, 1));
        final b = makeEntry(firstSeen: DateTime(2024, 1, 1));

        final merged = a.mergeWith(b);

        expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
      });

      test('takes latest lastSeen', () {
        final a = makeEntry(lastSeen: DateTime(2024, 6, 1));
        final b = makeEntry(lastSeen: DateTime(2024, 12, 1));

        final merged = a.mergeWith(b);

        expect(merged.lastSeen, equals(DateTime(2024, 12, 1)));
      });

      test('takes maximum encounterCount', () {
        final a = makeEntry(encounterCount: 5);
        final b = makeEntry(encounterCount: 15);

        final merged = a.mergeWith(b);

        expect(merged.encounterCount, equals(15));
      });

      test('takes maximum messageCount', () {
        final a = makeEntry(messageCount: 3);
        final b = makeEntry(messageCount: 10);

        final merged = a.mergeWith(b);

        expect(merged.messageCount, equals(10));
      });

      test('takes maximum maxDistanceSeen', () {
        final a = makeEntry(maxDistanceSeen: 1500.0);
        final b = makeEntry(maxDistanceSeen: 5000.0);

        final merged = a.mergeWith(b);

        expect(merged.maxDistanceSeen, equals(5000.0));
      });

      test('takes non-null maxDistanceSeen when other is null', () {
        final a = makeEntry(maxDistanceSeen: 2000.0);
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.maxDistanceSeen, equals(2000.0));
      });

      test('takes non-null maxDistanceSeen when this is null', () {
        final a = makeEntry();
        final b = makeEntry(maxDistanceSeen: 3000.0);

        final merged = a.mergeWith(b);

        expect(merged.maxDistanceSeen, equals(3000.0));
      });

      test('both null maxDistanceSeen remains null', () {
        final a = makeEntry();
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.maxDistanceSeen, isNull);
      });

      test('takes maximum bestSnr', () {
        final a = makeEntry(bestSnr: 5);
        final b = makeEntry(bestSnr: 12);

        final merged = a.mergeWith(b);

        expect(merged.bestSnr, equals(12));
      });

      test('takes non-null bestSnr when other is null', () {
        final a = makeEntry(bestSnr: 8);
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.bestSnr, equals(8));
      });

      test('takes maximum bestRssi (closer to 0)', () {
        final a = makeEntry(bestRssi: -100);
        final b = makeEntry(bestRssi: -75);

        final merged = a.mergeWith(b);

        expect(merged.bestRssi, equals(-75));
      });

      test('takes non-null bestRssi when other is null', () {
        final a = makeEntry();
        final b = makeEntry(bestRssi: -90);

        final merged = a.mergeWith(b);

        expect(merged.bestRssi, equals(-90));
      });
    });

    group('local-only fields', () {
      test('prefers this entry socialTag when set', () {
        final a = makeEntry(socialTag: NodeSocialTag.contact);
        final b = makeEntry(socialTag: NodeSocialTag.trustedNode);

        final merged = a.mergeWith(b);

        expect(merged.socialTag, equals(NodeSocialTag.contact));
      });

      test('falls back to other socialTag when this is null', () {
        final a = makeEntry();
        final b = makeEntry(socialTag: NodeSocialTag.knownRelay);

        final merged = a.mergeWith(b);

        expect(merged.socialTag, equals(NodeSocialTag.knownRelay));
      });

      test('both null socialTag remains null', () {
        final a = makeEntry();
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.socialTag, isNull);
      });

      test('prefers this entry userNote when set', () {
        final a = makeEntry(userNote: 'my note');
        final b = makeEntry(userNote: 'other note');

        final merged = a.mergeWith(b);

        expect(merged.userNote, equals('my note'));
      });

      test('falls back to other userNote when this is null', () {
        final a = makeEntry();
        final b = makeEntry(userNote: 'imported note');

        final merged = a.mergeWith(b);

        expect(merged.userNote, equals('imported note'));
      });

      test('prefers this entry sigil when set', () {
        const sigilA = SigilData(
          vertices: 5,
          rotation: 1.0,
          innerRings: 2,
          drawRadials: true,
          centerDot: false,
          symmetryFold: 3,
          primaryColor: Color(0xFF0EA5E9),
          secondaryColor: Color(0xFF8B5CF6),
          tertiaryColor: Color(0xFFF97316),
        );
        const sigilB = SigilData(
          vertices: 7,
          rotation: 2.0,
          innerRings: 1,
          drawRadials: false,
          centerDot: true,
          symmetryFold: 5,
          primaryColor: Color(0xFFEF4444),
          secondaryColor: Color(0xFFFBBF24),
          tertiaryColor: Color(0xFF10B981),
        );

        final a = makeEntry(sigil: sigilA);
        final b = makeEntry(sigil: sigilB);

        final merged = a.mergeWith(b);

        expect(merged.sigil!.vertices, equals(5));
      });

      test('falls back to other sigil when this is null', () {
        const sigilB = SigilData(
          vertices: 7,
          rotation: 2.0,
          innerRings: 1,
          drawRadials: false,
          centerDot: true,
          symmetryFold: 5,
          primaryColor: Color(0xFFEF4444),
          secondaryColor: Color(0xFFFBBF24),
          tertiaryColor: Color(0xFF10B981),
        );

        final a = makeEntry();
        final b = makeEntry(sigil: sigilB);

        final merged = a.mergeWith(b);

        expect(merged.sigil, isNotNull);
        expect(merged.sigil!.vertices, equals(7));
      });
    });

    group('encounters merge', () {
      test('unions encounters from both entries', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);
        final t2 = DateTime(2024, 1, 1, 10, 10);
        final t3 = DateTime(2024, 1, 1, 10, 20);

        final a = makeEntry(
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        );
        final b = makeEntry(
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8), // duplicate
            EncounterRecord(timestamp: t3, snr: 12),
          ],
        );

        final merged = a.mergeWith(b);

        expect(merged.encounters.length, equals(3));
      });

      test('deduplicates encounters by timestamp', () {
        final t1 = DateTime(2024, 1, 1, 10, 0);

        final a = makeEntry(
          encounters: [EncounterRecord(timestamp: t1, snr: 5)],
        );
        final b = makeEntry(
          encounters: [EncounterRecord(timestamp: t1, snr: 5)],
        );

        final merged = a.mergeWith(b);

        expect(merged.encounters.length, equals(1));
      });

      test('sorts merged encounters chronologically', () {
        final t1 = DateTime(2024, 1, 1);
        final t3 = DateTime(2024, 3, 1);
        final t2 = DateTime(2024, 2, 1);

        final a = makeEntry(encounters: [EncounterRecord(timestamp: t3)]);
        final b = makeEntry(
          encounters: [
            EncounterRecord(timestamp: t1),
            EncounterRecord(timestamp: t2),
          ],
        );

        final merged = a.mergeWith(b);

        expect(merged.encounters.length, equals(3));
        expect(merged.encounters[0].timestamp, equals(t1));
        expect(merged.encounters[1].timestamp, equals(t2));
        expect(merged.encounters[2].timestamp, equals(t3));
      });

      test('caps at maxEncounterRecords', () {
        final aEncounters = List.generate(
          30,
          (i) => EncounterRecord(
            timestamp: DateTime(2024, 1, 1).add(Duration(minutes: i * 10)),
          ),
        );
        final bEncounters = List.generate(
          30,
          (i) => EncounterRecord(
            timestamp: DateTime(
              2024,
              1,
              1,
            ).add(Duration(minutes: (i + 30) * 10)),
          ),
        );

        final a = makeEntry(encounters: aEncounters);
        final b = makeEntry(encounters: bEncounters);

        final merged = a.mergeWith(b);

        expect(
          merged.encounters.length,
          equals(NodeDexEntry.maxEncounterRecords),
        );
        // Should keep the most recent ones
        expect(
          merged.encounters.last.timestamp,
          equals(bEncounters.last.timestamp),
        );
      });

      test('empty encounters on both sides produces empty list', () {
        final a = makeEntry();
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.encounters, isEmpty);
      });
    });

    group('regions merge', () {
      test('unions regions by regionId', () {
        final now = DateTime(2024, 6, 1);
        final a = makeEntry(
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: now,
              lastSeen: now,
              encounterCount: 1,
            ),
          ],
        );
        final b = makeEntry(
          seenRegions: [
            SeenRegion(
              regionId: 'r2',
              label: 'R2',
              firstSeen: now,
              lastSeen: now,
              encounterCount: 1,
            ),
          ],
        );

        final merged = a.mergeWith(b);

        expect(merged.seenRegions.length, equals(2));
        final ids = merged.seenRegions.map((r) => r.regionId).toSet();
        expect(ids, containsAll(['r1', 'r2']));
      });

      test('merges overlapping regions using SeenRegion.merge', () {
        final a = makeEntry(
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
          ],
        );
        final b = makeEntry(
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 8,
            ),
          ],
        );

        final merged = a.mergeWith(b);

        expect(merged.seenRegions.length, equals(1));
        final r = merged.seenRegions.first;
        expect(r.firstSeen, equals(DateTime(2024, 1, 1)));
        expect(r.lastSeen, equals(DateTime(2024, 6, 1)));
        expect(r.encounterCount, equals(8));
      });

      test('empty regions on both sides produces empty list', () {
        final a = makeEntry();
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.seenRegions, isEmpty);
      });
    });

    group('co-seen relationships merge', () {
      test('unions co-seen maps from both entries', () {
        final now = DateTime(2024, 6, 1);
        final a = makeEntry(
          coSeenNodes: {
            10: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
          },
        );
        final b = makeEntry(
          coSeenNodes: {
            20: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
          },
        );

        final merged = a.mergeWith(b);

        expect(merged.coSeenNodes.length, equals(2));
        expect(merged.coSeenNodes.containsKey(10), isTrue);
        expect(merged.coSeenNodes.containsKey(20), isTrue);
      });

      test(
        'merges overlapping co-seen edges using CoSeenRelationship.merge',
        () {
          final a = makeEntry(
            coSeenNodes: {
              10: CoSeenRelationship(
                count: 3,
                firstSeen: DateTime(2024, 3, 1),
                lastSeen: DateTime(2024, 6, 1),
                messageCount: 2,
              ),
            },
          );
          final b = makeEntry(
            coSeenNodes: {
              10: CoSeenRelationship(
                count: 8,
                firstSeen: DateTime(2024, 1, 1),
                lastSeen: DateTime(2024, 5, 1),
                messageCount: 7,
              ),
            },
          );

          final merged = a.mergeWith(b);

          expect(merged.coSeenNodes.length, equals(1));
          final rel = merged.coSeenNodes[10]!;
          expect(rel.count, equals(8));
          expect(rel.firstSeen, equals(DateTime(2024, 1, 1)));
          expect(rel.lastSeen, equals(DateTime(2024, 6, 1)));
          expect(rel.messageCount, equals(7));
        },
      );

      test('merges mixed disjoint and overlapping co-seen edges', () {
        final now = DateTime(2024, 6, 1);
        final a = makeEntry(
          coSeenNodes: {
            10: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
            20: CoSeenRelationship(
              count: 2,
              firstSeen: now,
              lastSeen: now,
              messageCount: 1,
            ),
          },
        );
        final b = makeEntry(
          coSeenNodes: {
            20: CoSeenRelationship(
              count: 10,
              firstSeen: now,
              lastSeen: now,
              messageCount: 3,
            ),
            30: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        );

        final merged = a.mergeWith(b);

        expect(merged.coSeenNodes.length, equals(3));
        expect(merged.coSeenNodes[10]!.count, equals(5));
        expect(merged.coSeenNodes[20]!.count, equals(10));
        expect(merged.coSeenNodes[20]!.messageCount, equals(3));
        expect(merged.coSeenNodes[30]!.count, equals(1));
      });

      test('empty co-seen maps on both sides produces empty map', () {
        final a = makeEntry();
        final b = makeEntry();

        final merged = a.mergeWith(b);

        expect(merged.coSeenNodes, isEmpty);
      });
    });

    group('symmetry and idempotency', () {
      test('merging with self produces equivalent entry', () {
        final now = DateTime(2024, 6, 1);
        final entry = makeEntry(
          encounterCount: 5,
          maxDistanceSeen: 2000.0,
          bestSnr: 10,
          bestRssi: -80,
          messageCount: 3,
          socialTag: NodeSocialTag.contact,
          userNote: 'test',
          encounters: [EncounterRecord(timestamp: now)],
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: now,
              lastSeen: now,
              encounterCount: 1,
            ),
          ],
          coSeenNodes: {
            10: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
          },
        );

        final merged = entry.mergeWith(entry);

        expect(merged.nodeNum, equals(entry.nodeNum));
        expect(merged.firstSeen, equals(entry.firstSeen));
        expect(merged.lastSeen, equals(entry.lastSeen));
        expect(merged.encounterCount, equals(entry.encounterCount));
        expect(merged.maxDistanceSeen, equals(entry.maxDistanceSeen));
        expect(merged.messageCount, equals(entry.messageCount));
        expect(merged.socialTag, equals(entry.socialTag));
        expect(merged.userNote, equals(entry.userNote));
        expect(merged.encounters.length, equals(1));
        expect(merged.seenRegions.length, equals(1));
        expect(merged.coSeenNodes.length, equals(1));
        expect(merged.coSeenNodes[10]!.count, equals(3));
      });

      test('scalar merges are symmetric', () {
        final a = makeEntry(
          firstSeen: DateTime(2024, 3, 1),
          lastSeen: DateTime(2024, 8, 1),
          encounterCount: 5,
          maxDistanceSeen: 1000.0,
          bestSnr: 10,
          bestRssi: -90,
          messageCount: 3,
        );
        final b = makeEntry(
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 12, 1),
          encounterCount: 15,
          maxDistanceSeen: 5000.0,
          bestSnr: 15,
          bestRssi: -70,
          messageCount: 10,
        );

        final ab = a.mergeWith(b);
        final ba = b.mergeWith(a);

        expect(ab.firstSeen, equals(ba.firstSeen));
        expect(ab.lastSeen, equals(ba.lastSeen));
        expect(ab.encounterCount, equals(ba.encounterCount));
        expect(ab.maxDistanceSeen, equals(ba.maxDistanceSeen));
        expect(ab.bestSnr, equals(ba.bestSnr));
        expect(ab.bestRssi, equals(ba.bestRssi));
        expect(ab.messageCount, equals(ba.messageCount));
      });

      test('co-seen merge is symmetric for counts and time ranges', () {
        final a = makeEntry(
          coSeenNodes: {
            10: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 8, 1),
              messageCount: 2,
            ),
          },
        );
        final b = makeEntry(
          coSeenNodes: {
            10: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              messageCount: 5,
            ),
          },
        );

        final ab = a.mergeWith(b);
        final ba = b.mergeWith(a);

        expect(ab.coSeenNodes[10]!.count, equals(ba.coSeenNodes[10]!.count));
        expect(
          ab.coSeenNodes[10]!.firstSeen,
          equals(ba.coSeenNodes[10]!.firstSeen),
        );
        expect(
          ab.coSeenNodes[10]!.lastSeen,
          equals(ba.coSeenNodes[10]!.lastSeen),
        );
        expect(
          ab.coSeenNodes[10]!.messageCount,
          equals(ba.coSeenNodes[10]!.messageCount),
        );
      });
    });

    group('serialization round-trip after merge', () {
      test('merged entry survives toJson -> fromJson', () {
        final a = makeEntry(
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700200000000),
          encounterCount: 5,
          maxDistanceSeen: 2000.0,
          bestSnr: 10,
          bestRssi: -85,
          messageCount: 3,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
          encounters: [
            EncounterRecord(
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              snr: 8,
            ),
          ],
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
              encounterCount: 3,
            ),
          ],
          coSeenNodes: {
            10: CoSeenRelationship(
              count: 5,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
              messageCount: 2,
            ),
          },
        );
        final b = makeEntry(
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1699900000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700300000000),
          encounterCount: 10,
          maxDistanceSeen: 5000.0,
          bestSnr: 15,
          bestRssi: -70,
          messageCount: 8,
          encounters: [
            EncounterRecord(
              timestamp: DateTime.fromMillisecondsSinceEpoch(1700150000000),
              snr: 12,
            ),
          ],
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'R1',
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1699900000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700200000000),
              encounterCount: 7,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'R2',
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700300000000),
              encounterCount: 2,
            ),
          ],
          coSeenNodes: {
            10: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1699900000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700200000000),
              messageCount: 5,
            ),
            20: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700300000000),
            ),
          },
        );

        final merged = a.mergeWith(b);
        final json = merged.toJson();
        final restored = NodeDexEntry.fromJson(json);

        expect(restored.nodeNum, equals(42));
        expect(
          restored.firstSeen,
          equals(DateTime.fromMillisecondsSinceEpoch(1699900000000)),
        );
        expect(
          restored.lastSeen,
          equals(DateTime.fromMillisecondsSinceEpoch(1700300000000)),
        );
        expect(restored.encounterCount, equals(10));
        expect(restored.maxDistanceSeen, equals(5000.0));
        expect(restored.bestSnr, equals(15));
        expect(restored.bestRssi, equals(-70));
        expect(restored.messageCount, equals(8));
        expect(restored.socialTag, equals(NodeSocialTag.contact));
        expect(restored.userNote, equals('local note'));
        expect(restored.encounters.length, equals(2));
        expect(restored.seenRegions.length, equals(2));
        expect(restored.coSeenNodes.length, equals(2));
        expect(restored.coSeenNodes[10]!.count, equals(8));
        expect(restored.coSeenNodes[10]!.messageCount, equals(5));
        expect(restored.coSeenNodes[20]!.count, equals(3));
      });
    });
  });

  // ===========================================================================
  // NodeDexStore import simulation (model-level)
  // ===========================================================================

  group('import merge simulation', () {
    test('v1 legacy entries merge correctly with v2 entries', () {
      // Simulate an existing v2 entry in local store
      final localJson = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        'ec': 10,
        'mc': 5,
        'csn': {
          '100': {
            'c': 5,
            'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
            'ls': DateTime(2024, 5, 1).millisecondsSinceEpoch,
            'mc': 2,
          },
        },
      };

      // Simulate a v1 legacy import file
      final importedJson = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2023, 11, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
        'ec': 8,
        'mc': 3,
        'csn': {
          '100': 7, // v1: plain int
          '200': 3, // v1: plain int, new edge
        },
      };

      final local = NodeDexEntry.fromJson(localJson);
      final imported = NodeDexEntry.fromJson(importedJson);

      final merged = local.mergeWith(imported);

      // Time range broadened
      expect(merged.firstSeen, equals(DateTime(2023, 11, 1)));
      expect(merged.lastSeen, equals(DateTime(2024, 6, 1)));

      // Scalar metrics take max
      expect(merged.encounterCount, equals(10));
      expect(merged.messageCount, equals(5));

      // Co-seen relationships merged
      expect(merged.coSeenNodes.length, equals(2));

      // Edge to node 100: local had count=5 with mc=2; imported had count=7
      final rel100 = merged.coSeenNodes[100]!;
      expect(rel100.count, equals(7));
      expect(rel100.messageCount, equals(2));

      // Edge to node 200: new from import, migrated from v1
      final rel200 = merged.coSeenNodes[200]!;
      expect(rel200.count, equals(3));
      expect(rel200.messageCount, equals(0));
    });

    test('multiple entries encode/decode/merge correctly', () {
      final entries1 = [
        NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          encounterCount: 5,
          messageCount: 2,
          coSeenNodes: {
            2: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700050000000),
              messageCount: 1,
            ),
          },
        ),
        NodeDexEntry(
          nodeNum: 2,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          encounterCount: 3,
        ),
      ];

      final entries2 = [
        NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1699900000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700200000000),
          encounterCount: 10,
          messageCount: 7,
          coSeenNodes: {
            2: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1699900000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700150000000),
              messageCount: 4,
            ),
            3: CoSeenRelationship(
              count: 2,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700050000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
            ),
          },
        ),
        NodeDexEntry(
          nodeNum: 3,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700050000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          encounterCount: 1,
        ),
      ];

      // Encode and decode both sets
      final encoded1 = NodeDexEntry.encodeList(entries1);
      final encoded2 = NodeDexEntry.encodeList(entries2);
      final decoded1 = NodeDexEntry.decodeList(encoded1);
      final decoded2 = NodeDexEntry.decodeList(encoded2);

      // Simulate import merge: local=decoded1, imported=decoded2
      final localMap = {for (final e in decoded1) e.nodeNum: e};
      int mergedCount = 0;
      for (final entry in decoded2) {
        final existing = localMap[entry.nodeNum];
        if (existing != null) {
          localMap[entry.nodeNum] = existing.mergeWith(entry);
        } else {
          localMap[entry.nodeNum] = entry;
        }
        mergedCount++;
      }

      expect(mergedCount, equals(2));
      expect(localMap.length, equals(3)); // nodes 1, 2, 3

      // Node 1 merged
      final node1 = localMap[1]!;
      expect(
        node1.firstSeen,
        equals(DateTime.fromMillisecondsSinceEpoch(1699900000000)),
      );
      expect(
        node1.lastSeen,
        equals(DateTime.fromMillisecondsSinceEpoch(1700200000000)),
      );
      expect(node1.encounterCount, equals(10));
      expect(node1.messageCount, equals(7));
      expect(node1.coSeenNodes.length, equals(2));
      expect(node1.coSeenNodes[2]!.count, equals(8));
      expect(node1.coSeenNodes[2]!.messageCount, equals(4));
      expect(node1.coSeenNodes[3]!.count, equals(2));

      // Node 2 unchanged (no imported version)
      final node2 = localMap[2]!;
      expect(node2.encounterCount, equals(3));

      // Node 3 added from import
      final node3 = localMap[3]!;
      expect(node3.encounterCount, equals(1));
    });

    test('import with empty local store adds all entries', () {
      final imported = [
        NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          encounterCount: 5,
          coSeenNodes: {
            2: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700050000000),
            ),
          },
        ),
      ];

      final localMap = <int, NodeDexEntry>{};
      for (final entry in imported) {
        final existing = localMap[entry.nodeNum];
        if (existing != null) {
          localMap[entry.nodeNum] = existing.mergeWith(entry);
        } else {
          localMap[entry.nodeNum] = entry;
        }
      }

      expect(localMap.length, equals(1));
      expect(localMap[1]!.coSeenNodes[2]!.count, equals(3));
    });

    test('import with mixed v1 and v2 csn values in same file', () {
      final json = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        'csn': {
          '100': 5, // v1
          '200': {
            'c': 3,
            'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
            'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
            'mc': 2,
          }, // v2
          '300': 1, // v1
        },
      };

      final entry = NodeDexEntry.fromJson(json);

      expect(entry.coSeenNodes.length, equals(3));
      expect(entry.coSeenNodes[100]!.count, equals(5));
      expect(entry.coSeenNodes[100]!.messageCount, equals(0));
      expect(entry.coSeenNodes[200]!.count, equals(3));
      expect(entry.coSeenNodes[200]!.messageCount, equals(2));
      expect(entry.coSeenNodes[300]!.count, equals(1));

      // Merged v1 entries should have entry's firstSeen as fallback
      expect(entry.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(entry.coSeenNodes[300]!.firstSeen, equals(DateTime(2024, 1, 1)));

      // v2 entry should have its own timestamps
      expect(entry.coSeenNodes[200]!.firstSeen, equals(DateTime(2024, 2, 1)));
    });
  });
}
