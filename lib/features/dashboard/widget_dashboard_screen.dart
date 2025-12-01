import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart' as transport;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import 'models/dashboard_widget_config.dart';
import 'providers/dashboard_providers.dart';
import 'widgets/dashboard_widget.dart';
import 'widgets/network_overview_widget.dart';
import 'widgets/recent_messages_widget.dart';
import 'widgets/nearby_nodes_widget.dart';
import 'widgets/battery_status_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/signal_chart_widget.dart';

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
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final widgetConfigs = ref.watch(dashboardWidgetsProvider);

    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final batteryLevel = myNode?.batteryLevel;

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
        title: Text(
          _editMode ? 'Edit Dashboard' : 'Dashboard',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_editMode) ...[
            // Battery indicator
            if (batteryLevel != null && isConnected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getBatteryIcon(batteryLevel),
                      size: 20,
                      color: _getBatteryColor(batteryLevel),
                    ),
                    if (batteryLevel <= 100) ...[
                      const SizedBox(width: 2),
                      Text(
                        '$batteryLevel%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getBatteryColor(batteryLevel),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => setState(() => _editMode = true),
              tooltip: 'Edit Dashboard',
            ),
            // Device button
            _DeviceButton(
              isConnected: isConnected,
              isReconnecting: isReconnecting,
            ),
            // Settings
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              tooltip: 'Settings',
            ),
          ] else ...[
            // Add widget
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
              onPressed: () => _showAddWidgetSheet(context),
              tooltip: 'Add Widget',
            ),
            // Done button
            TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
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
                fontFamily: 'Inter',
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
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/scanner'),
              icon: const Icon(Icons.bluetooth_searching, size: 20),
              label: const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
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
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 24),
          Text(
            autoReconnectState == AutoReconnectState.scanning
                ? 'Scanning for device...'
                : 'Connecting...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while we reconnect',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<DashboardWidgetConfig> widgetConfigs,
  ) {
    final enabledWidgets = widgetConfigs.where((w) => w.isVisible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (enabledWidgets.isEmpty && !_editMode) {
      return _buildEmptyDashboard(context);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      buildDefaultDragHandles: false,
      itemCount: enabledWidgets.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(dashboardWidgetsProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final config = enabledWidgets[index];
        return Padding(
          key: ValueKey(config.id),
          padding: const EdgeInsets.only(bottom: 16),
          child: _editMode
              ? ReorderableDragStartListener(
                  index: index,
                  child: _buildWidgetCard(config),
                )
              : _buildWidgetCard(config),
        );
      },
    );
  }

  Widget _buildWidgetCard(DashboardWidgetConfig config) {
    final content = _getWidgetContent(config.type);

    return DashboardWidget(
      config: config,
      isEditMode: _editMode,
      onFavorite: () {
        ref.read(dashboardWidgetsProvider.notifier).toggleFavorite(config.id);
      },
      onRemove: () {
        ref.read(dashboardWidgetsProvider.notifier).removeWidget(config.id);
      },
      child: content,
    );
  }

  Widget _getWidgetContent(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.networkOverview:
        return const NetworkOverviewContent();
      case DashboardWidgetType.recentMessages:
        return const RecentMessagesContent();
      case DashboardWidgetType.nearbyNodes:
        return const NearbyNodesContent();
      case DashboardWidgetType.batteryStatus:
        return const BatteryStatusContent();
      case DashboardWidgetType.quickCompose:
        return const QuickActionsContent();
      case DashboardWidgetType.signalStrength:
        return const SignalChartContent();
      default:
        final info = WidgetRegistry.getInfo(type);
        return Center(
          child: Text(
            '${info.name} coming soon',
            style: const TextStyle(color: AppTheme.textTertiary),
          ),
        );
    }
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
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize your dashboard with widgets that matter to you',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddWidgetSheet(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Widgets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
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

  void _showAddWidgetSheet(BuildContext context) {
    final currentConfigs = ref.read(dashboardWidgetsProvider);
    final enabledTypes = currentConfigs
        .where((c) => c.isVisible)
        .map((c) => c.type)
        .toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AddWidgetSheet(
          scrollController: scrollController,
          enabledTypes: enabledTypes,
          onAdd: (type) {
            ref.read(dashboardWidgetsProvider.notifier).addWidget(type);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level >= 95) return Icons.battery_full;
    if (level >= 80) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AppTheme.primaryGreen;
    if (level >= 50) return AppTheme.primaryGreen;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
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
                ? AppTheme.primaryGreen
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
                    ? AppTheme.primaryGreen
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
      onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
      tooltip: 'Device',
    );
  }
}

/// Bottom sheet to add new widgets
class _AddWidgetSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Set<DashboardWidgetType> enabledTypes;
  final void Function(DashboardWidgetType) onAdd;

  const _AddWidgetSheet({
    required this.scrollController,
    required this.enabledTypes,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Add Widget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Widget list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: DashboardWidgetType.values.length,
            itemBuilder: (context, index) {
              final type = DashboardWidgetType.values[index];
              final isAdded = enabledTypes.contains(type);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WidgetOption(
                  type: type,
                  isAdded: isAdded,
                  onTap: isAdded ? null : () => onAdd(type),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WidgetOption extends StatelessWidget {
  final DashboardWidgetType type;
  final bool isAdded;
  final VoidCallback? onTap;

  const _WidgetOption({
    required this.type,
    required this.isAdded,
    required this.onTap,
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
                  ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                  : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Added',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                      fontFamily: 'Inter',
                    ),
                  ),
                )
              else
                Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
