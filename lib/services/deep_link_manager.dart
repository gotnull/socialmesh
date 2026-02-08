// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/navigation.dart';
import '../models/mesh_models.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../utils/snackbar.dart';
import '../utils/text_sanitizer.dart';
import 'deep_link/deep_link.dart';
import 'deep_link_service.dart';

/// Manages deep link navigation in a lifecycle-safe manner.
///
/// This is the single entry point for all deep link processing.
/// It uses:
/// - [DeepLinkParser] to parse URIs into [ParsedDeepLink]
/// - [DeepLinkRouter] to determine route destinations
/// - [navigatorKey] for all navigation (never widget context)
///
/// Safety guarantees:
/// 1. Links are queued until the app is fully ready
/// 2. Navigation is scheduled in post-frame callbacks
/// 3. Navigator availability is checked before every navigation
/// 4. All errors are caught and logged (never crash)
class DeepLinkManager {
  DeepLinkManager(this._ref);

  final Ref _ref;

  /// AppLinks instance for native deep link handling.
  final AppLinks _appLinks = AppLinks();

  /// Pending parsed link waiting to be processed.
  ParsedDeepLink? _pendingLink;

  /// Whether the app has signaled it's ready for navigation.
  bool _appReady = false;

  /// Stream subscription for incoming deep links.
  StreamSubscription<Uri>? _linkSubscription;

  /// Deduplication: track last processed link target to avoid double navigation
  /// Key format: "type:identifier" (e.g., "profile:gotnull", "node:abc123")
  String? _lastProcessedTarget;
  DateTime? _lastProcessedTime;
  static const _deduplicationWindow = Duration(seconds: 5);

