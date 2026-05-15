// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore BLE constants.
//
// This file contains BLE service UUIDs, characteristic UUIDs, and protocol
// constants for MeshCore devices. These values are isolated here to make
// them easy to update when MeshCore documentation becomes available.
//
// IMPORTANT: These are placeholder values. When actual MeshCore BLE
// identifiers are documented, update them here. The constants are designed
// to be easily swappable without changing other code.

/// MeshCore BLE service and characteristic UUIDs.
///
/// These UUIDs identify MeshCore devices during BLE scanning and are used
/// to locate the correct characteristics for communication.
///
/// MeshCore uses the Nordic UART Service (NUS) for BLE communication.
/// See: https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/libraries/bluetooth_services/services/nus.html
class MeshCoreBleUuids {
  MeshCoreBleUuids._();

  /// Nordic UART Service UUID.
  ///
  /// This is the primary service UUID exposed by MeshCore devices.
  /// It's the standard Nordic UART Service used for serial-over-BLE.
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// Nordic UART RX characteristic UUID (write to device).
  ///
  /// Data written to this characteristic is sent to the MeshCore device.
  /// Supports write without response for optimal throughput.
  static const String writeCharacteristicUuid =
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// Nordic UART TX characteristic UUID (notify from device).
  ///
  /// Subscribe to notifications on this characteristic to receive
  /// data from the MeshCore device.
  static const String notifyCharacteristicUuid =
      '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  /// List of all service UUIDs to filter during scanning.
  static const List<String> scanFilterUuids = [serviceUuid];
}

/// MeshCore device name patterns for detection.
///
/// These patterns are used to identify MeshCore devices from BLE
/// advertisement data when the service UUID alone is not sufficient.
class MeshCoreDevicePatterns {
  MeshCoreDevicePatterns._();

  /// Prefixes that indicate a MeshCore device (case-insensitive matching).
  ///
  /// PLACEHOLDER: Update with actual MeshCore device name patterns.
  static const List<String> namePrefixes = ['meshcore', 'mc-'];

  /// Substrings that indicate a MeshCore device (case-insensitive matching).
  ///
  /// PLACEHOLDER: Update with actual identifiers.
  static const List<String> nameContains = ['meshcore'];

  /// Check if a device name matches MeshCore patterns.
  ///
  /// Uses case-insensitive matching for better detection tolerance.
  static bool matchesDeviceName(String? name) {
    if (name == null || name.isEmpty) return false;

    final lowerName = name.toLowerCase();

    for (final prefix in namePrefixes) {
      if (lowerName.startsWith(prefix)) return true;
    }

    for (final substring in nameContains) {
      if (lowerName.contains(substring)) return true;
    }

    return false;
  }
}

/// MeshCore protocol framing constants.
///
/// MeshCore BLE: Each BLE notification IS the complete frame - NO extra framing.
/// MeshCore USB: Uses direction marker + 2-byte little-endian length + payload.
///   - App -> Radio: '<' (0x3C) + length(LE) + payload
///   - Radio -> App: '>' (0x3E) + length(LE) + payload
///
/// Frame format (inner protocol, after USB framing stripped):
///   [command: 1 byte][payload: 0-171 bytes]
///   Max total: 172 bytes
class MeshCoreFramingConstants {
  MeshCoreFramingConstants._();

  /// USB direction marker: app -> radio (outbound).
  static const int usbAppToRadioMarker = 0x3C; // '<'

  /// USB direction marker: radio -> app (inbound).
  static const int usbRadioToAppMarker = 0x3E; // '>'

  /// USB header size in bytes (marker + 2-byte length).
  static const int usbHeaderSize = 3;

  /// Maximum frame size in bytes (command + payload).
  static const int maxFrameSize = 172;

  /// Maximum payload size in bytes (legacy alias for maxFrameSize - 1).
  ///
  /// This is used for USB framing compatibility where the payload size
  /// limit is relevant. Use maxFrameSize for the actual protocol limit.
  static const int maxPayloadSize = 250;

  /// Public key size in bytes.
  static const int pubKeySize = 32;

  /// Maximum path size in bytes.
  static const int maxPathSize = 64;

  /// Maximum name size in bytes.
  static const int maxNameSize = 32;

