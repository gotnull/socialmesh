// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'deep_link_types.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

AppLocalizations get _l10n => safeL10n();

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
    AppLogging.qr(
      '🔗 Router: Routing ${link.type} link, valid=${link.isValid}, '
      'uri=${link.originalUri}',
    );

    // Invalid links go to fallback with error message
    if (!link.isValid) {
      AppLogging.qr(
        '🔗 Router: Invalid link - errors=${link.validationErrors}',
      );
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: link.validationErrors.isNotEmpty
            ? 'Invalid link: ${link.validationErrors.first}' // lint-allow: hardcoded-string
            : 'Unable to open this link',
      );
    }

    final result = switch (link.type) {
      DeepLinkType.node => _routeNode(link),
      DeepLinkType.channel => _routeChannel(link),
      DeepLinkType.channelInvite => _routeChannelInvite(link),
      DeepLinkType.profile => _routeProfile(link),
      DeepLinkType.widget => _routeWidget(link),
      DeepLinkType.post => _routePost(link),
      DeepLinkType.location => _routeLocation(link),
      DeepLinkType.automation => _routeAutomation(link),
      DeepLinkType.aetherFlight => _routeAetherFlight(link),
      DeepLinkType.legal => _routeLegal(link),
      DeepLinkType.invalid => DeepLinkRouteResult.fallback,
    };

    AppLogging.qr(
      '🔗 Router: Result - route=${result.routeName}, '
      'args=${result.arguments}, requiresDevice=${result.requiresDevice}',
    );
    return result;
  }

  /// Route a node deep link.
  DeepLinkRouteResult _routeNode(ParsedDeepLink link) {
    // Node links that need Firestore fetch are handled specially
    // by the manager - they route to nodes screen after processing
    if (link.needsFirestoreFetch || link.hasCompleteNodeData) {
      return DeepLinkRouteResult(
        routeName: '/nodes',
        arguments: {'highlightNodeNum': link.nodeNum, 'scrollToNode': true},
        fallbackMessage: _l10n.deepLinkNodeAddedSuccess,
      );
    }

    // Shouldn't reach here, but fallback safely
    return DeepLinkRouteResult(
      routeName: '/nodes',
      fallbackMessage: _l10n.deepLinkUnableToLoadNode,
    );
  }

  /// Route a channel deep link.
  /// Handles both Firestore-based (cloud-stored) and base64-encoded (legacy) channel links.
  DeepLinkRouteResult _routeChannel(ParsedDeepLink link) {
    // Cloud-stored channel via Firestore ID (from QR code sharing)
    if (link.hasChannelFirestoreId) {
      return DeepLinkRouteResult(
        routeName: '/channel-import',
        arguments: {'firestoreId': link.channelFirestoreId},
        requiresDevice: true,
        fallbackMessage: _l10n.deepLinkConnectToImportChannel,
      );
    }

    // Direct import via base64-encoded protobuf data (legacy)
    if (link.hasChannelBase64Data) {
      return DeepLinkRouteResult(
        routeName: '/qr-scanner',
        arguments: {'base64Data': link.channelBase64Data},
        requiresDevice: true,
        fallbackMessage: _l10n.deepLinkConnectToImportChannel,
      );
    }

    return DeepLinkRouteResult(
      routeName: '/channels',
      fallbackMessage: _l10n.deepLinkInvalidChannelData,
    );
  }

  /// Route a channel invite deep link.
  DeepLinkRouteResult _routeChannelInvite(ParsedDeepLink link) {
    if (!link.hasChannelInvite) {
      return DeepLinkRouteResult(
        routeName: '/channels',
        fallbackMessage: _l10n.deepLinkInvalidInviteLink,
      );
    }

    return DeepLinkRouteResult(
      routeName: '/channel-invite',
      arguments: {
        'inviteId': link.channelInviteId,
        'inviteSecret': link.channelInviteSecret,
      },
      requiresAuth: true,
      fallbackMessage: _l10n.deepLinkSignInToJoinChannel,
    );
  }

  /// Route a profile deep link.
  DeepLinkRouteResult _routeProfile(ParsedDeepLink link) {
    AppLogging.qr(
      '🔗 Router: _routeProfile - displayName=${link.profileDisplayName}',
    );

    if (link.profileDisplayName == null) {
      AppLogging.qr('🔗 Router: ERROR - Missing profile display name');
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: _l10n.deepLinkInvalidProfileLink,
      );
    }

    AppLogging.qr(
      '🔗 Router: Routing to /profile with displayName=${link.profileDisplayName}',
    );
    return DeepLinkRouteResult(
      routeName: '/profile',
      arguments: {'displayName': link.profileDisplayName},
    );
  }

  /// Route a widget deep link.
  /// Handles marketplace widget IDs, Firestore IDs, and base64-encoded widget schemas.
  DeepLinkRouteResult _routeWidget(ParsedDeepLink link) {
    // Cloud-stored widget via Firestore ID (from QR code sharing)
    if (link.hasWidgetFirestoreId) {
      return DeepLinkRouteResult(
        routeName: '/widget-import',
        arguments: {'firestoreId': link.widgetFirestoreId},
        requiresDevice: false,
      );
    }

    // Direct import via base64-encoded schema (legacy from QR code sharing)
    if (link.hasWidgetBase64Data) {
      return DeepLinkRouteResult(
        routeName: '/widget-import',
        arguments: {'base64Data': link.widgetBase64Data},
        requiresDevice: false,
      );
    }

    // Marketplace widget by ID
    if (link.widgetId == null) {
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: _l10n.deepLinkInvalidWidgetLink,
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
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: _l10n.deepLinkInvalidPostLink,
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
      return DeepLinkRouteResult(
        routeName: '/map',
        fallbackMessage: _l10n.deepLinkInvalidLocationCoordinates,
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
      return DeepLinkRouteResult(
        routeName: '/automations',
        fallbackMessage: _l10n.deepLinkInvalidAutomationLink,
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

  /// Route an Aether flight deep link.
  DeepLinkRouteResult _routeAetherFlight(ParsedDeepLink link) {
    if (!link.hasAetherFlightShareId) {
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: _l10n.deepLinkInvalidAetherFlightLink,
      );
    }

    return DeepLinkRouteResult(
      routeName: '/aether-flight',
      arguments: {'shareId': link.aetherFlightShareId},
      requiresDevice: false,
    );
  }

  /// Route a legal document deep link.
  DeepLinkRouteResult _routeLegal(ParsedDeepLink link) {
    final document = link.legalDocument;
    if (document == null) {
      return DeepLinkRouteResult(
        routeName: '/main',
        fallbackMessage: _l10n.deepLinkInvalidLegalDocumentLink,
      );
    }

    return DeepLinkRouteResult(
      routeName: '/legal/$document',
      arguments: {
        'document': document,
        'sectionAnchor': link.legalSectionAnchor,
      },
      requiresDevice: false,
    );
  }
}

/// Singleton router instance.
const deepLinkRouter = DeepLinkRouter();
