// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import '../logging.dart';
import '../transport.dart';

/// No-op [DeviceTransport] used when a capability-driven provider would
/// otherwise return `null` or crash on an unsupported platform.
///
/// Returned by `bleScanTransportProvider` when `!supportsBle`, and by
/// `transportProvider` when no transport is supported on the current
/// host. Consumers stay typed, scan/connect/send all no-op cleanly, and
/// the original requested [TransportType] is preserved so logs reflect
/// what the caller asked for (not just the fallback shape).
class NoopDeviceTransport implements DeviceTransport {
  @override
  final TransportType type;

  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  NoopDeviceTransport(this.type);

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  bool get isConnected => false;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) {
    AppLogging.platform('NoopDeviceTransport($type): scan() ignored');
    return const Stream<DeviceInfo>.empty();
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    AppLogging.platform(
      'NoopDeviceTransport($type): connect() ignored for ${device.id}',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {
    AppLogging.platform(
      'NoopDeviceTransport($type): send() ignored (${data.length} bytes)',
    );
  }

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
  }
}
