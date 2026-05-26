// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// License Org Overview screen. First investor-demoable group-licensing
// surface. Lists the license orgs the signed-in user belongs to, with
// role badge, status, seat count, joined date, and org id per card.
//
// Spec: docs/engineering/LICENSE_ORG_OVERVIEW_SCREEN.md.
//
// Provider graph (top-down):
//
//   currentUserLicenseOrgIdsProvider          -> Set<String>
//     ├─ licenseOrgProvider.family(orgId)
//     ├─ currentUserLicenseOrgMembershipProvider.family(orgId)
//     ├─ licenseOrgRoleProvider.family(orgId)
//     └─ licenseOrgRedeemedSeatCountProvider.family(orgId)
//                                             from
//                                             currentUserSeatAllocationsProvider
//
// State handling:
//   - flag off                          -> screen fails closed; sliver
//                                          renders the empty state (the
//                                          flag also hides the entry
//                                          tile so the route is
//                                          unreachable in practice)
//   - signed out / guest / empty uid    -> empty set; empty state copy
//   - loading                           -> compact skeleton card
//   - error                             -> error AnimatedEmptyState
//                                          with retry button that
//                                          invalidates the two source
//                                          providers
//   - zero orgs                         -> empty AnimatedEmptyState
//                                          with the existing
//                                          showOrgCheckoutSheet helper
//                                          wired into the action
//   - one or more orgs                  -> SliverList of
//                                          [LicenseOrgOverviewCard]
//
// IMPORTANT - reads the licensing namespace (`license_orgs/`), NOT the
// enterprise multi-tenancy `orgs/` namespace. The two systems stay
// isolated per
// docs/engineering/GROUP_LICENSING_FOUNDATION.md section 11.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/revenuecat_config.dart';
import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/license_org_membership_providers.dart';
import '../../providers/seat_allocation_providers.dart';
import '../external_purchase/org_checkout_sheet.dart';
import 'license_org_overview_card.dart';

class LicenseOrgOverviewScreen extends ConsumerStatefulWidget {
  const LicenseOrgOverviewScreen({super.key});

  /// Convenience route helper so callers can write
  /// `Navigator.of(context).push(LicenseOrgOverviewScreen.route())`
  /// without a separate import for [MaterialPageRoute].
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const LicenseOrgOverviewScreen());

  @override
  ConsumerState<LicenseOrgOverviewScreen> createState() =>
      _LicenseOrgOverviewScreenState();
}

class _LicenseOrgOverviewScreenState
    extends ConsumerState<LicenseOrgOverviewScreen>
    with LifecycleSafeMixin<LicenseOrgOverviewScreen> {
  bool _openedLogged = false;

  @override
  void initState() {
    super.initState();
    if (!_openedLogged) {
      _openedLogged = true;
      // Counts only - no uid, no orgId, no productId per privacy
      // contract in docs/engineering/LICENSE_ORG_OVERVIEW_SCREEN.md
      // section 8 (Tests) and the broader GROUP_LICENSING_FOUNDATION
      // PII rules.
      AppLogging.purchase(
        '[LicenseOrgOverview] screen opened '
        '(flag=${AppFeatureFlags.isGroupLicensingEnabled})',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orgsAsync = ref.watch(currentUserLicenseOrgIdsProvider);

    return GlassScaffold(
      title: l10n.licenseOrgOverviewTitle,
      slivers: [
        orgsAsync.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: _LoadingSkeleton(),
          ),
          error: (err, st) {
            AppLogging.purchase(
              '[LicenseOrgOverview] error state rendered '
              '(error class: ${err.runtimeType})',
            );
            return SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                onRetry: () {
                  ref.invalidate(currentUserLicenseOrgIdsProvider);
                  ref.invalidate(currentUserSeatAllocationsProvider);
                },
              ),
            );
          },
          data: (orgIds) {
            if (orgIds.isEmpty) {
              AppLogging.purchase('[LicenseOrgOverview] empty state rendered');
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  onAction: () => showOrgCheckoutSheet(
                    context,
                    productId: RevenueCatConfig.themePackProductId,
                  ),
                ),
              );
            }
            // Counts only - no orgIds, no uid leak.
            AppLogging.purchase(
              '[LicenseOrgOverview] loaded orgCount=${orgIds.length}',
            );
            final sorted = orgIds.toList()..sort();
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing32,
              ),
              sliver: SliverList.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.spacing24),
                itemBuilder: (context, index) =>
                    LicenseOrgOverviewCard(orgId: sorted[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAction;

  const _EmptyState({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.groups_outlined,
          Icons.diversity_3_outlined,
          Icons.workspace_premium_outlined,
          Icons.shield_outlined,
        ],
        taglines: [
          l10n.licenseOrgOverviewEmptyTagline1,
          l10n.licenseOrgOverviewEmptyTagline2,
          l10n.licenseOrgOverviewEmptyTagline3,
        ],
        titlePrefix: l10n.licenseOrgOverviewEmptyTitlePrefix,
        titleKeyword: l10n.licenseOrgOverviewEmptyTitleKeyword,
        titleSuffix: l10n.licenseOrgOverviewEmptyTitleSuffix,
        actionLabel: l10n.licenseOrgOverviewEmptyAction,
        actionIcon: Icons.add_card_outlined,
        onAction: onAction,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.cloud_off_outlined,
          Icons.wifi_off_outlined,
          Icons.error_outline,
        ],
        taglines: [l10n.licenseOrgOverviewErrorTagline],
        titlePrefix: l10n.licenseOrgOverviewErrorTitlePrefix,
        titleKeyword: l10n.licenseOrgOverviewErrorTitleKeyword,
        titleSuffix: l10n.licenseOrgOverviewErrorTitleSuffix,
        actionLabel: l10n.licenseOrgOverviewErrorAction,
        actionIcon: Icons.refresh,
        onAction: onRetry,
        accentColor: AppTheme.warningYellow,
      ),
    );
  }
}

// Lightweight skeleton card matching the InfoTable shape rendered by
// [LicenseOrgOverviewCard]. The radar empty-state already runs heavy
// animations, so the loading skeleton stays deliberately calm: a
// single pulsing block per row gives the eye a target without
// dragging in another animation controller.
class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing32,
      ),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final alpha = 0.10 + (_pulse.value * 0.10);
          final bar = Color.alphaBlend(
            context.textTertiary.withValues(alpha: alpha),
            context.background,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section title placeholder.
              Container(
                height: 12,
                width: 160,
                margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: bar,
                  borderRadius: BorderRadius.circular(AppTheme.radius4),
                ),
              ),
              // Card placeholder with five row outlines.
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                  color: context.background,
                ),
                child: Column(
                  children: List.generate(5, (index) {
                    final isOdd = index % 2 == 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: isOdd ? context.cardAlt : context.background,
                        border: Border(
                          bottom: index < 4
                              ? BorderSide(color: context.border)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 10,
                            decoration: BoxDecoration(
                              color: bar,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 120,
                            height: 10,
                            decoration: BoxDecoration(
                              color: bar,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
