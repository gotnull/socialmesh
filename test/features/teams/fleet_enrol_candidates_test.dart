// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Enrolment candidate classification.
//
// The load-bearing properties:
//   - classification is by canonical identity, never display metadata
//   - one canonical radio yields exactly one enrol opportunity
//   - unsupported wins before any other state
//   - a retired record is never offered as available

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/teams/application/fleet_enrol_candidates.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';

const _org = 'acme-team';

LicenseOrgFleetDevice _fleetDevice({
  required String identity,
  FleetDeviceStatus status = FleetDeviceStatus.active,
  FleetTransport transport = FleetTransport.meshtastic,
  String label = 'Enrolled',
}) {
  return LicenseOrgFleetDevice(
    id: fleetDeviceIdFor(licenseOrgId: _org, transportIdentity: identity)!,
    licenseOrgId: _org,
    transport: transport,
    transportIdentity: identity,
    label: label,
    assignedUid: null,
    assignment: FleetAssignmentKind.unassigned,
    purpose: null,
    tags: const [],
    notes: null,
    lastKnownHardware: null,
    lastKnownFirmware: null,
    createdBy: 'admin-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 14),
    status: status,
  );
}

List<int> _key(int fill) => List<int>.filled(32, fill);

List<FleetEnrolCandidate> _build({
  required List<ObservedRadio> observed,
  List<LicenseOrgFleetDevice> fleet = const [],
}) =>
    buildEnrolCandidates(observed: observed, fleet: fleet, licenseOrgId: _org);

