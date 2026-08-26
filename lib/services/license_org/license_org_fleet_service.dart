// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Thin client wrapper over the four PR1 fleet callables:
//   - enrollFleetDevice   (owner / admin adds a known radio to the org)
//   - updateFleetDevice   (mutable metadata only)
//   - assignFleetDevice   (custody: member / org pool / unassigned)
//   - retireFleetDevice   (soft; the record and its history are kept)
//
// Mirrors LicenseOrgInviteService: an injectable invoker so tests need
// no emulator, and sealed result types so callers switch on the outcome
// instead of inspecting raw FirebaseFunctionsException codes.
//
// The server is the authority for ALL of it - role, org active state,
// fleetAccess capability, assignment invariants, and the canonical
// document id. Nothing here re-implements those checks; this file only
// makes the failures legible to the UI.
//
// PII-safe: never logs uid, orgId, label, purpose or notes.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/logging.dart';
import '../../models/license_org_fleet_device.dart';

abstract class FleetCallableInvoker {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);

  static FleetCallableInvoker firebase() => _FirebaseFleetCallableInvoker();
}

class _FirebaseFleetCallableInvoker implements FleetCallableInvoker {
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }
}

/// Why a fleet mutation was refused.
///
/// Every value maps to a distinct user-facing explanation. `retired` in
/// particular must not be collapsed into `generic`: "this radio was
/// retired" is actionable, whereas "something went wrong" sends the
/// admin round in circles re-tapping Enrol.
enum FleetMutationReason {
  /// Caller is not an owner/admin of the org.
  permissionDenied,

  /// Signed out, or signed in anonymously.
  unauthenticated,

  /// The org is suspended, or has no `fleetAccess` capability.
  orgNotEligible,

  /// Enrolment hit an existing RETIRED record. Deliberately not a
  /// silent reactivation - see PHASE-1-DESIGN.
  deviceRetired,

  /// The target fleet device does not exist.
  notFound,

  /// The assignee is not an active member of this org.
  assigneeNotActiveMember,

  /// Input failed server-side validation (bounds, malformed identity,
  /// contradictory assignment).
  invalidInput,

  /// No network, or the callable could not be reached. Retryable.
  unavailable,

  generic,
}

sealed class FleetMutationResult {
  const FleetMutationResult();
}

class FleetMutationSuccess extends FleetMutationResult {
  final String fleetDeviceId;

  /// True when a new record was created rather than an existing one
  /// being refreshed. Lets the UI say "Added" vs "Already in the fleet".
  final bool created;

  const FleetMutationSuccess({
    required this.fleetDeviceId,
    this.created = false,
  });
}

class FleetMutationFailure extends FleetMutationResult {
  final FleetMutationReason reason;
  final String message;

  const FleetMutationFailure({required this.reason, required this.message});
}

/// Client surface for the fleet callables.
class LicenseOrgFleetService {
  final FleetCallableInvoker _invoker;

  LicenseOrgFleetService({FleetCallableInvoker? invoker})
    : _invoker = invoker ?? FleetCallableInvoker.firebase();

  /// Add a radio SocialMesh already knows to the org's fleet.
  ///
  /// This records organisation metadata ONLY. It does not read, write or
  /// otherwise touch the radio's configuration - the UI says so
  /// explicitly, and there is no code path here that could.
  Future<FleetMutationResult> enroll({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
    String? lastKnownHardware,
    String? lastKnownFirmware,
  }) {
    return _invoke('enrollFleetDevice', {
      'licenseOrgId': licenseOrgId,
      'transport': transport.toWire(),
      'rawIdentity': rawIdentity,
      if (label != null) 'label': label,
      if (purpose != null) 'purpose': purpose,
      if (tags != null) 'tags': tags,
      if (notes != null) 'notes': notes,
      if (lastKnownHardware != null) 'lastKnownHardware': lastKnownHardware,
      if (lastKnownFirmware != null) 'lastKnownFirmware': lastKnownFirmware,
    });
  }

  /// Update mutable metadata. Identity, custody and status are NOT
  /// settable here - the server rejects them as unknown keys.
  Future<FleetMutationResult> update({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
  }) {
    return _invoke('updateFleetDevice', {
      'licenseOrgId': licenseOrgId,
      'transport': transport.toWire(),
      'rawIdentity': rawIdentity,
      if (label != null) 'label': label,
      if (purpose != null) 'purpose': purpose,
      if (tags != null) 'tags': tags,
      if (notes != null) 'notes': notes,
    });
  }

  /// Set custody.
  ///
  /// [assignedUid] must be null for anything other than
  /// [FleetAssignmentKind.member]; the server enforces the same
  /// invariant and rejects contradictions.
  Future<FleetMutationResult> assign({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) {
    return _invoke('assignFleetDevice', {
      'licenseOrgId': licenseOrgId,
      'transport': transport.toWire(),
      'rawIdentity': rawIdentity,
      'assignment': assignment.toWire(),
      'assignedUid': assignment == FleetAssignmentKind.member
          ? assignedUid
          : null,
    });
  }

  /// Soft-retire. The record and its audit history are preserved, and
  /// the device remains retrievable under the retired filter.
  Future<FleetMutationResult> retire({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
  }) {
    return _invoke('retireFleetDevice', {
      'licenseOrgId': licenseOrgId,
      'transport': transport.toWire(),
      'rawIdentity': rawIdentity,
    });
  }

  Future<FleetMutationResult> _invoke(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _invoker.call(name, data);
      final id = result['fleetDeviceId'];
      return FleetMutationSuccess(
        fleetDeviceId: id is String ? id : '',
        created: result['created'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      final reason = _classify(e);
      AppLogging.groupLicensing(
        '[LicenseOrgFleetService] $name refused (reason: ${reason.name})',
      );
      return FleetMutationFailure(reason: reason, message: e.message ?? e.code);
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgFleetService] $name failed '
        '(error class: ${e.runtimeType})',
      );
      return const FleetMutationFailure(
        reason: FleetMutationReason.unavailable,
        message: 'fleet mutation could not be completed',
      );
    }
  }

  /// Maps a callable error onto an actionable reason.
  ///
  /// `failed-precondition` is overloaded server-side, so the message is
  /// consulted to separate the three cases that need different copy:
  /// a retired device, an ineligible org, and a non-member assignee.
  static FleetMutationReason _classify(FirebaseFunctionsException e) {
    final message = (e.message ?? '').toLowerCase();
    switch (e.code) {
      case 'permission-denied':
        // The server uses permission-denied for both "not an admin" and
        // "org lacks the fleet capability"; only the latter mentions
        // fleet access.
        return message.contains('fleet access')
            ? FleetMutationReason.orgNotEligible
            : FleetMutationReason.permissionDenied;
      case 'unauthenticated':
        return FleetMutationReason.unauthenticated;
      case 'not-found':
        return FleetMutationReason.notFound;
      case 'invalid-argument':
        return FleetMutationReason.invalidInput;
      case 'failed-precondition':
        if (message.contains('retired')) {
          return FleetMutationReason.deviceRetired;
        }
        if (message.contains('assignee')) {
          return FleetMutationReason.assigneeNotActiveMember;
        }
        return FleetMutationReason.orgNotEligible;
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
        return FleetMutationReason.unavailable;
      default:
        return FleetMutationReason.generic;
    }
  }
}
