// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Enrolment candidates: what the admin may add to the fleet right now.
//
// Pure function over three inputs - radios observed through the ACTIVE
// protocol, the current fleet snapshot, and the org id. No I/O, no
// providers, so the whole matrix is testable without a widget tree.
//
// Two framing rules this file exists to enforce:
//
//   1. These are "radios currently known through the active protocol",
//      NOT "your radios". `nodesProvider` is full of remote peers the
//      organisation has no relationship with - anyone within radio range
//      shows up. Implying ownership before enrolment would be wrong both
//      operationally and commercially.
//
//   2. Classification is by CANONICAL IDENTITY only, never by display
//      metadata. A radio that renamed itself, or whose MeshCore key
//      arrives in a different case, is the same radio.
//
// See docs/teams/PHASE-1-DESIGN.md.

import '../../../models/license_org_fleet_device.dart';

/// One radio as currently observed through the active protocol.
///
/// Transport-neutral on purpose: the Meshtastic and MeshCore models are
/// parallel hierarchies with no shared supertype, so the adapters
/// flatten them here rather than the candidate logic knowing about
/// either.
class ObservedRadio {
  final FleetTransport transport;

  /// Meshtastic node number. Null for MeshCore.
  final int? nodeNum;

  /// MeshCore public key bytes. Null for Meshtastic.
  final List<int>? publicKey;

  /// What to show the admin. Never used for identity.
  final String displayName;

  /// Hardware/firmware as last observed, when the transport reports
  /// them. MeshCore reports neither.
  final String? hardware;
  final String? firmware;

  /// True for the radio this phone is connected to. Surfaced so the
  /// picker can label it, not to exclude it - the local radio is
  /// frequently an organisation asset.
  final bool isLocalDevice;

  const ObservedRadio({
    required this.transport,
    required this.displayName,
    this.nodeNum,
    this.publicKey,
    this.hardware,
    this.firmware,
    this.isLocalDevice = false,
  });
}

/// Why a candidate can or cannot be enrolled.
///
/// Resolved BEFORE the admin taps, so nobody selects a radio only to be
/// refused after submitting.
enum FleetCandidateState {
  /// No canonical identity can be derived - a malformed node number, a
  /// MeshCore key of the wrong length, or a transport this build does
  /// not understand. Never enrollable.
  unsupported,

  /// A retired fleet record already exists for this identity. Enrolment
  /// would be refused server-side; reactivation is a separate explicit
  /// action that does not exist yet.
  retiredInFleet,

  /// Already in service in this org's fleet.
  alreadyInFleet,

  /// Enrollable now.
  available,
}

/// A radio the admin may consider adding to the fleet.
class FleetEnrolCandidate {
  /// Canonical transport identity, e.g. `mt-81c42d94`. Null only when
  /// [state] is [FleetCandidateState.unsupported].
  final String? transportIdentity;

  /// The hex half the enrol callable expects, without the prefix. Null
  /// for unsupported candidates.
  final String? rawIdentity;

  final FleetTransport transport;
  final String displayName;
  final String? observedHardware;
  final String? observedFirmware;
  final bool isLocalDevice;
  final FleetCandidateState state;

  const FleetEnrolCandidate({
    required this.transportIdentity,
    required this.rawIdentity,
    required this.transport,
    required this.displayName,
    required this.observedHardware,
    required this.observedFirmware,
    required this.isLocalDevice,
    required this.state,
  });

  bool get isEnrollable => state == FleetCandidateState.available;
}

/// Sort order: actionable first, dead ends last.
int _stateRank(FleetCandidateState state) => switch (state) {
  FleetCandidateState.available => 0,
  FleetCandidateState.alreadyInFleet => 1,
  FleetCandidateState.retiredInFleet => 2,
  FleetCandidateState.unsupported => 3,
};

/// Build the candidate list.
///
/// [fleet] must be the active+retired union, which is what
/// `licenseOrgFleetProvider` emits. Passing only the active half would
/// misclassify retired records as [FleetCandidateState.available] and
/// walk the admin into a server refusal.
///
/// Deduplicates on canonical identity using the same
/// [fleetDeviceIdFor] derivation the rest of the system uses, so a
/// source that emits the same radio twice yields one enrol opportunity
/// rather than two. First observation wins; later duplicates are
/// dropped rather than merged, because merging display metadata from an
/// arbitrary second sighting would make the row unstable between
/// refreshes.
List<FleetEnrolCandidate> buildEnrolCandidates({
  required List<ObservedRadio> observed,
  required List<LicenseOrgFleetDevice> fleet,
  required String licenseOrgId,
}) {
  // Index the fleet by canonical id once.
  final byId = <String, LicenseOrgFleetDevice>{
    for (final device in fleet) device.id: device,
  };

  final seenIdentities = <String>{};
  final candidates = <FleetEnrolCandidate>[];

  for (final radio in observed) {
    final identity = _canonicalIdentity(radio);

    if (identity == null) {
      // Unsupported wins before every other classification: without an
      // identity there is nothing to look up, so no other state is even
      // computable.
      candidates.add(
        FleetEnrolCandidate(
          transportIdentity: null,
          rawIdentity: null,
          transport: radio.transport,
          displayName: radio.displayName,
          observedHardware: radio.hardware,
          observedFirmware: radio.firmware,
          isLocalDevice: radio.isLocalDevice,
          state: FleetCandidateState.unsupported,
        ),
      );
      continue;
    }

    if (!seenIdentities.add(identity)) continue;

    final fleetId = fleetDeviceIdFor(
      licenseOrgId: licenseOrgId,
      transportIdentity: identity,
    );
    final existing = fleetId == null ? null : byId[fleetId];

    final state = switch (existing?.status) {
      null => FleetCandidateState.available,
      FleetDeviceStatus.retired => FleetCandidateState.retiredInFleet,
      // An active record, or one whose status this build does not
      // recognise. Either way a record exists and enrolment would
      // address it, so do not offer it as new.
      _ => FleetCandidateState.alreadyInFleet,
    };

    candidates.add(
      FleetEnrolCandidate(
        transportIdentity: identity,
        rawIdentity: identity.substring(3),
        transport: radio.transport,
        displayName: radio.displayName,
        observedHardware: radio.hardware,
        observedFirmware: radio.firmware,
        isLocalDevice: radio.isLocalDevice,
        state: state,
      ),
    );
  }

  candidates.sort((a, b) {
    final byState = _stateRank(a.state).compareTo(_stateRank(b.state));
    if (byState != 0) return byState;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });

  return List<FleetEnrolCandidate>.unmodifiable(candidates);
}

/// Canonical identity for an observation, or null when none can be
/// derived.
String? _canonicalIdentity(ObservedRadio radio) {
  switch (radio.transport) {
    case FleetTransport.meshtastic:
      final nodeNum = radio.nodeNum;
      if (nodeNum == null) return null;
      return fleetMeshtasticIdentity(nodeNum);
    case FleetTransport.meshCore:
      final key = radio.publicKey;
      if (key == null) return null;
      // Returns null on a wrong-length key. A MeshCore factory reset
      // produces a genuinely different key, and SocialMesh has no way
      // to know it is the same physical radio - that reappears here as
      // a new candidate, which is honest rather than inferred.
      return fleetMeshCoreIdentity(key);
    case FleetTransport.unknown:
      return null;
  }
}
