// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
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
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/map_controls.dart';
import '../../../core/widgets/map_entity_list_item.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import 'widgets/meshcore_contact_list_panel.dart';
import '../../../core/widgets/section_header.dart';
import '../../../utils/snackbar.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_path_overlay.dart';
import '../../../models/meshcore_pinned_location.dart';
import '../../../providers/meshcore_contact_block_provider.dart';
import '../../../providers/meshcore_pinned_location_provider.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../navigation/meshcore_shell.dart';
import '../widgets/meshcore_sigil_avatar.dart';
import 'meshcore_chat_screen.dart';
import 'meshcore_map_marker_staleness.dart';

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

class _MeshCoreMapScreenState extends ConsumerState<MeshCoreMapScreen>
    with LifecycleSafeMixin {
  final MapController _mapController = MapController();
  bool _hasInitializedMap = false;
  bool _showRepeaters = true;
  bool _showChatNodes = true;
  bool _showOtherNodes = true;
  // Row 14: extra filters beyond the original type-based set.
  bool _showOnlyUnread = false;
  bool _hideMuted = false;

  // Measurement state
  bool _measureMode = false;
  LatLng? _measureStart;
  LatLng? _measureEnd;
  MeshCoreContact? _measureContactA;
  MeshCoreContact? _measureContactB;

  // Side-panel state. Mirrors the Meshtastic map's node-list drawer
  // shape so the two screens render the same UI affordance for
  // browsing the entities with positions.
  bool _showContactList = false;
  MeshCoreContact? _selectedContact;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Live camera state - tracked via onPositionChanged so the controls
  // overlay (zoom buttons + compass) renders the correct current
  // values without polling the controller every frame.
  double _currentZoom = 13.0;
  double _mapRotation = 0.0;

  // Tile style. Hydrates from settings on first frame so the user's
  // selection survives app restarts; mirrors the Meshtastic map.
  MapTileStyle _mapStyle = MapTileStyle.dark;
  bool _mapStyleHydrated = false;

  // Diagnostic overlays. Independent toggles; can stack on top of each
  // other and the type filters. In-memory only for v1 - persistence
  // can be added once the cross-protocol storage key strategy lands.
  bool _showRangeCircles = false;
  bool _showHeatmap = false;

  // Cluster markers at low zoom so dense areas read cleanly. Off by
  // default. Mirrors the Meshtastic map's `_clusterMarkers` flag.
  bool _clusterMarkers = false;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=map');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.safeMove(widget.highlightPosition, widget.highlightZoom);
      _hydrateMapStyle();
    });
  }

  Future<void> _hydrateMapStyle() async {
    if (_mapStyleHydrated) return;
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      final index = settings.mapTileStyleIndex;
      if (index >= 0 && index < MapTileStyle.values.length) {
        safeSetState(() {
          _mapStyle = MapTileStyle.values[index];
          _mapStyleHydrated = true;
        });
      }
    } catch (_) {
      // Settings not available - keep default dark style.
    }
  }

  Future<void> _saveMapStyle(MapTileStyle style) async {
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      await settings.setMapTileStyleIndex(style.index);
    } catch (_) {
      // Storage failure is non-fatal - the in-memory selection still
      // applies for the rest of the session.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    // D-Q10: user-dropped POI pins. AsyncValue — hydrates from
    // SharedPreferences once after first build; treat the loading /
    // error state as "no pins" so the map renders cleanly.
    final pinnedLocations =
        ref.watch(meshCorePinnedLocationProvider).value ??
        const <MeshCorePinnedLocation>[];

    // Decode the user's own advertised lat/lon from SELF_INFO. Firmware
    // wire scale is 1e6 (kMeshCoreAdvertLatLonScale). Treat (0, 0) as
    // "no location stored" - that matches the firmware clear-position
    // convention used by `setAdvertLatLon`. Non-finite values guard
    // against malformed payloads.
    final selfInfo = ref.watch(meshCoreSelfInfoProvider).selfInfo;
    LatLng? selfPosition;
    if (selfInfo != null &&
        selfInfo.latitude != null &&
        selfInfo.longitude != null) {
      final lat = selfInfo.latitude! / 1e6;
      final lon = selfInfo.longitude! / 1e6;
      if (lat.isFinite && lon.isFinite && !(lat == 0 && lon == 0)) {
        selfPosition = LatLng(lat, lon);
      }
    }

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
    // Row 14: load the muted-contact set once per build so the
    // per-marker predicate can hide muted entries without a provider
    // read per item.
    final blockedHex = ref
        .watch(meshCoreContactBlockProvider)
        .maybeWhen(data: (set) => set, orElse: () => const <String>{});

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
          // Row 14: unread-only + hide-muted filters.
          if (_showOnlyUnread && c.unreadCount == 0) return false;
          if (_hideMuted && blockedHex.contains(c.publicKeyHex.toLowerCase())) {
            return false;
          }
          return true;
        })
        .toList();

    // Calculate center and zoom
    LatLng center = const LatLng(0, 0);
    double initialZoom = 10.0;
    final hasMapContent =
        contactsWithLocation.isNotEmpty ||
        widget.highlightPosition != null ||
        selfPosition != null;

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

    // Fall back to centering on the user's own advertised position
    // when no contacts have a known location. Lower priority than
    // contact-derived bounds (above) and than an explicit highlight
    // (below) - if we have peers to show, those drive the camera.
    if (contactsWithLocation.isEmpty && selfPosition != null) {
      center = selfPosition;
      initialZoom = 14.0;
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
        // Contextual clear-path action - only when a path overlay is
        // active. Surfaces as a primary icon (not buried in the
        // overflow menu) because it's a transient state the user just
        // toggled on and needs an obvious off switch.
        if (pathOverlay != null)
          IconButton(
            key: const ValueKey('meshcore-map-path-overlay-clear'),
            icon: const Icon(Icons.timeline_outlined),
            tooltip: context.l10n.meshcorePathOverlayClear,
            onPressed: () {
              ref.read(meshCorePathOverlayProvider.notifier).clear();
            },
          ),
        const MeshCoreDeviceStatusButton(),
        // Single kebab overflow for the remaining secondary actions
        // (toggle list, filters, tile style). Mirrors the Meshtastic
        // AppBar pattern - one contextual primary + DeviceStatus +
        // kebab.
        AppBarOverflowMenu<String>(
          tooltip: context.l10n.mapMoreOptionsTooltip,
          onSelected: (value) {
            if (value == 'toggle_list') {
              setState(() => _showContactList = !_showContactList);
              return;
            }
            if (value == 'filter') {
              _showFilterDialog(context);
              return;
            }
            if (value.startsWith('style_')) {
              final styleName = value.substring('style_'.length);
              for (final style in MapTileStyle.values) {
                if (style.name == styleName) {
                  setState(() => _mapStyle = style);
                  unawaited(_saveMapStyle(style));
                  return;
                }
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'toggle_list',
              child: Row(
                children: [
                  Icon(
                    _showContactList ? Icons.list_alt : Icons.list,
                    size: 18,
                    color: _showContactList
                        ? context.accentColor
                        : context.textSecondary,
                  ),
                  SizedBox(width: AppTheme.spacing8),
                  Text(
                    _showContactList
                        ? context.l10n.mapHideListSheet
                        : context.l10n.mapShowListSheet,
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'filter',
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: context.textSecondary,
                  ),
                  SizedBox(width: AppTheme.spacing8),
                  Text(context.l10n.meshcoreFilterTooltip),
                ],
              ),
            ),
            const PopupMenuDivider(),
            for (final style in MapTileStyle.values)
              PopupMenuItem<String>(
                value: 'style_${style.name}',
                child: Row(
                  children: [
                    Icon(
                      _mapStyle == style ? Icons.check : Icons.map_outlined,
                      size: 18,
                      color: _mapStyle == style
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(style.label),
                  ],
                ),
              ),
          ],
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
                    // Enable the full interaction set so the new
                    // MapControlsOverlay compass + rotation gestures
                    // are usable. Mirrors the Meshtastic map.
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                      pinchZoomThreshold: 0.5,
                      scrollWheelVelocity: 0.005,
                    ),
                    onPositionChanged: (position, hasGesture) {
                      final newZoom = position.zoom;
                      final newRotation = position.rotation;
                      if (newZoom != _currentZoom ||
                          newRotation != _mapRotation) {
                        setState(() {
                          _currentZoom = newZoom;
                          _mapRotation = newRotation;
                        });
                      }
                    },
                    onTap: (tapPos, point) {
                      if (_measureMode) {
                        _handleMeasureTap(point);
                      }
                    },
                    // D-Q10: long-press anywhere on the map to drop
                    // a pin (POI annotation). Measure mode owns
                    // taps; long-press is a separate gesture so the
                    // two never conflict.
                    onLongPress: (tapPos, point) {
                      _promptForPinLabel(point);
                    },
                  ),
                  children: [
                    // Tile layer. Routes through MapConfig so the
                    // active Mapbox style applies when available; falls
                    // back to the OpenStreetMap-style URL for the
                    // selected MapTileStyle otherwise.
                    TileLayer(
                      urlTemplate:
                          MapConfig.mapboxUrlForStyle(
                            _mapStyle,
                            satelliteLabelsOn: false,
                          ) ??
                          _mapStyle.url,
                      subdomains: MapConfig.isMapboxActive
                          ? const <String>[]
                          : _mapStyle.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      retinaMode: MapConfig.isMapboxActive,
                      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                    ),
                    // Range circles: 5km radius around each contact
                    // (and self). Visualises a rough LoRa coverage
                    // estimate so the user can eyeball gaps. Mirrors
                    // the Meshtastic map's range-circle layer 1:1 in
                    // style (translucent purple fill + thin border).
                    if (_showRangeCircles)
                      CircleLayer(
                        circles: [
                          for (final c in contactsWithLocation)
                            CircleMarker(
                              point: LatLng(c.latitude!, c.longitude!),
                              radius: 5000,
                              useRadiusInMeter: true,
                              color: AppTheme.primaryPurple.withValues(
                                alpha: 0.08,
                              ),
                              borderColor: AppTheme.primaryPurple.withValues(
                                alpha: 0.2,
                              ),
                              borderStrokeWidth: 1,
                            ),
                          if (selfPosition != null)
                            CircleMarker(
                              point: selfPosition,
                              radius: 5000,
                              useRadiusInMeter: true,
                              color: AccentColors.cyan.withValues(alpha: 0.08),
                              borderColor: AccentColors.cyan.withValues(
                                alpha: 0.25,
                              ),
                              borderStrokeWidth: 1,
                            ),
                        ],
                      ),
                    // Heatmap: small accent-tinted circle at every
                    // entity position. Density reads as a heatmap on
                    // top of the tile layer. Same shape as Meshtastic.
                    if (_showHeatmap)
                      CircleLayer(
                        circles: [
                          for (final c in contactsWithLocation)
                            CircleMarker(
                              point: LatLng(c.latitude!, c.longitude!),
                              radius: 50,
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderColor: context.accentColor.withValues(
                                alpha: 0.3,
                              ),
                              borderStrokeWidth: 1,
                            ),
                          if (selfPosition != null)
                            CircleMarker(
                              point: selfPosition,
                              radius: 50,
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderColor: context.accentColor.withValues(
                                alpha: 0.3,
                              ),
                              borderStrokeWidth: 1,
                            ),
                        ],
                      ),
                    // Non-clustered overlay markers: red highlight pin,
                    // the user's self "you are here" marker, and the
                    // POI pins. These never enter the cluster - they
                    // are distinct affordances that the user needs to
                    // see at every zoom level.
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
                        if (selfPosition != null)
                          Marker(
                            key: const ValueKey('meshcore-map-self-marker'),
                            point: selfPosition,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AccentColors.cyan,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AccentColors.cyan.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ..._buildPinnedLocationMarkers(pinnedLocations),
                      ]),
                    ),
                    // Contact markers - wrapped in a cluster layer when
                    // the user has opted in via the filter dialog. The
                    // contact-by-pubkey-hex map lets the cluster tap
                    // handler recover the underlying contact for the
                    // list sheet.
                    Builder(
                      builder: (context) {
                        final contactMarkers = finiteMarkers(
                          _buildContactMarkers(contactsWithLocation),
                        ).toList(growable: false);
                        if (!_clusterMarkers) {
                          return MarkerLayer(markers: contactMarkers);
                        }
                        return _buildClusterLayer(
                          context: context,
                          markers: contactMarkers,
                          contactsByPubKeyHex: {
                            for (final c in contactsWithLocation)
                              c.publicKeyHex: c,
                          },
                        );
                      },
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
                // Right-side controls overlay: compass, zoom in/out,
                // fit-all, center-on-me. Mirrors the Meshtastic map's
                // controls 1:1 via the shared `MapControlsOverlay`
                // widget in lib/core/widgets/.
                MapControlsOverlay(
                  currentZoom: _currentZoom,
                  mapRotation: _mapRotation,
                  onZoomIn: () {
                    final next = (_currentZoom + 1.0).clamp(2.0, 18.0);
                    _mapController.safeMove(_mapController.camera.center, next);
                  },
                  onZoomOut: () {
                    final next = (_currentZoom - 1.0).clamp(2.0, 18.0);
                    _mapController.safeMove(_mapController.camera.center, next);
                  },
                  onFitAll: contactsWithLocation.isEmpty && selfPosition == null
                      ? null
                      : () {
                          final points = <LatLng>[
                            for (final c in contactsWithLocation)
                              LatLng(c.latitude!, c.longitude!),
                            if (selfPosition != null) selfPosition,
                          ];
                          if (points.length < 2) {
                            _mapController.safeMove(points.first, 13.0);
                            return;
                          }
                          try {
                            _mapController.fitCamera(
                              CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(points),
                                padding: const EdgeInsets.all(
                                  AppTheme.spacing48,
                                ),
                              ),
                            );
                          } catch (_) {
                            // Degenerate bounds (points coincide); fall
                            // back to a simple move on the first point.
                            _mapController.safeMove(points.first, 13.0);
                          }
                        },
                  onCenterOnMe: selfPosition == null
                      ? null
                      : () => _mapController.safeMove(selfPosition, 15.0),
                  hasMyLocation: selfPosition != null,
                  onResetNorth: () {
                    _mapController.rotate(0);
                  },
                ),
                // Side panel listing contacts with locations. Mirrors
                // the Meshtastic map's `_NodeListPanel` slide-in shape
                // exactly: 300pt wide drawer that animates in from the
                // left edge. Tapping a contact centers the map and
                // opens the existing info sheet.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _showContactList ? 0 : -300,
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: MeshCoreContactListPanel(
                    contacts: contactsWithLocation,
                    selectedContact: _selectedContact,
                    selfPosition: selfPosition,
                    onContactSelected: (c) {
                      setState(() {
                        _selectedContact = c;
                        _showContactList = false;
                      });
                      _mapController.safeMove(
                        LatLng(c.latitude!, c.longitude!),
                        15.0,
                      );
                      _showContactInfo(c);
                    },
                    onClose: () => setState(() => _showContactList = false),
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                  ),
                ),
              ],
            ),
    );
  }

  /// Wraps the contact markers in a [MarkerClusterLayerWidget]. Config
  /// mirrors the Meshtastic map (`maxClusterRadius: 80`, fade-friendly
  /// animations) so cluster behaviour is consistent across both
  /// protocols. Tapping a cluster opens a bottom sheet listing the
  /// underlying contacts.
  Widget _buildClusterLayer({
    required BuildContext context,
    required List<Marker> markers,
    required Map<String, MeshCoreContact> contactsByPubKeyHex,
  }) {
    final accentColor = context.accentColor;
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        size: const Size(44, 44),
        alignment: Alignment.center,
        padding: EdgeInsets.zero,
        maxZoom: 15,
        zoomToBoundsOnClick: false,
        animationsOptions: const AnimationsOptions(
          zoom: Duration.zero,
          fitBound: Duration(milliseconds: 300),
          centerMarker: Duration.zero,
          spiderfy: Duration(milliseconds: 200),
        ),
        markers: markers,
        builder: (context, clusterMarkers) {
          final count = clusterMarkers.length;
          final size = count > 100
              ? 48.0
              : count > 50
              ? 44.0
              : 40.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showClusterListSheet(
              context,
              clusterMarkers,
              contactsByPubKeyHex,
            ),
            child: Container(
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
            ),
          );
        },
      ),
    );
  }

  /// Opens a bottom sheet listing the contacts inside a tapped
  /// cluster. Tapping a row centers the map on the contact and
  /// surfaces the existing contact info sheet.
  Future<void> _showClusterListSheet(
    BuildContext context,
    List<Marker> clusterMarkers,
    Map<String, MeshCoreContact> contactsByPubKeyHex,
  ) async {
    final contacts = <MeshCoreContact>[];
    for (final m in clusterMarkers) {
      final key = m.key;
      if (key is ValueKey<String>) {
        // Marker keys are formatted `meshcore-contact-marker-<hex>`.
        const prefix = 'meshcore-contact-marker-';
        if (key.value.startsWith(prefix)) {
          final hex = key.value.substring(prefix.length);
          final contact = contactsByPubKeyHex[hex];
          if (contact != null) contacts.add(contact);
        }
      }
    }
    if (contacts.isEmpty) return;
    HapticFeedback.selectionClick();
    await AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (scrollController) => ListView.builder(
        controller: scrollController,
        itemCount: contacts.length,
        itemBuilder: (ctx, i) {
          final c = contacts[i];
          final age = DateTime.now().difference(c.lastSeen);
          final isFresh = age <= kMeshCoreMarkerFreshThreshold;
          final isStale = age >= kMeshCoreMarkerVeryStaleThreshold;
          return MapEntityListItem(
            displayName: c.displayName,
            avatarChar: c.name.isNotEmpty
                ? c.name.characters.first.toUpperCase()
                : c.publicKeyHex.characters.first.toUpperCase(),
            isMyEntity: false,
            isSelected: false,
            isStale: isStale,
            isActive: isFresh,
            statusColor: isFresh
                ? AppTheme.successGreen
                : (isStale ? AppTheme.errorRed : ctx.textSecondary),
            statusText: c.typeLabel,
            onTap: () {
              if (!mounted) return;
              Navigator.of(ctx).pop();
              _mapController.safeMove(LatLng(c.latitude!, c.longitude!), 15.0);
              _showContactInfo(c);
            },
          );
        },
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
          context.l10n.meshcoreMapEmptyTaglineSetOwnLocation,
          context.l10n.meshcoreMapEmptyTaglineWaitForAdverts,
        ],
        titlePrefix: context.l10n.meshcoreMapEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreMapEmptyTitleKeyword,
        titleMid: context.l10n.meshcoreMapEmptyTitleMid,
        titleKeyword2: context.l10n.meshcoreMapEmptyTitleKeyword2,
        titleSuffix: context.l10n.meshcoreMapEmptyTitleSuffix,
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

    final now = DateTime.now();
    for (final contact in contacts) {
      if (!contact.hasLocation) continue;

      // Row 13: age-based marker fade. Contacts we haven't heard from
      // recently get rendered at reduced opacity so the map reflects
      // the freshness of the data at a glance.
      final stalenessOpacity = meshCoreContactMarkerOpacity(contact, now);

      markers.add(
        Marker(
          // Key carries the contact's public-key hex so the cluster
          // builder can recover the underlying MeshCoreContact when a
          // cluster expands into a list sheet.
          key: ValueKey<String>(
            'meshcore-contact-marker-${contact.publicKeyHex}',
          ),
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
            // D-S5b: sigil-with-type-badge composite when the contact
            // carries a usable pubkey. The outer container preserves
            // the "map pin" affordance (white border + drop shadow);
            // the inner sigil gives at-a-glance identity; the badge
            // overlay preserves at-a-glance type discrimination
            // (person / cell_tower / meeting_room / sensors). For
            // malformed contacts (< 4 byte pubkey) the original
            // type-only marker is preserved as a safe fallback.
            // Row 13: wrap in Opacity so stale-location markers fade.
            child: Opacity(
              opacity: stalenessOpacity,
              child: contact.publicKey.length >= 4
                  ? _buildSigilMarker(contact)
                  : Column(
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
        ),
      );
    }

    return markers;
  }

  /// D-S5b: composite map marker that overlays a small type-icon badge
  /// (bottom-right) on top of a pubkey-derived sigil. The outer ring
  /// keeps the "map pin" affordance (white border + drop shadow); the
  /// inner sigil delivers identity-glance; the badge delivers
  /// type-glance (chat / repeater / room / sensor). Callers guarantee
  /// `contact.publicKey.length >= 4`.
  Widget _buildSigilMarker(MeshCoreContact contact) {
    final typeColor = _getContactColor(contact.type);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: MeshCoreSigilAvatar(pubKey: contact.publicKey, size: 48),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: typeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _getContactIcon(contact.type),
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
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

  // ---------------------------------------------------------------------------
  // D-Q10: pinned-locations (POI annotations).
  // ---------------------------------------------------------------------------

  List<Marker> _buildPinnedLocationMarkers(List<MeshCorePinnedLocation> pins) {
    final markers = <Marker>[];
    for (final pin in pins) {
      // Drop pins with non-finite coords at the boundary - one NaN
      // LatLng in a MarkerLayer makes projectAtZoom throw and crashes
      // the whole map build.
      final point = safeLatLng(pin.latitude, pin.longitude);
      if (point == null) continue;
      markers.add(
        Marker(
          point: point,
          width: 36,
          height: 36,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showPinActionSheet(pin),
            child: Tooltip(
              message: pin.label,
              child: Icon(
                Icons.pin_drop_rounded,
                color: AccentColors.yellow,
                size: 30,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  /// D-Q10: bottom-sheet prompt for the pin label. Cancel returns
  /// without writing; submit appends to the SharedPreferences-backed
  /// list via the AsyncNotifier.
  Future<void> _promptForPinLabel(LatLng point) async {
    HapticFeedback.lightImpact();
    final l10n = context.l10n;
    final controller = TextEditingController();
    final result = await AppBottomSheet.show<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.meshcoreMapPinDropTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.meshcoreMapPinDropSubtitle(
                point.latitude.toStringAsFixed(5),
                point.longitude.toStringAsFixed(5),
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 64,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(context).pop(v),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: l10n.meshcoreMapPinDropLabelField,
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: l10n.meshcoreMapPinDropLabelHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                filled: true,
                fillColor: context.background,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                prefixIcon: Icon(
                  Icons.pin_drop_outlined,
                  color: context.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.meshcoreMapPinCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: l10n.meshcoreMapPinDropSave,
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(context).pop(controller.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted) return;
    final label = (result ?? '').trim();
    if (label.isEmpty) return;
    await ref
        .read(meshCorePinnedLocationProvider.notifier)
        .addPin(
          latitude: point.latitude,
          longitude: point.longitude,
          label: label,
        );
    if (!mounted) return;
    showSuccessSnackBar(context, l10n.meshcoreMapPinDropped(label));
  }

  /// D-Q10: tap a pin to open the per-pin action sheet (currently
  /// just a "Remove" affordance).
  Future<void> _showPinActionSheet(MeshCorePinnedLocation pin) async {
    HapticFeedback.lightImpact();
    final l10n = context.l10n;
    await AppBottomSheet.showActions<void>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing12,
        ),
        child: Text(
          pin.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.delete_outline_rounded,
          iconColor: AppTheme.errorRed,
          label: l10n.meshcoreMapPinRemove,
          isDestructive: true,
          onTap: () async {
            await ref
                .read(meshCorePinnedLocationProvider.notifier)
                .removePin(pin.id);
            if (!mounted) return;
            showSuccessSnackBar(context, l10n.meshcoreMapPinRemoved(pin.label));
          },
        ),
      ],
    );
  }

  Widget _buildLegend(int contactCount) {
    // Bottom-left so it doesn't collide with the right-side
    // MapControlsOverlay (compass + zoom + recenter column). Bottom
    // padding clears the system safe area + a comfortable thumb gap.
    return Positioned(
      bottom: 24,
      left: 16,
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
            // Row 14: unread-only + hide-muted filters.
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.meshcoreFilterUnreadOnly,
              Icons.mark_email_unread_outlined,
              AccentColors.cyan,
              _showOnlyUnread,
              (value) {
                setSheetState(() => _showOnlyUnread = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.meshcoreFilterHideMuted,
              Icons.notifications_off_outlined,
              AccentColors.orange,
              _hideMuted,
              (value) {
                setSheetState(() => _hideMuted = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.mapShowRangeCircles,
              Icons.radio_button_unchecked,
              AppTheme.primaryPurple,
              _showRangeCircles,
              (value) {
                setSheetState(() => _showRangeCircles = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.mapShowHeatmap,
              Icons.local_fire_department_outlined,
              AppTheme.errorRed,
              _showHeatmap,
              (value) {
                setSheetState(() => _showHeatmap = value);
                setState(() {});
              },
            ),
            _buildFilterSwitch(
              ctx,
              setSheetState,
              context.l10n.mapShowClusterMarkers,
              Icons.bubble_chart_outlined,
              AccentColors.cyan,
              _clusterMarkers,
              (value) {
                setSheetState(() => _clusterMarkers = value);
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
