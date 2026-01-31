// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../generated/meshtastic/config.pb.dart';
import 'app_bottom_sheet.dart';

/// Action taken by user in device privacy warning dialog
enum DevicePrivacyAction { proceed, cancel }

/// Device privacy warning dialog.
/// Shows when user attempts to link a device that shares location data.
class DevicePrivacyWarning extends StatelessWidget {
  const DevicePrivacyWarning({
    super.key,
    required this.nodeNum,
    required this.deviceName,
    required this.sharesLocation,
    required this.positionConfig,
  });

  final int nodeNum;
  final String deviceName;
  final bool sharesLocation;
  final Config_PositionConfig? positionConfig;

  /// Show the privacy warning as a bottom sheet.
  /// Returns DevicePrivacyAction indicating what user chose.
  static Future<DevicePrivacyAction> show(
    BuildContext context, {
    required int nodeNum,
    required String deviceName,
    required bool sharesLocation,
    required Config_PositionConfig? positionConfig,
  }) async {
    final action = await showModalBottomSheet<DevicePrivacyAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AppBottomSheet(
        child: SafeArea(
          top: false,
          child: _DevicePrivacyWarningContent(
            nodeNum: nodeNum,
            deviceName: deviceName,
            sharesLocation: sharesLocation,
            positionConfig: positionConfig,
          ),
        ),
      ),
    );
    return action ?? DevicePrivacyAction.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return _DevicePrivacyWarningContent(
      nodeNum: nodeNum,
      deviceName: deviceName,
      sharesLocation: sharesLocation,
      positionConfig: positionConfig,
    );
  }
}

class _DevicePrivacyWarningContent extends StatelessWidget {
  const _DevicePrivacyWarningContent({
    required this.nodeNum,
    required this.deviceName,
    required this.sharesLocation,
    required this.positionConfig,
  });

  final int nodeNum;
  final String deviceName;
  final bool sharesLocation;
  final Config_PositionConfig? positionConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with location icon
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sharesLocation
                      ? Icons.location_on
                      : Icons.location_off_outlined,
                  size: 32,
                  color: sharesLocation ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Device Location Sharing',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                sharesLocation
                    ? 'This device is configured to share its GPS location.'
                    : 'This device does not share GPS location data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Privacy details
        if (sharesLocation) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'What This Means',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  context,
                  icon: Icons.public,
                  title: 'Public Visibility',
                  description:
                      'Device location will be visible to all users on the mesh network and in the app\'s World Map.',
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  context,
                  icon: Icons.people_outline,
                  title: 'Follower Access',
                  description:
                      'Your followers will see this device\'s real-time position updates.',
                ),
                if (positionConfig != null &&
                    positionConfig!.positionBroadcastSecs > 0) ...[
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    context,
                    icon: Icons.schedule,
                    title: 'Update Frequency',
                    description:
                        'Location updates every ${positionConfig!.positionBroadcastSecs} seconds.',
                  ),
                ],
              ],
            ),
          ),
        ],

        // Privacy recommendation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sharesLocation
                  ? Colors.blue.withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sharesLocation
                    ? Colors.blue.withAlpha(50)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sharesLocation
                      ? Icons.privacy_tip_outlined
                      : Icons.check_circle_outline,
                  size: 20,
                  color: sharesLocation ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sharesLocation
                        ? 'Your location privacy depends on this device\'s Meshtastic configuration. To change sharing settings, update the device\'s Position Config.'
                        : 'This device has location sharing disabled. Your privacy is protected.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            children: [
              // Primary action: Link device
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context, DevicePrivacyAction.proceed);
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(
                    sharesLocation
                        ? 'Link Device (Location Shared)'
                        : 'Link Device',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancel
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, DevicePrivacyAction.cancel);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade300),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
