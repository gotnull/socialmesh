// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canned-message label composer. Imports no protocol-specific symbols.
// In Slice 5 this becomes the locale-resolution seam (each label resolved
// via lookupAppLocalizations(...) against the phone's active locale).
// Until then the labels are plain English so the wire contract matches
// the v1 plan and the Watch renders something the developer can read.

import '../models/watch_companion_canned_messages.dart';

/// Frozen v1 canned-message list in plan order. The composer copies this
/// into every snapshot; the Watch holds no local string table and
/// renders [WatchCompanionCannedMessage.label] verbatim.
///
/// When Slice 5 wires localization, this function will accept a
/// `lookupAppLocalizations` handle and resolve each label per the
/// active phone locale. The KEY order MUST stay stable across that
/// change (the Watch UI position is implicit in list order).
List<WatchCompanionCannedMessage> buildCannedMessages() {
  return const <WatchCompanionCannedMessage>[
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.onMyWay,
      label: 'On my way',
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.imOk,
      label: "I'm OK",
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.needHelp,
      label: 'Need help',
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.atCamp,
      label: 'At camp',
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.batteryLow,
      label: 'Battery low',
    ),
    WatchCompanionCannedMessage(
      key: WatchCompanionCannedMessageKeys.messageReceived,
      label: 'Message received',
    ),
  ];
}
