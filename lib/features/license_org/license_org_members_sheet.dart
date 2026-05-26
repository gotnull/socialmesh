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
import '../../models/license_org_membership.dart';
import '../../providers/auth_providers.dart';
import '../../providers/license_org_members_providers.dart';
import '../../providers/license_org_overview_providers.dart';

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
              membersAsync.maybeWhen(
                data: (members) => _CountChip(count: members.length),
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
            data: (members) {
              if (isSuspended) {
                return _SuspendedState(
                  scrollController: widget.scrollController,
                );
              }
              if (members.isEmpty) {
                return _EmptyState(scrollController: widget.scrollController);
              }
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing16,
                ),
                itemCount: members.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: SectionTitle(
                        title: l10n.licenseOrgMembersSectionActive,
                      ),
                    );
                  }
                  final member = members[index - 1];
                  return _MemberTile(
                    member: member,
                    isCurrentUser:
                        currentUid != null && member.uid == currentUid,
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

  const _MemberTile({required this.member, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _labelForUid(member.uid);
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
        ],
      ),
    );
  }
}

/// Deterministic short label derived from the first 6 chars of the
/// uid. Stable across sessions, opaque to other members, and good
/// enough to distinguish people in a small org. See spec §4.
String _labelForUid(String uid) {
  if (uid.isEmpty) return '#------';
  final prefix = uid.length >= 6 ? uid.substring(0, 6) : uid.padRight(6, '_');
  return '#${prefix.toUpperCase()}';
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
