// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../core/meshcore_constants.dart';
import '../../core/transport.dart';
import '../../models/mesh_device.dart';
import '../../providers/meshcore_providers.dart';
import '../protocol/protocol_service.dart';
import 'mesh_device_adapter.dart';
import 'mesh_transport.dart';
import 'meshcore_adapter.dart';
import 'meshcore_ble_transport.dart';
import 'meshcore_detector.dart';
import 'meshtastic_adapter.dart';
import 'protocol/meshcore_capture.dart';

/// Result of a connection attempt through the coordinator.
class ConnectionResult {
  /// Whether connection succeeded.
  final bool success;

  /// The adapter for the connected device (null if failed).
  final MeshDeviceAdapter? adapter;

  /// Device info from successful identification (null if failed).
  final MeshDeviceInfo? deviceInfo;

  /// Error message if connection failed.
  final String? errorMessage;

  /// Protocol error type if applicable.
  final MeshProtocolError? protocolError;

  const ConnectionResult._({
    required this.success,
    this.adapter,
    this.deviceInfo,
    this.errorMessage,
    this.protocolError,
  });

  factory ConnectionResult.success(
    MeshDeviceAdapter adapter,
    MeshDeviceInfo deviceInfo,
  ) {
    return ConnectionResult._(
      success: true,
      adapter: adapter,
      deviceInfo: deviceInfo,
    );
  }

  factory ConnectionResult.failure(String message, {MeshProtocolError? error}) {
    return ConnectionResult._(
      success: false,
      errorMessage: message,
      protocolError: error,
    );
  }

  /// Factory for "already connecting" guard result.
  factory ConnectionResult.alreadyConnecting() {
    return ConnectionResult._(
      success: false,
      errorMessage: 'Connection already in progress',
      protocolError: MeshProtocolError.connectionInProgress,
    );
  }

  @override
  String toString() => success
      ? 'ConnectionResult.success(${deviceInfo?.displayName})'
      : 'ConnectionResult.failure($errorMessage)';
}

/// Factory function type for creating MeshCore adapters.
///
/// Injectable for testing to verify MeshCore path is never called for Meshtastic.
typedef MeshCoreAdapterFactoryFn =
    MeshCoreAdapter Function(MeshTransport transport);

/// Factory function type for creating Meshtastic adapters.
///
/// Injectable for testing to verify Meshtastic path is never called for MeshCore.
typedef MeshtasticAdapterFactoryFn =
    MeshtasticAdapter Function(ProtocolService protocolService);

/// Factory function type for creating MeshCore BLE transport.
///
/// Injectable for testing to verify MeshCore transport is never created for Meshtastic.
typedef MeshCoreTransportFactoryFn = MeshCoreBleTransport Function();

/// Coordinates connection to mesh devices based on detected protocol.
///
/// This is the single integration point that routes device connections
/// to the appropriate adapter (MeshtasticAdapter or MeshCoreAdapter)
/// based on protocol detection.
///
/// Invariants enforced:
/// - Protocol is locked at connect() entry, never changed during attempt
/// - Only one connect() can run at a time (single-flight guard)
/// - MeshCore path never touches ProtocolService
/// - Meshtastic path never touches MeshCore session/transport
/// - Disconnect cleans up only the active protocol's resources
///
/// Usage:
/// 1. Scan results come in through existing BLE transport
/// 2. User taps to connect
/// 3. Coordinator detects protocol from scan data
/// 4. Coordinator creates appropriate adapter and connects
/// 5. Returns ConnectionResult with adapter and device info
///
/// The coordinator does NOT change the existing Meshtastic connection
/// flow - it only adds a protocol selection layer on top.
class ConnectionCoordinator {
  /// Currently active adapter (null if not connected).
  MeshDeviceAdapter? _activeAdapter;

  /// Currently detected protocol info.
  MeshDeviceInfo? _currentDeviceInfo;

  /// Protocol type of the current connection (null if not connected).
  MeshProtocolType? _activeProtocol;

  /// MeshCore capture for debugging (debug builds only).
  MeshCoreFrameCapture? _meshCoreCapture;

  /// Single-flight guard: non-null while connect() is running.
  Completer<ConnectionResult>? _connectInProgress;

  /// Stream controller for connection state changes.
  final StreamController<MeshConnectionState> _stateController =
      StreamController<MeshConnectionState>.broadcast();

  /// Factory for creating MeshCore adapters (injectable for testing).
  final MeshCoreAdapterFactoryFn _meshCoreAdapterFactory;

