// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../models/telemetry_log.dart';
import '../models/route.dart';
import '../models/tapback.dart';
import '../services/storage/telemetry_database.dart';
import '../services/storage/traceroute_database.dart';
import '../services/storage/traceroute_repository.dart';
import '../services/storage/route_storage_service.dart';
import '../services/storage/tapback_storage_service.dart';
import '../services/protocol/protocol_service.dart';
import 'app_providers.dart';

// SharedPreferences instance for storage services
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

// Telemetry storage service (SQLite-backed)
final telemetryStorageProvider = FutureProvider<TelemetryDatabase>((ref) async {
  final db = TelemetryDatabase();
  await db.init();
  ref.onDispose(() => db.close());
  return db;
});

// Route storage service (SQLite-backed)
final routeStorageProvider = FutureProvider<RouteStorageService>((ref) async {
  final service = RouteStorageService();
  await service.init();
  // Auto-prune routes older than 365 days on startup
  await service.pruneExpiredRoutes();
  return service;
});

// Tapback storage service
final tapbackStorageProvider = FutureProvider<TapbackStorageService>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return TapbackStorageService(prefs);
});

// Traceroute repository (SQLite-backed, persists across restarts)
final tracerouteRepositoryProvider = FutureProvider<SqliteTracerouteRepository>(
  (ref) async {
    final db = TracerouteDatabase();
    await db.open();

    final repo = SqliteTracerouteRepository(db);

    // One-time migration from SharedPreferences legacy storage
    try {
      final legacy = await ref.read(telemetryStorageProvider.future);
      final migrated = await repo.migrateFromSharedPreferences(legacy);
      if (migrated > 0) {
        AppLogging.storage(
          'Traceroute migration complete: $migrated runs imported to SQLite',
        );
      }
    } catch (e) {
      AppLogging.storage('Traceroute migration failed (non-fatal): $e');
    }

    ref.onDispose(() => db.close());
    return repo;
  },
);

// ============ Telemetry Log Providers ============

/// All device metrics history
final deviceMetricsLogsProvider = FutureProvider<List<DeviceMetricsLog>>((
  ref,
) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllDeviceMetrics();
});

/// All environment metrics history
final environmentMetricsLogsProvider =
    FutureProvider<List<EnvironmentMetricsLog>>((ref) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getAllEnvironmentMetrics();
    });

/// All power metrics history
final powerMetricsLogsProvider = FutureProvider<List<PowerMetricsLog>>((
  ref,
) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllPowerMetrics();
});

/// All air quality metrics history
final airQualityMetricsLogsProvider =
    FutureProvider<List<AirQualityMetricsLog>>((ref) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getAllAirQualityMetrics();
    });

/// All position history
final positionLogsProvider = FutureProvider<List<PositionLog>>((ref) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllPositionLogs();
});

/// All traceroute history (SQLite-backed, persists across restarts)
final traceRouteLogsProvider = FutureProvider<List<TraceRouteLog>>((ref) async {
  final repo = await ref.watch(tracerouteRepositoryProvider.future);
  return repo.listRuns();
});

/// All PAX counter history
final paxCounterLogsProvider = FutureProvider<List<PaxCounterLog>>((ref) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllPaxCounterLogs();
});

/// All detection sensor history
final detectionSensorLogsProvider = FutureProvider<List<DetectionSensorLog>>((
  ref,
) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllDetectionSensorLogs();
});

/// Device metrics for a specific node
final nodeDeviceMetricsLogsProvider =
    FutureProvider.family<List<DeviceMetricsLog>, int>((ref, nodeNum) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getDeviceMetrics(nodeNum);
    });

/// Environment metrics for a specific node
final nodeEnvironmentMetricsLogsProvider =
    FutureProvider.family<List<EnvironmentMetricsLog>, int>((
      ref,
      nodeNum,
    ) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getEnvironmentMetrics(nodeNum);
    });

/// Power metrics for a specific node
final nodePowerMetricsLogsProvider =
    FutureProvider.family<List<PowerMetricsLog>, int>((ref, nodeNum) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getPowerMetrics(nodeNum);
    });

/// Air quality metrics for a specific node
final nodeAirQualityMetricsLogsProvider =
    FutureProvider.family<List<AirQualityMetricsLog>, int>((
      ref,
      nodeNum,
    ) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getAirQualityMetrics(nodeNum);
    });

/// Position logs for a specific node
final nodePositionLogsProvider = FutureProvider.family<List<PositionLog>, int>((
  ref,
  nodeNum,
) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getPositionLogs(nodeNum);
});

