// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/import_preview.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';

void main() {
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

  // ===========================================================================
  // ImportPreview.build() — basic structure
  // ===========================================================================

  group('ImportPreview.build() — basic structure', () {
    test('empty imported list produces empty preview', () {
      final preview = ImportPreview.build(
        importedEntries: [],
        localEntries: {},
      );

      expect(preview.isEmpty, isTrue);
      expect(preview.totalImported, equals(0));
      expect(preview.entries, isEmpty);
      expect(preview.hasChanges, isFalse);
      expect(preview.hasConflicts, isFalse);
    });

    test('totalImported matches input length', () {
      final imported = [
        makeEntry(nodeNum: 1),
        makeEntry(nodeNum: 2),
        makeEntry(nodeNum: 3),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.totalImported, equals(3));
      expect(preview.entries.length, equals(3));
    });

    test('all new entries are classified as new', () {
      final imported = [makeEntry(nodeNum: 10), makeEntry(nodeNum: 20)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.newEntryCount, equals(2));
      expect(preview.mergeEntryCount, equals(0));
      expect(preview.conflictCount, equals(0));
      for (final entry in preview.entries) {
        expect(entry.isNew, isTrue);
        expect(entry.localEntry, isNull);
        expect(entry.hasConflicts, isFalse);
      }
    });

    test('existing entries are classified as merge candidates', () {
      final local = {10: makeEntry(nodeNum: 10), 20: makeEntry(nodeNum: 20)};
      final imported = [makeEntry(nodeNum: 10), makeEntry(nodeNum: 20)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.newEntryCount, equals(0));
      expect(preview.mergeEntryCount, equals(2));
      for (final entry in preview.entries) {
        expect(entry.isNew, isFalse);
        expect(entry.localEntry, isNotNull);
      }
    });

    test('mixed new and existing entries are classified correctly', () {
      final local = {10: makeEntry(nodeNum: 10)};
      final imported = [
        makeEntry(nodeNum: 10), // existing
        makeEntry(nodeNum: 20), // new
        makeEntry(nodeNum: 30), // new
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.totalImported, equals(3));
      expect(preview.newEntryCount, equals(2));
      expect(preview.mergeEntryCount, equals(1));
    });

    test('hasChanges is true when there are entries to process', () {
      final imported = [makeEntry(nodeNum: 1)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.hasChanges, isTrue);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — display name resolution
  // ===========================================================================

  group('ImportPreview.build() — display names', () {
    test('uses displayNameResolver when provided', () {
      final imported = [makeEntry(nodeNum: 0xABCD)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
        displayNameResolver: (nodeNum) => 'Custom Name $nodeNum',
      );

      expect(preview.entries.first.displayName, equals('Custom Name 43981'));
    });

    test('falls back to hex ID when no resolver provided', () {
      final imported = [makeEntry(nodeNum: 0x00FF)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.displayName, equals('Node 00FF'));
    });

    test('hex ID is padded to 4 characters', () {
      final imported = [makeEntry(nodeNum: 0x0A)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.displayName, equals('Node 000A'));
    });

    test('large node numbers use full hex without extra padding', () {
      final imported = [makeEntry(nodeNum: 0xABCDE)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.displayName, equals('Node ABCDE'));
    });
  });

  // ===========================================================================
  // ImportPreview.build() — socialTag conflict detection
  // ===========================================================================

  group('ImportPreview.build() — socialTag conflicts', () {
    test(
      'detects conflict when both local and imported have different tags',
      () {
        final local = {
          42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
        };
        final imported = [
          makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
        ];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final entry = preview.entries.first;
        expect(entry.hasConflicts, isTrue);
        expect(entry.socialTagConflict, isNotNull);
        expect(
          entry.socialTagConflict!.localValue,
          equals(NodeSocialTag.contact),
        );
        expect(
          entry.socialTagConflict!.importedValue,
          equals(NodeSocialTag.trustedNode),
        );
      },
    );

    test('no conflict when both have the same tag', () {
      final local = {
        42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      };
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.socialTagConflict, isNull);
    });

    test('no conflict when local has tag but import does not', () {
      final local = {
        42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      };
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.socialTagConflict, isNull);
    });

    test('no conflict when import has tag but local does not', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.socialTagConflict, isNull);
    });

    test('no conflict when both tags are null', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.socialTagConflict, isNull);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — userNote conflict detection
  // ===========================================================================

  group('ImportPreview.build() — userNote conflicts', () {
    test(
      'detects conflict when both local and imported have different notes',
      () {
        final local = {42: makeEntry(nodeNum: 42, userNote: 'local note')};
        final imported = [makeEntry(nodeNum: 42, userNote: 'imported note')];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final entry = preview.entries.first;
        expect(entry.hasConflicts, isTrue);
        expect(entry.userNoteConflict, isNotNull);
        expect(entry.userNoteConflict!.localValue, equals('local note'));
        expect(entry.userNoteConflict!.importedValue, equals('imported note'));
      },
    );

    test('no conflict when both have the same note', () {
      final local = {42: makeEntry(nodeNum: 42, userNote: 'same note')};
      final imported = [makeEntry(nodeNum: 42, userNote: 'same note')];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.userNoteConflict, isNull);
    });

    test('no conflict when local has note but import does not', () {
      final local = {42: makeEntry(nodeNum: 42, userNote: 'local only')};
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.userNoteConflict, isNull);
    });

    test('no conflict when import has note but local does not', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [makeEntry(nodeNum: 42, userNote: 'import only')];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.userNoteConflict, isNull);
    });

    test('no conflict when both notes are null', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.userNoteConflict, isNull);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — dual conflict detection
  // ===========================================================================

  group('ImportPreview.build() — dual conflicts', () {
    test('detects both socialTag and userNote conflicts simultaneously', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final entry = preview.entries.first;
      expect(entry.hasConflicts, isTrue);
      expect(entry.socialTagConflict, isNotNull);
      expect(entry.userNoteConflict, isNotNull);
    });

    test('socialTag conflict without userNote conflict', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'same note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.knownRelay,
          userNote: 'same note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final entry = preview.entries.first;
      expect(entry.socialTagConflict, isNotNull);
      expect(entry.userNoteConflict, isNull);
    });

    test('userNote conflict without socialTag conflict', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final entry = preview.entries.first;
      expect(entry.socialTagConflict, isNull);
      expect(entry.userNoteConflict, isNotNull);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — metadata flags
  // ===========================================================================

  group('ImportPreview.build() — metadata flags', () {
    test('importHasNewerData is true when imported lastSeen is later', () {
      final local = {
        42: makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 6, 1)),
      };
      final imported = [makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 8, 1))];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasNewerData, isTrue);
    });

    test('importHasNewerData is false when local lastSeen is later', () {
      final local = {
        42: makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 8, 1)),
      };
      final imported = [makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 6, 1))];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasNewerData, isFalse);
    });

    test('importHasNewerData is false when lastSeen is equal', () {
      final local = {
        42: makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 6, 1)),
      };
      final imported = [makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 6, 1))];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasNewerData, isFalse);
    });

    test('importHasMoreEncounters is true when import count is higher', () {
      final local = {42: makeEntry(nodeNum: 42, encounterCount: 5)};
      final imported = [makeEntry(nodeNum: 42, encounterCount: 10)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasMoreEncounters, isTrue);
    });

    test('importHasMoreEncounters is false when local count is higher', () {
      final local = {42: makeEntry(nodeNum: 42, encounterCount: 10)};
      final imported = [makeEntry(nodeNum: 42, encounterCount: 5)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasMoreEncounters, isFalse);
    });

    test('importHasMoreEncounters is false when counts are equal', () {
      final local = {42: makeEntry(nodeNum: 42, encounterCount: 5)};
      final imported = [makeEntry(nodeNum: 42, encounterCount: 5)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.importHasMoreEncounters, isFalse);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — co-seen edge counting
  // ===========================================================================

  group('ImportPreview.build() — newCoSeenEdges', () {
    test('counts edges present in import but not in local', () {
      final now = DateTime(2024, 6, 1);
      final local = {
        42: makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
          },
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
            300: CoSeenRelationship(count: 2, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // 200 and 300 are new edges; 100 already exists locally
      expect(preview.entries.first.newCoSeenEdges, equals(2));
    });

    test('zero new edges when all import edges exist locally', () {
      final now = DateTime(2024, 6, 1);
      final local = {
        42: makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newCoSeenEdges, equals(0));
    });

    test('all edges are new when local has none', () {
      final now = DateTime(2024, 6, 1);
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newCoSeenEdges, equals(2));
    });

    test('new entries report all co-seen edges as new', () {
      final now = DateTime(2024, 6, 1);
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
            200: CoSeenRelationship(count: 2, firstSeen: now, lastSeen: now),
            300: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.newCoSeenEdges, equals(3));
    });
  });

  // ===========================================================================
  // ImportPreview.build() — encounter record counting
  // ===========================================================================

  group('ImportPreview.build() — newEncounterRecords', () {
    test('counts encounter records not present locally by timestamp', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);
      final t3 = DateTime.fromMillisecondsSinceEpoch(1700020000000);

      final local = {
        42: makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8), // duplicate
            EncounterRecord(timestamp: t3, snr: 12), // new
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // Only t3 is new; t2 is a duplicate
      expect(preview.entries.first.newEncounterRecords, equals(1));
    });

    test('zero new records when all timestamps match', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final local = {
        42: makeEntry(
          nodeNum: 42,
          encounters: [EncounterRecord(timestamp: t1, snr: 5)],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [EncounterRecord(timestamp: t1, snr: 10)],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newEncounterRecords, equals(0));
    });

    test('all records are new when local has no encounters', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);

      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newEncounterRecords, equals(2));
    });

    test('new entries report all encounters as new', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [EncounterRecord(timestamp: t1, snr: 5)],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.newEncounterRecords, equals(1));
    });
  });

  // ===========================================================================
  // ImportPreview.build() — region counting
  // ===========================================================================

  group('ImportPreview.build() — newRegions', () {
    test('counts regions present in import but not locally', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
          ],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 2, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 3,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 3, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // r2 is new; r1 already exists locally
      expect(preview.entries.first.newRegions, equals(1));
    });

    test('zero new regions when all exist locally', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 3, 1),
              encounterCount: 1,
            ),
          ],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 2, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 3,
            ),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newRegions, equals(0));
    });

    test('all regions are new when local has none', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 2,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 3, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.newRegions, equals(2));
    });
  });

  // ===========================================================================
  // ImportPreview.build() — hasChanges detection
  // ===========================================================================

  group('ImportPreview.build() — hasChanges', () {
    test('hasChanges is true for new entry', () {
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when import has newer data', () {
      final local = {
        42: makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 6, 1)),
      };
      final imported = [makeEntry(nodeNum: 42, lastSeen: DateTime(2024, 8, 1))];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when import has more encounters', () {
      final local = {42: makeEntry(nodeNum: 42, encounterCount: 3)};
      final imported = [makeEntry(nodeNum: 42, encounterCount: 10)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when import has new co-seen edges', () {
      final now = DateTime(2024, 6, 1);
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when import has new encounter records', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [EncounterRecord(timestamp: t1, snr: 5)],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when import has new regions', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is true when there are conflicts', () {
      final local = {
        42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      };
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.entries.first.hasChanges, isTrue);
    });

    test('hasChanges is false when identical existing entry is imported '
        'with same timestamps and counts', () {
      // Both local and import have exactly the same scalar data,
      // no conflicts, no new edges/encounters/regions, and same lastSeen.
      final local = {
        42: makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // No new data, no conflicts, not newer, not more encounters
      expect(preview.entries.first.hasChanges, isFalse);
    });
  });

  // ===========================================================================
  // ImportPreview.build() — aggregate conflict counts
  // ===========================================================================

  group('ImportPreview.build() — aggregate counts', () {
    test('conflictCount counts entries with any conflict', () {
      final local = {
        1: makeEntry(nodeNum: 1, socialTag: NodeSocialTag.contact),
        2: makeEntry(nodeNum: 2, userNote: 'local note'),
        3: makeEntry(nodeNum: 3),
      };
      final imported = [
        makeEntry(nodeNum: 1, socialTag: NodeSocialTag.trustedNode),
        makeEntry(nodeNum: 2, userNote: 'import note'),
        makeEntry(nodeNum: 3),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.conflictCount, equals(2));
      expect(preview.socialTagConflictCount, equals(1));
      expect(preview.userNoteConflictCount, equals(1));
    });

    test('conflictingEntries returns only entries with conflicts sorted', () {
      final local = {
        30: makeEntry(nodeNum: 30, socialTag: NodeSocialTag.contact),
        10: makeEntry(nodeNum: 10, userNote: 'local note'),
        20: makeEntry(nodeNum: 20),
      };
      final imported = [
        makeEntry(nodeNum: 30, socialTag: NodeSocialTag.trustedNode),
        makeEntry(nodeNum: 10, userNote: 'import note'),
        makeEntry(nodeNum: 20),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final conflicting = preview.conflictingEntries;
      expect(conflicting.length, equals(2));
      // Sorted by nodeNum
      expect(conflicting[0].nodeNum, equals(10));
      expect(conflicting[1].nodeNum, equals(30));
    });

    test('newEntries returns only new entries sorted', () {
      final local = {10: makeEntry(nodeNum: 10)};
      final imported = [
        makeEntry(nodeNum: 30),
        makeEntry(nodeNum: 10),
        makeEntry(nodeNum: 20),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final newEntries = preview.newEntries;
      expect(newEntries.length, equals(2));
      expect(newEntries[0].nodeNum, equals(20));
      expect(newEntries[1].nodeNum, equals(30));
    });

    test(
      'cleanMergeEntries returns merge entries without conflicts sorted',
      () {
        final local = {
          10: makeEntry(nodeNum: 10, socialTag: NodeSocialTag.contact),
          20: makeEntry(nodeNum: 20),
          30: makeEntry(nodeNum: 30),
        };
        final imported = [
          makeEntry(nodeNum: 10, socialTag: NodeSocialTag.trustedNode),
          makeEntry(nodeNum: 20, encounterCount: 10),
          makeEntry(nodeNum: 30, encounterCount: 5),
        ];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final clean = preview.cleanMergeEntries;
        // Node 10 has a conflict; nodes 20 and 30 are clean merges
        expect(clean.length, equals(2));
        expect(clean[0].nodeNum, equals(20));
        expect(clean[1].nodeNum, equals(30));
      },
    );
  });

  // ===========================================================================
  // ImportPreview.build() — complex scenario
  // ===========================================================================

  group('ImportPreview.build() — complex scenario', () {
    test('multi-entry preview with mixed new, merge, and conflict entries', () {
      final now = DateTime(2024, 6, 1);
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      final local = {
        // Entry 10: will conflict on socialTag
        10: makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.contact,
          lastSeen: DateTime(2024, 3, 1),
          encounterCount: 3,
        ),
        // Entry 20: clean merge (no conflicts)
        20: makeEntry(
          nodeNum: 20,
          lastSeen: DateTime(2024, 4, 1),
          encounterCount: 5,
          coSeenNodes: {
            10: CoSeenRelationship(count: 2, firstSeen: now, lastSeen: now),
          },
        ),
        // Entry 30: will conflict on userNote
        30: makeEntry(nodeNum: 30, userNote: 'local note for 30'),
      };

      final imported = [
        // Entry 10: socialTag conflict
        makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.knownRelay,
          lastSeen: DateTime(2024, 8, 1),
          encounterCount: 10,
        ),
        // Entry 20: clean merge, with newer data and new edges
        makeEntry(
          nodeNum: 20,
          lastSeen: DateTime(2024, 7, 1),
          encounterCount: 8,
          coSeenNodes: {
            10: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
            30: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
          encounters: [EncounterRecord(timestamp: t1, snr: 12)],
        ),
        // Entry 30: userNote conflict
        makeEntry(nodeNum: 30, userNote: 'imported note for 30'),
        // Entry 40: entirely new
        makeEntry(nodeNum: 40),
        // Entry 50: entirely new
        makeEntry(nodeNum: 50),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      expect(preview.totalImported, equals(5));
      expect(preview.newEntryCount, equals(2));
      expect(preview.mergeEntryCount, equals(3));
      expect(preview.conflictCount, equals(2));
      expect(preview.socialTagConflictCount, equals(1));
      expect(preview.userNoteConflictCount, equals(1));
      expect(preview.hasConflicts, isTrue);
      expect(preview.hasChanges, isTrue);

      // Verify entry 10
      final entry10 = preview.entries.firstWhere((e) => e.nodeNum == 10);
      expect(entry10.isNew, isFalse);
      expect(entry10.hasConflicts, isTrue);
      expect(entry10.socialTagConflict, isNotNull);
      expect(entry10.importHasNewerData, isTrue);
      expect(entry10.importHasMoreEncounters, isTrue);

      // Verify entry 20
      final entry20 = preview.entries.firstWhere((e) => e.nodeNum == 20);
      expect(entry20.isNew, isFalse);
      expect(entry20.hasConflicts, isFalse);
      expect(entry20.importHasNewerData, isTrue);
      expect(entry20.importHasMoreEncounters, isTrue);
      expect(entry20.newCoSeenEdges, equals(1)); // edge to 30 is new
      expect(entry20.newEncounterRecords, equals(1));

      // Verify entry 30
      final entry30 = preview.entries.firstWhere((e) => e.nodeNum == 30);
      expect(entry30.isNew, isFalse);
      expect(entry30.hasConflicts, isTrue);
      expect(entry30.userNoteConflict, isNotNull);

      // Verify entry 40
      final entry40 = preview.entries.firstWhere((e) => e.nodeNum == 40);
      expect(entry40.isNew, isTrue);
      expect(entry40.hasConflicts, isFalse);

      // Verify entry 50
      final entry50 = preview.entries.firstWhere((e) => e.nodeNum == 50);
      expect(entry50.isNew, isTrue);
      expect(entry50.hasConflicts, isFalse);
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — MergeStrategy.keepLocal
  // ===========================================================================

  group('ImportPreview.applyMerge() — keepLocal strategy', () {
    test('new entries are added directly regardless of strategy', () {
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          socialTag: NodeSocialTag.contact,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {},
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.length, equals(1));
      expect(results.first.nodeNum, equals(42));
      expect(results.first.encounterCount, equals(10));
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('imported note'));
    });

    test('keeps local socialTag on conflict', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          encounterCount: 3,
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          encounterCount: 10,
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.length, equals(1));
      // socialTag should be local's value
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      // Scalar metrics should still be merged (max)
      expect(results.first.encounterCount, equals(10));
    });

    test('keeps local userNote on conflict', () {
      final local = {42: makeEntry(nodeNum: 42, userNote: 'local note')};
      final imported = [makeEntry(nodeNum: 42, userNote: 'imported note')];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.first.userNote, equals('local note'));
    });

    test('keeps both local socialTag and userNote on dual conflict', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('local note'));
    });

    test('fills socialTag from import when local has none (no conflict)', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      // No conflict — mergeWith should fill from import
      expect(results.first.socialTag, equals(NodeSocialTag.knownRelay));
    });

    test('fills userNote from import when local has none (no conflict)', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [makeEntry(nodeNum: 42, userNote: 'import only note')];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.first.userNote, equals('import only note'));
    });

    test(
      'scalar metrics are merged correctly alongside conflict resolution',
      () {
        final now = DateTime(2024, 6, 1);
        final local = {
          42: makeEntry(
            nodeNum: 42,
            socialTag: NodeSocialTag.contact,
            userNote: 'local note',
            firstSeen: DateTime(2024, 3, 1),
            lastSeen: DateTime(2024, 6, 1),
            encounterCount: 5,
            maxDistanceSeen: 1500.0,
            bestSnr: 10,
            bestRssi: -85,
            messageCount: 3,
            coSeenNodes: {
              100: CoSeenRelationship(
                count: 2,
                firstSeen: DateTime(2024, 3, 1),
                lastSeen: now,
              ),
            },
          ),
        };
        final imported = [
          makeEntry(
            nodeNum: 42,
            socialTag: NodeSocialTag.trustedNode,
            userNote: 'imported note',
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 8, 1),
            encounterCount: 10,
            maxDistanceSeen: 5000.0,
            bestSnr: 15,
            bestRssi: -70,
            messageCount: 8,
            coSeenNodes: {
              100: CoSeenRelationship(
                count: 5,
                firstSeen: DateTime(2024, 1, 1),
                lastSeen: DateTime(2024, 8, 1),
                messageCount: 3,
              ),
              200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
            },
          ),
        ];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final results = ImportPreview.applyMerge(
          preview: preview,
          localEntries: local,
          strategy: MergeStrategy.keepLocal,
        );

        final merged = results.first;
        // socialTag and userNote: local wins
        expect(merged.socialTag, equals(NodeSocialTag.contact));
        expect(merged.userNote, equals('local note'));
        // Scalar metrics: merged (max/best)
        expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
        expect(merged.lastSeen, equals(DateTime(2024, 8, 1)));
        expect(merged.encounterCount, equals(10));
        expect(merged.maxDistanceSeen, equals(5000.0));
        expect(merged.bestSnr, equals(15));
        expect(merged.bestRssi, equals(-70));
        expect(merged.messageCount, equals(8));
        // Co-seen: merged (edge 100 combined, edge 200 added)
        expect(merged.coSeenNodes.length, equals(2));
        expect(merged.coSeenNodes[100]!.count, equals(5));
        expect(merged.coSeenNodes[200]!.count, equals(1));
      },
    );
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — MergeStrategy.preferImport
  // ===========================================================================

  group('ImportPreview.applyMerge() — preferImport strategy', () {
    test('uses imported socialTag on conflict', () {
      final local = {
        42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      };
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );

      expect(results.first.socialTag, equals(NodeSocialTag.trustedNode));
    });

    test('uses imported userNote on conflict', () {
      final local = {42: makeEntry(nodeNum: 42, userNote: 'local note')};
      final imported = [makeEntry(nodeNum: 42, userNote: 'imported note')];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );

      expect(results.first.userNote, equals('imported note'));
    });

    test('uses both imported socialTag and userNote on dual conflict', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );

      expect(results.first.socialTag, equals(NodeSocialTag.trustedNode));
      expect(results.first.userNote, equals('imported note'));
    });

    test('preserves local socialTag when import is null (no conflict)', () {
      final local = {
        42: makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      };
      final imported = [makeEntry(nodeNum: 42)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );

      // No conflict — mergeWith prefers local (this), so local tag stays
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
    });

    test('fills socialTag from import when local is null (no conflict)', () {
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );

      // No conflict — mergeWith fills from other when local is null
      expect(results.first.socialTag, equals(NodeSocialTag.knownRelay));
    });

    test('new entries are added directly with preferImport', () {
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'test note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: {},
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {},
        strategy: MergeStrategy.preferImport,
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('test note'));
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — MergeStrategy.reviewConflicts
  // ===========================================================================

  group('ImportPreview.applyMerge() — reviewConflicts strategy', () {
    test('uses per-entry resolution to pick imported socialTag', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: false,
          ),
        },
      );

      // socialTag: import wins (per resolution)
      expect(results.first.socialTag, equals(NodeSocialTag.trustedNode));
      // userNote: local wins (per resolution)
      expect(results.first.userNote, equals('local note'));
    });

    test('uses per-entry resolution to pick imported userNote', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: false,
            useUserNoteFromImport: true,
          ),
        },
      );

      // socialTag: local wins (per resolution)
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      // userNote: import wins (per resolution)
      expect(results.first.userNote, equals('imported note'));
    });

    test('uses both imported values when resolution says so', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: true,
          ),
        },
      );

      expect(results.first.socialTag, equals(NodeSocialTag.trustedNode));
      expect(results.first.userNote, equals('imported note'));
    });

    test('keeps both local values when resolution says so', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: false,
            useUserNoteFromImport: false,
          ),
        },
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('local note'));
    });

    test('falls back to keepLocal when no resolution provided for '
        'reviewConflicts strategy', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // No resolutions provided — reviewConflicts without overrides
      // defaults to keepLocal behavior (useSocialTagFromImport is null,
      // strategy != preferImport, so the default mergeWith local-wins
      // behavior is kept)
      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {},
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('local note'));
    });

    test('null resolution fields fall back to keepLocal default for '
        'reviewConflicts', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          // Null fields = fall back to strategy default = keepLocal
          42: const ConflictResolution(nodeNum: 42),
        },
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('local note'));
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — per-entry resolutions on multiple entries
  // ===========================================================================

  group(
    'ImportPreview.applyMerge() — multiple entries with mixed resolutions',
    () {
      test('different resolutions for different entries', () {
        final local = {
          10: makeEntry(
            nodeNum: 10,
            socialTag: NodeSocialTag.contact,
            userNote: 'local note 10',
          ),
          20: makeEntry(
            nodeNum: 20,
            socialTag: NodeSocialTag.trustedNode,
            userNote: 'local note 20',
          ),
          30: makeEntry(nodeNum: 30, socialTag: NodeSocialTag.knownRelay),
        };
        final imported = [
          makeEntry(
            nodeNum: 10,
            socialTag: NodeSocialTag.trustedNode,
            userNote: 'imported note 10',
          ),
          makeEntry(
            nodeNum: 20,
            socialTag: NodeSocialTag.contact,
            userNote: 'imported note 20',
          ),
          makeEntry(nodeNum: 30, socialTag: NodeSocialTag.contact),
          makeEntry(nodeNum: 40), // new entry
        ];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final results = ImportPreview.applyMerge(
          preview: preview,
          localEntries: local,
          strategy: MergeStrategy.reviewConflicts,
          resolutions: {
            // Entry 10: prefer import for both
            10: const ConflictResolution(
              nodeNum: 10,
              useSocialTagFromImport: true,
              useUserNoteFromImport: true,
            ),
            // Entry 20: keep local for socialTag, import for userNote
            20: const ConflictResolution(
              nodeNum: 20,
              useSocialTagFromImport: false,
              useUserNoteFromImport: true,
            ),
            // Entry 30: prefer import for socialTag (no userNote conflict)
            30: const ConflictResolution(
              nodeNum: 30,
              useSocialTagFromImport: true,
            ),
          },
        );

        expect(results.length, equals(4));

        final result10 = results.firstWhere((e) => e.nodeNum == 10);
        expect(result10.socialTag, equals(NodeSocialTag.trustedNode));
        expect(result10.userNote, equals('imported note 10'));

        final result20 = results.firstWhere((e) => e.nodeNum == 20);
        expect(result20.socialTag, equals(NodeSocialTag.trustedNode));
        expect(result20.userNote, equals('imported note 20'));

        final result30 = results.firstWhere((e) => e.nodeNum == 30);
        expect(result30.socialTag, equals(NodeSocialTag.contact));

        final result40 = results.firstWhere((e) => e.nodeNum == 40);
        expect(result40.nodeNum, equals(40));
      });
    },
  );

  // ===========================================================================
  // ImportPreview.applyMerge() — empty preview
  // ===========================================================================

  group('ImportPreview.applyMerge() — empty preview', () {
    test('returns empty list for empty preview', () {
      const preview = ImportPreview(entries: [], totalImported: 0);

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {},
        strategy: MergeStrategy.keepLocal,
      );

      expect(results, isEmpty);
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — co-seen and region merging
  // ===========================================================================

  group('ImportPreview.applyMerge() — sub-collection merging', () {
    test('co-seen relationships are merged via mergeWith', () {
      final now = DateTime(2024, 6, 1);
      final local = {
        42: makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              messageCount: 2,
            ),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              messageCount: 5,
            ),
            300: CoSeenRelationship(count: 4, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      final merged = results.first;
      expect(merged.coSeenNodes.length, equals(3));

      // Edge 100: merged
      expect(merged.coSeenNodes[100]!.count, equals(8));
      expect(merged.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(merged.coSeenNodes[100]!.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(merged.coSeenNodes[100]!.messageCount, equals(5));

      // Edge 200: from local only
      expect(merged.coSeenNodes[200]!.count, equals(1));

      // Edge 300: from import only
      expect(merged.coSeenNodes[300]!.count, equals(4));
    });

    test('regions are merged via mergeWith', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 5,
            ),
          ],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 4, 1),
              encounterCount: 8,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 6, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      final merged = results.first;
      expect(merged.seenRegions.length, equals(2));

      final r1 = merged.seenRegions.firstWhere((r) => r.regionId == 'r1');
      expect(r1.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(r1.lastSeen, equals(DateTime(2024, 5, 1)));
      expect(r1.encounterCount, equals(8));

      final r2 = merged.seenRegions.firstWhere((r) => r.regionId == 'r2');
      expect(r2.encounterCount, equals(1));
    });

    test('encounters are merged and deduplicated via mergeWith', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);
      final t3 = DateTime.fromMillisecondsSinceEpoch(1700020000000);

      final local = {
        42: makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8), // duplicate
            EncounterRecord(timestamp: t3, snr: 12), // new
          ],
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      final merged = results.first;
      expect(merged.encounters.length, equals(3));
      expect(merged.encounters[0].timestamp, equals(t1));
      expect(merged.encounters[1].timestamp, equals(t2));
      expect(merged.encounters[2].timestamp, equals(t3));
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — strategy comparison
  // ===========================================================================

  group('ImportPreview.applyMerge() — strategy comparison', () {
    test('same conflict resolved differently by each strategy', () {
      final local = {
        42: makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      };
      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      // keepLocal
      final keepLocalResults = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );
      expect(keepLocalResults.first.socialTag, equals(NodeSocialTag.contact));
      expect(keepLocalResults.first.userNote, equals('local note'));

      // preferImport
      final preferImportResults = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.preferImport,
      );
      expect(
        preferImportResults.first.socialTag,
        equals(NodeSocialTag.trustedNode),
      );
      expect(preferImportResults.first.userNote, equals('imported note'));

      // reviewConflicts with resolution: import for tag, local for note
      final reviewResults = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: false,
          ),
        },
      );
      expect(reviewResults.first.socialTag, equals(NodeSocialTag.trustedNode));
      expect(reviewResults.first.userNote, equals('local note'));
    });

    test(
      'no-conflict entries produce the same result regardless of strategy',
      () {
        final now = DateTime(2024, 6, 1);
        final local = {
          42: makeEntry(
            nodeNum: 42,
            socialTag: NodeSocialTag.contact,
            encounterCount: 3,
            coSeenNodes: {
              100: CoSeenRelationship(count: 2, firstSeen: now, lastSeen: now),
            },
          ),
        };
        final imported = [
          makeEntry(
            nodeNum: 42,
            // No socialTag or userNote — no conflicts
            encounterCount: 10,
            coSeenNodes: {
              100: CoSeenRelationship(
                count: 5,
                firstSeen: DateTime(2024, 1, 1),
                lastSeen: now,
              ),
              200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
            },
          ),
        ];

        final preview = ImportPreview.build(
          importedEntries: imported,
          localEntries: local,
        );

        final keepLocalResults = ImportPreview.applyMerge(
          preview: preview,
          localEntries: local,
          strategy: MergeStrategy.keepLocal,
        );

        final preferImportResults = ImportPreview.applyMerge(
          preview: preview,
          localEntries: local,
          strategy: MergeStrategy.preferImport,
        );

        // Both should produce the same result
        expect(
          keepLocalResults.first.socialTag,
          equals(preferImportResults.first.socialTag),
        );
        expect(
          keepLocalResults.first.userNote,
          equals(preferImportResults.first.userNote),
        );
        expect(
          keepLocalResults.first.encounterCount,
          equals(preferImportResults.first.encounterCount),
        );
        expect(
          keepLocalResults.first.coSeenNodes.length,
          equals(preferImportResults.first.coSeenNodes.length),
        );
      },
    );
  });

  // ===========================================================================
  // ImportPreview.applyMerge() — sigil merging
  // ===========================================================================

  group('ImportPreview.applyMerge() — sigil handling', () {
    test('preserves local sigil when import has none', () {
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
      final local = {42: makeEntry(nodeNum: 42, sigil: sigil)};
      final imported = [makeEntry(nodeNum: 42, encounterCount: 10)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.first.sigil, isNotNull);
      expect(results.first.sigil!.vertices, equals(5));
    });

    test('fills sigil from import when local has none', () {
      const sigil = SigilData(
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
      final local = {42: makeEntry(nodeNum: 42)};
      final imported = [makeEntry(nodeNum: 42, sigil: sigil)];

      final preview = ImportPreview.build(
        importedEntries: imported,
        localEntries: local,
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: local,
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.first.sigil, isNotNull);
      expect(results.first.sigil!.vertices, equals(7));
    });
  });

  // ===========================================================================
  // EntryMergePreview helper getters
  // ===========================================================================

  group('EntryMergePreview — helper getters', () {
    test('isNew is true when localEntry is null', () {
      final preview = EntryMergePreview(
        nodeNum: 42,
        displayName: 'Node 002A',
        localEntry: null,
        importedEntry: makeEntry(nodeNum: 42),
      );

      expect(preview.isNew, isTrue);
    });

    test('isNew is false when localEntry is present', () {
      final local = makeEntry(nodeNum: 42);
      final preview = EntryMergePreview(
        nodeNum: 42,
        displayName: 'Node 002A',
        localEntry: local,
        importedEntry: makeEntry(nodeNum: 42),
      );

      expect(preview.isNew, isFalse);
    });

    test('hasConflicts is true with socialTag conflict only', () {
      final preview = EntryMergePreview(
        nodeNum: 42,
        displayName: 'Node 002A',
        importedEntry: makeEntry(nodeNum: 42),
        socialTagConflict: const FieldConflict(
          localValue: NodeSocialTag.contact,
          importedValue: NodeSocialTag.trustedNode,
        ),
      );

      expect(preview.hasConflicts, isTrue);
    });

    test('hasConflicts is true with userNote conflict only', () {
      final preview = EntryMergePreview(
        nodeNum: 42,
        displayName: 'Node 002A',
        importedEntry: makeEntry(nodeNum: 42),
        userNoteConflict: const FieldConflict(
          localValue: 'local',
          importedValue: 'imported',
        ),
      );

      expect(preview.hasConflicts, isTrue);
    });

    test('hasConflicts is false with no conflicts', () {
      final preview = EntryMergePreview(
        nodeNum: 42,
        displayName: 'Node 002A',
        importedEntry: makeEntry(nodeNum: 42),
      );

      expect(preview.hasConflicts, isFalse);
    });
  });

  // ===========================================================================
  // FieldConflict
  // ===========================================================================

  group('FieldConflict', () {
    test('stores local and imported values', () {
      const conflict = FieldConflict<String>(
        localValue: 'local',
        importedValue: 'imported',
      );

      expect(conflict.localValue, equals('local'));
      expect(conflict.importedValue, equals('imported'));
    });

    test('works with nullable types', () {
      const conflict = FieldConflict<NodeSocialTag?>(
        localValue: NodeSocialTag.contact,
        importedValue: NodeSocialTag.trustedNode,
      );

      expect(conflict.localValue, equals(NodeSocialTag.contact));
      expect(conflict.importedValue, equals(NodeSocialTag.trustedNode));
    });
  });

  // ===========================================================================
  // ConflictResolution
  // ===========================================================================

  group('ConflictResolution', () {
    test('stores resolution choices', () {
      const resolution = ConflictResolution(
        nodeNum: 42,
        useSocialTagFromImport: true,
        useUserNoteFromImport: false,
      );

      expect(resolution.nodeNum, equals(42));
      expect(resolution.useSocialTagFromImport, isTrue);
      expect(resolution.useUserNoteFromImport, isFalse);
    });

    test('fields default to null when not specified', () {
      const resolution = ConflictResolution(nodeNum: 42);

      expect(resolution.useSocialTagFromImport, isNull);
      expect(resolution.useUserNoteFromImport, isNull);
    });
  });

  // ===========================================================================
  // MergeStrategy enum
  // ===========================================================================

  group('MergeStrategy', () {
    test('has three values', () {
      expect(MergeStrategy.values.length, equals(3));
      expect(MergeStrategy.values, contains(MergeStrategy.keepLocal));
      expect(MergeStrategy.values, contains(MergeStrategy.preferImport));
      expect(MergeStrategy.values, contains(MergeStrategy.reviewConflicts));
    });
  });

  // ===========================================================================
  // ImportPreview aggregate properties
  // ===========================================================================

  group('ImportPreview — aggregate properties', () {
    test('isEmpty is true for empty entries list', () {
      const preview = ImportPreview(entries: [], totalImported: 0);

      expect(preview.isEmpty, isTrue);
    });

    test('isEmpty is false when entries exist', () {
      final preview = ImportPreview(
        entries: [
          EntryMergePreview(
            nodeNum: 42,
            displayName: 'Node 002A',
            importedEntry: makeEntry(nodeNum: 42),
          ),
        ],
        totalImported: 1,
      );

      expect(preview.isEmpty, isFalse);
    });

    test('hasConflicts is false when no entries have conflicts', () {
      final preview = ImportPreview(
        entries: [
          EntryMergePreview(
            nodeNum: 42,
            displayName: 'Node 002A',
            importedEntry: makeEntry(nodeNum: 42),
          ),
        ],
        totalImported: 1,
      );

      expect(preview.hasConflicts, isFalse);
    });

    test('hasConflicts is true when at least one entry has conflicts', () {
      final preview = ImportPreview(
        entries: [
          EntryMergePreview(
            nodeNum: 42,
            displayName: 'Node 002A',
            importedEntry: makeEntry(nodeNum: 42),
          ),
          EntryMergePreview(
            nodeNum: 43,
            displayName: 'Node 002B',
            importedEntry: makeEntry(nodeNum: 43),
            socialTagConflict: const FieldConflict(
              localValue: NodeSocialTag.contact,
              importedValue: NodeSocialTag.trustedNode,
            ),
          ),
        ],
        totalImported: 2,
      );

      expect(preview.hasConflicts, isTrue);
      expect(preview.conflictCount, equals(1));
    });
  });
}
