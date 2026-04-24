// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — full-screen map, glass blur would obscure tiles
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/los_analysis.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/map_controls.dart';
import '../../providers/help_providers.dart';
import '../../models/world_mesh_node.dart';
import '../../models/presence_confidence.dart';
import '../../providers/node_favorites_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/world_mesh_map_provider.dart';
import '../../utils/number_format.dart';
import '../../utils/snackbar.dart';
import 'favorites_screen.dart';
import 'widgets/node_intelligence_panel.dart';
import 'world_mesh_filter_sheet.dart';
import '../../core/widgets/loading_indicator.dart';

/// World Mesh Map screen showing all Meshtastic nodes from mesh-observer
class WorldMeshScreen extends ConsumerStatefulWidget {
  const WorldMeshScreen({super.key});

  @override
  ConsumerState<WorldMeshScreen> createState() => _WorldMeshScreenState();
}

class _WorldMeshScreenState extends ConsumerState<WorldMeshScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<WorldMeshScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 3.0;
  double _mapRotation = 0.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showSearchResults = false;
  WorldMeshNode? _selectedNode;
  bool _isLoadingNodeInfo = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Measurement state
  bool _measureMode = false;
  LatLng? _measureStart;
  LatLng? _measureEnd;
  WorldMeshNode? _measureNodeA;
  WorldMeshNode? _measureNodeB;

  // Animation controller for smooth movements
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _animatedMove(LatLng destLocation, double destZoom, {double? rotation}) {
    if (!isFiniteLatLng(destLocation) || !destZoom.isFinite) return;
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final startZoom = _mapController.camera.zoom;
    final startCenter = _mapController.camera.center;
    final startRotation = _mapController.camera.rotation;
    final destRotation = rotation ?? startRotation;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);
    final rotationTween = Tween<double>(
      begin: startRotation,
      end: destRotation,
    );

    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    );

    _animationController!.addListener(() {
      _mapController.safeMoveAndRotate(
        safeLatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
        rotationTween.evaluate(animation),
      );
      final currentRotation = rotationTween.evaluate(animation);
      if (currentRotation != _mapRotation) {
        setState(() => _mapRotation = currentRotation);
      }
    });

    _animationController!.forward();
  }

  Future<void> _loadMapStyle() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    final index = settings.mapTileStyleIndex;
    if (!mounted) return;
    if (index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() => _mapStyle = MapTileStyle.values[index]);
    }
  }

  Future<void> _saveMapStyle(MapTileStyle style) async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    await settings.setMapTileStyleIndex(style.index);
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
            safeSetState(() {
              _selectedNode = node;
            });
            _animatedMove(
              LatLng(node.latitudeDecimal, node.longitudeDecimal),
              14.0,
            );
          },
        ),
      ),
    );
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
  }

  void _handleMeasureTap(LatLng point) {
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = null;
        _measureNodeB = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureNodeB = null;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = null;
        _measureNodeB = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _handleMeasureNodeTap(WorldMeshNode node) {
    final point = LatLng(node.latitudeDecimal, node.longitudeDecimal);
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = node;
        _measureNodeB = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureNodeB = node;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = node;
        _measureNodeB = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meshMapState = ref.watch(worldMeshMapProvider);
    final accentColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'world_mesh_overview',
        stepKeys: const {},
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: context.background,
            title: Text(
              context.l10n.worldMeshTitle,
              style: TextStyle(color: context.textPrimary),
            ),
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
                    safeTimer(const Duration(milliseconds: 100), () {
                      _searchFocusNode.requestFocus();
                    });
                  },
                ),
              // Filter button with badge
              _buildFilterButton(accentColor),
              // Favorites
              IconButton(
                icon: ref.watch(favoritesCountProvider) > 0
                    ? Badge.count(
                        count: ref.watch(favoritesCountProvider),
                        child: const Icon(Icons.star),
                      )
                    : const Icon(Icons.star_border),
                tooltip: context.l10n.worldMeshFavoritesTooltip,
                onPressed: () => _openFavorites(context),
              ),
              // Overflow menu for map style and refresh
              AppBarOverflowMenu<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'dark':
                      setState(() => _mapStyle = MapTileStyle.dark);
                      unawaited(_saveMapStyle(MapTileStyle.dark));
                      break;
                    case 'satellite':
                      setState(() => _mapStyle = MapTileStyle.satellite);
                      unawaited(_saveMapStyle(MapTileStyle.satellite));
                      break;
                    case 'light':
                      setState(() => _mapStyle = MapTileStyle.light);
                      unawaited(_saveMapStyle(MapTileStyle.light));
                      break;
                    case 'terrain':
                      setState(() => _mapStyle = MapTileStyle.terrain);
                      unawaited(_saveMapStyle(MapTileStyle.terrain));
                      break;
                    case 'refresh':
                      HapticFeedback.lightImpact();
                      ref.read(worldMeshMapProvider.notifier).forceRefresh();
                      break;
                    case 'help':
                      ref
                          .read(helpProvider.notifier)
                          .startTour('world_mesh_overview');
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'dark',
                    child: ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(context.l10n.worldMeshMapStyleDark),
                      trailing: _mapStyle == MapTileStyle.dark
                          ? Icon(Icons.check, size: 18, color: accentColor)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'satellite',
                    child: ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(context.l10n.worldMeshMapStyleSatellite),
                      trailing: _mapStyle == MapTileStyle.satellite
                          ? Icon(Icons.check, size: 18, color: accentColor)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'light',
                    child: ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(context.l10n.worldMeshMapStyleLight),
                      trailing: _mapStyle == MapTileStyle.light
                          ? Icon(Icons.check, size: 18, color: accentColor)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'terrain',
                    child: ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(context.l10n.worldMeshMapStyleTerrain),
                      trailing: _mapStyle == MapTileStyle.terrain
                          ? Icon(Icons.check, size: 18, color: accentColor)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: const Icon(Icons.refresh),
                      title: Text(context.l10n.worldMeshRefresh),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(context.l10n.worldMeshHelp),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: meshMapState.when(
            loading: () => Center(child: LoadingIndicator(size: 32)),
            error: (error, _) => _buildErrorState(theme, error.toString()),
            data: (state) {
              if (state.isLoading && state.nodes.isEmpty) {
                return Center(child: LoadingIndicator(size: 32));
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
                      color: context.border.withValues(alpha: 0.3),
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
                            ref.watch(
                              worldMeshFilteredNodesProvider(_searchQuery),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build search bar widget matching direct messages design
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: TextField(
          maxLength: 100,
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: context.l10n.worldMeshSearchHint,
            hintStyle: TextStyle(color: context.textTertiary),
            prefixIcon: Icon(Icons.search, color: context.textTertiary),
            // Close button as suffix
            suffixIcon: IconButton(
              icon: Icon(Icons.close, color: context.textTertiary),
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
            counterText: '',
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
          tooltip: context.l10n.worldMeshFilterTooltip,
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
              padding: const EdgeInsets.all(AppTheme.spacing4),
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
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.search, size: 14, color: context.textTertiary),
                  SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.worldMeshSearchResultCount(results.length),
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.border),
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
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusLegendItem(
                    color: AppTheme.successGreen,
                    label: context.l10n.worldMeshLegendActive,
                  ),
                  SizedBox(width: AppTheme.spacing16),
                  _StatusLegendItem(
                    color: AppTheme.warningYellow,
                    label: context.l10n.worldMeshLegendIdle,
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  _StatusLegendItem(
                    color: context.textTertiary,
                    label: context.l10n.worldMeshLegendOffline,
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
    final accentColor = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: accentColor.withValues(alpha: 0.7),
            ),
            SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.worldMeshErrorTitle,
              style: TextStyle(color: context.textSecondary, fontSize: 16),
            ),
            SizedBox(height: AppTheme.spacing8),
            Text(
              error,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextButton(
              onPressed: () =>
                  ref.read(worldMeshMapProvider.notifier).forceRefresh(),
              child: Text(
                context.l10n.worldMeshRetry,
                style: TextStyle(color: accentColor),
              ),
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
              backgroundColor: context.background,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                pinchZoomThreshold: 0.5,
              ),
              onPositionChanged: (position, hasGesture) {
                _currentZoom = position.zoom;
                if (hasGesture && position.rotation != _mapRotation) {
                  setState(() => _mapRotation = position.rotation);
                }
              },
              onTap: (tapPosition, point) {
                // Close search results first
                if (_showSearchResults) {
                  setState(() => _showSearchResults = false);
                  return;
                }
                if (_measureMode) {
                  _handleMeasureTap(point);
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
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),
              // Marker clustering for better visualization of dense areas
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: EdgeInsets.zero,
                  maxZoom: 15,
                  // Disable animations for performance with 10k+ nodes
                  animationsOptions: const AnimationsOptions(
                    zoom: Duration.zero,
                    fitBound: Duration(milliseconds: 300),
                    centerMarker: Duration.zero,
                    spiderfy: Duration(milliseconds: 200),
                  ),
                  markers: finiteMarkers(
                    displayNodes.map((node) {
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
                            if (_measureMode) {
                              _handleMeasureNodeTap(node);
                              return;
                            }
                            setState(() {
                              _isLoadingNodeInfo = true;
                              _selectedNode = node;
                            });
                            Future.delayed(
                              const Duration(milliseconds: 150),
                              () {
                                if (mounted) {
                                  setState(() => _isLoadingNodeInfo = false);
                                }
                              },
                            );
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _measureMode = true;
                              _measureStart = LatLng(
                                node.latitudeDecimal,
                                node.longitudeDecimal,
                              );
                              _measureEnd = null;
                              _measureNodeA = node;
                              _measureNodeB = null;
                              _selectedNode = null;
                              _isLoadingNodeInfo = false;
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
                                    : SemanticColors.disabled.withValues(
                                        alpha: 0.5,
                                      ),
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
                    }),
                  ),
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
              // Measurement polyline
              if (_measureStart != null && _measureEnd != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_measureStart!, _measureEnd!],
                      strokeWidth: 2.5,
                      color: AppTheme.warningYellow,
                      pattern: const StrokePattern.dotted(spacingFactor: 1.5),
                    ),
                  ],
                ),
              // Measurement markers
              if (_measureStart != null && isFiniteLatLng(_measureStart))
                MarkerLayer(
                  markers: finiteMarkers([
                    Marker(
                      point: _measureStart!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.warningYellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            context.l10n.worldMeshMeasurePointA,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_measureEnd != null)
                      Marker(
                        point: _measureEnd!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              context.l10n.worldMeshMeasurePointB,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
            ],
          ),
        ),

        // Use shared map controls with ValueListenableBuilder for zoom state
        _MapControlsWithZoomState(
          mapController: _mapController,
          initialZoom: _currentZoom,
          mapRotation: _mapRotation,
          minZoom: 2.0,
          maxZoom: 18.0,
          animatedMove: _animatedMove,
          onResetNorth: () => _animatedMove(
            _mapController.camera.center,
            _currentZoom,
            rotation: 0,
          ),
          onFitAll: () {
            final finite = displayNodes
                .where(
                  (n) =>
                      n.latitudeDecimal.isFinite && n.longitudeDecimal.isFinite,
                )
                .toList(growable: false);
            if (finite.isEmpty) return;
            final lats = finite.map((n) => n.latitudeDecimal).toList();
            final lons = finite.map((n) => n.longitudeDecimal).toList();
            final sw = safeLatLng(lats.reduce(math.min), lons.reduce(math.min));
            final ne = safeLatLng(lats.reduce(math.max), lons.reduce(math.max));
            if (sw == null || ne == null) return;
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds(sw, ne),
                padding: const EdgeInsets.all(AppTheme.spacing50),
              ),
            );
          },
        ),

        // Node info card when selected (with loading indicator)
        // Position above the stats bar (which is ~60px) plus safe area
        if (_selectedNode != null && !_showSearchResults && !_measureMode)
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
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

        // Measurement mode indicator pill
        if (_measureMode && (_measureStart == null || _measureEnd == null))
          Positioned(
            top: 16,
            left: 16,
            right: 68,
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 4,
                  bottom: 4,
                  right: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow,
                  borderRadius: BorderRadius.circular(AppTheme.radius20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten, size: 16, color: Colors.black),
                    const SizedBox(width: AppTheme.spacing8),
                    Flexible(
                      child: Text(
                        _measureStart == null
                            ? context.l10n.worldMeshMeasureTapA
                            : context.l10n.worldMeshMeasureTapB,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _measureMode = false;
                        _measureStart = null;
                        _measureEnd = null;
                        _measureNodeA = null;
                        _measureNodeB = null;
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Measurement card
        if (_measureMode && _measureStart != null && _measureEnd != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + 56 + MediaQuery.of(context).padding.bottom,
            child: _WorldMeasurementCard(
              start: _measureStart!,
              end: _measureEnd!,
              nodeA: _measureNodeA,
              nodeB: _measureNodeB,
              onClear: () => setState(() {
                _measureStart = null;
                _measureEnd = null;
                _measureNodeA = null;
                _measureNodeB = null;
              }),
              onExitMeasureMode: () => setState(() {
                _measureMode = false;
                _measureStart = null;
                _measureEnd = null;
                _measureNodeA = null;
                _measureNodeB = null;
              }),
              onSwap: () => setState(() {
                final tmpStart = _measureStart;
                final tmpEnd = _measureEnd;
                final tmpNodeA = _measureNodeA;
                final tmpNodeB = _measureNodeB;
                _measureStart = tmpEnd;
                _measureEnd = tmpStart;
                _measureNodeA = tmpNodeB;
                _measureNodeB = tmpNodeA;
              }),
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
        color: context.card.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
            LoadingIndicator(size: 20),
            SizedBox(width: AppTheme.spacing12),
            Text(
              context.l10n.worldMeshLoadingNodeInfo,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
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
    final attributionUrl = _mapStyle == MapTileStyle.satellite
        ? 'https://www.esri.com'
        : _mapStyle == MapTileStyle.terrain
        ? 'https://opentopomap.org'
        : 'https://carto.com/attributions';
    final attributionLabel = _mapStyle == MapTileStyle.satellite
        ? '© Esri'
        : _mapStyle == MapTileStyle.terrain
        ? '© OpenTopoMap © OSM'
        : '© OSM © CARTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attribution row at the top
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(attributionUrl)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  attributionLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            // Stats row below
            Row(
              children: [
                _buildStatItem(
                  theme,
                  hasFilters ? Icons.filter_alt : Icons.public,
                  visibleCount,
                  hasFilters
                      ? context.l10n.worldMeshStatsFiltered
                      : context.l10n.worldMeshStatsVisible,
                  highlight: hasFilters,
                ),
                const SizedBox(width: AppTheme.spacing16),
                _buildStatItem(
                  theme,
                  Icons.cloud_done,
                  state.nodeCount,
                  context.l10n.worldMeshStatsTotal,
                ),
                const Spacer(),
                if (state.lastUpdated != null)
                  GestureDetector(
                    onTap: () {
                      ref.read(worldMeshMapProvider.notifier).forceRefresh();
                      showInfoSnackBar(
                        context,
                        context.l10n.worldMeshRefreshing,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isFromCache)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.cloud_off,
                              size: 12,
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        Text(
                          _formatLastUpdated(state.lastUpdated!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: state.isFromCache
                                ? theme.colorScheme.error.withValues(alpha: 0.6)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    int value,
    String label, {
    bool highlight = false,
  }) {
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppTheme.spacing6),
        AnimatedCounter(
          value: value,
          duration: const Duration(milliseconds: 600),
          formatter: (v) => NumberFormatUtils.formatWithThousandsSeparators(v),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(width: AppTheme.spacing4),
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
    if (diff.inSeconds < 60) {
      return context.l10n.worldMeshTimeJustNow;
    }
    if (diff.inMinutes < 60) {
      return context.l10n.worldMeshTimeMinutesAgo(diff.inMinutes);
    }
    return context.l10n.worldMeshTimeHoursAgo(diff.inHours);
  }
}

/// Map controls that listen to zoom state without triggering parent rebuilds
class _MapControlsWithZoomState extends StatefulWidget {
  const _MapControlsWithZoomState({
    required this.mapController,
    required this.initialZoom,
    required this.mapRotation,
    required this.minZoom,
    required this.maxZoom,
    required this.animatedMove,
    required this.onResetNorth,
    required this.onFitAll,
  });

  final MapController mapController;
  final double initialZoom;
  final double mapRotation;
  final double minZoom;
  final double maxZoom;
  final void Function(LatLng destLocation, double destZoom) animatedMove;
  final VoidCallback onResetNorth;
  final VoidCallback onFitAll;

  @override
  State<_MapControlsWithZoomState> createState() =>
      _MapControlsWithZoomStateState();
}

class _MapControlsWithZoomStateState extends State<_MapControlsWithZoomState> {
  late double _currentZoom;
  StreamSubscription<MapEvent>? _mapEventSubscription;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    // Listen to camera changes
    _mapEventSubscription = widget.mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventMoveEnd) {
        final newZoom = widget.mapController.camera.zoom;
        if (mounted && (_currentZoom - newZoom).abs() > 0.05) {
          setState(() => _currentZoom = newZoom);
        }
      }
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    super.dispose();
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
        widget.onResetNorth();
      },
      showFitAll: true,
      showNavigation: false,
      showCompass: true,
      mapRotation: widget.mapRotation,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Center(
              child: Text(
                context.l10n.worldMeshScrollForMore,
                style: context.bodySmallStyle?.copyWith(
                  color: context.textTertiary,
                ),
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
        SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: context.captionStyle?.copyWith(color: context.textTertiary),
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

  Color _statusColor(BuildContext context) {
    switch (node.presenceConfidence) {
      case PresenceConfidence.active:
        return AppTheme.successGreen;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  bool get _showStatusBadge =>
      node.presenceConfidence != PresenceConfidence.unknown;

  @override
  Widget build(BuildContext context) {
    final isActive = node.presenceConfidence.isActive;

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
                        : context.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Center(
                    child: Text(
                      _getAvatarText(),
                      style: TextStyle(
                        color: isActive ? accentColor : context.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: AppTheme.fontFamily,
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
                        color: _statusColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: AppTheme.spacing12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.displayName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    _buildSubtitle(),
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
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

  /// Get avatar text for a node - prefers shortName, falls back to hex ID
  String _getAvatarText() {
    final shortName = node.shortName.trim();
    if (shortName.isNotEmpty &&
        shortName != '????' &&
        !shortName.startsWith('!')) {
      return shortName.length > 2
          ? shortName.substring(0, 2).toUpperCase()
          : shortName.toUpperCase();
    }
    return node.nodeNum
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(0, 2)
        .toUpperCase();
  }
}

/// Rich info card for WorldMeshNode - shows all available data from mesh-observer
class WorldNodeInfoCard extends ConsumerStatefulWidget {
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
  ConsumerState<WorldNodeInfoCard> createState() => _WorldNodeInfoCardState();
}

class _WorldNodeInfoCardState extends ConsumerState<WorldNodeInfoCard> {
  WorldMeshNode get node => widget.node;
  VoidCallback? get onClose => widget.onClose;
  VoidCallback? get onFocus => widget.onFocus;

  void _toggleFavorite() {
    HapticFeedback.mediumImpact();
    final isFavorite = ref.read(isNodeFavoriteProvider(node.nodeNum));
    ref.read(nodeFavoritesProvider.notifier).toggleFavorite(node);

    if (isFavorite) {
      showInfoSnackBar(context, context.l10n.worldMeshRemovedFromFavorites);
    } else {
      showSuccessSnackBar(context, context.l10n.worldMeshAddedToFavorites);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final isFavorite = ref.watch(isNodeFavoriteProvider(node.nodeNum));

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Center(
                    child: Text(
                      _getAvatarText(node),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacing12),
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
                          // Only show nodeId if different from displayName
                          if (node.hasName)
                            Text(
                              node.nodeId,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                              ),
                            ),
                          if (node.hasName) SizedBox(width: AppTheme.spacing8),
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius4,
                                ),
                              ),
                              child: Text(
                                context.l10n.worldMeshBadgeActive,
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
                // Favorite button
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 22,
                    color: isFavorite
                        ? const Color(0xFFFFD700)
                        : context.textSecondary,
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: isFavorite
                      ? context.l10n.worldMeshRemoveFromFavorites
                      : context.l10n.worldMeshAddToFavorites,
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  color: context.textSecondary,
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // SCROLLABLE CONTENT - middle section
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mesh Intelligence Section - Derived from mesh-observer data
                  NodeIntelligencePanel(node: node, onShowOnMap: onFocus),
                  const SizedBox(height: AppTheme.spacing16),

                  // Device Info Section
                  _buildSectionHeader(
                    theme,
                    Icons.memory,
                    context.l10n.worldMeshSectionDevice,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildInfoGrid([
                    _InfoItem(
                      context.l10n.worldMeshInfoHardware,
                      _formatHardware(node.hwModel),
                    ),
                    _InfoItem(
                      context.l10n.worldMeshInfoRole,
                      _formatRole(node.role),
                    ),
                    if (node.fwVersion != null)
                      _InfoItem(
                        context.l10n.worldMeshInfoFirmware,
                        node.fwVersion!,
                      ),
                    if (node.region != null)
                      _InfoItem(context.l10n.worldMeshInfoRegion, node.region!),
                    if (node.modemPreset != null)
                      _InfoItem(
                        context.l10n.worldMeshInfoModem,
                        node.modemPreset!,
                      ),
                    if (node.onlineLocalNodes != null)
                      _InfoItem(
                        context.l10n.worldMeshInfoLocalNodes,
                        '${node.onlineLocalNodes}',
                      ),
                  ]),

                  // Position Section
                  if (node.altitude != null ||
                      node.precisionMarginMeters != null) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    _buildSectionHeader(
                      theme,
                      Icons.location_on,
                      context.l10n.worldMeshSectionPosition,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildInfoGrid([
                      _InfoItem(
                        context.l10n.worldMeshInfoCoordinates,
                        '${node.latitudeDecimal.toStringAsFixed(5)}, ${node.longitudeDecimal.toStringAsFixed(5)}',
                      ),
                      if (node.altitude != null)
                        _InfoItem(
                          context.l10n.worldMeshInfoAltitude,
                          '${node.altitude}m',
                        ),
                      if (node.precisionMarginMeters != null)
                        _InfoItem(
                          context.l10n.worldMeshInfoPrecision,
                          '±${_formatDistance(node.precisionMarginMeters!)}', // lint-allow: hardcoded-string
                        ),
                    ]),
                  ],

                  // Device Metrics Section
                  if (node.batteryLevel != null ||
                      node.voltage != null ||
                      node.chUtil != null ||
                      node.airUtilTx != null ||
                      node.uptime != null) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    _buildSectionHeader(
                      theme,
                      Icons.analytics,
                      context.l10n.worldMeshSectionDeviceMetrics,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
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
                          color: AppTheme.warningYellow,
                        ),
                      if (node.chUtil != null)
                        _MetricChip(
                          icon: Icons.show_chart,
                          value: '${node.chUtil!.toStringAsFixed(1)}% Ch',
                          color: AccentColors.blue,
                        ),
                      if (node.airUtilTx != null)
                        _MetricChip(
                          icon: Icons.cell_tower,
                          value: '${node.airUtilTx!.toStringAsFixed(1)}% Tx',
                          color: AccentColors.purple,
                        ),
                    ]),
                    if (node.uptimeString != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.l10n.worldMeshUptimeLabel(node.uptimeString!),
                          style: TextStyle(
                            color: context.textSecondary,
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
                    const SizedBox(height: AppTheme.spacing16),
                    _buildSectionHeader(
                      theme,
                      Icons.thermostat,
                      context.l10n.worldMeshSectionEnvironment,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildMetricsRow(theme, [
                      if (node.temperature != null)
                        _MetricChip(
                          icon: Icons.thermostat,
                          value: '${node.temperature!.toStringAsFixed(1)}°C',
                          color: AccentColors.orange,
                        ),
                      if (node.relativeHumidity != null)
                        _MetricChip(
                          icon: Icons.water_drop,
                          value:
                              '${node.relativeHumidity!.toStringAsFixed(0)}%',
                          color: AccentColors.cyan,
                        ),
                      if (node.barometricPressure != null)
                        _MetricChip(
                          icon: Icons.speed,
                          value:
                              '${node.barometricPressure!.toStringAsFixed(0)}hPa',
                          color: AccentColors.teal,
                        ),
                      if (node.lux != null)
                        _MetricChip(
                          icon: Icons.light_mode,
                          value: '${node.lux!.toStringAsFixed(0)} lux',
                          color: AppTheme.warningYellow,
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
                              color: AccentColors.slate,
                            ),
                          if (node.windGust != null)
                            _MetricChip(
                              icon: Icons.storm,
                              value:
                                  '${node.windGust!.toStringAsFixed(1)} gust',
                              color: AccentColors.slate,
                            ),
                        ]),
                      ),
                  ],

                  // Neighbors Section
                  if (node.neighbors != null && node.neighbors!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    _buildSectionHeader(
                      theme,
                      Icons.people,
                      context.l10n.worldMeshSectionNeighbors(
                        node.neighbors!.length,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
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
                            color: context.border.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                          ),
                          child: Text(
                            '${entry.key}${snr != null ? ' (${snr.toStringAsFixed(1)}dB)' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Seen By Section
                  if (node.seenBy.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spacing16),
                    _buildSectionHeader(
                      theme,
                      Icons.wifi_tethering,
                      context.l10n.worldMeshSectionSeenBy(node.seenBy.length),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      node.seenBy.keys.take(3).join(', ') +
                          (node.seenBy.length > 3
                              ? context.l10n.worldMeshMoreGateways(
                                  node.seenBy.length - 3,
                                )
                              : ''),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Last Seen
                  SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing6),
                      Text(
                        context.l10n.worldMeshLastSeen(node.lastSeenString),
                        style: TextStyle(
                          color: context.textSecondary,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: node.nodeId));
                      showSuccessSnackBar(
                        context,
                        context.l10n.worldMeshNodeIdCopied,
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(context.l10n.worldMeshCopyId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFocus,
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: Text(context.l10n.worldMeshFocus),
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
        const SizedBox(width: AppTheme.spacing8),
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
                style: TextStyle(color: context.textSecondary, fontSize: 11),
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
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: chip.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chip.icon, size: 14, color: chip.color),
              const SizedBox(width: AppTheme.spacing6),
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
    if (level > 30) return AccentColors.orange;
    return AppTheme.errorRed;
  }

  /// Get avatar text for a node - prefers shortName, falls back to hex ID
  String _getAvatarText(WorldMeshNode node) {
    // Check if shortName is valid (not empty and not default placeholder)
    final shortName = node.shortName.trim();
    if (shortName.isNotEmpty &&
        shortName != '????' &&
        !shortName.startsWith('!')) {
      // Use first 2 characters of shortName
      return shortName.length > 2
          ? shortName.substring(0, 2).toUpperCase()
          : shortName.toUpperCase();
    }
    // Fall back to hex node ID (first 2 hex chars)
    return node.nodeNum
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(0, 2)
        .toUpperCase();
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

/// Measurement card for World Mesh map — shows distance, bearing, altitude,
/// and LOS between two points/nodes. Long-press for actions sheet.
class _WorldMeasurementCard extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final WorldMeshNode? nodeA;
  final WorldMeshNode? nodeB;
  final VoidCallback onClear;
  final VoidCallback onExitMeasureMode;
  final VoidCallback? onSwap;

  const _WorldMeasurementCard({
    required this.start,
    required this.end,
    this.nodeA,
    this.nodeB,
    required this.onClear,
    required this.onExitMeasureMode,
    this.onSwap,
  });

  @override
  State<_WorldMeasurementCard> createState() => _WorldMeasurementCardState();
}

class _WorldMeasurementCardState extends State<_WorldMeasurementCard> {
  bool _showLos = false;

  String _formatDist(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  double _distanceKm() {
    return const Distance().as(LengthUnit.Kilometer, widget.start, widget.end);
  }

  String _pointLabel(LatLng point, WorldMeshNode? node, String prefix) {
    if (node != null) {
      final name = node.displayName;
      final alt = node.altitude != null
          ? ' · ${node.altitude}m'
          : ''; // lint-allow: hardcoded-string
      return '$prefix: $name$alt';
    }
    return '$prefix: ${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)}';
  }

  String _buildSummary({
    required double distanceKm,
    required double bearing,
    required String cardinal,
    int? elevDelta,
  }) {
    final buf = StringBuffer();
    buf.write(
      '${_formatDist(distanceKm)} · '
      '${bearing.toStringAsFixed(0)}° $cardinal',
    );
    if (elevDelta != null) {
      buf.write(' · ${elevDelta >= 0 ? '+' : ''}${elevDelta}m');
    }
    buf.writeln();
    buf.writeln(_pointLabel(widget.start, widget.nodeA, 'A'));
    buf.write(_pointLabel(widget.end, widget.nodeB, 'B'));
    return buf.toString();
  }

  void _showActionsSheet(BuildContext context) {
    final distanceKm = _distanceKm();
    final distanceM = distanceKm * 1000;
    final bearing = calculateBearing(
      widget.start.latitude,
      widget.start.longitude,
      widget.end.latitude,
      widget.end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);
    final altA = widget.nodeA?.altitude;
    final altB = widget.nodeB?.altitude;
    final hasElevation = altA != null && altB != null;
    final elevDelta = hasElevation ? altB - altA : null;

    HapticFeedback.selectionClick();
    AppBottomSheet.showActions<String>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
        child: Text(
          context.l10n.worldMeshMeasurementActions,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      actions: [
        if (hasElevation)
          BottomSheetAction(
            icon: Icons.visibility,
            label: context.l10n.worldMeshLosAnalysis,
            subtitle: context.l10n.worldMeshLosSubtitle,
            onTap: () => setState(() => _showLos = !_showLos),
          ),
        BottomSheetAction(
          icon: Icons.copy,
          label: context.l10n.worldMeshCopySummary,
          subtitle: _formatDist(distanceKm),
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildSummary(
                  distanceKm: distanceKm,
                  bearing: bearing,
                  cardinal: cardinal,
                  elevDelta: elevDelta,
                ),
              ),
            );
            if (context.mounted) {
              showSuccessSnackBar(
                context,
                context.l10n.worldMeshMeasurementCopied,
              );
            }
          },
        ),
        BottomSheetAction(
          icon: Icons.pin_drop,
          label: context.l10n.worldMeshCopyCoordinates,
          subtitle: context.l10n.worldMeshCopyCoordinatesSubtitle,
          onTap: () {
            final a = widget.start;
            final b = widget.end;
            Clipboard.setData(
              ClipboardData(
                text:
                    'A: ${a.latitude.toStringAsFixed(6)}, ' // lint-allow: hardcoded-string
                    '${a.longitude.toStringAsFixed(6)}\n'
                    'B: ${b.latitude.toStringAsFixed(6)}, ' // lint-allow: hardcoded-string
                    '${b.longitude.toStringAsFixed(6)}',
              ),
            );
            if (context.mounted) {
              showSuccessSnackBar(
                context,
                context.l10n.worldMeshCoordinatesCopied,
              );
            }
          },
        ),
        BottomSheetAction(
          icon: Icons.open_in_new,
          label: context.l10n.worldMeshOpenMidpointInMaps,
          subtitle: context.l10n.worldMeshOpenMidpointSubtitle,
          onTap: () {
            final midLat = (widget.start.latitude + widget.end.latitude) / 2.0;
            final midLon =
                (widget.start.longitude + widget.end.longitude) / 2.0;
            launchUrl(
              Uri.parse('https://maps.apple.com/?ll=$midLat,$midLon&z=14'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        if (widget.onSwap != null)
          BottomSheetAction(
            icon: Icons.swap_horiz,
            label: context.l10n.worldMeshSwapAB,
            subtitle: context.l10n.worldMeshSwapSubtitle,
            onTap: widget.onSwap,
          ),
        if (hasElevation)
          BottomSheetAction(
            icon: Icons.terrain,
            label: context.l10n.worldMeshRfLinkBudget,
            subtitle: context.l10n.worldMeshFsplSubtitle(
              _pathLoss(distanceM, 906.0).toStringAsFixed(0),
            ),
            onTap: () {
              final fspl = _pathLoss(distanceM, 906.0);
              Clipboard.setData(
                ClipboardData(
                  text: context.l10n.worldMeshRfLinkBudgetClipboard(
                    _formatDist(distanceKm),
                    '906 MHz', // lint-allow: hardcoded-string
                    '${fspl.toStringAsFixed(1)} dB',
                    'Alt A: ${altA}m · Alt B: ${altB}m\nBearing: ${bearing.toStringAsFixed(0)}° $cardinal', // lint-allow: hardcoded-string
                  ),
                ),
              );
              if (context.mounted) {
                showSuccessSnackBar(
                  context,
                  context.l10n.worldMeshLinkBudgetCopied,
                );
              }
            },
          ),
      ],
    );
  }

  static double _pathLoss(double distanceM, double freqMhz) {
    if (distanceM <= 0) return 0;
    return 20 * math.log(distanceM) / math.ln10 +
        20 * math.log(freqMhz) / math.ln10 -
        27.55;
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _distanceKm();
    final distanceM = distanceKm * 1000;
    final bearing = calculateBearing(
      widget.start.latitude,
      widget.start.longitude,
      widget.end.latitude,
      widget.end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);
    final altA = widget.nodeA?.altitude;
    final altB = widget.nodeB?.altitude;
    final hasElevation = altA != null && altB != null;
    final elevDelta = hasElevation ? altB - altA : null;

    return GestureDetector(
      onLongPress: () => _showActionsSheet(context),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: AppTheme.warningYellow.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warningYellow.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.straighten,
                    size: 18,
                    color: AppTheme.warningYellow,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDist(distanceKm),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningYellow,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            '${bearing.toStringAsFixed(0)}° $cardinal',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                          if (elevDelta != null) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            Icon(
                              elevDelta >= 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 14,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.spacing2),
                            Text(
                              '${elevDelta >= 0 ? '+' : ''}${elevDelta}m',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _pointLabel(widget.start, widget.nodeA, 'A'),
                        style: context.captionStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                      Text(
                        _pointLabel(widget.end, widget.nodeB, 'B'),
                        style: context.captionStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20),
                  color: context.textTertiary,
                  onPressed: widget.onClear,
                  tooltip: context.l10n.worldMeshNewMeasurement,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppTheme.errorRed,
                  onPressed: widget.onExitMeasureMode,
                  tooltip: context.l10n.worldMeshExitMeasureMode,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.worldMeshLongPressHint,
              style: TextStyle(fontSize: 10, color: context.textTertiary),
            ),
            if (_showLos && hasElevation) ...[
              const SizedBox(height: AppTheme.spacing8),
              _WorldLosResultPanel(
                altA: altA,
                altB: altB,
                distanceMeters: distanceM,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// LOS result panel for World Mesh measurement card.
class _WorldLosResultPanel extends StatelessWidget {
  final int altA;
  final int altB;
  final double distanceMeters;

  const _WorldLosResultPanel({
    required this.altA,
    required this.altB,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final result = evaluateLos(
      altA: altA,
      altB: altB,
      distanceMeters: distanceMeters,
    );

    Color verdictColor;
    IconData verdictIcon;
    switch (result.verdict) {
      case LosVerdict.clear:
        verdictColor = AppTheme.successGreen;
        verdictIcon = Icons.check_circle;
      case LosVerdict.marginal:
        verdictColor = AppTheme.warningYellow;
        verdictIcon = Icons.warning;
      case LosVerdict.obstructed:
        verdictColor = AppTheme.errorRed;
        verdictIcon = Icons.cancel;
      case LosVerdict.unknown:
        verdictColor = context.textTertiary;
        verdictIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(verdictIcon, size: 16, color: verdictColor),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                context.l10n.worldMeshLosVerdict(switch (result.verdict) {
                  LosVerdict.clear => context.l10n.losVerdictClear,
                  LosVerdict.marginal => context.l10n.losVerdictMarginal,
                  LosVerdict.obstructed => context.l10n.losVerdictObstructed,
                  LosVerdict.unknown => context.l10n.losVerdictUnknown,
                }),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: verdictColor,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.worldMeshLosBulgeAndFresnel(
                  result.earthBulgeMeters.toStringAsFixed(1),
                  result.fresnelRadiusMeters.toStringAsFixed(1),
                ),
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(switch (result.verdict) {
            LosVerdict.unknown => context.l10n.losExplanationNoAltitude,
            LosVerdict.obstructed => context.l10n.losExplanationObstructed(
              (-result.actualClearanceMeters).toStringAsFixed(0),
            ),
            LosVerdict.clear => context.l10n.losExplanationClear(
              result.actualClearanceMeters.toStringAsFixed(0),
            ),
            LosVerdict.marginal => context.l10n.losExplanationMarginal(
              result.actualClearanceMeters.toStringAsFixed(0),
              result.requiredClearanceMeters.toStringAsFixed(0),
            ),
          }, style: TextStyle(fontSize: 11, color: context.textSecondary)),
        ],
      ),
    );
  }
}
