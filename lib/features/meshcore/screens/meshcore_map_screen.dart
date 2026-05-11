// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../core/l10n/l10n_extension.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/logging.dart';
import '../../../core/los_analysis.dart';
import '../../../core/map_config.dart';
import '../../../core/safe_lat_lng.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../utils/snackbar.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_path_overlay.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_chat_screen.dart';

/// MeshCore Map screen.
///
/// Displays MeshCore contacts with location data on a map.
/// Styled to match the Meshtastic MapScreen but uses MeshCore data.
class MeshCoreMapScreen extends ConsumerStatefulWidget {
  final LatLng? highlightPosition;
  final String? highlightLabel;
  final double highlightZoom;

  const MeshCoreMapScreen({
    super.key,
    this.highlightPosition,
    this.highlightLabel,
    this.highlightZoom = 15.0,
  });

  @override
  ConsumerState<MeshCoreMapScreen> createState() => _MeshCoreMapScreenState();
}

class _MeshCoreMapScreenState extends ConsumerState<MeshCoreMapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitializedMap = false;
  bool _showRepeaters = true;
  bool _showChatNodes = true;
  bool _showOtherNodes = true;

  // Measurement state
  bool _measureMode = false;
  LatLng? _measureStart;
  LatLng? _measureEnd;
  MeshCoreContact? _measureContactA;
  MeshCoreContact? _measureContactB;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=map');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.safeMove(widget.highlightPosition, widget.highlightZoom);
    });
  }

  double _standardDeviation(List<double> values) {
    if (values.length <= 1) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = 0.0;
    for (final value in values) {
      final diff = value - mean;
      sumSquaredDiff += diff * diff;
    }
    final variance = sumSquaredDiff / (values.length - 1);
    return sqrt(variance);
  }

  double _zoomFromStdDev(double latStdDev, double lonStdDev) {
    final maxSpread = max(latStdDev, lonStdDev);
    if (maxSpread <= 0) return 13.0;
    final zoom = 10.0 - log(maxSpread * 10 + 1) / ln10 * 3;
    return zoom.clamp(4.0, 15.0);
  }

  /// D42-A: tracks the overlay we last auto-fitted to, so a single
  /// activation triggers one map-camera move rather than repeating
  /// on every rebuild.
  MeshCorePathOverlay? _lastFittedOverlay;

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final contactsState = ref.watch(meshCoreContactsProvider);
    // D42-A: path overlay drives the polyline + hop markers.
    final pathOverlay = ref.watch(meshCorePathOverlayProvider);

    // Auto-fit map bounds when the overlay flips to a new value.
    if (!identical(pathOverlay, _lastFittedOverlay)) {
      _lastFittedOverlay = pathOverlay;
      if (pathOverlay != null) {
        final pts = pathOverlay.drawablePoints();
        if (pts.length >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(pts),
                  padding: const EdgeInsets.all(AppTheme.spacing48),
                ),
              );
            } catch (_) {
              // fitCamera throws on degenerate bounds (single point);
              // safe to ignore - drawablePoints already filters to >=2.
            }
          });
        }
      }
    }

    // Filter contacts with finite location
    final contactsWithLocation = contactsState.contacts
        .where(
          (c) =>
              c.hasLocation &&
              (c.latitude?.isFinite ?? false) &&
              (c.longitude?.isFinite ?? false),
        )
        .where((c) {
          // Apply type filters
          if (c.type == 2 && !_showRepeaters) return false; // Repeater
          if (c.type == 1 && !_showChatNodes) return false; // Chat
          if (c.type != 1 && c.type != 2 && !_showOtherNodes) return false;
          return true;
        })
        .toList();

    // Calculate center and zoom
    LatLng center = const LatLng(0, 0);
    double initialZoom = 10.0;
    final hasMapContent =
        contactsWithLocation.isNotEmpty || widget.highlightPosition != null;

    if (contactsWithLocation.isNotEmpty) {
      final allPoints = contactsWithLocation
          .map((c) => LatLng(c.latitude!, c.longitude!))
          .toList();

      if (allPoints.length >= 3) {
        final latValues = allPoints.map((p) => p.latitude).toList();
        final lonValues = allPoints.map((p) => p.longitude).toList();
        final meanLat = latValues.reduce((a, b) => a + b) / latValues.length;
        final meanLon = lonValues.reduce((a, b) => a + b) / lonValues.length;
        final latStdDev = _standardDeviation(latValues);
        final lonStdDev = _standardDeviation(lonValues);

        final filteredPoints = allPoints
            .where(
              (p) =>
                  (p.latitude - meanLat).abs() <= latStdDev * 2 &&
                  (p.longitude - meanLon).abs() <= lonStdDev * 2,
            )
            .toList();

        if (filteredPoints.isNotEmpty) {
          final filteredLatValues = filteredPoints
              .map((p) => p.latitude)
              .toList();
          final filteredLonValues = filteredPoints
              .map((p) => p.longitude)
              .toList();
          final avgLat = filteredLatValues.reduce((a, b) => a + b);
          final avgLon = filteredLonValues.reduce((a, b) => a + b);
          center =
              safeLatLng(
                avgLat / filteredPoints.length,
                avgLon / filteredPoints.length,
              ) ??
              center;
          final filteredLatStdDev = _standardDeviation(filteredLatValues);
          final filteredLonStdDev = _standardDeviation(filteredLonValues);
          initialZoom = _zoomFromStdDev(filteredLatStdDev, filteredLonStdDev);
        } else {
          center = safeLatLng(meanLat, meanLon) ?? center;
          initialZoom = _zoomFromStdDev(latStdDev, lonStdDev);
        }
      } else {
        double avgLat = 0.0;
        double avgLon = 0.0;
        for (final point in allPoints) {
          avgLat += point.latitude;
          avgLon += point.longitude;
        }
        center =
            safeLatLng(avgLat / allPoints.length, avgLon / allPoints.length) ??
            center;
        initialZoom = 12.0;
      }
    }

    final highlight = widget.highlightPosition;
    if (highlight != null && isFiniteLatLng(highlight)) {
      center = highlight;
      initialZoom = widget.highlightZoom;
    }

    // Initialize map position after first build
    if (!_hasInitializedMap && hasMapContent) {
      _hasInitializedMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.safeMove(center, initialZoom);
        }
      });
    }

    return GlassScaffold.body(
      leading: const MeshCoreHamburgerMenuButton(),
      title: context.l10n.meshcoreMapTitle,
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        const MeshCoreDeviceStatusButton(),
        // D42-A: Clear-path action only visible when an overlay is set.
        if (pathOverlay != null)
          IconButton(
            key: const ValueKey('meshcore-map-path-overlay-clear'),
            icon: const Icon(Icons.timeline_outlined),
            onPressed: () =>
                ref.read(meshCorePathOverlayProvider.notifier).clear(),
            tooltip: context.l10n.meshcorePathOverlayClear,
          ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
          tooltip: context.l10n.meshcoreFilterTooltip,
        ),
      ],
      body: !isConnected
          ? _buildDisconnectedState()
          : !hasMapContent
          ? _buildEmptyState()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: initialZoom,
                    minZoom: 2.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                    onTap: (tapPos, point) {
                      if (_measureMode) {
                        _handleMeasureTap(point);
                      }
                    },
                  ),
                  children: [
                    // Tile layer. Routes to mapbox/dark-v11 when Mapbox is
                    // active so the visual matches the rest of the app.
                    TileLayer(
                      urlTemplate:
                          MapConfig.mapboxUrlForStyle(
                            MapTileStyle.dark,
                            satelliteLabelsOn: false,
                          ) ??
                          MapTileStyle.dark.url,
                      subdomains: MapConfig.isMapboxActive
                          ? const <String>[]
                          : MapTileStyle.dark.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      retinaMode: MapConfig.isMapboxActive,
                      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                    ),
                    MarkerLayer(
                      markers: finiteMarkers([
                        if (widget.highlightPosition != null)
                          Marker(
                            point: widget.highlightPosition!,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on_outlined,
                              color: AppTheme.errorRed,
                              size: 34,
                            ),
                          ),
                        ..._buildContactMarkers(contactsWithLocation),
                      ]),
                    ),
                    // Measurement polyline
                    if (_measureStart != null && _measureEnd != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_measureStart!, _measureEnd!],
                            strokeWidth: 2.5,
                            color: AppTheme.warningYellow,
                            pattern: const StrokePattern.dotted(
                              spacingFactor: 1.5,
                            ),
                          ),
                        ],
                      ),
                    // D42-A: path overlay polyline + hop markers.
                    // Uses a distinct accent + thicker stroke so it
                    // does not collide with the measurement polyline's
                    // warning-yellow dotted style.
                    if (pathOverlay != null &&
                        pathOverlay.drawablePoints().length >= 2)
                      PolylineLayer(
                        key: const ValueKey('meshcore-map-path-overlay-line'),
                        polylines: [
                          Polyline(
                            points: pathOverlay.drawablePoints(),
                            strokeWidth: 4,
                            color: context.accentColor,
                          ),
                        ],
                      ),
                    if (pathOverlay != null)
                      MarkerLayer(
                        key: const ValueKey(
                          'meshcore-map-path-overlay-markers',
                        ),
                        markers: finiteMarkers(
                          _buildPathOverlayMarkers(pathOverlay),
                        ),
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
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(
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
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'B',
                                    style: TextStyle(
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
                if (!_measureMode) _buildLegend(contactsWithLocation.length),
                // Measurement mode indicator pill
                if (_measureMode &&
                    (_measureStart == null || _measureEnd == null))
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius20,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.straighten,
                              size: 16,
                              color: Colors.black,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Flexible(
                              child: Text(
                                _measureStart == null
                                    ? context.l10n.meshcoreTapForPointA
                                    : context.l10n.meshcoreTapForPointB,
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
                                _measureContactA = null;
                                _measureContactB = null;
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
                if (_measureMode &&
                    _measureStart != null &&
                    _measureEnd != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _MeshCoreMeasurementCard(
                      start: _measureStart!,
                      end: _measureEnd!,
                      contactA: _measureContactA,
                      contactB: _measureContactB,
                      onClear: () => setState(() {
                        _measureStart = null;
                        _measureEnd = null;
                        _measureContactA = null;
                        _measureContactB = null;
                      }),
                      onExitMeasureMode: () => setState(() {
                        _measureMode = false;
                        _measureStart = null;
                        _measureEnd = null;
                        _measureContactA = null;
                        _measureContactB = null;
                      }),
                      onSwap: () => setState(() {
                        final tmpStart = _measureStart;
                        final tmpEnd = _measureEnd;
                        final tmpA = _measureContactA;
                        final tmpB = _measureContactB;
                        _measureStart = tmpEnd;
                        _measureEnd = tmpStart;
                        _measureContactA = tmpB;
                        _measureContactB = tmpA;
                      }),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDisconnectedState() {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.link_off_rounded,
          Icons.map_outlined,
          Icons.router_outlined,
          Icons.location_off_rounded,
          Icons.people_outline_rounded,
          Icons.cell_tower_rounded,
        ],
        taglines: [
          context.l10n.meshcoreDisconnectedMapDescription,
          context.l10n.meshcoreNoContactsWithLocationDescription,
          context.l10n.meshcoreContactsEmptyTagline1,
        ],
        titlePrefix: '',
        titleKeyword: context.l10n.meshcoreDisconnectedMapTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildEmptyState() {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.location_off_rounded,
          Icons.map_outlined,
          Icons.pin_drop_outlined,
          Icons.people_outline_rounded,
          Icons.gps_off_rounded,
          Icons.cell_tower_rounded,
        ],
        taglines: [
          context.l10n.meshcoreNoContactsWithLocationDescription,
          context.l10n.meshcoreContactsEmptyTagline1,
          context.l10n.meshcoreContactsEmptyTagline3,
        ],
        titlePrefix: '',
        titleKeyword: context.l10n.meshcoreNoContactsWithLocation,
        titleSuffix: '',
      ),
    );
  }

  /// D42-A: build the per-hop markers for the active path overlay.
  /// Only hops with a known position render a marker; unknown hops
  /// are surfaced via the overlay row sub-sheet (see
  /// [_showPathOverlayHopSheet]), never with a fabricated marker.
  List<Marker> _buildPathOverlayMarkers(MeshCorePathOverlay overlay) {
    final markers = <Marker>[];
    for (final hop in overlay.hops) {
      final ll = hop.latLng;
      if (ll == null) continue;
      markers.add(
        Marker(
          key: ValueKey('meshcore-map-path-hop-${hop.label}'),
          point: ll,
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showPathOverlayHopSheet(hop);
            },
            child: Container(
              decoration: BoxDecoration(
                color: context.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Center(
                child: Text(
                  hop.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  /// D42-A: minimal hop info sheet. Shows the hop's 2-char label and
  /// the matched contact's display name when present. Never a full
  /// pubkey, never the raw byte run.
  Future<void> _showPathOverlayHopSheet(MeshCorePathOverlayHop hop) {
    final l10n = context.l10n;
    return AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.meshcorePathOverlayHopSheetTitle),
          const SizedBox(height: AppTheme.spacing12),
          InfoTable(
            rows: [
              InfoTableRow(
                label: l10n.meshcorePathOverlayHopLabelHeader,
                value: l10n.meshcorePathOverlayHopLabelValue(hop.label),
              ),
              InfoTableRow(
                label: l10n.meshcorePathOverlayHopName,
                value: hop.displayName ?? l10n.meshcorePathOverlayUnknownHop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Marker> _buildContactMarkers(List<MeshCoreContact> contacts) {
    final markers = <Marker>[];

    for (final contact in contacts) {
      if (!contact.hasLocation) continue;

      markers.add(
        Marker(
          point: LatLng(contact.latitude!, contact.longitude!),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_measureMode) {
                _handleMeasureContactTap(contact);
                return;
              }
              _showContactInfo(contact);
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              setState(() {
                _measureMode = true;
                _measureStart = LatLng(contact.latitude!, contact.longitude!);
                _measureEnd = null;
                _measureContactA = contact;
                _measureContactB = null;
              });
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: _getContactColor(contact.type),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getContactIcon(contact.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Color _getContactColor(int type) {
    switch (type) {
      case 1: // Chat
        return AccentColors.blue;
      case 2: // Repeater
        return AppTheme.successGreen;
      case 3: // Room
        return AccentColors.purple;
      case 4: // Sensor
        return AccentColors.orange;
      default:
        return SemanticColors.disabled;
    }
  }

  IconData _getContactIcon(int type) {
    switch (type) {
      case 1: // Chat
        return Icons.person;
      case 2: // Repeater
        return Icons.cell_tower_rounded;
      case 3: // Room
        return Icons.meeting_room;
      case 4: // Sensor
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  Widget _buildLegend(int contactCount) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contactCount == 1
                    ? context.l10n.meshcoreContactCount(contactCount)
                    : context.l10n.meshcoreContactCountPlural(contactCount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildLegendItem(
                Icons.person,
                context.l10n.meshcoreLegendChat,
                AccentColors.blue,
              ),
              _buildLegendItem(
                Icons.cell_tower_rounded,
                context.l10n.meshcoreLegendRepeater,
                AppTheme.successGreen,
              ),
              _buildLegendItem(
                Icons.meeting_room,
                context.l10n.meshcoreLegendRoom,
                AccentColors.purple,
              ),
              _buildLegendItem(
                Icons.sensors,
                context.l10n.meshcoreLegendSensor,
                AccentColors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            label,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(MeshCoreContact contact) {
    AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing24,
          0,
          AppTheme.spacing24,
          AppTheme.spacing24,
        ),
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getContactColor(contact.type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  _getContactIcon(contact.type),
                  color: _getContactColor(contact.type),
                  size: 24,
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name.isNotEmpty
                          ? contact.name
                          : context.l10n.meshcoreUnknown,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing4),
                    Text(
                      contact.localizedTypeLabel(context.l10n),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing16),
          SectionTitle(title: context.l10n.meshcoreDeviceInfo),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.meshcoreChatInfoLocation,
                value:
                    '${contact.latitude?.toStringAsFixed(5)}, ${contact.longitude?.toStringAsFixed(5)}',
                icon: Icons.place_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreChatInfoPath,
                value: contact.localizedPathLabel(context.l10n),
                icon: Icons.alt_route_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcorePublicKeySettingsLabel,
                value: contact.publicKeyHex,
                icon: Icons.key_outlined,
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: PrimaryGradientButton(
                  icon: Icons.chat_rounded,
                  label: context.l10n.meshcoreMessageButton,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MeshCoreChatScreen.contact(contact: contact),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _centerOnContact(contact);
                },
                icon: const Icon(Icons.center_focus_strong),
                label: Text(context.l10n.meshcoreCenter),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _centerOnContact(MeshCoreContact contact) {
    if (!contact.hasLocation) return;
    _mapController.safeMove(
      safeLatLng(contact.latitude, contact.longitude),
      15.0,
    );
  }

  void _showFilterDialog(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.meshcoreFilterMap,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: this.context.textPrimary,
              ),
            ),
            SizedBox(height: AppTheme.spacing16),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.meshcoreFilterChatNodes,
              Icons.person,
              AccentColors.blue,
              _showChatNodes,
              (value) {
                setSheetState(() => _showChatNodes = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.meshcoreFilterRepeaters,
              Icons.cell_tower_rounded,
              AppTheme.successGreen,
              _showRepeaters,
              (value) {
                setSheetState(() => _showRepeaters = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.meshcoreFilterOtherNodes,
              Icons.device_unknown,
              SemanticColors.disabled,
              _showOtherNodes,
              (value) {
                setSheetState(() => _showOtherNodes = value);
                setState(() {});
              },
            ),
            SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: PrimaryGradientButton(
                label: context.l10n.meshcoreDone,
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSwitch(
    BuildContext ctx,
    StateSetter setSheetState,
    String label,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: context.bodyStyle?.copyWith(color: context.textPrimary),
            ),
          ),
          ThemedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  void _handleMeasureTap(LatLng point) {
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
        _measureContactA = null;
        _measureContactB = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureContactB = null;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureContactA = null;
        _measureContactB = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _handleMeasureContactTap(MeshCoreContact contact) {
    final point = LatLng(contact.latitude!, contact.longitude!);
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
        _measureContactA = contact;
        _measureContactB = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureContactB = contact;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureContactA = contact;
        _measureContactB = null;
      }
    });
    HapticFeedback.selectionClick();
  }
}

/// Measurement card for MeshCore map — distance + bearing between two points.
/// Long-press for actions sheet.
class _MeshCoreMeasurementCard extends StatelessWidget {
  final LatLng start;
  final LatLng end;
  final MeshCoreContact? contactA;
  final MeshCoreContact? contactB;
  final VoidCallback onClear;
  final VoidCallback onExitMeasureMode;
  final VoidCallback? onSwap;

  const _MeshCoreMeasurementCard({
    required this.start,
    required this.end,
    this.contactA,
    this.contactB,
    required this.onClear,
    required this.onExitMeasureMode,
    this.onSwap,
  });

  String _formatDist(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String _pointLabel(LatLng point, MeshCoreContact? contact, String prefix) {
    if (contact != null && contact.name.isNotEmpty) {
      return '$prefix: ${contact.name}';
    }
    return '$prefix: ${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)}';
  }

  String _buildSummary({
    required double distanceKm,
    required double bearing,
    required String cardinal,
  }) {
    final buf = StringBuffer();
    buf.write(
      '${_formatDist(distanceKm)} · '
      '${bearing.toStringAsFixed(0)}° $cardinal',
    );
    buf.writeln();
    buf.writeln(_pointLabel(start, contactA, 'A'));
    buf.write(_pointLabel(end, contactB, 'B'));
    return buf.toString();
  }

  void _showActionsSheet(BuildContext context) {
    final distanceKm = const Distance().as(LengthUnit.Kilometer, start, end);
    final bearing = calculateBearing(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);

    HapticFeedback.selectionClick();
    AppBottomSheet.showActions<String>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
        child: Text(
          context.l10n.meshcoreMeasurementActions,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.copy,
          label: context.l10n.meshcoreCopySummary,
          subtitle: _formatDist(distanceKm),
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildSummary(
                  distanceKm: distanceKm,
                  bearing: bearing,
                  cardinal: cardinal,
                ),
              ),
            );
            if (context.mounted) {
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreMeasurementCopied,
              );
            }
          },
        ),
        BottomSheetAction(
          icon: Icons.pin_drop,
          label: context.l10n.meshcoreCopyCoordinates,
          subtitle: context.l10n.meshcoreCopyCoordinatesSubtitle,
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text:
                    'A: ${start.latitude.toStringAsFixed(6)}, '
                    '${start.longitude.toStringAsFixed(6)}\n'
                    'B: ${end.latitude.toStringAsFixed(6)}, '
                    '${end.longitude.toStringAsFixed(6)}',
              ),
            );
            if (context.mounted) {
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreCoordinatesCopied,
              );
            }
          },
        ),
        BottomSheetAction(
          icon: Icons.open_in_new,
          label: context.l10n.meshcoreOpenMidpointInMaps,
          subtitle: context.l10n.meshcoreOpenInExternalMapApp,
          onTap: () {
            final midLat = (start.latitude + end.latitude) / 2.0;
            final midLon = (start.longitude + end.longitude) / 2.0;
            launchUrl(
              Uri.parse('https://maps.apple.com/?ll=$midLat,$midLon&z=14'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        if (onSwap != null)
          BottomSheetAction(
            icon: Icons.swap_horiz,
            label: context.l10n.meshcoreSwapAB,
            subtitle: context.l10n.meshcoreReverseMeasurementDirection,
            onTap: onSwap,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = const Distance().as(LengthUnit.Kilometer, start, end);
    final bearing = calculateBearing(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);

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
                        ],
                      ),
                      Text(
                        _pointLabel(start, contactA, 'A'),
                        style: context.captionStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                      Text(
                        _pointLabel(end, contactB, 'B'),
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
                  onPressed: onClear,
                  tooltip: context.l10n.meshcoreNewMeasurement,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppTheme.errorRed,
                  onPressed: onExitMeasureMode,
                  tooltip: context.l10n.meshcoreExitMeasureMode,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.meshcoreLongPressForActions,
              style: TextStyle(fontSize: 10, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
