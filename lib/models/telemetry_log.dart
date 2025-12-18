import 'package:uuid/uuid.dart';

/// Helper to sanitize double values for JSON encoding
/// NaN and Infinity cannot be encoded in JSON
double? _sanitizeDouble(double? value) {
  if (value == null) return null;
  if (value.isNaN || value.isInfinite) return null;
  return value;
}

/// Base class for telemetry log entries
abstract class TelemetryLogEntry {
  final String id;
  final int nodeNum;
  final DateTime timestamp;

  TelemetryLogEntry({String? id, required this.nodeNum, DateTime? timestamp})
    : id = id ?? const Uuid().v4(),
      timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson();
}

/// Device metrics log entry
class DeviceMetricsLog extends TelemetryLogEntry {
  final int? batteryLevel;
  final double? voltage;
  final double? channelUtilization;
  final double? airUtilTx;
  final int? uptimeSeconds;

  DeviceMetricsLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    this.batteryLevel,
    this.voltage,
    this.channelUtilization,
    this.airUtilTx,
    this.uptimeSeconds,
  });

  factory DeviceMetricsLog.fromJson(Map<String, dynamic> json) {
    return DeviceMetricsLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      batteryLevel: json['batteryLevel'] as int?,
      voltage: (json['voltage'] as num?)?.toDouble(),
      channelUtilization: (json['channelUtilization'] as num?)?.toDouble(),
      airUtilTx: (json['airUtilTx'] as num?)?.toDouble(),
      uptimeSeconds: json['uptimeSeconds'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'batteryLevel': batteryLevel,
    'voltage': _sanitizeDouble(voltage),
    'channelUtilization': _sanitizeDouble(channelUtilization),
    'airUtilTx': _sanitizeDouble(airUtilTx),
    'uptimeSeconds': uptimeSeconds,
  };
}

/// Environment metrics log entry
class EnvironmentMetricsLog extends TelemetryLogEntry {
  final double? temperature;
  final double? humidity;
  final double? relativeHumidity; // Alias for humidity
  final double? barometricPressure;
  final double? gasResistance;
  final int? iaq;
  final double? lux;
  final double? whiteLux;
  final double? uvLux;
  final int? windDirection;
  final double? windSpeed;
  final double? windGust;
  final double? rainfall;
  final double? rainfall1h;
  final double? rainfall24h;
  final int? soilMoisture;
  final double? soilTemperature;

  EnvironmentMetricsLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    this.temperature,
    double? humidity,
    double? relativeHumidity,
    this.barometricPressure,
    this.gasResistance,
    this.iaq,
    this.lux,
    this.whiteLux,
    this.uvLux,
    this.windDirection,
    this.windSpeed,
    this.windGust,
    double? rainfall,
    this.rainfall1h,
    this.rainfall24h,
    this.soilMoisture,
    this.soilTemperature,
  }) : humidity = humidity ?? relativeHumidity,
       relativeHumidity = relativeHumidity ?? humidity,
       rainfall = rainfall ?? rainfall1h;

  factory EnvironmentMetricsLog.fromJson(Map<String, dynamic> json) {
    return EnvironmentMetricsLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      relativeHumidity: (json['relativeHumidity'] as num?)?.toDouble(),
      barometricPressure: (json['barometricPressure'] as num?)?.toDouble(),
      gasResistance: (json['gasResistance'] as num?)?.toDouble(),
      iaq: json['iaq'] as int?,
      lux: (json['lux'] as num?)?.toDouble(),
      whiteLux: (json['whiteLux'] as num?)?.toDouble(),
      uvLux: (json['uvLux'] as num?)?.toDouble(),
      windDirection: json['windDirection'] as int?,
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
      windGust: (json['windGust'] as num?)?.toDouble(),
      rainfall: (json['rainfall'] as num?)?.toDouble(),
      rainfall1h: (json['rainfall1h'] as num?)?.toDouble(),
      rainfall24h: (json['rainfall24h'] as num?)?.toDouble(),
      soilMoisture: json['soilMoisture'] as int?,
      soilTemperature: (json['soilTemperature'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'temperature': _sanitizeDouble(temperature),
    'humidity': _sanitizeDouble(humidity),
    'barometricPressure': _sanitizeDouble(barometricPressure),
    'gasResistance': _sanitizeDouble(gasResistance),
    'iaq': iaq,
    'lux': _sanitizeDouble(lux),
    'whiteLux': _sanitizeDouble(whiteLux),
    'uvLux': _sanitizeDouble(uvLux),
    'windDirection': windDirection,
    'windSpeed': _sanitizeDouble(windSpeed),
    'windGust': _sanitizeDouble(windGust),
    'rainfall': _sanitizeDouble(rainfall),
    'rainfall1h': _sanitizeDouble(rainfall1h),
    'rainfall24h': _sanitizeDouble(rainfall24h),
    'soilMoisture': soilMoisture,
    'soilTemperature': _sanitizeDouble(soilTemperature),
  };
}

/// Power metrics log entry
class PowerMetricsLog extends TelemetryLogEntry {
  final double? ch1Voltage;
  final double? ch1Current;
  final double? ch2Voltage;
  final double? ch2Current;
  final double? ch3Voltage;
  final double? ch3Current;

  PowerMetricsLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    this.ch1Voltage,
    this.ch1Current,
    this.ch2Voltage,
    this.ch2Current,
    this.ch3Voltage,
    this.ch3Current,
  });

  factory PowerMetricsLog.fromJson(Map<String, dynamic> json) {
    return PowerMetricsLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      ch1Voltage: (json['ch1Voltage'] as num?)?.toDouble(),
      ch1Current: (json['ch1Current'] as num?)?.toDouble(),
      ch2Voltage: (json['ch2Voltage'] as num?)?.toDouble(),
      ch2Current: (json['ch2Current'] as num?)?.toDouble(),
      ch3Voltage: (json['ch3Voltage'] as num?)?.toDouble(),
      ch3Current: (json['ch3Current'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'ch1Voltage': _sanitizeDouble(ch1Voltage),
    'ch1Current': _sanitizeDouble(ch1Current),
    'ch2Voltage': _sanitizeDouble(ch2Voltage),
    'ch2Current': _sanitizeDouble(ch2Current),
    'ch3Voltage': _sanitizeDouble(ch3Voltage),
    'ch3Current': _sanitizeDouble(ch3Current),
  };
}

/// Air quality metrics log entry
class AirQualityMetricsLog extends TelemetryLogEntry {
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

  AirQualityMetricsLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
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

  factory AirQualityMetricsLog.fromJson(Map<String, dynamic> json) {
    return AirQualityMetricsLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      pm10Standard: json['pm10Standard'] as int?,
      pm25Standard: json['pm25Standard'] as int?,
      pm100Standard: json['pm100Standard'] as int?,
      pm10Environmental: json['pm10Environmental'] as int?,
      pm25Environmental: json['pm25Environmental'] as int?,
      pm100Environmental: json['pm100Environmental'] as int?,
      particles03um: json['particles03um'] as int?,
      particles05um: json['particles05um'] as int?,
      particles10um: json['particles10um'] as int?,
      particles25um: json['particles25um'] as int?,
      particles50um: json['particles50um'] as int?,
      particles100um: json['particles100um'] as int?,
      co2: json['co2'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'pm10Standard': pm10Standard,
    'pm25Standard': pm25Standard,
    'pm100Standard': pm100Standard,
    'pm10Environmental': pm10Environmental,
    'pm25Environmental': pm25Environmental,
    'pm100Environmental': pm100Environmental,
    'particles03um': particles03um,
    'particles05um': particles05um,
    'particles10um': particles10um,
    'particles25um': particles25um,
    'particles50um': particles50um,
    'particles100um': particles100um,
    'co2': co2,
  };
}

/// Position log entry
class PositionLog extends TelemetryLogEntry {
  final double latitude;
  final double longitude;
  final int? altitude;
  final int? satsInView;
  final int? speed;
  final int? heading;
  final int? precisionBits;

  PositionLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.satsInView,
    this.speed,
    this.heading,
    this.precisionBits,
  });

  factory PositionLog.fromJson(Map<String, dynamic> json) {
    return PositionLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] as int?,
      satsInView: json['satsInView'] as int?,
      speed: json['speed'] as int?,
      heading: json['heading'] as int?,
      precisionBits: json['precisionBits'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'latitude': _sanitizeDouble(latitude),
    'longitude': _sanitizeDouble(longitude),
    'altitude': altitude,
    'satsInView': satsInView,
    'speed': speed,
    'heading': heading,
    'precisionBits': precisionBits,
  };
}

