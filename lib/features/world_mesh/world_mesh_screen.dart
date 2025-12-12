import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/map_controls.dart';
import '../../providers/world_mesh_map_provider.dart';
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
                  return CircleMarker(
                    point: LatLng(node.latitudeDecimal, node.longitudeDecimal),
                    radius: 4,
                    color: node.isRecentlySeen
                        ? accentColor.withValues(alpha: 0.7)
                        : Colors.grey.withValues(alpha: 0.4),
                    borderColor: Colors.white.withValues(alpha: 0.5),
                    borderStrokeWidth: 0.5,
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
