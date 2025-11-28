import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import '../../core/transport.dart';

/// BLE implementation of DeviceTransport
class BleTransport implements DeviceTransport {
  final Logger _logger;
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  // Meshtastic BLE service and characteristic UUIDs (from official docs)
  // https://meshtastic.org/docs/development/device/client-api/
  static const String _serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
  static const String _toRadioUuid = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
  static const String _fromRadioUuid = '2c55e69e-4993-11ed-b878-0242ac120002';

  BleTransport({Logger? logger})
    : _logger = logger ?? Logger(),
      _stateController = StreamController<DeviceConnectionState>.broadcast(),
      _dataController = StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  void _updateState(DeviceConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _logger.d('BLE state changed to: $newState');
    }
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout}) async* {
    _logger.i('Starting BLE scan...');

    try {
      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        _logger.e('Bluetooth not supported');
        throw Exception('Bluetooth is not supported on this device');
      }

      // Wait for adapter state with timeout
      BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
      try {
        adapterState = await FlutterBluePlus.adapterState
            .firstWhere(
              (state) => state != BluetoothAdapterState.unknown,
              orElse: () => BluetoothAdapterState.unknown,
            )
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => BluetoothAdapterState.unknown,
            );
      } catch (e) {
        _logger.w('Error getting adapter state: $e');
      }

      // Check if Bluetooth is on or unknown (iOS may report unknown even when on)
      if (adapterState == BluetoothAdapterState.off) {
        _logger.w('Bluetooth is off');
        throw Exception('Please turn on Bluetooth to scan for devices');
      } else if (adapterState == BluetoothAdapterState.unauthorized) {
        _logger.w('Bluetooth permission not granted');
        throw Exception('Please grant Bluetooth permission in Settings');
      }

      _logger.d('Bluetooth adapter state: $adapterState');

      // Start scanning
      final scanDuration = timeout ?? const Duration(seconds: 10);
      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        withServices: [Guid(_serviceUuid)],
      );

      // Create timer to complete scan after timeout
      final scanCompleter = Completer<void>();
      final timer = Timer(scanDuration + const Duration(milliseconds: 500), () {
        if (!scanCompleter.isCompleted) {
          scanCompleter.complete();
        }
      });

      // Yield results until timeout
      await for (final result in FlutterBluePlus.scanResults) {
        if (scanCompleter.isCompleted) break;

        for (final r in result) {
          yield DeviceInfo(
            id: r.device.remoteId.toString(),
            name: r.device.platformName.isNotEmpty
                ? r.device.platformName
                : 'Unknown Meshtastic Device',
            type: TransportType.ble,
            address: r.device.remoteId.toString(),
            rssi: r.rssi,
          );
        }
      }

      timer.cancel();
    } catch (e) {
      _logger.e('BLE scan error: $e');
      rethrow;
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (_state == DeviceConnectionState.connected ||
        _state == DeviceConnectionState.connecting) {
      _logger.w('Already connected or connecting');
      return;
    }

    _updateState(DeviceConnectionState.connecting);

    try {
      _logger.i('Connecting to ${device.name}...');

      // Find the device
      final List<BluetoothDevice> systemDevices =
          await FlutterBluePlus.systemDevices([]);
      try {
        _device = systemDevices.firstWhere(
          (d) => d.remoteId.toString() == device.id,
        );

        // If device is already connected from another app, disconnect first
        if (_device!.isConnected) {
          _logger.w('Device already connected, forcing disconnect...');
          await _device!.disconnect();
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _device = BluetoothDevice.fromId(device.id);
      }

      // Connect
      await _device!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Listen to connection state
      _deviceStateSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _discoverServices();
        } else if (state == BluetoothConnectionState.disconnected) {
          _updateState(DeviceConnectionState.disconnected);
        }
      });
    } catch (e) {
      _logger.e('Connection error: $e');
      _updateState(DeviceConnectionState.error);
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    try {
      _logger.d('Discovering services...');

      final services = await _device!.discoverServices();

      // Log all discovered services and characteristics
      _logger.d('Found ${services.length} services');
      for (final svc in services) {
        _logger.d('Service: ${svc.uuid}');
        for (final char in svc.characteristics) {
          _logger.d('  Characteristic: ${char.uuid}');
        }
      }

      // Find Meshtastic service
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
      );

      // Find characteristics
      for (final characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        _logger.d('Checking characteristic: $uuid');

        if (uuid == _toRadioUuid.toLowerCase()) {
          _txCharacteristic = characteristic;
          _logger.d('Found TX characteristic (toRadio)');
        } else if (uuid == _fromRadioUuid.toLowerCase()) {
          _rxCharacteristic = characteristic;
          _logger.d('Found RX characteristic (fromRadio)');

          // Subscribe to notifications
          await characteristic.setNotifyValue(true);
          _characteristicSubscription = characteristic.lastValueStream.listen(
            (value) {
              if (value.isNotEmpty) {
                _logger.d('Received ${value.length} bytes');
                _dataController.add(value);
              }
            },
            onError: (error) {
              _logger.e('Characteristic error: $error');
            },
          );
        }
      }

      if (_txCharacteristic != null && _rxCharacteristic != null) {
        _updateState(DeviceConnectionState.connected);
        _logger.i('Connected successfully');
      } else {
        final missing = <String>[];
        if (_txCharacteristic == null) missing.add('TX');
        if (_rxCharacteristic == null) missing.add('RX');
        _logger.e('Missing characteristics: ${missing.join(", ")}');
        throw Exception(
          'Missing ${missing.join(" and ")} characteristic(s). '
          'Try power cycling the device.',
        );
      }
    } catch (e) {
      _logger.e('Service discovery error: $e');
      await disconnect();
      _updateState(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_state == DeviceConnectionState.disconnected) {
      return;
    }

    _updateState(DeviceConnectionState.disconnecting);

    try {
      await _characteristicSubscription?.cancel();
      await _deviceStateSubscription?.cancel();

      if (_device != null) {
        await _device!.disconnect();
      }

      _device = null;
      _txCharacteristic = null;
      _rxCharacteristic = null;
      _characteristicSubscription = null;
      _deviceStateSubscription = null;

      _updateState(DeviceConnectionState.disconnected);
      _logger.i('Disconnected');
    } catch (e) {
      _logger.e('Disconnect error: $e');
      _updateState(DeviceConnectionState.error);
    }
  }

  @override
  Future<void> send(List<int> data) async {
    if (_state != DeviceConnectionState.connected) {
      throw Exception('Not connected');
    }

    if (_txCharacteristic == null) {
      throw Exception('TX characteristic not available');
    }

    try {
      _logger.d('Sending ${data.length} bytes');

      // BLE has MTU limits, so we may need to chunk large packets
      const int mtu = 20; // Conservative MTU size

      for (int i = 0; i < data.length; i += mtu) {
        final end = (i + mtu < data.length) ? i + mtu : data.length;
        final chunk = data.sublist(i, end);

        await _txCharacteristic!.write(chunk, withoutResponse: false);

        // Small delay between chunks to avoid overwhelming the device
        if (end < data.length) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }

      _logger.d('Sent successfully');
    } catch (e) {
      _logger.e('Send error: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
  }
}
