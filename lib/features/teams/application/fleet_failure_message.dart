// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// One mapping from a fleet mutation reason to the copy the admin sees.
//
// Shared by every fleet surface on purpose. Two sheets each keeping
// their own switch would drift, and a reason that gained a distinct
// explanation in one place would keep reading as "Something went wrong"
// in the other.
//
// The switch is exhaustive with no default branch, so a new
// [FleetMutationReason] is a compile error until it is given honest
// copy rather than silently collapsing into the generic message.

import '../../../l10n/app_localizations.dart';
import '../../../services/license_org/license_org_fleet_service.dart';

String fleetFailureMessage(AppLocalizations l10n, FleetMutationReason reason) {
  return switch (reason) {
    FleetMutationReason.deviceRetired => l10n.fleetErrorDeviceRetired,
    FleetMutationReason.permissionDenied ||
    FleetMutationReason.unauthenticated => l10n.fleetErrorPermissionDenied,
    FleetMutationReason.orgNotEligible => l10n.fleetErrorOrgNotEligible,
    FleetMutationReason.assigneeNotActiveMember =>
      l10n.fleetErrorAssigneeNotMember,
    FleetMutationReason.invalidInput => l10n.fleetErrorInvalidInput,
    FleetMutationReason.unavailable => l10n.fleetErrorUnavailable,
    // `notFound` reaches the admin as the generic message deliberately:
    // a fleet record the server cannot find is not something they can
    // act on differently from any other unexpected refusal.
    FleetMutationReason.notFound ||
    FleetMutationReason.generic => l10n.fleetErrorGeneric,
  };
}
