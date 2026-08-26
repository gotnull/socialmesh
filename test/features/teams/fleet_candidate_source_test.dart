// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Candidate source: protocol scoping and the lossy adapters.
//
// The adapters are tested as pure functions. The point of these tests is
// less "does it map fields" and more "does it refuse to map the fields
// it must not" - every telemetry field reachable from MeshNode is a
// field that could quietly turn this into a PR4 adapter.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/teams/application/fleet_candidate_source.dart';
import 'package:socialmesh/features/teams/application/fleet_enrol_candidates.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshNode _node({
  required int nodeNum,
  String? longName,
  String? hardwareModel,
  String? firmwareVersion,
  int? batteryLevel,
  int? snr,
  DateTime? lastHeard,
  double? latitude,
  double? longitude,
  int? hopCount,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    longName: longName,
    hardwareModel: hardwareModel,
    firmwareVersion: firmwareVersion,
    batteryLevel: batteryLevel,
    snr: snr,
    lastHeard: lastHeard,
    latitude: latitude,
    longitude: longitude,
    hopCount: hopCount,
  );
}

MeshCoreContact _contact(int fill, {String name = 'Peer'}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List<int>.filled(32, fill)),
    name: name,
    type: 1,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime.utc(2026, 8, 15),
    lastMessageAt: DateTime.utc(2026, 8, 15),
    unreadCount: 0,
    flags: 0,
  );
}

void main() {
  group('Meshtastic adapter', () {
    test('maps only what enrolment needs', () {
      final observed = observedFromMeshtastic({
        1: _node(
          nodeNum: 0x81c42d94,
          longName: 'North Gate',
          hardwareModel: 'TRACKER_T1000_E',
          firmwareVersion: '2.7.19',
        ),
      }, null);

      final radio = observed.single;
      expect(radio.transport, FleetTransport.meshtastic);
      expect(radio.nodeNum, 0x81c42d94);
      expect(radio.displayName, 'North Gate');
      expect(radio.hardware, 'TRACKER_T1000_E');
      expect(radio.firmware, '2.7.19');
      expect(radio.publicKey, isNull);
    });

    test('drops every telemetry field, even when populated', () {
      // ObservedRadio has nowhere to put these by design. If a future
      // edit adds a field for one of them, this test is where the PR4
      // boundary gets defended.
      final observed = observedFromMeshtastic({
        1: _node(
          nodeNum: 0x81c42d94,
          longName: 'Loaded',
          batteryLevel: 82,
          snr: 11,
          lastHeard: DateTime.utc(2026, 8, 15),
          latitude: -37.8,
          longitude: 144.9,
          hopCount: 3,
        ),
      }, null);

      final radio = observed.single;
      // The only optional metadata carried is the enrolment snapshot.
      expect(radio.hardware, isNull);
      expect(radio.firmware, isNull);
      // And nothing else exists to inspect - the type has no battery,
      // snr, lastHeard, position or hop fields at all.
      expect(radio.displayName, 'Loaded');
    });

    test('flags the connected radio without excluding it', () {
      final observed = observedFromMeshtastic({
        1: _node(nodeNum: 0x0864, longName: 'Mine'),
        2: _node(nodeNum: 0x74db, longName: 'Theirs'),
      }, 0x0864);

      final mine = observed.firstWhere((r) => r.nodeNum == 0x0864);
      final theirs = observed.firstWhere((r) => r.nodeNum == 0x74db);
      expect(mine.isLocalDevice, isTrue);
      expect(theirs.isLocalDevice, isFalse);
      expect(observed, hasLength(2));
    });

    test('with no known local node, nothing is flagged local', () {
      final observed = observedFromMeshtastic({
        1: _node(nodeNum: 0x0864, longName: 'Mine'),
      }, null);
      expect(observed.single.isLocalDevice, isFalse);
    });

    test('an empty node set yields no observations', () {
      expect(observedFromMeshtastic(const {}, null), isEmpty);
    });
  });

  group('MeshCore adapter', () {
    test('maps contacts without inventing hardware or firmware', () {
      // MeshCore reports neither per contact. Filling them from the
      // locally-connected radio would attribute this phone's hardware
      // to a remote peer.
      final observed = observedFromMeshCore([
        _contact(0xAB, name: 'Peer'),
      ], null);

      final radio = observed.single;
      expect(radio.transport, FleetTransport.meshCore);
      expect(radio.publicKey, hasLength(32));
      expect(radio.hardware, isNull);
      expect(radio.firmware, isNull);
      expect(radio.nodeNum, isNull);
    });

    test('includes the connected radio from self info, flagged local', () {
      final observed = observedFromMeshCore(
        [_contact(0xAB, name: 'Peer')],
        MeshCoreSelfInfo(
          advType: 1,
          txPowerDbm: 0,
          maxLoraTxPower: 0,
          pubKey: Uint8List.fromList(List<int>.filled(32, 0xCD)),
          nodeName: 'My MeshCore',
          rawPayload: Uint8List(0),
        ),
      );

      expect(observed, hasLength(2));
      final local = observed.firstWhere((r) => r.isLocalDevice);
      expect(local.displayName, 'My MeshCore');
      expect(local.publicKey, List<int>.filled(32, 0xCD));
    });

    test('absent self info simply omits the local radio', () {
      final observed = observedFromMeshCore([_contact(0xAB)], null);
      expect(observed, hasLength(1));
      expect(observed.single.isLocalDevice, isFalse);
    });

    test(
      'a malformed key becomes one unsupported candidate, poisoning nothing',
      () {
        // The wrong-length key cannot yield an identity, but the good
        // contact beside it must still be enrollable.
        final observed = [
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: List<int>.filled(8, 1),
            displayName: 'Truncated',
          ),
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: List<int>.filled(32, 2),
            displayName: 'Fine',
          ),
        ];

        final candidates = buildEnrolCandidates(
          observed: observed,
          fleet: const [],
          licenseOrgId: 'acme-team',
        );

        expect(candidates, hasLength(2));
        expect(
          candidates.firstWhere((c) => c.displayName == 'Fine').state,
          FleetCandidateState.available,
        );
        expect(
          candidates.firstWhere((c) => c.displayName == 'Truncated').state,
          FleetCandidateState.unsupported,
        );
      },
    );
  });

  group('source states are distinguishable', () {
    test('the four states are distinct types', () {
      // An empty list must never be the way "no protocol", "loading" or
      // "failed" are expressed - each is its own type so a widget
      // cannot accidentally render them the same way.
      const states = <FleetCandidateSource>[
        FleetCandidateSourceNoProtocol(),
        FleetCandidateSourceLoading(),
        FleetCandidateSourceReady([]),
        FleetCandidateSourceUnavailable(),
      ];
      expect(states.map((s) => s.runtimeType).toSet(), hasLength(4));
    });

    test('ready-but-empty is a legitimate answer, not a failure', () {
      const ready = FleetCandidateSourceReady(<FleetEnrolCandidate>[]);
      expect(ready.candidates, isEmpty);
      expect(ready, isNot(isA<FleetCandidateSourceUnavailable>()));
      expect(ready, isNot(isA<FleetCandidateSourceLoading>()));
    });
  });
}