  /// App protocol version.
  static const int appProtocolVersion = 3;
}

/// MeshCore protocol command codes (app -> device).
class MeshCoreCommands {
  MeshCoreCommands._();

  /// App start / handshake command.
  static const int appStart = 0x01;

  /// Send text message to contact.
  static const int sendTxtMsg = 0x02;

  /// Send text message to channel.
  static const int sendChannelTxtMsg = 0x03;

  /// Request contacts list.
  static const int getContacts = 0x04;

  /// Get device time.
  static const int getDeviceTime = 0x05;

  /// Set device time.
  static const int setDeviceTime = 0x06;

  /// Send self advertisement.
  static const int sendSelfAdvert = 0x07;

  /// Set advertisement name.
  static const int setAdvertName = 0x08;

  /// Add or update contact.
  static const int addUpdateContact = 0x09;

  /// Sync next queued message.
  static const int syncNextMessage = 0x0A;

  /// Set radio parameters.
  static const int setRadioParams = 0x0B;

  /// Set radio TX power.
  static const int setRadioTxPower = 0x0C;

  /// Reset path for contact.
  static const int resetPath = 0x0D;

  /// Set advertisement lat/lon.
  static const int setAdvertLatLon = 0x0E;

  /// Remove contact.
  static const int removeContact = 0x0F;

  /// Share contact.
  static const int shareContact = 0x10;

  /// Export contact.
  static const int exportContact = 0x11;

  /// Import contact.
  static const int importContact = 0x12;

  /// Reboot device.
  static const int reboot = 0x13;

  /// Get battery and storage info.
  static const int getBattAndStorage = 0x14;

  /// Device query / info request.
  static const int deviceQuery = 0x16;

  /// Send login.
  static const int sendLogin = 0x1A;

  /// Send status request.
  static const int sendStatusReq = 0x1B;

  /// Get contact by public key.
  static const int getContactByKey = 0x1E;

  /// Get channel info.
  static const int getChannel = 0x1F;

  /// Set channel info.
  static const int setChannel = 0x20;

  /// Send trace path.
  static const int sendTracePath = 0x24;

  /// Get telemetry request.
  static const int getTelemetryReq = 0x27;

  /// Get custom variables.
  static const int getCustomVar = 0x28;

  /// Set custom variable.
  static const int setCustomVar = 0x29;

  /// Send binary request.
  static const int sendBinaryReq = 0x32;

  /// D35-A: get firmware-side stats. Second byte selects the
  /// subtype — only `MeshCoreStatsType.radio` (1) is consumed in
  /// this slice; CORE/PACKETS subtypes are intentionally deferred.
  /// Available on companion firmware v8 and newer; SocialMesh's
  /// pinned firmware (v1.15.0 / ver_code 11) is well past that gate.
  static const int getStats = 0x38;

  /// D47-A: write per-device auto-add config. Wire payload:
  /// `[0x3A][flags:1B]`. Firmware auto-promotes inbound adverts to
  /// the contact roster when the corresponding type bit is set in
  /// [flags]. See [MeshCoreAutoAddFlag] for the bit layout.
  static const int setAutoAddConfig = 0x3A;

  /// D47-A: read per-device auto-add config. Wire payload: `[0x3B]`.
  /// Response: `RESP_CODE_AUTO_ADD_CONFIG (0x19)` with a single
  /// flags byte.
  static const int getAutoAddConfig = 0x3B;
}

/// MeshCore response codes (device -> app, 0x00-0x7F).
class MeshCoreResponses {
  MeshCoreResponses._();

  /// OK / success.
  static const int ok = 0x00;

  /// Error.
  static const int err = 0x01;

  /// Contacts list start.
  static const int contactsStart = 0x02;

  /// Contact entry.
  static const int contact = 0x03;

  /// End of contacts list.
  static const int endOfContacts = 0x04;

  /// Self info.
  static const int selfInfo = 0x05;

  /// Message sent acknowledgment.
  static const int sent = 0x06;

  /// Contact message received.
  static const int contactMsgRecv = 0x07;

  /// Channel message received.
  static const int channelMsgRecv = 0x08;

  /// Current time.
  static const int currTime = 0x09;

  /// No more messages in queue.
  static const int noMoreMessages = 0x0A;

