// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../l10n/app_localizations.dart';
import '../l10n/l10n_utils.dart';
import '../models/presence_confidence.dart';

AppLocalizations _l10n() => safeL10n();

String get kPresenceInferenceTooltip => _l10n().presenceInferenceTooltip;

String formatSeenAgo(Duration? age) {
  if (age == null) return '';
  if (age.inSeconds < 30) return '';
  if (age.inMinutes < 1) return '${age.inSeconds}s';
  if (age.inMinutes < 60) return '${age.inMinutes}m';
  if (age.inHours < 24) return '${age.inHours}h';
  return '${age.inDays}d';
}

String presenceStatusText(PresenceConfidence confidence, Duration? age) {
  final l10n = _l10n();
  switch (confidence) {
    case PresenceConfidence.active:
      return l10n.presenceStatusActive;
    case PresenceConfidence.fading:
      final ago = formatSeenAgo(age);
      if (ago.isEmpty) return l10n.presenceSeenJustNow;
      return l10n.presenceSeenAgo(ago);
    case PresenceConfidence.stale:
      return l10n.presenceStatusQuiet;
    case PresenceConfidence.unknown:
      return l10n.presenceStatusUnknown;
  }
}

double presenceOpacity(PresenceConfidence confidence) {
  switch (confidence) {
    case PresenceConfidence.active:
      return 1.0;
    case PresenceConfidence.fading:
      return 0.85;
    case PresenceConfidence.stale:
      return 0.7;
    case PresenceConfidence.unknown:
      return 0.6;
  }
}
