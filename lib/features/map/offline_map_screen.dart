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
import 'package:latlong2/latlong.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../core/widgets/primary_gradient_button.dart';
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

  // Terrain is the most useful basemap for off-grid hiking, so default to it.
  MapTileStyle _style = MapTileStyle.terrain;
  double _currentZoom = MapConfig.defaultZoom;

  MapCompassMode _compassMode = MapCompassMode.northLocked;
  StreamSubscription<CompassEvent>? _compassSubscription;

  static const double _minZoom = 3;
  static const double _maxZoom = 18;

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _mapController.dispose();
    _rotation.dispose();
    super.dispose();
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

  void _setStyle(MapTileStyle style) => safeSetState(() => _style = style);

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

  @override
  Widget build(BuildContext context) {
    return GlassScaffold.body(
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
          ),
          ValueListenableBuilder<double>(
            valueListenable: _rotation,
            builder: (context, rotation, _) => MapControlsOverlay(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              mapRotation: rotation,
              compassMode: _compassMode,
              showNavigation: false,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onResetNorth: _onCompassTap,
            ),
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
    );
  }
}
