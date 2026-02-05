// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../providers/auth_providers.dart';
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
      'Sign in to share automations',
      actionLabel: 'Sign In',
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final userId = user.uid;

  await QrShareSheet.showWithLoader(
    context: context,
    title: 'Share Automation',
    subtitle: automation.name,
    infoText: 'Scan this QR code in Socialmesh to import this automation',
    shareSubject: 'Socialmesh Automation: ${automation.name}',
    shareMessage: 'Check out this automation on Socialmesh!',
    loader: () => _uploadAndGetShareData(automation, userId),
  );
}

/// Uploads automation and returns share data for QR sheet.
Future<QrShareData> _uploadAndGetShareData(
  Automation automation,
  String userId,
) async {
  // Create export data
  final exportData = _createExportData(automation);

  // Check if an identical automation already exists
  final existingId = await _findExistingAutomation(userId, exportData);
  String docId;

  if (existingId != null) {
    // Reuse existing automation
    docId = existingId;
    AppLogging.automations(
      '[AutomationShare] Reusing existing automation "${automation.name}" '
      'with ID $docId',
    );
  } else {
    // Upload new automation to Firestore shared_automations collection
    final docRef = await FirebaseFirestore.instance
        .collection('shared_automations')
        .add({
          ...exportData,
          'createdBy': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    docId = docRef.id;
    AppLogging.automations(
      '[AutomationShare] Uploaded automation "${automation.name}" '
      'with ID $docId',
    );
  }

  // Generate URLs
  final shareUrl = AppUrls.shareAutomationUrl(docId);
  final deepLink = 'socialmesh://automation/id:$docId';

  return QrShareData(qrData: deepLink, shareUrl: shareUrl);
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
  final sanitizedActions = automation.actions.map((action) {
    final sanitizedConfig = Map<String, dynamic>.from(action.config);
    sanitizedConfig.remove('targetNodeNum');
    sanitizedConfig.remove('targetChannelIndex');
    sanitizedConfig.remove('webhookUrl');
    sanitizedConfig.remove('webhookEventName');
    return {'type': action.type.name, 'config': sanitizedConfig};
  }).toList();

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
    if (sanitizedConditions != null) 'conditions': sanitizedConditions,
  };
}

/// Create a fingerprint from export data to detect duplicates.
String _createFingerprintFromStoredData(Map<String, dynamic> exportData) {
  final data = Map<String, dynamic>.from(exportData);
  data.remove('createdBy');
  data.remove('createdAt');

  final sortedKeys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.write('$key:${data[key]}|');
  }

  return buffer.toString().hashCode.toRadixString(16);
}

/// Check if an identical automation already exists in the user's shared_automations.
Future<String?> _findExistingAutomation(
  String userId,
  Map<String, dynamic> exportData,
) async {
  final fingerprint = _createFingerprintFromStoredData(exportData);
  final name = exportData['name'] as String?;

  final query = FirebaseFirestore.instance
      .collection('shared_automations')
      .where('createdBy', isEqualTo: userId)
      .where('name', isEqualTo: name)
      .limit(10);

  try {
    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
      final storedData = doc.data();
      final storedFingerprint = _createFingerprintFromStoredData(storedData);

      if (storedFingerprint == fingerprint) {
        AppLogging.automations(
          '[AutomationShare] Found existing automation "$name" with ID ${doc.id}',
        );
        return doc.id;
      }
    }
  } catch (e) {
    AppLogging.automations(
      '[AutomationShare] Error checking for duplicates: $e',
    );
  }

  return null;
}
