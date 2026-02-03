// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/logging.dart';
import 'deep_link_types.dart';

/// Routes parsed deep links to the appropriate screens.
///
/// This is a pure function layer that determines the route name and
/// arguments without performing actual navigation. This makes it
/// easy to test routing logic in isolation.
///
/// The router handles:
/// - Mapping deep link types to route names
/// - Extracting and formatting route arguments
/// - Determining auth/device requirements
/// - Providing fallback routes for invalid links
class DeepLinkRouter {
  const DeepLinkRouter();

  /// Determine the route for a parsed deep link.
  ///
  /// Returns a [DeepLinkRouteResult] containing the route name,
  /// arguments, and any requirements/fallback info.
  DeepLinkRouteResult route(ParsedDeepLink link) {
    AppLogging.debug('🔗 Router: Routing ${link.type} link');

    // Invalid links go to fallback with error message
    if (!link.isValid) {
      AppLogging.debug('🔗 Router: Invalid link - ${link.validationErrors}');
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: link.validationErrors.isNotEmpty
            ? 'Invalid link: ${link.validationErrors.first}'
            : 'Unable to open this link',
      );
    }

    switch (link.type) {
      case DeepLinkType.node:
        return _routeNode(link);
      case DeepLinkType.channel:
        return _routeChannel(link);
      case DeepLinkType.profile:
        return _routeProfile(link);
      case DeepLinkType.widget:
        return _routeWidget(link);
      case DeepLinkType.post:
        return _routePost(link);
      case DeepLinkType.location:
        return _routeLocation(link);
      case DeepLinkType.automation:
        return _routeAutomation(link);
      case DeepLinkType.invalid:
        return DeepLinkRouteResult.fallback;
    }
  }

  /// Route a node deep link.
  DeepLinkRouteResult _routeNode(ParsedDeepLink link) {
    // Node links that need Firestore fetch are handled specially
    // by the manager - they route to nodes screen after processing
    if (link.needsFirestoreFetch || link.hasCompleteNodeData) {
      return DeepLinkRouteResult(
        routeName: '/nodes',
        arguments: {'highlightNodeNum': link.nodeNum, 'scrollToNode': true},
        fallbackMessage: 'Node added successfully',
      );
    }

    // Shouldn't reach here, but fallback safely
    return const DeepLinkRouteResult(
      routeName: '/nodes',
      fallbackMessage: 'Unable to load node data',
    );
  }

  /// Route a channel deep link.
  DeepLinkRouteResult _routeChannel(ParsedDeepLink link) {
    if (link.channelBase64Data == null) {
      return const DeepLinkRouteResult(
        routeName: '/channels',
        fallbackMessage: 'Invalid channel data',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/qr-scanner',
      arguments: {'base64Data': link.channelBase64Data},
      requiresDevice: true,
      fallbackMessage: 'Connect a device to import this channel',
    );
  }

  /// Route a profile deep link.
  DeepLinkRouteResult _routeProfile(ParsedDeepLink link) {
    if (link.profileDisplayName == null) {
      return const DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: 'Invalid profile link',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/profile',
      arguments: {'displayName': link.profileDisplayName},
    );
  }

  /// Route a widget deep link.
  DeepLinkRouteResult _routeWidget(ParsedDeepLink link) {
    if (link.widgetId == null) {
      return const DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: 'Invalid widget link',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/widget-detail',
      arguments: {'widgetId': link.widgetId},
    );
  }

  /// Route a post deep link.
  DeepLinkRouteResult _routePost(ParsedDeepLink link) {
    if (link.postId == null) {
      return const DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: 'Invalid post link',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/post-detail',
      arguments: {'postId': link.postId},
    );
  }

  /// Route a location deep link.
  DeepLinkRouteResult _routeLocation(ParsedDeepLink link) {
    if (link.locationLatitude == null || link.locationLongitude == null) {
      return const DeepLinkRouteResult(
        routeName: '/map',
        fallbackMessage: 'Invalid location coordinates',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/map',
      arguments: {
        'latitude': link.locationLatitude,
        'longitude': link.locationLongitude,
        'label': link.locationLabel,
      },
    );
  }

  /// Route an automation deep link.
  DeepLinkRouteResult _routeAutomation(ParsedDeepLink link) {
    if (link.automationBase64Data == null &&
        link.automationFirestoreId == null) {
      return const DeepLinkRouteResult(
        routeName: '/automations',
        fallbackMessage: 'Invalid automation link',
      );
    }

    return DeepLinkRouteResult(
      routeName: '/automation-import',
      arguments: {
        'base64Data': link.automationBase64Data,
        'firestoreId': link.automationFirestoreId,
      },
      requiresDevice: false,
    );
  }
}

/// Singleton router instance.
const deepLinkRouter = DeepLinkRouter();