/// Trace route log entry
class TraceRouteLog extends TelemetryLogEntry {
  final int targetNode;
  final bool sent;
  final bool response;
  final int hopsTowards;
  final int hopsBack;
  final List<TraceRouteHop> hops;
  final double? snr;

  TraceRouteLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    required this.targetNode,
    this.sent = true,
    this.response = false,
    this.hopsTowards = 0,
    this.hopsBack = 0,
    this.hops = const [],
    this.snr,
  });

  factory TraceRouteLog.fromJson(Map<String, dynamic> json) {
    return TraceRouteLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      targetNode: json['targetNode'] as int,
      sent: json['sent'] as bool? ?? true,
      response: json['response'] as bool? ?? false,
      hopsTowards: json['hopsTowards'] as int? ?? 0,
      hopsBack: json['hopsBack'] as int? ?? 0,
      hops:
          (json['hops'] as List?)
              ?.map((h) => TraceRouteHop.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      snr: (json['snr'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'targetNode': targetNode,
    'sent': sent,
    'response': response,
    'hopsTowards': hopsTowards,
    'hopsBack': hopsBack,
    'hops': hops.map((h) => h.toJson()).toList(),
    'snr': _sanitizeDouble(snr),
  };
}

/// Trace route hop
class TraceRouteHop {
  final int nodeNum;
  final String? name;
  final double? snr;
  final bool back;
  final double? latitude;
  final double? longitude;

  TraceRouteHop({
    required this.nodeNum,
    this.name,
    this.snr,
    this.back = false,
    this.latitude,
    this.longitude,
  });

  factory TraceRouteHop.fromJson(Map<String, dynamic> json) {
    return TraceRouteHop(
      nodeNum: json['nodeNum'] as int,
      name: json['name'] as String?,
      snr: (json['snr'] as num?)?.toDouble(),
      back: json['back'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeNum': nodeNum,
    'name': name,
    'snr': _sanitizeDouble(snr),
    'back': back,
    'latitude': _sanitizeDouble(latitude),
    'longitude': _sanitizeDouble(longitude),
  };
}

/// PAX counter log entry
class PaxCounterLog extends TelemetryLogEntry {
  final int wifi;
  final int ble;
  final int uptime;

  PaxCounterLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    required this.wifi,
    required this.ble,
    this.uptime = 0,
  });

  int get total => wifi + ble;

  factory PaxCounterLog.fromJson(Map<String, dynamic> json) {
    return PaxCounterLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      wifi: json['wifi'] as int,
      ble: json['ble'] as int,
      uptime: json['uptime'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'wifi': wifi,
    'ble': ble,
    'uptime': uptime,
  };
}

/// Detection sensor log entry
class DetectionSensorLog extends TelemetryLogEntry {
  final String name;
  final bool detected;
  final String? eventType;

  DetectionSensorLog({
    super.id,
    required super.nodeNum,
    super.timestamp,
    this.name = '',
    this.detected = false,
    this.eventType,
  });

  factory DetectionSensorLog.fromJson(Map<String, dynamic> json) {
    return DetectionSensorLog(
      id: json['id'] as String?,
      nodeNum: json['nodeNum'] as int,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      name: json['name'] as String? ?? json['sensorName'] as String? ?? '',
      detected: json['detected'] as bool? ?? false,
      eventType: json['eventType'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'nodeNum': nodeNum,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'name': name,
    'detected': detected,
    'eventType': eventType,
  };
}
