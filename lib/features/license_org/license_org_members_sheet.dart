// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// License Org Members sheet. Read-only roster reachable from the
// "View members" action on the License Org Overview screen's per-org
// card. Spec: docs/engineering/LICENSE_ORG_ROSTER.md.
//
// Privacy contract (load-bearing, see spec section 3):
//   - Members see other members as opaque "#XXXXXX" labels derived
//     from the first 6 chars of the uid. NEVER raw display name or
//     email.
//   - Suspended orgs return an empty roster + an explanatory empty
//     state. No member data is surfaced.
//   - Revoked members are filtered at the provider level and never
//     appear in this sheet.
//
// Bottom-sheet shape: AppBottomSheet.showScrollable (per the
// canonical "content-heavy sheet" rule in CLAUDE.md). The inner
// ListView MUST be wired to widget.scrollController or drag-to-
// dismiss breaks.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../../models/license_org.dart';
import '../../models/license_org_audit_event.dart';
import '../../models/license_org_membership.dart';
import '../../providers/auth_providers.dart';
import '../../providers/license_org_audit_providers.dart';
import '../../providers/license_org_members_providers.dart';
import '../../providers/license_org_overview_providers.dart';
import '../../providers/seat_allocation_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/license_org/license_org_seat_service.dart';
import '../../utils/snackbar.dart';
import 'utils/member_label.dart';
import 'widgets/revoke_seat_confirm_sheet.dart';

class LicenseOrgMembersSheet extends ConsumerStatefulWidget {
  final String licenseOrgId;
  final ScrollController scrollController;

  const LicenseOrgMembersSheet({
    required this.licenseOrgId,
    required this.scrollController,
    super.key,
  });

  /// Open the sheet as a content-heavy `AppBottomSheet.showScrollable`.
  /// Caller passes the org id; the sheet reads its own data via
  /// `licenseOrgMembersProvider`. The flag gate is applied at the
  /// provider level, so this method is safe to call unconditionally.
  static Future<void> show(BuildContext context, String licenseOrgId) {
    return AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (controller) => LicenseOrgMembersSheet(
        licenseOrgId: licenseOrgId,
        scrollController: controller,
      ),
    );
  }

  @override
  ConsumerState<LicenseOrgMembersSheet> createState() =>
      _LicenseOrgMembersSheetState();
}