  /// Factory for creating Meshtastic adapters (injectable for testing).
  final MeshtasticAdapterFactoryFn _meshtasticAdapterFactory;

  /// Factory for creating MeshCore BLE transport (injectable for testing).
  final MeshCoreTransportFactoryFn _meshCoreTransportFactory;

  /// Creates a ConnectionCoordinator with optional injectable factories.
  ///
  /// The factories default to production implementations but can be
  /// replaced in tests to verify protocol isolation.
  ConnectionCoordinator({
    MeshCoreAdapterFactoryFn? meshCoreAdapterFactory,
    MeshtasticAdapterFactoryFn? meshtasticAdapterFactory,
    MeshCoreTransportFactoryFn? meshCoreTransportFactory,
  }) : _meshCoreAdapterFactory =
           meshCoreAdapterFactory ?? MeshCoreAdapterFactory.createForBle,
       _meshtasticAdapterFactory =
           meshtasticAdapterFactory ?? MeshtasticAdapter.new,
       _meshCoreTransportFactory =
           meshCoreTransportFactory ?? MeshCoreBleTransport.new;

  /// Stream of connection state changes.
  Stream<MeshConnectionState> get stateStream => _stateController.stream;

  /// Current protocol-agnostic device info.
  MeshDeviceInfo? get deviceInfo => _currentDeviceInfo;

  /// Currently active adapter.
  MeshDeviceAdapter? get activeAdapter => _activeAdapter;

  /// Whether connected to any device.
  bool get isConnected => _activeAdapter?.isReady ?? false;

  /// Whether a connection attempt is currently in progress.
  bool get isConnecting => _connectInProgress != null;

  /// Protocol type of the active connection (null if not connected).
  MeshProtocolType? get activeProtocol => _activeProtocol;

  /// Get the MeshCore capture instance (dev-only, null if not MeshCore or release).
  MeshCoreFrameCapture? get meshCoreCapture => _meshCoreCapture;

  /// Get the MeshCore adapter if connected to a MeshCore device.
  MeshCoreAdapter? get meshCoreAdapter => _activeAdapter is MeshCoreAdapter
      ? _activeAdapter as MeshCoreAdapter
      : null;

  /// Detect protocol for a device from scan data.
  ///
  /// This should be called when scan results are received to determine
  /// how to display the device in the list (protocol badge).
  ProtocolDetectionResult detectProtocol({
    required DeviceInfo device,
    List<String> advertisedServiceUuids = const [],
    Map<int, List<int>>? manufacturerData,
  }) {
    return MeshProtocolDetector.detect(
      device: device,
      advertisedServiceUuids: advertisedServiceUuids,
      manufacturerData: manufacturerData,
    );
  }

  /// Connect to a device using the appropriate adapter.
  ///
  /// This is the main entry point for connecting to mesh devices.
  /// It handles protocol detection, transport creation, and adapter setup.
  ///
  /// Single-flight guard: If connect() is already running, returns
  /// [ConnectionResult.alreadyConnecting] immediately without blocking.
  ///
  /// Protocol is locked at entry based on [advertisedServiceUuids].
  /// The locked protocol is never changed during the attempt, even on errors.
  ///
  /// [device] - Device info from scan result.
  /// [advertisedServiceUuids] - Service UUIDs from scan advertisement.
  /// [protocolService] - The existing Meshtastic protocol service (for Meshtastic devices).
  /// [existingTransport] - The existing Meshtastic transport (for Meshtastic devices).
  ///
  /// Returns ConnectionResult indicating success/failure and providing
  /// the adapter and device info on success.
  Future<ConnectionResult> connect({
    required DeviceInfo device,
    List<String> advertisedServiceUuids = const [],
    ProtocolService? protocolService,
    DeviceTransport? existingTransport,
  }) async {
    // -------------------------------------------------------------------------
    // Single-flight guard: only one connect() at a time
    // -------------------------------------------------------------------------
    if (_connectInProgress != null) {
      AppLogging.connection(
        'ConnectionCoordinator: Connect blocked - already connecting',
      );
      return ConnectionResult.alreadyConnecting();
    }

    final completer = Completer<ConnectionResult>();
    _connectInProgress = completer;

    try {
      final result = await _doConnect(
        device: device,
        advertisedServiceUuids: advertisedServiceUuids,
        protocolService: protocolService,
        existingTransport: existingTransport,
      );
      completer.complete(result);
      return result;
    } catch (e) {
      final failure = ConnectionResult.failure(e.toString());
      completer.complete(failure);
      return failure;
    } finally {
      _connectInProgress = null;
    }
  }

