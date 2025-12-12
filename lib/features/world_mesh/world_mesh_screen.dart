import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../models/world_mesh_node.dart';
import '../../providers/world_mesh_map_provider.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';

/// World Mesh Map screen showing all Meshtastic nodes from meshmap.net
class WorldMeshScreen extends ConsumerStatefulWidget {
  const WorldMeshScreen({super.key});

  @override
  ConsumerState<WorldMeshScreen> createState() => _WorldMeshScreenState();
}

class _WorldMeshScreenState extends ConsumerState<WorldMeshScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  WorldMeshNode? _selectedNode;
  double _currentZoom = 3.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  String _searchQuery = '';
  bool _showSearch = false;

  final TextEditingController _searchController = TextEditingController();
  final PopupController _popupController = PopupController();

  // Animation controller for smooth movements
  AnimationController? _animationController;

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _animatedMove(LatLng destLocation, double destZoom) {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final startZoom = _mapController.camera.zoom;
    final startCenter = _mapController.camera.center;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    );

    _animationController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _animationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meshMapState = ref.watch(worldMeshMapProvider);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: const HamburgerMenuButton(),
        title: _showSearch
            ? _buildSearchField(theme)
            : const Text('World Mesh Map'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          // Map style
          PopupMenuButton<MapTileStyle>(
            icon: const Icon(Icons.layers),
            tooltip: 'Map style',
            onSelected: (style) => setState(() => _mapStyle = style),
            itemBuilder: (context) => MapTileStyle.values
                .map(
                  (style) => PopupMenuItem(
                    value: style,
                    child: Row(
                      children: [
                        Icon(
                          _mapStyle == style
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _mapStyle == style ? accentColor : null,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(style.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(worldMeshMapProvider.notifier).forceRefresh();
            },
          ),
        ],
      ),
      body: meshMapState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(theme, error.toString()),
        data: (state) {
          if (state.isLoading && state.nodes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.nodes.isEmpty) {
            return _buildErrorState(theme, state.error!);
          }
          return _buildMap(context, theme, state);
        },
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search nodes...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: theme.hintColor),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Failed to load mesh map', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(worldMeshMapProvider.notifier).forceRefresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    ThemeData theme,
    WorldMeshMapState state,
  ) {
    final nodes = _searchQuery.isEmpty
        ? state.nodesWithPosition
        : ref.watch(worldMeshFilteredNodesProvider(_searchQuery));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(25, 0), // Global center
            initialZoom: 3.0,
            minZoom: 2.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (position, hasGesture) {
              setState(() => _currentZoom = position.zoom);
            },
            onTap: (tapPosition, point) {
              _popupController.hideAllPopups();
              setState(() => _selectedNode = null);
            },
          ),
          children: [
            // Tile layer
            MapConfig.tileLayerForStyle(_mapStyle),

            // Clustered markers
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: _currentZoom < 3 ? 60 : 45,
                size: const Size(48, 48),
                padding: const EdgeInsets.all(50),
                markers: nodes.map((node) => _buildMarker(node)).toList(),
                popupOptions: PopupOptions(
                  popupSnap: PopupSnap.markerTop,
                  popupController: _popupController,
                  popupBuilder: (context, marker) {
                    final node = _findNodeForMarker(marker, nodes);
                    if (node == null) return const SizedBox.shrink();
                    return _buildNodePopup(context, theme, node);
                  },
                ),
                builder: (context, markers) {
                  return _buildClusterMarker(theme, markers.length);
                },
              ),
            ),

            // Attribution
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution('MeshMap.net', onTap: () {}),
                TextSourceAttribution('${nodes.length} nodes', onTap: () {}),
              ],
            ),
          ],
        ),

        // Zoom controls
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildZoomButton(
                icon: Icons.add,
                onPressed: () {
                  final newZoom = math.min(_currentZoom + 1, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
              const SizedBox(height: 8),
              _buildZoomButton(
                icon: Icons.remove,
                onPressed: () {
                  final newZoom = math.max(_currentZoom - 1, 2.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
            ],
          ),
        ),

        // Stats bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildStatsBar(theme, state, nodes.length),
        ),
      ],
    );
  }

  Marker _buildMarker(WorldMeshNode node) {
    final isRecent = node.isRecentlySeen;
    return Marker(
      point: LatLng(node.latitudeDecimal, node.longitudeDecimal),
      width: 32,
      height: 32,
      child: _WorldMeshNodeMarker(
        node: node,
        isRecent: isRecent,
        isSelected: _selectedNode?.nodeNum == node.nodeNum,
        onTap: () {
          setState(() => _selectedNode = node);
        },
      ),
    );
  }

  WorldMeshNode? _findNodeForMarker(Marker marker, List<WorldMeshNode> nodes) {
    return nodes.firstWhere(
      (n) =>
          n.latitudeDecimal == marker.point.latitude &&
          n.longitudeDecimal == marker.point.longitude,
      orElse: () => nodes.first,
    );
  }

  Widget _buildClusterMarker(ThemeData theme, int count) {
    final accentColor = theme.colorScheme.primary;

    // Gradient colors based on cluster size
    final Color baseColor;
    final double size;
    if (count < 10) {
      baseColor = accentColor;
      size = 40;
    } else if (count < 100) {
      baseColor = Colors.orange;
      size = 44;
    } else if (count < 1000) {
      baseColor = Colors.deepOrange;
      size = 48;
    } else {
      baseColor = Colors.red;
      size = 52;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.9),
            baseColor.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _formatCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${count ~/ 1000}k';
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildNodePopup(
    BuildContext context,
    ThemeData theme,
    WorldMeshNode node,
  ) {
    final accentColor = theme.colorScheme.primary;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    node.shortName.length > 2
                        ? node.shortName.substring(0, 2)
                        : node.shortName,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      node.nodeId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _popupController.hideAllPopups(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Info rows
          _buildInfoRow(
            theme,
            Icons.memory,
            'Hardware',
            _formatHardwareModel(node.hwModel),
          ),
          _buildInfoRow(theme, Icons.person, 'Role', _formatRole(node.role)),
          if (node.fwVersion != null)
            _buildInfoRow(
              theme,
              Icons.system_update,
              'Firmware',
              node.fwVersion!,
            ),
          if (node.region != null)
            _buildInfoRow(
              theme,
              Icons.language,
              'Region',
              '${node.region} / ${node.modemPreset ?? 'N/A'}',
            ),
          _buildInfoRow(
            theme,
            Icons.schedule,
            'Last seen',
            node.lastSeenString,
          ),

          // Metrics section
          if (node.batteryLevel != null ||
              node.chUtil != null ||
              node.temperature != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              children: [
                if (node.batteryLevel != null)
                  _buildMetricChip(
                    theme,
                    Icons.battery_std,
                    node.batteryString!,
                    _getBatteryColor(node.batteryLevel!),
                  ),
                if (node.chUtil != null)
                  _buildMetricChip(
                    theme,
                    Icons.show_chart,
                    '${node.chUtil!.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                if (node.temperature != null)
                  _buildMetricChip(
                    theme,
                    Icons.thermostat,
                    '${node.temperature!.toStringAsFixed(1)}°C',
                    Colors.orange,
                  ),
              ],
            ),
          ],

          // Actions
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: node.nodeId));
                  showSuccessSnackBar(context, 'Node ID copied');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy ID'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  _animatedMove(
                    LatLng(node.latitudeDecimal, node.longitudeDecimal),
                    14.0,
                  );
                  _popupController.hideAllPopups();
                },
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('Focus'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    ThemeData theme,
    IconData icon,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return Colors.green; // Plugged in
    if (level > 60) return Colors.green;
    if (level > 30) return Colors.orange;
    return Colors.red;
  }

  String _formatHardwareModel(String model) {
    return model
        .replaceAll('_', ' ')
        .replaceAll('HELTEC', 'Heltec')
        .replaceAll('TBEAM', 'T-Beam')
        .replaceAll('TLORA', 'T-LoRa')
        .replaceAll('RAK', 'RAK');
  }

  String _formatRole(String role) {
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  Widget _buildStatsBar(
    ThemeData theme,
    WorldMeshMapState state,
    int visibleCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildStatItem(theme, Icons.public, '$visibleCount', 'visible'),
            const SizedBox(width: 24),
            _buildStatItem(
              theme,
              Icons.cloud_done,
              '${state.nodeCount}',
              'total',
            ),
            const Spacer(),
            if (state.lastUpdated != null)
              Text(
                'Updated ${_formatLastUpdated(state.lastUpdated!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  String _formatLastUpdated(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Individual node marker widget
class _WorldMeshNodeMarker extends StatelessWidget {
  final WorldMeshNode node;
  final bool isRecent;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorldMeshNodeMarker({
    required this.node,
    required this.isRecent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // Color based on recency
    final markerColor = isRecent
        ? accentColor
        : Colors.grey.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 36 : 28,
        height: isSelected ? 36 : 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: markerColor.withValues(alpha: isSelected ? 0.9 : 0.7),
          border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
          boxShadow: [
            if (isSelected || isRecent)
              BoxShadow(
                color: markerColor.withValues(alpha: 0.5),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            _getNodeIcon(node.role),
            color: Colors.white,
            size: isSelected ? 18 : 14,
          ),
        ),
      ),
    );
  }

  IconData _getNodeIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ROUTER':
      case 'ROUTER_CLIENT':
        return Icons.router;
      case 'REPEATER':
        return Icons.repeat;
      case 'TRACKER':
        return Icons.gps_fixed;
      case 'SENSOR':
        return Icons.sensors;
      case 'TAK':
        return Icons.military_tech;
      case 'TAK_TRACKER':
        return Icons.track_changes;
      case 'LOST_AND_FOUND':
        return Icons.search;
      default:
        return Icons.radio;
    }
  }
}