class _LicenseOrgMembersSheetState extends ConsumerState<LicenseOrgMembersSheet>
    with LifecycleSafeMixin<LicenseOrgMembersSheet> {
  bool _revoking = false;
  bool _reinstating = false;

  Future<void> _onReinstateTapped(String allocationId) async {
    if (_reinstating) return;
    final l10n = context.l10n;

    safeSetState(() => _reinstating = true);
    try {
      final service = LicenseOrgSeatService();
      final result = await service.reinstateSeat(
        licenseOrgId: widget.licenseOrgId,
        allocationId: allocationId,
      );
      if (!mounted) return;
      switch (result) {
        case ReinstateSeatSuccess(:final alreadyActive):
          await ref
              .read(hapticServiceProvider)
              .trigger(alreadyActive ? HapticType.light : HapticType.success);
          if (!mounted) return;
          safeShowSnackBar(
            alreadyActive
                ? l10n.licenseOrgMembersReinstateAlreadyActive
                : l10n.licenseOrgMembersReinstateSuccess,
            type: alreadyActive ? SnackBarType.info : SnackBarType.success,
          );
        case ReinstateSeatFailure(:final reason):
          await ref.read(hapticServiceProvider).trigger(HapticType.error);
          if (!mounted) return;
          safeShowSnackBar(
            _reinstateErrorMessage(l10n, reason),
            type: SnackBarType.error,
          );
      }
    } finally {
      if (mounted) safeSetState(() => _reinstating = false);
    }
  }

  String _reinstateErrorMessage(
    AppLocalizations l10n,
    ReinstateSeatReason reason,
  ) {
    switch (reason) {
      case ReinstateSeatReason.permissionDenied:
        return l10n.licenseOrgMembersReinstateErrorPermission;
      case ReinstateSeatReason.rateLimited:
        return l10n.licenseOrgMembersReinstateErrorRateLimit;
      case ReinstateSeatReason.overCapacity:
        return l10n.licenseOrgMembersReinstateErrorOverCapacity;
      case ReinstateSeatReason.notFound:
      case ReinstateSeatReason.unauthenticated:
      case ReinstateSeatReason.orgSuspended:
      case ReinstateSeatReason.generic:
        return l10n.licenseOrgMembersReinstateErrorGeneric;
    }
  }

  Future<void> _onRevokeTapped(LicenseOrgMembership member) async {
    if (_revoking) return;
    final l10n = context.l10n;
    final memberLabel = licenseOrgMemberLabel(member.uid);

    // Confirm-then-act. Cancel returns null/false; confirm returns
    // true. Sheet child pops itself with the chosen value so the
    // parent state's `mounted` guard does not race the sheet's
    // teardown.
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: RevokeSeatConfirmSheet(memberLabel: memberLabel),
    );
    if (confirmed != true || !mounted) return;

    safeSetState(() => _revoking = true);
    try {
      final allocationId = seatAllocationDocId(
        licenseOrgId: widget.licenseOrgId,
        uid: member.uid,
        productId: communityPackSeatProductId,
      );
      final service = LicenseOrgSeatService();
      final result = await service.revokeSeat(
        licenseOrgId: widget.licenseOrgId,
        allocationId: allocationId,
      );
      if (!mounted) return;
      switch (result) {
        case RevokeSeatSuccess(:final alreadyRevoked):
          await ref
              .read(hapticServiceProvider)
              .trigger(alreadyRevoked ? HapticType.light : HapticType.success);
          if (!mounted) return;
          safeShowSnackBar(
            alreadyRevoked
                ? l10n.licenseOrgMembersRevokeAlreadyRevoked
                : l10n.licenseOrgMembersRevokeSuccess,
            type: alreadyRevoked ? SnackBarType.info : SnackBarType.success,
          );
        case RevokeSeatFailure(:final reason):
          await ref.read(hapticServiceProvider).trigger(HapticType.error);
          if (!mounted) return;
          safeShowSnackBar(
            _revokeErrorMessage(l10n, reason),
            type: SnackBarType.error,
          );
      }
    } finally {
      if (mounted) safeSetState(() => _revoking = false);
    }
  }

  String _revokeErrorMessage(AppLocalizations l10n, RevokeSeatReason reason) {
    switch (reason) {
      case RevokeSeatReason.permissionDenied:
        return l10n.licenseOrgMembersRevokeErrorPermission;
      case RevokeSeatReason.rateLimited:
        return l10n.licenseOrgMembersRevokeErrorRateLimit;
      case RevokeSeatReason.notFound:
      case RevokeSeatReason.unauthenticated:
      case RevokeSeatReason.generic:
        return l10n.licenseOrgMembersRevokeErrorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orgAsync = ref.watch(licenseOrgProvider(widget.licenseOrgId));
    final membersAsync = ref.watch(
      licenseOrgMembersProvider(widget.licenseOrgId),
    );
    final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
    final currentUid = ref.watch(currentUserProvider)?.uid;

    final isSuspended = org != null && org.status != LicenseOrgStatus.active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row: title on the left, count chip on the right.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing16,
            AppTheme.spacing24,
            AppTheme.spacing8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.licenseOrgMembersTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              // Count chip mirrors the active-members filter (see
              // the ListView body below): we drop members whose seat
              // is revoked but whose membership doc is still `active`
              // per the manual-revoke spec, so the badge stays
              // consistent with the visible rows.
              membersAsync.maybeWhen(
                data: (members) {
                  final activeUids = ref
                      .watch(
                        licenseOrgActiveSeatHolderUidsProvider(
                          widget.licenseOrgId,
                        ),
                      )
                      .maybeWhen(
                        data: (s) => s,
                        orElse: () => const <String>{},
                      );
                  final active = members
                      .where((m) => activeUids.contains(m.uid))
                      .length;
                  return _CountChip(count: active);
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.border),
        Expanded(
          child: membersAsync.when(
            loading: () =>
                _LoadingSkeleton(scrollController: widget.scrollController),
            error: (err, _) {
              return _ErrorState(
                scrollController: widget.scrollController,
                onRetry: () => ref.invalidate(
                  licenseOrgMembersProvider(widget.licenseOrgId),
                ),
              );
            },
            data: (rawMembers) {
              if (isSuspended) {
                return _SuspendedState(
                  scrollController: widget.scrollController,
                );
              }
              // Revoked seats history. Watched at the same level as
              // the active members stream so the section can mount /
              // dismount live without re-keying the ListView. An
              // empty list (no revocations yet, OR the rules / flag
              // block the read) collapses the section entirely.
              final revokedAsync = ref.watch(
                licenseOrgRevokedSeatsProvider(widget.licenseOrgId),
              );
              final revokedRaw = revokedAsync.maybeWhen(
                data: (rows) => rows,
                orElse: () => const <LicenseOrgAuditEvent>[],
              );

              // Filter the Active Members list to uids that ALSO hold
              // an active seat row. Manual revoke flips the seat row
              // to 'revoked' but leaves the membership doc `active`
              // per the backend spec — without this filter the same
              // uid surfaces in BOTH Active and Revoked sections,
              // which is the confusing UX we saw on the 2026-05-28
              // sim verify. The seat-uid provider yields an empty
              // set while loading or on error so the filter starts
              // restrictive and relaxes once data lands.
              final activeUidsAsync = ref.watch(
                licenseOrgActiveSeatHolderUidsProvider(widget.licenseOrgId),
              );
              final activeUids = activeUidsAsync.maybeWhen(
                data: (s) => s,
                orElse: () => const <String>{},
              );

              // Symmetric dedupe on the Revoked side: drop revoke
              // audit rows whose target uid currently holds an
              // active seat (i.e. the seat was later reinstated).
              // Without this filter, a revoked-then-reinstated
              // member surfaces in BOTH Active AND Revoked, which
              // is the residual UX issue from the 2026-05-28 sim
              // verify. The audit log itself is append-only — the
              // historical revoke event is preserved in the full
              // Audit Log screen; the roster surface just shows
              // CURRENT state per uid.
              final revoked = revokedRaw
                  .where(
                    (e) => !activeUids.contains(
                      licenseOrgUidFromAllocationId(e.targetId ?? ''),
                    ),
                  )
                  .toList(growable: false);
              // Owners are intentionally NOT in the members
              // subcollection (they consume no seat), so a "no seat"
              // filter would hide them from a roster they might
              // appear in for legacy seeded orgs. Keep owner-role
              // rows visible regardless of the seat join.
              final members = rawMembers
                  .where(
                    (m) =>
                        activeUids.contains(m.uid) ||
                        m.role == LicenseOrgMemberRole.owner,
                  )
                  .toList(growable: false);

              if (members.isEmpty && revoked.isEmpty) {
                return _EmptyState(scrollController: widget.scrollController);
              }

              // Unified Members list. Tiles render in one flat
              // ListView with active members first (alphabetical-ish
              // by membership insertion order) followed by revoked
              // entries (most recent revoke first). The categorical
              // signal lives in tile styling — bright accent avatar
              // for active, dim person-off icon for revoked — not in
              // section headings. Earlier slices ran a dual-section
              // layout (Active / Revoked); that was clear but added
              // visual noise on a small roster, and the headings
              // re-rendered orphaned on edge transitions (last
              // active revoked, last revoked reinstated). The flat
              // list dodges both.
              final role = ref.watch(
                licenseOrgRoleProvider(widget.licenseOrgId),
              );
              final isCallerAdminOrOwner =
                  role == LicenseOrgMemberRole.owner ||
                  role == LicenseOrgMemberRole.admin;
              final itemCount = 1 + members.length + revoked.length;
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing16,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: SectionTitle(
                        title: l10n.licenseOrgMembersSectionAll,
                      ),
                    );
                  }
                  final flatIdx = index - 1;
                  if (flatIdx < members.length) {
                    final member = members[flatIdx];
                    final isCurrentUser =
                        currentUid != null && member.uid == currentUid;
                    // Reveal the revoke action only when:
                    //   - caller holds owner or admin role in THIS
                    //     org, AND
                    //   - the tile is NOT the current user (owners
                    //     and admins cannot revoke their own seat
                    //     from this surface; the leave / disband
                    //     flow handles that), AND
                    //   - the tile is NOT another owner (owners
                    //     aren't in the members subcollection by
                    //     design, but legacy seeded data can carry
                    //     OWNER role on a member doc — defensive
                    //     guard here).
                    final canRevoke =
                        !isCurrentUser &&
                        isCallerAdminOrOwner &&
                        member.role != LicenseOrgMemberRole.owner;
                    return _MemberTile(
                      member: member,
                      isCurrentUser: isCurrentUser,
                      onRevoke: canRevoke
                          ? () => _onRevokeTapped(member)
                          : null,
                    );
                  }
                  final event = revoked[flatIdx - members.length];
                  return _RevokedTile(
                    event: event,
                    onReinstate: isCallerAdminOrOwner
                        ? () => _onReinstateTapped(event.targetId ?? '')
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pluralised member count rendered as a small pill on the sheet
/// header line. Reads light at-a-glance but stays scannable.
class _CountChip extends StatelessWidget {
  final int count;

  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final color = context.accentColor;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          context.l10n.licenseOrgMembersCount(count),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Per-member row. Custom layout (not raw ListTile) so the role
/// pill aligns to the right edge on the same grid as the InfoTable
/// values used on the Overview screen. Top-aligned cross-axis
/// because the title / subtitle column wraps on small widths.
class _MemberTile extends StatelessWidget {
  final LicenseOrgMembership member;
  final bool isCurrentUser;

  /// Owner/admin-only callback. When null the tile renders read-only;
  /// when non-null an overflow icon appears on the trailing edge and
  /// taps invoke the parent's revoke flow.
  final VoidCallback? onRevoke;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = licenseOrgMemberLabel(member.uid);
    final role = _roleString(l10n, member.role);
    final joined = _formatJoinedRelative(l10n, member.joinedAt, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(label: label),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: AppTheme.spacing8),
                      _YouBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  joined,
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          _RolePill(role: member.role, label: role),
          if (onRevoke != null) ...[
            const SizedBox(width: AppTheme.spacing4),
            IconButton(
              tooltip: l10n.licenseOrgMembersRevokeAction,
              icon: Icon(
                Icons.more_vert,
                color: context.textTertiary,
                size: 20,
              ),
              onPressed: () => _showRevokeMenu(context, l10n),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRevokeMenu(BuildContext context, AppLocalizations l10n) {
    return AppBottomSheet.show<void>(
      context: context,
      child: _RevokeActionMenu(
        label: l10n.licenseOrgMembersRevokeAction,
        onTap: () {
          Navigator.of(context).pop();
          onRevoke?.call();
        },
      ),
    );
  }
}

/// One-action menu sheet shown when the owner taps the overflow on a
/// member tile. Kept as a separate widget so it pops cleanly via the
/// sheet's own BuildContext.
class _RevokeActionMenu extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RevokeActionMenu({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing8,
        AppTheme.spacing8,
        AppTheme.spacing8,
        AppTheme.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.person_remove_outlined,
              color: AppTheme.errorRed,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorRed,
              ),
            ),
            onTap: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
          ),
        ],
      ),
    );
  }
}

String _roleString(AppLocalizations l10n, LicenseOrgMemberRole role) {
  switch (role) {
    case LicenseOrgMemberRole.owner:
      return l10n.licenseOrgMembersRoleOwner;
    case LicenseOrgMemberRole.admin:
      return l10n.licenseOrgMembersRoleAdmin;
    case LicenseOrgMemberRole.member:
    case LicenseOrgMemberRole.unknown:
      return l10n.licenseOrgMembersRoleMember;
  }
}

String _formatJoinedRelative(
  AppLocalizations l10n,
  DateTime? joinedAt,
  DateTime now,
) {
  if (joinedAt == null) {
    return l10n.licenseOrgMembersJoinedRelative(
      l10n.licenseOrgMembersJoinedToday,
    );
  }
  final localJoined = joinedAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final joinedDay = DateTime(
    localJoined.year,
    localJoined.month,
    localJoined.day,
  );
  final days = today.difference(joinedDay).inDays;
  String relative;
  if (days <= 0) {
    relative = l10n.licenseOrgMembersJoinedToday;
  } else if (days == 1) {
    relative = l10n.licenseOrgMembersJoinedYesterday;
  } else if (days < 30) {
    relative = l10n.licenseOrgMembersJoinedDaysAgo(days);
  } else if (days < 365) {
    final months = (days / 30).floor();
    relative = l10n.licenseOrgMembersJoinedMonthsAgo(months);
  } else {
    final years = (days / 365).floor();
    relative = l10n.licenseOrgMembersJoinedYearsAgo(years);
  }
  return l10n.licenseOrgMembersJoinedRelative(relative);
}

class _Avatar extends StatelessWidget {
  final String label;

  const _Avatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    // First 2 characters after the '#' so we always render a
    // 2-character monogram, mirroring the iOS Mail / Slack avatar
    // pattern.
    final monogram = label.length >= 3 ? label.substring(1, 3) : '##';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        monogram,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: accent,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _YouBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = context.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        context.l10n.licenseOrgMembersYouBadge.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final LicenseOrgMemberRole role;
  final String label;

  const _RolePill({required this.role, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      LicenseOrgMemberRole.owner => AppTheme.warningYellow,
      LicenseOrgMemberRole.admin => context.accentColor,
      LicenseOrgMemberRole.member ||
      LicenseOrgMemberRole.unknown => context.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  final ScrollController scrollController;

  const _LoadingSkeleton({required this.scrollController});

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing16,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final alpha = 0.10 + (_pulse.value * 0.10);
            final bar = context.textTertiary.withValues(alpha: alpha);
            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing12,
              ),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 12, color: bar),
                        const SizedBox(height: AppTheme.spacing8),
                        Container(width: 80, height: 10, color: bar),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 22,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;

  const _EmptyState({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // SingleChildScrollView lets drag-to-dismiss continue working
    // even though the empty state itself is short.
    return SingleChildScrollView(
      controller: scrollController,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.people_outline,
              Icons.diversity_3_outlined,
              Icons.group_add_outlined,
            ],
            taglines: [l10n.licenseOrgMembersEmptyTagline],
            titlePrefix: l10n.licenseOrgMembersEmptyTitlePrefix,
            titleKeyword: l10n.licenseOrgMembersEmptyTitleKeyword,
            titleSuffix: l10n.licenseOrgMembersEmptyTitleSuffix,
          ),
        ),
      ),
    );
  }
}

