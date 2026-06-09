// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../utils/snackbar.dart';

/// Shared favorite / mute / traceroute action helpers used by both
/// [showNodeQuickActionsSheet] and [NodeDetailScreen].
///
/// Each helper owns the protocol round-trip, the local SharedPreferences
/// mirror, the `nodesProvider` state refresh, the snackbar, and the
/// AppLogging markers. Callers stay thin: the quick-action sheet just
/// awaits the future; the detail screen wraps it in a busy-flag setter
/// so the inline button can show a spinner.
///
/// All `ref.read` calls happen BEFORE awaits (per CLAUDE.md async safety)
/// and every post-await UI touch is guarded by `context.mounted`.

Future<void> toggleNodeFavorite(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final protocol = ref.read(protocolServiceProvider);
  final nodesNotifier = ref.read(nodesProvider.notifier);
  final deviceFavorites = ref.read(deviceFavoritesProvider).value;
  final next = !node.isFavorite;

  try {
    if (node.isFavorite) {
      await protocol.removeFavoriteNode(node.nodeNum);
      await deviceFavorites?.removeFavorite(node.nodeNum);
    } else {
      await protocol.setFavoriteNode(node.nodeNum);
      await deviceFavorites?.addFavorite(node.nodeNum);
    }
    nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: next));
    AppLogging.nodes(
      '[NodeActions] favorite toggled nodeNum=${node.nodeNum} next=$next',
    );
    if (context.mounted) {
      showSuccessSnackBar(
        context,
        next
            ? context.l10n.nodeDetailAddedToFavorites(node.displayName)
            : context.l10n.nodeDetailRemovedFromFavorites(node.displayName),
      );
    }
  } catch (e, st) {
    AppLogging.nodes(
      '[NodeActions] favorite failed nodeNum=${node.nodeNum} error=$e\n$st',
    );
    if (context.mounted) {
      showErrorSnackBar(
        context,
        context.l10n.quickActionFavoriteFailed(e.toString()),
      );
    }
  }
}

Future<void> toggleNodeMute(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final connectionState = ref.read(connectionStateProvider);
  final isConnected = connectionState.maybeWhen(
    data: (state) => state == DeviceConnectionState.connected,
    orElse: () => false,
  );
  if (!isConnected) {
    AppLogging.nodes(
      '[NodeActions] mute denied - not connected nodeNum=${node.nodeNum}',
    );
    if (context.mounted) {
      showErrorSnackBar(context, context.l10n.nodeDetailMuteNotConnected);
    }
    return;
  }

  final protocol = ref.read(protocolServiceProvider);
  final nodesNotifier = ref.read(nodesProvider.notifier);
  final deviceFavorites = ref.read(deviceFavoritesProvider).value;
  final next = !node.isIgnored;

  try {
    if (node.isIgnored) {
      await protocol.removeIgnoredNode(node.nodeNum);
      await deviceFavorites?.removeIgnored(node.nodeNum);
    } else {
      await protocol.setIgnoredNode(node.nodeNum);
      await deviceFavorites?.addIgnored(node.nodeNum);
    }
    nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: next));
    AppLogging.nodes(
      '[NodeActions] mute toggled nodeNum=${node.nodeNum} next=$next',
    );
    if (context.mounted) {
      showSuccessSnackBar(
        context,
        next
            ? context.l10n.nodeDetailMuted(node.displayName)
            : context.l10n.nodeDetailUnmuted(node.displayName),
      );
    }
  } catch (e, st) {
    AppLogging.nodes(
      '[NodeActions] mute failed nodeNum=${node.nodeNum} error=$e\n$st',
    );
    if (context.mounted) {
      showErrorSnackBar(
        context,
        context.l10n.quickActionMuteFailed(e.toString()),
      );
    }
  }
}

