// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for the License Org audit-events preview on the
// mobile Overview screen. Mirrors the web admin's recent-activity
// card.
//
// Provider graph (top-down):
//
//   licenseOrgAuditRepositoryProvider     <- data layer (Firestore by default)
//        |
//        v
//   licenseOrgRecentAuditProvider.family(orgId) - List<LicenseOrgAuditEvent>
//
// Fail-closed everywhere: flag off / signed out / anonymous user /
// suspended org / repository stream error all degrade to an empty
// list. The Overview card hides the section when the list is empty
// so the UI never renders an empty `Recent activity` block.
//
// See docs/engineering/LICENSE_ORG_AUDIT_EVENTS.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../models/license_org.dart';
import '../models/license_org_audit_event.dart';
import '../services/org/license_org_audit_repository.dart';
import 'auth_providers.dart';
import 'license_org_overview_providers.dart';

/// Injection point for [LicenseOrgAuditRepository]. Tests override
/// this with a fake repo; production reads from Firestore.
final licenseOrgAuditRepositoryProvider = Provider<LicenseOrgAuditRepository>((
  ref,
) {
  return FirestoreLicenseOrgAuditRepository();
});

/// Streams the most recent 5 audit events for [orgId]. Yields an
/// empty list whenever any precondition fails - the Overview card
/// uses the empty case to hide the entire `Recent activity` section,
/// so an unauthenticated / suspended / errored state degrades to a
/// clean Overview without an empty placeholder.
final licenseOrgRecentAuditProvider =
    StreamProvider.family<List<LicenseOrgAuditEvent>, String>((
      ref,
      orgId,
    ) async* {
      if (!AppFeatureFlags.isGroupLicensingEnabled) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }
      if (orgId.isEmpty) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      final user = ref.watch(currentUserProvider);
      if (user == null || user.isAnonymous || user.uid.isEmpty) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      // Defence-in-depth suspended-org guard. Audit rules already
      // allow reads for members of an active org; mirroring the
      // gate here keeps the UI rendering the suspended state
      // explanatory copy instead of an empty audit section.
      final orgAsync = ref.watch(licenseOrgProvider(orgId));
      final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
      if (org != null && org.status != LicenseOrgStatus.active) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      final repo = ref.watch(licenseOrgAuditRepositoryProvider);
      yield const <LicenseOrgAuditEvent>[];

      try {
        await for (final events in repo.recentEventsForOrg(orgId, limit: 5)) {
          yield events;
        }
      } catch (e) {
        AppLogging.groupLicensing(
          '[LicenseOrgAudit] provider stream threw - failing closed '
          '(error class: ${e.runtimeType})',
        );
        yield const <LicenseOrgAuditEvent>[];
      }
    });

/// Streams the audit rows for [orgId] filtered to manual seat
/// revocations (`seat_revoked_manual`). Used by the License Org
/// Members sheet to surface a "Revoked seats" history section so
/// owners can see who they removed and when, without leaving the
/// roster.
///
/// Fail-closed mirrors [licenseOrgRecentAuditProvider]: flag off /
/// signed out / anonymous user / suspended org / repo error all
/// degrade to an empty list. Capped at 100 rows to bound payload —
/// owners revoking past that have a much bigger problem than
/// scrollable history, and the full audit log screen surfaces
/// everything via the paginated provider.
final licenseOrgRevokedSeatsProvider =
    StreamProvider.family<List<LicenseOrgAuditEvent>, String>((
      ref,
      orgId,
    ) async* {
      if (!AppFeatureFlags.isGroupLicensingEnabled) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }
      if (orgId.isEmpty) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      final user = ref.watch(currentUserProvider);
      if (user == null || user.isAnonymous || user.uid.isEmpty) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      // Mirror the suspended-org guard from the recent-audit
      // provider. The roster sheet hides Members entirely on a
      // suspended org and the same gate applies here so a re-
      // enabled org doesn't briefly leak revoke history.
      final orgAsync = ref.watch(licenseOrgProvider(orgId));
      final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
      if (org != null && org.status != LicenseOrgStatus.active) {
        yield const <LicenseOrgAuditEvent>[];
        return;
      }

      final repo = ref.watch(licenseOrgAuditRepositoryProvider);
      yield const <LicenseOrgAuditEvent>[];

      try {
        await for (final events in repo.recentEventsForOrg(orgId, limit: 100)) {
          yield events
              .where(
                (e) =>
                    e.action == LicenseOrgAuditAction.seatRevokedManual &&
                    e.outcome == LicenseOrgAuditOutcome.success,
              )
              .toList(growable: false);
        }
      } catch (e) {
        AppLogging.groupLicensing(
          '[LicenseOrgAudit] revoked-seats stream threw - failing closed '
          '(error class: ${e.runtimeType})',
        );
        yield const <LicenseOrgAuditEvent>[];
      }
    });

