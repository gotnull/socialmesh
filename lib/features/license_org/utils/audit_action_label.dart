// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// One mapping from a licensing audit action to its label.
//
// Previously duplicated between the audit log screen and the org
// overview card. They drifted the moment the fleet actions gained real
// copy: the screen was updated, the card was not, and an enrolment that
// read "Radio added to Fleet" in one place still read "Other event" in
// the other. One definition, two callers.
//
// The switch is exhaustive with no default, so a new action is a compile
// error until it is given a label in BOTH surfaces at once.

import '../../../l10n/app_localizations.dart';
import '../../../models/license_org_audit_event.dart';

String licenseOrgAuditActionLabel(
  AppLocalizations l10n,
  LicenseOrgAuditAction a,
) {
  switch (a) {
    case LicenseOrgAuditAction.seatCodeMinted:
      return l10n.licenseOrgAuditActionSeatCodeMinted;
    case LicenseOrgAuditAction.seatCodeRedeemed:
      return l10n.licenseOrgAuditActionSeatCodeRedeemed;
    case LicenseOrgAuditAction.seatCodeReplayed:
      return l10n.licenseOrgAuditActionSeatCodeReplayed;
    case LicenseOrgAuditAction.seatRevokedManual:
      return l10n.licenseOrgAuditActionSeatRevokedManual;
    case LicenseOrgAuditAction.seatReplacementMinted:
      return l10n.licenseOrgAuditActionSeatReplacementMinted;
    case LicenseOrgAuditAction.seatReinstated:
      return l10n.licenseOrgAuditActionSeatReinstated;
    case LicenseOrgAuditAction.memberInvited:
      return l10n.licenseOrgAuditActionMemberInvited;
    case LicenseOrgAuditAction.memberJoined:
      return l10n.licenseOrgAuditActionMemberJoined;
    case LicenseOrgAuditAction.orgPurchased:
      return l10n.licenseOrgAuditActionOrgPurchased;
    case LicenseOrgAuditAction.orgOwnerCollision:
      return l10n.licenseOrgAuditActionOrgOwnerCollision;
    case LicenseOrgAuditAction.orgSeatRevokedRefund:
      return l10n.licenseOrgAuditActionOrgSeatRevokedRefund;
    case LicenseOrgAuditAction.orgSuspendedDrained:
      return l10n.licenseOrgAuditActionOrgSuspendedDrained;
    case LicenseOrgAuditAction.licenseOrgRenamed:
      return l10n.licenseOrgAuditActionLicenseOrgRenamed;
    case LicenseOrgAuditAction.fleetDeviceEnrolled:
      return l10n.licenseOrgAuditActionFleetDeviceEnrolled;
    case LicenseOrgAuditAction.fleetDeviceUpdated:
      return l10n.licenseOrgAuditActionFleetDeviceUpdated;
    case LicenseOrgAuditAction.fleetDeviceAssigned:
      return l10n.licenseOrgAuditActionFleetDeviceAssigned;
    case LicenseOrgAuditAction.fleetDeviceRetired:
      return l10n.licenseOrgAuditActionFleetDeviceRetired;
    case LicenseOrgAuditAction.pilotLicenseOrgProvisioned:
      return l10n.licenseOrgAuditActionPilotLicenseOrgProvisioned;
    // Only a wire value this build does not recognise falls through to
    // the generic label now.
    case LicenseOrgAuditAction.unknown:
      return l10n.licenseOrgAuditActionUnknown;
  }
}
