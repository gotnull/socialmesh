// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';
import '../../utils/snackbar.dart';
import '../l10n/l10n_extension.dart';
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

    final l10n = context.l10n;
    showActionSnackBar(
      context,
      metadata?.blockedMessage ??
          'Connect device to access this screen', // lint-allow: hardcoded-string
      actionLabel: l10n.actionConnect,
      onAction: () {
        navigator?.pushNamed('/scanner');
      },
      type: SnackBarType.warning,
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

    // No fallback supplied → bounce to Scanner. The "Access Restricted"
    // blocking screen used to live here; it was a dead-end UI that
    // confused users (especially after a factory-reset writeChar
    // failure dropped the BLE link mid-action). Removed entirely —
    // every blocked route now routes directly to the Scanner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/scanner');
    });
    return const SizedBox.shrink();
  }
}
