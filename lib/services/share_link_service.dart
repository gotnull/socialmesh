import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for sharing content with rich Open Graph link previews
class ShareLinkService {
  static const String baseUrl = 'https://socialmesh.app';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ShareLinkService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Share a mesh node with rich preview
  Future<void> shareNode({
    required String nodeId,
    required String nodeName,
    String? description,
    Rect? sharePositionOrigin,
  }) async {
    // Create a shareable record in Firestore
    final docRef = await _firestore.collection('shared_nodes').add({
      'nodeId': nodeId,
      'name': nodeName,
      'description': description ?? 'A mesh node on Socialmesh',
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final shareUrl = '$baseUrl/share/node/${docRef.id}';

    await Share.share(
      'Check out $nodeName on Socialmesh!\n$shareUrl',
      subject: '$nodeName - Socialmesh Node',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share user profile with rich preview
  Future<void> shareProfile({
    required String userId,
    required String displayName,
    Rect? sharePositionOrigin,
  }) async {
    final shareUrl = '$baseUrl/share/profile/$userId';

    await Share.share(
      'Check out $displayName on Socialmesh!\n$shareUrl',
      subject: '$displayName - Socialmesh Profile',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share a widget from the marketplace with rich preview
  Future<void> shareWidget({
    required String widgetId,
    required String widgetName,
    Rect? sharePositionOrigin,
  }) async {
    final shareUrl = '$baseUrl/share/widget/$widgetId';

    await Share.share(
      'Check out $widgetName on Socialmesh!\n$shareUrl',
      subject: '$widgetName - Socialmesh Widget',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share a location with rich preview
  Future<void> shareLocation({
    required double latitude,
    required double longitude,
    String? label,
    Rect? sharePositionOrigin,
  }) async {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);

    var shareUrl = '$baseUrl/share/location?lat=$lat&lng=$lng';
    if (label != null) {
      shareUrl += '&label=${Uri.encodeComponent(label)}';
    }

    final text = label != null
        ? 'Check out $label on Socialmesh!\n$shareUrl'
        : 'Check out this location on Socialmesh!\n$shareUrl';

    await Share.share(
      text,
      subject: label ?? 'Socialmesh Location',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share plain text (fallback, no rich preview)
  Future<void> shareText({
    required String text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}

/// Provider for ShareLinkService
final shareLinkServiceProvider = Provider<ShareLinkService>((ref) {
  return ShareLinkService();
});