/// Sends a traceroute to [node]. Returns true on success, false when
/// the cooldown blocks the send or the device is disconnected. Callers
/// own busy-flag state (the persistent cooldown toolbar is the canonical
/// "in progress" indicator; this helper does not require additional
/// inline spinners).
Future<bool> sendNodeTraceroute(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final cooldownNotifier = ref.read(countdownProvider.notifier);
  final cooldownRemaining = cooldownNotifier.globalTracerouteRemaining;
  if (cooldownRemaining > 0) {
    AppLogging.telemetry(
      '[NodeActions] traceroute denied - cooldown active '
      'nodeNum=${node.nodeNum} remaining=${cooldownRemaining}s',
    );
    if (context.mounted) {
      showWarningSnackBar(
        context,
        context.l10n.quickActionTracerouteCooldown(cooldownRemaining),
      );
    }
    return false;
  }

  final connectionState = ref.read(connectionStateProvider);
  final isConnected = connectionState.maybeWhen(
    data: (state) => state == DeviceConnectionState.connected,
    orElse: () => false,
  );
  if (!isConnected) {
    AppLogging.telemetry(
      '[NodeActions] traceroute denied - not connected nodeNum=${node.nodeNum}',
    );
    if (context.mounted) {
      showErrorSnackBar(context, context.l10n.nodeDetailTracerouteNotConnected);
    }
    return false;
  }

  AppLogging.telemetry(
    '[NodeActions] traceroute requested nodeNum=${node.nodeNum}',
  );

  final protocol = ref.read(protocolServiceProvider);
  try {
    await protocol.sendTraceroute(node.nodeNum);
    cooldownNotifier.startTracerouteCountdown(node.nodeNum);
    AppLogging.telemetry(
      '[NodeActions] traceroute sent nodeNum=${node.nodeNum}',
    );
    if (context.mounted) {
      showSuccessSnackBar(
        context,
        context.l10n.nodeDetailTracerouteSent(node.displayName),
      );
    }
    return true;
  } catch (e, st) {
    AppLogging.telemetry(
      '[NodeActions] traceroute failed nodeNum=${node.nodeNum} error=$e\n$st',
    );
    if (context.mounted) {
      // "Protocol not ready" gets a friendlier dedicated snackbar; every
      // other error falls back to the generic failure copy.
      if (!maybeShowTxBlockedSnackBar(context, e)) {
        showErrorSnackBar(
          context,
          context.l10n.quickActionTracerouteFailed(e.toString()),
        );
      }
    }
    return false;
  }
}

/// Localized display name for a requestable telemetry [type], reused for
/// snackbar copy and reload tooltips so the wording matches the tile labels.
String telemetryRequestTypeLabel(
  BuildContext context,
  TelemetryRequestType type,
) {
  final l10n = context.l10n;
  switch (type) {
    case TelemetryRequestType.device:
      return l10n.settingsTileDeviceMetricsTitle;
    case TelemetryRequestType.environment:
      return l10n.settingsTileEnvironmentMetricsTitle;
    case TelemetryRequestType.airQuality:
      return l10n.settingsTileAirQualityTitle;
  }
}

/// Requests telemetry of [type] from [node]. Returns true on success, false
/// when the per-type cooldown blocks the send or the device is disconnected.
/// The reload control's cooldown ring is the canonical "in progress"
/// indicator, so callers do not need their own busy flag.
Future<bool> requestNodeTelemetry(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
  TelemetryRequestType type,
) async {
  final cooldownNotifier = ref.read(countdownProvider.notifier);
  final cooldownId = CountdownNotifier.telemetryRequestId(node.nodeNum, type);
  final active = ref.read(countdownProvider)[cooldownId];
  if (active != null && active.remainingSeconds > 0) {
    AppLogging.telemetry(
      '[NodeActions] telemetry request denied - cooldown active '
      'nodeNum=${node.nodeNum} type=${type.name} '
      'remaining=${active.remainingSeconds}s',
    );
    if (context.mounted) {
      showWarningSnackBar(
        context,
        context.l10n.nodeDetailTelemetryRequestCooldown(
          active.remainingSeconds,
        ),
      );
    }
    return false;
  }

  final connectionState = ref.read(connectionStateProvider);
  final isConnected = connectionState.maybeWhen(
    data: (state) => state == DeviceConnectionState.connected,
    orElse: () => false,
  );
  if (!isConnected) {
    AppLogging.telemetry(
      '[NodeActions] telemetry request denied - not connected '
      'nodeNum=${node.nodeNum} type=${type.name}',
    );
    if (context.mounted) {
      showErrorSnackBar(context, context.l10n.nodeDetailTracerouteNotConnected);
    }
    return false;
  }

  final typeLabel = context.mounted
      ? telemetryRequestTypeLabel(context, type)
      : type.name;

  AppLogging.telemetry(
    '[NodeActions] telemetry requested nodeNum=${node.nodeNum} '
    'type=${type.name}',
  );

  final protocol = ref.read(protocolServiceProvider);
  try {
    await protocol.requestTelemetry(node.nodeNum, type: type);
    cooldownNotifier.startTelemetryRequestCountdown(node.nodeNum, type);
    AppLogging.telemetry(
      '[NodeActions] telemetry request sent nodeNum=${node.nodeNum} '
      'type=${type.name}',
    );
    if (context.mounted) {
      showSuccessSnackBar(
        context,
        context.l10n.nodeDetailTelemetryRequested(typeLabel, node.displayName),
      );
    }
    return true;
  } catch (e, st) {
    AppLogging.telemetry(
      '[NodeActions] telemetry request failed nodeNum=${node.nodeNum} '
      'type=${type.name} error=$e\n$st',
    );
    if (context.mounted) {
      if (!maybeShowTxBlockedSnackBar(context, e)) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailTelemetryRequestFailed(e.toString()),
        );
      }
    }
    return false;
  }
}
