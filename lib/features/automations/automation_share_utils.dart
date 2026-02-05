// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/share_utils.dart';
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

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSheet(automation: automation, userId: user.uid),
  );
}

/// Create export data for sharing (removes user-specific fields).
Map<String, dynamic> _createExportData(Automation automation) {
  // Sanitize trigger config - remove user-specific data
  final sanitizedTriggerConfig = Map<String, dynamic>.from(
    automation.trigger.config,
  );
  // Remove node-specific references (recipient won't have the same nodes)
  sanitizedTriggerConfig.remove('nodeNum');
  // Remove channel index (recipient's channel setup may differ)
  sanitizedTriggerConfig.remove('channelIndex');
  // Keep geofence coordinates - they're useful as a template

  // Sanitize actions - remove user-specific data
  final sanitizedActions = automation.actions.map((action) {
    final sanitizedConfig = Map<String, dynamic>.from(action.config);

    // Remove node-specific references
    sanitizedConfig.remove('targetNodeNum');
    // Remove channel index
    sanitizedConfig.remove('targetChannelIndex');
    // Remove webhook credentials (contains user's API keys)
    sanitizedConfig.remove('webhookUrl');
    sanitizedConfig.remove('webhookEventName');
    // Keep shortcutName as a hint, but recipient will need their own

    return {'type': action.type.name, 'config': sanitizedConfig};
  }).toList();

  // Sanitize conditions - remove user-specific data
  final sanitizedConditions = automation.conditions?.map((condition) {
    final sanitizedConfig = Map<String, dynamic>.from(condition.config);
    // Remove node-specific references
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
/// This excludes variable metadata to focus on the automation structure.
String _createFingerprintFromStoredData(Map<String, dynamic> exportData) {
  // Create a copy to avoid modifying original
  final data = Map<String, dynamic>.from(exportData);

  // Remove fields that shouldn't affect fingerprint
  data.remove('createdBy');
  data.remove('createdAt');

  // Sort keys for consistent ordering and convert to string
  final sortedKeys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.write('$key:${data[key]}|');
  }

  return buffer.toString().hashCode.toRadixString(16);
}

/// Check if an identical automation already exists in the user's shared_automations.
/// Returns the existing document ID if found, null otherwise.
Future<String?> _findExistingAutomation(
  String userId,
  Map<String, dynamic> exportData,
) async {
  final fingerprint = _createFingerprintFromStoredData(exportData);
  final name = exportData['name'] as String?;

  // Query for automations by this user with the same name (more efficient query)
  final query = FirebaseFirestore.instance
      .collection('shared_automations')
      .where('createdBy', isEqualTo: userId)
      .where('name', isEqualTo: name)
      .limit(10); // Limit results since we're comparing fingerprints

  try {
    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
      // Re-create fingerprint from stored data to compare
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
    // Fall through to create new automation
  }

  return null;
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.automation, required this.userId});

  final Automation automation;
  final String userId;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _isUploading = true;
  String? _shareUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _uploadAndGenerateLink();
  }

  Future<void> _uploadAndGenerateLink() async {
    try {
      // Create export data
      final exportData = _createExportData(widget.automation);

      // Check if an identical automation already exists
      final existingId = await _findExistingAutomation(
        widget.userId,
        exportData,
      );
      String docId;

      if (existingId != null) {
        // Reuse existing automation
        docId = existingId;
        AppLogging.automations(
          '[AutomationShare] Reusing existing automation '
          '"${widget.automation.name}" with ID $docId',
        );
      } else {
        // Upload new automation to Firestore shared_automations collection
        final docRef = await FirebaseFirestore.instance
            .collection('shared_automations')
            .add({
              ...exportData,
              'createdBy': widget.userId,
              'createdAt': FieldValue.serverTimestamp(),
            });
        docId = docRef.id;
        AppLogging.automations(
          '[AutomationShare] Uploaded automation "${widget.automation.name}" '
          'with ID $docId',
        );
      }

      // Generate short share URL using the document ID
      final shareUrl = AppUrls.shareAutomationUrl(docId);

      if (mounted) {
        setState(() {
          _shareUrl = shareUrl;
          _isUploading = false;
        });
      }
    } catch (e) {
      AppLogging.automations('[AutomationShare] Upload failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to upload automation: $e';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            children: [
              Icon(Icons.qr_code_2, color: context.accentColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Automation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      widget.automation.name,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content based on state
          if (_isUploading) ...[
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Preparing share link...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 40),
          ] else if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isUploading = true;
                  _error = null;
                });
                _uploadAndGenerateLink();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ] else ...[
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _shareUrl!,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 24),

            // Share URL display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _shareUrl!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan QR code or share link to import this automation',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Share actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareAsLink(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Share Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _copyLink(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _shareAsLink(BuildContext context) async {
    if (_shareUrl == null) return;

    AppLogging.automations(
      '[AutomationShare] Starting share for "${widget.automation.name}"',
    );

    // Capture share position before async gap (required for iPad)
    final sharePosition = getSafeSharePosition(context);

    try {
      await Share.share(
        'Check out my Socialmesh automation: ${widget.automation.name}\n$_shareUrl',
        subject: 'Socialmesh Automation: ${widget.automation.name}',
        sharePositionOrigin: sharePosition,
      );
      AppLogging.automations('[AutomationShare] Share completed');
    } catch (e) {
      AppLogging.automations('[AutomationShare] ERROR - $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share: $e');
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    if (_shareUrl == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _shareUrl!));
      if (context.mounted) {
        showSuccessSnackBar(context, 'Link copied to clipboard');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to copy: $e');
      }
    }
  }
}
