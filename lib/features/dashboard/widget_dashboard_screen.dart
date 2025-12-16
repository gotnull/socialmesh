import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../device/device_sheet.dart';
import '../navigation/main_shell.dart';
import '../widget_builder/storage/widget_storage_service.dart';
import '../widget_builder/wizard/widget_wizard_screen.dart';
import 'models/dashboard_widget_config.dart';
import 'providers/dashboard_providers.dart';
import 'widgets/dashboard_widget.dart';
import 'widgets/network_overview_widget.dart';
import 'widgets/recent_messages_widget.dart';
import 'widgets/nearby_nodes_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/signal_strength_widget.dart';
import 'widgets/channel_activity_widget.dart';
import 'widgets/mesh_health_widget.dart';
import 'widgets/node_map_widget.dart';
import 'widgets/schema_widget_content.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../settings/subscription_screen.dart';

/// Widgets available for free - showcase the feature
const _freeWidgetTypes = {
  DashboardWidgetType.signalStrength,
  DashboardWidgetType.networkOverview,
  DashboardWidgetType.custom, // Custom widgets are free
};

/// Customizable widget dashboard with drag/reorder/favorites
class WidgetDashboardScreen extends ConsumerStatefulWidget {
  const WidgetDashboardScreen({super.key});

  @override
  ConsumerState<WidgetDashboardScreen> createState() =>
      _WidgetDashboardScreenState();
}

