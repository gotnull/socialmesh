// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';

/// "First encounter" for a single sighting, otherwise "Seen N times".
String encounterSummaryLabel(AppLocalizations l10n, int encounterCount) =>
    l10n.presenceEncounterSummary(encounterCount);

/// How long ago a node was first seen, from whole days since first sight.
/// Under a week counts days, under a month counts weeks, then months.
String relationshipAgeLabel(AppLocalizations l10n, int days) {
  if (days <= 0) return l10n.presenceFirstSeenToday;
  if (days == 1) return l10n.presenceFirstSeenYesterday;
  if (days < 7) return l10n.presenceFirstSeenDaysAgo(days);
  if (days < 30) return l10n.presenceFirstSeenWeeksAgo(days ~/ 7);
  return l10n.presenceFirstSeenMonthsAgo(days ~/ 30);
}
