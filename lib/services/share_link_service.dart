import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/mesh_models.dart';

/// Service for sharing content with rich Open Graph link previews
class ShareLinkService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ShareLinkService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Share a mesh node with rich preview
  /// Stores complete node data in Firestore for proper deep link handling
  Future<void> shareNode({
    required MeshNode node,
    String? description,
    Rect? sharePositionOrigin,
  }) async {
    // Create a shareable record in Firestore with complete node data
    final docRef = await _firestore.collection('shared_nodes').add({
      'nodeNum': node.nodeNum,
      'nodeId': '!${node.nodeNum.toRadixString(16)}',
      'name': node.displayName,
      'longName': node.longName,
      'shortName': node.shortName,
      'userId': node.userId,
      'description': description ?? 'A mesh node on Socialmesh',
      // Include position if available
      if (node.hasPosition) 'latitude': node.latitude,
      if (node.hasPosition) 'longitude': node.longitude,
      if (node.altitude != null) 'altitude': node.altitude,
      // Include hardware info
      if (node.hardwareModel != null) 'hardwareModel': node.hardwareModel,
      if (node.role != null) 'role': node.role,
      // Metadata
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final shareUrl = AppUrls.shareNodeUrl(docRef.id);

    await Share.share(
      'Check out ${node.displayName} on Socialmesh!\n$shareUrl',
      subject: '${node.displayName} - Socialmesh Node',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share a mesh node with basic info only (legacy method)
  /// Prefer using shareNode with MeshNode for complete data
  Future<void> shareNodeBasic({
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

    final shareUrl = AppUrls.shareNodeUrl(docRef.id);

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
    final shareUrl = AppUrls.shareProfileUrl(userId);

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
    final shareUrl = AppUrls.shareWidgetUrl(widgetId);

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
    final shareUrl = AppUrls.shareLocationUrl(
      latitude,
      longitude,
      label: label,
    );

    final text = label != null
        ? 'Check out $label on Socialmesh!\n$shareUrl'
        : 'Check out this location on Socialmesh!\n$shareUrl';

    await Share.share(
      text,
      subject: label ?? 'Socialmesh Location',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share a post with rich preview
  Future<void> sharePost({
    required String postId,
    Rect? sharePositionOrigin,
  }) async {
    final shareUrl = AppUrls.sharePostUrl(postId);

    await Share.share(
      'Check out this post on Socialmesh!\n$shareUrl',
      subject: 'Socialmesh Post',
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
