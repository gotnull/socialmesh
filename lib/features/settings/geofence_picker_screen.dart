import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/theme.dart';

/// Result from the geofence picker
class GeofenceResult {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const GeofenceResult({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

/// Screen for visually picking a geofence location and radius on a map
class GeofencePickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final double initialRadius;

  const GeofencePickerScreen({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialRadius = 1000.0,
  });

  @override
  State<GeofencePickerScreen> createState() => _GeofencePickerScreenState();
}

class _GeofencePickerScreenState extends State<GeofencePickerScreen> {
  late final MapController _mapController;
  LatLng? _center;
  double _radiusMeters = 1000.0;
  bool _isDraggingRadius = false;
  bool _isLoadingLocation = false;

  // For calculating drag distance
  LatLng? _dragStart;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _radiusMeters = widget.initialRadius;

    if (widget.initialLat != null && widget.initialLon != null) {
      _center = LatLng(widget.initialLat!, widget.initialLon!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = newCenter;
        _isLoadingLocation = false;
      });

      _mapController.move(newCenter, _mapController.camera.zoom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    HapticFeedback.selectionClick();
    setState(() {
      _center = point;
    });
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    HapticFeedback.mediumImpact();
    setState(() {
      _center = point;
      _isDraggingRadius = true;
      _dragStart = point;
    });
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, from, to);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isDraggingRadius && _center != null && _dragStart != null) {
      // Convert screen position to map position
      final point = _mapController.camera.pointToLatLng(
        math.Point(event.localPosition.dx, event.localPosition.dy),
      );

      final newRadius = _calculateDistance(_center!, point);
      if (newRadius >= 50 && newRadius <= 50000) {
        setState(() {
          _radiusMeters = newRadius;
        });
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isDraggingRadius) {
      setState(() {
        _isDraggingRadius = false;
        _dragStart = null;
      });
    }
  }

  void _confirmGeofence() {
    if (_center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to set a geofence center'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      GeofenceResult(
        latitude: _center!.latitude,
        longitude: _center!.longitude,
        radiusMeters: _radiusMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Set Geofence'),
        actions: [
          TextButton(
            onPressed: _center != null ? _confirmGeofence : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: _center != null
                    ? AppTheme.primaryGreen
                    : AppTheme.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          Listener(
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center ?? const LatLng(-33.8688, 151.2093),
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
                onLongPress: _onMapLongPress,
                interactionOptions: InteractionOptions(
                  flags: _isDraggingRadius
                      ? InteractiveFlag.none
                      : InteractiveFlag.all,
                ),
              ),
              children: [
                MapConfig.darkTileLayer(),
                // Geofence circle
                if (_center != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center!,
                        radius: _radiusMeters,
                        useRadiusInMeter: true,
                        color: AppTheme.primaryGreen.withAlpha(40),
                        borderColor: AppTheme.primaryGreen,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                // Center marker
                if (_center != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(80),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Instructions overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tap to set center • Long press and drag to adjust radius',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_center != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Radius: ${_radiusMeters >= 1000 ? '${(_radiusMeters / 1000).toStringAsFixed(1)} km' : '${_radiusMeters.toStringAsFixed(0)} m'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Radius slider
                  if (_center != null) ...[
                    Row(
                      children: [
                        const Text(
                          'Radius',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _radiusMeters >= 1000
                              ? '${(_radiusMeters / 1000).toStringAsFixed(1)} km'
                              : '${_radiusMeters.toStringAsFixed(0)} m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: AppTheme.darkBorder,
                        thumbColor: AppTheme.primaryGreen,
                        overlayColor: AppTheme.primaryGreen.withAlpha(40),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _radiusMeters.clamp(100, 10000),
                        min: 100,
                        max: 10000,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _radiusMeters = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Buttons row
                  Row(
                    children: [
                      // Current location button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingLocation
                              ? null
                              : _getCurrentLocation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryGreen,
                            side: BorderSide(
                              color: AppTheme.primaryGreen.withAlpha(100),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isLoadingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            _isLoadingLocation
                                ? 'Getting...'
                                : 'Use My Location',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Confirm button
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _center != null ? _confirmGeofence : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.darkBorder,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Set Geofence'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
