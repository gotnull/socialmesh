// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Map screen — read-only projection of NodeDex entries
// onto the existing shared MeshMapWidget. No new map stack: the
// widget, marker model, camera helpers, and tile-style settings
// are all reused.
//
// Provider graph:
//   nodeDexSortedEntriesProvider + myNodeNumProvider
//     → nodeDexMapAllMarkersProvider     (NodeDex → marker projection)
//       + nodeDexMapFilterProvider
//         → nodeDexMapFilteredMarkersProvider
//           → MeshMapWidget (existing)
//
// The screen never writes to NodeDex state.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import '../../../core/safe_lat_lng.dart';
import '../../../core/safety/safety.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/mesh_map_widget.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/presence_providers.dart';
import '../../../utils/timestamp_validation.dart';
import '../screens/nodedex_detail_screen.dart';
import 'nodedex_map_adapter.dart';
import 'nodedex_map_provider.dart';

class NodeDexMapScreen extends ConsumerStatefulWidget {
  const NodeDexMapScreen({super.key});

  @override
  ConsumerState<NodeDexMapScreen> createState() => _NodeDexMapScreenState();
}

class _NodeDexMapScreenState extends ConsumerState<NodeDexMapScreen>
    with LifecycleSafeMixin<NodeDexMapScreen> {
  final MapController _mapController = MapController();
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    AppLogging.nodeDex('Map screen — init');
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  MapTileStyle _resolveMapStyle() {
    return ref
        .watch(settingsServiceProvider)
        .maybeWhen(
          data: (settings) {
            final index = settings.mapTileStyleIndex;
            if (index >= 0 && index < MapTileStyle.values.length) {
              return MapTileStyle.values[index];
            }
            return MapTileStyle.dark;
          },
          orElse: () => MapTileStyle.dark,
        );
  }

  void _fitToMarkersIfNeeded(List<NodeDexMapMarker> markers) {
    if (_initialFitDone || markers.isEmpty) return;
    final myMarker = markers.firstWhere(
      (m) => m.isSelf,
      orElse: () => markers.first,
    );

    if (myMarker.isSelf) {
      _mapController.safeMove(
        LatLng(myMarker.latitude, myMarker.longitude),
        13.0,
      );
      AppLogging.nodeDex(
        'Map camera — centered on self node ${myMarker.nodeNum}',
      );
    } else {
      final markerData = markers
          .map(
            (m) => MeshNodeMarkerData(
              node: m.liveNode ?? _stubNode(m),
              latitude: m.latitude,
              longitude: m.longitude,
            ),
          )
          .toList(growable: false);
      final center = calculateNodesCenter(markerData);
      final zoom = calculateZoomToFitNodes(markerData);
      _mapController.safeMove(center, zoom);
      AppLogging.nodeDex(
        'Map camera — fit ${markers.length} markers @ zoom=$zoom',
      );
    }
    _initialFitDone = true;
  }

  MeshNode _stubNode(NodeDexMapMarker marker) {
    return MeshNode(
      nodeNum: marker.nodeNum,
      shortName: marker.shortName,
      longName: marker.longName,
      latitude: marker.latitude,
      longitude: marker.longitude,
      lastHeard: marker.lastHeard,
      isFavorite: marker.isFavourite,
    );
  }

  void _onMarkerTap(MeshNode node) {
    final marker = ref
        .read(nodeDexMapFilteredMarkersProvider)
        .where((m) => m.nodeNum == node.nodeNum)
        .firstOrNull;
    if (marker == null) return;
    _showMarkerSheet(marker);
  }

  Future<void> _showMarkerSheet(NodeDexMapMarker marker) async {
    final l10n = context.l10n;
    final hexId =
        '!${marker.nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}';
    final lastHeardText = _formatLastHeard(marker.lastHeard);
    final distanceText = marker.distanceMeters != null
        ? _formatDistance(marker.distanceMeters!)
        : null;
    final displayName = (marker.longName?.isNotEmpty ?? false)
        ? marker.longName!
        : (marker.shortName?.isNotEmpty ?? false)
        ? marker.shortName!
        : hexId;

    AppLogging.nodeDex('Map marker tapped — node ${marker.nodeNum}');

    await AppBottomSheet.showActions<void>(
      context: context,
      header: _MarkerSheetHeader(
        displayName: displayName,
        hexId: hexId,
        lastHeardText: lastHeardText,
        distanceText: distanceText,
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.open_in_new,
          label: l10n.nodedexMapOpenDetails,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NodeDexDetailScreen(nodeNum: marker.nodeNum),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatLastHeard(DateTime lastHeard) {
    final l10n = context.l10n;
    final validated = TimestampValidation.validated(lastHeard);
    if (validated == null) return l10n.commonNever;
    final diff = DateTime.now().difference(validated);
    if (diff.isNegative || diff.inMinutes < 1) return l10n.commonJustNow;
    if (diff.inMinutes < 60) return l10n.commonMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.commonHoursAgo(diff.inHours);
    return l10n.commonDaysAgo(diff.inDays);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allProjection = ref.watch(nodeDexMapAllMarkersProvider);
    final markers = ref.watch(nodeDexMapFilteredMarkersProvider);
    final filter = ref.watch(nodeDexMapFilterProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final mapStyle = _resolveMapStyle();

    if (allProjection.markers.isEmpty) {
      return GlassScaffold.body(
        title: l10n.nodedexMapTitle,
        body: _MapEmptyState(hasNodesWithoutPositions: false),
      );
    }

    final markerData = markers
        .map(
          (m) => MeshNodeMarkerData(
            node: m.liveNode ?? _stubNode(m),
            latitude: m.latitude,
            longitude: m.longitude,
            isStale:
                m.staleness == NodeDexMapStaleness.stale ||
                m.staleness == NodeDexMapStaleness.unknown,
            presence: m.liveNode != null
                ? presenceConfidenceFor(presenceMap, m.liveNode!)
                : null,
          ),
        )
        .toList(growable: false);

    final initialCenter = _initialCenter(markers);
    final initialZoom = _initialZoom(markers);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitToMarkersIfNeeded(markers);
    });

    return GlassScaffold.body(
      title: l10n.nodedexMapTitle,
      hasScrollBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: MeshMapWidget(
              mapController: _mapController,
              mapStyle: mapStyle,
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              minZoom: 2,
              maxZoom: 18,
              myNodeNum: myNodeNum,
              nodeMarkers: markerData,
              onNodeTap: _onMarkerTap,
            ),
          ),
          if (markers.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: _MapEmptyState(hasNodesWithoutPositions: false),
              ),
            ),
          Positioned(
            top: AppTheme.spacing12,
            left: AppTheme.spacing12,
            right: AppTheme.spacing12,
            child: _FilterChipBar(
              filter: filter,
              totalMarkers: allProjection.markers.length,
              visibleMarkers: markers.length,
              onTimeWindow: (w) =>
                  ref.read(nodeDexMapFilterProvider.notifier).setTimeWindow(w),
              onToggleFavourites: () => ref
                  .read(nodeDexMapFilterProvider.notifier)
                  .toggleFavouritesOnly(),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _initialCenter(List<NodeDexMapMarker> markers) {
    if (markers.isEmpty) return const LatLng(0, 0);
    final myMarker =
        markers.where((m) => m.isSelf).firstOrNull ?? markers.first;
    return LatLng(myMarker.latitude, myMarker.longitude);
  }

  double _initialZoom(List<NodeDexMapMarker> markers) {
    if (markers.length <= 1) return 13.0;
    return 11.0;
  }
}

class _FilterChipBar extends StatelessWidget {
  final NodeDexMapFilter filter;
  final int totalMarkers;
  final int visibleMarkers;
  final void Function(NodeDexMapTimeWindow) onTimeWindow;
  final VoidCallback onToggleFavourites;

  const _FilterChipBar({
    required this.filter,
    required this.totalMarkers,
    required this.visibleMarkers,
    required this.onTimeWindow,
    required this.onToggleFavourites,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = <(NodeDexMapTimeWindow, String)>[
      (NodeDexMapTimeWindow.hour1, l10n.nodedexMapFilter1h),
      (NodeDexMapTimeWindow.hours24, l10n.nodedexMapFilter24h),
      (NodeDexMapTimeWindow.days7, l10n.nodedexMapFilter7d),
      (NodeDexMapTimeWindow.all, l10n.nodedexMapFilterAll),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (window, label) in entries)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppTheme.spacing8,
                            ),
                            child: _FilterChip(
                              label: label,
                              selected: filter.timeWindow == window,
                              onTap: () => onTimeWindow(window),
                            ),
                          ),
                        _FilterChip(
                          icon: Icons.star_rounded,
                          label: l10n.nodedexMapFilterFavourites,
                          selected: filter.favouritesOnly,
                          onTap: onToggleFavourites,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.nodedexMapVisibleCount(visibleMarkers, totalMarkers),
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final bg = selected ? accent.withValues(alpha: 0.18) : context.background;
    final fg = selected ? accent : context.textSecondary;
    final border = selected ? accent : context.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: AppTheme.spacing4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerSheetHeader extends StatelessWidget {
  final String displayName;
  final String hexId;
  final String lastHeardText;
  final String? distanceText;

  const _MarkerSheetHeader({
    required this.displayName,
    required this.hexId,
    required this.lastHeardText,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          hexId,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          l10n.nodedexMapLastHeard(lastHeardText),
          style: TextStyle(
            fontSize: 13,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        if (distanceText != null) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.nodedexMapDistance(distanceText!),
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  final bool hasNodesWithoutPositions;

  const _MapEmptyState({required this.hasNodesWithoutPositions});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hasNodesWithoutPositions) {
      return AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.location_off_outlined,
            Icons.explore_off_outlined,
            Icons.gps_off,
          ],
          taglines: [
            l10n.nodedexMapEmptyNoPositionsTagline1,
            l10n.nodedexMapEmptyNoPositionsTagline2,
          ],
          titlePrefix: l10n.nodedexMapEmptyNoPositionsTitlePrefix,
          titleKeyword: l10n.nodedexMapEmptyNoPositionsTitleKeyword,
          titleSuffix: l10n.nodedexMapEmptyNoPositionsTitleSuffix,
        ),
      );
    }
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.map_outlined,
          Icons.explore_outlined,
          Icons.hexagon_outlined,
        ],
        taglines: [
          l10n.nodedexEmptyTagline1,
          l10n.nodedexEmptyTagline2,
          l10n.nodedexEmptyTagline3,
        ],
        titlePrefix: l10n.nodedexEmptyTitlePrefix,
        titleKeyword: l10n.nodedexEmptyTitleKeyword,
        titleSuffix: l10n.nodedexEmptyTitleSuffix,
      ),
    );
  }
}
