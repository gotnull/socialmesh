import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';

/// BLE implementation of DeviceTransport
class BleTransport implements DeviceTransport {
  late final Logger _logger;
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _fromNumCharacteristic;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription? _fromNumSubscription;
  Timer? _pollingTimer;

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  // Meshtastic BLE service and characteristic UUIDs (from official docs)
  // https://meshtastic.org/docs/development/device/client-api/
  static const String _serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
  static const String _toRadioUuid = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
  static const String _fromRadioUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
  static const String _fromNumUuid = 'ed9da18c-a800-4f66-a670-aa7547e34453';

  // Device Information Service UUIDs (standard BLE)
  static const String _deviceInfoServiceUuid = '180a';
  static const String _modelNumberUuid = '2a24';
  static const String _manufacturerNameUuid = '2a29';

  // Cached device info from Device Information Service
  String? _bleModelNumber;
  String? _bleManufacturerName;

  /// Get the BLE model number read from Device Information Service
  @override
  String? get bleModelNumber => _bleModelNumber;

  /// Get the BLE manufacturer name read from Device Information Service
  @override
  String? get bleManufacturerName => _bleManufacturerName;

  BleTransport()
    : _stateController = StreamController<DeviceConnectionState>.broadcast(),
      _dataController = StreamController<List<int>>.broadcast() {
    _logger = AppLogging.bleLogger;
  }

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false; // BLE uses raw protobufs, no framing

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
    _logger.i('📡 BLE_TRANSPORT: scan() called');

    try {
      // Check if Bluetooth is supported
      _logger.i('📡 BLE_TRANSPORT: Checking if BT is supported...');
      if (!await FlutterBluePlus.isSupported) {
        _logger.e('📡 BLE_TRANSPORT: Bluetooth not supported');
        throw Exception('Bluetooth is not supported on this device');
      }
      _logger.i('📡 BLE_TRANSPORT: BT is supported');

      // Wait for Bluetooth adapter to be ready (up to 3 seconds)
      _logger.i('📡 BLE_TRANSPORT: Checking adapter state...');
      final adapterState = await FlutterBluePlus.adapterState
          .where(
            (s) =>
                s == BluetoothAdapterState.on || s == BluetoothAdapterState.off,
          )
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.unknown,
          );

      _logger.i('📡 BLE_TRANSPORT: Adapter state = $adapterState');

      if (adapterState == BluetoothAdapterState.off) {
        _logger.e('📡 BLE_TRANSPORT: Bluetooth is turned off');
        throw Exception('Please turn on Bluetooth to scan for devices');
      }

      if (adapterState == BluetoothAdapterState.unknown) {
        _logger.w(
          '📡 BLE_TRANSPORT: Bluetooth state unknown, attempting scan anyway...',
        );
      }

      final scanDuration = timeout ?? const Duration(seconds: 10);
      _logger.i('📡 BLE_TRANSPORT: Scan duration = ${scanDuration.inSeconds}s');

