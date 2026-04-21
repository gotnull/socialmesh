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

/// Inspect sheet — the "status" screen for the pet. Read-only.
class PetInspectSheet extends ConsumerWidget {
  const PetInspectSheet({super.key});

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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
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
        _RecentEventsList(events: state.recentEvents),
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

class _RecentEventsList extends StatelessWidget {
  final List<dynamic> events;
  const _RecentEventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 14,
          color: context.textTertiary,
          fontFamily: AppTheme.fontFamily,
        ),
      );
    }
    final tail = events.length > 8 ? events.sublist(events.length - 8) : events;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in tail.reversed.cast<dynamic>())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _formatEvent(e),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatEvent(dynamic event) {
    final at = event.at as DateTime;
    final kind = event.kind as CareEventKind;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$hh:$mm  ${kind.name}';
  }
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
