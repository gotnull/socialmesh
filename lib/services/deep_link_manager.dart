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

  /// Initialize the deep link manager.
  ///
  /// This sets up listening for deep links but does NOT process them
  /// until [markAppReady] is called.
  Future<void> initialize() async {
    AppLogging.debug('🔗 DeepLinkManager: Initializing...');

    try {
      // Handle initial link (app opened via deep link from cold start)
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          AppLogging.debug('🔗 DeepLinkManager: Initial link: $initialUri');
          _processUri(initialUri.toString());
        }
      } catch (e) {
        AppLogging.debug('🔗 DeepLinkManager: Error getting initial link: $e');
      }

      // Listen for incoming links while app is running
      await _linkSubscription?.cancel();
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          AppLogging.debug('🔗 DeepLinkManager: Stream link: $uri');
          _processUri(uri.toString());
        },
        onError: (error) {
          AppLogging.debug('🔗 DeepLinkManager: Stream error: $error');
        },
      );

      AppLogging.debug('🔗 DeepLinkManager: Initialized successfully');
    } catch (e) {
      AppLogging.debug('🔗 DeepLinkManager: Init failed: $e');
    }
  }

  /// Process a URI string through the centralized pipeline.
  ///
  /// This is the single entry point for all deep links.
  void _processUri(String uriString) {
    // Step 1: Parse the URI
    final parsed = deepLinkParser.parse(uriString);

    AppLogging.debug(
      '🔗 DeepLinkManager: Parsed ${parsed.type}, valid=${parsed.isValid}',
    );

    // Step 2: Queue or process based on app readiness
    if (_appReady && _isNavigatorReady()) {
      // App is ready, process immediately (in next frame)
      _scheduleNavigation(parsed);
    } else {
      // App not ready, queue for later
      _pendingLink = parsed;
      AppLogging.debug('🔗 DeepLinkManager: Queued link for later processing');
    }
  }

  /// Check if the navigator is ready for navigation.
  bool _isNavigatorReady() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.debug('🔗 DeepLinkManager: Navigator state is null');
      return false;
    }
    return true;
  }

  /// Mark the app as ready for deep link navigation.
  ///
  /// Call this once the app shell, auth, and providers are fully initialized.
  /// This will process any pending deep link.
  void markAppReady() {
    if (_appReady) return;

    AppLogging.debug('🔗 DeepLinkManager: App marked as ready');
    _appReady = true;

    // Process pending link if we have one
    if (_pendingLink != null) {
      _scheduleNavigation(_pendingLink!);
      _pendingLink = null;
    }
  }

  /// Mark the app as not ready (e.g., during logout or reset).
  void markAppNotReady() {
    AppLogging.debug('🔗 DeepLinkManager: App marked as not ready');
    _appReady = false;
  }

  /// Schedule navigation for the next frame.
  ///
  /// Uses addPostFrameCallback to ensure the widget tree is stable.
  void _scheduleNavigation(ParsedDeepLink link) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performNavigation(link);
    });
  }

  /// Perform the actual navigation, with safety checks.
  Future<void> _performNavigation(ParsedDeepLink link) async {
    // Final safety check before navigation
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.debug(
        '🔗 DeepLinkManager: Navigator not ready at navigation time, re-queueing',
      );
      _pendingLink = link;
      return;
    }

    AppLogging.debug('🔗 DeepLinkManager: Processing ${link.type}');

    try {
      // Handle node links specially - they may need Firestore fetch
      if (link.type == DeepLinkType.node) {
        await _handleNodeLink(link, navigator);
        return;
      }

      // For all other types, use the router
      final routeResult = deepLinkRouter.route(link);

      if (routeResult.requiresDevice) {
        // Check if device is connected
        final isConnected = _ref.read(isDeviceConnectedProvider);
        if (!isConnected) {
          _showSnackBar(
            routeResult.fallbackMessage ?? 'Connect a device first',
            isError: true,
          );
          return;
        }
      }

      // Navigate to the determined route
      _safeNavigate(routeResult.routeName, arguments: routeResult.arguments);
    } catch (e, st) {
      // Never crash on deep link handling - log and continue
      AppLogging.debug('🔗 DeepLinkManager: Navigation error: $e\n$st');
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
        '🔗 DeepLinkManager: Fetching node from Firestore: ${link.nodeFirestoreId}',
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
      '🔗 DeepLinkManager: Added node: ${node.displayName} (${node.nodeNum})',
    );

    // Pop to root first if needed
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    // Show success notification
    _showSnackBar(
      'Node "${longName ?? 'Unknown'}" added',
      action: SnackBarAction(
        label: 'View',
        onPressed: () => _safeNavigate('/nodes'),
      ),
    );
  }

  /// Safely navigate using the global navigator key.
  void _safeNavigate(String routeName, {Object? arguments}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      AppLogging.debug(
        '🔗 DeepLinkManager: Cannot navigate to $routeName - navigator null',
      );
      return;
    }

    try {
      navigator.pushNamed(routeName, arguments: arguments);
    } catch (e) {
      AppLogging.debug('🔗 DeepLinkManager: pushNamed failed: $e');
    }
  }

  /// Show a snackbar using the global navigator context.
  void _showSnackBar(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      AppLogging.debug('🔗 DeepLinkManager: Cannot show snackbar - no context');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
          action: action,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogging.debug('🔗 DeepLinkManager: showSnackBar failed: $e');
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
