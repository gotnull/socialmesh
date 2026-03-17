// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/widget_schema.dart';

import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/action_sheets.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/countdown_providers.dart';
import '../../../services/location/phone_position_governor.dart';
import '../../../utils/snackbar.dart';
import '../../settings/settings_screen.dart';

/// Handles action execution for custom widgets
class WidgetActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  WidgetActionHandler({required this.context, required this.ref});

  /// Static convenience method to handle an action
  static Future<void> handleAction(
    BuildContext context,
    WidgetRef ref,
    ActionSchema action,
  ) async {
    final handler = WidgetActionHandler(context: context, ref: ref);
    await handler.execute(action);
  }

  /// Execute an action from an element's ActionSchema
  Future<void> execute(ActionSchema action) async {
    switch (action.type) {
      case ActionType.none:
        return;

      case ActionType.sendMessage:
        await _handleSendMessage(action);

      case ActionType.shareLocation:
        await _handleShareLocation();

      case ActionType.traceroute:
        await _handleTraceroute(action);

      case ActionType.requestPositions:
        await _handleRequestPositions();

      case ActionType.sos:
        await _handleSos();

      case ActionType.navigate:
        _handleNavigate(action);

      case ActionType.openUrl:
        await _handleOpenUrl(action);

      case ActionType.copyToClipboard:
        // This would need the resolved value from binding
        break;
    }
  }

  Future<void> _handleSendMessage(ActionSchema action) async {
    // Show quick message bottom sheet directly - it has its own node selector
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: QuickMessageSheetContent(ref: ref),
    );
  }

  Future<void> _handleShareLocation() async {
    if (!context.mounted) return;

    // Show node selector to choose who to share location with.
    // The governor handles the providePhoneLocation gate, so we no longer
    // need a manual check here — it will deny with blockedDisabled.
    final selection = await NodeSelectorSheet.show(
      context,
      title: context.l10n.widgetBuilderShareLocationWith,
      allowBroadcast: true,
      broadcastLabel: context.l10n.widgetBuilderAllNodes,
      broadcastSubtitle: context.l10n.widgetBuilderBroadcastSubtitle,
    );

    if (selection == null || !context.mounted) return;

    try {
      final locationService = ref.read(locationServiceProvider);

      if (selection.isBroadcast) {
        // Route broadcast through the governor for centralized rate limiting.
        final decision = await locationService.publishWithReason(
          PositionPublishReason.widgetAction,
        );
        if (!context.mounted) return;

        switch (decision) {
          case PublishDecision.allowed:
            showSuccessSnackBar(
              context,
              context.l10n.widgetBuilderLocationSharedMesh,
            );
          case PublishDecision.blockedDisabled:
            final navigator = Navigator.of(context);
            showActionSnackBar(
              context,
              context.l10n.widgetBuilderEnablePhoneLocation,
              actionLabel: context.l10n.widgetBuilderView,
              onAction: () => navigator.push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(
                    initialSearchQuery: 'phone location',
                  ),
                ),
              ),
              type: SnackBarType.warning,
            );
          case PublishDecision.blockedInterval:
            showWarningSnackBar(
              context,
              context.l10n.widgetBuilderLocationSharedRecently,
            );
          case PublishDecision.blockedDistance:
          case PublishDecision.blockedNoPosition:
            showErrorSnackBar(
              context,
              context.l10n.widgetBuilderUnableToGetLocation,
            );
        }
      } else {
        // Direct sends to a specific node use ProtocolService directly.
        // These are already rate-limited by the 10s direct cooldown and
        // are not subject to the broadcast governor (different use case).
        final position = await locationService.getCurrentPosition();

        if (position == null) {
          if (context.mounted) {
            showErrorSnackBar(
              context,
              context.l10n.widgetBuilderUnableToGetLocation,
            );
          }
          return;
        }

        final protocol = ref.read(protocolServiceProvider);
        await protocol.sendPositionToNode(
          nodeNum: selection.nodeNum!,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude.toInt(),
        );
        if (context.mounted) {
          final nodes = ref.read(nodesProvider);
          final targetNode = nodes[selection.nodeNum!];
          final targetName = targetNode?.displayName ?? 'node';
          showSuccessSnackBar(
            context,
            context.l10n.widgetBuilderLocationSharedWithNode(targetName),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.widgetBuilderFailedToShareLocation(e.toString()),
        );
      }
    }
  }

  Future<void> _handleTraceroute(ActionSchema action) async {
    // Show traceroute sheet
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: const TracerouteSheetContent(),
    );
  }

  Future<void> _handleRequestPositions() async {
    // Prevent duplicate requests while a countdown is active
    final notifier = ref.read(countdownProvider.notifier);
    if (notifier.isPositionRequestActive) return;

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();

      // Start global position request countdown — banner persists
      // across navigation and sets expectations for trickle-in time.
      notifier.startPositionRequestCountdown();
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.widgetBuilderFailedToRequestPositions(e.toString()),
        );
      }
    }
  }

  Future<void> _handleSos() async {
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SosSheetContent(ref: ref),
    );
  }

  void _handleNavigate(ActionSchema action) {
    if (action.navigateTo == null) return;
    Navigator.of(context).pushNamed(action.navigateTo!);
  }

  Future<void> _handleOpenUrl(ActionSchema action) async {
    if (action.url == null) return;
    final uri = Uri.tryParse(action.url!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
