// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore protocol message parsing.
//
// Pure functions for parsing MeshCore response payloads into structured data.
// These functions do NOT handle framing or transport - they only parse payloads
// that have already been extracted from MeshCoreFrame.

import 'dart:typed_data';

import '../../../utils/text_sanitizer.dart';
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

  /// LoRa carrier frequency in kHz, as the firmware reports it. Sourced
  /// from `_prefs.freq` (companion-radio firmware ships this in SELF_INFO
  /// at offsets 47..50 once the payload is long enough). Null on legacy /
  /// truncated payloads where the field is absent. D16: this field used
  /// to be silently dropped by `parseSelfInfo`, which is why the radio
  /// settings sheet had to invent its own client-side cache (D11). The
  /// firmware was always sending it.
  final int? freqKhz;

  /// LoRa bandwidth in Hz, mirroring [freqKhz]. SELF_INFO offsets 51..54.
  final int? bandwidthHz;

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
    this.freqKhz,
    this.bandwidthHz,
    this.spreadingFactor,
    this.codingRate,
    required this.nodeName,
    required this.rawPayload,
  });

  @override
  String toString() =>
      'MeshCoreSelfInfo(name=$nodeName, advType=$advType, '
      'freqKhz=$freqKhz, bw=$bandwidthHz, sf=$spreadingFactor, '
      'cr=$codingRate, txPower=$txPowerDbm)';
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

/// D28 Part C: one hop in a parsed `PUSH_CODE_TRACE_DATA` (0x89) response.
class MeshCoreTraceHop {
  /// Single-byte hop identifier (typically the first byte of the
  /// repeater pubkey or a hop opcode). The companion firmware emits
  /// these bytes one per hop in the same order they appear in the
  /// response payload.
  final int pathByte;

  /// Raw firmware SNR encoding (signed int8, scaled by 4). Convert
  /// with `snrDb = snrQuarter / 4.0`.
  final int snrQuarter;

  const MeshCoreTraceHop({required this.pathByte, required this.snrQuarter});

  /// SNR in dB, derived from the firmware quarter encoding.
  double get snrDb => snrQuarter / 4.0;

  @override
  String toString() =>
      'MeshCoreTraceHop(pathByte=0x${pathByte.toRadixString(16).padLeft(2, '0')}, '
      'snr=${snrDb.toStringAsFixed(2)}dB)';
}

/// D28 Part C: parsed `PUSH_CODE_TRACE_DATA` (0x89) payload.
///
/// Wire format (after the 0x89 opcode byte is consumed by the framer):
/// ```
/// [0]      reserved                       u8
/// [1]      path_length                    u8
/// [2]      flag                           u8
/// [3..6]   tag                            u32 LE  (matches request tag)
/// [7..10]  auth_code                      u32 LE
/// [11..]   path_data (path_length bytes)
/// [11+pl..] snr_array  (path_length bytes, signed int8 ÷ 4 → dB)
/// ```
///
/// Receivers MUST verify that [tag] matches the tag they sent in
/// `CMD_SEND_TRACE_PATH (0x24)` before treating the result as the
/// response to their request — multiple traces can race.
class MeshCoreTraceResult {
  /// Correlation tag from the original request.
  final int tag;

  /// Firmware-supplied flag byte (typically zero).
  final int flag;

  /// Auth code echoed back from the request.
  final int authCode;

  /// Hops in the order they appear in the firmware payload.
  final List<MeshCoreTraceHop> hops;

  const MeshCoreTraceResult({
    required this.tag,
    required this.flag,
    required this.authCode,
    required this.hops,
  });

  @override
  String toString() => 'MeshCoreTraceResult(tag=$tag, hops=${hops.length})';
}

