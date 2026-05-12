// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: Cayenne LPP (Low Power Payload) parser for MeshCore peer
// telemetry responses.
//
// The MeshCore firmware uses a small subset of the Cayenne LPP TLV
// format for telemetry. Each reading is a triple
//   [channel:u8][type:u8][value:N B]
// where the byte count N is determined by the type. Multiple readings
// arrive concatenated in a single response payload (TELEM_CHANNEL_SELF
// for the primary device, dynamically-allocated channels for
// auxiliary sensors).
//
// D41-A supports five types - all that current firmware variants
// actually emit (`src/helpers/CayenneLPP.h`):
//
//   | Type | Name              | Bytes | Encoding                       |
//   |------|-------------------|-------|--------------------------------|
//   | 103  | Temperature       | 2     | signed int16 BE, 0.1 °C / LSB  |
//   | 104  | Relative humidity | 1     | unsigned u8, 0.5 % / LSB       |
//   | 115  | Barometric press. | 2     | unsigned u16 BE, 0.1 hPa / LSB |
//   | 116  | Voltage           | 2     | unsigned u16 BE, 0.01 V / LSB  |
//   | 136  | GPS               | 9     | 3x signed 24-bit BE:           |
//   |      |                   |       |   lat 1e-4 °, lon 1e-4 °,      |
//   |      |                   |       |   altitude 1e-2 m              |
//
// Unknown but known-size types are skipped via a static size table so
// the parser can still surface valid readings beyond the unknown one.
// Truncated payloads stop cleanly without throwing - never crash the
// caller because the wire was odd.
//
// Privacy:
//   - Reading toString() omits raw byte content.
//   - No path into the parser logs raw payload bytes; the session
//     helper handles redacted logging at the call boundary.

import 'dart:typed_data';

/// One decoded reading. Discriminate via `is` checks at the call site.
sealed class MeshCoreTelemetryReading {
  /// Cayenne LPP channel byte. `TELEM_CHANNEL_SELF == 1` per firmware
  /// (`src/helpers/SensorManager.h:10`); larger values indicate
  /// secondary sensor clusters.
  final int channel;

  const MeshCoreTelemetryReading(this.channel);
}

class MeshCoreTelemetryVoltage extends MeshCoreTelemetryReading {
  /// Volts. Source: Cayenne LPP type 116, u16 BE, 0.01 V/LSB.
  final double volts;
  const MeshCoreTelemetryVoltage(super.channel, this.volts);

  @override
  String toString() => 'MeshCoreTelemetryVoltage(ch=$channel)';
}

class MeshCoreTelemetryTemperature extends MeshCoreTelemetryReading {
  /// Degrees Celsius. Source: Cayenne LPP type 103, signed i16 BE,
  /// 0.1 °C/LSB.
  final double celsius;
  const MeshCoreTelemetryTemperature(super.channel, this.celsius);

  @override
  String toString() => 'MeshCoreTelemetryTemperature(ch=$channel)';
}

class MeshCoreTelemetryHumidity extends MeshCoreTelemetryReading {
  /// Relative humidity in percent. Source: Cayenne LPP type 104,
  /// u8, 0.5 %/LSB (range 0..127.5).
  final double percent;
  const MeshCoreTelemetryHumidity(super.channel, this.percent);

  @override
  String toString() => 'MeshCoreTelemetryHumidity(ch=$channel)';
}

class MeshCoreTelemetryPressure extends MeshCoreTelemetryReading {
  /// Atmospheric pressure in hectopascals. Source: Cayenne LPP type
  /// 115, u16 BE, 0.1 hPa/LSB.
  final double hPa;
  const MeshCoreTelemetryPressure(super.channel, this.hPa);

  @override
  String toString() => 'MeshCoreTelemetryPressure(ch=$channel)';
}

class MeshCoreTelemetryGps extends MeshCoreTelemetryReading {
  /// Latitude in degrees. Source: Cayenne LPP type 136 first 24-bit
  /// signed value, 1e-4 °/LSB.
  final double latitude;

  /// Longitude in degrees. Cayenne LPP type 136 second 24-bit signed
  /// value, 1e-4 °/LSB.
  final double longitude;

  /// Altitude in metres. Cayenne LPP type 136 third 24-bit signed
  /// value, 0.01 m/LSB.
  final double altitudeMetres;

  const MeshCoreTelemetryGps(
    super.channel,
    this.latitude,
    this.longitude,
    this.altitudeMetres,
  );

  @override
  String toString() => 'MeshCoreTelemetryGps(ch=$channel)';
}

/// A decoded telemetry response. `readings` is in wire order. Group
/// by `channel` in the UI to surface "Device" (channel 1) vs
/// `Aux <N>` sections.
class MeshCoreTelemetryResponse {
  /// All decoded readings, in the order the wire delivered them.
  final List<MeshCoreTelemetryReading> readings;

  /// Map of unknown Cayenne LPP type byte → count of times encountered.
  /// Surfaced for diagnostics only; never rendered in the UI.
  final Map<int, int> unknownTypes;

  /// Local clock time the parse completed. The wire does not carry a
  /// timestamp; this is set by the caller (provider) and may differ
  /// from when the firmware sampled.
  final DateTime fetchedAt;

  const MeshCoreTelemetryResponse({
    required this.readings,
    required this.unknownTypes,
    required this.fetchedAt,
  });

  /// True iff the wire delivered no readings AND no unknown bytes
  /// after a clean parse. Distinguished from a parse-error null
  /// return by the caller.
  bool get isEmpty => readings.isEmpty && unknownTypes.isEmpty;

  @override
  String toString() =>
      'MeshCoreTelemetryResponse('
      'readings=${readings.length}, '
      'unknown=${unknownTypes.length})';
}

