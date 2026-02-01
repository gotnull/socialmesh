// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore protocol message parsing.
//
// Pure functions for parsing MeshCore response payloads into structured data.
// These functions do NOT handle framing or transport - they only parse payloads
// that have already been extracted from MeshCoreFrame.
//
// Reference: meshcore-open implementation

import 'dart:typed_data';

import 'meshcore_frame.dart';

/// Parsed SELF_INFO response data.
///
/// Contains device identification information returned by the selfInfo response.
/// Fields may be null if the payload was too short to contain them.
class MeshCoreSelfInfo {
  /// Advertisement type (e.g., chat, repeater).
  final int advType;

  /// TX power in dBm.
  final int txPowerDbm;

  /// Maximum LoRa TX power.
  final int maxLoraTxPower;

  /// Device public key (32 bytes).
  final Uint8List pubKey;

  /// Device latitude (raw int32, needs conversion).
  final int? latitude;

  /// Device longitude (raw int32, needs conversion).
  final int? longitude;

  /// Spreading factor.
  final int? spreadingFactor;

  /// Coding rate.
  final int? codingRate;

  /// Node name (may be empty).
  final String nodeName;

  /// Raw payload for access to any fields not parsed.
  final Uint8List rawPayload;

  const MeshCoreSelfInfo({
    required this.advType,
    required this.txPowerDbm,
    required this.maxLoraTxPower,
    required this.pubKey,
    this.latitude,
    this.longitude,
    this.spreadingFactor,
    this.codingRate,
    required this.nodeName,
    required this.rawPayload,
  });

  @override
  String toString() =>
      'MeshCoreSelfInfo(name=$nodeName, advType=$advType, txPower=$txPowerDbm)';
}

/// Parsed BATT_AND_STORAGE response data.
///
/// Contains battery and storage information from the device.
class MeshCoreBattAndStorage {
  /// Battery voltage in millivolts.
  final int batteryMillivolts;

  /// Storage used (units depend on device).
  final int storageUsed;

  /// Storage total (units depend on device).
  final int storageTotal;

  /// Raw payload for access to any fields not parsed.
  final Uint8List rawPayload;

  const MeshCoreBattAndStorage({
    required this.batteryMillivolts,
    required this.storageUsed,
    required this.storageTotal,
    required this.rawPayload,
  });

  /// Battery percentage estimate (0-100), or null if cannot be determined.
  ///
  /// Based on typical LiPo voltage range: 3.0V (empty) to 4.2V (full).
  int? get batteryPercentEstimate {
    if (batteryMillivolts < 3000) return 0;
    if (batteryMillivolts > 4200) return 100;
    return ((batteryMillivolts - 3000) * 100 / 1200).round();
  }

  /// Storage percentage used (0-100), or null if total is zero.
  int? get storagePercentUsed {
    if (storageTotal == 0) return null;
    return (storageUsed * 100 / storageTotal).round();
  }

  @override
  String toString() =>
      'MeshCoreBattAndStorage(batt=${batteryMillivolts}mV, '
      'storage=$storageUsed/$storageTotal)';
}

/// Result of parsing a MeshCore message.
///
/// Contains either a successfully parsed message or an error description.
class ParseResult<T> {
  final T? value;
  final String? error;

  const ParseResult.success(T this.value) : error = null;
  const ParseResult.failure(String this.error) : value = null;

  bool get isSuccess => value != null;
  bool get isFailure => error != null;
}

/// Parse a SELF_INFO response payload.
///
/// SELF_INFO format (payload, after command byte):
/// ```
/// [0] = ADV_TYPE
/// [1] = tx_power_dbm
/// [2] = MAX_LORA_TX_POWER
/// [3-34] = pub_key (32 bytes)
/// [35-38] = lat (int32 LE)
/// [39-42] = lon (int32 LE)
/// [43] = multi_acks
/// [44] = advert_loc_policy
/// [45] = telemetry_modes
/// [46] = manual_add_contacts
/// [47-50] = freq (uint32 LE)
/// [51-54] = bw (uint32 LE)
/// [55] = sf
/// [56] = cr
/// [57+] = node_name (null-terminated, up to 32 chars)
/// ```
///
/// Returns parsed info or error if payload is malformed.
ParseResult<MeshCoreSelfInfo> parseSelfInfo(Uint8List payload) {
  // Minimum required: ADV_TYPE + tx_power + MAX_LORA_TX_POWER + pub_key = 35 bytes
  const minLength = 3 + meshCorePubKeySize;

  if (payload.length < minLength) {
    return ParseResult.failure(
      'Self info payload too short: ${payload.length} < $minLength',
    );
  }

  final reader = MeshCoreBufferReader(payload);

  // Required fields
  final advType = reader.readByte();
  final txPowerDbm = reader.readByte();
  final maxLoraTxPower = reader.readByte();
  final pubKey = reader.readBytes(meshCorePubKeySize);

  // Optional fields (may not be present in short payloads)
  int? lat;
  int? lon;
  int? sf;
  int? cr;
  String nodeName = '';

  // Try to read lat/lon (need 8 more bytes after pub_key)
  if (reader.remaining >= 8) {
    lat = reader.readInt32LE();
    lon = reader.readInt32LE();
  }

  // Skip to offset 55 for sf/cr (relative to start of payload)
  // Current position after lat/lon is 43, need to skip to 55 = skip 12
  if (payload.length > 56) {
    // Position reader at offset 55
    final sfOffset = 55;
    if (sfOffset < payload.length) {
      sf = payload[sfOffset];
    }
    if (sfOffset + 1 < payload.length) {
      cr = payload[sfOffset + 1];
    }
  }

  // Node name is at offset 57
  const nodeNameOffset = 57;
  if (payload.length > nodeNameOffset) {
    final nameReader = MeshCoreBufferReader(payload);
    nameReader.skip(nodeNameOffset);
    if (nameReader.hasRemaining) {
      nodeName = nameReader.readCString(meshCoreMaxNameSize);
    }
  }

  return ParseResult.success(
    MeshCoreSelfInfo(
      advType: advType,
      txPowerDbm: txPowerDbm,
      maxLoraTxPower: maxLoraTxPower,
      pubKey: pubKey,
      latitude: lat,
      longitude: lon,
      spreadingFactor: sf,
      codingRate: cr,
      nodeName: nodeName,
      rawPayload: payload,
    ),
  );
}

/// Parse a BATT_AND_STORAGE response payload.
///
/// BATT_AND_STORAGE format (payload, after command byte):
/// ```
/// [0-1] = battery_millivolts (uint16 LE)
/// [2-3] = storage_used (uint16 LE)
/// [4-5] = storage_total (uint16 LE)
/// ```
///
/// Returns parsed info or error if payload is malformed.
ParseResult<MeshCoreBattAndStorage> parseBattAndStorage(Uint8List payload) {
  // Minimum required: 6 bytes
  const minLength = 6;

  if (payload.length < minLength) {
    return ParseResult.failure(
      'Battery and storage payload too short: ${payload.length} < $minLength',
    );
  }

  final reader = MeshCoreBufferReader(payload);

  final batteryMillivolts = reader.readUint16LE();
  final storageUsed = reader.readUint16LE();
  final storageTotal = reader.readUint16LE();

  return ParseResult.success(
    MeshCoreBattAndStorage(
      batteryMillivolts: batteryMillivolts,
      storageUsed: storageUsed,
      storageTotal: storageTotal,
      rawPayload: payload,
    ),
  );
}
