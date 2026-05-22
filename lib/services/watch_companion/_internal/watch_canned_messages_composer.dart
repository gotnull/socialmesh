// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canned-message label composer. Imports no protocol-specific symbols.
// Labels are resolved from the active phone locale via [AppLocalizations];
// the Watch holds no string table of its own and renders
// [WatchCompanionCannedMessage.label] verbatim.

import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

import '../models/watch_companion_canned_messages.dart';

/// Frozen v1 canned-message list in plan order. The Watch UI position is
/// implicit in list order; key order MUST stay stable across locale
/// changes and translation updates.
///
/// [l10n] is optional so server-side / test code paths can still call
/// this without standing up a locale. When omitted, [safeL10n] resolves
/// the active phone locale (in-app picker override, then OS locale, then
/// English).
List<WatchCompanionCannedMessage> buildCannedMessages([
  AppLocalizations? l10n,
]) {
  final t = l10n ?? safeL10n();
  return <WatchCompanionCannedMessage>[
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.onMyWay,
      label: t.watchCannedOnMyWay,
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.imOk,
      label: t.watchCannedImOk,
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.needHelp,
      label: t.watchCannedNeedHelp,
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.atCamp,
      label: t.watchCannedAtCamp,
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.batteryLow,
      label: t.watchCannedBatteryLow,
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.messageReceived,
      label: t.watchCannedMessageReceived,
    ),
  ];
}
