// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import '../../core/logging.dart';
import '../../core/transport.dart';

/// Default Meshtastic TCP port (matches meshtastic-ios)
const int kMeshtasticDefaultPort = 4403;

/// TCP/IP network transport for Meshtastic devices.
///
/// Connects to a Meshtastic node via TCP socket. Uses the same
/// 0x94/0xC3 packet framing as USB serial (handled by [PacketFramer]
/// in the protocol layer via [requiresFraming] = true).
///
/// Reference: meshtastic-ios/Accessory/Transports/TCP/TCPConnection.swift
class NetworkTransport implements DeviceTransport {
  final String host;
  final int port;

  Socket? _socket;
  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _socketSubscription;

  /// Heartbeat timer — TCP connections need periodic probing to detect
  /// silent disconnections. Matches meshtastic-ios 15-second interval.
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 15);
  DateTime? _lastDataReceived;

  NetworkTransport({required this.host, required this.port});

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => true;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  void _setState(DeviceConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
    AppLogging.protocol('NetworkTransport: state → $newState');
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (_state == DeviceConnectionState.connected ||
        _state == DeviceConnectionState.connecting) {
      AppLogging.protocol(
        'NetworkTransport: Already ${_state.name}, ignoring connect()',
      );
      return;
    }

    _setState(DeviceConnectionState.connecting);

    try {
      AppLogging.protocol('NetworkTransport: Connecting to $host:$port...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );

      /// Total bytes received on this connection (security metric).
      var totalBytesReceived = 0;
      var totalChunks = 0;

      _socketSubscription = _socket!.listen(
        (data) {
          _lastDataReceived = DateTime.now();
          totalBytesReceived += data.length;
          totalChunks++;

          // --- SECURITY AUDIT LOGGING ---
          AppLogging.protocol(
            'NET SECURITY: Recv chunk #$totalChunks '
            'size=${data.length} '
            'totalBytes=$totalBytesReceived '
            'first8=${data.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          );
          if (data.length > 1024) {
            AppLogging.protocol(
              '⚠️ NET SECURITY: Large chunk received: ${data.length} bytes '
              '(possible flood attack)',
            );
          }
          // --- END SECURITY AUDIT LOGGING ---

          _dataController.add(data);
        },
        onError: (Object error) {
          AppLogging.protocol('NetworkTransport: Socket error: $error');
          _handleSocketClose();
        },
        onDone: () {
          AppLogging.protocol('NetworkTransport: Socket closed by remote');
          _handleSocketClose();
        },
        cancelOnError: false,
      );

      _setState(DeviceConnectionState.connected);
      _startHeartbeat();
      AppLogging.protocol('NetworkTransport: Connected to $host:$port');
    } on SocketException catch (e) {
      AppLogging.protocol('NetworkTransport: Connection failed: $e');
      _setState(DeviceConnectionState.error);
      rethrow;
    } on TimeoutException catch (e) {
      AppLogging.protocol('NetworkTransport: Connection timed out: $e');
      _setState(DeviceConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_state == DeviceConnectionState.disconnected ||
        _state == DeviceConnectionState.disconnecting) {
      return;
    }

    _setState(DeviceConnectionState.disconnecting);
    _stopHeartbeat();

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      _socket?.destroy();
      _socket = null;
    } catch (e) {
      AppLogging.protocol('NetworkTransport: Error during disconnect: $e');
    }

    _setState(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> send(List<int> data) async {
    if (_socket == null || _state != DeviceConnectionState.connected) {
      throw StateError('NetworkTransport: Not connected');
    }
    _socket!.add(data);
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) async* {
    // Network transport does not support scanning.
    // Devices are added manually via host:port.
  }

  @override
  Future<void> enableNotifications() async {
    // No-op for TCP. BLE-only concept.
  }

  @override
  Future<void> pollOnce() async {
    // No-op for TCP. Data arrives via socket stream.
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Future<void> dispose() async {
    _stopHeartbeat();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    await _stateController.close();
    await _dataController.close();
  }

  void _handleSocketClose() {
    if (_state == DeviceConnectionState.disconnecting ||
        _state == DeviceConnectionState.disconnected) {
      return;
    }
    _stopHeartbeat();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    _setState(DeviceConnectionState.disconnected);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _lastDataReceived = DateTime.now();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_state != DeviceConnectionState.connected) {
        _stopHeartbeat();
        return;
      }
      final lastData = _lastDataReceived;
      if (lastData != null &&
          DateTime.now().difference(lastData) > _heartbeatInterval * 3) {
        AppLogging.protocol(
          'NetworkTransport: No data for ${_heartbeatInterval.inSeconds * 3}s, '
          'connection may be dead',
        );
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