/// Immutable state held by [LicenseOrgAuditLogNotifier]. The notifier
/// accumulates pages so the screen renders a single growing list.
class LicenseOrgAuditLogState {
  final List<LicenseOrgAuditEvent> events;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? cursor;

  const LicenseOrgAuditLogState({
    required this.events,
    required this.hasMore,
    required this.isLoadingMore,
    required this.cursor,
  });

  static const empty = LicenseOrgAuditLogState(
    events: <LicenseOrgAuditEvent>[],
    hasMore: false,
    isLoadingMore: false,
    cursor: null,
  );

  LicenseOrgAuditLogState copyWith({
    List<LicenseOrgAuditEvent>? events,
    bool? hasMore,
    bool? isLoadingMore,
    Object? cursor,
    bool clearCursor = false,
  }) {
    return LicenseOrgAuditLogState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
    );
  }
}

/// Paginated audit-log feed for the License Org Audit Log screen.
/// Renders the first page on `build`; the screen calls [loadMore]
/// to append subsequent pages. Pagination is cursor-based via the
/// repository's [LicenseOrgAuditRepository.fetchPage] contract.
///
/// Fail-closed: every fail path (flag off / signed out / suspended
/// org / repo error) lands [LicenseOrgAuditLogState.empty] and the
/// `Load more` button stays disabled.
///
/// Riverpod 3.x family pattern: the notifier itself is a plain
/// [AsyncNotifier] that carries the family argument ([orgId]) as a
/// constructor field. The family-builder factory below threads
/// [orgId] in via `LicenseOrgAuditLogNotifier.new`.
class LicenseOrgAuditLogNotifier
    extends AsyncNotifier<LicenseOrgAuditLogState> {
  static const int pageSize = 50;

  final String orgId;

  LicenseOrgAuditLogNotifier(this.orgId);

  @override
  Future<LicenseOrgAuditLogState> build() async {
    if (!AppFeatureFlags.isGroupLicensingEnabled) {
      return LicenseOrgAuditLogState.empty;
    }
    if (orgId.isEmpty) {
      return LicenseOrgAuditLogState.empty;
    }
    final user = ref.watch(currentUserProvider);
    if (user == null || user.isAnonymous || user.uid.isEmpty) {
      return LicenseOrgAuditLogState.empty;
    }
    // Suspended-org gating lives at the Firestore rule layer plus the
    // overview-card entry point that doesn't surface the "View all"
    // tap for suspended orgs. The paginated notifier intentionally
    // does NOT ref.watch the org stream - any subsequent emission
    // would invalidate the notifier and discard pages the user has
    // already loaded via loadMore().

    final repo = ref.read(licenseOrgAuditRepositoryProvider);
    try {
      final page = await repo.fetchPage(orgId, limit: pageSize);
      return LicenseOrgAuditLogState(
        events: List<LicenseOrgAuditEvent>.unmodifiable(page.events),
        hasMore: page.hasMore,
        isLoadingMore: false,
        cursor: page.cursor,
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgAudit] paginated build threw - failing closed '
        '(error class: ${e.runtimeType})',
      );
      return LicenseOrgAuditLogState.empty;
    }
  }

  /// Fetches and appends the next page. No-op if the previous page
  /// reported `hasMore: false` OR another load is already in flight.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    // Surface the loading flag while keeping the existing events
    // visible (so the screen doesn't flicker to a spinner).
    state = AsyncData(current.copyWith(isLoadingMore: true));

    final repo = ref.read(licenseOrgAuditRepositoryProvider);
    try {
      final page = await repo.fetchPage(
        orgId,
        startAfter: current.cursor,
        limit: pageSize,
      );

      final combined = <LicenseOrgAuditEvent>[
        ...current.events,
        ...page.events,
      ];
      state = AsyncData(
        LicenseOrgAuditLogState(
          events: List<LicenseOrgAuditEvent>.unmodifiable(combined),
          hasMore: page.hasMore,
          isLoadingMore: false,
          cursor: page.cursor ?? current.cursor,
        ),
      );
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgAudit] loadMore threw - failing closed '
        '(error class: ${e.runtimeType})',
      );
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final licenseOrgAuditLogProvider =
    AsyncNotifierProvider.family<
      LicenseOrgAuditLogNotifier,
      LicenseOrgAuditLogState,
      String
    >(LicenseOrgAuditLogNotifier.new);
