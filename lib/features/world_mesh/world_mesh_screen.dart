import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/map_controls.dart';
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
  double _currentZoom = 3.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  String _searchQuery = '';
  bool _showSearch = false;
  WorldMeshNode? _selectedNode;

  final TextEditingController _searchController = TextEditingController();

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

    final accentColor = theme.colorScheme.primary;

    return Stack(
      children: [
        // Direct FlutterMap for maximum performance (like main mesh map)
        RepaintBoundary(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25, 0),
              initialZoom: 3.0,
              minZoom: 2.0,
              maxZoom: 18.0,
              backgroundColor: AppTheme.darkBackground,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, hasGesture) {
                _currentZoom = position.zoom;
              },
              onTap: (tapPosition, point) {
                // Find closest node to tap point
                final tappedNode = _findClosestNode(point, nodes);
                if (tappedNode != null) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedNode = tappedNode);
                } else {
                  setState(() => _selectedNode = null);
                }
              },
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: _mapStyle.url,
                subdomains: _mapStyle.subdomains,
                userAgentPackageName: MapConfig.userAgentPackageName,
                retinaMode: _mapStyle != MapTileStyle.satellite,
              ),
              // Use CircleLayer for 10k+ nodes - MUCH faster than Markers
              CircleLayer(
                circles: nodes.map((node) {
                  final isSelected = _selectedNode?.nodeNum == node.nodeNum;
                  return CircleMarker(
                    point: LatLng(node.latitudeDecimal, node.longitudeDecimal),
                    radius: isSelected ? 8 : 4,
                    color: isSelected
                        ? accentColor
                        : node.isRecentlySeen
                        ? accentColor.withValues(alpha: 0.7)
                        : Colors.grey.withValues(alpha: 0.4),
                    borderColor: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderStrokeWidth: isSelected ? 2 : 0.5,
                  );
                }).toList(),
              ),
              // Attribution
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('MeshMap.net', onTap: () {}),
                ],
              ),
            ],
          ),
        ),

        // Use shared map controls with ValueListenableBuilder for zoom state
        _MapControlsWithZoomState(
          mapController: _mapController,
          initialZoom: _currentZoom,
          minZoom: 2.0,
          maxZoom: 18.0,
          animatedMove: _animatedMove,
          onFitAll: () {
            // Fit to show all visible nodes
            if (nodes.isNotEmpty) {
              final lats = nodes.map((n) => n.latitudeDecimal).toList();
              final lons = nodes.map((n) => n.longitudeDecimal).toList();
              final bounds = LatLngBounds(
                LatLng(lats.reduce(math.min), lons.reduce(math.min)),
                LatLng(lats.reduce(math.max), lons.reduce(math.max)),
              );
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50),
                ),
              );
            }
          },
        ),

        // Node info card when selected
        if (_selectedNode != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 70,
            child: WorldNodeInfoCard(
              node: _selectedNode!,
              onClose: () => setState(() => _selectedNode = null),
              onFocus: () {
                _animatedMove(
                  LatLng(
                    _selectedNode!.latitudeDecimal,
                    _selectedNode!.longitudeDecimal,
                  ),
                  14.0,
                );
              },
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

  /// Find the closest node to a tap point within a reasonable distance
  WorldMeshNode? _findClosestNode(LatLng tapPoint, List<WorldMeshNode> nodes) {
    if (nodes.isEmpty) return null;

    // Calculate tap radius based on zoom level (in degrees)
    // At zoom 3, ~45 degrees per screen width; at zoom 18, ~0.001 degrees
    final tapRadius = 5.0 / math.pow(2, _currentZoom);

    WorldMeshNode? closest;
    double closestDist = double.infinity;

    for (final node in nodes) {
      final dx = node.longitudeDecimal - tapPoint.longitude;
      final dy = node.latitudeDecimal - tapPoint.latitude;
      final dist = dx * dx + dy * dy;

      if (dist < closestDist && dist < tapRadius * tapRadius) {
        closestDist = dist;
        closest = node;
      }
    }

    return closest;
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

/// Map controls that listen to zoom state without triggering parent rebuilds
class _MapControlsWithZoomState extends StatefulWidget {
  const _MapControlsWithZoomState({
    required this.mapController,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.animatedMove,
    required this.onFitAll,
  });

  final MapController mapController;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final void Function(LatLng destLocation, double destZoom) animatedMove;
  final VoidCallback onFitAll;

  @override
  State<_MapControlsWithZoomState> createState() =>
      _MapControlsWithZoomStateState();
}

class _MapControlsWithZoomStateState extends State<_MapControlsWithZoomState> {
  late double _currentZoom;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    // Listen to camera changes
    widget.mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventMoveEnd) {
        final newZoom = widget.mapController.camera.zoom;
        if ((_currentZoom - newZoom).abs() > 0.05) {
          setState(() => _currentZoom = newZoom);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MapControlsOverlay(
      currentZoom: _currentZoom,
      minZoom: widget.minZoom,
      maxZoom: widget.maxZoom,
      onZoomIn: () {
        final newZoom = math.min(_currentZoom + 1, widget.maxZoom);
        widget.animatedMove(widget.mapController.camera.center, newZoom);
        HapticFeedback.selectionClick();
      },
      onZoomOut: () {
        final newZoom = math.max(_currentZoom - 1, widget.minZoom);
        widget.animatedMove(widget.mapController.camera.center, newZoom);
        HapticFeedback.selectionClick();
      },
      onFitAll: widget.onFitAll,
      onResetNorth: () {
        HapticFeedback.selectionClick();
      },
      showFitAll: true,
      showNavigation: false,
      showCompass: true,
      mapRotation: 0, // World mesh doesn't rotate
    );
  }
}

/// Rich info card for WorldMeshNode - shows all available data from meshmap.net
class WorldNodeInfoCard extends StatelessWidget {
  final WorldMeshNode node;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;

  const WorldNodeInfoCard({
    super.key,
    required this.node,
    this.onClose,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with name and close button
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      node.shortName.length > 2
                          ? node.shortName.substring(0, 2).toUpperCase()
                          : node.shortName.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'JetBrainsMono',
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            node.nodeId,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (node.isRecentlySeen)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Device Info Section
            _buildSectionHeader(theme, Icons.memory, 'Device'),
            const SizedBox(height: 8),
            _buildInfoGrid([
              _InfoItem('Hardware', _formatHardware(node.hwModel)),
              _InfoItem('Role', _formatRole(node.role)),
              if (node.fwVersion != null)
                _InfoItem('Firmware', node.fwVersion!),
              if (node.region != null) _InfoItem('Region', node.region!),
              if (node.modemPreset != null)
                _InfoItem('Modem', node.modemPreset!),
              if (node.onlineLocalNodes != null)
                _InfoItem('Local Nodes', '${node.onlineLocalNodes}'),
            ]),

            // Position Section
            if (node.altitude != null ||
                node.precisionMarginMeters != null) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(theme, Icons.location_on, 'Position'),
              const SizedBox(height: 8),
              _buildInfoGrid([
                _InfoItem(
                  'Coordinates',
                  '${node.latitudeDecimal.toStringAsFixed(5)}, ${node.longitudeDecimal.toStringAsFixed(5)}',
                ),
                if (node.altitude != null)
                  _InfoItem('Altitude', '${node.altitude}m'),
                if (node.precisionMarginMeters != null)
                  _InfoItem(
                    'Precision',
                    '±${_formatDistance(node.precisionMarginMeters!)}',
                  ),
              ]),
            ],

            // Device Metrics Section
            if (node.batteryLevel != null ||
                node.voltage != null ||
                node.chUtil != null ||
                node.airUtilTx != null ||
                node.uptime != null) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(theme, Icons.analytics, 'Device Metrics'),
              const SizedBox(height: 8),
              _buildMetricsRow(theme, [
                if (node.batteryLevel != null)
                  _MetricChip(
                    icon: Icons.battery_std,
                    value: node.batteryString!,
                    color: _getBatteryColor(node.batteryLevel!),
                  ),
                if (node.voltage != null)
                  _MetricChip(
                    icon: Icons.electric_bolt,
                    value: '${node.voltage!.toStringAsFixed(2)}V',
                    color: Colors.amber,
                  ),
                if (node.chUtil != null)
                  _MetricChip(
                    icon: Icons.show_chart,
                    value: '${node.chUtil!.toStringAsFixed(1)}% Ch',
                    color: Colors.blue,
                  ),
                if (node.airUtilTx != null)
                  _MetricChip(
                    icon: Icons.cell_tower,
                    value: '${node.airUtilTx!.toStringAsFixed(1)}% Tx',
                    color: Colors.purple,
                  ),
              ]),
              if (node.uptimeString != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Uptime: ${node.uptimeString}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],

            // Environment Metrics Section
            if (node.temperature != null ||
                node.relativeHumidity != null ||
                node.barometricPressure != null ||
                node.windSpeed != null ||
                node.lux != null) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(theme, Icons.thermostat, 'Environment'),
              const SizedBox(height: 8),
              _buildMetricsRow(theme, [
                if (node.temperature != null)
                  _MetricChip(
                    icon: Icons.thermostat,
                    value: '${node.temperature!.toStringAsFixed(1)}°C',
                    color: Colors.orange,
                  ),
                if (node.relativeHumidity != null)
                  _MetricChip(
                    icon: Icons.water_drop,
                    value: '${node.relativeHumidity!.toStringAsFixed(0)}%',
                    color: Colors.cyan,
                  ),
                if (node.barometricPressure != null)
                  _MetricChip(
                    icon: Icons.speed,
                    value: '${node.barometricPressure!.toStringAsFixed(0)}hPa',
                    color: Colors.teal,
                  ),
                if (node.lux != null)
                  _MetricChip(
                    icon: Icons.light_mode,
                    value: '${node.lux!.toStringAsFixed(0)} lux',
                    color: Colors.yellow,
                  ),
              ]),
              if (node.windSpeed != null || node.windDirection != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildMetricsRow(theme, [
                    if (node.windSpeed != null)
                      _MetricChip(
                        icon: Icons.air,
                        value: '${node.windSpeed!.toStringAsFixed(1)} m/s',
                        color: Colors.blueGrey,
                      ),
                    if (node.windGust != null)
                      _MetricChip(
                        icon: Icons.storm,
                        value: '${node.windGust!.toStringAsFixed(1)} gust',
                        color: Colors.blueGrey,
                      ),
                  ]),
                ),
            ],

            // Neighbors Section
            if (node.neighbors != null && node.neighbors!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(
                theme,
                Icons.people,
                'Neighbors (${node.neighbors!.length})',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: node.neighbors!.entries.take(8).map((entry) {
                  final snr = entry.value.snr;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBorder.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key}${snr != null ? ' (${snr.toStringAsFixed(1)}dB)' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Seen By Section
            if (node.seenBy.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(
                theme,
                Icons.wifi_tethering,
                'Seen By (${node.seenBy.length} gateways)',
              ),
              const SizedBox(height: 8),
              Text(
                node.seenBy.keys.take(3).join(', ') +
                    (node.seenBy.length > 3
                        ? ' +${node.seenBy.length - 3} more'
                        : ''),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],

            // Last Seen
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Last seen: ${node.lastSeenString}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: node.nodeId));
                      showSuccessSnackBar(context, 'Node ID copied');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy ID'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFocus,
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: const Text('Focus'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                item.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricsRow(ThemeData theme, List<_MetricChip> chips) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chip.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chip.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chip.icon, size: 14, color: chip.color),
              const SizedBox(width: 6),
              Text(
                chip.value,
                style: TextStyle(
                  color: chip.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatHardware(String model) {
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

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AppTheme.successGreen; // Plugged in
    if (level > 60) return AppTheme.successGreen;
    if (level > 30) return Colors.orange;
    return AppTheme.errorRed;
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _MetricChip {
  final IconData icon;
  final String value;
  final Color color;
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.color,
  });
}