/// Traceroute logs for a specific node (SQLite-backed)
final nodeTraceRouteLogsProvider =
    FutureProvider.family<List<TraceRouteLog>, int>((ref, nodeNum) async {
      final repo = await ref.watch(tracerouteRepositoryProvider.future);
      return repo.listRuns(targetNodeId: nodeNum);
    });

/// PAX counter logs for a specific node
final nodePaxCounterLogsProvider =
    FutureProvider.family<List<PaxCounterLog>, int>((ref, nodeNum) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getPaxCounterLogs(nodeNum);
    });

/// Detection sensor logs for a specific node
final nodeDetectionSensorLogsProvider =
    FutureProvider.family<List<DetectionSensorLog>, int>((ref, nodeNum) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getDetectionSensorLogs(nodeNum);
    });

// ============ Route Providers ============

/// All saved routes
class RoutesNotifier extends Notifier<List<Route>> {
  @override
  List<Route> build() {
    final storageAsync = ref.watch(routeStorageProvider);
    final storage = storageAsync.value;
    if (storage != null) {
      _loadRoutes(storage);
    }
    return [];
  }

  RouteStorageService? get _storage => ref.read(routeStorageProvider).value;

  Future<void> _loadRoutes(RouteStorageService storage) async {
    final routes = await storage.getRoutes();
    // Sort by createdAt descending (newest first)
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = routes;
  }

  Future<void> saveRoute(Route route) async {
    if (_storage == null) return;
    await _storage!.saveRoute(route);
    final routes = await _storage!.getRoutes();
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = routes;
  }

  Future<void> deleteRoute(String routeId) async {
    if (_storage == null) return;
    await _storage!.deleteRoute(routeId);
    final routes = await _storage!.getRoutes();
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = routes;
  }

  Future<void> refresh() async {
    if (_storage == null) return;
    final routes = await _storage!.getRoutes();
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = routes;
  }
}

final routesProvider = NotifierProvider<RoutesNotifier, List<Route>>(
  RoutesNotifier.new,
);

/// Active route being recorded
class ActiveRouteNotifier extends Notifier<Route?> {
  StreamSubscription? _positionSubscription;

  @override
  Route? build() {
    ref.onDispose(() {
      _stopLocationTracking();
    });
    _init();
    return null;
  }

  RouteStorageService? get _storage => ref.read(routeStorageProvider).value;
  ProtocolService get _protocol => ref.read(protocolServiceProvider);

  Future<void> _init() async {
    if (_storage == null) return;
    state = await _storage!.getActiveRoute();
    if (state != null) {
      _startLocationTracking();
    }
  }

  Future<void> startRecording(String name, {String? notes, int? color}) async {
    if (_storage == null) return;
    final route = Route(name: name, notes: notes, color: color ?? 0xFF33C758);
    await _storage!.setActiveRoute(route);
    state = route;
    _startLocationTracking();
  }

  Future<Route?> stopRecording() async {
    if (_storage == null || state == null) return null;

    _stopLocationTracking();

    final completedRoute = state!.copyWith(endedAt: DateTime.now());

    // Save to permanent storage
    await _storage!.saveRoute(completedRoute);
    await _storage!.setActiveRoute(null);

    final result = state;
    state = null;
    return result;
  }

  void cancelRecording() async {
    if (_storage == null) return;
    _stopLocationTracking();
    await _storage!.setActiveRoute(null);
    state = null;
  }

