// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Data layer for the License Org audit-events collection
// (slice N+2 + the recent-activity preview added to the mobile
// Overview card).
//
// Only one public contract: stream the most recent N audit events for
// a given license org, ordered newest first. Implementations MUST
// fail closed: errored streams or malformed rows degrade to an empty
// list rather than throw.
//
// IMPORTANT - reads the licensing namespace
// (`license_org_audit_events/`). Not related to the enterprise
// multi-tenancy `orgs/` namespace.
//
// See docs/engineering/LICENSE_ORG_AUDIT_EVENTS.md.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logging.dart';
import '../../models/license_org_audit_event.dart';

/// A single page of audit events plus the cursor needed to fetch
/// the next page. The cursor is intentionally opaque (`Object?`) so
/// callers don't depend on Firestore's DocumentSnapshot type; tests
/// pass a sentinel value (an int or a model) through the same field.
class LicenseOrgAuditLogPage {
  /// The events in this page, ordered `tsServer desc`.
  final List<LicenseOrgAuditEvent> events;

  /// Opaque cursor pointing to the last document in [events]. Pass
  /// this value back as `startAfter` to fetch the next page. Null
  /// when there are no events.
  final Object? cursor;

  /// True when the page returned exactly [LicenseOrgAuditRepository]'s
  /// requested `limit` rows, suggesting more rows exist beyond it.
  /// False signals the caller to disable "Load more".
  final bool hasMore;

  const LicenseOrgAuditLogPage({
    required this.events,
    required this.cursor,
    required this.hasMore,
  });

  static const empty = LicenseOrgAuditLogPage(
    events: <LicenseOrgAuditEvent>[],
    cursor: null,
    hasMore: false,
  );
}

/// Read-only data layer for `license_org_audit_events/`.
///
/// Two surfaces:
///   - [recentEventsForOrg]: streams the small preview list rendered
///     on the mobile Overview card. Live; re-emits on writes.
///   - [fetchPage]: one-shot Future used by the paginated audit-log
///     screen. Cursor-based.
///
/// Both fail closed - errored Firestore reads degrade to an empty
/// page / list rather than rethrow.
abstract class LicenseOrgAuditRepository {
  /// Emits the most recent [limit] audit events for [orgId], ordered
  /// `tsServer desc`. Re-emits on every underlying change. Empty
  /// list on missing org, suspended-org Firestore-rule denial, or
  /// any underlying error.
  ///
  /// Default [limit] is 5 to match the Overview card's preview
  /// space; future drill-in surfaces can request more.
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  });

  /// Fetch one page of audit events for [orgId]. Pass [startAfter]
  /// null for the first page; for subsequent pages, pass the
  /// `cursor` returned by the previous call.
  ///
  /// Returns an empty page (with `hasMore: false`) on any error path,
  /// matching the fail-closed contract used elsewhere in this
  /// namespace.
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  });
}

/// Firestore-backed implementation.
///
/// Uses the existing composite index `(licenseOrgId asc,
/// tsServer desc)` shipped with slice N+2. No new indexes required.
class FirestoreLicenseOrgAuditRepository implements LicenseOrgAuditRepository {
  final FirebaseFirestore _firestore;

  FirestoreLicenseOrgAuditRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  }) {
    if (orgId.isEmpty) {
      return Stream.value(const <LicenseOrgAuditEvent>[]);
    }
    if (limit <= 0) {
      return Stream.value(const <LicenseOrgAuditEvent>[]);
    }

    final query = _firestore
        .collection('license_org_audit_events')
        .where('licenseOrgId', isEqualTo: orgId)
        .orderBy('tsServer', descending: true)
        .limit(limit)
        .withConverter<LicenseOrgAuditEvent?>(
          fromFirestore: (snapshot, _) =>
              LicenseOrgAuditEvent.fromFirestore(snapshot),
          toFirestore: (_, _) =>
              throw UnsupportedError('Audit events are server-write only'),
        );

    return query
        .snapshots()
        .map((snap) {
          // Drop nulls from malformed rows so consumers never branch on
          // partial wire data.
          return snap.docs
              .map((d) => d.data())
              .whereType<LicenseOrgAuditEvent>()
              .toList(growable: false);
        })
        .handleError((Object err, StackTrace _) {
          // Fail closed: error path yields an empty list, never rethrows.
          // Permission-denied (e.g. a member viewing an org whose audit
          // rules block non-admins) is the common case here.
          AppLogging.groupLicensing(
            '[LicenseOrgAudit] stream threw - failing closed '
            '(error class: ${err.runtimeType})',
          );
        });
  }

  @override
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  }) async {
    if (orgId.isEmpty || limit <= 0) {
      return LicenseOrgAuditLogPage.empty;
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('license_org_audit_events')
        .where('licenseOrgId', isEqualTo: orgId)
        .orderBy('tsServer', descending: true)
        .limit(limit);

    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }

    try {
      final snap = await query.get();
      final events = snap.docs
          .map(
            (d) => LicenseOrgAuditEvent.fromMap(
              d.id,
              d.data() as Map<String, dynamic>?,
            ),
          )
          .whereType<LicenseOrgAuditEvent>()
          .toList(growable: false);
      // Cursor is the LAST raw doc so the next call can pass it
      // unchanged. Null when the page is empty (nothing to paginate
      // past).
      final cursor = snap.docs.isEmpty ? null : snap.docs.last;
      return LicenseOrgAuditLogPage(
        events: events,
        cursor: cursor,
        hasMore: snap.docs.length == limit,
      );
    } catch (err) {
      AppLogging.groupLicensing(
        '[LicenseOrgAudit] fetchPage threw - failing closed '
        '(error class: ${err.runtimeType})',
      );
      return LicenseOrgAuditLogPage.empty;
    }
  }
}