/// Cayenne LPP type byte constants. Subset emitted by current
/// MeshCore firmware variants.
class MeshCoreLppType {
  MeshCoreLppType._();

  static const int temperature = 103; // 0x67
  static const int humidity = 104; // 0x68
  static const int pressure = 115; // 0x73
  static const int voltage = 116; // 0x74
  static const int gps = 136; // 0x88
}

/// Static type → byte-size table for unknown-but-known-size skip
/// recovery. Numbers from the Cayenne LPP spec; not every supported
/// type is wire-emitted by MeshCore firmware today, but knowing the
/// size lets the parser jump past one rather than abandon the rest
/// of the frame. Truly unknown types (not in this table) stop the
/// parse cleanly.
const Map<int, int> _lppKnownSizes = <int, int>{
  0: 1, // Digital Input
  1: 1, // Digital Output
  2: 2, // Analog Input
  3: 2, // Analog Output
  101: 2, // Illuminance
  102: 1, // Presence
  103: 2, // Temperature (supported)
  104: 1, // Humidity (supported)
  113: 6, // Accelerometer
  115: 2, // Barometric pressure (supported)
  116: 2, // Voltage (supported)
  117: 2, // Current
  118: 4, // Frequency
  120: 1, // Percentage
  121: 2, // Altitude
  125: 4, // Power
  128: 4, // Energy
  130: 2, // Direction
  133: 4, // Unix Time
  134: 6, // Gyrometer
  135: 6, // Color
  136: 9, // GPS (supported)
  142: 1, // Switch
};

/// Parse a Cayenne LPP TLV stream. Returns a non-null
/// `MeshCoreTelemetryResponse` for any payload that doesn't crash
/// the walker (zero readings is valid, truncation stops cleanly,
/// unknown but known-size types are skipped, unknown un-sized types
/// stop the parse but don't drop earlier readings).
///
/// Returns `null` only when [bytes] itself is empty AND
/// [allowEmptyInput] is false — most callers want the same response
/// shape regardless and pass an empty buffer through. The session
/// helper accepts an empty wire as "the contact has nothing to
/// share" rather than a parse error.
MeshCoreTelemetryResponse parseCayenneLpp(
  Uint8List bytes, {
  required DateTime fetchedAt,
}) {
  final readings = <MeshCoreTelemetryReading>[];
  final unknown = <int, int>{};
  final view = ByteData.sublistView(bytes);

  int i = 0;
  while (i < bytes.length) {
    // Need at least channel + type byte.
    if (i + 1 >= bytes.length) break;
    final channel = bytes[i];
    final type = bytes[i + 1];
    final headerEnd = i + 2;

    switch (type) {
      case MeshCoreLppType.voltage:
        if (headerEnd + 2 > bytes.length) {
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        final raw = view.getUint16(headerEnd, Endian.big);
        readings.add(MeshCoreTelemetryVoltage(channel, raw / 100.0));
        i = headerEnd + 2;

      case MeshCoreLppType.temperature:
        if (headerEnd + 2 > bytes.length) {
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        final raw = view.getInt16(headerEnd, Endian.big);
        readings.add(MeshCoreTelemetryTemperature(channel, raw / 10.0));
        i = headerEnd + 2;

      case MeshCoreLppType.humidity:
        if (headerEnd + 1 > bytes.length) {
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        final raw = bytes[headerEnd];
        readings.add(MeshCoreTelemetryHumidity(channel, raw / 2.0));
        i = headerEnd + 1;

      case MeshCoreLppType.pressure:
        if (headerEnd + 2 > bytes.length) {
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        final raw = view.getUint16(headerEnd, Endian.big);
        readings.add(MeshCoreTelemetryPressure(channel, raw / 10.0));
        i = headerEnd + 2;

      case MeshCoreLppType.gps:
        if (headerEnd + 9 > bytes.length) {
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        final lat = _read24bitSigned(bytes, headerEnd);
        final lon = _read24bitSigned(bytes, headerEnd + 3);
        final alt = _read24bitSigned(bytes, headerEnd + 6);
        readings.add(
          MeshCoreTelemetryGps(
            channel,
            lat / 10000.0,
            lon / 10000.0,
            alt / 100.0,
          ),
        );
        i = headerEnd + 9;

      default:
        // Unknown supported-size types: skip cleanly. Truly unknown
        // types stop the parse but keep what we have.
        final size = _lppKnownSizes[type];
        if (size == null) {
          unknown[type] = (unknown[type] ?? 0) + 1;
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        if (headerEnd + size > bytes.length) {
          // Truncated unknown-but-sized type: stop.
          return MeshCoreTelemetryResponse(
            readings: readings,
            unknownTypes: unknown,
            fetchedAt: fetchedAt,
          );
        }
        unknown[type] = (unknown[type] ?? 0) + 1;
        i = headerEnd + size;
    }
  }

  return MeshCoreTelemetryResponse(
    readings: readings,
    unknownTypes: unknown,
    fetchedAt: fetchedAt,
  );
}

/// Read a 24-bit big-endian SIGNED integer from [bytes] starting at
/// [offset]. Sign-extends the top bit to a Dart signed int.
int _read24bitSigned(Uint8List bytes, int offset) {
  final raw =
      (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
  // Bit 23 set -> value is negative. Translate by subtracting 2^24.
  // (A bitwise OR-mask like `raw | 0xFF000000` doesn't work because
  // Dart's int is signed and OR-ing the high bits produces a large
  // positive value, not a negative one.)
  if ((raw & 0x800000) != 0) {
    return raw - 0x1000000;
  }
  return raw;
}
