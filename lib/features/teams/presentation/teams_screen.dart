// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Teams list.
//
// Renders one of seven states derived from the licensing membership
// authority. The load-bearing rule: ONLY `TeamsEmpty` may say the user
// belongs to no organisations. Every other empty-looking state says why
// it cannot answer instead.
//
// This screen composes existing surfaces - each row is the shipped
// `LicenseOrgOverviewCard`. Teams adds no organisation rendering of its
// own.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../license_org/license_org_overview_card.dart';
import 'fleet_screen.dart';
import '../application/teams_list_state.dart';
import '../application/teams_providers.dart';

/// Top-level Teams screen.
class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  /// Push helper so callers need no MaterialPageRoute import.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const TeamsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(teamsListStateProvider);

    return GlassScaffold(
      title: l10n.teamsScreenTitle,
      slivers: [
        // Exhaustive switch: adding a state to TeamsListState is a
        // compile error here, which is where a new state must be given
        // an honest presentation rather than silently falling into a
        // default branch.
        switch (state) {
          TeamsDisabled() => _banner(
            context,
            StatusBannerType.info,
            l10n.teamsDisabledBody,
          ),
          TeamsAccountRequired() => _message(
            context,
            icon: Icons.account_circle_outlined,
            title: l10n.teamsAccountRequiredTitle,
            body: l10n.teamsAccountRequiredBody,
          ),
          TeamsChecking() => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoadingIndicator(),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    l10n.teamsCheckingLabel,
                    style: context.bodySecondaryStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          TeamsOfflineUnknown() => _message(
            context,
            icon: Icons.cloud_off_outlined,
            title: l10n.teamsOfflineTitle,
            body: l10n.teamsOfflineBody,
          ),
          TeamsUnavailable() => _message(
            context,
            icon: Icons.error_outline,
            title: l10n.teamsUnavailableTitle,
            body: l10n.teamsUnavailableBody,
            actionLabel: l10n.teamsRetryAction,
            // Retries the AUTHORITY, not a Teams-local copy, so every
            // consumer sees failed -> pending -> resolved/failed.
            onAction: () => retryTeamsMembership(ref),
          ),
          TeamsEmpty() => SliverFillRemaining(
            hasScrollBody: false,
            child: AnimatedEmptyState(
              config: AnimatedEmptyStateConfig(
                icons: const [
                  Icons.groups_outlined,
                  Icons.badge_outlined,
                  Icons.hub_outlined,
                ],
                taglines: [l10n.teamsEmptyTagline],
                titlePrefix: l10n.teamsEmptyTitlePrefix,
                titleKeyword: l10n.teamsEmptyTitleKeyword,
                titleSuffix: l10n.teamsEmptyTitleSuffix,
              ),
            ),
          ),
          // VERTICAL INSET ONLY. The two children need their horizontal
          // inset from different places, and applying it here breaks one
          // of them:
          //
          //   LicenseOrgOverviewCard carries no inset of its own and
          //   relies on its parent, exactly as LicenseOrgOverviewScreen
          //   provides.
          //   SettingsTile already carries margin: horizontal
          //   spacing16.
          //
          // A horizontal inset here doubles the tile's to 32 and the
          // Fleet row renders 16pt narrower per side than the card's own
          // rows - a stepped edge running down the screen. So each child
          // is given its inset individually below.
          TeamsLoaded(orgIds: final orgIds) => SliverPadding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacing16,
              bottom: AppTheme.spacing32,
            ),
            sliver: SliverList.separated(
              itemCount: orgIds.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spacing24),
              // The shared overview card is rendered unmodified, with the
              // Fleet entry point beneath it rather than inside it. The
              // same card is used by LicenseOrgOverviewScreen, which has
              // no Fleet concept, so adding a row to it would leak Teams
              // navigation into an unrelated surface.
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: LicenseOrgOverviewCard(orgId: orgIds[index]),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  SettingsTile(
                    icon: Icons.router_outlined,
                    title: l10n.fleetScreenTitle,
                    subtitle: l10n.fleetEntrySubtitle,
                    trailing: Icon(
                      Icons.chevron_right,
                      size: AppTheme.spacing20,
                      color: context.textTertiary,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      FleetScreen.route(orgIds[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        },
      ],
    );
  }

  static Widget _banner(
    BuildContext context,
    StatusBannerType type,
    String title,
  ) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: StatusBanner(type: type, title: title),
        ),
      ),
    );
  }

  /// Shared shape for the three "we cannot answer" states.
  ///
  /// Deliberately NOT `AnimatedEmptyState`: that surface reads as "there
  /// is nothing here", which is precisely the claim these states must
  /// not make.
  static Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppTheme.spacing40, color: context.textTertiary),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                title,
                style: context.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                body,
                style: context.bodySecondaryStyle,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppTheme.spacing24),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
