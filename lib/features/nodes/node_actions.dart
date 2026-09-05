// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bottom_sheet.dart';
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

/// Confirms and removes [node] from the device NodeDB and local state.
/// Returns true when the node was actually removed. Set [popOnSuccess]
/// when the calling screen presents the node itself and must close once
/// the node no longer exists.
Future<bool> confirmAndRemoveNode(
  BuildContext context,
  WidgetRef ref,
  MeshNode node, {
  bool popOnSuccess = false,
}) async {
  final confirmed = await AppBottomSheet.showConfirm(
    context: context,
    title: context.l10n.nodeDetailRemoveTitle,
    message: context.l10n.nodeDetailRemoveMessage(node.displayName),
    confirmLabel: context.l10n.nodeDetailRemoveConfirm,
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return false;

  final protocol = ref.read(protocolServiceProvider);
  final nodesNotifier = ref.read(nodesProvider.notifier);

  try {
    await protocol.removeNode(node.nodeNum);
    nodesNotifier.removeNode(node.nodeNum);
    AppLogging.nodes('[NodeActions] node removed nodeNum=${node.nodeNum}');
    if (context.mounted) {
      if (popOnSuccess) Navigator.pop(context);
      showSuccessSnackBar(
        context,
        context.l10n.nodeDetailRemovedSnackbar(node.displayName),
      );
    }
    return true;
  } catch (e, st) {
    AppLogging.nodes(
      '[NodeActions] remove failed nodeNum=${node.nodeNum} error=$e\n$st',
    );
    if (context.mounted) {
      showErrorSnackBar(
        context,
        context.l10n.nodeDetailRemoveError(e.toString()),
      );
    }
    return false;
  }
}

Future<void> toggleNodeFavorite(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final protocol = ref.read(protocolServiceProvider);
  final nodesNotifier = ref.read(nodesProvider.notifier);
  final next = !node.isFavorite;

  try {
    if (node.isFavorite) {
      await protocol.removeFavoriteNode(node.nodeNum);
    } else {
      await protocol.setFavoriteNode(node.nodeNum);
    }
    await nodesNotifier.setNodeFavorite(node.nodeNum, next);
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

/// Lets the user choose which channel a traceroute to [node] goes out on.
///
/// Returns the chosen channel index, or null when the sheet was dismissed.
/// The channel [node] was last heard on is preselected and tagged; it is
/// what a plain tap on the traceroute button uses, so the picker only earns
/// its keep when the node lives behind another channel (an MQTT or UDP
/// bridged secondary, for example). Disabled channel slots are not offered.
Future<int?> pickTracerouteChannel(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final l10n = context.l10n;
  final channels =
      ref
          .read(channelsProvider)
          .where((c) => c.index == 0 || c.role != 'DISABLED')
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  if (channels.isEmpty) return null;

  final lastHeard = node.lastHeardChannel ?? 0;
  final preselected = channels.firstWhere(
    (c) => c.index == lastHeard,
    orElse: () => channels.first,
  );

  String nameOf(ChannelConfig c) {
    if (c.name.isNotEmpty) return c.name;
    return c.index == 0
        ? l10n.channelFormPrimaryChannelTitle
        : l10n.channelsDefaultChannelName(c.index);
  }

  final picked = await AppBottomSheet.showPicker<ChannelConfig>(
    context: context,
    title: l10n.nodeDetailTracerouteChannelTitle,
    items: channels,
    selectedItem: preselected,
    itemBuilder: (channel, isSelected) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected ? context.accentColor : context.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${channel.index}  ${nameOf(channel)}',
                  style: TextStyle(
                    color: isSelected
                        ? context.textPrimary
                        : context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (channel.index == lastHeard)
                  Text(
                    l10n.nodeDetailTracerouteChannelLastHeard,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return picked?.index;
}

/// Sends a traceroute to [node]. Returns true on success, false when
/// the cooldown blocks the send or the device is disconnected. Callers
/// own busy-flag state (the persistent cooldown toolbar is the canonical
/// "in progress" indicator; this helper does not require additional
/// inline spinners). [channel] overrides the channel index; by default the
/// request goes out on the channel [node] was last heard on.
Future<bool> sendNodeTraceroute(
  BuildContext context,
  WidgetRef ref,
  MeshNode node, {
  int? channel,
}) async {
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
    await protocol.sendTraceroute(node.nodeNum, channel: channel);
    cooldownNotifier.startTracerouteCountdown(node.nodeNum);
    AppLogging.telemetry(
      '[NodeActions] traceroute sent nodeNum=${node.nodeNum}'
      '${channel != null ? ' channel=$channel' : ''}',
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
