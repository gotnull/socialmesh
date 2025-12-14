import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/map_controls.dart';
import '../../models/world_mesh_node.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/world_mesh_map_provider.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';
import 'favorites_screen.dart';
import 'services/node_favorites_service.dart';
import 'widgets/node_intelligence_panel.dart';
import 'world_mesh_filter_sheet.dart';

/// World Mesh Map screen showing all Meshtastic nodes from mesh-observer
class WorldMeshScreen extends ConsumerStatefulWidget {
  const WorldMeshScreen({super.key});

  @override
  ConsumerState<WorldMeshScreen> createState() => _WorldMeshScreenState();
}

class _WorldMeshScreenState extends ConsumerState<WorldMeshScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final NodeFavoritesService _favoritesService = NodeFavoritesService();
  double _currentZoom = 3.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showSearchResults = false;
  WorldMeshNode? _selectedNode;
  bool _isLoadingNodeInfo = false;
  int _favoritesCount = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Animation controller for smooth movements
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _loadFavoritesCount();
  }

  Future<void> _loadFavoritesCount() async {
    final favorites = await _favoritesService.getFavorites();
    if (mounted) {
      setState(() => _favoritesCount = favorites.length);
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _openFavorites(BuildContext context) {
    final asyncState = ref.read(worldMeshMapProvider);
    final nodes = asyncState.value?.nodes;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FavoritesScreen(
          allNodes: nodes,
          onShowOnMap: (node) {
            setState(() {
              _selectedNode = node;
            });
            _animatedMove(
              LatLng(node.latitudeDecimal, node.longitudeDecimal),
              14.0,
            );
          },
        ),
      ),
    ).then((_) => _loadFavoritesCount());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meshMapState = ref.watch(worldMeshMapProvider);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: const HamburgerMenuButton(),
        title: const Text('World Mesh Map'),
        actions: [
          // Search toggle (only show when search is NOT active)
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = true;
                  _showSearchResults = false;
                });
                // Auto-focus when opening search
                Future.delayed(const Duration(milliseconds: 100), () {
                  _searchFocusNode.requestFocus();
                });
              },
            ),
          // Filter button with badge
          _buildFilterButton(accentColor),
          // Favorites
          IconButton(
            icon: _favoritesCount > 0
                ? Badge.count(
                    count: _favoritesCount,
                    child: const Icon(Icons.star),
                  )
                : const Icon(Icons.star_border),
            tooltip: 'Favorites',
            onPressed: () => _openFavorites(context),
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
        loading: () => Center(
          child: MeshLoadingIndicator(
            size: 48,
            colors: [
              context.accentColor,
              context.accentColor.withValues(alpha: 0.6),
              context.accentColor.withValues(alpha: 0.3),
            ],
          ),
        ),
        error: (error, _) => _buildErrorState(theme, error.toString()),
        data: (state) {
          if (state.isLoading && state.nodes.isEmpty) {
            return Center(
              child: MeshLoadingIndicator(
                size: 48,
                colors: [
                  context.accentColor,
                  context.accentColor.withValues(alpha: 0.6),
                  context.accentColor.withValues(alpha: 0.3),
                ],
              ),
            );
          }
          if (state.error != null && state.nodes.isEmpty) {
            return _buildErrorState(theme, state.error!);
          }
          return Column(
            children: [
              // Search bar (same design as Direct Messages)
              if (_showSearch) _buildSearchBar(),
              // Divider when searching
              if (_showSearch)
                Container(
                  height: 1,
                  color: AppTheme.darkBorder.withValues(alpha: 0.3),
                ),
              // Map content (wrapping in Expanded with Stack for dropdown)
              Expanded(
                child: Stack(
                  children: [
                    _buildMap(context, theme, state),
                    // Search results dropdown overlay
                    if (_showSearch && _showSearchResults)
                      _buildSearchResultsOverlay(
                        theme,
                        ref.watch(worldMeshFilteredNodesProvider(_searchQuery)),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build search bar widget matching direct messages design
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Find a node',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
            // Close button as suffix
            suffixIcon: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textTertiary),
              onPressed: () {
                setState(() {
                  _showSearch = false;
                  _showSearchResults = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _showSearchResults = value.isNotEmpty;
            });
          },
        ),
      ),
    );
  }

  /// Build filter button with active filter count badge
  Widget _buildFilterButton(Color accentColor) {
    final filters = ref.watch(worldMeshFiltersProvider);
    final activeCount = filters.activeFilterCount;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: activeCount > 0 ? accentColor : null,
          ),
          tooltip: 'Filter nodes',
          onPressed: () async {
            HapticFeedback.selectionClick();
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const WorldMeshFilterSheet(),
            );
          },
        ),
        if (activeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Build search results overlay dropdown with lazy loading
  Widget _buildSearchResultsOverlay(
    ThemeData theme,
    List<WorldMeshNode> results,
  ) {
    if (results.isEmpty) return const SizedBox.shrink();

    final accentColor = theme.colorScheme.primary;

    return Positioned(
      left: 8,
      right: 8,
      top: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header with count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.search, size: 14, color: AppTheme.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    '${results.length} node${results.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),
            // Lazy loading results list
            Flexible(
              child: _LazySearchResultsList(
                results: results,
                accentColor: accentColor,
                onTap: (node) {
                  HapticFeedback.selectionClick();
                  // Navigate to node and show info card
                  setState(() {
                    _showSearchResults = false;
                    _showSearch = false;
                    _searchQuery = '';
                    _searchController.clear();
                    // Show the node info card for the selected node
                    _selectedNode = node;
                    _isLoadingNodeInfo = false;
                  });
                  // Animate to the node at high zoom to ensure it's visible
                  _animatedMove(
                    LatLng(node.latitudeDecimal, node.longitudeDecimal),
                    16.0,
                  );
                },
              ),
            ),
            // Status legend
            const Divider(height: 1, color: AppTheme.darkBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusLegendItem(
                    color: AppTheme.successGreen,
                    label: 'Online (<1h)',
                  ),
                  const SizedBox(width: 16),
                  _StatusLegendItem(color: Colors.amber, label: 'Idle (1-24h)'),
                  const SizedBox(width: 16),
                  _StatusLegendItem(
                    color: AppTheme.textTertiary,
                    label: 'Offline (>24h)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    // Get filtered nodes for display - apply user filters to base nodes
    final filters = ref.watch(worldMeshFiltersProvider);
    final allNodes = state.nodesWithPosition;
    final displayNodes = filters.hasActiveFilters
        ? filters.apply(allNodes)
        : allNodes;
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
                // Close search results first
                if (_showSearchResults) {
                  setState(() => _showSearchResults = false);
                  return;
                }
                // Deselect node when tapping empty map areas
                // (Marker taps are handled by GestureDetector on each marker)
                if (_selectedNode != null) {
                  setState(() {
                    _selectedNode = null;
                    _isLoadingNodeInfo = false;
                  });
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
              // Marker clustering for better visualization of dense areas
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  // Disable animations for performance with 10k+ nodes
                  animationsOptions: const AnimationsOptions(
                    zoom: Duration.zero,
                    fitBound: Duration(milliseconds: 300),
                    centerMarker: Duration.zero,
                    spiderfy: Duration(milliseconds: 200),
                  ),
                  markers: displayNodes.map((node) {
                    final isSelected = _selectedNode?.nodeNum == node.nodeNum;
                    // Use larger tap target (44px) but smaller visual marker
                    const tapTargetSize = 44.0;
                    final visualSize = isSelected ? 24.0 : 14.0;
                    return Marker(
                      point: LatLng(
                        node.latitudeDecimal,
                        node.longitudeDecimal,
                      ),
                      width: tapTargetSize,
                      height: tapTargetSize,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isLoadingNodeInfo = true;
                            _selectedNode = node;
                          });
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) {
                              setState(() => _isLoadingNodeInfo = false);
                            }
                          });
                        },
                        child: Center(
                          child: Container(
                            width: visualSize,
                            height: visualSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? accentColor
                                  : node.isRecentlySeen
                                  ? accentColor.withValues(alpha: 0.8)
                                  : Colors.grey.withValues(alpha: 0.5),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) {
                    // Cluster marker builder
                    final count = markers.length;
                    final size = count > 100
                        ? 48.0
                        : count > 50
                        ? 44.0
                        : 40.0;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.9),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          count > 999
                              ? '${(count / 1000).toStringAsFixed(1)}k'
                              : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Attribution
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('Socialmesh', onTap: () {}),
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
            if (displayNodes.isNotEmpty) {
              final lats = displayNodes.map((n) => n.latitudeDecimal).toList();
              final lons = displayNodes.map((n) => n.longitudeDecimal).toList();
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

        // Node info card when selected (with loading indicator)
        if (_selectedNode != null && !_showSearchResults)
          Positioned(
            left: 16,
            right: 16,
            bottom: 70,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoadingNodeInfo
                  ? _buildLoadingCard(theme)
                  : WorldNodeInfoCard(
                      key: ValueKey(_selectedNode!.nodeNum),
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
          ),

        // Stats bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildStatsBar(
            theme,
            state,
            displayNodes.length,
            filters.hasActiveFilters,
          ),
        ),
      ],
    );
  }

  /// Build a loading placeholder card with shimmer effect
  Widget _buildLoadingCard(ThemeData theme) {
    final accentColor = theme.colorScheme.primary;
    return Container(
      key: const ValueKey('loading'),
      height: 120,
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
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MeshLoadingIndicator(
              size: 20,
              colors: [
                accentColor,
                accentColor.withValues(alpha: 0.6),
                accentColor.withValues(alpha: 0.3),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              'Loading node info...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(
    ThemeData theme,
    WorldMeshMapState state,
    int visibleCount,
    bool hasFilters,
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
            _buildStatItem(
              theme,
              hasFilters ? Icons.filter_alt : Icons.public,
              '$visibleCount',
              hasFilters ? 'filtered' : 'visible',
              highlight: hasFilters,
            ),
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
    String label, {
    bool highlight = false,
  }) {
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: highlight
                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

/// Lazy loading search results list - loads more as user scrolls
class _LazySearchResultsList extends StatefulWidget {
  final List<WorldMeshNode> results;
  final Color accentColor;
  final void Function(WorldMeshNode node) onTap;

  const _LazySearchResultsList({
    required this.results,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_LazySearchResultsList> createState() => _LazySearchResultsListState();
}

class _LazySearchResultsListState extends State<_LazySearchResultsList> {
  static const int _pageSize = 20;
  int _displayCount = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls near the bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_displayCount < widget.results.length) {
      setState(() {
        _displayCount = (_displayCount + _pageSize).clamp(
          0,
          widget.results.length,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayResults = widget.results.take(_displayCount).toList();
    final hasMore = _displayCount < widget.results.length;

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: displayResults.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end if there's more to load
        if (index >= displayResults.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Scroll for more...',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
            ),
          );
        }

        final node = displayResults[index];
        return _SearchResultTile(
          node: node,
          accentColor: widget.accentColor,
          onTap: () => widget.onTap(node),
        );
      },
    );
  }
}

/// Status legend item widget
class _StatusLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}

/// Search result tile for world mesh nodes
class _SearchResultTile extends StatelessWidget {
  final WorldMeshNode node;
  final Color accentColor;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.node,
    required this.accentColor,
    required this.onTap,
  });

  Color get _statusColor {
    switch (node.status) {
      case NodeStatus.online:
        return AppTheme.successGreen;
      case NodeStatus.idle:
        return Colors.amber;
      case NodeStatus.offline:
        return AppTheme.textTertiary;
    }
  }

  bool get _showStatusBadge => node.status != NodeStatus.offline;

  @override
  Widget build(BuildContext context) {
    final isActive = node.status != NodeStatus.offline;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with status indicator badge
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.2)
                        : AppTheme.darkBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      node.shortName.length > 2
                          ? node.shortName.substring(0, 2).toUpperCase()
                          : node.shortName.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? accentColor : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
                ),
                // Status badge (top-right corner)
                if (_showStatusBadge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.darkCard, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSubtitle(),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    parts.add(node.nodeId);
    if (node.region != null) parts.add(node.region!);
    if (node.hwModel != 'UNKNOWN') parts.add(_formatHardware(node.hwModel));
    return parts.join(' • ');
  }

  String _formatHardware(String model) {
    return model
        .replaceAll('_', ' ')
        .replaceAll('HELTEC', 'Heltec')
        .replaceAll('TBEAM', 'T-Beam')
        .replaceAll('TLORA', 'T-LoRa')
        .replaceAll('RAK', 'RAK');
  }
}

/// Rich info card for WorldMeshNode - shows all available data from mesh-observer
class WorldNodeInfoCard extends StatelessWidget {
  final WorldMeshNode node;
  final VoidCallback? onClose;
  final VoidCallback? onFocus;
  final bool isLoading;

  const WorldNodeInfoCard({
    super.key,
    required this.node,
    this.onClose,
    this.onFocus,
    this.isLoading = false,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // STATIC HEADER - doesn't scroll
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
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
          ),

          const Divider(height: 1),

          // SCROLLABLE CONTENT - middle section
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mesh Intelligence Section - Derived from mesh-observer data
                  NodeIntelligencePanel(node: node, onShowOnMap: onFocus),
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
                    _buildSectionHeader(
                      theme,
                      Icons.analytics,
                      'Device Metrics',
                    ),
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
                          value:
                              '${node.relativeHumidity!.toStringAsFixed(0)}%',
                          color: Colors.cyan,
                        ),
                      if (node.barometricPressure != null)
                        _MetricChip(
                          icon: Icons.speed,
                          value:
                              '${node.barometricPressure!.toStringAsFixed(0)}hPa',
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
                              value:
                                  '${node.windSpeed!.toStringAsFixed(1)} m/s',
                              color: Colors.blueGrey,
                            ),
                          if (node.windGust != null)
                            _MetricChip(
                              icon: Icons.storm,
                              value:
                                  '${node.windGust!.toStringAsFixed(1)} gust',
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
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Last Seen
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last seen: ${node.lastSeenString}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // STATIC FOOTER - action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
          ),
        ],
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
