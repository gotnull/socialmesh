// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/identity_registry.dart';

void main() {
  late TakIdentityRegistry registry;
  late List<TakIdentity> persisted;

  setUp(() {
    persisted = [];
    registry = TakIdentityRegistry(
      persist: (identity) async => persisted.add(identity),
      load: () async => [],
    );
  });

  group('TakIdentity', () {
    test('serialization round-trip', () {
      final identity = TakIdentity(
        nodeNum: 0x1A2B3C4D,
        takUid: 'MESHTASTIC-1A2B3C4D',
        callsign: 'Alpha',
        overrideCallsign: 'LEAD',
        firstSeenMs: 1000,
        lastSeenMs: 2000,
      );

      final map = identity.toMap();
      final restored = TakIdentity.fromMap(map);

      expect(restored.nodeNum, identity.nodeNum);
      expect(restored.takUid, identity.takUid);
      expect(restored.callsign, identity.callsign);
      expect(restored.overrideCallsign, identity.overrideCallsign);
      expect(restored.firstSeenMs, identity.firstSeenMs);
      expect(restored.lastSeenMs, identity.lastSeenMs);
    });

    test('displayCallsign uses override when set', () {
      final withOverride = TakIdentity(
        nodeNum: 1,
        takUid: 'test',
        callsign: 'Original',
        overrideCallsign: 'Custom',
        firstSeenMs: 0,
        lastSeenMs: 0,
      );
      expect(withOverride.displayCallsign, 'Custom');

      final withoutOverride = TakIdentity(
        nodeNum: 1,
        takUid: 'test2',
        callsign: 'Original',
        firstSeenMs: 0,
        lastSeenMs: 0,
      );
      expect(withoutOverride.displayCallsign, 'Original');
    });

    test('isMeshNode is true for non-zero nodeNum', () {
      final mesh = TakIdentity(
        nodeNum: 42,
        takUid: 'uid',
        callsign: 'cs',
        firstSeenMs: 0,
        lastSeenMs: 0,
      );
      expect(mesh.isMeshNode, isTrue);

      final tak = TakIdentity(
        nodeNum: 0,
        takUid: 'uid2',
        callsign: 'cs2',
        firstSeenMs: 0,
        lastSeenMs: 0,
      );
      expect(tak.isMeshNode, isFalse);
    });

    test('equality', () {
      final a = TakIdentity(
        nodeNum: 1,
        takUid: 'uid',
        callsign: 'cs',
        firstSeenMs: 0,
        lastSeenMs: 0,
      );
      final b = TakIdentity(
        nodeNum: 1,
        takUid: 'uid',
        callsign: 'cs',
        firstSeenMs: 100,
        lastSeenMs: 200,
      );
      expect(a, equals(b)); // timestamps not in equality
    });
  });

  group('TakIdentityRegistry', () {
    test('registerMeshNode creates identity', () async {
      await registry.registerMeshNode(0x1A2B3C4D, 'Node-Alpha', 'NA');

      final identity = registry.lookupByNodeNum(0x1A2B3C4D);
      expect(identity, isNotNull);
      expect(identity!.takUid, 'MESHTASTIC-1A2B3C4D');
      expect(identity.callsign, 'Node-Alpha');
      expect(identity.isMeshNode, isTrue);
    });

    test('registerMeshNode persists', () async {
      await registry.registerMeshNode(0xDEADBEEF, 'Dead', 'DB');
      expect(persisted, hasLength(1));
      expect(persisted.first.takUid, 'MESHTASTIC-DEADBEEF');
    });

    test('registerMeshNode preserves override on update', () async {
      await registry.registerMeshNode(0x11111111, 'Original', 'O');
      await registry.setCallsignOverride(0x11111111, 'Custom');

      // Re-register with new long name.
      await registry.registerMeshNode(0x11111111, 'Updated', 'U');

      final identity = registry.lookupByNodeNum(0x11111111);
      expect(identity!.callsign, 'Updated');
      expect(identity.overrideCallsign, 'Custom');
      expect(identity.displayCallsign, 'Custom');
    });

    test('registerTakClient creates identity', () async {
      await registry.registerTakClient('ANDROID-abc123', 'ALPHA-1');

      final identity = registry.lookupByTakUid('ANDROID-abc123');
      expect(identity, isNotNull);
      expect(identity!.callsign, 'ALPHA-1');
      expect(identity.nodeNum, 0);
      expect(identity.isMeshNode, isFalse);
    });

    test('lookupByCallsign is case insensitive', () async {
      await registry.registerMeshNode(0xAAAAAAAA, 'TestNode', 'TN');

      expect(registry.lookupByCallsign('testnode'), isNotNull);
      expect(registry.lookupByCallsign('TESTNODE'), isNotNull);
      expect(registry.lookupByCallsign('TestNode'), isNotNull);
    });

    test('setCallsignOverride updates identity', () async {
      await registry.registerMeshNode(0xBBBBBBBB, 'Radio-1', 'R1');
      await registry.setCallsignOverride(0xBBBBBBBB, 'TEAM-LEAD');

      final identity = registry.lookupByNodeNum(0xBBBBBBBB);
      expect(identity!.displayCallsign, 'TEAM-LEAD');
      expect(identity.callsign, 'Radio-1'); // Original preserved.

      // Lookup by new callsign works.
      expect(registry.lookupByCallsign('TEAM-LEAD'), isNotNull);
    });

    test('setCallsignOverride ignores unknown nodeNum', () async {
      await registry.setCallsignOverride(0xFFFFFFFF, 'Nobody');
      expect(persisted, isEmpty);
    });

    test('loadFromStorage populates registry', () async {
      final preloaded = TakIdentityRegistry(
        persist: (identity) async => persisted.add(identity),
        load: () async => [
          TakIdentity(
            nodeNum: 0x11111111,
            takUid: 'MESHTASTIC-11111111',
            callsign: 'Preloaded',
            firstSeenMs: 1000,
            lastSeenMs: 2000,
          ),
          TakIdentity(
            nodeNum: 0,
            takUid: 'ANDROID-xyz',
            callsign: 'TakUser',
            firstSeenMs: 1000,
            lastSeenMs: 2000,
          ),
        ],
      );

      await preloaded.loadFromStorage();

      expect(preloaded.lookupByNodeNum(0x11111111), isNotNull);
      expect(preloaded.lookupByTakUid('ANDROID-xyz'), isNotNull);
      expect(preloaded.meshNodeCount, 1);
      expect(preloaded.takClientCount, 1);
    });

    test('allIdentities returns all entries', () async {
      await registry.registerMeshNode(0x11111111, 'A', 'a');
      await registry.registerMeshNode(0x22222222, 'B', 'b');
      await registry.registerTakClient('ANDROID-1', 'User1');

      expect(registry.allIdentities, hasLength(3));
    });

    test('clear removes all entries', () async {
      await registry.registerMeshNode(0x11111111, 'A', 'a');
      await registry.registerTakClient('ANDROID-1', 'User1');

      registry.clear();

      expect(registry.lookupByNodeNum(0x11111111), isNull);
      expect(registry.lookupByTakUid('ANDROID-1'), isNull);
      expect(registry.allIdentities, isEmpty);
    });

    test(
      're-registration updates lastSeenMs and preserves firstSeenMs',
      () async {
        await registry.registerMeshNode(0xCCCCCCCC, 'First', 'F');
        final firstSeen = registry.lookupByNodeNum(0xCCCCCCCC)!.firstSeenMs;

        // Small delay to ensure different timestamp.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await registry.registerMeshNode(0xCCCCCCCC, 'Updated', 'U');
        final identity = registry.lookupByNodeNum(0xCCCCCCCC)!;
        expect(identity.firstSeenMs, firstSeen);
        expect(identity.lastSeenMs, greaterThanOrEqualTo(firstSeen));
        expect(identity.callsign, 'Updated');
      },
    );
  });
}