  /// D46-A: serialized contact-frame bytes returned by
  /// `CMD_EXPORT_CONTACT (0x11)`. Payload is the 135..147-byte
  /// canonical contact frame (`parseContact`-compatible).
  static const int exportContact = 0x0B;

  /// Battery and storage info.
  static const int battAndStorage = 0x0C;

  /// Device info.
  static const int deviceInfo = 0x0D;

  /// Contact message received (v3 format).
  static const int contactMsgRecvV3 = 0x10;

  /// Channel message received (v3 format).
  static const int channelMsgRecvV3 = 0x11;

  /// Channel info.
  static const int channelInfo = 0x12;

  /// Custom variables.
  static const int customVars = 0x15;

  /// D35-A: response to `MeshCoreCommands.getStats`. Second byte
  /// echoes the requested subtype. Only the RADIO subtype payload
  /// is parsed today.
  static const int stats = 0x18;

  /// D47-A: auto-add config payload returned by
  /// `CMD_GET_AUTO_ADD_CONFIG (0x3B)`. Single byte of flag bits;
  /// see [MeshCoreAutoAddFlag].
  static const int autoAddConfig = 0x19;
}

/// D35-A: stats subtypes carried as the second byte of both the
/// `getStats` request and the `stats` response.
///
/// Only [radio] is consumed by SocialMesh today. The CORE / PACKETS
/// subtypes are intentionally deferred — adding them later is a
/// separate slice with its own UX review.
class MeshCoreStatsType {
  MeshCoreStatsType._();

  /// Battery mV + uptime seconds + error flags + queue depth.
  /// Reserved-only; not parsed in D35-A.
  static const int core = 0;

  /// Noise floor + last RSSI + last SNR (raw quarter-dB) + cumulative
  /// TX/RX airtime seconds. Parsed by `MeshCoreRadioStats`.
  static const int radio = 1;

  /// RX/TX packet counters + flooded/direct breakdowns + reception
  /// errors. Reserved-only; not parsed in D35-A.
  static const int packets = 2;
}

/// D47-A: auto-add config flag bits carried as the single byte of
/// the `CMD_SET_AUTO_ADD_CONFIG (0x3A)` payload and the
/// `RESP_CODE_AUTO_ADD_CONFIG (0x19)` response payload.
///
/// Each set bit enables firmware auto-promotion of the matching
/// contact type when an inbound advert (`PUSH_CODE_NEW_ADVERT 0x8A`)
/// arrives. Auto-promotion is firmware-driven; the app owns only the
/// policy toggle.
///
/// Reserved bits (`0x20`..`0x80`) are preserved on round-trip so a
/// future firmware can introduce additional types without breaking
/// our parser.
class MeshCoreAutoAddFlag {
  MeshCoreAutoAddFlag._();

  /// Evict the oldest non-favorite contact when the firmware roster
  /// is full and a new candidate qualifies.
  static const int overwriteOldest = 0x01;

  /// Auto-add chat / companion-type contacts.
  static const int chat = 0x02;

  /// Auto-add repeater-type contacts.
  static const int repeater = 0x04;

  /// Auto-add room-server-type contacts.
  static const int roomServer = 0x08;

  /// Auto-add sensor-type contacts.
  static const int sensor = 0x10;
}

/// D36-A: request-type byte placed at the head of the `requestBytes`
/// payload for `CMD_SEND_BINARY_REQ` (0x32). The firmware on the
/// remote peer dispatches on this byte to decide how to interpret
/// the rest of the request body.
///
/// Only [getNeighbours] is consumed by SocialMesh today. Other
/// request types may exist in the broader MeshCore ecosystem
/// (telemetry, page-fetch, etc.); adding any of them requires its
/// own session-helper wrapper and recon. The single-flight binary
/// request helper is intentionally narrow and not exposed as a
/// generic binary-RPC surface.
class MeshCoreBinaryReqType {
  MeshCoreBinaryReqType._();

  /// "List adjacent peers heard by the target repeater." Followed by
  /// `[reserved:u8][max:u8][offset_hi:u8][offset_lo:u8][order_by:u8]
  /// [key_prefix_len:u8]`. The repeater responds asynchronously via
  /// `PUSH_CODE_BINARY_RESPONSE` (0x8C) with a tag matching the
  /// `RESP_CODE_SENT` (0x06) acknowledgement.
  static const int getNeighbours = 0x06;
}

