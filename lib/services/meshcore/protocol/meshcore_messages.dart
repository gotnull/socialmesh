// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore protocol message parsing.
//
// Pure functions for parsing MeshCore response payloads into structured data.
// These functions do NOT handle framing or transport - they only parse payloads
// that have already been extracted from MeshCoreFrame.

import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import '../../../utils/text_sanitizer.dart';
import '../storage/meshcore_battery_chemistry.dart';
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
  /// D-Q11 routes through the chemistry-aware estimator so callers
  /// with a non-LiPo cell (LiFePO4 / Li-Ion / NiMH) can pass the
  /// right profile; this getter preserves the historical default
  /// for callers that don't know any better.
  int? get batteryPercentEstimate {
    return estimateMeshCoreBatteryPercent(
      voltageMv: batteryMillivolts,
      chemistry: MeshCoreBatteryChemistry.lipo,
    );
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

/// D35-A: parsed `RESP_CODE_STATS` (0x18) payload for the RADIO subtype.
///
/// The companion firmware exposes this on `CMD_GET_STATS` (0x38) with the
/// second byte set to `STATS_TYPE_RADIO` (1). Wire layout (14 bytes):
///
/// ```
/// offset  field            type      notes
/// 0       resp_code        u8 = 0x18 RESP_CODE_STATS
/// 1       stats_type       u8 = 1    STATS_TYPE_RADIO
/// 2-3     noise_floor      i16 LE    dBm
/// 4       last_rssi        i8        dBm
/// 5       last_snr_raw     i8        quarter-dB (raw / 4 = dB)
/// 6-9     tx_air_secs      u32 LE    cumulative TX airtime, seconds
/// 10-13   rx_air_secs      u32 LE    cumulative RX airtime, seconds
/// ```
///
/// TX/RX airtime totals are cumulative since last firmware power
/// cycle; the firmware does NOT expose a reset command. Noise floor /
/// RSSI / SNR are momentary readouts at fetch time.
class MeshCoreRadioStats {
  /// Noise floor in dBm. Negative values typical (-110 .. -90).
  final int noiseFloorDbm;

  /// Last observed RSSI in dBm. Negative values typical.
  final int lastRssiDbm;

  /// Last observed SNR encoded as the firmware's raw int8 quarter-dB
  /// value. Use [snrDb] for the human-readable conversion.
  final int lastSnrQuarter;

  /// Cumulative TX airtime since the radio booted. Resets only on
  /// power cycle.
  final Duration txAirtime;

  /// Cumulative RX airtime since the radio booted. Resets only on
  /// power cycle.
  final Duration rxAirtime;

  /// Wall-clock time the snapshot was received. Used by the provider
  /// to flag stale data when transport drops mid-poll.
  final DateTime fetchedAt;

  const MeshCoreRadioStats({
    required this.noiseFloorDbm,
    required this.lastRssiDbm,
    required this.lastSnrQuarter,
    required this.txAirtime,
    required this.rxAirtime,
    required this.fetchedAt,
  });

  /// Last SNR in dB (raw quarter-dB / 4.0). Negative values are
  /// typical; values may be small fractional numbers.
  double get snrDb => lastSnrQuarter / 4.0;

  /// Parse a RADIO-subtype stats payload. Returns `null` on:
  ///   - wrong length (must be exactly 14 bytes),
  ///   - wrong discriminator (`payload[0] != 0x18`),
  ///   - wrong subtype (`payload[1] != 1`).
  ///
  /// `now` lets tests inject a deterministic `fetchedAt`. Production
  /// callers omit it; the parser falls back to `DateTime.now()`.
  static MeshCoreRadioStats? parse(Uint8List payload, {DateTime? now}) {
    if (payload.length != 14) return null;
    if (payload[0] != 0x18) return null;
    if (payload[1] != 1) return null;

    final byteData = ByteData.sublistView(payload);
    final noise = byteData.getInt16(2, Endian.little);
    final rssi = byteData.getInt8(4);
    final snrRaw = byteData.getInt8(5);
    final txSecs = byteData.getUint32(6, Endian.little);
    final rxSecs = byteData.getUint32(10, Endian.little);

    return MeshCoreRadioStats(
      noiseFloorDbm: noise,
      lastRssiDbm: rssi,
      lastSnrQuarter: snrRaw,
      txAirtime: Duration(seconds: txSecs),
      rxAirtime: Duration(seconds: rxSecs),
      fetchedAt: now ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'MeshCoreRadioStats(noise=${noiseFloorDbm}dBm, '
      'rssi=${lastRssiDbm}dBm, snr_q=$lastSnrQuarter, '
      'tx=${txAirtime.inSeconds}s, rx=${rxAirtime.inSeconds}s)';
}

/// D49-A: outcome of a `CMD_SEND_LOGIN 0x1A` round-trip. The firmware
/// answers asynchronously with either `PUSH_CODE_LOGIN_SUCCESS 0x85`
/// (admin or guest) or `PUSH_CODE_LOGIN_FAIL 0x86`; the wrapper
/// boxes both outcomes plus the timeout case here.
class MeshCoreLoginResult {
  /// `true` if the firmware confirmed authentication (0x85 received).
  final bool delivered;

  /// On `delivered`: whether the firmware accepted this client as an
  /// admin (byte 1 of the 0x85 push = 1) vs a guest (0). Undefined
  /// when `delivered` is false.
  final bool isAdmin;

  const MeshCoreLoginResult({required this.delivered, required this.isAdmin});

  const MeshCoreLoginResult.timedOut() : delivered = false, isAdmin = false;
  const MeshCoreLoginResult.failed() : delivered = false, isAdmin = false;
}

// D49-B: outcome of [MeshCoreSession.sendCliCommand].
//
// Discriminates the three terminal states of a CLI round-trip:
// successful routed text reply (after `XX|` token strip), host-side
// rate-limit rejection, or no routed reply within the timeout. The
// shape mirrors [MeshCoreTextSendResult] so call sites can switch on
// the same outcome enum surface.
class MeshCoreCliResult {
  final MeshCoreCliOutcome outcome;

  // Repeater text reply with the leading `XX|` correlation token
  // stripped. Non-null when [outcome] is `ok`.
  final String? response;

  // On `rateLimited`: how long the caller should wait before retrying.
  final Duration? nextSendIn;

  // On `rateLimited`: bytes still available in the budget window
  // (the rejected request did NOT consume).
  final int? remainingBytes;

  const MeshCoreCliResult._({
    required this.outcome,
    this.response,
    this.nextSendIn,
    this.remainingBytes,
  });

  factory MeshCoreCliResult.ok({required String response}) =>
      MeshCoreCliResult._(outcome: MeshCoreCliOutcome.ok, response: response);

  factory MeshCoreCliResult.rateLimited({
    required Duration nextSendIn,
    required int remainingBytes,
  }) => MeshCoreCliResult._(
    outcome: MeshCoreCliOutcome.rateLimited,
    nextSendIn: nextSendIn,
    remainingBytes: remainingBytes,
  );

  factory MeshCoreCliResult.firmwareTimeout() =>
      const MeshCoreCliResult._(outcome: MeshCoreCliOutcome.firmwareTimeout);

  bool get ok => outcome == MeshCoreCliOutcome.ok;
  bool get rateLimited => outcome == MeshCoreCliOutcome.rateLimited;
  bool get firmwareTimeout => outcome == MeshCoreCliOutcome.firmwareTimeout;
}

enum MeshCoreCliOutcome { ok, rateLimited, firmwareTimeout }

/// D49-A: parsed `PUSH_CODE_STATUS_RESPONSE 0x87` body for the
/// repeater admin status surface.
///
/// Wire layout (after the leading opcode is stripped, so `payload[0]`
/// is the byte after `0x87`):
///
/// ```
/// [0]      reserved
/// [1..7]   sender pubkey prefix (6 B) -- correlation key
/// [7..]    stats body, exactly 52 bytes:
///   +0  u16 LE  battery_mv
///   +2  u16 LE  queue_len
///   +4  i16 LE  noise_floor_dbm
///   +6  i16 LE  last_rssi
///   +8  u32 LE  packets_recv
///   +12 u32 LE  packets_sent
///   +16 u32 LE  tx_air_secs
///   +20 u32 LE  uptime_secs
///   +24 u32 LE  flood_tx
///   +28 u32 LE  direct_tx
///   +32 u32 LE  flood_rx
///   +36 u32 LE  direct_rx
///   +40 u16 LE  err_events
///   +42 i16 LE  last_snr_raw  (divide by 4.0 for dB)
///   +44 u16 LE  direct_dups
///   +46 u16 LE  flood_dups
///   +48 u32 LE  rx_air_secs
/// ```
///
/// Total minimum payload length: 7 (header) + 52 (body) = 59 bytes.
class MeshCoreRepeaterStatus {
  /// 6-byte prefix of the responding repeater's public key. Used by
  /// the session listener to correlate the push to an outstanding
  /// `sendStatusRequest`.
  final Uint8List senderPubKeyPrefix;
  final int batteryMv;
  final int queueLen;
  final int noiseFloorDbm;
  final int lastRssiDbm;
  final int packetsRecv;
  final int packetsSent;
  final Duration txAirtime;
  final Duration uptime;
  final int floodTx;
  final int directTx;
  final int floodRx;
  final int directRx;
  final int errEvents;
  final int lastSnrQuarter;
  final int directDups;
  final int floodDups;
  final Duration rxAirtime;
  final DateTime fetchedAt;

  const MeshCoreRepeaterStatus({
    required this.senderPubKeyPrefix,
    required this.batteryMv,
    required this.queueLen,
    required this.noiseFloorDbm,
    required this.lastRssiDbm,
    required this.packetsRecv,
    required this.packetsSent,
    required this.txAirtime,
    required this.uptime,
    required this.floodTx,
    required this.directTx,
    required this.floodRx,
    required this.directRx,
    required this.errEvents,
    required this.lastSnrQuarter,
    required this.directDups,
    required this.floodDups,
    required this.rxAirtime,
    required this.fetchedAt,
  });

  /// Battery voltage in volts (mv / 1000). Returns `null` when the
  /// firmware did not measure a value (battery_mv == 0).
  double? get batteryVolts => batteryMv == 0 ? null : batteryMv / 1000.0;

  /// SNR in dB (raw quarter-dB / 4.0).
  double get lastSnrDb => lastSnrQuarter / 4.0;

  /// Parse the body of a `PUSH_CODE_STATUS_RESPONSE 0x87` frame.
  /// Returns `null` on payload shorter than 59 bytes.
  ///
  /// `now` is injectable for deterministic tests; production callers
  /// omit it and the parser stamps `DateTime.now()`.
  static MeshCoreRepeaterStatus? parse(Uint8List payload, {DateTime? now}) {
    if (payload.length < 59) return null;
    final prefix = Uint8List.fromList(payload.sublist(1, 7));
    final bd = ByteData.sublistView(payload, 7);
    return MeshCoreRepeaterStatus(
      senderPubKeyPrefix: prefix,
      batteryMv: bd.getUint16(0, Endian.little),
      queueLen: bd.getUint16(2, Endian.little),
      noiseFloorDbm: bd.getInt16(4, Endian.little),
      lastRssiDbm: bd.getInt16(6, Endian.little),
      packetsRecv: bd.getUint32(8, Endian.little),
      packetsSent: bd.getUint32(12, Endian.little),
      txAirtime: Duration(seconds: bd.getUint32(16, Endian.little)),
      uptime: Duration(seconds: bd.getUint32(20, Endian.little)),
      floodTx: bd.getUint32(24, Endian.little),
      directTx: bd.getUint32(28, Endian.little),
      floodRx: bd.getUint32(32, Endian.little),
      directRx: bd.getUint32(36, Endian.little),
      errEvents: bd.getUint16(40, Endian.little),
      lastSnrQuarter: bd.getInt16(42, Endian.little),
      directDups: bd.getUint16(44, Endian.little),
      floodDups: bd.getUint16(46, Endian.little),
      rxAirtime: Duration(seconds: bd.getUint32(48, Endian.little)),
      fetchedAt: now ?? DateTime.now(),
    );
  }
}

/// D35-B-A: parsed `RESP_CODE_STATS` (0x18) payload for the CORE subtype.
///
/// The companion firmware exposes this on `CMD_GET_STATS` (0x38) with the
/// second byte set to `STATS_TYPE_CORE` (0). Wire layout (11 bytes):
///
/// ```
/// offset  field            type      notes
/// 0       resp_code        u8 = 0x18 RESP_CODE_STATS
/// 1       stats_type       u8 = 0    STATS_TYPE_CORE
/// 2-3     battery_mv       u16 LE    millivolts
/// 4-7     uptime_secs      u32 LE    seconds since power-on
/// 8-9     error_flags      u16 LE    firmware-internal flags accumulator
/// 10      queue_len        u8        outbound LoRa TX queue depth
/// ```
///
/// Resets:
///   - uptime resets on power cycle AND soft reboot.
///   - battery, error flags, queue length reset on power cycle.
/// The firmware does NOT expose a host command to clear any of these.
///
/// Privacy:
///   - The CORE response carries no peer identity, no message content,
///     no path bytes, no PSKs.
///   - `errorFlags` is a u16 accumulator with NO named bit constants in
///     the firmware source. The UI never invents per-bit labels; it
///     surfaces the value as opaque hex when non-zero, intended only
///     for inclusion in support reports.
class MeshCoreCoreStats {
  /// Battery voltage in millivolts. Parsed for completeness but the
  /// companion-radio Tools card does NOT render this row, since
  /// `meshCoreBatteryProvider` already exposes battery via
  /// `getBattAndStorage`. The field is preserved here so a future
  /// fallback path could rely on it without re-parsing.
  final int batteryMillivolts;

  /// Time since the radio's last power-on. Resets on soft reboot too.
  final Duration uptime;

  /// Firmware-internal error flags. Bits are NOT documented in the
  /// companion-radio firmware source; treat as opaque. The UI shows
  /// this as a hex value only when non-zero.
  final int errorFlags;

  /// Number of packets pending outbound LoRa transmission. Distinct
  /// from D28's `_QueueStatusCard` (which tracks the inbound
  /// `next_message_ready` drain heartbeat).
  final int queueLength;

  /// Wall-clock time the snapshot was received. Used by the provider
  /// to flag stale data when transport drops mid-poll.
  final DateTime fetchedAt;

  const MeshCoreCoreStats({
    required this.batteryMillivolts,
    required this.uptime,
    required this.errorFlags,
    required this.queueLength,
    required this.fetchedAt,
  });

  /// Parse a CORE-subtype stats payload. Returns `null` on:
  ///   - wrong length (must be exactly 11 bytes),
  ///   - wrong discriminator (`payload[0] != 0x18`),
  ///   - wrong subtype (`payload[1] != 0`).
  ///
  /// `now` lets tests inject a deterministic `fetchedAt`. Production
  /// callers omit it; the parser falls back to `DateTime.now()`.
  static MeshCoreCoreStats? parse(Uint8List payload, {DateTime? now}) {
    if (payload.length != 11) return null;
    if (payload[0] != 0x18) return null;
    if (payload[1] != 0) return null;

    final byteData = ByteData.sublistView(payload);
    final batteryMv = byteData.getUint16(2, Endian.little);
    final uptimeSecs = byteData.getUint32(4, Endian.little);
    final errFlags = byteData.getUint16(8, Endian.little);
    final queueLen = byteData.getUint8(10);

    return MeshCoreCoreStats(
      batteryMillivolts: batteryMv,
      uptime: Duration(seconds: uptimeSecs),
      errorFlags: errFlags,
      queueLength: queueLen,
      fetchedAt: now ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'MeshCoreCoreStats(uptime=${uptime.inSeconds}s, '
      'q=$queueLength, err_flags=0x'
      '${errorFlags.toRadixString(16).padLeft(4, '0')})';
}

/// D35-PACKETS-A: parsed `RESP_CODE_STATS` (0x18) payload for the
/// PACKETS subtype.
///
/// The companion firmware exposes this on `CMD_GET_STATS` (0x38) with
/// the second byte set to `STATS_TYPE_PACKETS` (2). Wire layout
/// (30 bytes):
///
/// ```
/// offset  field              type      notes
/// 0       resp_code          u8 = 0x18 RESP_CODE_STATS
/// 1       stats_type         u8 = 2    STATS_TYPE_PACKETS
/// 2-5     packets_received   u32 LE    radio-driver aggregate RX
/// 6-9     packets_sent       u32 LE    radio-driver aggregate TX
/// 10-13   sent_flood         u32 LE    flood-routed TX
/// 14-17   sent_direct        u32 LE    direct-routed TX
/// 18-21   recv_flood         u32 LE    flood-mode RX
/// 22-25   recv_direct        u32 LE    direct-routed RX
/// 26-29   recv_errors        u32 LE    opaque RX-error tally
/// ```
///
/// Resets:
///   - All counters reset only on power cycle (radio-driver memory).
///   - The firmware exposes NO host command to clear them.
///
/// Privacy:
///   - The PACKETS response carries no peer identity, no message
///     content, no path bytes, no PSKs. Only aggregate cumulative
///     packet counts.
///   - `recvErrors` is a single opaque tally maintained by the radio
///     driver. The firmware source defines no error categories; the
///     UI MUST surface this as one count, never per-bit / per-cause
///     labels.
///   - `packetsReceived` and `recvFlood + recvDirect` may not sum
///     identically: the radio driver's aggregate counter and the
///     mesh-routing breakdown can diverge slightly (overheard
///     traffic, malformed headers). A small delta is expected.
class MeshCorePacketsStats {
  /// Total RX packets seen by the radio driver. Aggregate across all
  /// modes.
  final int packetsReceived;

  /// Total TX packets emitted by the radio driver. Aggregate across
  /// all modes.
  final int packetsSent;

  /// Packets we transmitted in flood mode.
  final int sentFlood;

  /// Packets we transmitted via direct routing (known path).
  final int sentDirect;

  /// Packets we heard in flood-mode broadcast.
  final int recvFlood;

  /// Packets we heard via direct routing (destined for or relayed by
  /// this node).
  final int recvDirect;

  /// Generic packet-reception failures. The firmware does NOT
  /// categorise these (no CRC vs header-mismatch vs decode-failure
  /// breakdown). Surface as one opaque count.
  final int recvErrors;

  /// Wall-clock time the snapshot was received. Used by the provider
  /// to flag stale data when transport drops mid-poll.
  final DateTime fetchedAt;

  const MeshCorePacketsStats({
    required this.packetsReceived,
    required this.packetsSent,
    required this.sentFlood,
    required this.sentDirect,
    required this.recvFlood,
    required this.recvDirect,
    required this.recvErrors,
    required this.fetchedAt,
  });

  /// Parse a PACKETS-subtype stats payload. Returns `null` on:
  ///   - wrong length (must be exactly 30 bytes),
  ///   - wrong discriminator (`payload[0] != 0x18`),
  ///   - wrong subtype (`payload[1] != 2`).
  ///
  /// `now` lets tests inject a deterministic `fetchedAt`. Production
  /// callers omit it; the parser falls back to `DateTime.now()`.
  static MeshCorePacketsStats? parse(Uint8List payload, {DateTime? now}) {
    if (payload.length != 30) return null;
    if (payload[0] != 0x18) return null;
    if (payload[1] != 2) return null;

    final byteData = ByteData.sublistView(payload);
    final rx = byteData.getUint32(2, Endian.little);
    final tx = byteData.getUint32(6, Endian.little);
    final txFlood = byteData.getUint32(10, Endian.little);
    final txDirect = byteData.getUint32(14, Endian.little);
    final rxFlood = byteData.getUint32(18, Endian.little);
    final rxDirect = byteData.getUint32(22, Endian.little);
    final rxErr = byteData.getUint32(26, Endian.little);

    return MeshCorePacketsStats(
      packetsReceived: rx,
      packetsSent: tx,
      sentFlood: txFlood,
      sentDirect: txDirect,
      recvFlood: rxFlood,
      recvDirect: rxDirect,
      recvErrors: rxErr,
      fetchedAt: now ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'MeshCorePacketsStats(rx=$packetsReceived tx=$packetsSent '
      'tx_flood=$sentFlood tx_direct=$sentDirect '
      'rx_flood=$recvFlood rx_direct=$recvDirect '
      'rx_err=$recvErrors)';
}

/// D36-A: one neighbour entry in a `MeshCoreNeighborsResponse`.
///
/// Each record is 9 bytes on the wire:
///   [0..3]  pubkey_prefix    raw 4-byte prefix of the neighbour's pubkey
///   [4..7]  last_heard_secs  u32 LE, seconds since the repeater last heard
///   [8]     snr_raw          i8, quarter-dB (raw / 4.0 = dB)
///
/// Privacy: only the 4-byte prefix is exposed. The UI must NEVER
/// reconstruct or display a full 32-byte pubkey from this record;
/// the prefix is sufficient to match against the local contact
/// roster and to render a short fingerprint when no match exists.
class MeshCoreNeighbor {
  /// 4-byte prefix of the neighbour's pubkey.
  final Uint8List pubKeyPrefix;

  /// Time since the target repeater last heard this neighbour.
  final Duration lastHeard;

  /// Last-known SNR encoded as the firmware's raw int8 quarter-dB
  /// value. Use [snrDb] for the human-readable conversion.
  final int snrQuarter;

  const MeshCoreNeighbor({
    required this.pubKeyPrefix,
    required this.lastHeard,
    required this.snrQuarter,
  });

  /// SNR in dB (raw quarter-dB / 4.0). Negative values are typical.
  double get snrDb => snrQuarter / 4.0;

  @override
  String toString() =>
      'MeshCoreNeighbor(prefix=4B last=${lastHeard.inSeconds}s '
      'snr_q=$snrQuarter)';
}

/// D36-A: parsed `PUSH_CODE_BINARY_RESPONSE` (0x8C) payload for the
/// `getNeighbours` request type (0x06).
///
/// Wire layout (variable length):
///   [0..1]  reported_count   u16 LE   total neighbours the repeater knows
///   [2..3]  results_count    u16 LE   rows actually included in this response
///   [4..]   N × neighbour_record (9 bytes each, see [MeshCoreNeighbor])
///
/// `reportedCount` may exceed `results.length` when the request asked
/// for fewer rows than the repeater has (we cap at 15 by spec); the
/// UI surfaces this as a "Showing N of M" footer.
class MeshCoreNeighborsResponse {
  /// Total number of neighbours the target repeater says it has.
  final int reportedCount;

  /// Parsed records actually included in this response.
  final List<MeshCoreNeighbor> results;

  /// Wall-clock time the response was received.
  final DateTime fetchedAt;

  const MeshCoreNeighborsResponse({
    required this.reportedCount,
    required this.results,
    required this.fetchedAt,
  });

  /// Parse a neighbours-response payload. Returns `null` on:
  ///   - payload < 4 bytes (no count headers),
  ///   - tail length != resultsCount × 9 (mismatch between declared
  ///     and actual record count).
  ///
  /// `now` lets tests inject a deterministic `fetchedAt`. Production
  /// callers omit it; the parser falls back to `DateTime.now()`.
  static MeshCoreNeighborsResponse? parse(Uint8List payload, {DateTime? now}) {
    if (payload.length < 4) return null;
    final byteData = ByteData.sublistView(payload);
    final reportedCount = byteData.getUint16(0, Endian.little);
    final resultsCount = byteData.getUint16(2, Endian.little);
    final expectedTail = resultsCount * 9;
    if (payload.length - 4 != expectedTail) return null;

    final results = <MeshCoreNeighbor>[];
    for (var i = 0; i < resultsCount; i++) {
      final base = 4 + i * 9;
      final prefix = Uint8List.fromList(payload.sublist(base, base + 4));
      final lastHeardSecs = byteData.getUint32(base + 4, Endian.little);
      final snrRaw = byteData.getInt8(base + 8);
      results.add(
        MeshCoreNeighbor(
          pubKeyPrefix: prefix,
          lastHeard: Duration(seconds: lastHeardSecs),
          snrQuarter: snrRaw,
        ),
      );
    }

    return MeshCoreNeighborsResponse(
      reportedCount: reportedCount,
      results: List.unmodifiable(results),
      fetchedAt: now ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'MeshCoreNeighborsResponse(reported=$reportedCount '
      'results=${results.length})';
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

  /// D-Q3: firmware-side flags byte at offset 33 of the CONTACT
  /// frame. Bit 0 is `favorite`; other bits reserved for upstream
  /// telemetry-permission expansion (preserved verbatim on toggle).
  final int flags;

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
    this.flags = 0,
    required this.lastMod,
    this.latitude,
    this.longitude,
    required this.name,
    required this.pathBytes,
    required this.rawPayload,
  });

  /// D-Q3: convenience getter for the `favorite` bit (offset 0x01).
  bool get isFavorite =>
      (flags & MeshCoreContactFlags.favorite) == MeshCoreContactFlags.favorite;

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
  // D-Q3: capture the firmware-side flags byte (bit 0 = favorite).
  // Reserved bits round-trip on toggle so future telemetry-permission
  // bits stay intact.
  final flags = reader.readByte();
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
      flags: flags,
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
