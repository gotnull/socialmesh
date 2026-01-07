import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';
import 'route_guard.dart';

/// Navigation observer that enforces route requirements.
/// Intercepts navigation to device-required routes when disconnected.
class DeviceRouteObserver extends NavigatorObserver {
  final WidgetRef ref;

  DeviceRouteObserver(this.ref);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _validateRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _validateRoute(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _validateRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null) return;

    // Check if this route requires device connection
    if (RouteRegistry.isDeviceRequired(routeName)) {
      final deviceState = ref.read(deviceConnectionProvider);

      if (!deviceState.isConnected) {
        // Schedule a pop after this navigation completes
        // This prevents the route from being displayed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator?.canPop() ?? false) {
            navigator?.pop();
            _showBlockedSnackbar(routeName);
          }
        });
      }
    }
  }

  void _showBlockedSnackbar(String routeName) {
    final metadata = RouteRegistry.getMetadata(routeName);
    final context = navigator?.context;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                metadata?.blockedMessage ??
                    'Connect device to access this screen',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Connect',
          textColor: Colors.white,
          onPressed: () {
            navigator?.pushNamed('/scanner');
          },
        ),
      ),
    );
  }
}

/// Provider to create the navigation observer
final deviceRouteObserverProvider =
    Provider.family<DeviceRouteObserver, WidgetRef>(
      (ref, widgetRef) => DeviceRouteObserver(widgetRef),
    );

/// Protected route builder that checks requirements before building
class ProtectedRoute extends ConsumerWidget {
  final String routeName;
  final WidgetBuilder builder;
  final WidgetBuilder? fallbackBuilder;

  const ProtectedRoute({
    super.key,
    required this.routeName,
    required this.builder,
    this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guard = RouteGuard(ref);
    final result = guard.canNavigate(routeName);

    if (result.isAllowed) {
      return builder(context);
    }

    if (fallbackBuilder != null) {
      return fallbackBuilder!(context);
    }

    // Default blocked screen
    return _BlockedRouteScreen(
      message: result.reason ?? 'This screen is not available',
      fallbackRoute: result.fallbackRoute,
    );
  }
}

/// Screen shown when a protected route is blocked
class _BlockedRouteScreen extends StatelessWidget {
  final String message;
  final String? fallbackRoute;

  const _BlockedRouteScreen({required this.message, this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Access Restricted')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              if (fallbackRoute != null)
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed(fallbackRoute!);
                  },
                  child: const Text('Go Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
