// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'app_bottom_sheet.dart';
import 'branded_qr_code.dart';

/// A standardized bottom sheet for sharing QR codes across the app.
///
/// This widget provides a consistent look and feel for all QR code sharing
/// functionality, including the QR code display, title, subtitle, and action
/// buttons.
class QrShareSheet extends StatelessWidget {
  const QrShareSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.qrData,
    this.infoText,
    this.shareUrl,
    this.onShare,
    this.onCopy,
    this.primaryButtonLabel = 'Share Link',
    this.secondaryButtonLabel = 'Copy Link',
    this.showButtons = true,
    this.qrSize = 220,
  });

  /// The main title displayed at the top of the sheet.
  final String title;

  /// The subtitle displayed below the title.
  final String subtitle;

  /// The data to encode in the QR code (typically a deep link).
  final String qrData;

  /// Optional info text displayed below the QR code.
  final String? infoText;

  /// The URL to share (can be different from qrData for https vs deep links).
  final String? shareUrl;

  /// Custom share action. If null, uses default Share.share.
  final VoidCallback? onShare;

  /// Custom copy action. If null, copies shareUrl to clipboard.
  final VoidCallback? onCopy;

  /// Label for the primary (share) button.
  final String primaryButtonLabel;

  /// Label for the secondary (copy) button.
  final String secondaryButtonLabel;

  /// Whether to show the action buttons.
  final bool showButtons;

  /// Size of the QR code.
  final double qrSize;

  /// Shows the QR share sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String qrData,
    String? infoText,
    String? shareUrl,
    VoidCallback? onShare,
    VoidCallback? onCopy,
    String primaryButtonLabel = 'Share Link',
    String secondaryButtonLabel = 'Copy Link',
    bool showButtons = true,
    double qrSize = 220,
  }) {
    return AppBottomSheet.show(
      context: context,
      child: QrShareSheet(
        title: title,
        subtitle: subtitle,
        qrData: qrData,
        infoText: infoText,
        shareUrl: shareUrl,
        onShare: onShare,
        onCopy: onCopy,
        primaryButtonLabel: primaryButtonLabel,
        secondaryButtonLabel: secondaryButtonLabel,
        showButtons: showButtons,
        qrSize: qrSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _buildHeader(context),
        const SizedBox(height: 24),

        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: BrandedQrCode(data: qrData, size: qrSize),
        ),

        // Info text
        if (infoText != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    infoText!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Action buttons
        if (showButtons) ...[
          const SizedBox(height: 24),
          _buildButtons(context),
        ],

        // Bottom safe area
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.qr_code_2, color: context.accentColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: context.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (onShare != null) {
                onShare!();
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text(primaryButtonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.accentColor,
              side: BorderSide(color: context.accentColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              if (onCopy != null) {
                onCopy!();
              } else if (shareUrl != null) {
                Clipboard.setData(ClipboardData(text: shareUrl!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(secondaryButtonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
