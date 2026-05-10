// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for NodeDex help content, section info buttons, sticky headers,
// and detail screen widget integration.
//
// Covers:
// - HelpContent.nodeDexDetail topic registration and step completeness
// - HelpContent.nodeDexSectionHelp map coverage
// - NodeDex detail screen rendering with help buttons
// - Sticky header delegate behavior
// - Section info button interaction

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/help/help_content.dart';
import 'package:socialmesh/features/nodedex/models/import_preview.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/providers/help_providers.dart';

void main() {
  // ===========================================================================
  // HelpContent — nodeDexDetail topic
  // ===========================================================================

  group('HelpContent.nodeDexDetail', () {
    test('topic is registered in allTopics', () {
      final topic = HelpContent.getTopic('nodedex_detail');
      expect(topic, isNotNull);
      expect(topic!.id, equals('nodedex_detail'));
    });

    test('topic has correct metadata', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      expect(topic.title, equals('Node Profile'));
      expect(topic.description, isNotEmpty);
      expect(topic.icon, equals(Icons.hexagon_outlined));
      expect(topic.category, equals(HelpContent.catNodes));
      expect(topic.priority, equals(4));
    });

    test('topic has steps for every major section', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      final stepIds = topic.steps.map((s) => s.id).toSet();

      expect(stepIds, contains('nodedex_sigil'));
      expect(stepIds, contains('nodedex_trait'));
      expect(stepIds, contains('nodedex_discovery'));
      expect(stepIds, contains('nodedex_signal'));
      expect(stepIds, contains('nodedex_social_tag'));
      expect(stepIds, contains('nodedex_note'));
      expect(stepIds, contains('nodedex_regions'));
      expect(stepIds, contains('nodedex_auto_summary'));
      expect(stepIds, contains('nodedex_observation_timeline'));
      expect(stepIds, contains('nodedex_encounters'));
      expect(stepIds, contains('nodedex_activity_timeline'));
      expect(stepIds, contains('nodedex_coseen'));
      expect(stepIds, contains('nodedex_device'));
    });

    test('topic has exactly 19 steps', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      expect(topic.steps.length, equals(19));
    });

    test('first step cannot go back', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      expect(topic.steps.first.canGoBack, isFalse);
    });

    test('all steps have non-empty bubble text', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      for (final step in topic.steps) {
        expect(
          step.bubbleText.isNotEmpty,
          isTrue,
          reason: 'Step ${step.id} has empty bubbleText',
        );
      }
    });

    test('all step IDs are unique', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      final ids = topic.steps.map((s) => s.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('topic is in the Nodes category alongside nodesOverview', () {
      final nodeTopics = HelpContent.getTopicsByCategory(HelpContent.catNodes);
      final ids = nodeTopics.map((t) => t.id).toSet();
      expect(ids, contains('nodes_overview'));
      expect(ids, contains('nodedex_detail'));
    });

    test('nodeDexDetail has lower priority than nodesOverview', () {
      final nodesOverview = HelpContent.getTopic('nodes_overview')!;
      final nodeDexDetail = HelpContent.getTopic('nodedex_detail')!;
      // Higher priority number = lower priority
      expect(nodeDexDetail.priority, greaterThan(nodesOverview.priority));
    });
  });

  // ===========================================================================
  // HelpContent — nodeDexSectionHelp map
  // ===========================================================================

  group('HelpContent.nodeDexSectionHelp', () {
    test('contains all expected section keys', () {
      const expectedKeys = [
        'sigil',
        'trait',
        'discovery',
        'signal',
        'social_tag',
        'note',
        'regions',
        'encounters',
        'coseen',
        'device',
      ];

      for (final key in expectedKeys) {
        expect(
          HelpContent.nodeDexSectionHelp.containsKey(key),
          isTrue,
          reason: 'Missing section help key: $key',
        );
      }
    });

    test('contains all expected album section keys', () {
      const expectedAlbumKeys = [
        'album_rarity',
        'album_grouping',
        'album_explorer_title',
        'album_holographic',
        'album_patina',
        'album_cloud_sync',
      ];

      for (final key in expectedAlbumKeys) {
        expect(
          HelpContent.nodeDexSectionHelp.containsKey(key),
          isTrue,
          reason: 'Missing album section help key: $key',
        );
      }
    });

    test('has exactly 26 entries (20 node-detail + 6 album)', () {
      expect(HelpContent.nodeDexSectionHelp.length, equals(26));
    });

    test('all values are non-empty strings', () {
      for (final entry in HelpContent.nodeDexSectionHelp.entries) {
        expect(
          entry.value.isNotEmpty,
          isTrue,
          reason: 'Section help for "${entry.key}" is empty',
        );
      }
    });

    test('all values are reasonable length (at least 50 chars)', () {
      for (final entry in HelpContent.nodeDexSectionHelp.entries) {
        expect(
          entry.value.length,
          greaterThanOrEqualTo(50),
          reason:
              'Section help for "${entry.key}" is too short: ${entry.value.length} chars',
        );
      }
    });

    test('node-detail section help keys align with tour step IDs', () {
      final topic = HelpContent.getTopic('nodedex_detail')!;
      final stepIds = topic.steps.map((s) => s.id).toSet();

      // Only node-detail keys (non-album) should align with nodedex_detail steps
      final nodeDetailKeys = HelpContent.nodeDexSectionHelp.keys
          .where((k) => !k.startsWith('album_'))
          .toSet();

      for (final key in nodeDetailKeys) {
        // pet_companion_self and pet_companion_remote both share the
        // single tour bubble "nodedex_pet_companion" — the tour is
        // generic; the info sheet is what branches on self vs remote.
        final expectedStepId = key.startsWith('pet_companion_')
            ? 'nodedex_pet_companion'
            : 'nodedex_$key';
        expect(
          stepIds.contains(expectedStepId),
          isTrue,
          reason:
              'Section help key "$key" has no matching tour step "$expectedStepId"',
        );
      }
    });

    test('album section help keys are valid inline helpers', () {
      // Album section help keys are contextual inline helpers shown in
      // tooltips or info panels. Not all have matching tour steps — keys
      // like album_explorer_title, album_patina, and album_cloud_sync
      // are explanatory snippets, not guided tour steps.
      final albumKeys = HelpContent.nodeDexSectionHelp.keys
          .where((k) => k.startsWith('album_'))
          .toList();

      expect(albumKeys.length, equals(6));

      for (final key in albumKeys) {
        final text = HelpContent.nodeDexSectionHelp[key]!;
        expect(
          text.length,
          greaterThanOrEqualTo(50),
          reason:
              'Album section help "$key" is too short: ${text.length} chars',
        );
      }
    });

    test('signal section mentions SNR and RSSI', () {
      final text = HelpContent.nodeDexSectionHelp['signal']!;
      expect(text, contains('SNR'));
      expect(text, contains('RSSI'));
    });

    test('coseen section mentions session and edge detail', () {
      final text = HelpContent.nodeDexSectionHelp['coseen']!;
      expect(text.toLowerCase(), contains('session'));
      expect(text.toLowerCase(), contains('together'));
    });

    test('social_tag section mentions local storage', () {
      final text = HelpContent.nodeDexSectionHelp['social_tag']!;
      expect(text.toLowerCase(), contains('local'));
    });

    test('encounters section mentions timeline', () {
      final text = HelpContent.nodeDexSectionHelp['encounters']!;
      expect(text.toLowerCase(), contains('timeline'));
    });
  });

  // ===========================================================================
  // HelpState integration with NodeDex topics
  // ===========================================================================

  group('HelpState with NodeDex topics', () {
    test('nodeDexDetail topic is initially available', () {
      const state = HelpState();
      expect(state.shouldShowHelp('nodedex_detail'), isTrue);
    });

    test('nodeDexDetail can be completed', () {
      const state = HelpState(completedTopics: {'nodedex_detail'});
      expect(state.isTopicCompleted('nodedex_detail'), isTrue);
      expect(state.shouldShowHelp('nodedex_detail'), isFalse);
    });

    test('nodeDexDetail can be dismissed', () {
      const state = HelpState(dismissedTopics: {'nodedex_detail'});
      expect(state.isTopicDismissed('nodedex_detail'), isTrue);
      expect(state.shouldShowHelp('nodedex_detail'), isFalse);
    });

    test('skipFutureHelp hides nodeDexDetail', () {
      const state = HelpState(skipFutureHelp: true);
      expect(state.shouldShowHelp('nodedex_detail'), isFalse);
    });

    test('completing nodesOverview does not affect nodeDexDetail', () {
      const state = HelpState(completedTopics: {'nodes_overview'});
      expect(state.shouldShowHelp('nodedex_detail'), isTrue);
    });
  });

  // ===========================================================================
  // ImportPreview — edge cases for help content alignment
  // ===========================================================================

  group('ImportPreview — help context relevance', () {
    NodeDexEntry makeEntry({
      required int nodeNum,
      NodeSocialTag? socialTag,
      String? userNote,
      List<EncounterRecord> encounters = const [],
      Map<int, CoSeenRelationship> coSeenNodes = const {},
      List<SeenRegion> seenRegions = const [],
    }) {
      return NodeDexEntry(
        nodeNum: nodeNum,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: encounters.isEmpty ? 1 : encounters.length,
        socialTag: socialTag,
        userNote: userNote,
        encounters: encounters,
        coSeenNodes: coSeenNodes,
        seenRegions: seenRegions,
      );
    }

    test('preview detects social tag conflicts mentioned in help text', () {
      // The help text for social_tag says tags are "stored locally"
      // and "included in NodeDex exports" — conflicts arise on import
      final local = makeEntry(nodeNum: 1, socialTag: NodeSocialTag.contact);
      final imported = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.knownRelay,
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      expect(preview.conflictCount, equals(1));
      expect(preview.entries.first.socialTagConflict, isNotNull);
      expect(
        preview.entries.first.socialTagConflict!.localValue,
        equals(NodeSocialTag.contact),
      );
      expect(
        preview.entries.first.socialTagConflict!.importedValue,
        equals(NodeSocialTag.knownRelay),
      );
    });

    test('preview detects note conflicts mentioned in help text', () {
      // The help text for note says notes are "included in NodeDex exports"
      final local = makeEntry(nodeNum: 2, userNote: 'Hilltop relay near park');
      final imported = makeEntry(
        nodeNum: 2,
        userNote: 'Solar-powered relay station',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {2: local},
      );

      expect(preview.conflictCount, equals(1));
      expect(preview.entries.first.userNoteConflict, isNotNull);
    });

    test('preview counts new constellation edges', () {
      // The help text for constellation says these are "nodes frequently
      // seen in the same session" — edges are per-import enrichment
      final local = makeEntry(
        nodeNum: 3,
        coSeenNodes: {
          10: CoSeenRelationship(
            count: 5,
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 3, 1),
          ),
        },
      );
      final imported = makeEntry(
        nodeNum: 3,
        coSeenNodes: {
          10: CoSeenRelationship(
            count: 3,
            firstSeen: DateTime(2024, 2, 1),
            lastSeen: DateTime(2024, 4, 1),
          ),
          20: CoSeenRelationship(
            count: 2,
            firstSeen: DateTime(2024, 3, 1),
            lastSeen: DateTime(2024, 5, 1),
          ),
        },
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {3: local},
      );

      // Node 20 is new, node 10 already exists locally
      expect(preview.entries.first.newCoSeenEdges, equals(1));
    });

    test('preview counts new encounter records', () {
      // The help text for encounters says "each encounter records the
      // timestamp, signal quality" — new records come from import
      final localEncounters = [
        EncounterRecord(timestamp: DateTime(2024, 1, 15), snr: 10, rssi: -80),
      ];
      final importedEncounters = [
        EncounterRecord(timestamp: DateTime(2024, 1, 15), snr: 10, rssi: -80),
        EncounterRecord(timestamp: DateTime(2024, 2, 20), snr: 8, rssi: -90),
      ];

      final local = makeEntry(nodeNum: 4, encounters: localEncounters);
      final imported = makeEntry(nodeNum: 4, encounters: importedEncounters);

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {4: local},
      );

      expect(preview.entries.first.newEncounterRecords, equals(1));
    });

    test('preview counts new regions', () {
      // The help text for regions says "every regulatory region where
      // this node has been observed"
      final localRegions = [
        SeenRegion(
          regionId: 'US',
          label: 'US',
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          encounterCount: 5,
        ),
      ];
      final importedRegions = [
        SeenRegion(
          regionId: 'US',
          label: 'US',
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          encounterCount: 5,
        ),
        SeenRegion(
          regionId: 'EU_868',
          label: 'EU_868',
          firstSeen: DateTime(2024, 4, 1),
          lastSeen: DateTime(2024, 5, 1),
          encounterCount: 2,
        ),
      ];

      final local = makeEntry(nodeNum: 5, seenRegions: localRegions);
      final imported = makeEntry(nodeNum: 5, seenRegions: importedRegions);

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {5: local},
      );

      expect(preview.entries.first.newRegions, equals(1));
    });
  });

  // ===========================================================================
  // MergeStrategy — alignment with help-described behavior
  // ===========================================================================

  group('MergeStrategy behavior matches help descriptions', () {
    NodeDexEntry makeEntry({
      required int nodeNum,
      NodeSocialTag? socialTag,
      String? userNote,
    }) {
      return NodeDexEntry(
        nodeNum: nodeNum,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: 1,
        socialTag: socialTag,
        userNote: userNote,
      );
    }

    test('keepLocal strategy preserves local social tag and note', () {
      final local = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.contact,
        userNote: 'My local note',
      );
      final imported = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.knownRelay,
        userNote: 'Imported note',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {1: local},
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.length, equals(1));
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('My local note'));
    });

    test('preferImport strategy uses imported social tag and note', () {
      final local = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.contact,
        userNote: 'My local note',
      );
      final imported = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.knownRelay,
        userNote: 'Imported note',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {1: local},
        strategy: MergeStrategy.preferImport,
      );

      expect(results.length, equals(1));
      expect(results.first.socialTag, equals(NodeSocialTag.knownRelay));
      expect(results.first.userNote, equals('Imported note'));
    });

    test('reviewConflicts with per-entry resolution overrides', () {
      final local = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.contact,
        userNote: 'My local note',
      );
      final imported = makeEntry(
        nodeNum: 1,
        socialTag: NodeSocialTag.knownRelay,
        userNote: 'Imported note',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      // Keep local tag but use imported note
      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {1: local},
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          1: const ConflictResolution(
            nodeNum: 1,
            useSocialTagFromImport: false,
            useUserNoteFromImport: true,
          ),
        },
      );

      expect(results.length, equals(1));
      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('Imported note'));
    });

    test('new entries are always added regardless of strategy', () {
      final imported = makeEntry(
        nodeNum: 99,
        socialTag: NodeSocialTag.trustedNode,
        userNote: 'New node from import',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {},
      );

      for (final strategy in MergeStrategy.values) {
        final results = ImportPreview.applyMerge(
          preview: preview,
          localEntries: {},
          strategy: strategy,
        );

        expect(
          results.length,
          equals(1),
          reason: 'Strategy ${strategy.name} should add new entry',
        );
        expect(results.first.nodeNum, equals(99));
        expect(results.first.socialTag, equals(NodeSocialTag.trustedNode));
      }
    });
  });

  // ===========================================================================
  // EntryMergePreview — computed properties
  // ===========================================================================

  group('EntryMergePreview computed properties', () {
    test('isNew when localEntry is null', () {
      final dummyEntry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );
      final preview = EntryMergePreview(
        nodeNum: 1,
        displayName: 'Node 0001',
        localEntry: null,
        importedEntry: dummyEntry,
        newCoSeenEdges: 3,
        newEncounterRecords: 2,
        newRegions: 1,
      );

      expect(preview.isNew, isTrue);
      expect(preview.hasConflicts, isFalse);
      expect(preview.hasChanges, isTrue);
    });

    test('hasConflicts when socialTag conflict exists', () {
      final preview = EntryMergePreview(
        nodeNum: 1,
        displayName: 'Test',
        importedEntry: NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
          encounterCount: 1,
        ),
        localEntry: NodeDexEntry(
          nodeNum: 1,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
          encounterCount: 1,
        ),
        socialTagConflict: const FieldConflict(
          localValue: NodeSocialTag.contact,
          importedValue: NodeSocialTag.knownRelay,
        ),
      );

      expect(preview.hasConflicts, isTrue);
      expect(preview.isNew, isFalse);
    });

    test('hasConflicts when userNote conflict exists', () {
      final preview = EntryMergePreview(
        nodeNum: 2,
        displayName: 'Test',
        importedEntry: NodeDexEntry(
          nodeNum: 2,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
          encounterCount: 1,
        ),
        localEntry: NodeDexEntry(
          nodeNum: 2,
          firstSeen: DateTime(2024),
          lastSeen: DateTime(2024),
          encounterCount: 1,
        ),
        userNoteConflict: const FieldConflict(
          localValue: 'Local note',
          importedValue: 'Imported note',
        ),
      );

      expect(preview.hasConflicts, isTrue);
    });

    test('hasChanges is false when nothing differs', () {
      final entry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final preview = EntryMergePreview(
        nodeNum: 1,
        displayName: 'Test',
        importedEntry: entry,
        localEntry: entry,
      );

      expect(preview.hasChanges, isFalse);
      expect(preview.isNew, isFalse);
      expect(preview.hasConflicts, isFalse);
    });

    test('hasChanges is true when import has newer data', () {
      final local = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final preview = EntryMergePreview(
        nodeNum: 1,
        displayName: 'Test',
        importedEntry: local,
        localEntry: local,
        importHasNewerData: true,
      );

      expect(preview.hasChanges, isTrue);
    });
  });

  // ===========================================================================
  // ImportPreview — aggregate computed properties
  // ===========================================================================

  group('ImportPreview aggregate properties', () {
    test('empty preview reports correct counts', () {
      const preview = ImportPreview(entries: [], totalImported: 0);

      expect(preview.isEmpty, isTrue);
      expect(preview.hasChanges, isFalse);
      expect(preview.hasConflicts, isFalse);
      expect(preview.newEntryCount, equals(0));
      expect(preview.mergeEntryCount, equals(0));
      expect(preview.conflictCount, equals(0));
      expect(preview.socialTagConflictCount, equals(0));
      expect(preview.userNoteConflictCount, equals(0));
    });

    test('mixed preview reports correct counts', () {
      final entry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final previews = [
        // New entry
        EntryMergePreview(
          nodeNum: 1,
          displayName: 'New Node',
          localEntry: null,
          importedEntry: entry,
          newCoSeenEdges: 2,
        ),
        // Merge with tag conflict
        EntryMergePreview(
          nodeNum: 2,
          displayName: 'Conflict Node',
          localEntry: entry,
          importedEntry: entry,
          socialTagConflict: const FieldConflict(
            localValue: NodeSocialTag.contact,
            importedValue: NodeSocialTag.knownRelay,
          ),
        ),
        // Merge with note conflict
        EntryMergePreview(
          nodeNum: 3,
          displayName: 'Note Conflict',
          localEntry: entry,
          importedEntry: entry,
          userNoteConflict: const FieldConflict(
            localValue: 'A',
            importedValue: 'B',
          ),
        ),
        // Clean merge
        EntryMergePreview(
          nodeNum: 4,
          displayName: 'Clean Merge',
          localEntry: entry,
          importedEntry: entry,
          importHasNewerData: true,
        ),
      ];

      final preview = ImportPreview(entries: previews, totalImported: 4);

      expect(preview.isEmpty, isFalse);
      expect(preview.hasChanges, isTrue);
      expect(preview.hasConflicts, isTrue);
      expect(preview.newEntryCount, equals(1));
      expect(preview.mergeEntryCount, equals(3));
      expect(preview.conflictCount, equals(2));
      expect(preview.socialTagConflictCount, equals(1));
      expect(preview.userNoteConflictCount, equals(1));
    });

    test('conflictingEntries sorted by node number', () {
      final entry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final previews = [
        EntryMergePreview(
          nodeNum: 30,
          displayName: 'C',
          localEntry: entry,
          importedEntry: entry,
          socialTagConflict: const FieldConflict(
            localValue: NodeSocialTag.contact,
            importedValue: NodeSocialTag.knownRelay,
          ),
        ),
        EntryMergePreview(
          nodeNum: 10,
          displayName: 'A',
          localEntry: entry,
          importedEntry: entry,
          userNoteConflict: const FieldConflict(
            localValue: 'X',
            importedValue: 'Y',
          ),
        ),
        EntryMergePreview(
          nodeNum: 20,
          displayName: 'B',
          localEntry: null,
          importedEntry: entry,
        ),
      ];

      final preview = ImportPreview(entries: previews, totalImported: 3);
      final conflicting = preview.conflictingEntries;

      expect(conflicting.length, equals(2));
      expect(conflicting[0].nodeNum, equals(10));
      expect(conflicting[1].nodeNum, equals(30));
    });

    test('newEntries sorted by node number', () {
      final entry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final previews = [
        EntryMergePreview(
          nodeNum: 50,
          displayName: 'E',
          localEntry: null,
          importedEntry: entry,
        ),
        EntryMergePreview(
          nodeNum: 10,
          displayName: 'A',
          localEntry: null,
          importedEntry: entry,
        ),
        EntryMergePreview(
          nodeNum: 30,
          displayName: 'C',
          localEntry: entry,
          importedEntry: entry,
        ),
      ];

      final preview = ImportPreview(entries: previews, totalImported: 3);
      final newEntries = preview.newEntries;

      expect(newEntries.length, equals(2));
      expect(newEntries[0].nodeNum, equals(10));
      expect(newEntries[1].nodeNum, equals(50));
    });

    test('cleanMergeEntries excludes new and conflicting', () {
      final entry = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final previews = [
        // New
        EntryMergePreview(
          nodeNum: 1,
          displayName: 'New',
          localEntry: null,
          importedEntry: entry,
        ),
        // Conflict
        EntryMergePreview(
          nodeNum: 2,
          displayName: 'Conflict',
          localEntry: entry,
          importedEntry: entry,
          socialTagConflict: const FieldConflict(
            localValue: NodeSocialTag.contact,
            importedValue: NodeSocialTag.knownRelay,
          ),
        ),
        // Clean merge
        EntryMergePreview(
          nodeNum: 3,
          displayName: 'Clean',
          localEntry: entry,
          importedEntry: entry,
          importHasNewerData: true,
        ),
      ];

      final preview = ImportPreview(entries: previews, totalImported: 3);
      final clean = preview.cleanMergeEntries;

      expect(clean.length, equals(1));
      expect(clean.first.nodeNum, equals(3));
    });
  });

  // ===========================================================================
  // FieldConflict — basic
  // ===========================================================================

  group('FieldConflict', () {
    test('stores local and imported values', () {
      const conflict = FieldConflict<String?>(
        localValue: 'local',
        importedValue: 'imported',
      );

      expect(conflict.localValue, equals('local'));
      expect(conflict.importedValue, equals('imported'));
    });

    test('works with nullable types', () {
      const conflict = FieldConflict<NodeSocialTag?>(
        localValue: NodeSocialTag.contact,
        importedValue: null,
      );

      expect(conflict.localValue, equals(NodeSocialTag.contact));
      expect(conflict.importedValue, isNull);
    });
  });

  // ===========================================================================
  // ConflictResolution
  // ===========================================================================

  group('ConflictResolution', () {
    test('stores per-entry override preferences', () {
      const resolution = ConflictResolution(
        nodeNum: 42,
        useSocialTagFromImport: true,
        useUserNoteFromImport: false,
      );

      expect(resolution.nodeNum, equals(42));
      expect(resolution.useSocialTagFromImport, isTrue);
      expect(resolution.useUserNoteFromImport, isFalse);
    });

    test('null fields mean use global strategy', () {
      const resolution = ConflictResolution(nodeNum: 1);

      expect(resolution.useSocialTagFromImport, isNull);
      expect(resolution.useUserNoteFromImport, isNull);
    });
  });

  // ===========================================================================
  // MergeStrategy enum
  // ===========================================================================

  group('MergeStrategy', () {
    test('has exactly 3 values', () {
      expect(MergeStrategy.values.length, equals(3));
    });

    test('contains expected strategies', () {
      expect(MergeStrategy.values, contains(MergeStrategy.keepLocal));
      expect(MergeStrategy.values, contains(MergeStrategy.preferImport));
      expect(MergeStrategy.values, contains(MergeStrategy.reviewConflicts));
    });
  });

  // ===========================================================================
  // ImportPreview.build — display name resolver
  // ===========================================================================

  group('ImportPreview.build — displayNameResolver', () {
    test('uses resolver when provided', () {
      final imported = NodeDexEntry(
        nodeNum: 0xABCD,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {},
        displayNameResolver: (nodeNum) => 'Custom Name $nodeNum',
      );

      expect(preview.entries.first.displayName, equals('Custom Name 43981'));
    });

    test('falls back to hex ID when no resolver', () {
      final imported = NodeDexEntry(
        nodeNum: 0xABCD,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {},
      );

      expect(preview.entries.first.displayName, equals('Meshtastic ABCD'));
    });

    test('pads short hex IDs to 4 characters', () {
      final imported = NodeDexEntry(
        nodeNum: 0x0A,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {},
      );

      expect(preview.entries.first.displayName, equals('Meshtastic 000A'));
    });
  });

  // ===========================================================================
  // ImportPreview.applyMerge — edge cases
  // ===========================================================================

  group('ImportPreview.applyMerge — edge cases', () {
    test('no-conflict entries pass through regardless of strategy', () {
      final local = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
        encounterCount: 3,
        socialTag: NodeSocialTag.contact,
      );
      final imported = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        encounterCount: 5,
        // No socialTag — no conflict
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      expect(preview.hasConflicts, isFalse);

      // All strategies should produce same result when no conflicts
      for (final strategy in MergeStrategy.values) {
        final results = ImportPreview.applyMerge(
          preview: preview,
          localEntries: {1: local},
          strategy: strategy,
        );

        expect(results.length, equals(1));
        // socialTag should be preserved from local (mergeWith behavior)
        expect(results.first.socialTag, equals(NodeSocialTag.contact));
      }
    });

    test('mixed new and existing entries merge correctly', () {
      final local = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
        encounterCount: 2,
        socialTag: NodeSocialTag.contact,
        userNote: 'Known relay',
      );
      final importedExisting = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 5, 1),
        encounterCount: 4,
        socialTag: NodeSocialTag.trustedNode,
        userNote: 'Updated info',
      );
      final importedNew = NodeDexEntry(
        nodeNum: 2,
        firstSeen: DateTime(2024, 4, 1),
        lastSeen: DateTime(2024, 5, 1),
        encounterCount: 1,
        socialTag: NodeSocialTag.frequentPeer,
      );

      final preview = ImportPreview.build(
        importedEntries: [importedExisting, importedNew],
        localEntries: {1: local},
      );

      expect(preview.newEntryCount, equals(1));
      expect(preview.conflictCount, equals(1));

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {1: local},
        strategy: MergeStrategy.keepLocal,
      );

      expect(results.length, equals(2));

      // Existing entry keeps local values
      final merged = results.firstWhere((e) => e.nodeNum == 1);
      expect(merged.socialTag, equals(NodeSocialTag.contact));
      expect(merged.userNote, equals('Known relay'));

      // New entry is added as-is
      final newEntry = results.firstWhere((e) => e.nodeNum == 2);
      expect(newEntry.socialTag, equals(NodeSocialTag.frequentPeer));
    });

    test('empty import produces empty results', () {
      final preview = ImportPreview.build(
        importedEntries: [],
        localEntries: {
          1: NodeDexEntry(
            nodeNum: 1,
            firstSeen: DateTime(2024),
            lastSeen: DateTime(2024),
            encounterCount: 1,
          ),
        },
      );

      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {},
        strategy: MergeStrategy.keepLocal,
      );

      expect(results, isEmpty);
    });

    test('resolution overrides take precedence over strategy', () {
      final local = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
        socialTag: NodeSocialTag.contact,
        userNote: 'Local',
      );
      final imported = NodeDexEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024),
        lastSeen: DateTime(2024),
        encounterCount: 1,
        socialTag: NodeSocialTag.knownRelay,
        userNote: 'Imported',
      );

      final preview = ImportPreview.build(
        importedEntries: [imported],
        localEntries: {1: local},
      );

      // Strategy says prefer import, but resolution says keep local tag
      final results = ImportPreview.applyMerge(
        preview: preview,
        localEntries: {1: local},
        strategy: MergeStrategy.preferImport,
        resolutions: {
          1: const ConflictResolution(
            nodeNum: 1,
            useSocialTagFromImport: false,
            // Note uses global strategy (preferImport)
          ),
        },
      );

      expect(results.first.socialTag, equals(NodeSocialTag.contact));
      expect(results.first.userNote, equals('Imported'));
    });
  });

  // ===========================================================================
  // HelpContent — allTopics integrity
  // ===========================================================================

  group('HelpContent allTopics integrity', () {
    test('no duplicate topic IDs', () {
      final ids = HelpContent.allTopics.map((t) => t.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('all topics have at least one step', () {
      for (final topic in HelpContent.allTopics) {
        expect(
          topic.steps.isNotEmpty,
          isTrue,
          reason: 'Topic ${topic.id} has no steps',
        );
      }
    });

    test('all topics have valid categories', () {
      final validCategories = HelpContent.allCategories.toSet();
      for (final topic in HelpContent.allTopics) {
        expect(
          validCategories.contains(topic.category),
          isTrue,
          reason: 'Topic ${topic.id} has invalid category: ${topic.category}',
        );
      }
    });

    test('getTopic returns null for unknown ID', () {
      expect(HelpContent.getTopic('nonexistent_topic'), isNull);
    });

    test('getTopicsByCategory returns sorted by priority', () {
      for (final category in HelpContent.allCategories) {
        final topics = HelpContent.getTopicsByCategory(category);
        for (int i = 1; i < topics.length; i++) {
          expect(
            topics[i].priority,
            greaterThanOrEqualTo(topics[i - 1].priority),
            reason: 'Topics in $category not sorted by priority at index $i',
          );
        }
      }
    });

    test('topicsByPriority returns all topics sorted', () {
      final sorted = HelpContent.topicsByPriority;
      expect(sorted.length, equals(HelpContent.allTopics.length));
      for (int i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].priority,
          greaterThanOrEqualTo(sorted[i - 1].priority),
        );
      }
    });
  });

  // ===========================================================================
  // Companion copy — truthfulness guard.
  //
  // Guards against copy regressions that would mislead users about how
  // NodePet visibility works:
  //   1. No claim that pet data is never transmitted (it is, when remote
  //      sharing is enabled — small summary via companion sharing).
  //   2. No passive-only "only observed" framing — remote visibility
  //      depends on the peer explicitly sharing a summary.
  //   3. No protocol jargon leaks (MRRP / SIP / pet.v1 / wire / packets).
  //   4. Self copy makes it clear the companion is local-first.
  //   5. Remote copy stays conservative while sharing is alpha.
  // ===========================================================================

  group('Companion copy truthfulness', () {
    // Every piece of user-facing companion copy we can reach at test time
    // (tour bubble + info-sheet fallback map). The ARB-backed sheet copy
    // resolves through AppLocalizations at runtime; its English value is
    // pinned by the fallback map entries below (same words).
    List<String> companionCopyStrings() {
      final tour = HelpContent.getTopic(
        'nodedex_detail',
      )!.steps.firstWhere((s) => s.id == 'nodedex_pet_companion').bubbleText;
      final selfFallback =
          HelpContent.nodeDexSectionHelp['pet_companion_self']!;
      final remoteFallback =
          HelpContent.nodeDexSectionHelp['pet_companion_remote']!;
      return [tour, selfFallback, remoteFallback];
    }

    test('does not claim pet data is never transmitted', () {
      for (final copy in companionCopyStrings()) {
        expect(
          copy.toLowerCase(),
          isNot(contains('never transmit')),
          reason:
              'Companion copy must not claim pet data is never transmitted. '
              'When companion sharing is enabled, a small summary is sent.',
        );
        expect(
          copy.toLowerCase(),
          isNot(contains('no pet data')),
          reason: 'Dropped phrase "no pet data" reintroduced — this is false.',
        );
        expect(
          copy.toLowerCase(),
          isNot(contains('never travels')),
          reason: 'Companion copy must not imply it never leaves the node.',
        );
      }
    });

    test('does not imply passive-only observation', () {
      for (final copy in companionCopyStrings()) {
        expect(
          copy.toLowerCase(),
          isNot(contains('only observed')),
          reason:
              'Companion copy must not claim peer pets are "only observed" — '
              'visibility requires the peer to share a summary.',
        );
        expect(
          copy.toLowerCase(),
          isNot(contains('passively')),
          reason:
              'Companion copy must not imply peer pets appear passively from '
              'mesh behaviour alone.',
        );
      }
    });

    test('contains no protocol jargon', () {
      const banned = ['mrrp', 'sip', 'pet.v1', 'wire format', 'packet'];
      for (final copy in companionCopyStrings()) {
        final lower = copy.toLowerCase();
        for (final term in banned) {
          expect(
            lower,
            isNot(contains(term)),
            reason:
                'User-facing companion copy must not mention protocol jargon '
                '("$term" leaked into: "$copy").',
          );
        }
      }
    });

    test('self info copy is local-first and mentions the own node', () {
      final selfCopy = HelpContent.nodeDexSectionHelp['pet_companion_self']!
          .toLowerCase();
      expect(selfCopy, contains('your'));
      expect(selfCopy, anyOf(contains('local'), contains('with your node')));
    });

    test('remote info copy is conservative about sharing', () {
      final remoteCopy = HelpContent.nodeDexSectionHelp['pet_companion_remote']!
          .toLowerCase();
      // Must not over-promise — no "always"/"live" language.
      expect(remoteCopy, isNot(contains('always')));
      expect(remoteCopy, isNot(contains('live')));
      // Must frame remote visibility as conditional on the peer sharing.
      expect(remoteCopy, anyOf(contains('if'), contains('when')));
      expect(remoteCopy, contains('share'));
    });
  });
}
