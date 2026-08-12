// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
/// Transport types supported by the app
enum TransportType { ble, usb, network }

/// Device information from scan results
class DeviceInfo {
  final String id;
  final String name;
  final TransportType type;
  final String? address;
  final int? rssi;

  /// BLE advertisement data: service UUIDs (lowercased)
  final List<String> serviceUuids;

  /// BLE advertisement data: manufacturer data (company ID -> payload bytes)
  final Map<int, List<int>> manufacturerData;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.rssi,
    this.serviceUuids = const [],
    this.manufacturerData = const {},
  });

  @override
  String toString() => 'DeviceInfo($name, $type, rssi: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

/// Connection state
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// How this transport is re-established after an unexpected disconnect.
///
/// `scanBased` transports (BLE) have to rediscover the peer via an OS scan
/// before they can connect. `directEndpoint` transports (TCP/network) have
/// an address-like identity (host:port) and reconnect directly to it.
enum TransportReconnectMode { scanBased, directEndpoint }

/// Typed exception thrown by [DeviceTransport.send] when the transport
/// is in a state that prevents the write (not connected, missing TX
/// characteristic). Mid-send disconnect failures are NOT thrown -
/// those transition state and return normally so the caller observes
/// the disconnect via [DeviceTransport.stateStream] rather than via
/// an exception that previously bubbled to PlatformDispatcher.onError.
/// Crashlytics issues [D 7894c78d] (NetworkTransport) + [D 5dd688f9]
/// (BleTransport).
class TransportSendError implements Exception {
  final String message;
  const TransportSendError(this.message);

  @override
  String toString() => 'TransportSendError: $message';
}

/// How an OS-level BLE scan registration failed.
///
/// `stackFailure` covers the Android scanner-service failures that mean
/// the Bluetooth stack itself is in a bad state (scan client registration
/// refused, internal error, out of hardware resources). Retrying from the
/// app does not help; the user has to cycle Bluetooth off and on (or
/// reboot). `throttled` means Android rejected the scan because scans
/// were started too frequently - backing off and retrying later succeeds
/// without any user action.
enum BleScanFailureKind { stackFailure, throttled }

/// Typed error emitted by [DeviceTransport.scan] when the OS-level BLE
/// scanner rejects the scan itself (as opposed to the adapter being off
/// or permission missing). Carries the platform error code so logs stay
/// diagnosable, while UI layers key off [kind] to show a localised
/// recovery message instead of the raw plugin exception text.
class BleScanFailure implements Exception {
  final BleScanFailureKind kind;

  /// The raw Android `ScanCallback` error code (e.g. 2 for
  /// SCAN_FAILED_APPLICATION_REGISTRATION_FAILED).
  final int platformCode;

  const BleScanFailure({required this.kind, required this.platformCode});

  @override
  String toString() =>
      'BleScanFailure(kind: ${kind.name}, platformCode: $platformCode)';
}

/// Abstract transport interface
abstract class DeviceTransport {
  /// Get the transport type
  TransportType get type;

  /// Whether this transport requires packet framing
  /// BLE does NOT require framing (raw protobufs)
  /// Serial/USB/Network DO require framing (0x94, 0xC3, length, payload)
  bool get requiresFraming;

  /// Whether this transport needs the 32-byte `0xC3` wake preamble sent
  /// ahead of the first `wantConfigId`. This is a serial-link quirk —
  /// framed traffic alone does NOT imply the device needs waking.
  ///
  /// BLE: false (no serial link beneath)
  /// USB: true (CP210x/CH34x UART on the other side)
  /// Network/TCP: false (firmware-side PhoneAPI, not a UART)
  bool get requiresWakeSequence => false;

  /// How this transport recovers from disconnect — used by the reconnect
  /// coordinator to pick scan-based vs direct-endpoint reconnect logic.
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  /// Current connection state
  DeviceConnectionState get state;

  /// Stream of connection state changes
  Stream<DeviceConnectionState> get stateStream;

  /// Stream of received data
  Stream<List<int>> get dataStream;

  /// Scan for available devices
  ///
  /// [timeout] - How long to scan for devices
  /// [scanAll] - If true, scan for ALL BLE devices without service filtering.
  ///   Default (false) filters by known mesh protocol service UUIDs.
  ///   When true, returns all discovered devices with advertisement data.
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false});

  /// Connect to a device
  Future<void> connect(DeviceInfo device);

  /// Disconnect from the current device
  Future<void> disconnect();

  /// Send data to the device
  Future<void> send(List<int> data);

  /// Poll for data once (for transports that support active polling)
  Future<void> pollOnce();

  /// Enable notifications (BLE-specific, called after initial config download)
  Future<void> enableNotifications();

  /// Read current RSSI value (BLE-specific)
  /// Returns null if not supported or not connected
  Future<int?> readRssi();

  /// Re-subscribe to BLE characteristic notifications.
  ///
  /// On iOS/Android, BLE notification subscriptions can be silently dropped
  /// by the OS while the GATT connection remains alive. Calling this method
  /// reapplies `setNotifyValue(true)` on the fromNum characteristic to
  /// restore the data-flow path. No-op for non-BLE transports.
  Future<void> refreshNotifications() async {}

  /// Get the BLE device model number from Device Information Service
  /// Returns null if not available (USB transport or not read yet)
  String? get bleModelNumber => null;

  /// Get the BLE manufacturer name from Device Information Service
  /// Returns null if not available (USB transport or not read yet)
  String? get bleManufacturerName => null;

  /// Dispose resources
  Future<void> dispose();

  /// Check if connected
  bool get isConnected => state == DeviceConnectionState.connected;
}