class _WidgetDashboardScreenState extends ConsumerState<WidgetDashboardScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final widgetConfigs = ref.watch(dashboardWidgetsProvider);

    final connectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => transport.DeviceConnectionState.connecting,
      error: (_, s) => transport.DeviceConnectionState.error,
    );

    final isConnected =
        connectionState == transport.DeviceConnectionState.connected;
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          _editMode ? 'Edit Dashboard' : 'Dashboard',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Add widget button - always visible
          IconButton(
            icon: Icon(Icons.add, color: context.accentColor),
            onPressed: () => _showAddWidgetSheet(context),
            tooltip: 'Add Widget',
          ),
          if (!_editMode) ...[
            // Device button
            _DeviceButton(
              isConnected: isConnected,
              isReconnecting: isReconnecting,
            ),
            // Settings
            IconButton(
              icon: Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              tooltip: 'Settings',
            ),
          ] else ...[
            // Done button
            TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: Text(
                'Done',
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ],
      ),
      body: !isConnected && !isReconnecting
          ? _buildDisconnectedState(context, autoReconnectState)
          : isReconnecting
          ? _buildReconnectingState(context, autoReconnectState)
          : _buildDashboard(context, widgetConfigs),
    );
  }

  Widget _buildDisconnectedState(
    BuildContext context,
    AutoReconnectState autoReconnectState,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              autoReconnectState == AutoReconnectState.failed
                  ? Icons.wifi_off
                  : Icons.bluetooth_disabled,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              autoReconnectState == AutoReconnectState.failed
                  ? 'Connection Failed'
                  : 'No Device Connected',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              autoReconnectState == AutoReconnectState.failed
                  ? 'Could not find saved device'
                  : 'Connect to a Meshtastic device to get started',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/scanner'),
              icon: Icon(Icons.bluetooth_searching, size: 20),
              label: Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectingState(
    BuildContext context,
    AutoReconnectState autoReconnectState,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MeshLoadingIndicator(size: 48),
          const SizedBox(height: 24),
          Text(
            autoReconnectState == AutoReconnectState.scanning
                ? 'Scanning for device...'
                : 'Connecting...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we reconnect',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<DashboardWidgetConfig> widgetConfigs,
  ) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final hasWidgetPack = purchaseState.hasFeature(PremiumFeature.homeWidgets);

    final enabledWidgets = widgetConfigs.where((w) => w.isVisible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (enabledWidgets.isEmpty && !_editMode) {
      return _buildEmptyDashboard(context);
    }

    // Calculate how many more widgets are available
    final totalWidgetTypes = DashboardWidgetType.values.length;
    final freeWidgetCount = _freeWidgetTypes.length;
    final premiumWidgetCount = totalWidgetTypes - freeWidgetCount;

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              !hasWidgetPack && !_editMode ? 8 : 16,
            ),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = lerpDouble(0, 8, animation.value) ?? 0;
                  return Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemCount: enabledWidgets.length,
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final config = enabledWidgets[index];
              return Padding(
                key: ValueKey(config.id),
                padding: const EdgeInsets.only(bottom: 16),
                child: _editMode
                    ? _buildWidgetCard(config, reorderIndex: index)
                    : GestureDetector(
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _showWidgetContextMenu(context, config);
                        },
                        child: _buildWidgetCard(config),
                      ),
              );
            },
          ),
        ),
        // Upsell card for non-premium users
        if (!hasWidgetPack && !_editMode)
          _buildWidgetUpsellCard(premiumWidgetCount),
      ],
    );
  }

  Widget _buildWidgetUpsellCard(int premiumWidgetCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: context.accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.accentColor.withValues(alpha: 0.3),
                        context.accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.widgets_rounded,
                    color: context.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock $premiumWidgetCount More Widgets',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Battery, messages, map, and more',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: context.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetCard(DashboardWidgetConfig config, {int? reorderIndex}) {
    // Custom widgets render with minimal wrapper - just the content with edit mode support
    if (config.type == DashboardWidgetType.custom && config.schemaId != null) {
      return _buildCustomWidgetCard(config, reorderIndex: reorderIndex);
    }

    final content = _getWidgetContent(config);
    final trailing = config.type == DashboardWidgetType.signalStrength
        ? buildLiveIndicator()
        : null;

    return DashboardWidget(
      config: config,
      isEditMode: _editMode,
      reorderIndex: reorderIndex,
      trailing: trailing,
      onFavorite: () {
        ref.read(dashboardWidgetsProvider.notifier).toggleFavorite(config.id);
      },
      onRemove: () {
        ref.read(dashboardWidgetsProvider.notifier).removeWidget(config.id);
      },
      child: content,
    );
  }

  /// Build a custom widget with edit mode support using the same DashboardWidget wrapper
  Widget _buildCustomWidgetCard(
    DashboardWidgetConfig config, {
    int? reorderIndex,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final schemaAsync = ref.watch(customWidgetProvider(config.schemaId!));

        return schemaAsync.when(
          data: (schema) {
            if (schema == null) {
              // Schema not found - auto-remove orphaned widget from dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              });
              // Return empty container while removal is processed
              return const SizedBox.shrink();
            }

            // Use DashboardWidget wrapper with the schema's name and icon
            return DashboardWidget(
              config: config,
              isEditMode: _editMode,
              reorderIndex: reorderIndex,
              customName: schema.name,
              customIcon: _getIconForTemplate(schema.tags),
              showHeader: true, // Always show header like native widgets
              onFavorite: () {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .toggleFavorite(config.id);
              },
              onRemove: () {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              },
              child: SchemaWidgetContent(schemaId: config.schemaId!),
            );
          },
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: MeshLoadingIndicator(size: 20)),
          ),
          error: (e, _) => DashboardWidget(
            config: config,
            isEditMode: _editMode,
            reorderIndex: reorderIndex,
            customName: 'Error Loading Widget',
            customIcon: Icons.error_outline,
            onRemove: () {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .removeWidget(config.id);
            },
            child: const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Failed to load widget',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getWidgetContent(DashboardWidgetConfig config) {
    // Handle custom schema-based widgets
    if (config.type == DashboardWidgetType.custom && config.schemaId != null) {
      return SchemaWidgetContent(schemaId: config.schemaId!);
    }

    switch (config.type) {
      case DashboardWidgetType.networkOverview:
        return const NetworkOverviewContent();
      case DashboardWidgetType.recentMessages:
        return const RecentMessagesContent();
      case DashboardWidgetType.nearbyNodes:
        return const NearbyNodesContent();
      case DashboardWidgetType.quickCompose:
        return const QuickActionsContent();
      case DashboardWidgetType.channelActivity:
        return const ChannelActivityContent();
      case DashboardWidgetType.meshHealth:
        return const MeshHealthContent();
      case DashboardWidgetType.signalStrength:
        return const SignalStrengthContent();
      case DashboardWidgetType.nodeMap:
        return const NodeMapContent();
      case DashboardWidgetType.custom:
        // If no schemaId, show error
        return const Center(
          child: Text(
            'Widget not found',
            style: TextStyle(color: Colors.white54),
          ),
        );
    }
  }

  /// Get the appropriate icon for a custom widget based on its template tags
  IconData _getIconForTemplate(List<String> tags) {
    if (tags.contains('actions')) return Icons.touch_app;
    if (tags.contains('gauge')) return Icons.speed;
    if (tags.contains('info')) return Icons.info_outline;
    if (tags.contains('location')) return Icons.location_on;
    if (tags.contains('environment')) return Icons.thermostat;
    if (tags.contains('status')) return Icons.dashboard;
    return Icons.widgets; // Default fallback
  }

  Widget _buildEmptyDashboard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize,
              size: 64,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Widgets Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize your dashboard with widgets that matter to you',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddWidgetSheet(context),
              icon: Icon(Icons.add, size: 20),
              label: Text('Add Widgets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomWidget(String? schemaId) async {
    if (schemaId == null) return;

    final storageService = WidgetStorageService();
    await storageService.init();
    final schema = await storageService.getWidget(schemaId);

    if (schema == null || !mounted) return;

    await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: schema,
          onSave: (updated) async {
            await storageService.saveWidget(updated);
          },
        ),
      ),
    );

    // Refresh dashboard to pick up any changes
    if (mounted) {
      setState(() {});
    }
  }

  void _showAddWidgetSheet(BuildContext context) {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (scrollController) => _AddWidgetSheet(
        scrollController: scrollController,
        widgetsNotifier: ref.read(dashboardWidgetsProvider.notifier),
        widgetsProvider: dashboardWidgetsProvider,
      ),
    );
  }

  void _showWidgetContextMenu(
    BuildContext context,
    DashboardWidgetConfig config,
  ) {
    final isCustomWidget =
        config.type == DashboardWidgetType.custom && config.schemaId != null;
    final widgetInfo = WidgetRegistry.getInfo(config.type);

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCustomWidget ? Icons.widgets : widgetInfo.icon,
                    color: context.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCustomWidget ? 'Custom Widget' : widgetInfo.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          // Edit option (only for custom widgets)
          if (isCustomWidget)
            ListTile(
              leading: Icon(Icons.edit, color: context.accentColor),
              title: const Text(
                'Edit Widget',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _editCustomWidget(config.schemaId);
              },
            ),
          // Toggle favorite
          ListTile(
            leading: Icon(
              config.isFavorite ? Icons.star : Icons.star_border,
              color: config.isFavorite ? AppTheme.warningYellow : Colors.white,
            ),
            title: Text(
              config.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .toggleFavorite(config.id);
              Navigator.pop(context);
            },
          ),
          // Edit dashboard mode
          ListTile(
            leading: const Icon(Icons.dashboard_customize, color: Colors.white),
            title: const Text(
              'Edit Dashboard',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() => _editMode = true);
            },
          ),
          // Remove widget
          ListTile(
            leading: const Icon(
              Icons.remove_circle_outline,
              color: AppTheme.errorRed,
            ),
            title: const Text(
              'Remove Widget',
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () async {
              Navigator.pop(context);
              final shouldRemove = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.darkCard,
                  title: const Text(
                    'Remove Widget?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    'Are you sure you want to remove this widget from your dashboard?',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (shouldRemove == true) {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Device button that shows connection status and navigates to device page
class _DeviceButton extends StatelessWidget {
  final bool isConnected;
  final bool isReconnecting;

  const _DeviceButton({
    required this.isConnected,
    required this.isReconnecting,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.router,
            color: isConnected
                ? context.accentColor
                : isReconnecting
                ? AppTheme.warningYellow
                : AppTheme.textTertiary,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isConnected
                    ? context.accentColor
                    : isReconnecting
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.darkBackground, width: 2),
              ),
            ),
          ),
        ],
      ),
      onPressed: () => showDeviceSheet(context),
      tooltip: 'Device',
    );
  }
}