void main() {
  group('classification by identity', () {
    test('an unseen radio is available', () {
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'North Gate',
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.available);
      expect(result.single.transportIdentity, 'mt-81c42d94');
      // The callable wants the hex half without the prefix.
      expect(result.single.rawIdentity, '81c42d94');
      expect(result.single.isEnrollable, isTrue);
    });

    test('an enrolled radio is alreadyInFleet', () {
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'North Gate',
          ),
        ],
        fleet: [_fleetDevice(identity: 'mt-81c42d94')],
      );
      expect(result.single.state, FleetCandidateState.alreadyInFleet);
      expect(result.single.isEnrollable, isFalse);
    });

    test('a retired record is never offered as available', () {
      // Offering it would walk the admin into a server refusal, since
      // enrolment deliberately does not resurrect retired records.
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'North Gate',
          ),
        ],
        fleet: [
          _fleetDevice(
            identity: 'mt-81c42d94',
            status: FleetDeviceStatus.retired,
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.retiredInFleet);
      expect(result.single.isEnrollable, isFalse);
    });

    test('a record with an unrecognised status is not offered as new', () {
      // A record exists; enrolment would address it. Fail closed.
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'North Gate',
          ),
        ],
        fleet: [
          _fleetDevice(
            identity: 'mt-81c42d94',
            status: FleetDeviceStatus.unknown,
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.alreadyInFleet);
    });

    test('display metadata never affects classification', () {
      // The radio renamed itself and reports different hardware since
      // enrolment. It is still the same radio.
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'Completely Different Name',
            hardware: 'SOMETHING_ELSE',
            firmware: '9.9.9',
          ),
        ],
        fleet: [_fleetDevice(identity: 'mt-81c42d94', label: 'North Gate')],
      );
      expect(result.single.state, FleetCandidateState.alreadyInFleet);
    });

    test('a different radio with a similar name is still available', () {
      // The inverse: same display name, different identity.
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x0000abcd,
            displayName: 'North Gate',
          ),
        ],
        fleet: [_fleetDevice(identity: 'mt-81c42d94', label: 'North Gate')],
      );
      expect(result.single.state, FleetCandidateState.available);
    });

    test('a fleet record in ANOTHER org does not mask this org', () {
      // byId is keyed on the org-scoped composite, so a record for the
      // same radio in a different org must not classify here.
      final otherOrgDevice = LicenseOrgFleetDevice(
        id: 'other-org__mt-81c42d94',
        licenseOrgId: 'other-org',
        transport: FleetTransport.meshtastic,
        transportIdentity: 'mt-81c42d94',
        label: 'Theirs',
        assignedUid: null,
        assignment: FleetAssignmentKind.unassigned,
        purpose: null,
        tags: const [],
        notes: null,
        lastKnownHardware: null,
        lastKnownFirmware: null,
        createdBy: 'someone',
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
        status: FleetDeviceStatus.active,
      );
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'Ours',
          ),
        ],
        fleet: [otherOrgDevice],
      );
      expect(result.single.state, FleetCandidateState.available);
    });
  });

  group('unsupported wins before every other state', () {
    test('a meshtastic observation with no node number', () {
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.meshtastic,
            displayName: 'Nameless',
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.unsupported);
      expect(result.single.transportIdentity, isNull);
      expect(result.single.rawIdentity, isNull);
    });

    test('a meshcore key of the wrong length', () {
      for (final length in [0, 31, 33]) {
        final result = _build(
          observed: [
            ObservedRadio(
              transport: FleetTransport.meshCore,
              publicKey: List<int>.filled(length, 1),
              displayName: 'Truncated',
            ),
          ],
        );
        expect(
          result.single.state,
          FleetCandidateState.unsupported,
          reason: 'a $length-byte key cannot be a MeshCore identity',
        );
      }
    });

    test('an unknown transport', () {
      final result = _build(
        observed: [
          const ObservedRadio(
            transport: FleetTransport.unknown,
            nodeNum: 0x81c42d94,
            displayName: 'Mystery',
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.unsupported);
    });

    test('unsupported is not deduplicated away', () {
      // Two malformed observations are two separate problems the admin
      // may want to see, and neither has an identity to dedupe on.
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            displayName: 'Broken A',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            displayName: 'Broken B',
          ),
        ],
      );
      expect(result, hasLength(2));
      expect(
        result.every((c) => c.state == FleetCandidateState.unsupported),
        isTrue,
      );
    });
  });

  group('deduplication by canonical identity', () {
    test('the same radio observed twice yields ONE candidate', () {
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'First sighting',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'Second sighting',
          ),
        ],
      );
      expect(result, hasLength(1));
      // First observation wins, so the row does not flicker between
      // refreshes depending on which sighting arrived last.
      expect(result.single.displayName, 'First sighting');
    });

    test('duplicates differing only in display metadata still collapse', () {
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'Name A',
            hardware: 'HW_A',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x81c42d94,
            displayName: 'Name B',
            hardware: 'HW_B',
          ),
        ],
      );
      expect(result, hasLength(1));
    });

    test('a signed and unsigned node number are the same radio', () {
      // -1 and 0xFFFFFFFF are the same 32-bit value. Without the
      // canonical unsigned derivation these would look like two radios.
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: -1,
            displayName: 'Signed',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0xFFFFFFFF,
            displayName: 'Unsigned',
          ),
        ],
      );
      expect(result, hasLength(1));
      expect(result.single.transportIdentity, 'mt-ffffffff');
    });

    test('identical meshcore keys collapse to one candidate', () {
      final result = _build(
        observed: [
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: _key(0xAB),
            displayName: 'First',
          ),
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: _key(0xAB),
            displayName: 'Second',
          ),
        ],
      );
      expect(result, hasLength(1));
      expect(result.single.transportIdentity, 'mc-${'ab' * 32}');
    });

    test('different meshcore keys stay separate', () {
      // A factory reset produces a genuinely different key, and it must
      // appear as a new candidate rather than being inferred as the
      // same radio.
      final result = _build(
        observed: [
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: _key(0xAB),
            displayName: 'Before reset',
          ),
          ObservedRadio(
            transport: FleetTransport.meshCore,
            publicKey: _key(0xCD),
            displayName: 'After reset',
          ),
        ],
      );
      expect(result, hasLength(2));
    });
  });

  group('the local radio', () {
    test('is included, and flagged', () {
      // The connected radio is frequently an organisation asset, so it
      // must be enrollable. The flag exists so the picker can label it,
      // not so it can be filtered out.
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x0864,
            displayName: 'This device',
            isLocalDevice: true,
          ),
        ],
      );
      expect(result.single.state, FleetCandidateState.available);
      expect(result.single.isLocalDevice, isTrue);
    });
  });

  group('ordering', () {
    test('actionable candidates come first, dead ends last', () {
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            displayName: 'zz broken',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x00000002,
            displayName: 'bb enrolled',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x00000003,
            displayName: 'cc retired',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 0x00000004,
            displayName: 'aa available',
          ),
        ],
        fleet: [
          _fleetDevice(identity: 'mt-00000002'),
          _fleetDevice(
            identity: 'mt-00000003',
            status: FleetDeviceStatus.retired,
          ),
        ],
      );

      expect(result.map((c) => c.state), [
        FleetCandidateState.available,
        FleetCandidateState.alreadyInFleet,
        FleetCandidateState.retiredInFleet,
        FleetCandidateState.unsupported,
      ]);
    });

    test('within a state, ordering is alphabetical and case-insensitive', () {
      final result = _build(
        observed: const [
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 1,
            displayName: 'beta',
          ),
          ObservedRadio(
            transport: FleetTransport.meshtastic,
            nodeNum: 2,
            displayName: 'Alpha',
          ),
        ],
      );
      expect(result.map((c) => c.displayName), ['Alpha', 'beta']);
    });
  });

  test('an empty mesh yields no candidates', () {
    expect(_build(observed: const []), isEmpty);
  });
}
