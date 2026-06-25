// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/metric_chip.dart';
import '../../../l10n/app_localizations.dart';

// Shared "Direct / N hops" label for a message's hop count. A hop count of
// 0 means the sender was in direct radio range (no relay); anything higher
// is the number of times the message was relayed before arriving. Routing
// all hop-label sites through this helper keeps the wording identical across
// the bubble chip, the on-tap tech-info panel, and the long-press details
// sheet.
String hopCountLabel(AppLocalizations l10n, int hopCount) => hopCount == 0
    ? l10n.messagingTechInfoDirectHop
    : l10n.messagingTechInfoHops(hopCount);

// Ambient, always-visible hop-count chip shown under received message
// bubbles. It is rendered locally from data already on the message and
// sends nothing over the air. It deliberately uses MetricChip (tertiary
// tint, icon + text) so it reads as metadata and never as a sent reaction.
class HopCountChip extends StatelessWidget {
  final int hopCount;

  const HopCountChip({super.key, required this.hopCount});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MetricChip(
      icon: Icons.route,
      value: hopCountLabel(l10n, hopCount),
      tooltip: l10n.messagingTechInfoExplainHopsBody,
    );
  }
}