/// Bottom sheet to add/remove widgets - stays open for multiple operations
class _AddWidgetSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final DashboardWidgetsNotifier widgetsNotifier;
  final NotifierProvider<DashboardWidgetsNotifier, List<DashboardWidgetConfig>>
  widgetsProvider;

  const _AddWidgetSheet({
    required this.scrollController,
    required this.widgetsNotifier,
    required this.widgetsProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfigs = ref.watch(widgetsProvider);
    final enabledTypes = currentConfigs
        .where((c) => c.isVisible)
        .map((c) => c.type)
        .toSet();
    final hasWidgetPack = ref.watch(
      hasPurchasedProvider(RevenueCatConfig.widgetPackProductId),
    );

    // Sort widgets: free first, then premium
    // Filter out 'custom' type - those are added from Widget Builder, not here
    final sortedTypes =
        DashboardWidgetType.values
            .where((t) => t != DashboardWidgetType.custom)
            .toList()
          ..sort((a, b) {
            final aFree = _freeWidgetTypes.contains(a);
            final bFree = _freeWidgetTypes.contains(b);
            if (aFree && !bFree) return -1;
            if (!aFree && bFree) return 1;
            return a.index.compareTo(b.index);
          });

    return Column(
      children: [
        // Header with title and done button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Widgets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Tap to add or remove widgets from your dashboard',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        // Widget list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount:
                sortedTypes.length +
                (hasWidgetPack ? 0 : 1), // +1 for upsell card
            itemBuilder: (context, index) {
              // Show upsell card after free widgets
              if (!hasWidgetPack && index == _freeWidgetTypes.length) {
                return _buildUpsellCard(context);
              }

              // Adjust index for items after upsell card
              final typeIndex =
                  !hasWidgetPack && index > _freeWidgetTypes.length
                  ? index - 1
                  : index;
              final type = sortedTypes[typeIndex];
              final isAdded = enabledTypes.contains(type);
              final isFree = _freeWidgetTypes.contains(type);
              final isLocked = !isFree && !hasWidgetPack;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WidgetOption(
                  type: type,
                  isAdded: isAdded,
                  isLocked: isLocked,
                  onTap: () {
                    // Locked widgets do nothing - user should tap Unlock button
                    if (isLocked) return;
                    if (isAdded) {
                      // Find the config and remove it
                      final config = currentConfigs.firstWhere(
                        (c) => c.type == type && c.isVisible,
                      );
                      widgetsNotifier.removeWidget(config.id);
                    } else {
                      widgetsNotifier.addWidget(type);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpsellCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.accentColor.withValues(alpha: 0.15),
            context.accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: context.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock All Widgets',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get Widget Pack for ${DashboardWidgetType.values.length - _freeWidgetTypes.length} more widgets',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Unlock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetOption extends StatelessWidget {
  final DashboardWidgetType type;
  final bool isAdded;
  final bool isLocked;
  final VoidCallback onTap;

  const _WidgetOption({
    required this.type,
    required this.isAdded,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = WidgetRegistry.getInfo(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAdded
                  ? context.accentColor.withValues(alpha: 0.3)
                  : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.darkSurface.withValues(alpha: 0.5)
                      : isAdded
                      ? context.accentColor.withValues(alpha: 0.15)
                      : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLocked ? Icons.lock_outline : info.icon,
                  color: isLocked
                      ? AppTheme.textTertiary
                      : isAdded
                      ? context.accentColor
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            info.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isLocked
                                  ? AppTheme.textTertiary
                                  : isAdded
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: context.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked
                            ? AppTheme.textTertiary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle switch style indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.darkBorder.withValues(alpha: 0.5)
                      : isAdded
                      ? context.accentColor
                      : AppTheme.darkBorder,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock
                      : isAdded
                      ? Icons.check
                      : Icons.add,
                  color: isLocked
                      ? AppTheme.textTertiary
                      : isAdded
                      ? Colors.black
                      : AppTheme.textTertiary,
                  size: isLocked ? 14 : 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
