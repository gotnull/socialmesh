// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Map Screen — a lightweight, device-free map reachable from the
// scanner so users can browse and pre-download map tiles before pairing a node
// (e.g. prepping for an off-grid trip). Deliberately carries NO mesh layers:
// it has no protocol dependency and nothing to render empty when disconnected.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../core/widgets/primary_gradient_button.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import 'offline_tiles/offline_download_sheet.dart';
import 'offline_tiles/offline_tile_cache.dart';

class OfflineMapScreen extends ConsumerStatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  ConsumerState<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends ConsumerState<OfflineMapScreen>
    with LifecycleSafeMixin<OfflineMapScreen> {
  final MapController _mapController = MapController();
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0);
  final TextEditingController _searchController = TextEditingController();

  // Async-action guards so the search bar / locate button show a spinner and
  // can't be double-fired.
  bool _isSearching = false;
  bool _isLocating = false;

  // Terrain is the most useful basemap for off-grid hiking, so default to it.
  MapTileStyle _style = MapTileStyle.terrain;
  double _currentZoom = MapConfig.defaultZoom;

  // Last known device position, shown as a marker once "center on me" runs.
  LatLng? _myLocation;

  MapCompassMode _compassMode = MapCompassMode.northLocked;
  StreamSubscription<CompassEvent>? _compassSubscription;

  static const double _minZoom = 3;
  static const double _maxZoom = 18;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _mapController.dispose();
    _rotation.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Restore the persisted offline-map base style (falls back to the terrain
  // default when never set).
  Future<void> _loadStyle() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    final index = settings.offlineMapTileStyleIndex;
    if (index != null && index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() => _style = MapTileStyle.values[index]);
    }
  }

  Future<void> _saveStyle(MapTileStyle style) async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setOfflineMapTileStyleIndex(style.index);
  }

  // Jump the camera to a place typed in the search bar, using the platform
  // geocoder (no API key). Network is required, which is fine for the pre-trip
  // "download my area" flow this screen exists for.
  Future<void> _searchPlace(String query) async {
    final q = query.trim();
    if (q.isEmpty || _isSearching) return;
    FocusScope.of(context).unfocus();
    safeSetState(() => _isSearching = true);
    try {
      final results = await geocoding.locationFromAddress(q);
      if (!mounted) return;
      if (results.isEmpty) {
        showWarningSnackBar(context, context.l10n.offlineMapSearchFailed);
        return;
      }
      final first = results.first;
      final target = safeLatLng(first.latitude, first.longitude);
      if (target == null) return;
      // Land at street level so the searched place reads as a destination,
      // not a district. Clamped to _maxZoom for safety.
      const zoom = 16.0;
      _mapController.safeMove(target, zoom);
      _currentZoom = zoom;
    } catch (e) {
      AppLogging.map('Place search failed: $e');
      if (!mounted) return;
      showWarningSnackBar(context, context.l10n.offlineMapSearchFailed);
    } finally {
      if (mounted) safeSetState(() => _isSearching = false);
    }
  }

  // Center the map on the device's current GPS position. Independent of the
  // mesh location service so this screen stays protocol-free.
  Future<void> _centerOnMyLocation() async {
    if (_isLocating) return;
    safeSetState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        showWarningSnackBar(context, context.l10n.offlineMapLocationOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showWarningSnackBar(context, context.l10n.offlineMapLocationDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final target = safeLatLng(pos.latitude, pos.longitude);
      if (target == null) return;
      final zoom = _currentZoom < 12 ? 12.0 : _currentZoom;
      safeSetState(() => _myLocation = target);
      _mapController.safeMove(target, zoom);
      _currentZoom = zoom;
    } catch (e) {
      AppLogging.map('Center on location failed: $e');
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.offlineMapLocationUnavailable);
    } finally {
      if (mounted) safeSetState(() => _isLocating = false);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _compassMode == MapCompassMode.followHeading) {
      final rotDiff = ((camera.rotation - _rotation.value + 540) % 360) - 180;
      if (rotDiff.abs() > 1.0) {
        _compassSubscription?.cancel();
        _compassSubscription = null;
        safeSetState(() => _compassMode = MapCompassMode.freeRotate);
      }
    }
    _rotation.value = camera.rotation;
    _currentZoom = camera.zoom;
  }

  void _zoomBy(double delta) {
    final newZoom = (_currentZoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.safeMove(_mapController.camera.center, newZoom);
    _currentZoom = newZoom;
  }

  void _enableHeadingUp() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      final newRotation = -heading;
      final diff = ((newRotation - _rotation.value + 540) % 360) - 180;
      if (diff.abs() < 1.0) return;
      _mapController.safeMoveAndRotate(
        _mapController.camera.center,
        _currentZoom,
        newRotation,
      );
      _rotation.value = newRotation;
    });
    if (_compassSubscription != null) {
      safeSetState(() => _compassMode = MapCompassMode.followHeading);
    }
  }

  void _resetToNorthLocked() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _mapController.safeMoveAndRotate(
      _mapController.camera.center,
      _currentZoom,
      0,
    );
    _rotation.value = 0;
    safeSetState(() => _compassMode = MapCompassMode.northLocked);
  }

  void _onCompassTap() {
    switch (_compassMode) {
      case MapCompassMode.northLocked:
        safeSetState(() => _compassMode = MapCompassMode.freeRotate);
      case MapCompassMode.freeRotate:
        if (FlutterCompass.events == null) {
          showWarningSnackBar(context, context.l10n.mapCompassUnavailable);
          _resetToNorthLocked();
          return;
        }
        _enableHeadingUp();
      case MapCompassMode.followHeading:
        _resetToNorthLocked();
    }
  }

  void _setStyle(MapTileStyle style) {
    safeSetState(() => _style = style);
    _saveStyle(style);
  }

  void _downloadThisArea() {
    if (MapConfig.isMapboxActive || !kDownloadableStyles.contains(_style)) {
      showInfoSnackBar(context, context.l10n.offlineMapSatelliteNoDownload);
      return;
    }
    showOfflineDownloadSheet(
      context: context,
      bounds: _mapController.camera.visibleBounds,
      style: _style,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _searchController,
        maxLength: 120,
        textInputAction: TextInputAction.search,
        // Place names (e.g. "Kiruna") must not be autocorrected/suggested.
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: _searchPlace,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: context.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: context.l10n.offlineMapSearchHint,
          hintStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: context.textTertiary,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: context.textSecondary,
            size: 20,
          ),
          suffixIcon: _isSearching
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  child: SizedBox(
                    width: AppTheme.spacing16,
                    height: AppTheme.spacing16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.accentColor,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // lint-allow: haptic-feedback — the only bare GestureDetector here is the
    // keyboard-dismiss wrapper; control taps (compass, zoom) haptic via the
    // shared MapControls widgets.
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold.body(
        // A full-bleed map must not live in a scrollable viewport — mirror the
        // main map screen so the body gets fixed, bounded constraints.
        physics: const NeverScrollableScrollPhysics(),
        resizeToAvoidBottomInset: false,
        title: context.l10n.offlineMapTitle,
        actions: [
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              if (value == 'download') {
                _downloadThisArea();
                return;
              }
              final style = MapTileStyle.values
                  .where((s) => s.name == value)
                  .firstOrNull;
              if (style != null) _setStyle(style);
            },
            itemBuilder: (context) => [
              for (final style in MapTileStyle.values)
                PopupMenuItem<String>(
                  value: style.name,
                  child: Row(
                    children: [
                      Icon(
                        _style == style ? Icons.check : Icons.map_outlined,
                        size: 18,
                        color: _style == style
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(style.label),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(
                      Icons.download_for_offline_outlined,
                      size: 18,
                      color: context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(context.l10n.offlineMapDownloadArea),
                  ],
                ),
              ),
            ],
          ),
        ],
        body: Stack(
          children: [
            MeshMapWidget(
              mapController: _mapController,
              mapStyle: _style,
              initialCenter: const LatLng(
                MapConfig.defaultLat,
                MapConfig.defaultLon,
              ),
              initialZoom: MapConfig.defaultZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              disableRotation: _compassMode == MapCompassMode.northLocked,
              onPositionChanged: _onPositionChanged,
              onTap: (_, _) => FocusScope.of(context).unfocus(),
              additionalLayers: [
                if (_myLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _myLocation!,
                        width: AppTheme.spacing24,
                        height: AppTheme.spacing24,
                        child: const _MyLocationDot(),
                      ),
                    ],
                  ),
              ],
            ),
            ValueListenableBuilder<double>(
              valueListenable: _rotation,
              builder: (context, rotation, _) => MapControlsOverlay(
                currentZoom: _currentZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                mapRotation: rotation,
                compassMode: _compassMode,
                // Pushed down so the search bar above doesn't overlap the compass.
                topOffset: 72,
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onResetNorth: _onCompassTap,
                onCenterOnMe: _centerOnMyLocation,
              ),
            ),
            Positioned(
              top: AppTheme.spacing8,
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              child: _buildSearchBar(context),
            ),
            Positioned(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: AppTheme.spacing16,
              child: SafeArea(
                top: false,
                child: PrimaryGradientButton(
                  label: context.l10n.offlineMapPairCta,
                  icon: Icons.bluetooth_searching,
                  onPressed: safeNavigatorPop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You are here" marker: a solid blue dot with a white ring and a soft glow,
/// shown on the offline map after the user taps "center on me".
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AccentColors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AccentColors.blue.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