  /// Internal connect implementation (guarded by single-flight in connect()).
  Future<ConnectionResult> _doConnect({
    required DeviceInfo device,
    required List<String> advertisedServiceUuids,
    required ProtocolService? protocolService,
    required DeviceTransport? existingTransport,
  }) async {
    AppLogging.connection(
      'ConnectionCoordinator: Connecting to ${device.name}...',
    );
    _stateController.add(MeshConnectionState.connecting);

    // -------------------------------------------------------------------------
    // Protocol locked at entry: compute once, never change
    // -------------------------------------------------------------------------
    final detection = detectProtocol(
      device: device,
      advertisedServiceUuids: advertisedServiceUuids,
    );
    final lockedProtocol = detection.protocolType;

    AppLogging.connection(
      'ConnectionCoordinator: Protocol locked: $lockedProtocol',
    );

    try {
      // -------------------------------------------------------------------------
      // Protocol-specific routing: each branch uses only its own resources
      // -------------------------------------------------------------------------
      switch (lockedProtocol) {
        case MeshProtocolType.meshcore:
          // MeshCore path: uses MeshCore transport/session, NEVER ProtocolService
          return await _connectMeshCore(device, advertisedServiceUuids);

        case MeshProtocolType.meshtastic:
        case MeshProtocolType.unknown:
          // Meshtastic path: uses ProtocolService, NEVER MeshCore resources
          return await _connectMeshtastic(
            device,
            protocolService,
            existingTransport,
          );
      }
    } catch (e) {
      AppLogging.connection('ConnectionCoordinator: Connection error: $e');
      _stateController.add(MeshConnectionState.error);
      return ConnectionResult.failure(e.toString());
    }
  }

  Future<ConnectionResult> _connectMeshCore(
    DeviceInfo device,
    List<String> advertisedServiceUuids,
  ) async {
    AppLogging.connection('ConnectionCoordinator: Using MeshCore adapter');

    // -------------------------------------------------------------------------
    // Invariant: Verify UART service is advertised BEFORE creating resources
    // This prevents MeshCore devices from accidentally entering Meshtastic flow
    // -------------------------------------------------------------------------
    final hasUartService = advertisedServiceUuids.any(
      (uuid) => uuid.toLowerCase() == MeshCoreBleUuids.serviceUuid,
    );
    if (!hasUartService) {
      AppLogging.connection(
        'ConnectionCoordinator: MeshCore device missing UART service',
      );
      _stateController.add(MeshConnectionState.error);
      return ConnectionResult.failure(
        'MeshCore device missing required UART service',
        error: MeshProtocolError.unsupportedDevice,
      );
    }

    // Create MeshCore transport using injectable factory
    final transport = _meshCoreTransportFactory();

    try {
      // -------------------------------------------------------------------------
      // MeshCore Connection Sequence (from meshcore-open reference):
      // 1. BLE connect to device
      // 2. Discover services (Nordic UART: 6e400001-...)
      // 3. Subscribe to TX notify characteristic BEFORE any writes
      // 4. Session now listening for responses
      // 5. Send cmdDeviceQuery (0x07) to request device capabilities
      // 6. Send cmdAppStart (0x01) to initiate app protocol handshake
      // 7. Wait for respSelfInfo (0x01) containing node identity
      //
      // Key invariant: notify subscription must be active before any command
      // is sent, otherwise responses may be missed.
      // -------------------------------------------------------------------------

      // Step 1-3: Connect transport (handles BLE connect + service discovery + notify subscribe)
      await transport.connect(device);

      // Step 4: Create adapter which initializes session (starts listening)
      // Uses injectable factory - tests can verify this is never called for Meshtastic
      final adapter = _meshCoreAdapterFactory(transport);
      _activeAdapter = adapter;
      _activeProtocol = MeshProtocolType.meshcore;

      // Attach capture in debug builds for dev-only protocol inspection
      if (kDebugMode) {
        _meshCoreCapture = MeshCoreFrameCapture();
        adapter.session?.setCapture(_meshCoreCapture);
        AppLogging.protocol('MeshCore: Debug capture enabled');
      }

      // Step 5-7: Identify device (sends deviceQuery + appStart, waits for selfInfo)
      _stateController.add(MeshConnectionState.identifying);
      final identifyResult = await adapter.identify();

      if (identifyResult.isFailure) {
        await _cleanupMeshCore(transport);
        _stateController.add(MeshConnectionState.error);
        return ConnectionResult.failure(
          identifyResult.errorMessage ?? 'Identification failed',
          error: identifyResult.error,
        );
      }

      _currentDeviceInfo = identifyResult.value;
      _stateController.add(MeshConnectionState.connected);

      AppLogging.connection(
        'ConnectionCoordinator: MeshCore connected and identified',
      );

      return ConnectionResult.success(adapter, _currentDeviceInfo!);
    } catch (e) {
      await _cleanupMeshCore(transport);
      _stateController.add(MeshConnectionState.error);
      return ConnectionResult.failure(e.toString());
    }
  }

