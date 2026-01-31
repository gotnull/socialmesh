// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../providers/app_providers.dart';
import '../utils/text_sanitizer.dart';

/// Represents a parsed deep link
sealed class DeepLinkData {
  const DeepLinkData();
}

/// Node deep link - can be from QR code (base64 encoded) or web share (Firestore doc ID)
class NodeDeepLink extends DeepLinkData {
  final int? nodeNum;
  final String? longName;
  final String? shortName;
  final String? userId;
  final double? latitude;
  final double? longitude;
  final String? firestoreDocId; // For web share links

  const NodeDeepLink({
    this.nodeNum,
    this.longName,
    this.shortName,
    this.userId,
    this.latitude,
    this.longitude,
    this.firestoreDocId,
  });

  bool get hasValidNodeData => nodeNum != null;
  bool get needsFirestoreFetch => firestoreDocId != null && nodeNum == null;
}

/// Channel deep link with encoded channel settings
class ChannelDeepLink extends DeepLinkData {
  final String base64Data;

  const ChannelDeepLink({required this.base64Data});
}

/// Profile deep link
class ProfileDeepLink extends DeepLinkData {
  final String profileId;

  const ProfileDeepLink({required this.profileId});
}

/// Widget marketplace deep link
class WidgetDeepLink extends DeepLinkData {
  final String widgetId;

  const WidgetDeepLink({required this.widgetId});
}

/// Post deep link
class PostDeepLink extends DeepLinkData {
  final String postId;

  const PostDeepLink({required this.postId});
}

/// Location deep link
class LocationDeepLink extends DeepLinkData {
  final double latitude;
  final double longitude;
  final String? label;

  const LocationDeepLink({
    required this.latitude,
    required this.longitude,
    this.label,
  });
}

