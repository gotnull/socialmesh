import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
class RoutesNotifier extends StateNotifier<List<Route>> {
  final RouteStorageService? _storage;

  RoutesNotifier(this._storage) : super([]) {
    if (_storage != null) {
      _loadRoutes();
    }
  }

  Future<void> _loadRoutes() async {
    if (_storage == null) return;
    state = await _storage.getRoutes();
  }

  Future<void> saveRoute(Route route) async {
    if (_storage == null) return;
    await _storage.saveRoute(route);
    state = await _storage.getRoutes();
  }

  Future<void> deleteRoute(String routeId) async {
    if (_storage == null) return;
    await _storage.deleteRoute(routeId);
    state = await _storage.getRoutes();
  }

  Future<void> refresh() async {
    if (_storage == null) return;
    state = await _storage.getRoutes();
  }
}

final routesProvider = StateNotifierProvider<RoutesNotifier, List<Route>>((
  ref,
) {
  final storageAsync = ref.watch(routeStorageProvider);
  final storage = storageAsync.valueOrNull;
  return RoutesNotifier(storage);
});

/// Active route being recorded
class ActiveRouteNotifier extends StateNotifier<Route?> {
  final RouteStorageService? _storage;
  final ProtocolService _protocol;
  StreamSubscription? _positionSubscription;

  ActiveRouteNotifier(this._storage, this._protocol) : super(null) {
    _init();
  }

  Future<void> _init() async {
    if (_storage == null) return;
    state = await _storage.getActiveRoute();
    if (state != null) {
      _startLocationTracking();
    }
  }

  Future<void> startRecording(String name, {String? notes, int? color}) async {
    if (_storage == null) return;
    final route = Route(name: name, notes: notes, color: color ?? 0xFF33C758);
    await _storage.setActiveRoute(route);
    state = route;
    _startLocationTracking();
  }

  Future<Route?> stopRecording() async {
    if (_storage == null || state == null) return null;

    _stopLocationTracking();

    final completedRoute = state!.copyWith(endedAt: DateTime.now());

    // Save to permanent storage
    await _storage.saveRoute(completedRoute);
    await _storage.setActiveRoute(null);

    final result = state;
    state = null;
    return result;
  }

  void cancelRecording() async {
    if (_storage == null) return;
    _stopLocationTracking();
    await _storage.setActiveRoute(null);
    state = null;
  }

  void _startLocationTracking() {
    // Listen to position updates from nodes (including phone GPS positions)
    _positionSubscription = _protocol.nodeStream.listen((node) async {
      if (state == null || !node.hasPosition) return;

      // Check if this is a position update for any tracked node
      // For route recording, we typically track the local device's position
      final myNodeNum = _protocol.myNodeNum;
      if (node.nodeNum != myNodeNum) return;

      final newLat = node.latitude!;
      final newLon = node.longitude!;

      // Filter out GPS jumps - if distance from last point is too far for the time elapsed
      // Max realistic speed: ~150 km/h = ~42 m/s
      if (state!.locations.isNotEmpty) {
        final lastLoc = state!.locations.last;
        final timeDiff = DateTime.now().difference(lastLoc.timestamp).inSeconds;
        if (timeDiff > 0) {
          final distance = _calculateDistance(
            lastLoc.latitude,
            lastLoc.longitude,
            newLat,
            newLon,
          );
          final speed = distance / timeDiff; // meters per second
          // Skip if speed > 50 m/s (180 km/h) - likely GPS error
          if (speed > 50) {
            return;
          }
        }
      }

      final location = RouteLocation(
        latitude: newLat,
        longitude: newLon,
        altitude: node.altitude,
        heading: null, // Could be added if available
        speed: null, // Could be added if available
      );

      if (_storage != null) {
        final updated = await _storage.addLocationToActiveRoute(location);
        if (updated != null) {
          state = updated;
        }
      }
    });
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Haversine distance calculation
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1 * 3.141592653589793 / 180) *
            _cos(lat2 * 3.141592653589793 / 180) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return r * c;
  }

  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 10; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (y > 0) return 1.5707963267948966;
    if (y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atan(double x) {
    if (x.abs() > 1)
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    double r = 0, t = x;
    for (int n = 0; n < 10; n++) {
      r += t / (2 * n + 1);
      t *= -x * x;
    }
    return r;
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }
}

final activeRouteProvider = StateNotifierProvider<ActiveRouteNotifier, Route?>((
  ref,
) {
  final storageAsync = ref.watch(routeStorageProvider);
  final protocol = ref.watch(protocolServiceProvider);
  final storage = storageAsync.valueOrNull;
  return ActiveRouteNotifier(storage, protocol);
});

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
class TapbackActionsNotifier extends StateNotifier<void> {
  final TapbackStorageService? _storage;
  final ProtocolService _protocol;

  TapbackActionsNotifier(this._storage, this._protocol) : super(null);

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
    await _storage.addTapback(tapback);

    // Send tapback as emoji message to the original sender
    if (toNodeNum != null) {
      try {
        await _protocol.sendMessage(
          text: type.emoji,
          to: toNodeNum,
          wantAck: true,
        );
        debugPrint('📱 Sent tapback ${type.emoji} to node $toNodeNum');
      } catch (e) {
        debugPrint('📱 Failed to send tapback: $e');
      }
    }
  }

  /// Remove a tapback reaction
  Future<void> removeTapback({
    required String messageId,
    required int fromNodeNum,
  }) async {
    if (_storage == null) return;
    await _storage.removeTapback(messageId, fromNodeNum);
  }
}

final tapbackActionsProvider =
    StateNotifierProvider<TapbackActionsNotifier, void>((ref) {
      final storageAsync = ref.watch(tapbackStorageProvider);
      final protocol = ref.watch(protocolServiceProvider);
      final storage = storageAsync.valueOrNull;
      return TapbackActionsNotifier(storage, protocol);
    });

// ============ Telemetry Auto-Logging ============

/// Telemetry logger that automatically saves telemetry to storage when received
class TelemetryLoggerNotifier extends StateNotifier<bool> {
  final TelemetryStorageService? _storage;
  final ProtocolService _protocol;
  StreamSubscription? _nodeSubscription;

  TelemetryLoggerNotifier(this._storage, this._protocol) : super(false) {
    if (_storage != null) {
      _startLogging();
    }
  }

  void _startLogging() {
    state = true;

    // Listen to node updates and log telemetry
    _nodeSubscription = _protocol.nodeStream.listen((node) async {
      if (_storage == null) return;

      // Log device metrics if present
      if (node.batteryLevel != null || node.voltage != null) {
        await _storage.addDeviceMetrics(
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
        await _storage.addEnvironmentMetrics(
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
        await _storage.addPowerMetrics(
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
        await _storage.addAirQualityMetrics(
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
        await _storage.addPositionLog(
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

  @override
  void dispose() {
    _nodeSubscription?.cancel();
    super.dispose();
  }
}

final telemetryLoggerProvider =
    StateNotifierProvider<TelemetryLoggerNotifier, bool>((ref) {
      final storageAsync = ref.watch(telemetryStorageProvider);
      final protocol = ref.watch(protocolServiceProvider);
      final storage = storageAsync.valueOrNull;
      return TelemetryLoggerNotifier(storage, protocol);
    });
