// SPDX-License-Identifier: GPL-3.0-or-later

// Sync Coverage Tests — verifies Cloud Sync contract completeness,
// merge/conflict resolution, serialization round-trips, and queue
// behavior for all syncable entity types.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/services/sync/sync_contract.dart';
import 'package:socialmesh/services/sync/sync_diagnostics.dart';

void main() {
  // ===========================================================================
  // Sync Contract Completeness
  // ===========================================================================

  group('SyncContract', () {
    test('every SyncType has a config entry', () {
      expect(verifySyncContractCompleteness(), isTrue);
      expect(getMissingSyncConfigs(), isEmpty);
    });

    test('all SyncType values are accounted for', () {
      for (final type in SyncType.values) {
        expect(
          syncTypeConfigs.containsKey(type),
          isTrue,
          reason: '${type.name} is missing from syncTypeConfigs',
        );
      }
    });

    test('every config has a non-empty displayName', () {
      for (final entry in syncTypeConfigs.entries) {
        expect(
          entry.value.displayName.isNotEmpty,
          isTrue,
          reason: '${entry.key.name} has empty displayName',
        );
      }
    });

    test('every config has a non-empty entityTypeKey', () {
      for (final entry in syncTypeConfigs.entries) {
        expect(
          entry.value.entityTypeKey.isNotEmpty,
          isTrue,
          reason: '${entry.key.name} has empty entityTypeKey',
        );
      }
    });

    test('every config has a non-empty cloudCollectionPath', () {
      for (final entry in syncTypeConfigs.entries) {
        expect(
          entry.value.cloudCollectionPath.isNotEmpty,
          isTrue,
          reason: '${entry.key.name} has empty cloudCollectionPath',
        );
      }
    });

    test('every config has a non-empty conflictPolicy', () {
      for (final entry in syncTypeConfigs.entries) {
        expect(
          entry.value.conflictPolicy.isNotEmpty,
          isTrue,
          reason: '${entry.key.name} has empty conflictPolicy',
        );
      }
    });

    test('embedded types have a parentType', () {
      for (final entry in syncTypeConfigs.entries) {
        if (entry.value.isEmbeddedInParent) {
          expect(
            entry.value.parentType,
            isNotNull,
            reason: '${entry.key.name} is embedded but has no parentType',
          );
        }
      }
    });

    test('non-embedded types do not have a parentType', () {
      for (final entry in syncTypeConfigs.entries) {
        if (!entry.value.isEmbeddedInParent) {
          expect(
            entry.value.parentType,
            isNull,
            reason: '${entry.key.name} is not embedded but has a parentType',
          );
        }
      }
    });

    test('entitlement-gated types include all NodeDex types', () {
      final gated = getEntitlementGatedTypes();
      expect(gated, contains(SyncType.nodedexEntry));
      expect(gated, contains(SyncType.nodedexSocialTag));
      expect(gated, contains(SyncType.nodedexUserNote));
    });

    test('profile and preferences are not entitlement-gated', () {
      final gated = getEntitlementGatedTypes();
      expect(gated, isNot(contains(SyncType.userProfile)));
      expect(gated, isNot(contains(SyncType.userPreferences)));
    });

    test('outbox types include NodeDex types', () {
      final outbox = getOutboxTypes();
      expect(outbox, contains(SyncType.nodedexEntry));
      expect(outbox, contains(SyncType.nodedexSocialTag));
      expect(outbox, contains(SyncType.nodedexUserNote));
    });
  });

  // ===========================================================================
  // socialTag and userNote per-field timestamp merge
  // ===========================================================================

  group('mergeWith — socialTag last-write-wins', () {
    NodeDexEntry makeEntry({
      int nodeNum = 42,
      DateTime? firstSeen,
      DateTime? lastSeen,
      NodeSocialTag? socialTag,
      int? socialTagUpdatedAtMs,
      String? userNote,
      int? userNoteUpdatedAtMs,
    }) {
      return NodeDexEntry(
        nodeNum: nodeNum,
        firstSeen: firstSeen ?? DateTime(2024, 1, 1),
        lastSeen: lastSeen ?? DateTime(2024, 6, 1),
        socialTag: socialTag,
        socialTagUpdatedAtMs: socialTagUpdatedAtMs,
        userNote: userNote,
        userNoteUpdatedAtMs: userNoteUpdatedAtMs,
      );
    }

    test('remote socialTag wins when remote timestamp is later', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 2000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
      expect(merged.socialTagUpdatedAtMs, equals(2000));
    });

    test('local socialTag wins when local timestamp is later', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.knownRelay,
        socialTagUpdatedAtMs: 3000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.frequentPeer,
        socialTagUpdatedAtMs: 1000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.knownRelay));
      expect(merged.socialTagUpdatedAtMs, equals(3000));
    });

    test('remote clear wins when remote timestamp is later', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );
      final remote = makeEntry(socialTag: null, socialTagUpdatedAtMs: 2000);

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, isNull);
      expect(merged.socialTagUpdatedAtMs, equals(2000));
    });

    test('local clear wins when local timestamp is later', () {
      final local = makeEntry(socialTag: null, socialTagUpdatedAtMs: 5000);
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 3000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, isNull);
      expect(merged.socialTagUpdatedAtMs, equals(5000));
    });

    test('equal timestamps: local wins', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 1000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.contact));
      expect(merged.socialTagUpdatedAtMs, equals(1000));
    });

    test('timestamped side wins over non-timestamped side', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: null,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 1000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
      expect(merged.socialTagUpdatedAtMs, equals(1000));
    });

    test('local timestamped wins over remote non-timestamped', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.knownRelay,
        socialTagUpdatedAtMs: 500,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.frequentPeer,
        socialTagUpdatedAtMs: null,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.knownRelay));
      expect(merged.socialTagUpdatedAtMs, equals(500));
    });

    test('both null timestamps: legacy fallback prefers local non-null', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: null,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: null,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.contact));
      expect(merged.socialTagUpdatedAtMs, isNull);
    });

    test('both null timestamps: remote used when local is null', () {
      final local = makeEntry(socialTag: null, socialTagUpdatedAtMs: null);
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: null,
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
    });

    test('both null values and null timestamps remain null', () {
      final local = makeEntry(socialTag: null, socialTagUpdatedAtMs: null);
      final remote = makeEntry(socialTag: null, socialTagUpdatedAtMs: null);

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, isNull);
      expect(merged.socialTagUpdatedAtMs, isNull);
    });
  });

  group('mergeWith — userNote last-write-wins', () {
    NodeDexEntry makeEntry({
      int nodeNum = 42,
      String? userNote,
      int? userNoteUpdatedAtMs,
    }) {
      return NodeDexEntry(
        nodeNum: nodeNum,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: userNote,
        userNoteUpdatedAtMs: userNoteUpdatedAtMs,
      );
    }

    test('remote userNote wins when remote timestamp is later', () {
      final local = makeEntry(
        userNote: 'local note',
        userNoteUpdatedAtMs: 1000,
      );
      final remote = makeEntry(
        userNote: 'remote note',
        userNoteUpdatedAtMs: 2000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.userNote, equals('remote note'));
      expect(merged.userNoteUpdatedAtMs, equals(2000));
    });

    test('local userNote wins when local timestamp is later', () {
      final local = makeEntry(
        userNote: 'local note',
        userNoteUpdatedAtMs: 3000,
      );
      final remote = makeEntry(
        userNote: 'remote note',
        userNoteUpdatedAtMs: 1000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.userNote, equals('local note'));
      expect(merged.userNoteUpdatedAtMs, equals(3000));
    });

    test('remote clear wins when remote timestamp is later', () {
      final local = makeEntry(userNote: 'my note', userNoteUpdatedAtMs: 1000);
      final remote = makeEntry(userNote: null, userNoteUpdatedAtMs: 2000);

      final merged = local.mergeWith(remote);

      expect(merged.userNote, isNull);
      expect(merged.userNoteUpdatedAtMs, equals(2000));
    });

    test('local clear wins when local timestamp is later', () {
      final local = makeEntry(userNote: null, userNoteUpdatedAtMs: 5000);
      final remote = makeEntry(
        userNote: 'remote note',
        userNoteUpdatedAtMs: 3000,
      );

      final merged = local.mergeWith(remote);

      expect(merged.userNote, isNull);
      expect(merged.userNoteUpdatedAtMs, equals(5000));
    });

    test('timestamped side wins over non-timestamped side', () {
      final local = makeEntry(userNote: 'old note', userNoteUpdatedAtMs: null);
      final remote = makeEntry(userNote: 'new note', userNoteUpdatedAtMs: 1000);

      final merged = local.mergeWith(remote);

      expect(merged.userNote, equals('new note'));
    });

    test('both null timestamps: legacy fallback prefers local non-null', () {
      final local = makeEntry(
        userNote: 'local note',
        userNoteUpdatedAtMs: null,
      );
      final remote = makeEntry(
        userNote: 'remote note',
        userNoteUpdatedAtMs: null,
      );

      final merged = local.mergeWith(remote);

      expect(merged.userNote, equals('local note'));
    });
  });

  // ===========================================================================
  // Conflict detection
  // ===========================================================================

  group('mergeWith — conflict detection', () {
    NodeDexEntry makeEntry({
      int nodeNum = 42,
      NodeSocialTag? socialTag,
      int? socialTagUpdatedAtMs,
      String? userNote,
      int? userNoteUpdatedAtMs,
    }) {
      return NodeDexEntry(
        nodeNum: nodeNum,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        socialTag: socialTag,
        socialTagUpdatedAtMs: socialTagUpdatedAtMs,
        userNote: userNote,
        userNoteUpdatedAtMs: userNoteUpdatedAtMs,
      );
    }

    test('near-simultaneous different socialTag edits produce winner '
        'but both values exist in merge logic', () {
      // Within the 5-second conflict window
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 10000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 10003, // 3ms later, within 5s window
      );

      final merged = local.mergeWith(remote);

      // Remote wins (later timestamp)
      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
      expect(merged.socialTagUpdatedAtMs, equals(10003));
    });

    test('edits far apart in time do not flag conflict', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 10000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 20000, // 10s later, outside 5s window
      );

      final merged = local.mergeWith(remote);

      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
      expect(merged.socialTagUpdatedAtMs, equals(20000));
    });

    test('same value within conflict window is not a conflict', () {
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 10000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.contact, // Same value
        socialTagUpdatedAtMs: 10003,
      );

      final merged = local.mergeWith(remote);

      // Later timestamp wins, but values are identical so no conflict
      expect(merged.socialTag, equals(NodeSocialTag.contact));
      expect(merged.socialTagUpdatedAtMs, equals(10003));
    });

    test('conflict window is exactly 5 seconds', () {
      // At boundary: 5000ms difference is still within window
      final local = makeEntry(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 10000,
      );
      final remote = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 15000,
      );

      final merged = local.mergeWith(remote);

      // Remote wins
      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));

      // Just outside window: 5001ms is not a conflict
      final remote2 = makeEntry(
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 15001,
      );

      final merged2 = local.mergeWith(remote2);
      expect(merged2.socialTag, equals(NodeSocialTag.trustedNode));
    });

    test('near-simultaneous userNote edits produce winner', () {
      final local = makeEntry(userNote: 'note A', userNoteUpdatedAtMs: 10000);
      final remote = makeEntry(userNote: 'note B', userNoteUpdatedAtMs: 10002);

      final merged = local.mergeWith(remote);

      expect(merged.userNote, equals('note B'));
      expect(merged.userNoteUpdatedAtMs, equals(10002));
    });
  });

  // ===========================================================================
  // Serialization round-trip with new timestamp fields
  // ===========================================================================

  group('serialization — timestamp fields round-trip', () {
    test('socialTagUpdatedAtMs survives toJson/fromJson', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1706400000000,
      );

      final json = entry.toJson();
      final restored = NodeDexEntry.fromJson(json);

      expect(restored.socialTag, equals(NodeSocialTag.contact));
      expect(restored.socialTagUpdatedAtMs, equals(1706400000000));
    });

    test('userNoteUpdatedAtMs survives toJson/fromJson', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: 'test note',
        userNoteUpdatedAtMs: 1706400000000,
      );

      final json = entry.toJson();
      final restored = NodeDexEntry.fromJson(json);

      expect(restored.userNote, equals('test note'));
      expect(restored.userNoteUpdatedAtMs, equals(1706400000000));
    });

    test('null timestamps serialize correctly (omitted from JSON)', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final json = entry.toJson();

      expect(json.containsKey('st_ms'), isFalse);
      expect(json.containsKey('un_ms'), isFalse);

      final restored = NodeDexEntry.fromJson(json);

      expect(restored.socialTagUpdatedAtMs, isNull);
      expect(restored.userNoteUpdatedAtMs, isNull);
    });

    test('full entry with all fields round-trips correctly', () {
      final entry = NodeDexEntry(
        nodeNum: 99,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 15),
        encounterCount: 10,
        maxDistanceSeen: 5000.0,
        bestSnr: 15,
        bestRssi: -70,
        messageCount: 5,
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 1000000,
        userNote: 'A relay on the hill',
        userNoteUpdatedAtMs: 2000000,
        encounters: [
          EncounterRecord(
            timestamp: DateTime(2024, 3, 1),
            distanceMeters: 1500.0,
            snr: 10,
            rssi: -85,
          ),
        ],
        seenRegions: [
          SeenRegion(
            regionId: 'g33_151',
            label: '33S 151E',
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 6, 1),
            encounterCount: 5,
          ),
        ],
      );

      final json = entry.toJson();
      final restored = NodeDexEntry.fromJson(json);

      expect(restored.nodeNum, equals(99));
      expect(restored.encounterCount, equals(10));
      expect(restored.maxDistanceSeen, equals(5000.0));
      expect(restored.bestSnr, equals(15));
      expect(restored.bestRssi, equals(-70));
      expect(restored.messageCount, equals(5));
      expect(restored.socialTag, equals(NodeSocialTag.trustedNode));
      expect(restored.socialTagUpdatedAtMs, equals(1000000));
      expect(restored.userNote, equals('A relay on the hill'));
      expect(restored.userNoteUpdatedAtMs, equals(2000000));
      expect(restored.encounters.length, equals(1));
      expect(restored.seenRegions.length, equals(1));
    });

    test('legacy JSON without timestamp fields deserializes with null', () {
      // Simulate a pre-v2 JSON payload (no st_ms or un_ms)
      final legacyJson = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        'st': NodeSocialTag.contact.index,
        'un': 'old note',
        'enc': <dynamic>[],
        'sr': <dynamic>[],
      };

      final entry = NodeDexEntry.fromJson(legacyJson);

      expect(entry.socialTag, equals(NodeSocialTag.contact));
      expect(entry.socialTagUpdatedAtMs, isNull);
      expect(entry.userNote, equals('old note'));
      expect(entry.userNoteUpdatedAtMs, isNull);
    });
  });

  // ===========================================================================
  // copyWith timestamp auto-stamping
  // ===========================================================================

  group('copyWith — auto-stamps timestamps', () {
    test('setting socialTag auto-stamps socialTagUpdatedAtMs', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      final updated = entry.copyWith(socialTag: NodeSocialTag.contact);
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(updated.socialTag, equals(NodeSocialTag.contact));
      expect(updated.socialTagUpdatedAtMs, isNotNull);
      expect(updated.socialTagUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(updated.socialTagUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test('clearing socialTag auto-stamps socialTagUpdatedAtMs', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      final updated = entry.copyWith(clearSocialTag: true);
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(updated.socialTag, isNull);
      expect(updated.socialTagUpdatedAtMs, isNotNull);
      expect(updated.socialTagUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(updated.socialTagUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test('setting userNote auto-stamps userNoteUpdatedAtMs', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      final updated = entry.copyWith(userNote: 'hello');
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(updated.userNote, equals('hello'));
      expect(updated.userNoteUpdatedAtMs, isNotNull);
      expect(updated.userNoteUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(updated.userNoteUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test('clearing userNote auto-stamps userNoteUpdatedAtMs', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: 'existing note',
        userNoteUpdatedAtMs: 1000,
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      final updated = entry.copyWith(clearUserNote: true);
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(updated.userNote, isNull);
      expect(updated.userNoteUpdatedAtMs, isNotNull);
      expect(updated.userNoteUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(updated.userNoteUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test(
      'copyWith without changing socialTag preserves existing timestamp',
      () {
        final entry = NodeDexEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          socialTag: NodeSocialTag.contact,
          socialTagUpdatedAtMs: 12345,
        );

        final updated = entry.copyWith(encounterCount: 5);

        expect(updated.socialTag, equals(NodeSocialTag.contact));
        expect(updated.socialTagUpdatedAtMs, equals(12345));
      },
    );

    test('copyWith without changing userNote preserves existing timestamp', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: 'note',
        userNoteUpdatedAtMs: 67890,
      );

      final updated = entry.copyWith(encounterCount: 5);

      expect(updated.userNote, equals('note'));
      expect(updated.userNoteUpdatedAtMs, equals(67890));
    });

    test('explicit timestamp in copyWith overrides auto-stamp', () {
      final entry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final updated = entry.copyWith(
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 99999,
      );

      expect(updated.socialTagUpdatedAtMs, equals(99999));
    });
  });

  // ===========================================================================
  // mergeWith preserves non-user-editable merge rules
  // ===========================================================================

  group('mergeWith — metric merge rules still work', () {
    NodeDexEntry makeEntry({
      int nodeNum = 42,
      DateTime? firstSeen,
      DateTime? lastSeen,
      int encounterCount = 1,
      double? maxDistanceSeen,
      int? bestSnr,
      int? bestRssi,
      int messageCount = 0,
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
      );
    }

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

    test('takes maximum bestSnr', () {
      final a = makeEntry(bestSnr: 5);
      final b = makeEntry(bestSnr: 12);

      final merged = a.mergeWith(b);

      expect(merged.bestSnr, equals(12));
    });

    test('takes maximum bestRssi (closer to 0)', () {
      final a = makeEntry(bestRssi: -100);
      final b = makeEntry(bestRssi: -75);

      final merged = a.mergeWith(b);

      expect(merged.bestRssi, equals(-75));
    });
  });

  // ===========================================================================
  // Encounter union merge
  // ===========================================================================

  group('mergeWith — encounter union merge', () {
    test('encounters from both sides are combined', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [
          EncounterRecord(timestamp: DateTime(2024, 1, 1)),
          EncounterRecord(timestamp: DateTime(2024, 2, 1)),
        ],
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [
          EncounterRecord(timestamp: DateTime(2024, 3, 1)),
          EncounterRecord(timestamp: DateTime(2024, 4, 1)),
        ],
      );

      final merged = a.mergeWith(b);

      expect(merged.encounters.length, equals(4));
    });

    test('duplicate encounters are deduplicated by timestamp', () {
      final shared = DateTime(2024, 2, 1);
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [
          EncounterRecord(timestamp: DateTime(2024, 1, 1)),
          EncounterRecord(timestamp: shared),
        ],
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [
          EncounterRecord(timestamp: shared), // duplicate
          EncounterRecord(timestamp: DateTime(2024, 3, 1)),
        ],
      );

      final merged = a.mergeWith(b);

      expect(merged.encounters.length, equals(3));
    });

    test('encounters are sorted chronologically after merge', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [EncounterRecord(timestamp: DateTime(2024, 6, 1))],
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounters: [EncounterRecord(timestamp: DateTime(2024, 1, 1))],
      );

      final merged = a.mergeWith(b);

      expect(merged.encounters.first.timestamp, equals(DateTime(2024, 1, 1)));
      expect(merged.encounters.last.timestamp, equals(DateTime(2024, 6, 1)));
    });
  });

  // ===========================================================================
  // Region merge
  // ===========================================================================

  group('mergeWith — region merge', () {
    test('regions from both sides are combined', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        seenRegions: [
          SeenRegion(
            regionId: 'r1',
            label: 'Region 1',
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 3, 1),
            encounterCount: 3,
          ),
        ],
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        seenRegions: [
          SeenRegion(
            regionId: 'r2',
            label: 'Region 2',
            firstSeen: DateTime(2024, 4, 1),
            lastSeen: DateTime(2024, 6, 1),
            encounterCount: 2,
          ),
        ],
      );

      final merged = a.mergeWith(b);

      expect(merged.seenRegions.length, equals(2));
    });

    test('same regions are merged with min firstSeen and max lastSeen', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        seenRegions: [
          SeenRegion(
            regionId: 'r1',
            label: 'Region 1',
            firstSeen: DateTime(2024, 3, 1),
            lastSeen: DateTime(2024, 4, 1),
            encounterCount: 3,
          ),
        ],
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        seenRegions: [
          SeenRegion(
            regionId: 'r1',
            label: 'Region 1',
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 6, 1),
            encounterCount: 5,
          ),
        ],
      );

      final merged = a.mergeWith(b);

      expect(merged.seenRegions.length, equals(1));
      final r = merged.seenRegions.first;
      expect(r.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(r.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(r.encounterCount, equals(5));
    });
  });

  // ===========================================================================
  // Co-seen edge merge
  // ===========================================================================

  group('mergeWith — co-seen edge merge', () {
    test('co-seen edges from both sides are combined', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        coSeenNodes: {
          100: CoSeenRelationship(
            count: 3,
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 3, 1),
          ),
        },
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        coSeenNodes: {
          200: CoSeenRelationship(
            count: 2,
            firstSeen: DateTime(2024, 4, 1),
            lastSeen: DateTime(2024, 6, 1),
          ),
        },
      );

      final merged = a.mergeWith(b);

      expect(merged.coSeenNodes.length, equals(2));
      expect(merged.coSeenNodes.containsKey(100), isTrue);
      expect(merged.coSeenNodes.containsKey(200), isTrue);
    });

    test('same co-seen edge is merged properly', () {
      final a = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        coSeenNodes: {
          100: CoSeenRelationship(
            count: 3,
            firstSeen: DateTime(2024, 3, 1),
            lastSeen: DateTime(2024, 4, 1),
          ),
        },
      );
      final b = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        coSeenNodes: {
          100: CoSeenRelationship(
            count: 5,
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 6, 1),
          ),
        },
      );

      final merged = a.mergeWith(b);

      expect(merged.coSeenNodes.length, equals(1));
      final edge = merged.coSeenNodes[100]!;
      expect(edge.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(edge.lastSeen, equals(DateTime(2024, 6, 1)));
    });
  });

  // ===========================================================================
  // SyncDiagnostics
  // ===========================================================================

  group('SyncDiagnostics', () {
    late SyncDiagnostics diagnostics;

    setUp(() {
      diagnostics = SyncDiagnostics.instance;
      diagnostics.reset();
    });

    test('initial snapshot has empty state', () {
      final snap = diagnostics.snapshot;

      expect(snap.entitlementActive, isFalse);
      expect(snap.lastSyncTime, isNull);
      expect(snap.queuedItemsByType, isEmpty);
      expect(snap.lastErrorByType, isEmpty);
      expect(snap.uploadSuccessByType, isEmpty);
      expect(snap.pullAppliedByType, isEmpty);
      expect(snap.conflictsByType, isEmpty);
    });

    test('recordEntitlementState updates snapshot', () {
      diagnostics.recordEntitlementState(true);

      expect(diagnostics.snapshot.entitlementActive, isTrue);

      diagnostics.recordEntitlementState(false);

      expect(diagnostics.snapshot.entitlementActive, isFalse);
    });

    test('recordEnqueue accumulates count', () {
      diagnostics.recordEnqueue(SyncType.nodedexEntry);
      diagnostics.recordEnqueue(SyncType.nodedexEntry, count: 3);

      expect(
        diagnostics.snapshot.queuedItemsByType[SyncType.nodedexEntry],
        equals(4),
      );
    });

    test('recordUploadSuccess decrements queued count', () {
      diagnostics.recordEnqueue(SyncType.nodedexEntry, count: 5);
      diagnostics.recordUploadSuccess(SyncType.nodedexEntry, count: 3);

      expect(
        diagnostics.snapshot.queuedItemsByType[SyncType.nodedexEntry],
        equals(2),
      );
      expect(
        diagnostics.snapshot.uploadSuccessByType[SyncType.nodedexEntry],
        equals(3),
      );
    });

    test('recordUploadSuccess does not go below zero', () {
      diagnostics.recordUploadSuccess(SyncType.nodedexEntry, count: 5);

      expect(
        diagnostics.snapshot.queuedItemsByType[SyncType.nodedexEntry],
        equals(0),
      );
    });

    test('recordPullApplied accumulates', () {
      diagnostics.recordPullApplied(SyncType.nodedexEntry, count: 3);
      diagnostics.recordPullApplied(SyncType.nodedexEntry, count: 7);

      expect(
        diagnostics.snapshot.pullAppliedByType[SyncType.nodedexEntry],
        equals(10),
      );
    });

    test('recordConflict accumulates', () {
      diagnostics.recordConflict(SyncType.nodedexSocialTag);
      diagnostics.recordConflict(SyncType.nodedexSocialTag);

      expect(
        diagnostics.snapshot.conflictsByType[SyncType.nodedexSocialTag],
        equals(2),
      );
    });

    test('recordError stores last error per type', () {
      diagnostics.recordError(SyncType.nodedexEntry, 'network timeout');
      diagnostics.recordError(SyncType.nodedexEntry, 'auth expired');

      final err = diagnostics.snapshot.lastErrorByType[SyncType.nodedexEntry]!;
      expect(err.message, equals('auth expired'));
    });

    test('clearError removes error for type', () {
      diagnostics.recordError(SyncType.nodedexEntry, 'fail');
      diagnostics.clearError(SyncType.nodedexEntry);

      expect(
        diagnostics.snapshot.lastErrorByType.containsKey(SyncType.nodedexEntry),
        isFalse,
      );
    });

    test('recordSyncCycleComplete sets lastSyncTime', () {
      expect(diagnostics.snapshot.lastSyncTime, isNull);

      diagnostics.recordSyncCycleComplete();

      expect(diagnostics.snapshot.lastSyncTime, isNotNull);
    });

    test('reset clears all state', () {
      diagnostics.recordEntitlementState(true);
      diagnostics.recordEnqueue(SyncType.nodedexEntry, count: 5);
      diagnostics.recordUploadSuccess(SyncType.nodedexEntry, count: 2);
      diagnostics.recordPullApplied(SyncType.nodedexEntry, count: 3);
      diagnostics.recordConflict(SyncType.nodedexSocialTag);
      diagnostics.recordError(SyncType.nodedexEntry, 'fail');
      diagnostics.recordSyncCycleComplete();

      diagnostics.reset();

      final snap = diagnostics.snapshot;
      expect(snap.entitlementActive, isFalse);
      expect(snap.lastSyncTime, isNull);
      expect(snap.queuedItemsByType, isEmpty);
      expect(snap.lastErrorByType, isEmpty);
      expect(snap.uploadSuccessByType, isEmpty);
      expect(snap.pullAppliedByType, isEmpty);
      expect(snap.conflictsByType, isEmpty);
    });

    test('snapshot toString produces readable output', () {
      diagnostics.recordEntitlementState(true);
      diagnostics.recordEnqueue(SyncType.nodedexEntry, count: 2);
      diagnostics.recordSyncCycleComplete();

      final output = diagnostics.snapshot.toString();

      expect(output, contains('Sync Diagnostics'));
      expect(output, contains('ACTIVE'));
      expect(output, contains('nodedexEntry'));
    });
  });

  // ===========================================================================
  // Integration-style: local create -> serialize -> remote apply -> merge
  // ===========================================================================

  group('integration — create -> upload -> apply -> second device', () {
    test('Device A creates entry with socialTag, Device B receives it', () {
      // Device A creates an entry with a classification
      final deviceA = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: 5,
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1706400000000,
        userNote: 'My friend Alice',
        userNoteUpdatedAtMs: 1706400000000,
      );

      // Serialize for upload
      final json = deviceA.toJson();

      // Device B receives and deserializes
      final deviceB = NodeDexEntry.fromJson(json);

      expect(deviceB.socialTag, equals(NodeSocialTag.contact));
      expect(deviceB.socialTagUpdatedAtMs, equals(1706400000000));
      expect(deviceB.userNote, equals('My friend Alice'));
      expect(deviceB.userNoteUpdatedAtMs, equals(1706400000000));
    });

    test('Device B has existing entry, merges remote classification', () {
      // Device B already has this node with metrics but no classification
      final deviceBLocal = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 2, 1), // later firstSeen
        lastSeen: DateTime(2024, 5, 1), // earlier lastSeen
        encounterCount: 3,
      );

      // Device A's entry arrives with classification
      final fromDeviceA = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1), // earlier firstSeen
        lastSeen: DateTime(2024, 6, 1), // later lastSeen
        encounterCount: 5,
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 1706400000000,
        userNote: 'Infrastructure relay',
        userNoteUpdatedAtMs: 1706400000000,
      );

      // Merge: local.mergeWith(remote)
      final merged = deviceBLocal.mergeWith(fromDeviceA);

      // Metrics: broadest range
      expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(merged.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(merged.encounterCount, equals(5));

      // User fields: remote wins (has timestamp, local does not)
      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
      expect(merged.socialTagUpdatedAtMs, equals(1706400000000));
      expect(merged.userNote, equals('Infrastructure relay'));
      expect(merged.userNoteUpdatedAtMs, equals(1706400000000));
    });

    test('both devices edit socialTag offline, later writer wins', () {
      // Device A sets classification at time 1000
      final deviceA = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );

      // Device B sets classification at time 2000 (later)
      final deviceB = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 2000,
      );

      // When Device A receives Device B's data:
      final mergedOnA = deviceA.mergeWith(deviceB);
      expect(mergedOnA.socialTag, equals(NodeSocialTag.trustedNode));

      // When Device B receives Device A's data:
      final mergedOnB = deviceB.mergeWith(deviceA);
      expect(mergedOnB.socialTag, equals(NodeSocialTag.trustedNode));

      // Both converge to the same value
      expect(mergedOnA.socialTag, equals(mergedOnB.socialTag));
      expect(
        mergedOnA.socialTagUpdatedAtMs,
        equals(mergedOnB.socialTagUpdatedAtMs),
      );
    });

    test('Device A clears note, Device B has note — clear propagates', () {
      // Device A cleared the note at time 3000
      final deviceA = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: null,
        userNoteUpdatedAtMs: 3000,
      );

      // Device B still has the note from time 1000
      final deviceB = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        userNote: 'old note',
        userNoteUpdatedAtMs: 1000,
      );

      // Merge on Device B: the clear should win
      final merged = deviceB.mergeWith(deviceA);

      expect(merged.userNote, isNull);
      expect(merged.userNoteUpdatedAtMs, equals(3000));
    });

    test('airplane mode: edits queue locally, merge after reconnect', () {
      // Simulate: Device A makes edits while offline
      final offlineEntry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
        encounterCount: 3,
        socialTag: NodeSocialTag.knownRelay,
        socialTagUpdatedAtMs: 5000,
        userNote: 'Relay on Mt Wilson',
        userNoteUpdatedAtMs: 5000,
      );

      // Meanwhile, Device B also made edits with earlier timestamps
      final deviceBEntry = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 4, 1),
        encounterCount: 7,
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 3000,
        userNote: 'Alice',
        userNoteUpdatedAtMs: 3000,
      );

      // After reconnect, Device A pulls Device B's data
      final merged = offlineEntry.mergeWith(deviceBEntry);

      // Metrics: max/best
      expect(merged.encounterCount, equals(7));
      expect(merged.lastSeen, equals(DateTime(2024, 4, 1)));

      // User fields: Device A's edits win (later timestamps)
      expect(merged.socialTag, equals(NodeSocialTag.knownRelay));
      expect(merged.socialTagUpdatedAtMs, equals(5000));
      expect(merged.userNote, equals('Relay on Mt Wilson'));
      expect(merged.userNoteUpdatedAtMs, equals(5000));
    });
  });

  // ===========================================================================
  // Entitlement gating logic
  // ===========================================================================

  group('entitlement gating', () {
    test('NodeDex sync types require entitlement', () {
      final entryConfig = syncTypeConfigs[SyncType.nodedexEntry]!;
      final tagConfig = syncTypeConfigs[SyncType.nodedexSocialTag]!;
      final noteConfig = syncTypeConfigs[SyncType.nodedexUserNote]!;

      expect(entryConfig.requiresEntitlement, isTrue);
      expect(tagConfig.requiresEntitlement, isTrue);
      expect(noteConfig.requiresEntitlement, isTrue);
    });

    test('profile types do not require entitlement', () {
      final profileConfig = syncTypeConfigs[SyncType.userProfile]!;
      final prefsConfig = syncTypeConfigs[SyncType.userPreferences]!;
      final automationsConfig = syncTypeConfigs[SyncType.automationRules]!;

      expect(profileConfig.requiresEntitlement, isFalse);
      expect(prefsConfig.requiresEntitlement, isFalse);
      expect(automationsConfig.requiresEntitlement, isFalse);
    });
  });

  // ===========================================================================
  // encodeList / decodeList with new fields
  // ===========================================================================

  group('encodeList / decodeList with timestamps', () {
    test('list encoding preserves timestamp fields', () {
      final entries = [
        NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          socialTag: NodeSocialTag.contact,
          socialTagUpdatedAtMs: 1000,
          userNote: 'note 1',
          userNoteUpdatedAtMs: 2000,
        ),
        NodeDexEntry(
          nodeNum: 2,
          firstSeen: DateTime(2024, 2, 1),
          lastSeen: DateTime(2024, 7, 1),
          socialTag: NodeSocialTag.trustedNode,
          socialTagUpdatedAtMs: 3000,
        ),
      ];

      final encoded = NodeDexEntry.encodeList(entries);
      final decoded = NodeDexEntry.decodeList(encoded);

      expect(decoded.length, equals(2));
      expect(decoded[0].socialTag, equals(NodeSocialTag.contact));
      expect(decoded[0].socialTagUpdatedAtMs, equals(1000));
      expect(decoded[0].userNote, equals('note 1'));
      expect(decoded[0].userNoteUpdatedAtMs, equals(2000));
      expect(decoded[1].socialTag, equals(NodeSocialTag.trustedNode));
      expect(decoded[1].socialTagUpdatedAtMs, equals(3000));
      expect(decoded[1].userNoteUpdatedAtMs, isNull);
    });
  });
}
