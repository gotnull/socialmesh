// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Where enrolment candidates come from.
//
// Transport availability is kept SEPARATE from candidate contents,
// because an empty list would otherwise conflate four different
// situations the admin needs told apart:
//
//   no protocol active            -> connect a radio first
//   still resolving               -> wait
//   observed, nothing enrollable  -> everything is already in the fleet
//   the source failed             -> not the same as "no radios"
//
// The adapters are deliberately LOSSY. `ObservedRadio` carries only what
// enrolment needs: identity input, display name, transport, the
// local-radio flag, and a hardware/firmware snapshot where the transport
// actually reports one. Battery, SNR, last-seen, position, hops and
// health are all reachable from these sources and are all deliberately
// left behind - passing them through would quietly make this the first
// PR4 telemetry adapter.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/license_org_fleet_device.dart';
import '../../../models/mesh_models.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/license_org_fleet_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import 'fleet_enrol_candidates.dart';

/// Availability of the candidate source, independent of how many
/// candidates it produced.
sealed class FleetCandidateSource {
  const FleetCandidateSource();
}

/// No radio is connected, so there is no protocol to observe through.
/// Distinct from "no radios found": nothing was even asked.
class FleetCandidateSourceNoProtocol extends FleetCandidateSource {
  const FleetCandidateSourceNoProtocol();
}

/// The protocol is active but the fleet or the radio source has not
/// resolved yet. Classifying now would misreport enrolled radios as
/// available, because an unresolved fleet looks empty.
class FleetCandidateSourceLoading extends FleetCandidateSource {
  const FleetCandidateSourceLoading();
}

/// Candidates resolved. May legitimately be empty, which means "nothing
/// observable to enrol" rather than "something went wrong".
class FleetCandidateSourceReady extends FleetCandidateSource {
  final List<FleetEnrolCandidate> candidates;

  const FleetCandidateSourceReady(this.candidates);
}

/// The underlying radio source reported a failure. Never presented as an
/// empty list.
class FleetCandidateSourceUnavailable extends FleetCandidateSource {
  const FleetCandidateSourceUnavailable();
}

/// Flatten the Meshtastic node set into observations.
///
/// Every node the radio knows about is included, not just the connected
/// one - a peer in range may well be an organisation asset. The picker
/// is responsible for saying these are radios SocialMesh can *see*, not
/// radios the organisation owns.
List<ObservedRadio> observedFromMeshtastic(
  Map<int, MeshNode> nodes,
  int? myNodeNum,
) {
  final out = <ObservedRadio>[];
  for (final node in nodes.values) {
    out.add(
      ObservedRadio(
        transport: FleetTransport.meshtastic,
        nodeNum: node.nodeNum,
        displayName: node.displayName,
        hardware: node.hardwareModel,
        firmware: node.firmwareVersion,
        isLocalDevice: myNodeNum != null && node.nodeNum == myNodeNum,
      ),
    );
  }
  return out;
}

/// Flatten the MeshCore contact set into observations.
///
/// MeshCore reports no hardware model and no firmware version per
/// contact, so those stay null rather than being invented from the
/// locally-connected radio's values - attributing this phone's radio
/// hardware to a remote peer would be a fabrication.
///
/// The connected radio itself is added from self-info when available,
/// because it is not part of the contact list but is frequently an
/// organisation asset.
List<ObservedRadio> observedFromMeshCore(
  List<MeshCoreContact> contacts,
  MeshCoreSelfInfo? selfInfo,
) {
  final out = <ObservedRadio>[];

  final selfKey = selfInfo?.pubKey;
  if (selfKey != null && selfKey.isNotEmpty) {
    out.add(
      ObservedRadio(
        transport: FleetTransport.meshCore,
        publicKey: selfKey,
        displayName: selfInfo?.nodeName ?? '',
        isLocalDevice: true,
      ),
    );
  }

  for (final contact in contacts) {
    out.add(
      ObservedRadio(
        transport: FleetTransport.meshCore,
        publicKey: contact.publicKey,
        displayName: contact.displayName,
        isLocalDevice: false,
      ),
    );
  }
  return out;
}

/// Enrolment candidates for [licenseOrgId], sourced from the ACTIVE
/// protocol only.
///
/// Switching protocol replaces the candidate set rather than unioning
/// it, structurally: the switch selects exactly one source, so the
/// previous protocol's observations are never in scope to merge.
final fleetCandidateSourceProvider =
    Provider.family<FleetCandidateSource, String>((ref, licenseOrgId) {
      final protocol = ref.watch(activeProtocolProvider);

      if (protocol == ActiveProtocol.none) {
        return const FleetCandidateSourceNoProtocol();
      }

      // The fleet must be resolved before anything is classified.
      // Against an unresolved (empty-looking) fleet every enrolled radio
      // would read as Available, and the admin would tap into a server
      // refusal.
      final fleetAsync = ref.watch(licenseOrgFleetProvider(licenseOrgId));
      final fleet = fleetAsync.maybeWhen(
        data: (snapshot) => snapshot.devices,
        orElse: () => null,
      );
      if (fleet == null) return const FleetCandidateSourceLoading();

      final List<ObservedRadio> observed;
      switch (protocol) {
        case ActiveProtocol.meshtastic:
          observed = observedFromMeshtastic(
            ref.watch(nodesProvider),
            ref.watch(myNodeNumProvider),
          );
        case ActiveProtocol.meshcore:
          final contactsState = ref.watch(meshCoreContactsProvider);
          if (contactsState.error != null) {
            return const FleetCandidateSourceUnavailable();
          }
          if (contactsState.isLoading) {
            return const FleetCandidateSourceLoading();
          }
          observed = observedFromMeshCore(
            contactsState.contacts,
            ref.watch(meshCoreSelfInfoProvider).selfInfo,
          );
        case ActiveProtocol.none:
          // Unreachable - handled above. Present so the switch stays
          // exhaustive if ActiveProtocol gains a member.
          return const FleetCandidateSourceNoProtocol();
      }

      return FleetCandidateSourceReady(
        buildEnrolCandidates(
          observed: observed,
          fleet: fleet,
          licenseOrgId: licenseOrgId,
        ),
      );
    });
