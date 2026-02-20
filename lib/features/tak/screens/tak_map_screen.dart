// SPDX-License-Identifier: GPL-3.0-or-later
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
import '../../navigation/main_shell.dart';
import '../../../services/haptic_service.dart';
import '../models/tak_event.dart';
import '../providers/tak_filter_provider.dart';
import '../providers/tak_providers.dart';
import '../providers/tak_tracking_provider.dart';

import '../services/tak_gateway_client.dart';
import '../utils/cot_affiliation.dart';
import '../widgets/tak_map_layer.dart';
import '../widgets/tak_trail_layer.dart';
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

  bool _autoConnectDone = false;

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    AppLogging.tak('TakMapScreen initState');

    // Ensure the persistence notifier is alive
    ref.read(takPersistenceNotifierProvider);

    // Auto-connect on first build
    final client = ref.read(takGatewayClientProvider);
    if (client.state == TakConnectionState.disconnected) {
      AppLogging.tak('TakMapScreen: auto-connecting...');
      client.connect();
      _autoConnectDone = true;
    }
  }

  @override
  void dispose() {
    AppLogging.tak('TakMapScreen dispose');
    _animationController?.dispose();
    super.dispose();
  }

  void _toggleConnection() {
    final client = ref.read(takGatewayClientProvider);
    final connState =
        ref.read(takConnectionStateProvider).whenOrNull(data: (s) => s) ??
        client.state;
    if (connState == TakConnectionState.connected) {
      AppLogging.tak('TakMapScreen: user toggled disconnect');
      client.disconnect();
    } else {
      AppLogging.tak('TakMapScreen: user toggled connect');
      client.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(filteredTakEventsProvider);
    final trackedUids = ref.watch(takTrackedUidsProvider);
    final client = ref.read(takGatewayClientProvider);
    final connectionAsync = ref.watch(takConnectionStateProvider);
    final connectionState =
        connectionAsync.whenOrNull(data: (s) => s) ?? client.state;

    // Auto-connect if provider was rebuilt and client is fresh
    if (!_autoConnectDone &&
        connectionState == TakConnectionState.disconnected) {
      Future.microtask(() {
        if (!mounted) return;
        AppLogging.tak('TakMapScreen: deferred auto-connect after rebuild');
        client.connect();
      });
      _autoConnectDone = true;
    }

    // Determine initial center from events
    final center = _calculateCenter(events);

    // Check if this screen was pushed (can pop) or is a root drawer screen.
    final route = ModalRoute.of(context);
    final canPop = route != null ? !route.isFirst : Navigator.canPop(context);

    return GlassScaffold.body(
      title: 'TAK Map',
      leading: canPop ? const BackButton() : const HamburgerMenuButton(),
      actions: [
        // Connection toggle
        IconButton(
          icon: Icon(
            connectionState == TakConnectionState.connected
                ? Icons.link
                : Icons.link_off,
            color: connectionState == TakConnectionState.connected
                ? Colors.green
                : Colors.grey,
          ),
          onPressed: _toggleConnection,
          tooltip: connectionState == TakConnectionState.connected
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
          ? _buildEmptyState(context, connectionState)
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
                    // Trail polylines for tracked entities
                    FutureBuilder<Map<String, TakTrailData>>(
                      future: _buildTrailData(events, trackedUids),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return TakTrailLayer(trails: snapshot.data!);
                      },
                    ),
                    // TAK entity markers
                    TakMapLayer(
                      events: events,
                      trackedUids: trackedUids,
                      onMarkerTap: (event) {
                        AppLogging.tak(
                          'TAK Map entity selected: uid=${event.uid}, '
                          'callsign=${event.displayName}',
                        );
                        HapticFeedback.selectionClick();
                        setState(() => _selectedEntity = event);
                      },
                      onMarkerLongPress: (event) async {
                        final tracking = ref.read(takTrackingProvider.notifier);
                        final nowTracked = await tracking.toggle(event.uid);
                        if (!mounted) return;
                        ref.haptics.longPress();
                        AppLogging.tak(
                          'TAK Map entity ${nowTracked ? "tracked" : "untracked"}: '
                          'uid=${event.uid}, callsign=${event.displayName}',
                        );
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
                                ? '\u00A9 OpenTopoMap \u00A9 OSM'
                                : '\u00A9 OSM \u00A9 CARTO',
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
                _buildStatusBar(context, events, connectionState),
                // Selected entity card
                if (_selectedEntity != null)
                  _buildEntityCard(context, trackedUids),
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

  Widget _buildEmptyState(
    BuildContext context,
    TakConnectionState connectionState,
  ) {
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
            connectionState == TakConnectionState.connected
                ? 'Waiting for CoT entities...'
                : 'Not connected to TAK Gateway',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connectionState == TakConnectionState.connected
                ? 'Entities will appear as markers on the map'
                : 'Connect to the gateway to see TAK entities',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (connectionState != TakConnectionState.connected) ...[
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

  Widget _buildStatusBar(
    BuildContext context,
    List<TakEvent> events,
    TakConnectionState connectionState,
  ) {
    final staleCount = events.where((e) => e.isStale).length;
    final activeCount = events.length - staleCount;
    final stateColor = switch (connectionState) {
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
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
              '$activeCount active',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
            if (staleCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '• $staleCount stale',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textTertiary,
                ),
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

  Widget _buildEntityCard(BuildContext context, Set<String> trackedUids) {
    final event = _selectedEntity!;
    final theme = Theme.of(context);
    final isStale = event.isStale;
    final affiliation = parseAffiliation(event.type);
    final affiliationColor = affiliation.color;
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
            border: Border.all(color: affiliationColor.withValues(alpha: 0.3)),
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
              Opacity(
                opacity: isStale ? 0.4 : 1.0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: affiliationColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: affiliationColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.gps_fixed,
                    color: affiliationColor,
                    size: 24,
                  ),
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
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: affiliationColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: affiliationColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            affiliation.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: affiliationColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          age,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final tracking = ref.read(takTrackingProvider.notifier);
                      await tracking.toggle(event.uid);
                      if (!mounted) return;
                      ref.haptics.toggle();
                      setState(() {}); // Rebuild card
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: trackedUids.contains(event.uid)
                            ? affiliationColor.withValues(alpha: 0.15)
                            : theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: affiliationColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trackedUids.contains(event.uid)
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 12,
                            color: affiliationColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trackedUids.contains(event.uid)
                                ? 'Tracked'
                                : 'Track',
                            style: TextStyle(
                              fontSize: 11,
                              color: affiliationColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
  // Trail data
  // ---------------------------------------------------------------------------

  Future<Map<String, TakTrailData>> _buildTrailData(
    List<TakEvent> events,
    Set<String> trackedUids,
  ) async {
    if (trackedUids.isEmpty) return {};
    final db = ref.read(takDatabaseProvider);
    final trails = <String, TakTrailData>{};
    for (final uid in trackedUids) {
      final event = events.where((e) => e.uid == uid).firstOrNull;
      if (event == null) continue;
      final history = await db.getPositionHistory(uid, limit: 50);
      trails[uid] = TakTrailData.fromHistory(event, history);
    }
    return trails;
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