class _SuspendedState extends StatelessWidget {
  final ScrollController scrollController;

  const _SuspendedState({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      controller: scrollController,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.lock_outline,
              Icons.pause_circle_outline,
              Icons.shield_outlined,
            ],
            taglines: [l10n.licenseOrgMembersSuspendedTagline],
            titlePrefix: l10n.licenseOrgMembersSuspendedTitlePrefix,
            titleKeyword: l10n.licenseOrgMembersSuspendedTitleKeyword,
            titleSuffix: l10n.licenseOrgMembersSuspendedTitleSuffix,
            accentColor: AppTheme.warningYellow,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onRetry;

  const _ErrorState({required this.scrollController, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      controller: scrollController,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.cloud_off_outlined,
              Icons.wifi_off_outlined,
              Icons.error_outline,
            ],
            taglines: [l10n.licenseOrgMembersErrorTagline],
            titlePrefix: l10n.licenseOrgMembersErrorTitlePrefix,
            titleKeyword: l10n.licenseOrgMembersErrorTitleKeyword,
            titleSuffix: l10n.licenseOrgMembersErrorTitleSuffix,
            actionLabel: l10n.licenseOrgMembersErrorRetry,
            actionIcon: Icons.refresh,
            onAction: onRetry,
            accentColor: AppTheme.warningYellow,
          ),
        ),
      ),
    );
  }
}

