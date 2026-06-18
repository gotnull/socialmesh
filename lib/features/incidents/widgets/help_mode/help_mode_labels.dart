// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Localised labels + accent colours for Incident Mode (Help Mode) UI.
///
/// Centralises the enum -> l10n / colour mapping so widgets do not duplicate
/// switch logic. All user-visible strings come from `context.l10n`.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/chip_selector.dart';
import '../../models/incident_mode_models.dart';

/// Localised label for a quick-status code.
String incidentQuickUpdateLabel(
  BuildContext context,
  IncidentQuickUpdate code,
) {
  final l10n = context.l10n;
  return switch (code) {
    IncidentQuickUpdate.imOk => l10n.helpModeStatusImOk,
    IncidentQuickUpdate.imInjured => l10n.helpModeStatusInjured,
    IncidentQuickUpdate.cantMove => l10n.helpModeStatusCantMove,
    IncidentQuickUpdate.needWater => l10n.helpModeStatusNeedWater,
    IncidentQuickUpdate.needMedical => l10n.helpModeStatusNeedMedical,
    IncidentQuickUpdate.falseAlarm => l10n.helpModeStatusFalseAlarm,
    IncidentQuickUpdate.situationWorse => l10n.helpModeStatusWorse,
    IncidentQuickUpdate.onMyWay => l10n.helpModeStatusOnMyWay,
    IncidentQuickUpdate.arrived => l10n.helpModeStatusArrived,
    IncidentQuickUpdate.needBackup => l10n.helpModeStatusNeedBackup,
    IncidentQuickUpdate.blocked => l10n.helpModeStatusBlocked,
    IncidentQuickUpdate.cantReachYou => l10n.helpModeStatusCantReach,
    IncidentQuickUpdate.leavingResponse => l10n.helpModeStatusLeaving,
  };
}

/// Accent colour for a quick-status chip (semantic, theme-sourced).
Color incidentQuickUpdateColor(IncidentQuickUpdate code) {
  return switch (code) {
    IncidentQuickUpdate.imOk => AppTheme.successGreen,
    IncidentQuickUpdate.arrived => AppTheme.successGreen,
    IncidentQuickUpdate.onMyWay => AccentColors.sky,
    IncidentQuickUpdate.needWater => AccentColors.sky,
    IncidentQuickUpdate.imInjured => AppTheme.warningYellow,
    IncidentQuickUpdate.cantMove => AppTheme.warningYellow,
    IncidentQuickUpdate.blocked => AppTheme.warningYellow,
    IncidentQuickUpdate.cantReachYou => AppTheme.warningYellow,
    IncidentQuickUpdate.needBackup => AppTheme.warningYellow,
    IncidentQuickUpdate.needMedical => AppTheme.errorRed,
    IncidentQuickUpdate.situationWorse => AppTheme.errorRed,
    IncidentQuickUpdate.falseAlarm => AccentColors.slate,
    IncidentQuickUpdate.leavingResponse => AccentColors.slate,
  };
}

/// The requester quick-status codes, in display order.
const List<IncidentQuickUpdate> requesterQuickUpdates = [
  IncidentQuickUpdate.imOk,
  IncidentQuickUpdate.imInjured,
  IncidentQuickUpdate.cantMove,
  IncidentQuickUpdate.needWater,
  IncidentQuickUpdate.needMedical,
  IncidentQuickUpdate.situationWorse,
  IncidentQuickUpdate.falseAlarm,
];

/// The responder quick-status codes, in display order.
const List<IncidentQuickUpdate> responderQuickUpdates = [
  IncidentQuickUpdate.onMyWay,
  IncidentQuickUpdate.arrived,
  IncidentQuickUpdate.needBackup,
  IncidentQuickUpdate.blocked,
  IncidentQuickUpdate.cantReachYou,
  IncidentQuickUpdate.leavingResponse,
];

/// Builds [ChipOption]s for a quick-status set.
List<ChipOption<IncidentQuickUpdate?>> quickUpdateChipOptions(
  BuildContext context,
  List<IncidentQuickUpdate> codes,
) {
  return [
    for (final c in codes)
      ChipOption<IncidentQuickUpdate?>(
        value: c,
        label: incidentQuickUpdateLabel(context, c),
        color: incidentQuickUpdateColor(c),
      ),
  ];
}

/// Localised timeline label for an event.
String incidentEventLabel(BuildContext context, IncidentEvent event) {
  final l10n = context.l10n;
  return switch (event.type) {
    IncidentEventType.create => l10n.helpModeEventCreate,
    IncidentEventType.ack => l10n.helpModeEventAck,
    IncidentEventType.seen => l10n.helpModeEventSeen,
    IncidentEventType.responderAccept => l10n.helpModeEventResponderAccept,
    IncidentEventType.responderLeave => l10n.helpModeEventResponderLeave,
    IncidentEventType.requesterStatus => l10n.helpModeEventRequesterStatus,
    IncidentEventType.responderStatus => l10n.helpModeEventResponderStatus,
    IncidentEventType.location => l10n.helpModeEventLocation,
    IncidentEventType.message => l10n.helpModeEventMessage,
    IncidentEventType.resolve => l10n.helpModeEventResolve,
    IncidentEventType.cancel => l10n.helpModeEventCancel,
    IncidentEventType.expire => l10n.helpModeEventExpire,
    IncidentEventType.hazardReport => l10n.helpModeEventCreate,
  };
}
