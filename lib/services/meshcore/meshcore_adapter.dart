// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_device.dart';
import 'mesh_device_adapter.dart';
import 'mesh_transport.dart';
import 'protocol/meshcore_frame.dart';
import 'protocol/meshcore_session.dart';

// MeshCore protocol adapter implementation.
//
// This adapter is a thin wrapper that:
// - Manages MeshTransport connection
// - Creates MeshCoreSession for protocol operations
// - Exposes MeshDeviceAdapter interface for device identification and ping
//
// Protocol logic lives in MeshCoreSession and meshcore_messages.dart.

/// MeshCore protocol adapter implementation.
///
/// Implements [MeshDeviceAdapter] for MeshCore devices by wrapping a
/// [MeshTransport] and using [MeshCoreSession] for protocol operations.
class MeshCoreAdapter implements MeshDeviceAdapter {
  final MeshTransport _transport;

  MeshDeviceInfo? _deviceInfo;
  MeshCoreSession? _session;
  StreamSubscription<MeshCoreFrame>? _frameSubscription;

  /// Internal frame controller for backward compatibility.
  final StreamController<MeshCoreFrame> _frameController =
      StreamController<MeshCoreFrame>.broadcast();

  MeshCoreAdapter(this._transport) {
    _setupSession();
  }

  /// Create an adapter with a pre-connected transport.
  factory MeshCoreAdapter.withTransport(MeshTransport transport) {
    return MeshCoreAdapter(transport);
  }

  void _setupSession() {
    // Wrap transport in the session interface
    final sessionTransport = _MeshTransportAdapter(_transport);
    _session = MeshCoreSession(sessionTransport);

    // Forward frames to our stream for backward compatibility
    _frameSubscription = _session!.frameStream.listen((frame) {
      AppLogging.protocol(
        'MeshCore: Received frame: code=0x${frame.command.toRadixString(16)}, '
        '${frame.payload.length} bytes',
      );
      _frameController.add(frame);
    });
  }

  @override
  MeshProtocolType get protocolType => MeshProtocolType.meshcore;

  @override
  bool get isReady => _transport.isConnected && _deviceInfo != null;

  @override
  MeshDeviceInfo? get deviceInfo => _deviceInfo;

  /// The underlying protocol session.
  MeshCoreSession? get session => _session;

  /// Stream of decoded frames from the device.
  Stream<MeshCoreFrame> get frameStream => _frameController.stream;

  @override
  Future<MeshProtocolResult<MeshDeviceInfo>> identify() async {
    if (!_transport.isConnected) {
      return const MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        'Transport not connected',
      );
    }

    final session = _session;
    if (session == null) {
      return const MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        'Session not initialized',
      );
    }

    try {
      AppLogging.protocol('MeshCore: Starting device identification...');

      // Use session's high-level getSelfInfo
      final selfInfo = await session.getSelfInfo();

      if (selfInfo == null) {
        return const MeshProtocolResult.failure(
          MeshProtocolError.timeout,
          'Device info request timed out',
        );
      }

      // Convert to MeshDeviceInfo
      _deviceInfo = MeshDeviceInfo(
        protocolType: MeshProtocolType.meshcore,
        displayName: selfInfo.nodeName.isNotEmpty
            ? selfInfo.nodeName
            : 'MeshCore',
        nodeId: null, // Could extract from pub_key if needed
        firmwareVersion: null, // Not in self info response
      );

      AppLogging.protocol('MeshCore: Identified as $_deviceInfo');

      return MeshProtocolResult.success(_deviceInfo!);
    } on MeshCoreParseException catch (e) {
      // Log with code and payload length for debugging
      AppLogging.protocol(
        'MeshCore: Parse error: ${e.message} '
        '(code=0x${e.code.toRadixString(16)}, ${e.payload.length} bytes)',
      );
      return MeshProtocolResult.failure(
        MeshProtocolError.identificationFailed,
        e.message,
      );
    } catch (e) {
      AppLogging.protocol('MeshCore: Identify error: $e');
      return MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        e.toString(),
      );
    }
  }

  @override
  Future<MeshProtocolResult<Duration>> ping() async {
    if (!_transport.isConnected) {
      return const MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        'Transport not connected',
      );
    }

    final session = _session;
    if (session == null) {
      return const MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        'Session not initialized',
      );
    }

    try {
      AppLogging.protocol('MeshCore: Sending battery request as ping...');

      // Use session's ping (which uses battery request)
      final latency = await session.ping();

      if (latency == null) {
        return const MeshProtocolResult.failure(
          MeshProtocolError.timeout,
          'Battery request timed out',
        );
      }

      AppLogging.protocol(
        'MeshCore: Battery response received, latency: ${latency.inMilliseconds}ms',
      );

      return MeshProtocolResult.success(latency);
    } catch (e) {
      AppLogging.protocol('MeshCore: Ping error: $e');
      return MeshProtocolResult.failure(
        MeshProtocolError.communicationError,
        e.toString(),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _transport.disconnect();
    _deviceInfo = null;
    _session?.clearPendingResponses();
  }

  @override
  Future<void> dispose() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _session?.dispose();
    _session = null;
    await _frameController.close();
    await _transport.dispose();
  }
}

/// Adapter to bridge MeshTransport to MeshCoreTransport interface.
class _MeshTransportAdapter implements MeshCoreTransport {
  final MeshTransport _transport;

  _MeshTransportAdapter(this._transport);

  @override
  Stream<Uint8List> get rawRxStream =>
      _transport.dataStream.map((data) => Uint8List.fromList(data));

  @override
  Future<void> sendRaw(Uint8List data) => _transport.sendBytes(data);

  @override
  bool get isConnected => _transport.isConnected;
}

/// Factory for creating MeshCore adapters with appropriate transport.
class MeshCoreAdapterFactory {
  MeshCoreAdapterFactory._();

  /// Create a MeshCore adapter for BLE transport.
  static MeshCoreAdapter createForBle(MeshTransport transport) {
    return MeshCoreAdapter(transport);
  }
}

/// Fake transport for testing MeshCoreAdapter without real BLE.
class FakeMeshTransport implements MeshTransport {
  final StreamController<DeviceConnectionState> _stateController;
  final StreamController<List<int>> _dataController;
  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  /// Queue of responses to send when data is received.
  final List<List<int>> _responseQueue = [];

  /// Captured sent data for verification.
  final List<List<int>> sentData = [];

  /// Whether to simulate connection success.
  bool connectSucceeds = true;

  /// Simulated connection delay.
  Duration connectionDelay = const Duration(milliseconds: 10);

  FakeMeshTransport()
    : _stateController = StreamController<DeviceConnectionState>.broadcast(),
      _dataController = StreamController<List<int>>.broadcast();

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

  void _updateState(DeviceConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Queue a response to be sent after the next sendBytes call.
  void queueResponse(List<int> response) {
    _responseQueue.add(response);
  }

  /// Simulate receiving data from the device.
  void simulateReceive(List<int> data) {
    _dataController.add(data);
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    _updateState(DeviceConnectionState.connecting);
    await Future.delayed(connectionDelay);

    if (!connectSucceeds) {
      _updateState(DeviceConnectionState.error);
      throw Exception('Connection failed (simulated)');
    }

    _updateState(DeviceConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _updateState(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    sentData.add(List.from(data));

    // Send queued response if available
    if (_responseQueue.isNotEmpty) {
      final response = _responseQueue.removeAt(0);
      // Simulate async response
      Future.microtask(() => _dataController.add(response));
    }
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
    await _dataController.close();
  }
}