      // Stop any existing scan first
      _logger.i('📡 BLE_TRANSPORT: Stopping any existing scan...');
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        _logger.w('📡 BLE_TRANSPORT: stopScan error (ignored): $e');
      }

      // Small delay to let BLE subsystem settle
      _logger.i('📡 BLE_TRANSPORT: Waiting 300ms for BLE to settle...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Try to start scan with retry for transient states
      int retryCount = 0;
      const maxRetries = 3;
      _logger.i('📡 BLE_TRANSPORT: Starting scan (max $maxRetries retries)...');

      while (retryCount < maxRetries) {
        try {
          _logger.i(
            '📡 BLE_TRANSPORT: Calling FlutterBluePlus.startScan() (attempt ${retryCount + 1})...',
          );
          await FlutterBluePlus.startScan(
            timeout: scanDuration,
            withServices: [Guid(_serviceUuid)],
          );
          _logger.i('📡 BLE_TRANSPORT: startScan() completed successfully');
          break; // Success, exit retry loop
        } catch (e) {
          retryCount++;
          final errorStr = e.toString();
          _logger.w('📡 BLE_TRANSPORT: startScan() error: $errorStr');
          // Handle transient Bluetooth states
          if (errorStr.contains('CBManagerStateUnknown') ||
              errorStr.contains('bluetooth must be turned on') ||
              errorStr.contains('Bluetooth adapter is not available')) {
            if (retryCount < maxRetries) {
              _logger.w(
                '📡 BLE_TRANSPORT: Bluetooth not ready (attempt $retryCount/$maxRetries), retrying...',
              );
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
              continue;
            }
            // All retries exhausted
            throw Exception(
              'Bluetooth is not ready. Please ensure Bluetooth is enabled and try again.',
            );
          }
          rethrow;
        }
      }

      // Create timer to complete scan after timeout
      final scanCompleter = Completer<void>();
      final timer = Timer(scanDuration + const Duration(milliseconds: 500), () {
        _logger.i('📡 BLE_TRANSPORT: Scan timeout timer fired');
        if (!scanCompleter.isCompleted) {
          scanCompleter.complete();
        }
      });

      // Yield results until timeout
      _logger.i('📡 BLE_TRANSPORT: Listening to scanResults stream...');
      int deviceCount = 0;
      await for (final result in FlutterBluePlus.scanResults) {
        if (scanCompleter.isCompleted) {
          _logger.i('📡 BLE_TRANSPORT: Scan completer completed, breaking');
          break;
        }

        _logger.d(
          '📡 BLE_TRANSPORT: scanResults batch received, ${result.length} items',
        );
        for (final r in result) {
          deviceCount++;
          _logger.i(
            '📡 BLE_TRANSPORT: Found device #$deviceCount: ${r.device.remoteId} (${r.device.platformName})',
          );
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

      _logger.i(
        '📡 BLE_TRANSPORT: Scan stream ended, found $deviceCount devices total',
      );
      timer.cancel();
    } catch (e) {
      _logger.e('📡 BLE_TRANSPORT: BLE scan error: $e');
      rethrow;
    } finally {
      _logger.i('📡 BLE_TRANSPORT: Finally block, stopping scan...');
      await FlutterBluePlus.stopScan();
      _logger.i('📡 BLE_TRANSPORT: Scan stopped');
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    // Force cleanup any stale state before connecting
    // This fixes issues where PIN cancellation leaves BLE in a weird state
    if (_state == DeviceConnectionState.connecting) {
      _logger.w('Already connecting - forcing cleanup first');
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    } else if (_state == DeviceConnectionState.connected) {
      _logger.w('Already connected');
      return;
    } else if (_state == DeviceConnectionState.error) {
      _logger.w('Was in error state - cleaning up first');
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
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

        // If device is already connected from another app or stale connection, disconnect first
        if (_device!.isConnected) {
          _logger.w('Device already connected, forcing disconnect...');
          try {
            await _device!.disconnect();
          } catch (e) {
            _logger.w('Pre-connect disconnect error (ignored): $e');
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        _device = BluetoothDevice.fromId(device.id);
      }

      // Connect to device - simple and reliable
      _logger.d('Initiating BLE connection...');
      await _device!.connect(license: License.free, autoConnect: false);

      // Device is now connected, discover services immediately
      _logger.i('Connection established, discovering services...');

      // Request MTU size 512 per Meshtastic docs
      try {
        await _device!.requestMtu(512);
      } catch (e) {
        _logger.w('MTU request failed (may not be supported): $e');
      }

      await _discoverServices();

      // Set up listener for disconnection events
      _deviceStateSubscription = _device!.connectionState.listen((state) {
        _logger.d('Connection state changed: $state');
        if (state == BluetoothConnectionState.disconnected) {
          _logger.w('Device disconnected');
          _updateState(DeviceConnectionState.disconnected);
        }
      });
    } catch (e) {
      _logger.e('Connection error: $e');
      await disconnect();
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

      // Try to read model number from Device Information Service (0x180A)
      await _readDeviceModelNumber(services);

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
        } else if (uuid == _fromNumUuid.toLowerCase()) {
          _fromNumCharacteristic = characteristic;
          _logger.d('Found fromNum characteristic');
        }
      }

      if (_txCharacteristic != null && _rxCharacteristic != null) {
        _updateState(DeviceConnectionState.connected);
        _logger.i('Connected successfully');

        // Perform initial read from fromRadio to wake up the device
        if (_rxCharacteristic != null) {
          try {
            final initialData = await _rxCharacteristic!.read();
            if (initialData.isNotEmpty) {
              _dataController.add(initialData);
            }
          } catch (e) {
            _logger.d('Initial read error (ignored): $e');
          }
        }

        // If fromNum is not available, fall back to polling
        if (_fromNumCharacteristic == null) {
          _logger.w('fromNum not available, using polling fallback');
          _startPolling();
        }
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

  /// Read device info from Device Information Service (0x180A)
  Future<void> _readDeviceModelNumber(List<BluetoothService> services) async {
    AppLogging.ble('Searching for Device Information Service (0x180A)...');
    try {
      // Find Device Information Service
      final deviceInfoService = services.cast<BluetoothService?>().firstWhere(
        (s) => s?.uuid.toString().toLowerCase() == _deviceInfoServiceUuid,
        orElse: () => null,
      );

      if (deviceInfoService == null) {
        AppLogging.ble('Device Information Service (0x180A) not found');
        _logger.d('Device Information Service (0x180A) not found');
        return;
      }
      AppLogging.ble('Found Device Information Service');

      // Read all characteristics for debugging
      for (final char in deviceInfoService.characteristics) {
        try {
          final data = await char.read();
          final value = String.fromCharCodes(data).trim();
          AppLogging.ble('Device Info ${char.uuid}: "$value" (raw: $data)');

          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == _modelNumberUuid) {
            _bleModelNumber = value;
          } else if (uuid == _manufacturerNameUuid) {
            _bleManufacturerName = value;
          }
        } catch (e) {
          AppLogging.ble('Could not read ${char.uuid}: $e');
        }
      }

      AppLogging.ble(
        'Model="$_bleModelNumber", '
        'Manufacturer="$_bleManufacturerName"',
      );
    } catch (e) {
      AppLogging.ble('Device Info read error: $e');
      _logger.d('Could not read device info: $e');
    }
  }

  /// Check if an error indicates BLE authentication/pairing failure
  bool _isAuthenticationError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('authentication') ||
        errorStr.contains('encryption') ||
        errorStr.contains('insufficient') ||
        errorStr.contains('pairing');
  }

  /// Enable fromNum notifications after initial config download
  /// Per Meshtastic docs, this should be called AFTER config is received
  @override
  Future<void> enableNotifications() async {
    if (_fromNumCharacteristic == null) {
      _logger.w(
        'Cannot enable notifications: fromNum characteristic not found',
      );
      return;
    }

    try {
      final canNotify = _fromNumCharacteristic!.properties.notify;
      final canIndicate = _fromNumCharacteristic!.properties.indicate;

      if (!canNotify && !canIndicate) {
        _logger.w('fromNum does not support notifications');
        return;
      }

      await _fromNumCharacteristic!.setNotifyValue(true);

      _fromNumSubscription = _fromNumCharacteristic!.lastValueStream.listen(
        (value) async {
          // fromNum value is just a counter - read fromRadio regardless
          if (_rxCharacteristic != null) {
            _logger.d('fromNum notified, reading fromRadio');
            try {
              // Read from fromRadio until empty
              while (true) {
                final data = await _rxCharacteristic!.read();
                if (data.isEmpty) break;
                _logger.d('Read ${data.length} bytes from fromRadio');
                _dataController.add(data);
              }
            } catch (e) {
              _logger.e('Error reading fromRadio: $e');
              if (_isAuthenticationError(e)) {
                _logger.e('Authentication error - PIN may have been cancelled');
                _updateState(DeviceConnectionState.error);
              }
            }
          }
        },
        onError: (error) {
          _logger.e('fromNum error: $error');
          if (_isAuthenticationError(error)) {
            _logger.e(
              'Authentication error in notification - PIN may have been cancelled',
            );
            _updateState(DeviceConnectionState.error);
          }
        },
      );
      _logger.i('fromNum notifications enabled');
    } catch (e) {
      _logger.e('Error enabling notifications: $e');
      if (_isAuthenticationError(e)) {
        _logger.e(
          'Authentication error enabling notifications - PIN cancelled',
        );
        _updateState(DeviceConnectionState.error);
        rethrow;
      }
    }
  }

  void _startPolling() {
    _logger.d('Starting polling for fromRadio characteristic');

    // Poll every 100ms for new data
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (_rxCharacteristic == null ||
          _state != DeviceConnectionState.connected) {
        _pollingTimer?.cancel();
        return;
      }

      try {
        final value = await _rxCharacteristic!.read();
        if (value.isNotEmpty) {
          _logger.d('Polled ${value.length} bytes');
          _dataController.add(value);
        }
      } catch (e) {
        _logger.e('Polling error: $e');
      }
    });
  }

  /// Track consecutive auth errors for polling
  int _consecutiveAuthErrors = 0;

  @override
  Future<void> pollOnce() async {
    if (_rxCharacteristic == null ||
        _state != DeviceConnectionState.connected) {
      return;
    }

    try {
      final value = await _rxCharacteristic!.read();
      _consecutiveAuthErrors = 0; // Reset on success
      if (value.isNotEmpty) {
        _logger.d('Polled ${value.length} bytes');
        _dataController.add(value);
      }
    } catch (e) {
      _logger.e('Polling error: $e');
      if (_isAuthenticationError(e)) {
        _consecutiveAuthErrors++;
        _logger.e(
          'Authentication error during poll (count: $_consecutiveAuthErrors)',
        );
        // After 3 consecutive auth errors, assume PIN was cancelled
        if (_consecutiveAuthErrors >= 3) {
          _logger.e(
            'Multiple auth errors - PIN likely cancelled, transitioning to error state',
          );
          _updateState(DeviceConnectionState.error);
        }
      }
    }
  }

  @override
  Future<void> disconnect() async {
    // Don't skip cleanup based on state - force full cleanup every time
    // This fixes issues where PIN cancellation leaves stale BLE state
    final wasDisconnected = _state == DeviceConnectionState.disconnected;

    if (!wasDisconnected) {
      _updateState(DeviceConnectionState.disconnecting);
    }

    try {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      await _characteristicSubscription?.cancel();
      await _fromNumSubscription?.cancel();
      await _deviceStateSubscription?.cancel();

      if (_device != null) {
        try {
          await _device!.disconnect();
        } catch (e) {
          _logger.w('Device disconnect error (ignored): $e');
        }
      }

      _device = null;
      _txCharacteristic = null;
      _rxCharacteristic = null;
      _characteristicSubscription = null;
      _deviceStateSubscription = null;
      _fromNumSubscription = null;
      _consecutiveAuthErrors = 0;

      if (!wasDisconnected) {
        _updateState(DeviceConnectionState.disconnected);
        _logger.i('Disconnected');
      }
    } catch (e) {
      _logger.e('Disconnect error: $e');
      // Still clean up state even on error
      _device = null;
      _txCharacteristic = null;
      _rxCharacteristic = null;
      _updateState(DeviceConnectionState.disconnected);
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

      // Use flutter_blue_plus's built-in long write support.
      // Meshtastic expects complete ToRadio protobuf messages in a single
      // logical write operation. The BLE stack handles ATT-layer chunking
      // via the "Prepare Write" / "Execute Write" protocol when needed.
      // allowLongWrite: true enables this for data > MTU size.
      await _txCharacteristic!.write(
        data,
        withoutResponse: false,
        allowLongWrite: true,
      );

      _logger.d('Sent successfully');
    } catch (e) {
      _logger.e('Send error: $e');

      // Check if this is a disconnection error and update state accordingly
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('disconnect') ||
          errorStr.contains('not connected') ||
          errorStr.contains('connection') ||
          errorStr.contains('invalid') ||
          errorStr.contains('peripheral')) {
        _logger.w('Device appears to have disconnected during send');
        // Trigger disconnection cleanup if device disconnected mid-send
        if (_state == DeviceConnectionState.connected) {
          _txCharacteristic = null;
          _rxCharacteristic = null;
          _device = null;
          _updateState(DeviceConnectionState.disconnected);
        }
      }

      rethrow;
    }
  }

  @override
  Future<int?> readRssi() async {
    if (_device == null || _state != DeviceConnectionState.connected) {
      return null;
    }

    try {
      final rssi = await _device!.readRssi();
      return rssi;
    } catch (e) {
      _logger.w('Failed to read RSSI: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
  }
}
