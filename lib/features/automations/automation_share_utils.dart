// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../providers/auth_providers.dart';
import '../../services/share/shared_content_uploader.dart';
import '../../utils/snackbar.dart';
import 'models/automation.dart';

/// Show a bottom sheet with QR code and share options for an automation.
/// Uploads automation to Firestore and generates a short shareable link.
/// Requires user to be signed in for cloud sharing features.
Future<void> showAutomationShareSheet(
  BuildContext context,
  Automation automation, {
  required WidgetRef ref,
}) async {
  // Check if user is signed in
  final user = ref.read(currentUserProvider);
  if (user == null) {
    showActionSnackBar(
      context,
      context.l10n.automationShareSignIn,
      actionLabel: context.l10n.automationShareSignInAction,
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final userId = user.uid;

  await QrShareSheet.showWithLoader(
    context: context,
    title: context.l10n.automationShareTitle,
    subtitle: automation.name,
    infoText: context.l10n.automationShareScanInfo,
    shareSubject: context.l10n.automationShareSubject(automation.name),
    shareMessage: context.l10n.automationShareMessage,
    loader: () => _uploadAndGetShareData(automation, userId),
  );
}

const _uploader = SharedContentUploader(
  collection: 'shared_automations',
  log: AppLogging.automations,
);

/// Uploads automation and returns share data for QR sheet.
Future<QrShareData> _uploadAndGetShareData(
  Automation automation,
  String userId,
) async {
  final exportData = _createExportData(automation);
  final docId = await _uploader.uploadOrReuse(
    userId: userId,
    exportData: exportData,
    contentName: automation.name,
  );

  // Generate URLs
  final shareUrl = AppUrls.shareAutomationUrl(docId);
  final deepLink = 'socialmesh://automation/id:$docId';

  return QrShareData(qrData: deepLink, shareUrl: shareUrl);
}

/// Sanitize an action list by removing user-specific data.
List<Map<String, dynamic>> _sanitizeActions(List<AutomationAction> actions) {
  return actions.map((action) {
    final sanitizedConfig = Map<String, dynamic>.from(action.config);
    sanitizedConfig.remove('targetNodeNum');
    sanitizedConfig.remove('targetChannelIndex');
    sanitizedConfig.remove('webhookUrl');
    sanitizedConfig.remove('webhookEventName');
    return {'type': action.type.name, 'config': sanitizedConfig};
  }).toList();
}

/// Create export data for sharing (removes user-specific fields).
Map<String, dynamic> _createExportData(Automation automation) {
  // Sanitize trigger config - remove user-specific data
  final sanitizedTriggerConfig = Map<String, dynamic>.from(
    automation.trigger.config,
  );
  sanitizedTriggerConfig.remove('nodeNum');
  sanitizedTriggerConfig.remove('channelIndex');

  // Sanitize actions - remove user-specific data
  final sanitizedActions = _sanitizeActions(automation.actions);

  // Sanitize branch action lists
  final sanitizedThenActions = automation.thenActions != null
      ? _sanitizeActions(automation.thenActions!)
      : null;
  final sanitizedElseActions = automation.elseActions != null
      ? _sanitizeActions(automation.elseActions!)
      : null;

  // Sanitize conditions - remove user-specific data
  final sanitizedConditions = automation.conditions?.map((condition) {
    final sanitizedConfig = Map<String, dynamic>.from(condition.config);
    sanitizedConfig.remove('nodeNum');
    return {'type': condition.type.name, 'config': sanitizedConfig};
  }).toList();

  return {
    'name': automation.name,
    'description': automation.description,
    'trigger': {
      'type': automation.trigger.type.name,
      'config': sanitizedTriggerConfig,
    },
    'actions': sanitizedActions,
    if (sanitizedThenActions != null) 'thenActions': sanitizedThenActions,
    if (sanitizedElseActions != null) 'elseActions': sanitizedElseActions,
    if (sanitizedConditions != null) 'conditions': sanitizedConditions,
  };
}