  void _startLocationTracking() {
    AppLogging.debug('🛤️ Route: Starting location tracking');
    // Cancel any existing subscription first
    _positionSubscription?.cancel();
    // Listen to position updates from nodes (including phone GPS positions)
    _positionSubscription = _protocol.nodeStream.listen((node) async {
      if (state == null) {
        AppLogging.debug('🛤️ Route: No active route, skipping');
        return;
      }
      if (!node.hasPosition) {
        AppLogging.debug(
          '🛤️ Route: Node ${node.nodeNum} has no position, skipping',
        );
        return;
      }

      // Track position updates from our own node
      final myNodeNum = _protocol.myNodeNum;
      AppLogging.debug(
        '🛤️ Route: Got position from node ${node.nodeNum}, myNodeNum=$myNodeNum',
      );

      // Skip if this isn't our node (but allow if myNodeNum is null during setup)
      if (myNodeNum != null && node.nodeNum != myNodeNum) {
        AppLogging.debug('🛤️ Route: Skipping - not our node');
        return;
      }

      final newLat = node.latitude!;
      final newLon = node.longitude!;
      AppLogging.debug(
        '🛤️ Route: New position: $newLat, $newLon (precision=${node.precisionBits})',
      );

      // Filter out GPS jumps and low precision positions
      if (state!.locations.isNotEmpty) {
        final lastLoc = state!.locations.last;
        final timeDiff = DateTime.now().difference(lastLoc.timestamp).inSeconds;

        final distance = _calculateDistance(
          lastLoc.latitude,
          lastLoc.longitude,
          newLat,
          newLon,
        );

        // Skip duplicate positions (same lat/lon as last point)
        if (lastLoc.latitude == newLat && lastLoc.longitude == newLon) {
          AppLogging.debug('🛤️ Route: Skipping - duplicate position');
          return;
        }

        // Skip if distance is unreasonably large (> 500m) - likely precision truncation
        // Position precision bits can cause coordinates to jump by kilometers
        if (distance > 500) {
          AppLogging.debug(
            '🛤️ Route: Skipping - distance too large (${distance.toStringAsFixed(0)}m > 500m limit)',
          );
          return;
        }

        // Only check speed if we have meaningful time difference (at least 1 second)
        if (timeDiff >= 1) {
          final speed = distance / timeDiff; // meters per second
          AppLogging.debug(
            '🛤️ Route: Distance=${distance.toStringAsFixed(1)}m, timeDiff=${timeDiff}s, speed=${speed.toStringAsFixed(1)}m/s',
          );

          // Skip if speed > 50 m/s (180 km/h) - likely GPS error
          if (speed > 50) {
            AppLogging.debug(
              '🛤️ Route: Skipping - GPS jump detected (speed too high)',
            );
            return;
          }
        }
      } else {
        // First point - log it
        AppLogging.debug('🛤️ Route: Recording first point');
      }

      final location = RouteLocation(
        latitude: newLat,
        longitude: newLon,
        altitude: node.altitude,
        heading: node.groundTrack?.toInt(),
        speed: node.groundSpeed?.toInt(),
      );

      AppLogging.debug(
        '🛤️ Route: Adding location point #${state!.locations.length + 1}',
      );
      if (_storage != null) {
        final updated = await _storage!.addLocationToActiveRoute(location);
        if (updated != null) {
          state = updated;
          AppLogging.debug(
            '🛤️ Route: Now have ${state!.locations.length} points',
          );
        }
      }
    });
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Haversine distance calculation using dart:math
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

final activeRouteProvider = NotifierProvider<ActiveRouteNotifier, Route?>(
  ActiveRouteNotifier.new,
);

// ============ Tapback Providers ============

/// Get tapbacks for a specific message
final messageTapbacksProvider =
    FutureProvider.family<List<MessageTapback>, String>((ref, messageId) async {
      final storage = await ref.watch(tapbackStorageProvider.future);
      return storage.getTapbacksForMessage(messageId);
    });

/// Tapback actions notifier
class TapbackActionsNotifier extends Notifier<void> {
  @override
  void build() {
    return;
  }

  TapbackStorageService? get _storage => ref.read(tapbackStorageProvider).value;
  ProtocolService get _protocol => ref.read(protocolServiceProvider);

  /// Add a tapback reaction to a message
  Future<void> addTapback({
    required String messageId,
    required int fromNodeNum,
    required TapbackType type,
    int? toNodeNum,
  }) async {
    if (_storage == null) return;

    final tapback = MessageTapback(
      messageId: messageId,
      fromNodeNum: fromNodeNum,
      emoji: type.emoji,
    );
    await _storage!.addTapback(tapback);

    // Send tapback as emoji message to the original sender
    if (toNodeNum != null) {
      try {
        await _protocol.sendMessage(
          text: type.emoji,
          to: toNodeNum,
          wantAck: true,
          source: MessageSource.tapback,
        );
        AppLogging.liveActivity(
          'Sent tapback ${type.emoji} to node $toNodeNum',
        );
      } catch (e) {
        AppLogging.liveActivity('Failed to send tapback: $e');
      }
    }
  }

  /// Remove a tapback reaction
  Future<void> removeTapback({
    required String messageId,
    required int fromNodeNum,
  }) async {
    if (_storage == null) return;
    await _storage!.removeTapback(messageId, fromNodeNum);
  }
}

final tapbackActionsProvider = NotifierProvider<TapbackActionsNotifier, void>(
  TapbackActionsNotifier.new,
);

// ============ Telemetry Auto-Logging ============

/// Fingerprint of the last logged device metrics for a given node.
/// Used to suppress duplicate writes when the node stream re-emits
/// unchanged values (e.g. position updates, lastHeard bumps).
class _DeviceMetricsFingerprint {
  final int? batteryLevel;
  final double? voltage;
  final double? channelUtilization;
  final double? airUtilTx;
  final int? uptimeSeconds;

  const _DeviceMetricsFingerprint({
    this.batteryLevel,
    this.voltage,
    this.channelUtilization,
    this.airUtilTx,
    this.uptimeSeconds,
  });

  bool matches(MeshNode node) =>
      batteryLevel == node.batteryLevel &&
      voltage == node.voltage &&
      channelUtilization == node.channelUtilization &&
      airUtilTx == node.airUtilTx &&
      uptimeSeconds == node.uptimeSeconds;
}

/// Fingerprint of the last logged environment metrics for a given node.
class _EnvMetricsFingerprint {
  final double? temperature;
  final double? humidity;
  final double? barometricPressure;
  final double? gasResistance;
  final int? iaq;
  final double? lux;
  final double? whiteLux;
  final double? uvLux;
  final int? windDirection;
  final double? windSpeed;
  final double? windGust;
  final double? rainfall1h;
  final double? rainfall24h;
  final int? soilMoisture;
  final double? soilTemperature;

  const _EnvMetricsFingerprint({
    this.temperature,
    this.humidity,
    this.barometricPressure,
    this.gasResistance,
    this.iaq,
    this.lux,
    this.whiteLux,
    this.uvLux,
    this.windDirection,
    this.windSpeed,
    this.windGust,
    this.rainfall1h,
    this.rainfall24h,
    this.soilMoisture,
    this.soilTemperature,
  });

  bool matches(MeshNode node) =>
      temperature == node.temperature &&
      humidity == node.humidity &&
      barometricPressure == node.barometricPressure &&
      gasResistance == node.gasResistance &&
      iaq == node.iaq &&
      lux == node.lux &&
      whiteLux == node.whiteLux &&
      uvLux == node.uvLux &&
      windDirection == node.windDirection &&
      windSpeed == node.windSpeed &&
      windGust == node.windGust &&
      rainfall1h == node.rainfall1h &&
      rainfall24h == node.rainfall24h &&
      soilMoisture == node.soilMoisture &&
      soilTemperature == node.soilTemperature;
}

/// Fingerprint of the last logged power metrics for a given node.
class _PowerMetricsFingerprint {
  final double? ch1Voltage;
  final double? ch1Current;
  final double? ch2Voltage;
  final double? ch2Current;
  final double? ch3Voltage;
  final double? ch3Current;

  const _PowerMetricsFingerprint({
    this.ch1Voltage,
    this.ch1Current,
    this.ch2Voltage,
    this.ch2Current,
    this.ch3Voltage,
    this.ch3Current,
  });

  bool matches(MeshNode node) =>
      ch1Voltage == node.ch1Voltage &&
      ch1Current == node.ch1Current &&
      ch2Voltage == node.ch2Voltage &&
      ch2Current == node.ch2Current &&
      ch3Voltage == node.ch3Voltage &&
      ch3Current == node.ch3Current;
}

/// Fingerprint of the last logged air quality metrics for a given node.
class _AirQualityFingerprint {
  final int? pm10Standard;
  final int? pm25Standard;
  final int? pm100Standard;
  final int? pm10Environmental;
  final int? pm25Environmental;
  final int? pm100Environmental;
  final int? particles03um;
  final int? particles05um;
  final int? particles10um;
  final int? particles25um;
  final int? particles50um;
  final int? particles100um;
  final int? co2;

  const _AirQualityFingerprint({
    this.pm10Standard,
    this.pm25Standard,
    this.pm100Standard,
    this.pm10Environmental,
    this.pm25Environmental,
    this.pm100Environmental,
    this.particles03um,
    this.particles05um,
    this.particles10um,
    this.particles25um,
    this.particles50um,
    this.particles100um,
    this.co2,
  });

  bool matches(MeshNode node) =>
      pm10Standard == node.pm10Standard &&
      pm25Standard == node.pm25Standard &&
      pm100Standard == node.pm100Standard &&
      pm10Environmental == node.pm10Environmental &&
      pm25Environmental == node.pm25Environmental &&
      pm100Environmental == node.pm100Environmental &&
      particles03um == node.particles03um &&
      particles05um == node.particles05um &&
      particles10um == node.particles10um &&
      particles25um == node.particles25um &&
      particles50um == node.particles50um &&
      particles100um == node.particles100um &&
      co2 == node.co2;
}

/// Fingerprint of the last logged position for a given node.
class _PositionFingerprint {
  final double latitude;
  final double longitude;
  final int? altitude;
  final int? satsInView;

  const _PositionFingerprint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.satsInView,
  });