/// Deep link handling service using app_links package
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  // Firestore reference is optional and only obtained when needed so that
  // this service can be constructed before Firebase initialization completes.
  // If null, we lazily access FirebaseFirestore.instance in fetchSharedNodeData.
  final FirebaseFirestore? _firestore;
  final Ref _ref;

  StreamSubscription<Uri>? _linkSubscription;
  final _linkController = StreamController<DeepLinkData>.broadcast();

  /// Stream of parsed deep links
  Stream<DeepLinkData> get linkStream => _linkController.stream;

  DeepLinkService(this._ref, {FirebaseFirestore? firestore}) : _firestore = firestore;

  /// Initialize deep link handling
  Future<void> initialize() async {
    AppLogging.debug('🔗 Initializing deep link service');

    // Handle initial link (app opened via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        AppLogging.debug('🔗 Initial deep link: $initialUri');
        final parsed = await parseLink(initialUri.toString());
        if (parsed != null) {
          _linkController.add(parsed);
        }
      }
    } catch (e) {
      AppLogging.debug('🔗 Error getting initial link: $e');
    }

    // Listen for incoming links while app is running
    await _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        AppLogging.debug('🔗 Received deep link: $uri');
        final parsed = await parseLink(uri.toString());
        if (parsed != null) {
          _linkController.add(parsed);
        }
      },
      onError: (error) {
        AppLogging.debug('🔗 Deep link stream error: $error');
      },
    );
  }

  /// Parse a deep link URL into structured data
  /// Supports both socialmesh:// custom scheme and https://socialmesh.app URLs
  Future<DeepLinkData?> parseLink(String link) async {
    try {
      final uri = Uri.parse(link);

      // Handle https://socialmesh.app/share/* URLs
      if (uri.scheme == 'https' && uri.host == 'socialmesh.app') {
        return _parseWebLink(uri);
      }

      // Handle socialmesh:// scheme
      if (uri.scheme != 'socialmesh') {
        AppLogging.debug('🔗 Unknown scheme: ${uri.scheme}');
        return null;
      }

      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) {
        AppLogging.debug('🔗 Empty path in deep link');
        return null;
      }

      final type = pathSegments[0];
      final data = pathSegments.length > 1 ? pathSegments[1] : null;

      switch (type) {
        case 'node':
          return _parseNodeLink(data, uri.queryParameters);

        case 'channel':
          if (data != null) {
            return ChannelDeepLink(base64Data: data);
          }
          return null;

        case 'profile':
          if (data != null) {
            return ProfileDeepLink(profileId: data);
          }
          return null;

        case 'widget':
          if (data != null) {
            return WidgetDeepLink(widgetId: data);
          }
          return null;

        case 'post':
          if (data != null) {
            return PostDeepLink(postId: data);
          }
          return null;

        case 'location':
          return _parseLocationLink(uri.queryParameters);

        default:
          AppLogging.debug('🔗 Unknown deep link type: $type');
          return null;
      }
    } catch (e) {
      AppLogging.debug('🔗 Error parsing deep link: $e');
      return null;
    }
  }

  /// Parse https://socialmesh.app/share/* URLs
  DeepLinkData? _parseWebLink(Uri uri) {
    final pathSegments = uri.pathSegments;

    // Expected: /share/{type}/{id}
    if (pathSegments.length < 2 || pathSegments[0] != 'share') {
      AppLogging.debug('🔗 Invalid web link path: ${uri.path}');
      return null;
    }

    final type = pathSegments[1];
    final id = pathSegments.length > 2 ? pathSegments[2] : null;

    switch (type) {
      case 'node':
        // Web share links use Firestore doc ID
        if (id != null) {
          return NodeDeepLink(firestoreDocId: id);
        }
        return null;

      case 'profile':
        if (id != null) {
          return ProfileDeepLink(profileId: id);
        }
        return null;

      case 'widget':
        if (id != null) {
          return WidgetDeepLink(widgetId: id);
        }
        return null;

      case 'post':
        if (id != null) {
          return PostDeepLink(postId: id);
        }
        return null;

      case 'location':
        return _parseLocationLink(uri.queryParameters);

      default:
        AppLogging.debug('🔗 Unknown web link type: $type');
        return null;
    }
  }

  /// Parse node deep link
  /// Supports two formats:
  /// 1. Base64 encoded JSON (from QR codes): `socialmesh://node/<base64>`
  /// 2. Firestore doc ID (from web shares): `socialmesh://node/<docId>`
  Future<NodeDeepLink?> _parseNodeLink(
    String? data,
    Map<String, String> queryParams,
  ) async {
    if (data == null || data.isEmpty) return null;

    // Try to decode as base64 JSON first (QR code format)
    try {
      final decoded = utf8.decode(base64Decode(data));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return NodeDeepLink(
        nodeNum: json['nodeNum'] as int?,
        longName: json['longName'] as String?,
        shortName: json['shortName'] as String?,
        userId: json['userId'] as String?,
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lon'] as num?)?.toDouble(),
      );
    } catch (_) {
      // Not base64 - assume it's a Firestore document ID
      AppLogging.debug('🔗 Node link appears to be Firestore doc ID: $data');
      return NodeDeepLink(firestoreDocId: data);
    }
  }

  /// Parse location deep link
  LocationDeepLink? _parseLocationLink(Map<String, String> params) {
    final lat = double.tryParse(params['lat'] ?? '');
    final lng = double.tryParse(params['lng'] ?? '');

    if (lat == null || lng == null) return null;

    return LocationDeepLink(
      latitude: lat,
      longitude: lng,
      label: params['label'],
    );
  }

  /// Fetch node data from Firestore for web share links
  Future<NodeDeepLink?> fetchSharedNodeData(String docId) async {
    try {
      // If a Firestore instance was injected, use it; otherwise obtain one
      // lazily. Accessing `FirebaseFirestore.instance` can throw if Firebase
      // hasn't been initialized yet, so guard that and return `null` instead
      // of throwing.
      final firestore =
          _firestore ??
          (() {
            try {
              return FirebaseFirestore.instance;
            } catch (e) {
              AppLogging.debug('🔗 Firebase not available yet: $e');
              return null;
            }
          }());

      if (firestore == null) {
        AppLogging.debug(
          '🔗 Skipping shared node fetch - Firestore unavailable',
        );
        return null;
      }

      final doc = await firestore.collection('shared_nodes').doc(docId).get();
      if (!doc.exists) {
        AppLogging.debug('🔗 Shared node document not found: $docId');
        return null;
      }

      final data = doc.data()!;
      return NodeDeepLink(
        nodeNum: data['nodeNum'] as int?,
        longName: data['longName'] as String? ?? data['name'] as String?,
        shortName: data['shortName'] as String?,
        userId: data['userId'] as String?,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
      );
    } catch (e) {
      AppLogging.debug('🔗 Error fetching shared node: $e');
      return null;
    }
  }

  /// Handle a node deep link - adds to tracked nodes
  Future<bool> handleNodeLink(NodeDeepLink link) async {
    var nodeData = link;

    // Fetch from Firestore if needed
    if (link.needsFirestoreFetch) {
      final fetched = await fetchSharedNodeData(link.firestoreDocId!);
      if (fetched == null || !fetched.hasValidNodeData) {
        AppLogging.debug('🔗 Failed to fetch node data from Firestore');
        return false;
      }
      nodeData = fetched;
    }

    if (!nodeData.hasValidNodeData) {
      AppLogging.debug('🔗 Invalid node data in deep link');
      return false;
    }

    // Create a MeshNode from the deep link data, sanitizing names to prevent UTF-16 crashes
    final node = MeshNode(
      nodeNum: nodeData.nodeNum!,
      longName: nodeData.longName != null ? sanitizeUtf16(nodeData.longName!) : null,
      shortName: nodeData.shortName != null ? sanitizeUtf16(nodeData.shortName!) : null,
      userId: nodeData.userId,
      latitude: nodeData.latitude,
      longitude: nodeData.longitude,
      lastHeard: DateTime.now(),
    );

    // Add to nodes provider
    _ref.read(nodesProvider.notifier).addOrUpdateNode(node);

    AppLogging.debug(
      '🔗 Added node from deep link: ${node.displayName} (${node.nodeNum})',
    );

    return true;
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkController.close();
  }
}

/// Provider for deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the stream of incoming deep links
final deepLinkStreamProvider = StreamProvider<DeepLinkData>((ref) {
  final service = ref.watch(deepLinkServiceProvider);
  return service.linkStream;
});

/// Notifier for pending deep link (set when app receives a link)
class PendingDeepLinkNotifier extends Notifier<DeepLinkData?> {
  @override
  DeepLinkData? build() => null;

  void setLink(DeepLinkData? link) => state = link;
  void clear() => state = null;
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, DeepLinkData?>(
      PendingDeepLinkNotifier.new,
    );
