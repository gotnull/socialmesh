// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../application/operations_providers.dart';
import '../widgets/operation_card.dart';
import 'operation_detail_screen.dart';

/// Top-level Operations screen.
///
/// Shows the active and completed lists, an empty state when nothing is
/// in progress, and a disabled banner when the feature flag is off.
class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(operationsProvider);
    final l10n = context.l10n;

    return GlassScaffold(
      title: l10n.operationsScreenTitle,
      slivers: [
        stateAsync.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: LoadingIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: StatusBanner(
                  type: StatusBannerType.error,
                  title: l10n.operationsErrorBody,
                ),
              ),
            ),
          ),
          data: (state) {
            if (!state.enabled) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Center(
                    child: StatusBanner(
                      type: StatusBannerType.info,
                      title: l10n.operationsDisabledBody,
                    ),
                  ),
                ),
              );
            }

            final active = ref.watch(operationsActiveListProvider);
            final completed = ref.watch(operationsCompletedListProvider);

            if (active.isEmpty && completed.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedEmptyState(
                  config: AnimatedEmptyStateConfig(
                    icons: const [Icons.radar, Icons.timeline, Icons.public],
                    taglines: [
                      l10n.operationsEmptyTagline1,
                      l10n.operationsEmptyTagline2,
                      l10n.operationsEmptyTagline3,
                    ],
                    titlePrefix: l10n.operationsEmptyTitlePrefix,
                    titleKeyword: l10n.operationsEmptyTitleKeyword,
                    titleSuffix: l10n.operationsEmptyTitleSuffix,
                  ),
                ),
              );
            }

            return SliverList.list(
              children: [
                const SizedBox(height: AppTheme.spacing8),
                if (active.isNotEmpty) ...[
                  SettingsSectionHeader(title: l10n.operationsSectionActive),
                  ...active.map(
                    (vm) => OperationCard(
                      viewModel: vm,
                      onTap: () => _openDetail(context, vm.definition.id),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                ],
                if (completed.isNotEmpty) ...[
                  SettingsSectionHeader(title: l10n.operationsSectionCompleted),
                  ...completed.map(
                    (vm) => OperationCard(
                      viewModel: vm,
                      onTap: () => _openDetail(context, vm.definition.id),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                ],
                const SizedBox(height: AppTheme.spacing32),
              ],
            );
          },
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, String operationId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OperationDetailScreen(operationId: operationId),
      ),
    );
  }
}