  bool matches(MeshNode node) =>
      latitude == node.latitude &&
      longitude == node.longitude &&
      altitude == node.altitude &&
      satsInView == node.satsInView;
}

/// Telemetry logger that automatically saves telemetry to storage when received.
///
/// The protocol service emits node updates on every change (position,
/// lastHeard, name, telemetry, etc.). Without deduplication each emission
/// would create a new database row even when the metric values are
/// identical. The per-node fingerprint caches below suppress duplicate
/// writes by comparing incoming values against the last logged values.
class TelemetryLoggerNotifier extends Notifier<bool> {
  StreamSubscription? _nodeSubscription;
  StreamSubscription? _traceRouteSubscription;

  /// Per-node caches of the last logged metric values. Keyed by nodeNum.
  final _lastDevice = <int, _DeviceMetricsFingerprint>{};
  final _lastEnv = <int, _EnvMetricsFingerprint>{};
  final _lastPower = <int, _PowerMetricsFingerprint>{};
  final _lastAirQuality = <int, _AirQualityFingerprint>{};
  final _lastPosition = <int, _PositionFingerprint>{};

  @override
  bool build() {
    ref.onDispose(() {
      _nodeSubscription?.cancel();
      _traceRouteSubscription?.cancel();
    });
    final storageAsync = ref.watch(telemetryStorageProvider);
    final storage = storageAsync.value;
    if (storage != null) {
      _startLogging(storage);
      return true;
    }
    return false;
  }

