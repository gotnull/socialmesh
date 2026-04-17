// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

import '../../../l10n/app_localizations.dart';
import 'mesh_service_signal_kind.dart';
import 'mesh_service_template.dart';

String meshServiceTypeName(AppLocalizations l10n, MeshServiceType type) {
  return switch (type) {
    MeshServiceType.feed => l10n.meshServicesTypeFeed,
    MeshServiceType.list => l10n.meshServicesTypeList,
    MeshServiceType.poll => l10n.meshServicesTypePoll,
    MeshServiceType.signal => l10n.meshServicesTypeSignal,
    MeshServiceType.sensor => l10n.meshServicesTypeSensor,
    MeshServiceType.game => l10n.meshServicesTypeGame,
  };
}

String meshServiceIntentName(AppLocalizations l10n, MeshServiceType type) {
  return switch (type) {
    MeshServiceType.feed => l10n.meshServicesIntentFeed,
    MeshServiceType.list => l10n.meshServicesIntentList,
    MeshServiceType.poll => l10n.meshServicesIntentPoll,
    MeshServiceType.signal => l10n.meshServicesIntentSignal,
    MeshServiceType.sensor => l10n.meshServicesIntentSensor,
    MeshServiceType.game => l10n.meshServicesIntentGame,
  };
}

String meshServiceIntentDescription(
  AppLocalizations l10n,
  MeshServiceType type,
) {
  return switch (type) {
    MeshServiceType.feed => l10n.meshServicesIntentFeedDescription,
    MeshServiceType.list => l10n.meshServicesIntentListDescription,
    MeshServiceType.poll => l10n.meshServicesIntentPollDescription,
    MeshServiceType.signal => l10n.meshServicesIntentSignalDescription,
    MeshServiceType.sensor => l10n.meshServicesIntentSensorDescription,
    MeshServiceType.game => l10n.meshServicesIntentGameDescription,
  };
}

String meshServiceTypeDescription(AppLocalizations l10n, MeshServiceType type) {
  return switch (type) {
    MeshServiceType.feed => l10n.meshServicesTypeFeedDescription,
    MeshServiceType.list => l10n.meshServicesTypeListDescription,
    MeshServiceType.poll => l10n.meshServicesTypePollDescription,
    MeshServiceType.signal => l10n.meshServicesTypeSignalDescription,
    MeshServiceType.sensor => l10n.meshServicesTypeSensorDescription,
    MeshServiceType.game => l10n.meshServicesTypeGameDescription,
  };
}

String meshServicePresetName(
  AppLocalizations l10n,
  MeshServicePresetId presetId,
) {
  return switch (presetId) {
    MeshServicePresetId.bulletinBoard => l10n.meshServicesTemplateBoard,
    MeshServicePresetId.trailConditions =>
      l10n.meshServicesTemplateTrailConditions,
    MeshServicePresetId.lostAndFound => l10n.meshServicesTemplateLostAndFound,
    MeshServicePresetId.sharedChecklist => l10n.meshServicesTemplateChecklist,
    MeshServicePresetId.resourceList => l10n.meshServicesTemplateResourceList,
    MeshServicePresetId.taskBoard => l10n.meshServicesTemplateTaskBoard,
    MeshServicePresetId.weatherStation =>
      l10n.meshServicesTemplateWeatherStation,
    MeshServicePresetId.sensorNode => l10n.meshServicesTemplateSensorNode,
    MeshServicePresetId.rpsV1 => l10n.meshGamesTypeRps,
    MeshServicePresetId.ticTacToeV1 => l10n.meshGamesTypeTicTacToe,
  };
}

String meshServicePresetDescription(
  AppLocalizations l10n,
  MeshServicePresetId presetId,
) {
  return switch (presetId) {
    MeshServicePresetId.bulletinBoard =>
      l10n.meshServicesTemplateBoardDescription,
    MeshServicePresetId.trailConditions =>
      l10n.meshServicesTemplateTrailConditionsDescription,
    MeshServicePresetId.lostAndFound =>
      l10n.meshServicesTemplateLostAndFoundDescription,
    MeshServicePresetId.sharedChecklist =>
      l10n.meshServicesTemplateChecklistDescription,
    MeshServicePresetId.resourceList =>
      l10n.meshServicesTemplateResourceListDescription,
    MeshServicePresetId.taskBoard =>
      l10n.meshServicesTemplateTaskBoardDescription,
    MeshServicePresetId.weatherStation =>
      l10n.meshServicesTemplateWeatherStationDescription,
    MeshServicePresetId.sensorNode =>
      l10n.meshServicesTemplateSensorNodeDescription,
    MeshServicePresetId.rpsV1 => l10n.meshGamesTypeRpsDescription,
    MeshServicePresetId.ticTacToeV1 => l10n.meshGamesTypeTicTacToeDescription,
  };
}

String meshServiceDisplayName(
  AppLocalizations l10n, {
  required MeshServiceType canonicalType,
  MeshServicePresetId? presetId,
}) {
  return presetId == null
      ? meshServiceTypeName(l10n, canonicalType)
      : meshServicePresetName(l10n, presetId);
}

String meshServiceDisplayDescription(
  AppLocalizations l10n, {
  required MeshServiceType canonicalType,
  MeshServicePresetId? presetId,
}) {
  return presetId == null
      ? meshServiceTypeDescription(l10n, canonicalType)
      : meshServicePresetDescription(l10n, presetId);
}

String meshServiceSignalKindName(
  AppLocalizations l10n,
  MeshServiceSignalKind kind,
) {
  return switch (kind) {
    MeshServiceSignalKind.checkIn => l10n.meshServicesSignalKindCheckIn,
    MeshServiceSignalKind.needHelp => l10n.meshServicesSignalKindNeedHelp,
    MeshServiceSignalKind.hazard => l10n.meshServicesSignalKindHazard,
    MeshServiceSignalKind.meetHere => l10n.meshServicesSignalKindMeetHere,
    MeshServiceSignalKind.relayActive => l10n.meshServicesSignalKindRelayActive,
  };
}
