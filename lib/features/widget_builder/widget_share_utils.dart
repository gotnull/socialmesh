// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/branded_qr_code.dart';
import '../../providers/auth_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import 'models/widget_schema.dart';

/// Show a bottom sheet with QR code and share options for a widget
/// Uploads widget to Firestore and generates a short shareable link
/// Requires user to be signed in for cloud sharing features
Future<void> showWidgetShareSheet(
  BuildContext context,
  WidgetSchema schema, {
  required WidgetRef ref,
}) async {
  // Check if user is signed in
  final user = ref.read(currentUserProvider);
  if (user == null) {
    showActionSnackBar(
      context,
      'Sign in to share widgets',
      actionLabel: 'Sign In',
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  await AppBottomSheet.show(
    context: context,
    child: _ShareSheet(schema: schema, userId: user.uid),
  );
}

/// Create export data for sharing (removes user-specific fields)
Map<String, dynamic> _createExportData(WidgetSchema schema) {
  final exportData = schema.toJson();

  // Remove fields that shouldn't be shared
  exportData.remove('id'); // Generate new ID on import
  exportData.remove('downloadCount');
  exportData.remove('rating');
  exportData.remove('thumbnailUrl');
  exportData.remove('createdAt');
  exportData.remove('updatedAt');
  exportData.remove('schemaVersion'); // Will use current version on import
  exportData['isPublic'] = false;

  return exportData;
}

/// Create a fingerprint from export data to detect duplicates.
/// This excludes variable metadata to focus on the widget structure.
String _createFingerprintFromStoredData(Map<String, dynamic> exportData) {
  // Create a copy to avoid modifying original
  final data = Map<String, dynamic>.from(exportData);

  // Remove fields that shouldn't affect fingerprint
  data.remove('createdBy');
  data.remove('createdAt');
  data.remove('isPublic');

  // Sort keys for consistent ordering and convert to string
  final sortedKeys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.write('$key:${data[key]}|');
  }

  return buffer.toString().hashCode.toRadixString(16);
}

/// Check if an identical widget already exists in the user's shared_widgets.
/// Returns the existing document ID if found, null otherwise.
Future<String?> _findExistingWidget(
  String userId,
  Map<String, dynamic> exportData,
) async {
  final fingerprint = _createFingerprintFromStoredData(exportData);
  final name = exportData['name'] as String?;

  // Query for widgets by this user with the same name (more efficient query)
  final query = FirebaseFirestore.instance
      .collection('shared_widgets')
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
        AppLogging.widgets(
          '[WidgetShare] Found existing widget "$name" with ID ${doc.id}',
        );
        return doc.id;
      }
    }
  } catch (e) {
    AppLogging.widgets('[WidgetShare] Error checking for duplicates: $e');
    // Fall through to create new widget
  }

  return null;
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.schema, required this.userId});

  final WidgetSchema schema;
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
      final exportData = _createExportData(widget.schema);

      // Check if an identical widget already exists
      final existingId = await _findExistingWidget(widget.userId, exportData);
      String docId;

      if (existingId != null) {
        // Reuse existing widget
        docId = existingId;
        AppLogging.widgets(
          '[WidgetShare] Reusing existing widget "${widget.schema.name}" '
          'with ID $docId',
        );
      } else {
        // Upload new widget to Firestore shared_widgets collection
        final docRef = await FirebaseFirestore.instance
            .collection('shared_widgets')
            .add({
              ...exportData,
              'createdBy': widget.userId,
              'createdAt': FieldValue.serverTimestamp(),
            });
        docId = docRef.id;
        AppLogging.widgets(
          '[WidgetShare] Uploaded widget "${widget.schema.name}" '
          'with ID $docId',
        );
      }

      // Generate short share URL using the document ID
      final shareUrl = AppUrls.shareWidgetUrl(docId);

      if (mounted) {
        setState(() {
          _shareUrl = shareUrl;
          _isUploading = false;
        });
      }
    } catch (e) {
      AppLogging.widgets('[WidgetShare] Upload failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to upload widget: $e';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        BottomSheetHeader(
          icon: Icons.qr_code_2,
          title: 'Share Widget',
          subtitle: widget.schema.name,
        ),
        const SizedBox(height: 24),

        // Content based on state
        if (_isUploading)
          _buildLoading()
        else if (_error != null)
          _buildError()
        else
          _buildQrCode(),

        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        const SizedBox(
          width: 250,
          height: 250,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading widget...'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Container(
          width: 250,
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.errorRed,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Failed',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
      ],
    );
  }

  Widget _buildQrCode() {
    // Deep link for QR code scanning within the app
    // Use socialmesh:// scheme with Firestore doc ID
    final deepLink = 'socialmesh://widget/id:${_shareUrl!.split('/').last}';

    return Column(
      children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: BrandedQrCode(data: deepLink, size: 220),
        ),
        const SizedBox(height: 16),

        // Instructions
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
                  'Scan this QR code in Socialmesh to import this widget',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Share actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _shareAsLink,
                icon: const Icon(Icons.share),
                label: const Text('Share Link'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _shareAsLink() async {
    if (_shareUrl == null) return;

    AppLogging.widgets(
      'Share widget: Starting share for "${widget.schema.name}"',
    );

    // Capture share position before async gap (required for iPad)
    final sharePosition = getSafeSharePosition(context);

    try {
      await Share.share(
        'Check out this widget on Socialmesh!\n$_shareUrl',
        subject: 'Socialmesh Widget: ${widget.schema.name}',
        sharePositionOrigin: sharePosition,
      );
    } catch (e) {
      AppLogging.widgets('Share widget: ERROR - $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to share: $e');
      }
    }
  }

  Future<void> _copyLink() async {
    if (_shareUrl == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _shareUrl!));
      if (mounted) {
        showSuccessSnackBar(context, 'Link copied to clipboard');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to copy: $e');
      }
    }
  }
}
