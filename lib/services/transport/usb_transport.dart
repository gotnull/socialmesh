import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:logger/logger.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';

/// USB Serial implementation of DeviceTransport
class UsbTransport implements DeviceTransport {
  late final Logger _logger;
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;

  UsbPort? _port;
  UsbDevice? _device;
  StreamSubscription<Uint8List>? _portSubscription;

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  UsbTransport()
    : _stateController = StreamController<DeviceConnectionState>.broadcast(),
      _dataController = StreamController<List<int>>.broadcast() {
    _logger = AppLogging.bleLogger; // USB uses same logging config
  }

  @override
  TransportType get type => TransportType.usb;

  @override
  bool get requiresFraming => true; // USB Serial requires packet framing

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  String? get bleModelNumber => null; // Not available for USB transport

  @override
  String? get bleManufacturerName => null; // Not available for USB transport

  void _updateState(DeviceConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _logger.d('USB state changed to: $newState');
    }
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout}) async* {
    _logger.i('Scanning for USB devices...');

    try {
      final devices = await UsbSerial.listDevices();

      for (final device in devices) {
        yield DeviceInfo(
          id: '${device.vid}:${device.pid}:${device.deviceId}',
          name: device.productName ?? 'USB Serial Device',
          type: TransportType.usb,
          address: device.deviceName,
        );
      }
    } catch (e) {
      _logger.e('USB scan error: $e');
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
      final devices = await UsbSerial.listDevices();
      _device = devices.firstWhere(
        (d) => '${d.vid}:${d.pid}:${d.deviceId}' == device.id,
      );

      // Create port
      _port = await _device!.create();

      if (_port == null) {
        throw Exception('Failed to create USB port');
      }

      // Open port with standard settings
      final opened = await _port!.open();
      if (!opened) {
        throw Exception('Failed to open USB port');
      }

      // Configure port for Meshtastic (115200 baud, 8N1)
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // Listen to data
      _portSubscription = _port!.inputStream?.listen(
        (data) {
          if (data.isNotEmpty) {
            _logger.d('Received ${data.length} bytes');
            _dataController.add(data.toList());
          }
        },
        onError: (error) {
          _logger.e('Port error: $error');
          _updateState(DeviceConnectionState.error);
        },
        onDone: () {
          _logger.i('Port closed');
          _updateState(DeviceConnectionState.disconnected);
        },
      );

      _updateState(DeviceConnectionState.connected);
      _logger.i('Connected successfully');
    } catch (e) {
      _logger.e('Connection error: $e');
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
      await _portSubscription?.cancel();
      _portSubscription = null;

      if (_port != null) {
        await _port!.close();
      }

      _port = null;
      _device = null;

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

    if (_port == null) {
      throw Exception('Port not available');
    }

    try {
      _logger.d('Sending ${data.length} bytes');
      await _port!.write(Uint8List.fromList(data));
      _logger.d('Sent successfully');
    } catch (e) {
      _logger.e('Send error: $e');
      rethrow;
    }
  }

  @override
  Future<void> pollOnce() async {
    // USB serial uses continuous stream, no polling needed
  }

  @override
  Future<void> enableNotifications() async {
    // USB doesn't use BLE notifications
  }

  @override
  Future<int?> readRssi() async {
    // USB doesn't support RSSI
    return null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
  }
}
