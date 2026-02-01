// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore BLE constants.
//
// This file contains BLE service UUIDs, characteristic UUIDs, and protocol
// constants for MeshCore devices. These values are isolated here to make
// them easy to update when MeshCore documentation becomes available.
//
// IMPORTANT: These are placeholder values. When actual MeshCore BLE
// identifiers are documented, update them here. The constants are designed
// to be easily swappable without changing other code.

// MeshCore Protocol Code Ranges (from meshcore-open reference):
// - Commands (app -> device): 0x01-0x3F
// - Responses (device -> app, request/reply): 0x00-0x7F
// - Push codes (device -> app, async events): 0x80-0xFF
//
// Key distinction:
// - Response codes (0x00-0x7F) answer a specific command and should satisfy waiters
// - Push codes (0x80-0xFF) are unsolicited events and must NOT satisfy waiters

/// MeshCore protocol code classification helpers.
///
/// These helpers categorize frame codes into commands, responses, and push events.
/// Critical for waiter safety: only response codes should complete pending requests.
class MeshCoreCodeClassification {
  MeshCoreCodeClassification._();

  /// Maximum code value for response codes (request/reply pattern).
  /// Codes 0x00-0x7F are responses; 0x80-0xFF are push/async events.
  static const int maxResponseCode = 0x7F;

  /// Minimum code value for push codes (async events).
  static const int minPushCode = 0x80;

  /// Check if a code is a response code (0x00-0x7F).
  ///
  /// Response codes are returned by the device in reply to a command.
  /// These codes CAN satisfy pending response waiters.
  static bool isResponseCode(int code) =>
      code >= 0x00 && code <= maxResponseCode;

  /// Check if a code is a push code (0x80-0xFF).
  ///
  /// Push codes are unsolicited async events from the device (advertisements,
  /// delivery confirmations, etc.). These codes must NEVER satisfy waiters.
  static bool isPushCode(int code) => code >= minPushCode && code <= 0xFF;

  /// Check if a code is a command code (app -> device).
  ///
  /// Command codes are in the range 0x01-0x3F based on meshcore-open.
  /// This is used for validation, not waiter logic.
  static bool isCommandCode(int code) => code >= 0x01 && code <= 0x3F;
}

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
  ///
  /// From meshcore-open: maxFrameSize = 172
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
///
/// Learned from meshcore-open reference implementation.
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

  /// Get radio settings.
  static const int getRadioSettings = 0x39;
}

/// MeshCore response codes (device -> app, 0x00-0x7F).
///
/// Learned from meshcore-open reference implementation.
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

  /// Radio settings.
  static const int radioSettings = 0x19;
}

/// MeshCore push codes (async device -> app, 0x80+).
///
/// Learned from meshcore-open reference implementation.
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
