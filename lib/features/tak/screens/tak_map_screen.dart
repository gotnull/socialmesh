// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/map_controls.dart';
import '../models/tak_event.dart';
import '../providers/tak_providers.dart';
import '../services/tak_gateway_client.dart';
import '../widgets/tak_map_layer.dart';
import 'tak_event_detail_screen.dart';

/// Dedicated map screen for TAK/CoT entities.
///
/// Shares the same map tile styles and controls as the mesh node map but
/// displays TAK entities exclusively. Accessible from the drawer.
class TakMapScreen extends ConsumerStatefulWidget {
  const TakMapScreen({super.key});

  @override
  ConsumerState<TakMapScreen> createState() => _TakMapScreenState();
}

class _TakMapScreenState extends ConsumerState<TakMapScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<TakMapScreen> {
  final MapController _mapController = MapController();

  double _currentZoom = 10.0;
  double _mapRotation = 0.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  TakEvent? _selectedEntity;

  StreamSubscription<TakConnectionState>? _stateSub;
  TakConnectionState _connectionState = TakConnectionState.disconnected;

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    AppLogging.tak('TakMapScreen initState');

    final client = ref.read(takGatewayClientProvider);
    _stateSub = client.stateStream.listen((state) {
      if (!mounted) return;
      safeSetState(() => _connectionState = state);
    });
    _connectionState = client.state;

    // Ensure the persistence notifier is alive
    ref.read(takPersistenceNotifierProvider);

