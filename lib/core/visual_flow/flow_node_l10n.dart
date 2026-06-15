// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';

/// Resolves a flow node port/node title to its localized version.
///
/// Node definitions use `const` constructors, so titles are hardcoded English
/// strings at compile time. Call this function at display time to map each
/// English title to its localized equivalent.
///
/// Falls back to the original English [title] when no localization exists.
String localizedFlowTitle(String title, AppLocalizations l10n) {
  return switch (title) {
    // Trigger nodes — displayNames
    'Event' => l10n.flowNodeEvent,
    'Node Online' => l10n.flowNodeNodeOnline,
    'Node Offline' => l10n.flowNodeNodeOffline,
    'Battery Low' => l10n.flowNodeBatteryLow,
    'Battery Full' => l10n.flowNodeBatteryFull,
    'Message Received' => l10n.flowNodeMessageReceived,
    'Message Contains' => l10n.flowNodeMessageContains,
    'Position Changed' => l10n.flowNodePositionChanged,
    'Geofence Enter' => l10n.flowNodeGeofenceEnter,
    'Geofence Exit' => l10n.flowNodeGeofenceExit,
    'Node Silent' => l10n.flowNodeNodeSilent,
    'Scheduled' => l10n.flowNodeScheduled,
    'Signal Weak' => l10n.flowNodeSignalWeak,
    'Channel Activity' => l10n.flowNodeChannelActivity,
    'Detection Sensor' => l10n.flowNodeDetectionSensor,
    'Manual' => l10n.flowNodeManual,
    // Action nodes — displayNames
    'Send Message' => l10n.flowNodeSendMessage,
    'Play Sound' => l10n.flowNodePlaySound,
    'Vibrate' => l10n.flowNodeVibrate,
    'Push Notification' => l10n.flowNodePushNotification,
    'Trigger Webhook' => l10n.flowNodeTriggerWebhook,
    'Log Event' => l10n.flowNodeLogEvent,
    'Update Widget' => l10n.flowNodeUpdateWidget,
    'Send to Channel' => l10n.flowNodeSendToChannel,
    'Trigger Shortcut' => l10n.flowNodeTriggerShortcut,
    'Execute' => l10n.flowNodeExecute,
    // Condition nodes — displayNames
    'Time Range' => l10n.flowNodeTimeRange,
    'Day of Week' => l10n.flowNodeDayOfWeek,
    'Battery Above' => l10n.flowNodeBatteryAbove,
    'Battery Below' => l10n.flowNodeBatteryBelow,
    'Node Is Online' => l10n.flowNodeNodeIsOnline,
    'Node Is Offline' => l10n.flowNodeNodeIsOffline,
    'Within Geofence' => l10n.flowNodeWithinGeofence,
    'Outside Geofence' => l10n.flowNodeOutsideGeofence,
    // Logic gate nodes — displayNames + descriptions
    'AND' => l10n.flowNodeAnd,
    'OR' => l10n.flowNodeOr,
    'NOT' => l10n.flowNodeNot,
    'Delay' => l10n.flowNodeDelay,
    'All Met' => l10n.flowNodeAllMet,
    'Any Met' => l10n.flowNodeAnyMet,
    'Inverted' => l10n.flowNodeInverted,
    'Delayed' => l10n.flowNodeDelayed,
    'All inputs must pass' => l10n.flowNodeGateAllMustPass,
    'Any input can pass' => l10n.flowNodeGateAnyCanPass,
    'Inverts the signal' => l10n.flowNodeGateInverts,
    'Delays the signal' => l10n.flowNodeGateDelays,
    // Subgroup names
    'Triggers' => l10n.flowSubgroupTriggers,
    'Conditions' => l10n.flowSubgroupConditions,
    'Logic' => l10n.flowSubgroupLogic,
    'Actions' => l10n.flowSubgroupActions,
    'NodeDex' => l10n.flowSubgroupNodeDex,
    // NodeDex query nodes
    'All Nodes' => l10n.flowNodeAllNodes,
    'Nodes' => l10n.flowNodeNodes,
    'Trait Filter' => l10n.flowNodeTraitFilter,
    'Distance Filter' => l10n.flowNodeDistanceFilter,
    'Encounter Filter' => l10n.flowNodeEncounterFilter,
    'Online Filter' => l10n.flowNodeOnlineFilter,
    'Battery Filter' => l10n.flowNodeBatteryFilter,
    'Name Filter' => l10n.flowNodeNameFilter,
    'Sort' => l10n.flowNodeSort,
    'Limit' => l10n.flowNodeLimit,
    'Input' => l10n.flowNodeInput,
    'Filtered' => l10n.flowNodeFiltered,
    'Sorted' => l10n.flowNodeSorted,
    'Limited' => l10n.flowNodeLimited,
    _ => title,
  };
}
