// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';

/// Localised recovery card for an Android scan refusal: the OS scanner
/// rejected the scan (SCAN_FAILED_*) or a precondition was not met
/// (Location services, scan permission). Shown in place of the raw
/// plugin exception text.
class ScanFailureCard extends StatelessWidget {
  final BleScanFailureKind kind;
  final VoidCallback onDismiss;

  /// Opens the settings page that fixes [kind]. Throttling recovers on
  /// its own, so the card shows no action for it.
  final VoidCallback onOpenSettings;

  const ScanFailureCard({
    super.key,
    required this.kind,
    required this.onDismiss,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (String title, String body) = switch (kind) {
      BleScanFailureKind.stackFailure => (
        l10n.scannerScanStackErrorTitle,
        l10n.scannerScanStackErrorBody,
      ),
      BleScanFailureKind.throttled => (
        l10n.scannerScanThrottledTitle,
        l10n.scannerScanThrottledBody,
      ),
      BleScanFailureKind.locationServicesOff => (
        l10n.scannerLocationServicesOffTitle,
        l10n.scannerLocationServicesOffBody,
      ),
      BleScanFailureKind.permissionDenied => (
        l10n.scannerScanPermissionTitle,
        l10n.scannerScanPermissionBody,
      ),
    };
    final (IconData, String)? action = switch (kind) {
      BleScanFailureKind.throttled => null,
      BleScanFailureKind.stackFailure => (
        Icons.bluetooth_rounded,
        l10n.scannerPairingRefreshOpenBluetoothSettings,
      ),
      BleScanFailureKind.locationServicesOff => (
        Icons.location_on_rounded,
        l10n.scannerOpenLocationSettings,
      ),
      BleScanFailureKind.permissionDenied => (
        Icons.settings_rounded,
        l10n.scannerOpenAppSettings,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            TextButton.icon(
              onPressed: onOpenSettings,
              icon: Icon(action.$1, size: 16, color: context.textPrimary),
              label: Text(
                action.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
