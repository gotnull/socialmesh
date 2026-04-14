// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';
import 'models/automation.dart';

/// Generates human-readable summaries for automations.
///
/// Format: "When [trigger], if [conditions], then [actions], else [actions]"
class AutomationSummary {
  const AutomationSummary._();

  /// Build a human-readable summary string for the given [automation].
  static String build(Automation automation, AppLocalizations l10n) {
    final parts = <String>[];

    // WHEN
    parts.add(
      l10n.automationSummaryWhen(automation.trigger.type.localizedName(l10n)),
    );

    // IF (conditions)
    final conditions = automation.conditions;
    if (conditions != null && conditions.isNotEmpty) {
      final conditionNames = conditions
          .map((c) => c.type.localizedName(l10n))
          .join(', ');
      parts.add(l10n.automationSummaryIf(conditionNames));
    }

    // THEN
    final thenActions = automation.effectiveThenActions;
    if (thenActions.isNotEmpty) {
      final actionNames = thenActions
          .map((a) => a.type.localizedName(l10n))
          .join(', ');
      parts.add(l10n.automationSummaryThen(actionNames));
    }

    // ELSE
    final elseActions = automation.effectiveElseActions;
    if (elseActions != null && elseActions.isNotEmpty) {
      final actionNames = elseActions
          .map((a) => a.type.localizedName(l10n))
          .join(', ');
      parts.add(l10n.automationSummaryElse(actionNames));
    }

    return parts.join(', ');
  }
}
