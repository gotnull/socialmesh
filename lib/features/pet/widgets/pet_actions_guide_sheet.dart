// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet Action Guide — explains what each care action does and when
// to use it. Opens from the help IconButton in the pet home screen
// app bar. Uses the reusable [HelpSheet] widget; this file just
// supplies the data (icon + localized title + description per action)
// so a future designer tweaking the list doesn't have to touch the
// sheet widget itself.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/help_sheet.dart';

class PetActionsGuideSheet extends StatelessWidget {
  final ScrollController? scrollController;

  const PetActionsGuideSheet({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HelpSheet(
      scrollController: scrollController,
      title: l10n.petGuideSheetTitle,
      intro: l10n.petGuideSheetIntro,
      items: [
        HelpSheetItem(
          icon: Icons.bolt_outlined,
          iconColor: AccentColors.yellow,
          title: l10n.petActionCharge,
          description: l10n.petActionChargeDescription,
        ),
        HelpSheetItem(
          icon: Icons.bolt,
          iconColor: AccentColors.red,
          title: l10n.petActionSurge,
          description: l10n.petActionSurgeDescription,
        ),
        HelpSheetItem(
          icon: Icons.graphic_eq,
          iconColor: AccentColors.pink,
          title: l10n.petActionResonate,
          description: l10n.petActionResonateDescription,
        ),
        HelpSheetItem(
          icon: Icons.cleaning_services_outlined,
          iconColor: AccentColors.teal,
          title: l10n.petActionStabilise,
          description: l10n.petActionStabiliseDescription,
        ),
        HelpSheetItem(
          icon: Icons.healing_outlined,
          iconColor: AccentColors.red,
          title: l10n.petActionPurge,
          description: l10n.petActionPurgeDescription,
        ),
        HelpSheetItem(
          icon: Icons.nightlight_round,
          iconColor: AccentColors.indigo,
          title: l10n.petActionDim,
          description: l10n.petActionDimDescription,
        ),
        HelpSheetItem(
          icon: Icons.visibility_outlined,
          iconColor: AccentColors.sky,
          title: l10n.petActionInspect,
          description: l10n.petActionInspectDescription,
        ),
        HelpSheetItem(
          icon: Icons.auto_awesome_outlined,
          iconColor: AccentColors.yellow,
          title: l10n.petActionReSigil,
          description: l10n.petActionReSigilDescription,
        ),
      ],
    );
  }
}
