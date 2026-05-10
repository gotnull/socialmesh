// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../l10n/app_localizations.dart';
import '../application/operations_providers.dart';
import '../models/operation_models.dart';

/// Card representing a single operation in the active or completed list.
///
/// Visual treatment mirrors the canonical inner-settings card body
/// (`context.card` background, `radius12`, horizontal margin
/// `AppTheme.spacing16`) so the surface reads as native SocialMesh.
/// Inside it lays out a category icon, the localized title, an optional
/// subtitle (objective summary), and a trailing progress ring whose
/// numeric label inverts to a check on completion.
class OperationCard extends StatelessWidget {
  final OperationViewModel viewModel;
  final VoidCallback onTap;

  const OperationCard({
    super.key,
    required this.viewModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final def = viewModel.definition;
    final progress = viewModel.progress;
    final isCompleted = viewModel.state == OperationCompletionState.completed;
    final l10n = context.l10n;

    final completedTotal = def.objectives.fold<int>(
      0,
      (sum, o) => sum + (progress.objectiveProgress[o.id] ?? 0),
    );
    final targetTotal = def.objectives.fold<int>(0, (sum, o) => sum + o.target);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Row(
              children: [
                Icon(_categoryIcon(def.category), color: context.textSecondary),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localizeTitle(l10n, def),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        isCompleted
                            ? l10n.operationCardCompletedSubtitle
                            : l10n.operationCardProgressSubtitle(
                                completedTotal,
                                targetTotal,
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                AnimatedProgressRing(
                  progress: viewModel.overallFraction,
                  size: 36,
                  strokeWidth: 3,
                  child: isCompleted
                      ? Icon(Icons.check, size: 18, color: context.accentColor)
                      : Text(
                          '${(viewModel.overallFraction * 100).round()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(OperationCategory category) {
    switch (category) {
      case OperationCategory.discovery:
        return Icons.radar;
      case OperationCategory.connectivity:
        return Icons.timeline;
      case OperationCategory.coverage:
        return Icons.public;
      case OperationCategory.endurance:
        return Icons.bolt;
      case OperationCategory.community:
        return Icons.groups;
    }
  }

  String _localizeTitle(AppLocalizations l10n, OperationDefinition def) {
    return resolveOperationKey(l10n, def.titleKey);
  }
}

/// Resolves an ARB key by name. ARB-generated AppLocalizations does not
/// expose keys by string lookup, so the Operations catalog (which holds
/// keys as strings in static data) goes through this switch. Adding a
/// new operation requires extending both the catalog and this resolver.
String resolveOperationKey(AppLocalizations l10n, String key) {
  switch (key) {
    case 'operationFirstContactTitle':
      return l10n.operationFirstContactTitle;
    case 'operationFirstContactDescription':
      return l10n.operationFirstContactDescription;
    case 'operationFirstContactObjective':
      return l10n.operationFirstContactObjective;
    case 'operationFirstContactRewardLabel':
      return l10n.operationFirstContactRewardLabel;
    case 'operationSignalHunterTitle':
      return l10n.operationSignalHunterTitle;
    case 'operationSignalHunterDescription':
      return l10n.operationSignalHunterDescription;
    case 'operationSignalHunterObjective':
      return l10n.operationSignalHunterObjective;
    case 'operationSignalHunterRewardLabel':
      return l10n.operationSignalHunterRewardLabel;
    case 'operationPathfinderTitle':
      return l10n.operationPathfinderTitle;
    case 'operationPathfinderDescription':
      return l10n.operationPathfinderDescription;
    case 'operationPathfinderObjective':
      return l10n.operationPathfinderObjective;
    case 'operationPathfinderRewardLabel':
      return l10n.operationPathfinderRewardLabel;
    case 'operationLongRangeObserverTitle':
      return l10n.operationLongRangeObserverTitle;
    case 'operationLongRangeObserverDescription':
      return l10n.operationLongRangeObserverDescription;
    case 'operationLongRangeObserverObjective':
      return l10n.operationLongRangeObserverObjective;
    case 'operationNightWatchTitle':
      return l10n.operationNightWatchTitle;
    case 'operationNightWatchDescription':
      return l10n.operationNightWatchDescription;
    case 'operationNightWatchObjective':
      return l10n.operationNightWatchObjective;
    case 'operationMultiHopObserverTitle':
      return l10n.operationMultiHopObserverTitle;
    case 'operationMultiHopObserverDescription':
      return l10n.operationMultiHopObserverDescription;
    case 'operationMultiHopObserverObjective':
      return l10n.operationMultiHopObserverObjective;
    case 'operationMapCoverageTitle':
      return l10n.operationMapCoverageTitle;
    case 'operationMapCoverageDescription':
      return l10n.operationMapCoverageDescription;
    case 'operationMapCoverageObjective':
      return l10n.operationMapCoverageObjective;
    default:
      return key;
  }
}
