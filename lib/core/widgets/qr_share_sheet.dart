// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import 'app_bottom_sheet.dart';
import 'branded_qr_code.dart';
import 'status_banner.dart';

/// A standardized bottom sheet for sharing QR codes across the app.
///
/// This widget provides a consistent look and feel for all QR code sharing
/// functionality. ALL QR sharing should use this widget - no exceptions.
///
/// Features:
/// - Consistent header with QR icon, title, subtitle
/// - Branded QR code with app logo
/// - Info text below QR code
/// - Share Link + Copy Link buttons
/// - Loading and error states for async operations
class QrShareSheet extends StatelessWidget {
  const QrShareSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.qrData,
    this.infoText,
    this.shareUrl,
    this.shareSubject,
    this.shareMessage,
    this.onShareComplete,
    this.onCopyComplete,
  });

  /// The main title displayed at the top of the sheet.
  final String title;

  /// The subtitle displayed below the title.
  final String subtitle;

  /// The data to encode in the QR code (typically a deep link).
  final String qrData;

  /// Optional info text displayed below the QR code.
  final String? infoText;

  /// The URL to share/copy. If null, qrData is used.
  final String? shareUrl;

  /// Subject for share intent.
  final String? shareSubject;

  /// Message prefix for share intent (URL appended after).
  final String? shareMessage;

  /// Called after share action completes.
  final VoidCallback? onShareComplete;

  /// Called after copy action completes.
  final VoidCallback? onCopyComplete;

  /// Shows the QR share sheet as a modal bottom sheet.
  ///
  /// This is the standard way to show a QR share sheet.
  /// Use this for simple cases where data is already available.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String qrData,
    String? infoText,
    String? shareUrl,
    String? shareSubject,
    String? shareMessage,
    VoidCallback? onShareComplete,
    VoidCallback? onCopyComplete,
  }) {
    return AppBottomSheet.show(
      context: context,
      child: QrShareSheet(
        title: title,
        subtitle: subtitle,
        qrData: qrData,
        infoText: infoText,
        shareUrl: shareUrl,
        shareSubject: shareSubject,
        shareMessage: shareMessage,
        onShareComplete: onShareComplete,
        onCopyComplete: onCopyComplete,
      ),
    );
  }

  /// Shows a QR share sheet with async loading.
  ///
  /// Use this when data needs to be uploaded/fetched first.
  /// The [loader] function should return the share data.
  static Future<void> showWithLoader({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Future<QrShareData> Function() loader,
    String? infoText,
    String? shareSubject,
    String? shareMessage,
  }) {
    return AppBottomSheet.show(
      context: context,
      child: _AsyncQrShareSheet(
        title: title,
        subtitle: subtitle,
        loader: loader,
        infoText: infoText,
        shareSubject: shareSubject,
        shareMessage: shareMessage,
      ),
    );
  }

  String get _effectiveShareUrl => shareUrl ?? qrData;

  @override
  Widget build(BuildContext context) {
    return _QrShareContent(
      title: title,
      subtitle: subtitle,
      qrData: qrData,
      infoText: infoText,
      shareUrl: _effectiveShareUrl,
      shareSubject: shareSubject,
      shareMessage: shareMessage,
      onShareComplete: onShareComplete,
      onCopyComplete: onCopyComplete,
    );
  }
}

/// Data returned from async loader for QR share sheet.
class QrShareData {
  const QrShareData({required this.qrData, required this.shareUrl});

  /// The data to encode in the QR code (typically a deep link).
  final String qrData;

  /// The URL to share/copy (typically https URL).
  final String shareUrl;
}

/// Async wrapper that shows loading/error states.
class _AsyncQrShareSheet extends StatefulWidget {
  const _AsyncQrShareSheet({
    required this.title,
    required this.subtitle,
    required this.loader,
    this.infoText,
    this.shareSubject,
    this.shareMessage,
  });

  final String title;
  final String subtitle;
  final Future<QrShareData> Function() loader;
  final String? infoText;
  final String? shareSubject;
  final String? shareMessage;

  @override
  State<_AsyncQrShareSheet> createState() => _AsyncQrShareSheetState();
}

class _AsyncQrShareSheetState extends State<_AsyncQrShareSheet> {
  bool _isLoading = true;
  String? _error;
  QrShareData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await widget.loader();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading(context);
    }

    if (_error != null) {
      return _buildError(context);
    }

    return _QrShareContent(
      title: widget.title,
      subtitle: widget.subtitle,
      qrData: _data!.qrData,
      infoText: widget.infoText,
      shareUrl: _data!.shareUrl,
      shareSubject: widget.shareSubject,
      shareMessage: widget.shareMessage,
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QrShareHeader(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 48),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Preparing share link...',
          style: TextStyle(color: context.textSecondary),
        ),
        const SizedBox(height: 48),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QrShareHeader(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 24),
        StatusBanner.error(title: _error!),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            _loadData();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        const SizedBox(height: 24),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

/// The actual QR share content - used by both sync and async versions.
class _QrShareContent extends StatefulWidget {
  const _QrShareContent({
    required this.title,
    required this.subtitle,
    required this.qrData,
    required this.shareUrl,
    this.infoText,
    this.shareSubject,
    this.shareMessage,
    this.onShareComplete,
    this.onCopyComplete,
  });

  final String title;
  final String subtitle;
  final String qrData;
  final String shareUrl;
  final String? infoText;
  final String? shareSubject;
  final String? shareMessage;
  final VoidCallback? onShareComplete;
  final VoidCallback? onCopyComplete;

  @override
  State<_QrShareContent> createState() => _QrShareContentState();
}

class _QrShareContentState extends State<_QrShareContent> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _QrShareHeader(title: widget.title, subtitle: widget.subtitle),
        const SizedBox(height: 24),

        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: BrandedQrCode(data: widget.qrData, size: 220),
        ),

        // Info text
        if (widget.infoText != null) ...[
          const SizedBox(height: 16),
          StatusBanner.accent(title: widget.infoText!, margin: EdgeInsets.zero),
        ],

        // Action buttons
        const SizedBox(height: 24),
        _buildButtons(context),

        // Bottom safe area
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        // Share Link button (outlined, left)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSharing ? null : () => _handleShare(context),
            icon: _isSharing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : const Icon(Icons.share, size: 18),
            label: Text(_isSharing ? 'Sharing...' : 'Share Link'),
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
        // Copy Link button (filled, right)
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSharing ? null : () => _handleCopy(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Link'),
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

  Future<void> _handleShare(BuildContext context) async {
    setState(() => _isSharing = true);
    HapticFeedback.lightImpact();
    final sharePosition = getSafeSharePosition(context);

    try {
      final message = widget.shareMessage != null
          ? '${widget.shareMessage}\n${widget.shareUrl}'
          : widget.shareUrl;
      await Share.share(
        message,
        subject: widget.shareSubject,
        sharePositionOrigin: sharePosition,
      );
      widget.onShareComplete?.call();
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _handleCopy(BuildContext context) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: widget.shareUrl));
    Navigator.pop(context);
    showSuccessSnackBar(context, 'Link copied to clipboard');
    widget.onCopyComplete?.call();
  }
}

/// Standard header for QR share sheets.
class _QrShareHeader extends StatelessWidget {
  const _QrShareHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
}