    // Auto-connect if not already connected
    if (client.state == TakConnectionState.disconnected) {
      AppLogging.tak('TakMapScreen: auto-connecting...');
      client.connect();
    }
  }

  @override
  void dispose() {
    AppLogging.tak('TakMapScreen dispose');
    _stateSub?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _toggleConnection() {
    final client = ref.read(takGatewayClientProvider);
    if (_connectionState == TakConnectionState.connected) {
      AppLogging.tak('TakMapScreen: user toggled disconnect');
      client.disconnect();
    } else {
      AppLogging.tak('TakMapScreen: user toggled connect');
      client.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(takActiveEventsProvider);

    // Determine initial center from events
    final center = _calculateCenter(events);

    return GlassScaffold.body(
      title: 'TAK Map',
      actions: [
        // Connection toggle
        IconButton(
          icon: Icon(
            _connectionState == TakConnectionState.connected
                ? Icons.link
                : Icons.link_off,
            color: _connectionState == TakConnectionState.connected
                ? Colors.green
                : Colors.grey,
          ),
          onPressed: _toggleConnection,
          tooltip: _connectionState == TakConnectionState.connected
              ? 'Disconnect'
              : 'Connect',
        ),
        // Map style picker
        PopupMenuButton<MapTileStyle>(
          icon: Icon(Icons.map, color: context.textSecondary),
          tooltip: 'Map style',
          onSelected: (style) => setState(() => _mapStyle = style),
          itemBuilder: (context) => MapTileStyle.values.map((style) {
            return PopupMenuItem(
              value: style,
              child: Row(
                children: [
                  Icon(
                    _mapStyle == style ? Icons.check : Icons.map_outlined,
                    size: 18,
                    color: _mapStyle == style
                        ? context.accentColor
                        : context.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(style.label),
                ],
              ),
            );
          }).toList(),
        ),
        // Overflow menu
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            switch (value) {
              case 'fit_all':
                _fitAllEntities(events);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'fit_all',
              enabled: events.isNotEmpty,
              child: Row(
                children: [
                  Icon(
                    Icons.fit_screen,
                    size: 18,
                    color: events.isNotEmpty
                        ? context.textSecondary
                        : context.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Fit all entities'),
                ],
              ),
            ),
          ],
        ),
      ],
      body: events.isEmpty
          ? _buildEmptyState(context)
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _currentZoom,
                    minZoom: 4,
                    maxZoom: 18,
                    backgroundColor: context.background,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                      pinchZoomThreshold: 0.5,
                      scrollWheelVelocity: 0.005,
                    ),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _currentZoom = position.zoom;
                          _mapRotation = position.rotation;
                        });
                      }
                    },
                    onTap: (_, _) {
                      setState(() => _selectedEntity = null);
                    },
                  ),
                  children: [
                    // Map tiles
                    TileLayer(
                      urlTemplate: _mapStyle.url,
                      subdomains: _mapStyle.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      retinaMode: _mapStyle != MapTileStyle.satellite,
                      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                      tileBuilder: (context, tileWidget, tile) {
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: tileWidget,
                        );
                      },
                    ),
                    // TAK entity markers
                    TakMapLayer(
                      events: events,
                      onMarkerTap: (event) {
                        AppLogging.tak(
                          'TAK Map entity selected: uid=${event.uid}, '
                          'callsign=${event.displayName}',
                        );
                        HapticFeedback.selectionClick();
                        setState(() => _selectedEntity = event);
                      },
                    ),
                    // Attribution
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(
                            _mapStyle == MapTileStyle.satellite
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
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _mapStyle == MapTileStyle.satellite
                                ? '\u00A9 Esri'
                                : _mapStyle == MapTileStyle.terrain
                                ? '\u00A9 OpenTopoMap'
                                : '\u00A9 CARTO',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Status bar overlay
                _buildStatusBar(context, events),
                // Selected entity card
                if (_selectedEntity != null) _buildEntityCard(context),
                // Map controls
                MapControlsOverlay(
                  currentZoom: _currentZoom,
                  minZoom: 4,
                  maxZoom: 18,
                  mapRotation: _mapRotation,
                  onZoomIn: () {
                    final newZoom = (_currentZoom + 1).clamp(4.0, 18.0);
                    _animatedMove(_mapController.camera.center, newZoom);
                    HapticFeedback.selectionClick();
                  },
                  onZoomOut: () {
                    final newZoom = (_currentZoom - 1).clamp(4.0, 18.0);
                    _animatedMove(_mapController.camera.center, newZoom);
                    HapticFeedback.selectionClick();
                  },
                  onFitAll: events.isNotEmpty
                      ? () => _fitAllEntities(events)
                      : null,
                  onResetNorth: () => _animatedMove(
                    _mapController.camera.center,
                    _currentZoom,
                    rotation: 0,
                  ),
                  showFitAll: events.isNotEmpty,
                  showNavigation: false,
                  showCompass: true,
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _connectionState == TakConnectionState.connected
                ? 'Waiting for CoT entities...'
                : 'Not connected to TAK Gateway',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _connectionState == TakConnectionState.connected
                ? 'Entities will appear as markers on the map'
                : 'Connect to the gateway to see TAK entities',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (_connectionState != TakConnectionState.connected) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _toggleConnection,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(BuildContext context, List<TakEvent> events) {
    final staleCount = events.where((e) => e.isStale).length;
    final activeCount = events.length - staleCount;
    final stateLabel = switch (_connectionState) {
      TakConnectionState.connected => 'Connected',
      TakConnectionState.connecting => 'Connecting...',
      TakConnectionState.reconnecting => 'Reconnecting...',
      TakConnectionState.disconnected => 'Disconnected',
    };
    final stateColor = switch (_connectionState) {
      TakConnectionState.connected => Colors.green,
      TakConnectionState.connecting ||
      TakConnectionState.reconnecting => Colors.orange,
      TakConnectionState.disconnected => Colors.grey,
    };

    return Positioned(
      left: 16,
      top: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stateColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: stateColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stateLabel,
              style: TextStyle(
                fontSize: 12,
                color: stateColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$activeCount active',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            if (staleCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$staleCount stale',
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Entity card (on marker tap)
  // ---------------------------------------------------------------------------

  Widget _buildEntityCard(BuildContext context) {
    final event = _selectedEntity!;
    final theme = Theme.of(context);
    final isStale = event.isStale;
    final age = _formatAge(event.receivedUtcMs);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: () {
          AppLogging.tak(
            'TAK Map popup tap-through to detail: uid=${event.uid}',
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TakEventDetailScreen(event: event),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isStale ? Colors.grey : Colors.orange).withValues(
                alpha: 0.3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.gps_fixed,
                  color: isStale ? Colors.grey : Colors.orange.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.typeDescription}  \u2022  '
                      '${event.lat.toStringAsFixed(4)}, '
                      '${event.lon.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      age,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isStale ? Colors.red : Colors.green).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isStale ? 'STALE' : 'ACTIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isStale ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  LatLng _calculateCenter(List<TakEvent> events) {
    final validEvents = events
        .where((e) => e.lat != 0.0 || e.lon != 0.0)
        .toList();
    if (validEvents.isEmpty) {
      return LatLng(MapConfig.defaultLat, MapConfig.defaultLon);
    }
    final avgLat =
        validEvents.map((e) => e.lat).reduce((a, b) => a + b) /
        validEvents.length;
    final avgLon =
        validEvents.map((e) => e.lon).reduce((a, b) => a + b) /
        validEvents.length;
    return LatLng(avgLat, avgLon);
  }

  void _fitAllEntities(List<TakEvent> events) {
    final validEvents = events
        .where((e) => e.lat != 0.0 || e.lon != 0.0)
        .toList();
    if (validEvents.isEmpty) return;

    if (validEvents.length == 1) {
      _animatedMove(LatLng(validEvents.first.lat, validEvents.first.lon), 14);
      return;
    }

    final lats = validEvents.map((e) => e.lat);
    final lons = validEvents.map((e) => e.lon);
    final bounds = LatLngBounds(
      LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lons.reduce((a, b) => a < b ? a : b),
      ),
      LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lons.reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
    HapticFeedback.selectionClick();
  }

  void _animatedMove(LatLng dest, double zoom, {double? rotation}) {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final startPos = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final startRotation = _mapController.camera.rotation;
    final endRotation = rotation ?? startRotation;

    final latTween = Tween(begin: startPos.latitude, end: dest.latitude);
    final lngTween = Tween(begin: startPos.longitude, end: dest.longitude);
    final zoomTween = Tween(begin: startZoom, end: zoom);
    final rotTween = Tween(begin: startRotation, end: endRotation);

    final curved = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _animationController!.addListener(() {
      _mapController.moveAndRotate(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
        rotTween.evaluate(curved),
      );
    });

    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentZoom = zoom;
          if (rotation != null) _mapRotation = rotation;
        });
      }
    });

    _animationController!.forward();
  }

  static String _formatAge(int receivedUtcMs) {
    final age = DateTime.now().millisecondsSinceEpoch - receivedUtcMs;
    if (age < 60000) return '${(age / 1000).round()}s ago';
    if (age < 3600000) return '${(age / 60000).round()}m ago';
    return '${(age / 3600000).round()}h ago';
  }
}
