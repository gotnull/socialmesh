// SPDX-License-Identifier: GPL-3.0-or-later

/// Global Layer Hub Screen — entry point for the Global Layer feature.
///
/// This screen acts as a router:
/// - If setup is not complete → shows the Setup Wizard
/// - If setup is complete → shows the Status Panel
///
/// It also marks the feature as "viewed" on first visit to dismiss
/// the NEW badge in the drawer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/mqtt_providers.dart';
import 'global_layer_setup_wizard.dart';
import 'global_layer_status_screen.dart';

/// Hub screen that routes to the appropriate Global Layer sub-screen
/// based on the current setup state.
///
/// This is the screen referenced by the drawer menu item. It handles:
/// - Loading state while config is fetched from storage
/// - Routing to wizard vs status panel
/// - Marking the feature as viewed (dismisses NEW badge)
class GlobalLayerHubScreen extends ConsumerStatefulWidget {
  const GlobalLayerHubScreen({super.key});

  @override
  ConsumerState<GlobalLayerHubScreen> createState() =>
      _GlobalLayerHubScreenState();
}

class _GlobalLayerHubScreenState extends ConsumerState<GlobalLayerHubScreen>
    with LifecycleSafeMixin<GlobalLayerHubScreen> {
  bool _hasMarkedViewed = false;

  @override
  void initState() {
    super.initState();
    _markAsViewed();
  }

  /// Marks the Global Layer feature as viewed so the NEW badge
  /// in the drawer is dismissed. Only runs once per screen instance.
  Future<void> _markAsViewed() async {
    if (_hasMarkedViewed) return;
    _hasMarkedViewed = true;

    final storage = ref.read(globalLayerStorageProvider);
    await storage.markFirstViewed();

    // Invalidate the badge provider so the drawer updates
    if (!mounted) return;
    ref.invalidate(globalLayerShowNewBadgeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(globalLayerConfigProvider);

    return configAsync.when(
      data: (config) {
        if (config.setupComplete) {
          return const GlobalLayerStatusScreen();
        }
        return const GlobalLayerSetupWizard();
      },
      loading: () => GlassScaffold.body(
        title: GlobalLayerConstants.featureLabel,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassScaffold.body(
        title: GlobalLayerConstants.featureLabel,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load Global Layer configuration',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(globalLayerConfigProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