/// D28 Part C: parse a `PUSH_CODE_TRACE_DATA` (0x89) frame payload.
///
/// Pass the payload AFTER the framer has stripped the opcode byte; the
/// reserved byte at offset 0 is part of the wire payload here.
ParseResult<MeshCoreTraceResult> parseTraceData(Uint8List payload) {
  // Header is 11 bytes (1 reserved + 1 pathLen + 1 flag + 4 tag + 4 auth).
  if (payload.length < 11) {
    return ParseResult.failure(
      'Trace data payload too short: ${payload.length} < 11',
    );
  }
  final pathLen = payload[1];
  final flag = payload[2];
  final tag =
      payload[3] | (payload[4] << 8) | (payload[5] << 16) | (payload[6] << 24);
  final authCode =
      payload[7] | (payload[8] << 8) | (payload[9] << 16) | (payload[10] << 24);
  // Variable section: pathLen bytes of path data + pathLen bytes of SNR.
  final required = 11 + (pathLen * 2);
  if (payload.length < required) {
    return ParseResult.failure(
      'Trace data payload truncated: '
      'have=${payload.length} need=$required (pathLen=$pathLen)',
    );
  }
  final hops = <MeshCoreTraceHop>[];
  for (var i = 0; i < pathLen; i++) {
    final pathByte = payload[11 + i];
    final raw = payload[11 + pathLen + i];
    // Convert unsigned byte to signed int8.
    final snrQuarter = raw < 128 ? raw : raw - 256;
    hops.add(MeshCoreTraceHop(pathByte: pathByte, snrQuarter: snrQuarter));
  }
  return ParseResult.success(
    MeshCoreTraceResult(tag: tag, flag: flag, authCode: authCode, hops: hops),
  );
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
  int? freqKhz;
  int? bandwidthHz;
  int? sf;
  int? cr;
  String nodeName = '';

  // Try to read lat/lon (need 8 more bytes after pub_key)
  if (reader.remaining >= 8) {
    lat = reader.readInt32LE();
    lon = reader.readInt32LE();
  }

  // SELF_INFO layout (companion-radio firmware):
  //   0       RESP_CODE_SELF_INFO consumed by caller
  //   0       advType                 [u8]
  //   1       tx_power_dbm            [i8]
  //   2       MAX_LORA_TX_POWER       [u8]
  //   3..34   pub_key                 [32]
  //   35..38  latitude  (signed *1e6) [i32 LE]
  //   39..42  longitude (signed *1e6) [i32 LE]
  //   43      multi_acks (v7+)        [u8]
  //   44      advert_loc_policy       [u8]
  //   45      telemetry_mode (packed) [u8]
  //   46      manual_add_contacts     [u8]
  //   47..50  freq (kHz)              [u32 LE]   <-- D16 read-back
  //   51..54  bw   (Hz)               [u32 LE]   <-- D16 read-back
  //   55      sf                      [u8]
  //   56      cr                      [u8]
  //   57..N   node_name (UTF-8, no trailing null)
  //
  // Pre-D16 the parser only extracted sf+cr and silently dropped freq+bw,
  // which forced the radio settings sheet to keep its own SharedPreferences
  // cache (D11). Now both fields are read directly from the firmware.
  const freqOffset = 47;
  const bwOffset = 51;
  const sfOffset = 55;
  const crOffset = 56;

  if (payload.length >= freqOffset + 4) {
    freqKhz =
        payload[freqOffset] |
        (payload[freqOffset + 1] << 8) |
        (payload[freqOffset + 2] << 16) |
        (payload[freqOffset + 3] << 24);
  }
  if (payload.length >= bwOffset + 4) {
    bandwidthHz =
        payload[bwOffset] |
        (payload[bwOffset + 1] << 8) |
        (payload[bwOffset + 2] << 16) |
        (payload[bwOffset + 3] << 24);
  }
  if (payload.length > sfOffset) {
    sf = payload[sfOffset];
  }
  if (payload.length > crOffset) {
    cr = payload[crOffset];
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
      freqKhz: freqKhz,
      bandwidthHz: bandwidthHz,
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

// ---------------------------------------------------------------------------
// Contact Parsing
// ---------------------------------------------------------------------------

/// Parsed contact entry from CONTACT response.
class MeshCoreContactInfo {
  /// Public key (32 bytes).
  final Uint8List publicKey;

  /// Advertisement type (chat, repeater, room, sensor).
  final int advType;

  /// Path length: -1 = flood, 0+ = direct hops.
  final int pathLength;

  /// Last modification timestamp.
  final int lastMod;

  /// Latitude (raw int32, divide by 1e7 for degrees in this model;
  /// the firmware actually encodes degrees * 1e6, so the
  /// `latitudeDegrees` getter under-reports by 10x. D24.B does not
  /// touch this scale to avoid widening scope into the map UI;
  /// the next slice that owns coordinate display should fold the
  /// `1e6` correction into both this getter and any cached
  /// SharedPreferences entries.
  final int? latitude;

  /// Longitude (raw int32, divide by 1e7 for degrees — see scale
  /// caveat above on [latitude]).
  final int? longitude;

  /// Contact name.
  final String name;

  /// Path bytes (length = pathLength if pathLength > 0).
  final Uint8List pathBytes;

  /// Raw payload for debugging.
  final Uint8List rawPayload;

  const MeshCoreContactInfo({
    required this.publicKey,
    required this.advType,
    required this.pathLength,
    required this.lastMod,
    this.latitude,
    this.longitude,
    required this.name,
    required this.pathBytes,
    required this.rawPayload,
  });

  /// Public key as hex string.
  String get publicKeyHex =>
      publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Latitude in degrees (or null).
  double? get latitudeDegrees => latitude != null ? latitude! / 1e7 : null;

  /// Longitude in degrees (or null).
  double? get longitudeDegrees => longitude != null ? longitude! / 1e7 : null;

  @override
  String toString() =>
      'MeshCoreContactInfo(name=$name, type=$advType, path=$pathLength)';
}

/// Parse a CONTACT response payload (`RESP_CODE_CONTACT` / 0x03)
/// or a NEW-ADVERT push payload (`PUSH_CODE_NEW_ADVERT` / 0x8A).
/// Both share the firmware's contact-response layout. The byte map
/// below is the protocol contract; tests pin the offsets so a
/// future refactor cannot silently change the encoding.
///
/// Wire layout (after the leading code byte has been stripped by
/// the codec, so offset 0 is the first byte of [payload]):
///
/// ```
/// [0..31]    = pub_key            (32 bytes)
/// [32]       = adv_type           (uint8)
/// [33]       = flags              (uint8)
/// [34]       = path_len           (int8: 0xFF = flood, else hop count)
/// [35..98]   = path               (64 bytes, valid prefix = path_len)
/// [99..130]  = name               (32 bytes, null-padded ASCII)
/// [131..134] = last_advert_ts     (uint32 LE, seconds since epoch)
/// [135..138] = gps_lat            (int32 LE, degrees * 1e6)
/// [139..142] = gps_lon            (int32 LE, degrees * 1e6)
/// [143..146] = lastmod            (uint32 LE)
/// ```
///
/// D24.B: pre-D24 the parser read a phantom `pubkey + adv_type +
/// path_len + lastmod(uint16) + lat + lon + name` layout that did
/// not match the firmware. The bug surfaced as every nameless-
/// looking contact: the parser landed on `out_path[9..]` for the
/// "name" field, and a zero byte at that offset (typical when
/// path is empty) terminated the C-string at length zero. The
/// firmware actually stored a real name; we just never read it.
/// Restored here against the firmware's actual layout.
ParseResult<MeshCoreContactInfo> parseContact(Uint8List payload) {
  // Pre-D24 the minimum was 36 bytes; the corrected fixed layout
  // ends at offset 147 (lastmod), so anything shorter than the
  // path-end (98) is unparseable. Older firmware versions that
  // truncate optional trailing fields are tolerated below by
  // making lat/lon/lastmod optional after the 131-byte name end.
  const minLength =
      32 /*pub*/ +
      1 /*type*/ +
      1 /*flags*/ +
      1 /*plen*/ +
      meshCoreMaxPathSize +
      meshCoreMaxNameSize +
      4 /*last_advert_ts*/;

  if (payload.length < minLength) {
    return ParseResult.failure(
      'Contact payload too short: ${payload.length} < $minLength',
    );
  }

  final reader = MeshCoreBufferReader(payload);

  // Required fields
  final pubKey = reader.readBytes(meshCorePubKeySize);
  final advType = reader.readByte();
  reader.readByte(); // flags — currently unused by the app surface
  final pathLenUnsigned = reader.readByte();
  // 0xFF (255) is the firmware's sentinel for "flood / no direct
  // path"; map to -1 to preserve the historical
  // `MeshCoreContactInfo.pathLength` contract (signed: -1 = flood).
  final pathLen = pathLenUnsigned == 0xFF
      ? -1
      : (pathLenUnsigned > meshCoreMaxPathSize
            ? meshCoreMaxPathSize
            : pathLenUnsigned);

  // Read the full 64-byte path slot, slice to the valid prefix.
  final pathSlot = reader.readBytes(meshCoreMaxPathSize);
  final pathBytes = pathLen > 0 ? pathSlot.sublist(0, pathLen) : Uint8List(0);

  // 32-byte null-padded name. `readCString` treats the first
  // `\0` as terminator and sanitizes lone surrogates.
  final name = reader.readCString(meshCoreMaxNameSize);

  // Mandatory `last_advert_timestamp`.
  final lastAdvertTs = reader.readUint32LE();

  // Optional gps_lat / gps_lon / lastmod (12 bytes total).
  int? lat;
  int? lon;
  int lastMod = lastAdvertTs;
  if (reader.remaining >= 12) {
    final latRaw = reader.readInt32LE();
    final lonRaw = reader.readInt32LE();
    final lastModRaw = reader.readUint32LE();
    if (latRaw != 0 || lonRaw != 0) {
      lat = latRaw;
      lon = lonRaw;
    }
    if (lastModRaw != 0) {
      lastMod = lastModRaw;
    }
  } else if (reader.remaining >= 8) {
    // Legacy firmware: gps fields without lastmod tail.
    final latRaw = reader.readInt32LE();
    final lonRaw = reader.readInt32LE();
    if (latRaw != 0 || lonRaw != 0) {
      lat = latRaw;
      lon = lonRaw;
    }
  }

  return ParseResult.success(
    MeshCoreContactInfo(
      publicKey: pubKey,
      advType: advType,
      pathLength: pathLen,
      lastMod: lastMod,
      latitude: lat,
      longitude: lon,
      name: name,
      pathBytes: pathBytes,
      rawPayload: payload,
    ),
  );
}

// ---------------------------------------------------------------------------
// Channel Parsing
// ---------------------------------------------------------------------------

/// Parsed channel info from CHANNEL_INFO response.
class MeshCoreChannelInfo {
  /// Channel index (0-based).
  final int index;

  /// Channel name.
  final String name;

  /// Pre-shared key (16 bytes).
  final Uint8List psk;

  /// Raw payload for debugging.
  final Uint8List rawPayload;

  const MeshCoreChannelInfo({
    required this.index,
    required this.name,
    required this.psk,
    required this.rawPayload,
  });

  /// PSK as hex string.
  String get pskHex =>
      psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Whether this channel is empty/unconfigured.
  bool get isEmpty => name.isEmpty && psk.every((b) => b == 0);

  @override
  String toString() => 'MeshCoreChannelInfo($index: $name)';
}

/// Parse a CHANNEL_INFO response payload.
///
/// CHANNEL_INFO format:
/// ```
/// [0] = channel_idx
/// [1-32] = name (32 bytes, null-terminated)
/// [33-48] = psk (16 bytes)
/// ```
ParseResult<MeshCoreChannelInfo> parseChannelInfo(Uint8List payload) {
  // Need: idx(1) + name(32) + psk(16) = 49 bytes
  const minLength = 49;

  if (payload.length < minLength) {
    return ParseResult.failure(
      'Channel info payload too short: ${payload.length} < $minLength',
    );
  }

  final index = payload[0];

  // Read name (null-terminated within 32 bytes)
  int nameEnd = 1;
  while (nameEnd < 33 && nameEnd < payload.length && payload[nameEnd] != 0) {
    nameEnd++;
  }
  final name = sanitizeExternalText(
    String.fromCharCodes(payload.sublist(1, nameEnd)),
  );

  // Read PSK (16 bytes at offset 33)
  final psk = Uint8List.fromList(payload.sublist(33, 49));

  return ParseResult.success(
    MeshCoreChannelInfo(
      index: index,
      name: name,
      psk: psk,
      rawPayload: payload,
    ),
  );
}
