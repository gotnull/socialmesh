// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../core/meshcore_constants.dart';
import '../../models/mesh_device.dart';
import 'mesh_transport.dart';

/// Exception thrown when MeshCore UART service is not found.
class MeshCoreServiceNotFoundException implements Exception {
  final String message;
  const MeshCoreServiceNotFoundException(this.message);

  @override
  String toString() => 'MeshCoreServiceNotFoundException: $message';
}

/// Exception thrown when MeshCore UART characteristics are missing.
class MeshCoreCharacteristicNotFoundException implements Exception {
  final String message;
  final MeshProtocolError error;
  const MeshCoreCharacteristicNotFoundException(this.message, this.error);

  @override
  String toString() => 'MeshCoreCharacteristicNotFoundException: $message';
}

/// MeshCore BLE transport implementation.
///
/// This class handles BLE communication with MeshCore devices, including:
/// - Connection establishment
/// - Service/characteristic discovery (Nordic UART Service)
/// - Notification subscription
/// - Byte-level send/receive
///
/// It does NOT handle protocol framing - that's the adapter's job.
///
/// Key differences from Meshtastic BLE:
/// - Uses Nordic UART Service (6e400001-...) NOT Meshtastic service
/// - Does NOT require Device Information Service (0x180A)
/// - TX char (6e400002) is write-to-device
/// - RX char (6e400003) is notify-from-device
class MeshCoreBleTransport implements MeshTransport {
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;
  final StreamController<Uint8List> _rawRxController;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  MeshCoreBleTransport()
    : _stateController = StreamController<DeviceConnectionState>.broadcast(),
      _dataController = StreamController<List<int>>.broadcast(),
      _rawRxController = StreamController<Uint8List>.broadcast();

  @override
  TransportType get transportType => TransportType.ble;

  @override
  DeviceConnectionState get connectionState => _state;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  /// Raw receive stream for debugging.
  ///
  /// Every BLE notification is pushed here as raw bytes without any processing.
  /// This is useful for debugging and protocol analysis.
  Stream<Uint8List> get rawRxStream => _rawRxController.stream;

  void _updateState(DeviceConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      AppLogging.ble('MeshCore BLE state changed to: $newState');
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (_state == DeviceConnectionState.connecting ||
        _state == DeviceConnectionState.connected) {
      AppLogging.ble('MeshCore: Already connected or connecting');
      return;
    }

    _updateState(DeviceConnectionState.connecting);

    try {
      AppLogging.ble('MeshCore: Connecting to ${device.name}...');

      // Get or create BluetoothDevice
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      try {
        _device = systemDevices.firstWhere(
          (d) => d.remoteId.toString() == device.id,
        );
      } catch (_) {
        _device = BluetoothDevice.fromId(device.id);
      }

      // Connect
      await _device!.connect(
        license: License.free,
        autoConnect: false,
        mtu: null,
        timeout: MeshCoreTimeouts.connection,
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (!_device!.isConnected) {
        throw Exception('Device disconnected during setup');
      }

      AppLogging.ble(
        'MeshCore: Connection established, discovering services...',
      );
      await _discoverServicesAndSubscribe();

      // Set up disconnection listener
      _deviceStateSubscription = _device!.connectionState.listen((state) {
        AppLogging.ble('MeshCore: BLE state changed: $state');
        if (state == BluetoothConnectionState.disconnected) {
          _updateState(DeviceConnectionState.disconnected);
        }
      });

      _updateState(DeviceConnectionState.connected);
      AppLogging.ble('MeshCore: Connected and ready');
    } catch (e) {
      AppLogging.ble('MeshCore: Connection error: $e');
      await disconnect();
      _updateState(DeviceConnectionState.error);
      rethrow;
    }
  }

  Future<void> _discoverServicesAndSubscribe() async {
    final services = await _device!.discoverServices();

    // Log all discovered services for debugging
    AppLogging.ble('MeshCore: Found ${services.length} services');
    for (final svc in services) {
      AppLogging.ble('MeshCore: Service: ${svc.uuid}');
      for (final char in svc.characteristics) {
        AppLogging.ble('MeshCore:   Char: ${char.uuid}');
      }
    }

    // Find MeshCore Nordic UART service (6e400001-...)
    // NOTE: We do NOT look for Device Information Service (0x180A) - it's optional
    BluetoothService? meshCoreService;
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          MeshCoreBleUuids.serviceUuid.toLowerCase()) {
        meshCoreService = service;
        break;
      }
    }