/// MeshCore push codes (async device -> app, 0x80+).
class MeshCorePushCodes {
  MeshCorePushCodes._();

  /// Advertisement received.
  static const int advert = 0x80;

  /// Path updated for contact.
  static const int pathUpdated = 0x81;

  /// Send confirmed (delivery receipt).
  static const int sendConfirmed = 0x82;

  /// Message waiting in queue.
  static const int msgWaiting = 0x83;

  /// Login success.
  static const int loginSuccess = 0x85;

  /// Login failed.
  static const int loginFail = 0x86;

  /// Status response.
  static const int statusResponse = 0x87;

  /// Log RX data.
  static const int logRxData = 0x88;

  /// Trace data.
  static const int traceData = 0x89;

  /// New advertisement.
  static const int newAdvert = 0x8A;

  /// Telemetry response.
  static const int telemetryResponse = 0x8B;

  /// Binary response.
  static const int binaryResponse = 0x8C;
}

/// MeshCore text message types.
class MeshCoreTextTypes {
  MeshCoreTextTypes._();

  /// Plain text message.
  static const int plain = 0x00;

  /// CLI command data.
  static const int cliData = 0x01;
}

/// MeshCore advertisement types.
class MeshCoreAdvertTypes {
  MeshCoreAdvertTypes._();

  /// Chat node.
  static const int chat = 0x01;

  /// Repeater node.
  static const int repeater = 0x02;

  /// Room/group node.
  static const int room = 0x03;

  /// Sensor node.
  static const int sensor = 0x04;
}

/// D-Q3: MeshCore contact-flags bitset. Lives at offset 33 of the
/// canonical 147-byte CONTACT frame and round-trips through
/// `CMD_ADD_UPDATE_CONTACT 0x09`. Today SocialMesh consumes the
/// `favorite` bit only; other bits are reserved for telemetry-
/// permission / future expansion and are preserved verbatim on
/// read-modify-write.
class MeshCoreContactFlags {
  MeshCoreContactFlags._();

  /// Per-contact "favorite" marker — surfaces in the contacts list
  /// with a star badge + pins the row to the top.
  static const int favorite = 0x01;
}

/// MeshCore protocol timeouts.
class MeshCoreTimeouts {
  MeshCoreTimeouts._();

  /// Timeout for connection establishment.
  static const Duration connection = Duration(seconds: 15);

  /// Timeout for device info / self info response.
  static const Duration deviceInfo = Duration(seconds: 5);

  /// Timeout for generic requests.
  static const Duration request = Duration(seconds: 10);
}

// D22.A: missed-tickle recovery drain heartbeat interval (seconds).
//
// While connected to MeshCore, the conversations notifier periodically
// fires `CMD_SYNC_NEXT_MESSAGE` to recover queued messages whose
// one-shot `0x83` tickle was lost (transport blip, app cold-start
// race, BLE buffer pressure). The firmware's queue is reachable via
// the sync command at any time; the tickle is just a notification
// that gets dropped silently when the companion is offline at the
// moment of arrival.
//
// 60 s is the cheap-but-recovers-fast default: at idle this adds one
// 1-byte command + one 1-byte `RESP_CODE_NO_MORE_MESSAGES` per minute
// over the companion link (TCP / BLE), zero airtime. When the queue
// is non-empty the heartbeat drains iteratively until empty in the
// same tick.
const int kMeshCoreDrainHeartbeatSeconds = 60;

// D26: MeshCore advertised-name max length (firmware buffer minus
// null terminator). The companion-radio firmware stores the node
// name in `char node_name[32]` and reserves 1 byte for `\0`, so
// `CMD_SET_ADVERT_NAME` (0x08) accepts at most 31 UTF-8 bytes of
// payload. Longer payloads are silently truncated by the firmware.
// Validate in the UI before sending so the user sees the limit
// explicitly instead of getting a partially-saved name.
const int kMeshCoreMaxNodeNameBytes = 31;