  ProtocolService get _protocol => ref.read(protocolServiceProvider);

  void _startLogging(TelemetryDatabase storage) {
    // Cancel any existing subscriptions first
    _nodeSubscription?.cancel();
    _traceRouteSubscription?.cancel();

    // Listen to traceroute events and persist them to SQLite.
    // Outbound requests arrive with response == false (placeholder).
    // Inbound responses arrive with response == true and replace the placeholder.
    _traceRouteSubscription = _protocol.traceRouteLogStream.listen((log) async {
      try {
        final repo = await ref.read(tracerouteRepositoryProvider.future);
        if (log.response) {
          await repo.replaceOrAddRun(log);
        } else {
          await repo.saveRun(log);
        }
      } catch (e) {
        AppLogging.storage('TelemetryLogger: Traceroute DB write failed: $e');
      }
      ref.invalidate(traceRouteLogsProvider);
      ref.invalidate(nodeTraceRouteLogsProvider(log.nodeNum));
    });

    // Listen to node updates and log telemetry.
    // The node stream fires for ANY node mutation (position, name,
    // lastHeard, telemetry, etc.). To avoid writing duplicate rows when
    // the actual metric values have not changed, each metric type keeps
    // a per-node fingerprint of the last logged values.
    _nodeSubscription = _protocol.nodeStream.listen((node) async {
      final id = node.nodeNum;

      // Log device metrics only when values actually change
      if (node.batteryLevel != null || node.voltage != null) {
        final cached = _lastDevice[id];
        if (cached == null || !cached.matches(node)) {
          _lastDevice[id] = _DeviceMetricsFingerprint(
            batteryLevel: node.batteryLevel,
            voltage: node.voltage,
            channelUtilization: node.channelUtilization,
            airUtilTx: node.airUtilTx,
            uptimeSeconds: node.uptimeSeconds,
          );
          await storage.addDeviceMetrics(
            DeviceMetricsLog(
              nodeNum: id,
              batteryLevel: node.batteryLevel,
              voltage: node.voltage,
              channelUtilization: node.channelUtilization,
              airUtilTx: node.airUtilTx,
              uptimeSeconds: node.uptimeSeconds,
            ),
          );
        }
      }

      // Log environment metrics only when values actually change
      if (node.temperature != null || node.humidity != null) {
        final cached = _lastEnv[id];
        if (cached == null || !cached.matches(node)) {
          _lastEnv[id] = _EnvMetricsFingerprint(
            temperature: node.temperature,
            humidity: node.humidity,
            barometricPressure: node.barometricPressure,
            gasResistance: node.gasResistance,
            iaq: node.iaq,
            lux: node.lux,
            whiteLux: node.whiteLux,
            uvLux: node.uvLux,
            windDirection: node.windDirection,
            windSpeed: node.windSpeed,
            windGust: node.windGust,
            rainfall1h: node.rainfall1h,
            rainfall24h: node.rainfall24h,
            soilMoisture: node.soilMoisture,
            soilTemperature: node.soilTemperature,
          );
          await storage.addEnvironmentMetrics(
            EnvironmentMetricsLog(
              nodeNum: id,
              temperature: node.temperature,
              humidity: node.humidity,
              barometricPressure: node.barometricPressure,
              gasResistance: node.gasResistance,
              iaq: node.iaq,
              lux: node.lux,
              whiteLux: node.whiteLux,
              uvLux: node.uvLux,
              windDirection: node.windDirection,
              windSpeed: node.windSpeed,
              windGust: node.windGust,
              rainfall1h: node.rainfall1h,
              rainfall24h: node.rainfall24h,
              soilMoisture: node.soilMoisture,
              soilTemperature: node.soilTemperature,
            ),
          );
        }
      }

      // Log power metrics only when values actually change
      if (node.ch1Voltage != null ||
          node.ch2Voltage != null ||
          node.ch3Voltage != null) {
        final cached = _lastPower[id];
        if (cached == null || !cached.matches(node)) {
          _lastPower[id] = _PowerMetricsFingerprint(
            ch1Voltage: node.ch1Voltage,
            ch1Current: node.ch1Current,
            ch2Voltage: node.ch2Voltage,
            ch2Current: node.ch2Current,
            ch3Voltage: node.ch3Voltage,
            ch3Current: node.ch3Current,
          );
          await storage.addPowerMetrics(
            PowerMetricsLog(
              nodeNum: id,
              ch1Voltage: node.ch1Voltage,
              ch1Current: node.ch1Current,
              ch2Voltage: node.ch2Voltage,
              ch2Current: node.ch2Current,
              ch3Voltage: node.ch3Voltage,
              ch3Current: node.ch3Current,
            ),
          );
        }
      }

      // Log air quality only when values actually change
      if (node.pm10Standard != null ||
          node.pm25Standard != null ||
          node.co2 != null) {
        final cached = _lastAirQuality[id];
        if (cached == null || !cached.matches(node)) {
          _lastAirQuality[id] = _AirQualityFingerprint(
            pm10Standard: node.pm10Standard,
            pm25Standard: node.pm25Standard,
            pm100Standard: node.pm100Standard,
            pm10Environmental: node.pm10Environmental,
            pm25Environmental: node.pm25Environmental,
            pm100Environmental: node.pm100Environmental,
            particles03um: node.particles03um,
            particles05um: node.particles05um,
            particles10um: node.particles10um,
            particles25um: node.particles25um,
            particles50um: node.particles50um,
            particles100um: node.particles100um,
            co2: node.co2,
          );
          await storage.addAirQualityMetrics(
            AirQualityMetricsLog(
              nodeNum: id,
              pm10Standard: node.pm10Standard,
              pm25Standard: node.pm25Standard,
              pm100Standard: node.pm100Standard,
              pm10Environmental: node.pm10Environmental,
              pm25Environmental: node.pm25Environmental,
              pm100Environmental: node.pm100Environmental,
              particles03um: node.particles03um,
              particles05um: node.particles05um,
              particles10um: node.particles10um,
              particles25um: node.particles25um,
              particles50um: node.particles50um,
              particles100um: node.particles100um,
              co2: node.co2,
            ),
          );
        }
      }

      // Log position only when values actually change
      if (node.hasPosition) {
        final cached = _lastPosition[id];
        if (cached == null || !cached.matches(node)) {
          _lastPosition[id] = _PositionFingerprint(
            latitude: node.latitude!,
            longitude: node.longitude!,
            altitude: node.altitude,
            satsInView: node.satsInView,
          );
          await storage.addPositionLog(
            PositionLog(
              nodeNum: id,
              latitude: node.latitude!,
              longitude: node.longitude!,
              altitude: node.altitude,
              satsInView: node.satsInView,
            ),
          );
        }
      }
    });
  }
}

final telemetryLoggerProvider = NotifierProvider<TelemetryLoggerNotifier, bool>(
  TelemetryLoggerNotifier.new,
);