/// Single row in the Revoked section. Renders the same opaque
/// `#ABCDEF` label as a [_MemberTile] (so a viewer can match a
/// revocation back to a former member they had in mind) plus the
/// relative timestamp and the actor who performed the revoke.
///
/// Optional [onReinstate] surfaces a trailing icon button that
/// calls the parent state's reinstate flow. The caller (owner /
/// admin gate) decides whether to pass it; non-eligible viewers
/// pass null and the tile stays read-only.
class _RevokedTile extends StatelessWidget {
  final LicenseOrgAuditEvent event;
  final VoidCallback? onReinstate;

  const _RevokedTile({required this.event, this.onReinstate});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // `targetId` on a seat_revoked_manual audit row is the full
    // allocation doc id: `<orgId>__<uid>__<productId>` (mirrors the
    // backend's `seatAllocationDocId`). The opaque member label
    // wants the uid (middle segment) — using the whole targetId
    // here surfaced `#CLEANR` (the first 6 chars of the orgId
    // prefix) on first sim verification, 2026-05-28.
    final revokedUid = licenseOrgUidFromAllocationId(event.targetId ?? '');
    final memberLabel = licenseOrgMemberLabel(revokedUid);
    final actorLabel = event.actorRole == LicenseOrgAuditActorRole.system
        ? 'system'
        : licenseOrgMemberLabel(event.actorUid);
    final relative = _formatRevokedRelative(
      l10n,
      event.tsServer,
      DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.textTertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(
                color: context.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_off_outlined,
              size: 20,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.licenseOrgMembersRevokedTileTitle(memberLabel),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  '${l10n.licenseOrgMembersRevokedTileBy(actorLabel)} · $relative',
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
          if (onReinstate != null) ...[
            const SizedBox(width: AppTheme.spacing4),
            IconButton(
              tooltip: l10n.licenseOrgMembersReinstateAction,
              icon: Icon(
                Icons.restore_outlined,
                color: context.accentColor,
                size: 20,
              ),
              onPressed: onReinstate,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatRevokedRelative(
  AppLocalizations l10n,
  DateTime? tsServer,
  DateTime now,
) {
  if (tsServer == null) return l10n.licenseOrgMembersJoinedToday;
  final diff = now.toUtc().difference(tsServer);
  if (diff.inDays >= 365) {
    return l10n.licenseOrgMembersJoinedYearsAgo(diff.inDays ~/ 365);
  }
  if (diff.inDays >= 30) {
    return l10n.licenseOrgMembersJoinedMonthsAgo(diff.inDays ~/ 30);
  }
  if (diff.inDays >= 1) {
    return l10n.licenseOrgMembersJoinedDaysAgo(diff.inDays);
  }
  return l10n.licenseOrgMembersJoinedToday;
}