// D26: MeshCore lat/lon scale used by `CMD_SET_ADVERT_LAT_LON`
// (0x0E). The firmware stores `int32` and divides by `1e6` to
// recover degrees. The same scale applies on the wire for
// `setAdvertLatLon`. Note this is `1e6`, NOT `1e7` (Meshtastic
// convention) — easy footgun if you derive from a Meshtastic-shaped
// helper.
const int kMeshCoreAdvertLatLonScale = 1000000;

/// D26: MeshCore region preset.
///
/// Each preset packs the four LoRa params + a recommended TX power
/// (firmware caps to the regulatory ceiling regardless). Selecting
/// a preset prefills the radio settings sheet's frequency /
/// bandwidth / SF / CR / TX power fields; manual edits switch the
/// chip to "Custom" without changing any field values.
///
/// Persistence: the user's last-selected preset id is stored in
/// `MeshCoreRadioParamsStore` for UI-state hydration only. Live
/// firmware values from `selfInfo` remain the source of truth for
/// what the radio actually has applied.
///
/// Source: community-curated values (verified against
/// regulatory + practical operating windows for each region). Not
/// derived from firmware; firmware does not ship preset tables.
class MeshCoreRegionPreset {
  /// Stable identifier used for persistence. Snake_case, never
  /// translated. Adding new presets at the end of the list is
  /// safe; renaming an id silently breaks last-selected hydration.
  final String id;

  /// User-visible label. English source; Italian/Portuguese ARBs
  /// can localize on demand but most are place names that do not
  /// translate.
  final String label;

  final double frequencyMHz;

  /// Bandwidth in kHz (62.5 / 125 / 250 / 500 are the firmware-
  /// supported buckets).
  final double bandwidthKhz;

  final int spreadingFactor;

  /// Coding rate denominator: 5 → 4/5, 6 → 4/6, 7 → 4/7, 8 → 4/8.
  final int codingRate;

  /// Recommended TX power in dBm. Firmware will cap to the
  /// regulatory maximum, so a 20 here may be applied as e.g. 14
  /// in EU jurisdictions.
  final int txPowerDbm;

  const MeshCoreRegionPreset({
    required this.id,
    required this.label,
    required this.frequencyMHz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.txPowerDbm,
  });
}

/// D26: canonical MeshCore region presets.
///
/// 19 named operating points covering the common regional bands
/// (433 / 869 / 870 / 908 / 910 / 915 / 916 / 917 / 918 / 920 /
/// 923 MHz). The values mirror the operating points used by the
/// reference companion implementation; they are not regulatory
/// guarantees and the user remains responsible for picking a
/// preset that is legal in their jurisdiction. Custom is exposed
/// as a UI-only sentinel and has no entry in this list.
const List<MeshCoreRegionPreset> kMeshCoreRegionPresets = [
  MeshCoreRegionPreset(
    id: 'au_default',
    label: 'Australia',
    frequencyMHz: 915.8,
    bandwidthKhz: 250,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'au_narrow',
    label: 'Australia (Narrow)',
    frequencyMHz: 916.575,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'au_sa_wa_qld',
    label: 'Australia SA, WA, QLD',
    frequencyMHz: 923.125,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'cz',
    label: 'Czech Republic',
    frequencyMHz: 869.432,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'eu_433',
    label: 'EU 433MHz',
    frequencyMHz: 433.650,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'eu_uk_long_range',
    label: 'EU/UK (Long Range)',
    frequencyMHz: 869.525,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'eu_uk_medium_range',
    label: 'EU/UK (Medium Range)',
    frequencyMHz: 869.525,
    bandwidthKhz: 250,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'eu_uk_narrow',
    label: 'EU/UK (Narrow)',
    frequencyMHz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'nz_default',
    label: 'New Zealand',
    frequencyMHz: 917.375,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'nz_narrow',
    label: 'New Zealand (Narrow)',
    frequencyMHz: 917.375,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'pt_433',
    label: 'Portugal 433',
    frequencyMHz: 433.375,
    bandwidthKhz: 62.5,
    spreadingFactor: 9,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'pt_869',
    label: 'Portugal 869',
    frequencyMHz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'ch',
    label: 'Switzerland',
    frequencyMHz: 869.618,
    bandwidthKhz: 62.5,
    spreadingFactor: 8,
    codingRate: 5,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'us_arizona',
    label: 'USA Arizona',
    frequencyMHz: 908.205,
    bandwidthKhz: 62.5,
    spreadingFactor: 10,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'us_canada',
    label: 'USA/Canada',
    frequencyMHz: 910.525,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'vn',
    label: 'Vietnam',
    frequencyMHz: 920.250,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 5,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'offgrid_433',
    label: 'Off-Grid 433',
    frequencyMHz: 433.0,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 8,
    txPowerDbm: 20,
  ),
  MeshCoreRegionPreset(
    id: 'offgrid_869',
    label: 'Off-Grid 869',
    frequencyMHz: 869.0,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 8,
    txPowerDbm: 14,
  ),
  MeshCoreRegionPreset(
    id: 'offgrid_918',
    label: 'Off-Grid 918',
    frequencyMHz: 918.0,
    bandwidthKhz: 250,
    spreadingFactor: 11,
    codingRate: 8,
    txPowerDbm: 20,
  ),
];