/// Optional capability interface for transports that can surface
/// receive-pipeline diagnostic counters.
///
/// Only BLE transports implement this — USB / TCP / test fakes don't,
/// and the protocol-layer stall detector falls back to safe defaults
/// (`null` / `0`) when the active transport isn't a
/// `ReceiveDiagnosticsSupport`. Keeps every existing
/// `implements DeviceTransport` callsite (production and test) free of
/// no-op overrides.
abstract class ReceiveDiagnosticsSupport {
  /// Timestamp of the last raw notification received from the
  /// underlying transport. Used by the protocol-layer receive-stall
  /// detector.
  DateTime? get lastNotificationAt;

  /// Diagnostic counter: number of low-level notification events
  /// observed (e.g. BLE `fromNum` notifications).
  int get fromNumNotificationCount;

  /// Diagnostic counter: number of non-empty data reads observed.
  int get rxBytesReadCount;

  /// Diagnostic counter: number of read failures observed.
  int get rxReadFailureCount;

  /// Diagnostic counter: number of accepted
  /// `DeviceTransport.refreshNotifications` invocations.
  int get refreshNotificationsCount;

  /// Diagnostic counter: number of `refreshNotifications` failures.
  /// A failure either preserves the prior subscription or transitions
  /// to disconnected — never silently leaves the transport in a
  /// "connected, no subscription" state.
  int get refreshNotificationsFailureCount;

  /// Snapshot of the most recent link teardown, or `null` when the
  /// transport has not observed one this session. Populated at every
  /// disconnect origin (OS state change, notification stream closing,
  /// app-requested teardown) so the reconnect layer and bug reports can
  /// state WHO ended the link instead of collapsing everything into
  /// "unexpected disconnect".
  BleDisconnectDetail? get lastDisconnectDetail;

  /// Tags the next app-requested disconnect with its initiating cause
  /// (e.g. a protocol-layer watchdog). Consumed by the transport when
  /// `disconnect()` runs; without a pending cause an app-requested
  /// teardown is recorded as unspecified.
  void noteDisconnectCause(String cause);
}

/// Diagnostic snapshot of one BLE link teardown.
///
/// [origin] states which code path observed the teardown:
/// `os_state_change` (platform reported disconnected),
/// `notify_stream_closed` / `notify_stream_closed_refresh` (the fromNum
/// notification stream completed), `refresh_install_failed` (listener
/// reinstall failed after a resubscribe), or `app_requested`
/// (transport.disconnect() was called - [appCause] carries the watchdog
/// tag when one initiated it).
class BleDisconnectDetail {
  final String origin;

  /// Platform disconnect code when known (CBError on iOS, GATT status
  /// on Android).
  final int? platformCode;
  final String? platformDescription;

  /// When the teardown was observed.
  final DateTime at;

  /// How long the link had been up, when the connect time is known.
  final Duration? uptime;

  /// Age of the last received fromNum notification at teardown time -
  /// distinguishes "link died silent" from "died mid-traffic".
  final Duration? lastNotificationAge;

  /// App-side initiator tag consumed from
  /// [ReceiveDiagnosticsSupport.noteDisconnectCause], when the app
  /// requested the teardown.
  final String? appCause;

  const BleDisconnectDetail({
    required this.origin,
    required this.at,
    this.platformCode,
    this.platformDescription,
    this.uptime,
    this.lastNotificationAge,
    this.appCause,
  });

  /// Key=value payload for `BLE_DISCONNECT` log lines.
  String toLogPayload() {
    final desc = platformDescription;
    return [
      'origin=$origin',
      if (platformCode != null) 'code=$platformCode',
      if (desc != null && desc.isNotEmpty) 'desc="$desc"',
      if (uptime != null) 'uptimeS=${uptime!.inSeconds}',
      if (lastNotificationAge != null)
        'lastNotifAgoS=${lastNotificationAge!.inSeconds}',
      if (appCause != null) 'cause=$appCause',
    ].join(' ');
  }

  /// Single-line summary for connection state and bug-report context.
  String toCompactString() {
    final desc = platformDescription;
    return [
      origin,
      if (platformCode != null) 'code=$platformCode',
      if (desc != null && desc.isNotEmpty) '($desc)',
      if (uptime != null) 'up=${uptime!.inSeconds}s',
      if (lastNotificationAge != null)
        'notif=${lastNotificationAge!.inSeconds}s',
      if (appCause != null) 'cause=$appCause',
    ].join(' ');
  }
}
