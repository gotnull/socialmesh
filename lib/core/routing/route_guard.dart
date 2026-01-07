import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';

/// Route requirement types
enum RouteRequirement {
  /// No requirements - always accessible
  none,

  /// Requires network (Firebase)
  network,

  /// Requires device to have been paired at least once (cached data)
  devicePaired,

  /// Requires active device connection
  deviceConnected,
}

/// Route metadata with requirements
class RouteMetadata {
  final String path;
  final Set<RouteRequirement> requirements;
  final String? fallbackRoute;
  final String? blockedMessage;

  const RouteMetadata({
    required this.path,
    this.requirements = const {RouteRequirement.none},
    this.fallbackRoute,
    this.blockedMessage,
  });
}

/// Route registry - defines requirements for all routes
class RouteRegistry {
  static const Map<String, RouteMetadata> _routes = {
    // Unrestricted routes
    '/': RouteMetadata(path: '/'),
    '/main': RouteMetadata(path: '/main'),
    '/settings': RouteMetadata(path: '/settings'),
    '/onboarding': RouteMetadata(path: '/onboarding'),
    '/scanner': RouteMetadata(path: '/scanner'),
    '/profile': RouteMetadata(path: '/profile'),
    '/post-detail': RouteMetadata(path: '/post-detail'),

    // Device-required routes
    '/device-config': RouteMetadata(
      path: '/device-config',
      requirements: {RouteRequirement.deviceConnected},
      fallbackRoute: '/main',
      blockedMessage: 'Connect device to access configuration',
    ),
    '/region-setup': RouteMetadata(
      path: '/region-setup',
      requirements: {RouteRequirement.deviceConnected},
      fallbackRoute: '/main',
      blockedMessage: 'Connect device to set region',
    ),
    '/channel-qr-scanner': RouteMetadata(
      path: '/channel-qr-scanner',
      requirements: {RouteRequirement.deviceConnected},
      fallbackRoute: '/main',
      blockedMessage: 'Connect device to import channels',
    ),

    // Cached data routes (can work offline but need to have paired once)
    '/messages': RouteMetadata(
      path: '/messages',
      requirements: {RouteRequirement.devicePaired},
    ),
    '/channels': RouteMetadata(
      path: '/channels',
      requirements: {RouteRequirement.devicePaired},
    ),
    '/nodes': RouteMetadata(
      path: '/nodes',
      requirements: {RouteRequirement.devicePaired},
    ),
    '/map': RouteMetadata(
      path: '/map',
      requirements: {RouteRequirement.devicePaired},
    ),
  };

  static RouteMetadata? getMetadata(String? routeName) {
    if (routeName == null) return null;
    return _routes[routeName];
  }

  static Set<RouteRequirement> getRequirements(String? routeName) {
    return getMetadata(routeName)?.requirements ?? {RouteRequirement.none};
  }

  static bool isDeviceRequired(String? routeName) {
    final reqs = getRequirements(routeName);
    return reqs.contains(RouteRequirement.deviceConnected);
  }
}

/// Route guard that validates requirements before navigation
class RouteGuard {
  final WidgetRef ref;

  RouteGuard(this.ref);

  /// Check if navigation to a route is allowed
  RouteGuardResult canNavigate(String? routeName) {
    final metadata = RouteRegistry.getMetadata(routeName);
    if (metadata == null) {
      // Unknown route, allow by default
      return const RouteGuardResult.allowed();
    }

    final deviceState = ref.read(deviceConnectionProvider);

    for (final requirement in metadata.requirements) {
      switch (requirement) {
        case RouteRequirement.none:
          continue;

        case RouteRequirement.network:
          // For now, assume network is available
          continue;

        case RouteRequirement.devicePaired:
          if (deviceState.state == DevicePairingState.neverPaired) {
            return RouteGuardResult.blocked(
              reason: 'Pair a device first',
              fallbackRoute: metadata.fallbackRoute ?? '/scanner',
            );
          }
          continue;

        case RouteRequirement.deviceConnected:
          if (!deviceState.isConnected) {
            return RouteGuardResult.blocked(
              reason: metadata.blockedMessage ?? 'Device not connected',
              fallbackRoute: metadata.fallbackRoute ?? '/main',
            );
          }
          continue;
      }
    }

    return const RouteGuardResult.allowed();
  }

  /// Validate navigation and execute if allowed
  Future<bool> validateAndNavigate(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool showBlockedMessage = true,
  }) async {
    final result = canNavigate(routeName);

    if (result.isAllowed) {
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
      return true;
    }

    if (showBlockedMessage && result.reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(result.reason!)),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          action: result.fallbackRoute != null
              ? SnackBarAction(
                  label: 'Connect',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pushNamed('/scanner');
                  },
                )
              : null,
        ),
      );
    }

    return false;
  }
}

/// Result of route guard check
class RouteGuardResult {
  final bool isAllowed;
  final String? reason;
  final String? fallbackRoute;

  const RouteGuardResult({
    required this.isAllowed,
    this.reason,
    this.fallbackRoute,
  });

  const RouteGuardResult.allowed()
    : isAllowed = true,
      reason = null,
      fallbackRoute = null;

  const RouteGuardResult.blocked({required this.reason, this.fallbackRoute})
    : isAllowed = false;
}

/// Provider for route guard
final routeGuardProvider = Provider.family<RouteGuard, WidgetRef>((
  ref,
  widgetRef,
) {
  return RouteGuard(widgetRef);
});

/// Extension for easy route guarding
extension RouteGuardExtension on WidgetRef {
  RouteGuard get routeGuard => RouteGuard(this);

  /// Navigate with route guard validation
  Future<bool> guardedNavigate(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return routeGuard.validateAndNavigate(
      context,
      routeName,
      arguments: arguments,
    );
  }
}