/// Sentinel preset id used when the user has manually edited any
/// radio param so it no longer matches a known preset's tuple.
/// Stored in [MeshCoreRadioParamsStore] just like a real preset id;
/// hydrating it leaves the chip un-highlighted.
const String kMeshCoreCustomPresetId = 'custom';

/// Find the preset in [kMeshCoreRegionPresets] whose tuple matches
/// the given live radio params, or `null` if no preset matches and
/// the user is on a Custom config. Bandwidth comparison uses a
/// 0.5 kHz tolerance to absorb the 62.5 / 125.0 etc. float roundoff;
/// frequency uses 0.001 MHz (1 kHz) tolerance for the same reason.
MeshCoreRegionPreset? meshCoreRegionPresetMatching({
  required double frequencyMHz,
  required double bandwidthKhz,
  required int spreadingFactor,
  required int codingRate,
  required int txPowerDbm,
}) {
  const freqTol = 0.001;
  const bwTol = 0.5;
  for (final p in kMeshCoreRegionPresets) {
    if ((p.frequencyMHz - frequencyMHz).abs() > freqTol) continue;
    if ((p.bandwidthKhz - bandwidthKhz).abs() > bwTol) continue;
    if (p.spreadingFactor != spreadingFactor) continue;
    if (p.codingRate != codingRate) continue;
    if (p.txPowerDbm != txPowerDbm) continue;
    return p;
  }
  return null;
}

/// MeshCore code classification utilities.
///
/// Code ranges from reference implementation:
/// - Commands (app -> device): 0x01 - 0x7F (full sub-push range)
/// - Responses (device -> app, synchronous): 0x00 - 0x7F
/// - Push codes (device -> app, asynchronous): 0x80 - 0xFF
///
/// Responses are direct replies to commands. Push codes are unsolicited
/// events from the device (advertisements, path updates, confirmations).
class MeshCoreCodeClassification {
  MeshCoreCodeClassification._();

  /// The boundary between response codes and push codes.
  ///
  /// Codes >= this value are push codes (async events).
  /// Codes < this value are response codes (command replies).
  static const int pushCodeBoundary = 0x80;

  /// Check if [code] is a response code (synchronous reply to a command).
  ///
  /// Response codes are in the range 0x00 - 0x7F and are direct replies
  /// to commands sent by the app.
  static bool isResponseCode(int code) => code < pushCodeBoundary;

  /// Check if [code] is a push code (asynchronous event from device).
  ///
  /// Push codes are in the range 0x80 - 0xFF and represent unsolicited
  /// events like advertisements, path updates, and delivery confirmations.
  static bool isPushCode(int code) => code >= pushCodeBoundary;

  /// Check if [code] is a valid command code (app -> device).
  ///
  /// Commands occupy the same numeric range as response codes
  /// (0x01..0x7F) since both are sub-push. Pre-D16 the upper bound was
  /// pinned at a phantom `getRadioSettings = 0x39` constant which both
  /// (a) doesn't exist in firmware and (b) was below several real
  /// firmware command codes (e.g. CMD_GET_DEFAULT_FLOOD_SCOPE = 0x40).
  /// Using the push-code boundary directly is the correct upper bound.
  /// 0x00 is not a valid command (it's the OK response code).
  static bool isCommandCode(int code) =>
      code >= 0x01 && code < pushCodeBoundary;
}
