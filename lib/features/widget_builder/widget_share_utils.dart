// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar.dart';
import 'models/widget_schema.dart';

/// Show a bottom sheet with QR code and share options for a widget.
/// Uploads widget to Firestore and generates a short shareable link.
/// Requires user to be signed in for cloud sharing features.
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

  final userId = user.uid;

  await QrShareSheet.showWithLoader(
    context: context,
    title: 'Share Widget',
    subtitle: schema.name,
    infoText: 'Scan this QR code in Socialmesh to import this widget',
    shareSubject: 'Socialmesh Widget: ${schema.name}',
    shareMessage: 'Check out this widget on Socialmesh!',
    loader: () => _uploadAndGetShareData(schema, userId),
  );
}

/// Uploads widget and returns share data for QR sheet.
Future<QrShareData> _uploadAndGetShareData(
  WidgetSchema schema,
  String userId,
) async {
  // Create export data
  final exportData = _createExportData(schema);

  // Check if an identical widget already exists
  final existingId = await _findExistingWidget(userId, exportData);
  String docId;

  if (existingId != null) {
    // Reuse existing widget
    docId = existingId;
    AppLogging.widgets(
      '[WidgetShare] Reusing existing widget "${schema.name}" with ID $docId',
    );
  } else {
    // Upload new widget to Firestore shared_widgets collection
    final docRef = await FirebaseFirestore.instance
        .collection('shared_widgets')
        .add({
          ...exportData,
          'createdBy': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    docId = docRef.id;
    AppLogging.widgets(
      '[WidgetShare] Uploaded widget "${schema.name}" with ID $docId',
    );
  }

  // Generate URLs
  final shareUrl = AppUrls.shareWidgetUrl(docId);
  final deepLink = 'socialmesh://widget/id:$docId';

  return QrShareData(qrData: deepLink, shareUrl: shareUrl);
}

/// Create export data for sharing (removes user-specific fields).
Map<String, dynamic> _createExportData(WidgetSchema schema) {
  final exportData = schema.toJson();

  // Remove fields that shouldn't be shared
  exportData.remove('id');
  exportData.remove('downloadCount');
  exportData.remove('rating');
  exportData.remove('thumbnailUrl');
  exportData.remove('createdAt');
  exportData.remove('updatedAt');
  exportData.remove('schemaVersion');
  exportData['isPublic'] = false;

  return exportData;
}

/// Create a fingerprint from export data to detect duplicates.
String _createFingerprintFromStoredData(Map<String, dynamic> exportData) {
  final data = Map<String, dynamic>.from(exportData);
  data.remove('createdBy');
  data.remove('createdAt');
  data.remove('isPublic');

  final sortedKeys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.write('$key:${data[key]}|');
  }

  return buffer.toString().hashCode.toRadixString(16);
}

/// Check if an identical widget already exists in the user's shared_widgets.
Future<String?> _findExistingWidget(
  String userId,
  Map<String, dynamic> exportData,
) async {
  final fingerprint = _createFingerprintFromStoredData(exportData);
  final name = exportData['name'] as String?;

  final query = FirebaseFirestore.instance
      .collection('shared_widgets')
      .where('createdBy', isEqualTo: userId)
      .where('name', isEqualTo: name)
      .limit(10);

  try {
    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
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
  }

  return null;
}
