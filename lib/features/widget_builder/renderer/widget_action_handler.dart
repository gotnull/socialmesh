import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/widget_schema.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/action_sheets.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';

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
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.sendPositionOnce();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Location shared with mesh');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share location: $e');
      }
    }
  }

  Future<void> _handleTraceroute(ActionSchema action) async {
    // Show traceroute sheet
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: TracerouteSheetContent(ref: ref),
    );
  }

  Future<void> _handleRequestPositions() async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Position requests sent to all nodes');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request positions: $e');
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
