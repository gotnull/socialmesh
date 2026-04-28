// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../models/pet_enums.dart';
import '../providers/pet_providers.dart';
import 'pet_recent_timeline.dart';

/// Inspect sheet — the "status" screen for the pet. Read-only.
class PetInspectSheet extends ConsumerWidget {
  /// Provided by `AppBottomSheet.showScrollable`'s builder — wired to
  /// the internal ListView so drag gestures coordinate with scroll
  /// position.
  final ScrollController? scrollController;

  const PetInspectSheet({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ownPetProvider).value;
    final l10n = context.l10n;
    if (state == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Text(
          l10n.petNoOwnerDescription,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      );
    }
    final ageDays = state.ageInDaysAt(DateTime.now());
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      children: [
        Text(
          l10n.petInspectTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petInspectSectionIdentity),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.petInspectRowDnaSeed,
              value: '0x${state.dnaSeed.toRadixString(16).padLeft(8, '0')}',
              icon: Icons.fingerprint,
            ),
            InfoTableRow(
              label: l10n.petInspectRowOwnerNode,
              value: '!${state.ownerNodeNum.toRadixString(16)}',
              icon: Icons.device_hub,
            ),
            InfoTableRow(
              label: l10n.petInspectRowStage,
              value: _stageLabel(state.stage, l10n),
              icon: Icons.eco_outlined,
            ),
            InfoTableRow(
              label: l10n.petInspectRowBranch,
              value: _branchLabel(state.branch, l10n),
              icon: Icons.account_tree_outlined,
            ),
            InfoTableRow(
              label: l10n.petInspectRowHatched,
              value: l10n.petAgeDaysLabel(ageDays),
              icon: Icons.schedule_outlined,
            ),
            InfoTableRow(
              label: l10n.petInspectRowInStage,
              value: _elapsedLabel(
                DateTime.now().difference(state.stageStartedAt),
              ),
              icon: Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petInspectSectionStats),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.petStatEnergy,
              value: '${state.energy}/10',
              icon: Icons.bolt_outlined,
              iconColor: AccentColors.yellow,
            ),
            InfoTableRow(
              label: l10n.petStatMood,
              value: '${state.mood}/10',
              icon: Icons.favorite_border,
              iconColor: AccentColors.pink,
            ),
            InfoTableRow(
              label: l10n.petStatStability,
              value: '${state.stability}/10',
              icon: Icons.blur_on_outlined,
              iconColor: AccentColors.teal,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petInspectSectionRecent),
        PetRecentTimeline(
          events: state.recentEvents,
          accent: _branchAccent(state.branch),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          l10n.petInspectDeviceLocalNote,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiary,
            fontStyle: FontStyle.italic,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

/// Map a [PetBranch] to the accent color used by the recent-events
/// timeline (chevron buttons + generic stage-advanced dots). Mirrors
/// the branch-primary mapping in [PetRenderPalette] but inlined so
/// this file doesn't have to reach into the render-model layer just
/// for a single color lookup.
Color _branchAccent(PetBranch branch) {
  switch (branch) {
    case PetBranch.luminous:
      return AccentColors.yellow;
    case PetBranch.steady:
      return AccentColors.emerald;
    case PetBranch.volatile:
      return AccentColors.orange;
    case PetBranch.dimmed:
      return AccentColors.lavender;
    case PetBranch.unborn:
      return AppTheme.primaryPurple;
  }
}

/// Compact elapsed-duration label for the "In stage" row. Differs from
/// [_relativeTime] in that it has no "ago" suffix — this is a forward-
/// reading elapsed counter, not a past-tense timestamp.
///
///   < 1 m  → "<1m"
///   < 1 h  → "12m"
///   < 1 d  → "2h 15m"  (minutes only shown when > 0)
///   ≥ 1 d  → "3d 4h"   (hours only shown when > 0)
String _elapsedLabel(Duration d) {
  if (d.isNegative || d.inMinutes < 1) {
    return '<1m'; // lint-allow: hardcoded-string
  }
  if (d.inHours < 1) return '${d.inMinutes}m'; // lint-allow: hardcoded-string
  if (d.inDays < 1) {
    final h = d.inHours;
    final m = d.inMinutes - h * 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h'; // lint-allow: hardcoded-string
  }
  final days = d.inDays;
  final hours = d.inHours - days * 24;
  return hours > 0
      ? '${days}d ${hours}h'
      : '${days}d'; // lint-allow: hardcoded-string
}

String _stageLabel(PetStage stage, dynamic l10n) {
  switch (stage) {
    case PetStage.egg:
      return l10n.petStageEgg as String;
    case PetStage.juvenile:
      return l10n.petStageJuvenile as String;
    case PetStage.adolescent:
      return l10n.petStageAdolescent as String;
    case PetStage.adult:
      return l10n.petStageAdult as String;
    case PetStage.elder:
      return l10n.petStageElder as String;
    case PetStage.dormant:
      return l10n.petStageDormant as String;
  }
}

String _branchLabel(PetBranch branch, dynamic l10n) {
  switch (branch) {
    case PetBranch.unborn:
      return l10n.petBranchUnborn as String;
    case PetBranch.luminous:
      return l10n.petBranchLuminous as String;
    case PetBranch.steady:
      return l10n.petBranchSteady as String;
    case PetBranch.volatile:
      return l10n.petBranchVolatile as String;
    case PetBranch.dimmed:
      return l10n.petBranchDimmed as String;
  }
}
