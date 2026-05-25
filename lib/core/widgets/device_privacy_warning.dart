// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../generated/meshtastic/config.pb.dart';
import '../l10n/l10n_extension.dart';
import 'app_bottom_sheet.dart';
import 'package:socialmesh/core/theme.dart';

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
    final action = await AppBottomSheet.show<DevicePrivacyAction>(
      context: context,
      isDismissible: false,
      child: _DevicePrivacyWarningContent(
        nodeNum: nodeNum,
        deviceName: deviceName,
        sharesLocation: sharesLocation,
        positionConfig: positionConfig,
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
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 24, 20, 16),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AccentColors.blue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sharesLocation
                      ? Icons.location_on
                      : Icons.location_off_outlined,
                  size: 32,
                  color: sharesLocation
                      ? AccentColors.blue
                      : SemanticColors.disabled,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                context.l10n.devicePrivacyLocationSharing,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                sharesLocation
                    ? context.l10n.devicePrivacySharingEnabled
                    : context.l10n.devicePrivacySharingDisabled,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AccentColors.blue,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.devicePrivacyWhatThisMeans,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildInfoItem(
                  context,
                  icon: Icons.public,
                  title: context.l10n.devicePrivacyPublicVisibility,
                  description: context.l10n.devicePrivacyPublicDescription,
                ),
                const SizedBox(height: AppTheme.spacing12),
                _buildInfoItem(
                  context,
                  icon: Icons.people_outline,
                  title: context.l10n.devicePrivacyFollowerAccess,
                  description: context.l10n.devicePrivacyFollowerDescription,
                ),
                if (positionConfig != null &&
                    positionConfig!.positionBroadcastSecs > 0) ...[
                  const SizedBox(height: AppTheme.spacing12),
                  _buildInfoItem(
                    context,
                    icon: Icons.schedule,
                    title: context.l10n.devicePrivacyUpdateFrequency,
                    description: context.l10n
                        .devicePrivacyUpdateFrequencyDescription(
                          positionConfig!.positionBroadcastSecs,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Privacy recommendation
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: sharesLocation
                  ? AccentColors.blue.withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color: sharesLocation
                    ? AccentColors.blue.withAlpha(50)
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
                  color: sharesLocation
                      ? AccentColors.blue
                      : AppTheme.successGreen,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    sharesLocation
                        ? context.l10n.devicePrivacyPrivacyDependsNote
                        : context.l10n.devicePrivacyPrivacyProtected,
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
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 24),
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
                        ? context.l10n.devicePrivacyLinkDeviceLocationShared
                        : context.l10n.devicePrivacyLinkDevice,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
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
                  child: Text(context.l10n.commonCancel),
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
        Icon(icon, size: 16, color: AccentColors.blue),
        const SizedBox(width: AppTheme.spacing8),
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
              const SizedBox(height: AppTheme.spacing2),
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
