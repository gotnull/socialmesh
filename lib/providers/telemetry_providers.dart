import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../models/telemetry_log.dart';
import '../models/route.dart';
import '../models/tapback.dart';
import '../services/storage/telemetry_storage_service.dart';
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

// Telemetry storage service
final telemetryStorageProvider = FutureProvider<TelemetryStorageService>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return TelemetryStorageService(prefs);
});

// Route storage service
final routeStorageProvider = FutureProvider<RouteStorageService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return RouteStorageService(prefs);
});

// Tapback storage service
final tapbackStorageProvider = FutureProvider<TapbackStorageService>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return TapbackStorageService(prefs);
});

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

/// All traceroute history
final traceRouteLogsProvider = FutureProvider<List<TraceRouteLog>>((ref) async {
  final storage = await ref.watch(telemetryStorageProvider.future);
  return storage.getAllTraceRouteLogs();
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

/// TraceRoute logs for a specific node
final nodeTraceRouteLogsProvider =
    FutureProvider.family<List<TraceRouteLog>, int>((ref, nodeNum) async {
      final storage = await ref.watch(telemetryStorageProvider.future);
      return storage.getTraceRouteLogs(nodeNum);
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

/// Grouped tapbacks by type for a message (for display)
final groupedTapbacksProvider =
    FutureProvider.family<Map<TapbackType, List<int>>, String>((
      ref,
      messageId,
    ) async {
      final storage = await ref.watch(tapbackStorageProvider.future);
      return storage.getGroupedTapbacks(messageId);
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
      type: type,
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

/// Telemetry logger that automatically saves telemetry to storage when received
class TelemetryLoggerNotifier extends Notifier<bool> {
  StreamSubscription? _nodeSubscription;

  @override
  bool build() {
    ref.onDispose(() {
      _nodeSubscription?.cancel();
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

  void _startLogging(TelemetryStorageService storage) {
    // Cancel any existing subscription first
    _nodeSubscription?.cancel();
    // Listen to node updates and log telemetry
    _nodeSubscription = _protocol.nodeStream.listen((node) async {
      // Log device metrics if present
      if (node.batteryLevel != null || node.voltage != null) {
        await storage.addDeviceMetrics(
          DeviceMetricsLog(
            nodeNum: node.nodeNum,
            batteryLevel: node.batteryLevel,
            voltage: node.voltage,
            channelUtilization: node.channelUtilization,
            airUtilTx: node.airUtilTx,
            uptimeSeconds: node.uptimeSeconds,
          ),
        );
      }

      // Log environment metrics if present
      if (node.temperature != null || node.humidity != null) {
        await storage.addEnvironmentMetrics(
          EnvironmentMetricsLog(
            nodeNum: node.nodeNum,
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

      // Log power metrics if present
      if (node.ch1Voltage != null ||
          node.ch2Voltage != null ||
          node.ch3Voltage != null) {
        await storage.addPowerMetrics(
          PowerMetricsLog(
            nodeNum: node.nodeNum,
            ch1Voltage: node.ch1Voltage,
            ch1Current: node.ch1Current,
            ch2Voltage: node.ch2Voltage,
            ch2Current: node.ch2Current,
            ch3Voltage: node.ch3Voltage,
            ch3Current: node.ch3Current,
          ),
        );
      }

      // Log air quality if present
      if (node.pm10Standard != null ||
          node.pm25Standard != null ||
          node.co2 != null) {
        await storage.addAirQualityMetrics(
          AirQualityMetricsLog(
            nodeNum: node.nodeNum,
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

      // Log position if present
      if (node.hasPosition) {
        await storage.addPositionLog(
          PositionLog(
            nodeNum: node.nodeNum,
            latitude: node.latitude!,
            longitude: node.longitude!,
            altitude: node.altitude,
            satsInView: node.satsInView,
          ),
        );
      }
    });
  }
}

final telemetryLoggerProvider = NotifierProvider<TelemetryLoggerNotifier, bool>(
  TelemetryLoggerNotifier.new,
);
