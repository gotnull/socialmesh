// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/logging.dart';
import '../../core/transport.dart';
import 'mesh_transport.dart';
import 'meshcore_usb_framing.dart';

/// MeshCore TCP transport for companion-radio firmware that exposes its
/// binary command/frame interface over a network socket.
///
/// The MeshCore reference firmware uses the same `<` / `>` direction-marker
/// + 2-byte little-endian length wire format on TCP as it does on USB-CDC.
/// This transport reuses [MeshCoreUsbEncoder] / [MeshCoreUsbDecoder]
/// verbatim — the only thing that differs from USB is the byte source.
///
/// [dataStream] emits **decoded payloads** (post-deframing). Each emitted
/// chunk is one complete MeshCore message ready for [MeshCoreDecoder] in
/// the session — exactly the same shape as [MeshCoreBleTransport]
/// (where each BLE notification is a complete payload).
///
/// Currently used as a dev/simulator path: the simulator build can connect
/// to a MeshCore companion radio over WiFi for E2E validation when no BLE
/// peer is available. Production runtime paths still use BLE/USB.
class MeshCoreTcpTransport implements MeshTransport {
  final String host;
  final int port;
  final Duration connectTimeout;

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  final _stateController = StreamController<DeviceConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();
  final _decoder = MeshCoreUsbDecoder();

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  MeshCoreTcpTransport({
    required this.host,
    required this.port,
    this.connectTimeout = const Duration(seconds: 10),
  });

  @override
  TransportType get transportType => TransportType.network;

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
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (_state == DeviceConnectionState.connecting ||
        _state == DeviceConnectionState.connected) {
      return;
    }

    _updateState(DeviceConnectionState.connecting);
    AppLogging.connection('MeshCoreTcpTransport: Connecting to $host:$port...');

    try {
      _socket = await Socket.connect(host, port, timeout: connectTimeout);
    } catch (e) {
      AppLogging.connection('MeshCoreTcpTransport: Connect failed: $e');
      _updateState(DeviceConnectionState.error);
      rethrow;
    }

    _socketSub = _socket!.listen(
      _onSocketData,
      onError: (Object error, StackTrace _) {
        AppLogging.connection('MeshCoreTcpTransport: Socket error: $error');
        _handleDisconnect(reason: 'socket-error');
      },
      onDone: () {
        AppLogging.connection('MeshCoreTcpTransport: Socket closed by peer');
        _handleDisconnect(reason: 'peer-closed');
      },
      cancelOnError: false,
    );

    _updateState(DeviceConnectionState.connected);
    AppLogging.connection('MeshCoreTcpTransport: Connected to $host:$port');
  }

  void _onSocketData(List<int> bytes) {
    // Feed raw socket bytes through the USB-style deframer. The same
    // `<` / `>` + length framing applies on the wire; the decoder buffers
    // partial reads and concatenates to extract complete payloads.
    final payloads = _decoder.addData(bytes);
    if (payloads.isEmpty) return;
    if (_dataController.isClosed) return;
    for (final payload in payloads) {
      _dataController.add(payload);
    }
  }

  void _handleDisconnect({required String reason}) {
    if (_state == DeviceConnectionState.disconnected ||
        _state == DeviceConnectionState.disconnecting) {
      return;
    }
    AppLogging.connection(
      'MeshCoreTcpTransport: Disconnected (reason: $reason)',
    );
    _updateState(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    final socket = _socket;
    if (socket == null || !isConnected) {
      throw StateError('MeshCoreTcpTransport: Not connected');
    }
    final payload = data is Uint8List ? data : Uint8List.fromList(data);
    final framed = MeshCoreUsbEncoder.frame(payload);
    socket.add(framed);
  }

  @override
  Future<void> disconnect() async {
    if (_state == DeviceConnectionState.disconnected) return;
    _updateState(DeviceConnectionState.disconnecting);

    await _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.destroy();
    } catch (_) {
      // Socket may already be closed; nothing actionable.
    }
    _socket = null;
    _decoder.clear();

    _updateState(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
    if (!_dataController.isClosed) {
      await _dataController.close();
    }
  }
}
