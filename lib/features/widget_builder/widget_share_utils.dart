// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../providers/auth_providers.dart';
import '../../services/share/shared_content_uploader.dart';
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
      context.l10n.widgetBuilderSignInToShare,
      actionLabel: context.l10n.widgetBuilderSignInAction,
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final userId = user.uid;

  await QrShareSheet.showWithLoader(
    context: context,
    title: context.l10n.widgetBuilderShareTitle,
    subtitle: schema.name,
    infoText: context.l10n.widgetBuilderShareInfoText,
    shareSubject: context.l10n.widgetBuilderShareSubject(schema.name),
    shareMessage: context.l10n.widgetBuilderShareMessage,
    loader: () => _uploadAndGetShareData(schema, userId),
  );
}

const _uploader = SharedContentUploader(
  collection: 'shared_widgets',
  log: AppLogging.widgets,
  // isPublic is forced false on export and may be flipped server-side;
  // it must not make an otherwise-identical widget look new.
  fingerprintIgnoredKeys: {'createdBy', 'createdAt', 'isPublic'},
);

/// Uploads widget and returns share data for QR sheet.
Future<QrShareData> _uploadAndGetShareData(
  WidgetSchema schema,
  String userId,
) async {
  final exportData = _createExportData(schema);
  final docId = await _uploader.uploadOrReuse(
    userId: userId,
    exportData: exportData,
    contentName: schema.name,
  );

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
