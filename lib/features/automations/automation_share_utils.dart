// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import 'models/automation.dart';

/// Show a bottom sheet with QR code and share options for an automation
/// Requires user to be signed in for cloud sharing features
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

  // Generate base64 data with sanitized export
  final exportData = {
    'name': automation.name,
    'description': automation.description,
    'trigger': {
      'type': automation.trigger.type.name,
      'config': sanitizedTriggerConfig,
    },
    'actions': sanitizedActions,
    if (sanitizedConditions != null) 'conditions': sanitizedConditions,
  };

  final jsonString = jsonEncode(exportData);
  final base64Data = base64Encode(
    utf8.encode(jsonString),
  ).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

  final deepLink = 'socialmesh://automation/$base64Data';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSheet(
      automation: automation,
      deepLink: deepLink,
      base64Data: base64Data,
    ),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.automation,
    required this.deepLink,
    required this.base64Data,
  });

  final Automation automation;
  final String deepLink;
  final String base64Data;

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
                      automation.name,
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

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: deepLink,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan this QR code in Socialmesh to import this automation',
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
          const SizedBox(height: 8),

          // Data size info
          Text(
            'Link size: ${base64Data.length} characters',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _shareAsLink(BuildContext context) async {
    AppLogging.automations(
      'Share automation: Starting share for "${automation.name}"',
    );
    AppLogging.automations(
      'Share automation: Deep link length: ${deepLink.length}',
    );

    // Capture share position before async gap (required for iPad)
    final sharePosition = getSafeSharePosition(context);

    try {
      AppLogging.automations('Share automation: Calling Share.share()');
      await Share.share(
        deepLink,
        subject: 'Socialmesh Automation: ${automation.name}',
        sharePositionOrigin: sharePosition,
      );
      AppLogging.automations('Share automation: Share.share() completed');
    } catch (e) {
      AppLogging.automations('Share automation: ERROR - $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share: $e');
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    try {
      await _copyToClipboard(deepLink);
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

  Future<void> _copyToClipboard(String text) async {
    // Use Flutter's clipboard API
    await Clipboard.setData(ClipboardData(text: text));
  }
}
