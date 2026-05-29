// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Opaque member-label scheme for license-org admin surfaces. Mirrors
// the roster spec (LICENSE_ORG_ROSTER.md §4): no raw display name or
// email, just an 8-char `#XXXXXX` derived from the first 6 chars of
// the uid. Stable across sessions, opaque to other members, and good
// enough to distinguish people in a small org.
//
// Why shared: used by the Members sheet (revoke + reinstate flows)
// AND by the Seat Usage section on the per-org card. Keeping the
// derivation in one place means a future change to the scheme
// (e.g. a longer prefix, hashed slug) doesn't drift between surfaces.

/// Deterministic opaque label for a member uid. Returns `#------`
/// for an empty input so the row never blanks. The output is
/// uppercase to match the roster's `#9LTXJG` convention.
String licenseOrgMemberLabel(String uid) {
  if (uid.isEmpty) return '#------';
  final prefix = uid.length >= 6 ? uid.substring(0, 6) : uid.padRight(6, '_');
  return '#${prefix.toUpperCase()}';
}

/// Extract the uid from a seat allocation doc id. Backend format
/// (see `seatAllocationDocId` in
/// `backend/functions/src/license_seat_codes.ts` and
/// `backend/functions/src/license_org_invites.ts`):
/// `<orgId>__<uid>__<productId>`.
/// Splits on `__` and returns the middle segment; falls back to the
/// raw input when the format doesn't match so an unknown shape
/// degrades to a less-specific label rather than blanking.
String licenseOrgUidFromAllocationId(String allocationId) {
  if (allocationId.isEmpty) return '';
  final parts = allocationId.split('__');
  if (parts.length != 3) return allocationId;
  return parts[1];
}
