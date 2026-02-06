// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../models/mesh_models.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar.dart';

/// Show a bottom sheet with QR code and share options for a channel.
/// Uploads channel to Firestore and generates a short shareable link.
/// Requires user to be signed in for cloud sharing features.
Future<void> showChannelShareSheet(
  BuildContext context,
  ChannelConfig channel, {
  required WidgetRef ref,
  String? displayTitle,
}) async {
  // Check if user is signed in
  final user = ref.read(currentUserProvider);
  if (user == null) {
    showActionSnackBar(
      context,
      'Sign in to share channels',
      actionLabel: 'Sign In',
      onAction: () => Navigator.pushNamed(context, '/account'),
      type: SnackBarType.info,
    );
    return;
  }

  final userId = user.uid;
  final channelName =
      displayTitle ??
      (channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name);

  await QrShareSheet.showWithLoader(
    context: context,
    title: 'Share Channel',
    subtitle: channelName,
    infoText: 'Scan this QR code in Socialmesh to import this channel',
    shareSubject: 'Socialmesh Channel: $channelName',
    shareMessage: 'Join my channel on Socialmesh!',
    loader: () => _uploadAndGetShareData(channel, userId),
  );
}

/// Uploads channel and returns share data for QR sheet.
Future<QrShareData> _uploadAndGetShareData(
  ChannelConfig channel,
  String userId,
) async {
  // Create export data
  final exportData = _createExportData(channel);

  // Check if an identical channel already exists
  final existingId = await _findExistingChannel(userId, exportData);
  String docId;

  if (existingId != null) {
    // Reuse existing channel
    docId = existingId;
    AppLogging.channels(
      '[ChannelShare] Reusing existing channel "${channel.name}" '
      'with ID $docId',
    );
  } else {
    // Upload new channel to Firestore shared_channels collection
    final docRef = await FirebaseFirestore.instance
        .collection('shared_channels')
        .add({
          ...exportData,
          'createdBy': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    docId = docRef.id;
    AppLogging.channels(
      '[ChannelShare] Uploaded channel "${channel.name}" with ID $docId',
    );
  }

  // Generate URLs
  final shareUrl = AppUrls.shareChannelUrl(docId);
  final deepLink = 'socialmesh://channel/id:$docId';

  return QrShareData(qrData: deepLink, shareUrl: shareUrl);
}

/// Create export data for sharing.
/// Stores the PSK as base64 for Firestore compatibility.
Map<String, dynamic> _createExportData(ChannelConfig channel) {
  return {
    'name': channel.name,
    'psk': base64Encode(channel.psk),
    'index': channel.index,
    'role': channel.role,
    'uplink': channel.uplink,
    'downlink': channel.downlink,
    'positionPrecision': channel.positionPrecision,
  };
}

/// Create a fingerprint from export data to detect duplicates.
String _createFingerprintFromStoredData(Map<String, dynamic> exportData) {
  final data = Map<String, dynamic>.from(exportData);
  data.remove('createdBy');
  data.remove('createdAt');

  final sortedKeys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final key in sortedKeys) {
    buffer.write('$key:${data[key]}|');
  }

  return buffer.toString().hashCode.toRadixString(16);
}

/// Check if an identical channel already exists in the user's shared_channels.
Future<String?> _findExistingChannel(
  String userId,
  Map<String, dynamic> exportData,
) async {
  final fingerprint = _createFingerprintFromStoredData(exportData);
  final name = exportData['name'] as String?;

  final query = FirebaseFirestore.instance
      .collection('shared_channels')
      .where('createdBy', isEqualTo: userId)
      .where('name', isEqualTo: name)
      .limit(10);

  try {
    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
      final storedData = doc.data();
      final storedFingerprint = _createFingerprintFromStoredData(storedData);

      if (storedFingerprint == fingerprint) {
        AppLogging.channels(
          '[ChannelShare] Found existing channel "$name" with ID ${doc.id}',
        );
        return doc.id;
      }
    }
  } catch (e) {
    AppLogging.channels('[ChannelShare] Error checking for duplicates: $e');
  }

  return null;
}