  /// Clean up MeshCore-specific resources on failure.
  Future<void> _cleanupMeshCore(MeshCoreBleTransport transport) async {
    await transport.dispose();
    _activeAdapter = null;
    _activeProtocol = null;
    _meshCoreCapture = null;
  }

  Future<ConnectionResult> _connectMeshtastic(
    DeviceInfo device,
    ProtocolService? protocolService,
    DeviceTransport? existingTransport,
  ) async {
    AppLogging.connection('ConnectionCoordinator: Using Meshtastic adapter');

    // For Meshtastic, we use the existing protocol service that's managed
    // by the app providers. The actual connection happens through the
    // existing scanner_screen.dart flow.

    if (protocolService == null) {
      return ConnectionResult.failure(
        'Meshtastic protocol service not available',
      );
    }

    // Create Meshtastic adapter using injectable factory
    // Tests can verify this is never called for MeshCore
    final adapter = _meshtasticAdapterFactory(protocolService);
    _activeAdapter = adapter;
    _activeProtocol = MeshProtocolType.meshtastic;

    // Note: For Meshtastic, the actual BLE connection and protocol startup
    // is handled by the existing code in scanner_screen.dart.
    // The adapter just wraps the protocol service for uniform access.

    // Check if already identified
    _stateController.add(MeshConnectionState.identifying);
    final identifyResult = await adapter.identify();

    if (identifyResult.isFailure) {
      _activeAdapter = null;
      _activeProtocol = null;
      // Don't disconnect - let existing code handle it
      _stateController.add(MeshConnectionState.error);
      return ConnectionResult.failure(
        identifyResult.errorMessage ?? 'Identification failed',
        error: identifyResult.error,
      );
    }

    _currentDeviceInfo = identifyResult.value;
    _stateController.add(MeshConnectionState.connected);

    AppLogging.connection(
      'ConnectionCoordinator: Meshtastic connected and identified',
    );

    return ConnectionResult.success(adapter, _currentDeviceInfo!);
  }

  /// Disconnect from the current device.
  ///
  /// Cleans up only the active protocol's resources:
  /// - MeshCore: disposes session, transport, capture
  /// - Meshtastic: disposes adapter only (transport managed elsewhere)
  Future<void> disconnect() async {
    AppLogging.connection('ConnectionCoordinator: Disconnecting...');
    _stateController.add(MeshConnectionState.disconnecting);

    // Protocol-specific cleanup
    if (_activeProtocol == MeshProtocolType.meshcore) {
      // MeshCore: clear capture before disposing adapter
      _meshCoreCapture?.stop();
      _meshCoreCapture = null;
    }
    // Meshtastic: no special cleanup needed (transport managed by scanner)

    await _activeAdapter?.disconnect();
    await _activeAdapter?.dispose();
    _activeAdapter = null;
    _activeProtocol = null;
    _currentDeviceInfo = null;

    _stateController.add(MeshConnectionState.disconnected);
    AppLogging.connection('ConnectionCoordinator: Disconnected');
  }

  /// Ping the connected device.
  ///
  /// Returns latency on success, null on failure.
  Future<Duration?> ping() async {
    if (_activeAdapter == null || !_activeAdapter!.isReady) {
      return null;
    }

    final result = await _activeAdapter!.ping();
    return result.isSuccess ? result.value : null;
  }

  /// Discover and dump all GATT services/characteristics.
  ///
  /// Returns list of service info, or null if not available.
  /// This is a debug tool to discover actual BLE UUIDs.
  Future<List<GattServiceInfo>?> discoverGattServices() async {
    // This only works for MeshCore BLE transport
    final adapter = _activeAdapter;
    if (adapter is MeshCoreAdapter) {
      // For now, return placeholder - actual implementation would
      // need access to transport internals or a dedicated method
      AppLogging.ble('GATT dump: Feature not yet implemented for MeshCore');
      return null;
    }

    // For Meshtastic, GATT discovery happens automatically
    AppLogging.ble('GATT dump: Not available for Meshtastic devices');
    return null;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }
}