    if (meshCoreService == null) {
      AppLogging.ble(
        'MeshCore: Nordic UART service not found (${MeshCoreBleUuids.serviceUuid})',
      );
      throw MeshCoreServiceNotFoundException(
        'MeshCore Nordic UART service (${MeshCoreBleUuids.serviceUuid}) not found. '
        'This device may not be a MeshCore device.',
      );
    }

    AppLogging.ble(
      'MeshCore: Found Nordic UART service, discovering characteristics...',
    );

    // Find characteristics - TX (6e400002) and RX/notify (6e400003)
    for (final char in meshCoreService.characteristics) {
      final uuid = char.uuid.toString().toLowerCase();
      if (uuid == MeshCoreBleUuids.writeCharacteristicUuid.toLowerCase()) {
        _writeCharacteristic = char;
        AppLogging.ble('MeshCore: Found TX characteristic (6e400002)');
      } else if (uuid ==
          MeshCoreBleUuids.notifyCharacteristicUuid.toLowerCase()) {
        _notifyCharacteristic = char;
        AppLogging.ble('MeshCore: Found RX/notify characteristic (6e400003)');
      }
    }

    // Validate required characteristics
    if (_writeCharacteristic == null) {
      AppLogging.ble(
        'MeshCore: TX characteristic not found (${MeshCoreBleUuids.writeCharacteristicUuid})',
      );
      throw MeshCoreCharacteristicNotFoundException(
        'MeshCore TX characteristic (${MeshCoreBleUuids.writeCharacteristicUuid}) not found',
        MeshProtocolError.unsupportedDevice,
      );
    }
    if (_notifyCharacteristic == null) {
      AppLogging.ble(
        'MeshCore: RX characteristic not found (${MeshCoreBleUuids.notifyCharacteristicUuid})',
      );
      throw MeshCoreCharacteristicNotFoundException(
        'MeshCore RX characteristic (${MeshCoreBleUuids.notifyCharacteristicUuid}) not found',
        MeshProtocolError.unsupportedDevice,
      );
    }

    // Subscribe to notifications
    AppLogging.ble('MeshCore: Subscribing to RX notifications...');
    await _notifyCharacteristic!.setNotifyValue(true);

    _notifySubscription = _notifyCharacteristic!.onValueReceived.listen(
      (data) {
        AppLogging.ble('MeshCore: Received ${data.length} bytes');
        // Push to raw debug stream
        _rawRxController.add(Uint8List.fromList(data));
        // Push to normal data stream
        _dataController.add(data);
      },
      onError: (e) {
        AppLogging.ble('MeshCore: Notify error: $e');
      },
    );

    AppLogging.ble('MeshCore: Characteristic setup complete');
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    if (_writeCharacteristic == null || !isConnected) {
      throw Exception('MeshCore: Not connected');
    }

    AppLogging.ble('MeshCore: Sending ${data.length} bytes');
    await _writeCharacteristic!.write(data, withoutResponse: false);
  }

  /// Send raw bytes to the device (debug/low-level API).
  ///
  /// This is the same as sendBytes but takes Uint8List for consistency
  /// with the raw receive stream.
  Future<void> sendRaw(Uint8List data) async {
    await sendBytes(data);
  }

  @override
  Future<void> disconnect() async {
    AppLogging.ble('MeshCore: Disconnecting...');

    // Debug: Log stack trace to identify disconnect caller
    if (kDebugMode) {
      AppLogging.ble(
        'MeshCore transport disconnect() called from:\n${StackTrace.current}',
      );
    }

    _updateState(DeviceConnectionState.disconnecting);

    await _notifySubscription?.cancel();
    _notifySubscription = null;

    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    try {
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(false);
      }
    } catch (_) {}

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;

    _updateState(DeviceConnectionState.disconnected);
    AppLogging.ble('MeshCore: Disconnected');
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
    await _rawRxController.close();
  }
}
