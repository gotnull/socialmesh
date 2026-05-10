// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/operations_providers.dart';
import '../models/operation_models.dart';
import '../widgets/operation_card.dart';

/// Detail view for a single operation. Shows objective progress rows, a
/// reward preview block, and contextual metadata. The screen is a passive
/// reader — there are no destructive actions in v1.
class OperationDetailScreen extends ConsumerWidget {
  final String operationId;

  const OperationDetailScreen({super.key, required this.operationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(operationByIdProvider(operationId));
    final l10n = context.l10n;

    if (viewModel == null) {
      return GlassScaffold(
        title: l10n.operationDetailTitle,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: StatusBanner(
                  type: StatusBannerType.error,
                  title: l10n.operationDetailNotFound,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final def = viewModel.definition;
    final progress = viewModel.progress;
    final isCompleted = viewModel.state == OperationCompletionState.completed;

    return GlassScaffold(
      title: resolveOperationKey(l10n, def.titleKey),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          sliver: SliverList.list(
            children: [
              _SummaryHeader(viewModel: viewModel),
              const SizedBox(height: AppTheme.spacing24),
              SectionTitle(title: l10n.operationDetailObjectivesSection),
              const SizedBox(height: AppTheme.spacing8),
              _ObjectivesCard(viewModel: viewModel),
              const SizedBox(height: AppTheme.spacing24),
              if (def.rewards.isNotEmpty) ...[
                SectionTitle(title: l10n.operationDetailRewardsSection),
                const SizedBox(height: AppTheme.spacing8),
                _RewardsCard(viewModel: viewModel),
                const SizedBox(height: AppTheme.spacing24),
              ],
              SectionTitle(title: l10n.operationDetailStatusSection),
              const SizedBox(height: AppTheme.spacing8),
              _StatusInfoTable(viewModel: viewModel),
              const SizedBox(height: AppTheme.spacing24),
              if (isCompleted && progress.claimedAt == null)
                _RewardClaimButton(operationId: def.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final OperationViewModel viewModel;

  const _SummaryHeader({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final def = viewModel.definition;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          AnimatedProgressRing(
            progress: viewModel.overallFraction,
            size: 64,
            strokeWidth: 5,
            child: Text(
              '${(viewModel.overallFraction * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolveOperationKey(l10n, def.titleKey),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  resolveOperationKey(l10n, def.descriptionKey),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectivesCard extends StatelessWidget {
  final OperationViewModel viewModel;

  const _ObjectivesCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final def = viewModel.definition;
    final progress = viewModel.progress;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < def.objectives.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.background),
            _ObjectiveRow(
              objective: def.objectives[i],
              count: progress.objectiveProgress[def.objectives[i].id] ?? 0,
              l10n: l10n,
            ),
          ],
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  final OperationObjective objective;
  final int count;
  final AppLocalizations l10n;

  const _ObjectiveRow({
    required this.objective,
    required this.count,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = objective.target == 0
        ? 0.0
        : (count / objective.target).clamp(0.0, 1.0);
    final isDone = count >= objective.target;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: isDone ? context.accentColor : context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  resolveOperationKey(l10n, objective.titleKey),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                '$count / ${objective.target}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: context.background,
              valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsCard extends StatelessWidget {
  final OperationViewModel viewModel;

  const _RewardsCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final def = viewModel.definition;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reward in def.rewards) ...[
            Row(
              children: [
                Icon(
                  _rewardIcon(reward.kind),
                  color: context.accentColor,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    resolveOperationKey(l10n, reward.labelKey),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            if (reward != def.rewards.last)
              const SizedBox(height: AppTheme.spacing8),
          ],
        ],
      ),
    );
  }

  IconData _rewardIcon(OperationRewardKind kind) {
    switch (kind) {
      case OperationRewardKind.badge:
        return Icons.workspace_premium;
      case OperationRewardKind.patch:
        return Icons.shield;
      case OperationRewardKind.sigilTrait:
        return Icons.auto_awesome;
      case OperationRewardKind.themeToken:
        return Icons.palette;
      case OperationRewardKind.title:
        return Icons.military_tech;
    }
  }
}

class _StatusInfoTable extends StatelessWidget {
  final OperationViewModel viewModel;

  const _StatusInfoTable({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = viewModel.progress;
    final def = viewModel.definition;
    return InfoTable(
      rows: [
        InfoTableRow(
          label: l10n.operationDetailStatusCategoryLabel,
          value: _categoryLabel(l10n, def.category),
        ),
        InfoTableRow(
          label: l10n.operationDetailStatusStateLabel,
          value: _stateLabel(l10n, viewModel.state),
        ),
        if (progress.completedAt != null)
          InfoTableRow(
            label: l10n.operationDetailStatusCompletedAtLabel,
            value: progress.completedAt!.toLocal().toString(),
          ),
        if (progress.claimedAt != null)
          InfoTableRow(
            label: l10n.operationDetailStatusClaimedAtLabel,
            value: progress.claimedAt!.toLocal().toString(),
          ),
      ],
    );
  }

  String _categoryLabel(AppLocalizations l10n, OperationCategory category) {
    switch (category) {
      case OperationCategory.discovery:
        return l10n.operationCategoryDiscovery;
      case OperationCategory.connectivity:
        return l10n.operationCategoryConnectivity;
      case OperationCategory.coverage:
        return l10n.operationCategoryCoverage;
      case OperationCategory.endurance:
        return l10n.operationCategoryEndurance;
      case OperationCategory.community:
        return l10n.operationCategoryCommunity;
    }
  }

  String _stateLabel(AppLocalizations l10n, OperationCompletionState state) {
    switch (state) {
      case OperationCompletionState.notStarted:
        return l10n.operationStateNotStarted;
      case OperationCompletionState.inProgress:
        return l10n.operationStateInProgress;
      case OperationCompletionState.completed:
        return l10n.operationStateCompleted;
    }
  }
}

class _RewardClaimButton extends ConsumerWidget {
  final String operationId;

  const _RewardClaimButton({required this.operationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        child: SettingsTile(
          icon: Icons.celebration,
          iconColor: context.accentColor,
          title: l10n.operationDetailClaimAcknowledgeTitle,
          subtitle: l10n.operationDetailClaimAcknowledgeSubtitle,
          onTap: () {
            ref
                .read(operationsProvider.notifier)
                .markRewardClaimed(operationId);
          },
        ),
      ),
    );
  }
}
