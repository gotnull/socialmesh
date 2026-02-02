// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/logging.dart';
import '../../core/meshcore_constants.dart';
import '../../core/transport.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Exception thrown when Meshtastic BLE service is not found on a device.
///
/// This typically occurs when connecting to a device that runs a different
/// protocol (e.g., MeshCore) or is not a mesh radio at all.
class MeshtasticServiceNotFoundException implements Exception {
  final String message;
  const MeshtasticServiceNotFoundException(this.message);

  @override
  String toString() => 'MeshtasticServiceNotFoundException: $message';
}

/// BLE implementation of DeviceTransport
class BleTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;
  final StreamController<pb.LogRecord> _deviceLogController;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _fromNumCharacteristic;
  BluetoothCharacteristic? _logRadioCharacteristic;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription? _fromNumSubscription;
  StreamSubscription? _logRadioSubscription;
  Timer? _pollingTimer;

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  // Meshtastic BLE service and characteristic UUIDs (from official docs)
  // https://meshtastic.org/docs/development/device/client-api/
  static const String _serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
  static const String _toRadioUuid = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
  static const String _fromRadioUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
  static const String _fromNumUuid = 'ed9da18c-a800-4f66-a670-aa7547e34453';
  // LogRadio characteristic - streams LogRecord protobufs from device firmware
  static const String _logRadioUuid = '5a3d6e49-06e6-4423-9944-e9de8cdf9547';

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
      _dataController = StreamController<List<int>>.broadcast(),
      _deviceLogController = StreamController<pb.LogRecord>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  /// Stream of device firmware log records (from LogRadio BLE characteristic)
  Stream<pb.LogRecord> get deviceLogStream => _deviceLogController.stream;

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
      AppLogging.ble('BLE state changed to: $newState');
    }
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) {
    AppLogging.ble('📡 BLE_TRANSPORT: scan() called (scanAll: $scanAll)');

    // Use a StreamController so we can properly cancel the scan
    // The old await for approach didn't exit when stopScan() was called,
    // causing race conditions where multiple scans interfered with each other
    final controller = StreamController<DeviceInfo>();
    StreamSubscription<List<ScanResult>>? scanSubscription;
    Timer? timeoutTimer;
    int deviceCount = 0;
    bool scanStarted = false;

    // Start the scan asynchronously
    () async {
      try {
        // Check if Bluetooth is supported
        AppLogging.ble('📡 BLE_TRANSPORT: Checking if BT is supported...');
        if (!await FlutterBluePlus.isSupported) {
          AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: Bluetooth not supported');
          controller.addError(
            Exception('Bluetooth is not supported on this device'),
          );
          return;
        }
        AppLogging.ble('📡 BLE_TRANSPORT: BT is supported');

        // Wait for Bluetooth adapter to be ready (up to 3 seconds)
        AppLogging.ble('📡 BLE_TRANSPORT: Checking adapter state...');
        final adapterState = await FlutterBluePlus.adapterState
            .where(
              (s) =>
                  s == BluetoothAdapterState.on ||
                  s == BluetoothAdapterState.off,
            )
            .first
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => BluetoothAdapterState.unknown,
            );

        AppLogging.ble('📡 BLE_TRANSPORT: Adapter state = $adapterState');

        if (adapterState == BluetoothAdapterState.off) {
          AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: Bluetooth is turned off');
          controller.addError(
            Exception('Please turn on Bluetooth to scan for devices'),
          );
          return;
        }

        if (adapterState == BluetoothAdapterState.unknown) {
          AppLogging.ble(
            '⚠️ 📡 BLE_TRANSPORT: Bluetooth state unknown, attempting scan anyway...',
          );
        }

        final scanDuration = timeout ?? const Duration(seconds: 10);
        AppLogging.ble(
          '📡 BLE_TRANSPORT: Scan duration = ${scanDuration.inSeconds}s',
        );

        // Stop any existing scan first
        AppLogging.ble('📡 BLE_TRANSPORT: Stopping any existing scan...');
        try {
          await FlutterBluePlus.stopScan();
        } catch (e) {
          AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: stopScan error (ignored): $e');
        }

        // Small delay to let BLE subsystem settle
        AppLogging.ble('📡 BLE_TRANSPORT: Waiting 300ms for BLE to settle...');
        await Future.delayed(const Duration(milliseconds: 300));

        // Check if controller was closed while waiting
        if (controller.isClosed) {
          AppLogging.ble('📡 BLE_TRANSPORT: Controller closed during setup');
          return;
        }

        // Try to start scan with retry for transient states
        int retryCount = 0;
        const maxRetries = 3;
        AppLogging.ble(
          '📡 BLE_TRANSPORT: Starting scan (max $maxRetries retries)...',
        );

        while (retryCount < maxRetries) {
          try {
            // Build service filter list for logging
            final serviceFilters = scanAll
                ? <String>[]
                : [_serviceUuid, MeshCoreBleUuids.serviceUuid];
            AppLogging.ble(
              '📡 BLE_TRANSPORT: Calling FlutterBluePlus.startScan() '
              '(attempt ${retryCount + 1}, scanAll=$scanAll, '
              'serviceFilters=${serviceFilters.isEmpty ? "NONE" : serviceFilters})...',
            );
            // When scanAll is true, scan without service filter to see ALL devices
            // When false, filter by Meshtastic AND MeshCore service UUIDs
            await FlutterBluePlus.startScan(
              timeout: scanDuration,
              withServices: scanAll
                  ? []
                  : [Guid(_serviceUuid), Guid(MeshCoreBleUuids.serviceUuid)],
            );
            AppLogging.ble(
              '📡 BLE_TRANSPORT: startScan() completed successfully',
            );
            scanStarted = true;
            break; // Success, exit retry loop
          } catch (e) {
            retryCount++;
            final errorStr = e.toString();
            AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: startScan() error: $errorStr');
            // Handle transient Bluetooth states
            if (errorStr.contains('CBManagerStateUnknown') ||
                errorStr.contains('bluetooth must be turned on') ||
                errorStr.contains('Bluetooth adapter is not available')) {
              if (retryCount < maxRetries) {
                AppLogging.ble(
                  '⚠️ 📡 BLE_TRANSPORT: Bluetooth not ready (attempt $retryCount/$maxRetries), retrying...',
                );
                await Future.delayed(Duration(milliseconds: 500 * retryCount));
                continue;
              }
              // All retries exhausted
              controller.addError(
                Exception(
                  'Bluetooth is not ready. Please ensure Bluetooth is enabled and try again.',
                ),
              );
              return;
            }
            controller.addError(e);
            return;
          }
        }

        // Set up timeout timer
        timeoutTimer = Timer(
          scanDuration + const Duration(milliseconds: 500),
          () {
            AppLogging.ble('📡 BLE_TRANSPORT: Scan timeout timer fired');
            _finishScan(
              controller,
              scanSubscription,
              timeoutTimer,
              deviceCount,
              scanStarted,
            );
          },
        );

        // Subscribe to scan results
        AppLogging.ble('📡 BLE_TRANSPORT: Listening to scanResults stream...');
        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) {
            if (controller.isClosed) return;

            AppLogging.ble(
              '📡 BLE_TRANSPORT: scanResults batch received, ${results.length} items',
            );
            for (final r in results) {
              deviceCount++;
              // Extract advertisement data
              final serviceUuids = r.advertisementData.serviceUuids
                  .map((guid) => guid.toString().toLowerCase())
                  .toList();
              final manufacturerData = r.advertisementData.manufacturerData.map(
                (key, value) => MapEntry(key, value.toList()),
              );
              AppLogging.ble(
                '📡 BLE_TRANSPORT: Found device #$deviceCount: ${r.device.remoteId} '
                '(${r.device.platformName}) services: $serviceUuids',
              );
              controller.add(
                DeviceInfo(
                  id: r.device.remoteId.toString(),
                  name: r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : 'Unknown Device',
                  type: TransportType.ble,
                  address: r.device.remoteId.toString(),
                  rssi: r.rssi,
                  serviceUuids: serviceUuids,
                  manufacturerData: manufacturerData,
                ),
              );
            }
          },
          onError: (e) {
            AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: scanResults error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
          onDone: () {
            AppLogging.ble('📡 BLE_TRANSPORT: scanResults stream done');
            _finishScan(
              controller,
              scanSubscription,
              timeoutTimer,
              deviceCount,
              scanStarted,
            );
          },
        );
      } catch (e) {
        AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: BLE scan error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
          controller.close();
        }
      }
    }();

    // Handle cancellation when the stream subscription is cancelled
    controller.onCancel = () async {
      AppLogging.ble('📡 BLE_TRANSPORT: Scan stream cancelled');
      await _finishScan(
        controller,
        scanSubscription,
        timeoutTimer,
        deviceCount,
        scanStarted,
      );
    };

    return controller.stream;
  }

  Future<void> _finishScan(
    StreamController<DeviceInfo> controller,
    StreamSubscription<List<ScanResult>>? scanSubscription,
    Timer? timeoutTimer,
    int deviceCount,
    bool scanStarted,
  ) async {
    if (controller.isClosed) return;

    AppLogging.ble(
      '📡 BLE_TRANSPORT: Finishing scan, found $deviceCount devices total',
    );

    timeoutTimer?.cancel();
    await scanSubscription?.cancel();

    if (scanStarted) {
      AppLogging.ble('📡 BLE_TRANSPORT: Stopping hardware scan...');
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        AppLogging.ble('⚠️ 📡 BLE_TRANSPORT: stopScan error (ignored): $e');
      }
      AppLogging.ble('📡 BLE_TRANSPORT: Scan stopped');
    }

    if (!controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    // Force cleanup any stale state before connecting
    // This fixes issues where PIN cancellation leaves BLE in a weird state
    if (_state == DeviceConnectionState.connecting) {
      AppLogging.ble('⚠️ Already connecting - forcing cleanup first');
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    } else if (_state == DeviceConnectionState.connected) {
      AppLogging.ble('⚠️ Already connected');
      return;
    } else if (_state == DeviceConnectionState.error) {
      AppLogging.ble('⚠️ Was in error state - cleaning up first');
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _updateState(DeviceConnectionState.connecting);

    try {
      AppLogging.ble('Connecting to ${device.name}...');

      // Find the device
      final List<BluetoothDevice> systemDevices =
          await FlutterBluePlus.systemDevices([]);
      try {
        _device = systemDevices.firstWhere(
          (d) => d.remoteId.toString() == device.id,
        );

        // If device is already connected from another app or stale connection, disconnect first
        if (_device!.isConnected) {
          AppLogging.ble('⚠️ Device already connected, forcing disconnect...');
          try {
            await _device!.disconnect();
          } catch (e) {
            AppLogging.ble('⚠️ Pre-connect disconnect error (ignored): $e');
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        _device = BluetoothDevice.fromId(device.id);
      }

      // Connect to device with longer timeout and no auto MTU
      // Status 5 disconnects happen when the device drops connection during MTU negotiation
      AppLogging.ble('Initiating BLE connection...');
      await _device!.connect(
        license: License.free,
        autoConnect: false,
        mtu: null, // Skip auto MTU request - we'll do it manually with retry
        timeout: const Duration(
          seconds: 15,
        ), // Give device more time to stabilize
      );

      // Longer delay to let connection fully stabilize before ANY operations
      // The device seems to drop connection if hit too fast after GATT connect
      await Future.delayed(const Duration(milliseconds: 500));

      // Device is now connected, check if still connected before proceeding
      if (!_device!.isConnected) {
        throw Exception('Device disconnected during connection setup');
      }

      AppLogging.ble('Connection established, discovering services...');

      // Discover services FIRST - gives connection more time to stabilize
      await _discoverServices();

      // Now request MTU after connection is proven stable
      // Request MTU size 512 per Meshtastic docs with retry logic
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          await _device!.requestMtu(512);
          AppLogging.ble('✓ MTU request successful');
          break;
        } catch (e) {
          AppLogging.ble('⚠️ MTU request attempt $attempt/3 failed: $e');
          if (attempt == 3) {
            // After 3 attempts, continue anyway - some devices don't support MTU negotiation
            AppLogging.ble('⚠️ Proceeding without MTU negotiation');
          } else {
            // Wait before retrying, check if still connected
            await Future.delayed(const Duration(milliseconds: 300));
            if (!_device!.isConnected) {
              throw Exception('Device disconnected during MTU negotiation');
            }
          }
        }
      }

      // Set up listener for disconnection events
      _deviceStateSubscription = _device!.connectionState.listen((state) {
        AppLogging.ble('Connection state changed: $state');
        if (state == BluetoothConnectionState.disconnected) {
          AppLogging.ble('⚠️ Device disconnected');
          _updateState(DeviceConnectionState.disconnected);
        }
      });
    } catch (e) {
      AppLogging.ble('⚠️ Connection error: $e');
      await disconnect();
      _updateState(DeviceConnectionState.error);
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    try {
      AppLogging.ble('Discovering services...');

      List<BluetoothService> services;
      try {
        services = await _device!.discoverServices();
      } on PlatformException catch (e) {
        AppLogging.ble('⚠️ PlatformException during discoverServices: $e');
        throw Exception('Bluetooth discovery failed: ${e.message ?? e}');
      } on FlutterError catch (e) {
        AppLogging.ble('⚠️ FlutterError during discoverServices: $e');
        throw Exception('Bluetooth discovery failed: $e');
      } catch (e) {
        AppLogging.ble('⚠️ Unknown error during discoverServices: $e');
        throw Exception('Bluetooth discovery failed: $e');
      }

      // Log all discovered services and characteristics
      AppLogging.ble('Found ${services.length} services');
      for (final svc in services) {
        AppLogging.ble('Service: ${svc.uuid}');
        for (final char in svc.characteristics) {
          AppLogging.ble('  Characteristic: ${char.uuid}');
        }
      }

      // Try to read model number from Device Information Service (0x180A)
      await _readDeviceModelNumber(services);

      // Find Meshtastic service
      final service = services.cast<BluetoothService?>().firstWhere(
        (s) => s?.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
        orElse: () => null,
      );

      if (service == null) {
        // Meshtastic service not found - this device may be MeshCore or another protocol
        AppLogging.ble('⚠️ Meshtastic service not found (UUID: $_serviceUuid)');
        AppLogging.ble(
          'This device may use a different protocol (e.g., MeshCore). '
          'Discovered services:',
        );
        for (final svc in services) {
          AppLogging.ble('  - ${svc.uuid}');
        }
        throw MeshtasticServiceNotFoundException(
          'Meshtastic BLE service not found. This device may be running '
          'a different protocol (e.g., MeshCore) or is not a mesh radio.',
        );
      }

      // Find characteristics
      for (final characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        AppLogging.ble('Checking characteristic: $uuid');

        if (uuid == _toRadioUuid.toLowerCase()) {
          _txCharacteristic = characteristic;
          AppLogging.ble('Found TX characteristic (toRadio)');
        } else if (uuid == _fromRadioUuid.toLowerCase()) {
          _rxCharacteristic = characteristic;
          AppLogging.ble('Found RX characteristic (fromRadio)');
        } else if (uuid == _fromNumUuid.toLowerCase()) {
          _fromNumCharacteristic = characteristic;
          AppLogging.ble('Found fromNum characteristic');
        } else if (uuid == _logRadioUuid.toLowerCase()) {
          _logRadioCharacteristic = characteristic;
          AppLogging.ble('Found logRadio characteristic (device logs)');
        }
      }

      if (_txCharacteristic != null && _rxCharacteristic != null) {
        _updateState(DeviceConnectionState.connected);
        AppLogging.ble('Connected successfully');

        // Perform initial read from fromRadio to wake up the device
        if (_rxCharacteristic != null) {
          try {
            final initialData = await _rxCharacteristic!.read();
            if (initialData.isNotEmpty) {
              _dataController.add(initialData);
            }
          } catch (e) {
            AppLogging.ble('Initial read error (ignored): $e');
          }
        }

        // If fromNum is not available, fall back to polling
        if (_fromNumCharacteristic == null) {
          AppLogging.ble('⚠️ fromNum not available, using polling fallback');
          _startPolling();
        }
      } else {
        final missing = <String>[];
        if (_txCharacteristic == null) missing.add('TX');
        if (_rxCharacteristic == null) missing.add('RX');
        AppLogging.ble('⚠️ Missing characteristics: ${missing.join(", ")}');
        throw Exception(
          'Missing ${missing.join(" and ")} characteristic(s). '
          'Try power cycling the device.',
        );
      }
    } catch (e) {
      AppLogging.ble('⚠️ Service discovery error: $e');
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
      AppLogging.ble(
        '⚠️ Cannot enable notifications: fromNum characteristic not found',
      );
      return;
    }

    try {
      final canNotify = _fromNumCharacteristic!.properties.notify;
      final canIndicate = _fromNumCharacteristic!.properties.indicate;

      if (!canNotify && !canIndicate) {
        AppLogging.ble('⚠️ fromNum does not support notifications');
        return;
      }

      await _fromNumCharacteristic!.setNotifyValue(true);
      AppLogging.ble('BLE_NOTIFY_SUBSCRIBED fromNum');

      _fromNumSubscription = _fromNumCharacteristic!.lastValueStream.listen(
        (value) async {
          // fromNum value is just a counter - read fromRadio regardless
          if (_rxCharacteristic != null) {
            AppLogging.ble('fromNum notified, reading fromRadio');
            try {
              // Read from fromRadio until empty
              while (true) {
                final data = await _rxCharacteristic!.read();
                if (data.isEmpty) break;
                AppLogging.ble(
                  'BLE_RX_RAW len=${data.length} ts=${DateTime.now().toIso8601String()}',
                );
                AppLogging.ble('Read ${data.length} bytes from fromRadio');
                _dataController.add(data);
              }
            } catch (e) {
              AppLogging.ble('⚠️ Error reading fromRadio: $e');
              if (_isAuthenticationError(e)) {
                AppLogging.ble(
                  '⚠️ Authentication error - PIN may have been cancelled',
                );
                _updateState(DeviceConnectionState.error);
              }
            }
          }
        },
        onError: (error) {
          AppLogging.ble('⚠️ fromNum error: $error');
          if (_isAuthenticationError(error)) {
            AppLogging.ble(
              '⚠️ Authentication error in notification - PIN may have been cancelled',
            );
            _updateState(DeviceConnectionState.error);
          }
        },
      );
      AppLogging.ble('fromNum notifications enabled');

      // Subscribe to logRadio for device firmware debug logs
      await _subscribeToLogRadio();
    } catch (e) {
      AppLogging.ble('⚠️ Error enabling notifications: $e');
      if (_isAuthenticationError(e)) {
        AppLogging.ble(
          '⚠️ Authentication error enabling notifications - PIN cancelled',
        );
        _updateState(DeviceConnectionState.error);
        rethrow;
      }
    }
  }

  void _startPolling() {
    AppLogging.ble('Starting polling for fromRadio characteristic');

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
          AppLogging.ble('Polled ${value.length} bytes');
          _dataController.add(value);
        }
      } catch (e) {
        AppLogging.ble('⚠️ Polling error: $e');
      }
    });
  }

  /// Subscribe to the LogRadio characteristic for device firmware debug logs
  Future<void> _subscribeToLogRadio() async {
    if (_logRadioCharacteristic == null) {
      AppLogging.ble('⚠️ logRadio characteristic not found, skipping');
      return;
    }

    try {
      final canNotify = _logRadioCharacteristic!.properties.notify;
      if (!canNotify) {
        AppLogging.ble('⚠️ logRadio does not support notifications');
        return;
      }

      await _logRadioCharacteristic!.setNotifyValue(true);
      AppLogging.ble('BLE_NOTIFY_SUBSCRIBED logRadio');

      _logRadioSubscription = _logRadioCharacteristic!.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;

          try {
            // Parse the LogRecord protobuf
            final logRecord = pb.LogRecord.fromBuffer(value);
            AppLogging.ble(
              'DEVICE_LOG [${logRecord.level.name}] ${logRecord.source}: ${logRecord.message}',
            );
            _deviceLogController.add(logRecord);
          } catch (e) {
            AppLogging.ble('⚠️ Error parsing LogRecord: $e');
          }
        },
        onError: (error) {
          AppLogging.ble('⚠️ logRadio error: $error');
        },
      );
      AppLogging.ble('logRadio notifications enabled (device logs)');
    } catch (e) {
      AppLogging.ble('⚠️ Error enabling logRadio notifications: $e');
    }
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
        AppLogging.ble('Polled ${value.length} bytes');
        _dataController.add(value);
      }
    } catch (e) {
      AppLogging.ble('⚠️ Polling error: $e');
      if (_isAuthenticationError(e)) {
        _consecutiveAuthErrors++;
        AppLogging.ble(
          '⚠️ Authentication error during poll (count: $_consecutiveAuthErrors)',
        );
        // After 3 consecutive auth errors, assume PIN was cancelled
        if (_consecutiveAuthErrors >= 3) {
          AppLogging.ble(
            '⚠️ Multiple auth errors - PIN likely cancelled, transitioning to error state',
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
      if (_fromNumSubscription != null) {
        await _fromNumSubscription?.cancel();
        AppLogging.ble('BLE_NOTIFY_UNSUBSCRIBED fromNum');
      }
      if (_logRadioSubscription != null) {
        await _logRadioSubscription?.cancel();
        AppLogging.ble('BLE_NOTIFY_UNSUBSCRIBED logRadio');
      }
      await _deviceStateSubscription?.cancel();

      if (_device != null) {
        try {
          await _device!.disconnect();
        } catch (e) {
          AppLogging.ble('⚠️ Device disconnect error (ignored): $e');
        }
      }

      _device = null;
      _txCharacteristic = null;
      _rxCharacteristic = null;
      _logRadioCharacteristic = null;
      _characteristicSubscription = null;
      _deviceStateSubscription = null;
      _fromNumSubscription = null;
      _logRadioSubscription = null;
      _consecutiveAuthErrors = 0;

      if (!wasDisconnected) {
        _updateState(DeviceConnectionState.disconnected);
        AppLogging.ble('Disconnected');
      }
    } catch (e) {
      AppLogging.ble('⚠️ Disconnect error: $e');
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
      AppLogging.ble('Sending ${data.length} bytes');

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

      AppLogging.ble('Sent successfully');
    } catch (e) {
      AppLogging.ble('⚠️ Send error: $e');

      // Check if this is a disconnection error and update state accordingly
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('disconnect') ||
          errorStr.contains('not connected') ||
          errorStr.contains('connection') ||
          errorStr.contains('invalid') ||
          errorStr.contains('peripheral')) {
        AppLogging.ble('⚠️ Device appears to have disconnected during send');
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
      AppLogging.ble('⚠️ Failed to read RSSI: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
    await _deviceLogController.close();
  }
}