  /// Initialize the deep link manager.
  ///
  /// This sets up listening for deep links but does NOT process them
  /// until [markAppReady] is called.
  Future<void> initialize() async {
    AppLogging.qr('DeepLinkManager: Initializing...');
    AppLogging.qr('DeepLinkManager: _appReady=$_appReady');

    try {
      // Handle initial link (app opened via deep link from cold start)
      try {
        AppLogging.qr('DeepLinkManager: Checking for initial link...');
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          AppLogging.qr(
            'DeepLinkManager: FOUND initial link (cold start): $initialUri',
          );
          _processUri(initialUri.toString());
        } else {
          AppLogging.qr(
            'DeepLinkManager: No initial link (app opened normally)',
          );
        }
      } catch (e) {
        AppLogging.qr('QR - DeepLinkManager: Error getting initial link: $e');
      }

      // Listen for incoming links while app is running
      await _linkSubscription?.cancel();
      AppLogging.qr('DeepLinkManager: Setting up uriLinkStream listener...');
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          AppLogging.qr('DeepLinkManager: ⚡ Stream link received: $uri');
          AppLogging.qr(
            'DeepLinkManager: ⚡ _appReady=$_appReady at stream receive time',
          );
          _processUri(uri.toString());
        },
        onError: (error) {
          AppLogging.qr('DeepLinkManager: Stream error: $error');
        },
      );

      AppLogging.qr(
        'DeepLinkManager: Initialized successfully, listening for links',
      );
    } catch (e) {
      AppLogging.qr('DeepLinkManager: Init failed: $e');
    }
  }

  /// Process a URI string through the centralized pipeline.
  ///
  /// This is the single entry point for all deep links.
  void _processUri(String uriString) {
    AppLogging.qr('DeepLinkManager: ========== PROCESSING URI ==========');
    AppLogging.qr('DeepLinkManager: URI: $uriString');
    AppLogging.qr('DeepLinkManager: _appReady=$_appReady');
    AppLogging.qr('DeepLinkManager: _isNavigatorReady=${_isNavigatorReady()}');

    // Step 1: Parse the URI
    final parsed = deepLinkParser.parse(uriString);

    AppLogging.qr(
      'DeepLinkManager: Parsed result - type=${parsed.type}, '
      'valid=${parsed.isValid}, errors=${parsed.validationErrors}',
    );
    AppLogging.qr(
      'DeepLinkManager: Parsed details - automationFirestoreId=${parsed.automationFirestoreId}, '
      'automationBase64Data=${parsed.automationBase64Data != null ? "<present>" : "null"}',
    );

    // Step 2: Check for duplicate (same target within deduplication window)
    final targetKey = _getTargetKey(parsed);
    if (targetKey != null && _isDuplicate(targetKey)) {
      AppLogging.qr(
        'DeepLinkManager: Skipping duplicate link (same target: $targetKey)',
      );
      return;
    }

    // Record this link for deduplication
    if (targetKey != null) {
      _lastProcessedTarget = targetKey;
      _lastProcessedTime = DateTime.now();
    }

    // Step 3: Queue or process based on app readiness
    if (_appReady && _isNavigatorReady()) {
      AppLogging.qr(
        'DeepLinkManager: ✅ App ready AND navigator ready, processing immediately',
      );
      // App is ready, process immediately (in next frame)
      _scheduleNavigation(parsed);
    } else {
      // App not ready, queue for later
      AppLogging.qr(
        'DeepLinkManager: ⏳ App NOT ready - _appReady=$_appReady, navigatorReady=${_isNavigatorReady()}',
      );
      AppLogging.qr(
        'DeepLinkManager: ⏳ QUEUING link for later: ${parsed.type}',
      );
      _pendingLink = parsed;
    }
  }

  /// Generate a unique key for the link target (type + identifier)
  /// This allows deduplication across different URL formats pointing to same target
  String? _getTargetKey(ParsedDeepLink link) {
    switch (link.type) {
      case DeepLinkType.profile:
        final name = link.profileDisplayName?.toLowerCase();
        return name != null ? 'profile:$name' : null;
      case DeepLinkType.node:
        final id = link.nodeFirestoreId ?? link.nodeNum?.toString();
        return id != null ? 'node:$id' : null;
      case DeepLinkType.widget:
        return link.widgetId != null ? 'widget:${link.widgetId}' : null;
      case DeepLinkType.post:
        return link.postId != null ? 'post:${link.postId}' : null;
      case DeepLinkType.channel:
        // Channels are unique by their base64 data
        final data = link.channelBase64Data;
        return data != null ? 'channel:${data.hashCode}' : null;
      case DeepLinkType.channelInvite:
        return link.channelInviteId != null
            ? 'channel-invite:${link.channelInviteId}'
            : null;
      case DeepLinkType.location:
        final lat = link.locationLatitude;
        final lng = link.locationLongitude;
        return lat != null && lng != null ? 'location:$lat,$lng' : null;
      case DeepLinkType.automation:
        final id =
            link.automationFirestoreId ??
            link.automationBase64Data?.hashCode.toString();
        return id != null ? 'automation:$id' : null;
      case DeepLinkType.legal:
        final doc = link.legalDocument;
        return doc != null ? 'legal:$doc' : null;
      case DeepLinkType.invalid:
        return null;
    }
  }

  /// Check if this target was recently processed (within deduplication window)
  bool _isDuplicate(String targetKey) {
    if (_lastProcessedTarget != targetKey) return false;
    if (_lastProcessedTime == null) return false;

    final elapsed = DateTime.now().difference(_lastProcessedTime!);
    return elapsed < _deduplicationWindow;
  }

  /// Check if the navigator is ready for navigation.
  bool _isNavigatorReady() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.debug('DeepLinkManager: Navigator state is null');
      return false;
    }
    return true;
  }

  /// Mark the app as ready for deep link navigation.
  ///
  /// Call this once the app shell, auth, and providers are fully initialized.
  /// This will process any pending deep link.
  void markAppReady() {
    AppLogging.qr('DeepLinkManager: markAppReady() called');
    AppLogging.qr('DeepLinkManager: current _appReady=$_appReady');
    AppLogging.qr('DeepLinkManager: _pendingLink=${_pendingLink?.type}');

    if (_appReady) {
      AppLogging.qr('DeepLinkManager: Already marked ready, ignoring');
      return;
    }

    AppLogging.qr('DeepLinkManager: ✅ App marked as READY');
    _appReady = true;

    // Process pending link if we have one
    if (_pendingLink != null) {
      AppLogging.qr(
        'DeepLinkManager: 🚀 Processing PENDING link: ${_pendingLink!.type}',
      );
      AppLogging.qr(
        'DeepLinkManager: 🚀 Pending link details - automationFirestoreId=${_pendingLink!.automationFirestoreId}',
      );
      _scheduleNavigation(_pendingLink!);
      _pendingLink = null;
    } else {
      AppLogging.qr('DeepLinkManager: No pending link to process');
    }
  }

  /// Mark the app as not ready (e.g., during logout or reset).
  void markAppNotReady() {
    AppLogging.debug('DeepLinkManager: App marked as not ready');
    _appReady = false;
  }

  /// Schedule navigation for the next frame.
  ///
  /// Uses addPostFrameCallback to ensure the widget tree is stable.
  void _scheduleNavigation(ParsedDeepLink link) {
    AppLogging.qr(
      'DeepLinkManager: _scheduleNavigation called for ${link.type}',
    );
    AppLogging.qr('DeepLinkManager: Scheduling navigation in next frame...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogging.qr(
        'DeepLinkManager: 🎯 PostFrameCallback fired, calling _performNavigation',
      );
      _performNavigation(link);
    });
  }

  /// Perform the actual navigation, with safety checks.
  Future<void> _performNavigation(ParsedDeepLink link) async {
    AppLogging.qr('DeepLinkManager: ========== _performNavigation ==========');
    AppLogging.qr(
      'DeepLinkManager: type=${link.type}, uri=${link.originalUri}',
    );

    // Silently ignore invalid/empty deep links - don't navigate anywhere
    if (link.type == DeepLinkType.invalid || !link.isValid) {
      AppLogging.qr(
        'DeepLinkManager: ❌ Ignoring invalid link: ${link.validationErrors}',
      );
      return;
    }

    // Final safety check before navigation
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.qr(
        'DeepLinkManager: Navigator not ready at navigation time, re-queueing',
      );
      _pendingLink = link;
      return;
    }

    AppLogging.qr('DeepLinkManager: Navigator ready, processing ${link.type}');

    try {
      // Handle node links specially - they may need Firestore fetch
      if (link.type == DeepLinkType.node) {
        AppLogging.qr('DeepLinkManager: Handling as node link');
        await _handleNodeLink(link, navigator);
        return;
      }

      // For all other types, use the router
      AppLogging.qr('DeepLinkManager: 🗺️ Using router for ${link.type}');
      final routeResult = deepLinkRouter.route(link);

      AppLogging.qr(
        'DeepLinkManager: 🗺️ Router result - route=${routeResult.routeName}, '
        'args=${routeResult.arguments}, requiresDevice=${routeResult.requiresDevice}',
      );

      if (routeResult.requiresDevice) {
        // Check if device is connected
        final isConnected = _ref.read(isDeviceConnectedProvider);
        AppLogging.qr(
          'DeepLinkManager: Route requires device, isConnected=$isConnected',
        );
        if (!isConnected) {
          _showSnackBar(
            routeResult.fallbackMessage ?? 'Connect a device first',
            isError: true,
          );
          return;
        }
      }

      // Navigate to the determined route
      AppLogging.qr(
        'DeepLinkManager: 🚀 NAVIGATING to ${routeResult.routeName}',
      );
      AppLogging.qr('DeepLinkManager: 🚀 with args=${routeResult.arguments}');
      _safeNavigate(routeResult.routeName, arguments: routeResult.arguments);
      AppLogging.qr('DeepLinkManager: ✅ _safeNavigate returned');
    } catch (e, st) {
      // Never crash on deep link handling - log and continue
      AppLogging.qr('DeepLinkManager: Navigation error: $e\n$st');
    }
  }

  /// Handle node deep links specially (may need Firestore fetch).
  Future<void> _handleNodeLink(
    ParsedDeepLink link,
    NavigatorState navigator,
  ) async {
    int? nodeNum = link.nodeNum;
    String? longName = link.nodeLongName;
    String? shortName = link.nodeShortName;
    String? userId = link.nodeUserId;
    double? latitude = link.nodeLatitude;
    double? longitude = link.nodeLongitude;

    // If we need to fetch from Firestore, do it now
    if (link.needsFirestoreFetch && link.nodeFirestoreId != null) {
      AppLogging.debug(
        'DeepLinkManager: Fetching node from Firestore: ${link.nodeFirestoreId}',
      );

      final deepLinkService = _ref.read(deepLinkServiceProvider);
      final fetched = await deepLinkService.fetchSharedNodeData(
        link.nodeFirestoreId!,
      );

      if (fetched == null || !fetched.hasValidNodeData) {
        _showSnackBar('Unable to load shared node', isError: true);
        return;
      }

      // Use fetched data
      nodeNum = fetched.nodeNum;
      longName = fetched.longName;
      shortName = fetched.shortName;
      userId = fetched.userId;
      latitude = fetched.latitude;
      longitude = fetched.longitude;
    }

    if (nodeNum == null) {
      _showSnackBar('Invalid node data in link', isError: true);
      return;
    }

    // Create a MeshNode from the deep link data, sanitizing names
    final node = MeshNode(
      nodeNum: nodeNum,
      longName: longName != null ? sanitizeUtf16(longName) : null,
      shortName: shortName != null ? sanitizeUtf16(shortName) : null,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      lastHeard: DateTime.now(),
    );

    // Add to nodes provider
    _ref.read(nodesProvider.notifier).addOrUpdateNode(node);

    AppLogging.debug(
      'DeepLinkManager: Added node: ${node.displayName} (${node.nodeNum})',
    );

    // Pop to root first if needed
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    // Show success notification
    _showSnackBar('Node "${longName ?? 'Unknown'}" added');
  }

  /// Safely navigate using the global navigator key.
  void _safeNavigate(String routeName, {Object? arguments}) {
    AppLogging.qr(
      'DeepLinkManager: _safeNavigate to $routeName with args=$arguments',
    );

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.qr(
        'DeepLinkManager: Cannot navigate to $routeName - navigator is null',
      );
      return;
    }

    try {
      AppLogging.qr('DeepLinkManager: Calling pushNamed($routeName)');
      navigator.pushNamed(routeName, arguments: arguments);
      AppLogging.qr('DeepLinkManager: pushNamed succeeded');
    } catch (e) {
      AppLogging.qr('DeepLinkManager: pushNamed failed: $e');
    }
  }

  /// Show a snackbar using the global navigator context.
  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      showGlobalErrorSnackBar(message);
    } else {
      showGlobalInfoSnackBar(message);
    }
  }

  /// Dispose of resources.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _pendingLink = null;
    _appReady = false;
  }
}

/// Provider for the deep link manager.
final deepLinkManagerProvider = Provider<DeepLinkManager>((ref) {
  final manager = DeepLinkManager(ref);
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Notifier to track app readiness for deep links.
class DeepLinkReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setReady() {
    if (state) return;
    state = true;
    ref.read(deepLinkManagerProvider).markAppReady();
  }

  void setNotReady() {
    state = false;
    ref.read(deepLinkManagerProvider).markAppNotReady();
  }
}

final deepLinkReadyProvider = NotifierProvider<DeepLinkReadyNotifier, bool>(
  DeepLinkReadyNotifier.new,
);
