// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import '../../../core/safe_lat_lng.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../utils/signal_utils.dart';
import 'signal_thumbnail.dart';

/// A map view showing signals with GPS locations
class SignalMapView extends ConsumerStatefulWidget {
  const SignalMapView({
    required this.signals,
    required this.onSignalTap,
    this.initialCenter,
    this.initialZoom = 10.0,
    this.initialSelectedSignalId,
    super.key,
  });

  final List<Post> signals;
  final void Function(Post signal) onSignalTap;
  final LatLng? initialCenter;
  final double initialZoom;
  final String? initialSelectedSignalId;

  @override
  ConsumerState<SignalMapView> createState() => _SignalMapViewState();
}

class _SignalMapViewState extends ConsumerState<SignalMapView>
    with LifecycleSafeMixin<SignalMapView> {
  final MapController _mapController = MapController();
  Post? _selectedSignal;
  bool _showSignalList = false;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  bool _showSatelliteLabels = true;

  /// Programmatically focus on a specific signal: select the preview card
  /// and center/zoom the map to its location.
  void focusOnSignal(Post signal, {double zoom = 15.0}) {
    final location = signal.location;
    if (location == null) return;
    final point = safeLatLng(location.latitude, location.longitude);
    if (point == null) return;

    safeSetState(() {
      _selectedSignal = signal;
      _showSignalList = false;
    });

    _mapController.safeMove(point, zoom);
  }

  List<Post> get _signalsWithLocation =>
      widget.signals.where((s) => s.location != null).toList();

  LatLng? get _center {
    final initial = widget.initialCenter;
    if (isFiniteLatLng(initial)) return initial;

    final withLocation = _signalsWithLocation
        .where(
          (s) =>
              s.location!.latitude.isFinite && s.location!.longitude.isFinite,
        )
        .toList(growable: false);
    if (withLocation.isEmpty) return null;

    double totalLat = 0;
    double totalLng = 0;
    for (final signal in withLocation) {
      totalLat += signal.location!.latitude;
      totalLng += signal.location!.longitude;
    }
    return safeLatLng(
      totalLat / withLocation.length,
      totalLng / withLocation.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    // Defence in depth: callers may construct LatLng(NaN, NaN) from corrupted
    // persisted signal locations. The `_center` getter already drops a non-
    // finite initialCenter, but log here so the rejection is visible in
    // breadcrumbs the next time a real crash slips through.
    final initial = widget.initialCenter;
    if (initial != null && !isFiniteLatLng(initial)) {
      AppLogging.maps(
        'SignalMapView rejected non-finite initialCenter '
        '(lat=${initial.latitude}, lng=${initial.longitude})',
      );
    }
    if (widget.initialSelectedSignalId != null) {
      try {
        _selectedSignal = widget.signals.firstWhere(
          (s) => s.id == widget.initialSelectedSignalId,
        );
      } catch (_) {
        _selectedSignal = null;
      }
    }
  }

  Future<void> _loadMapStyle() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    final index = settings.mapTileStyleIndex;
    final labelsEnabled = settings.satelliteLabelsEnabled;
    if (index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() {
        _mapStyle = MapTileStyle.values[index];
        _showSatelliteLabels = labelsEnabled;
      });
    } else {
      safeSetState(() => _showSatelliteLabels = labelsEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    if (center == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: SemanticColors.muted),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.signalNoLocationTitle,
              style: TextStyle(color: SemanticColors.muted, fontSize: 16),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.signalNoLocationDescription,
              style: TextStyle(color: SemanticColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) {
              setState(() {
                _selectedSignal = null;
                _showSignalList = false;
              });
            },
            backgroundColor: context.background,
          ),
          children: [
            // Tile layer. Routes to Mapbox when its flag + token are set.
            TileLayer(
              urlTemplate:
                  MapConfig.mapboxUrlForStyle(
                    _mapStyle,
                    satelliteLabelsOn: _showSatelliteLabels,
                  ) ??
                  _mapStyle.url,
              subdomains: MapConfig.isMapboxActive
                  ? const <String>[]
                  : _mapStyle.subdomains,
              userAgentPackageName: MapConfig.userAgentPackageName,
              retinaMode: MapConfig.isMapboxActive,
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            ),
            // Transparent place-name + boundary overlay above satellite
            // imagery. Sits below mesh / signal markers. Skipped on the
            // Mapbox path (labels baked into satellite-streets-v12).
            if (_mapStyle == MapTileStyle.satellite &&
                _showSatelliteLabels &&
                !MapConfig.isMapboxActive)
              MapConfig.satelliteReferenceLabelsTileLayer(),
            MarkerLayer(
              markers: finiteMarkers(
                _signalsWithLocation.map((signal) {
                  final isSelected = _selectedSignal?.id == signal.id;
                  final markerSize = isSelected ? 48.0 : 36.0;

                  return Marker(
                    point: LatLng(
                      signal.location!.latitude,
                      signal.location!.longitude,
                    ),
                    width: markerSize,
                    height: markerSize,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSignal = signal;
                        });
                      },
                      child: SignalMapMarker(
                        signal: signal,
                        size: markerSize,
                        isSelected: isSelected,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Map attribution (matches world mesh style). Mapbox TOS
            // requires their attribution line and tap-through.
            Positioned(
              left: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(
                    MapConfig.isMapboxActive
                        ? MapConfig.mapboxAttributionUrl
                        : _mapStyle == MapTileStyle.satellite
                        ? 'https://www.esri.com'
                        : _mapStyle == MapTileStyle.terrain
                        ? 'https://opentopomap.org'
                        : 'https://carto.com/attributions',
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                  ),
                  child: Text(
                    MapConfig.isMapboxActive
                        ? MapConfig.mapboxAttributionLabel
                        : _mapStyle == MapTileStyle.satellite
                        ? '© Esri'
                        : _mapStyle == MapTileStyle.terrain
                        ? '© OpenTopoMap © OSM'
                        : '© OSM © CARTO',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Legend
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendItem(
                  color: AppTheme.successGreen,
                  label: context.l10n.signalLegendFiveMin,
                ),
                const SizedBox(height: AppTheme.spacing4),
                _LegendItem(
                  color: AppTheme.warningYellow,
                  label: context.l10n.signalLegendThirtyMin,
                ),
                const SizedBox(height: AppTheme.spacing4),
                _LegendItem(
                  color: AccentColors.orange,
                  label: context.l10n.signalLegendTwoHrs,
                ),
                const SizedBox(height: AppTheme.spacing4),
                _LegendItem(
                  color: AppTheme.errorRed,
                  label: context.l10n.signalLegendOverTwoHrs,
                ),
              ],
            ),
          ),
        ),
        // Fit all button (below legend)
        Positioned(
          top:
              16 +
              12 +
              (4 * 16) +
              (3 * 4) +
              12 +
              8, // legend top + padding + 4 items + 3 gaps + padding + spacing
          right: 16,
          child: _MapControlButton(
            icon: Icons.fit_screen,
            tooltip: context.l10n.signalFitAllSignals,
            onTap: _fitAllSignals,
          ),
        ),
        // Signal list panel (slides in from left)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: _showSignalList ? 0 : -300,
          top: 0,
          bottom: 0,
          width: 300,
          child: _SignalListPanel(
            signals: _signalsWithLocation,
            selectedSignal: _selectedSignal,
            onSignalSelected: (signal) {
              setState(() {
                _selectedSignal = signal;
                _showSignalList = false;
              });
              final location = signal.location;
              if (location != null) {
                _mapController.safeMove(
                  safeLatLng(location.latitude, location.longitude),
                  14.0,
                );
              }
            },
            onClose: () => setState(() => _showSignalList = false),
          ),
        ),
        // Signal count badge (tappable to open list)
        Positioned(
          top: 16,
          left: 16,
          child: IgnorePointer(
            ignoring: _showSignalList,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showSignalList ? 0.0 : 1.0,
              child: GestureDetector(
                onTap: () => setState(() => _showSignalList = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(AppTheme.radius20),
                    border: Border.all(
                      color: AccentColors.cyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, color: AccentColors.cyan, size: 16),
                      const SizedBox(width: AppTheme.spacing6),
                      Text(
                        context.l10n.signalOnMapCount(
                          _signalsWithLocation.length,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Selected signal preview
        if (_selectedSignal != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _SignalPreviewCard(
              signal: _selectedSignal!,
              onTap: () => widget.onSignalTap(_selectedSignal!),
              onClose: () {
                setState(() {
                  _selectedSignal = null;
                });
              },
            ),
          ),
      ],
    );
  }

  void _fitAllSignals() {
    final signals = _signalsWithLocation
        .where(
          (s) =>
              s.location!.latitude.isFinite && s.location!.longitude.isFinite,
        )
        .toList(growable: false);
    if (signals.isEmpty) return;

    double minLat = signals.first.location!.latitude;
    double maxLat = signals.first.location!.latitude;
    double minLng = signals.first.location!.longitude;
    double maxLng = signals.first.location!.longitude;

    for (final s in signals) {
      final lat = s.location!.latitude;
      final lng = s.location!.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    final sw = safeLatLng(minLat - latPadding, minLng - lngPadding);
    final ne = safeLatLng(maxLat + latPadding, maxLng + lngPadding);
    if (sw == null || ne == null) return;

    final cameraFit = CameraFit.bounds(
      bounds: LatLngBounds(sw, ne),
      padding: const EdgeInsets.all(AppTheme.spacing50),
    );

    final camera = cameraFit.fit(_mapController.camera);
    _mapController.safeMove(camera.center, camera.zoom.clamp(4.0, 16.0));
    HapticFeedback.lightImpact();
  }
}

/// Map control button widget
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _SignalPreviewCard extends StatelessWidget {
  const _SignalPreviewCard({
    required this.signal,
    required this.onTap,
    required this.onClose,
  });

  final Post signal;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ageColor = getSignalAgeColor(signal.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentOpacity: 0.5,
        backgroundColor: const Color(0xFF1a1a2e),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with thumbnail and close
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signal thumbnail
                SignalThumbnail(
                  signal: signal,
                  size: 56,
                  borderRadius: 12,
                  borderColor: context.accentColor.withValues(alpha: 0.3),
                ),
                const SizedBox(width: AppTheme.spacing12),
                // Signal content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (signal.content.isNotEmpty)
                        Text(
                          signal.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          '📡 ${context.l10n.signalFallbackContent}', // lint-allow: hardcoded-string
                          style: TextStyle(
                            color: SemanticColors.disabled,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: AppTheme.spacing4),
                      // Location name if available
                      if (signal.location?.name != null &&
                          signal.location!.name!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AccentColors.cyan,
                              size: 14,
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Expanded(
                              child: Text(
                                signal.location!.name!,
                                style: TextStyle(
                                  color: AccentColors.cyan,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  color: SemanticColors.muted,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Row(
                children: [
                  // Hop count
                  if (signal.hopCount != null) ...[
                    _StatChip(
                      icon: Icons.route,
                      label: signal.hopCount == 0
                          ? context.l10n.signalHopSingular(0)
                          : signal.hopCount == 1
                          ? context.l10n.signalHopSingular(1)
                          : context.l10n.signalHopsPlural(signal.hopCount!),
                      color: signal.hopCount == 0
                          ? AppTheme.successGreen
                          : signal.hopCount! <= 2
                          ? AppTheme.warningYellow
                          : AccentColors.orange,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                  ],
                  // Time ago
                  _StatChip(
                    icon: Icons.access_time,
                    label: formatTimeAgo(signal.createdAt, context.l10n),
                    color: ageColor,
                  ),
                  const Spacer(),
                  // TTL remaining
                  if (signal.expiresAt != null) ...[
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: formatTtlRemaining(signal.expiresAt, context.l10n),
                      color: getTtlColor(signal.expiresAt),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            // Footer row with additional info
            Row(
              children: [
                // Origin badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: signal.origin == SignalOrigin.mesh
                        ? AccentColors.cyan.withValues(alpha: 0.2)
                        : AccentColors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        signal.origin == SignalOrigin.mesh
                            ? Icons.sensors
                            : Icons.cloud,
                        size: 12,
                        color: signal.origin == SignalOrigin.mesh
                            ? AccentColors.cyan
                            : AccentColors.purple,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        signal.origin == SignalOrigin.mesh
                            ? context.l10n.signalOriginMesh
                            : context.l10n.signalOriginCloud,
                        style: TextStyle(
                          fontSize: 11,
                          color: signal.origin == SignalOrigin.mesh
                              ? AccentColors.cyan
                              : AccentColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                // Mesh node ID if available
                if (signal.meshNodeId != null)
                  Text(
                    '!${signal.meshNodeId!.toRadixString(16).padLeft(8, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: SemanticColors.muted,
                    ),
                  ),
                const Spacer(),
                // Tap to view hint
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.signalTapToView,
                      style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.muted,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: SemanticColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat chip with icon and label
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppTheme.spacing4),
        Text(label, style: context.bodySmallStyle?.copyWith(color: color)),
      ],
    );
  }
}

/// Panel showing list of signals on the map
class _SignalListPanel extends StatelessWidget {
  const _SignalListPanel({
    required this.signals,
    required this.selectedSignal,
    required this.onSignalSelected,
    required this.onClose,
  });

  final List<Post> signals;
  final Post? selectedSignal;
  final void Function(Post) onSignalSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Sort by most recent first
    final sortedSignals = List<Post>.from(signals)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: const Border(right: BorderSide(color: Colors.white10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 8, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Icon(Icons.list, size: 20, color: AccentColors.cyan),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.signalsPanelTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${sortedSignals.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white54,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Signal list
          Expanded(
            child: sortedSignals.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.signalNoSignals,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: sortedSignals.length,
                    itemBuilder: (context, index) {
                      final signal = sortedSignals[index];
                      final isSelected = selectedSignal?.id == signal.id;

                      return _SignalListItem(
                        signal: signal,
                        isSelected: isSelected,
                        onTap: () => onSignalSelected(signal),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Individual signal item in the list
class _SignalListItem extends StatelessWidget {
  const _SignalListItem({
    required this.signal,
    required this.isSelected,
    required this.onTap,
  });

  final Post signal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ageColor = getSignalAgeColor(signal.createdAt);

    return Material(
      color: isSelected
          ? AccentColors.cyan.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AccentColors.cyan : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Age indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ageColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing10),
              // Thumbnail
              SignalThumbnail(
                signal: signal,
                size: 40,
                borderRadius: 8,
                borderColor: ageColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppTheme.spacing10),
              // Signal info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      signal.content.isNotEmpty
                          ? signal.content
                          : '📡 ${context.l10n.signalFallbackContent}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Row(
                      children: [
                        if (signal.hopCount != null) ...[
                          Icon(Icons.route, size: 12, color: Colors.white38),
                          const SizedBox(width: AppTheme.spacing3),
                          Text(
                            '${signal.hopCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: AppTheme.spacing3),
                        Text(
                          formatTimeAgo(signal.createdAt, context.l10n),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                        if (signal.expiresAt != null) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: getTtlColor(signal.expiresAt),
                          ),
                          const SizedBox(width: AppTheme.spacing3),
                          Text(
                            formatTtlRemaining(
                              signal.expiresAt,
                              context.l10n,
                              compact: true,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: getTtlColor(signal.expiresAt),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isSelected ? AccentColors.cyan : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
