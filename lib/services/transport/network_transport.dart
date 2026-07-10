// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import '../../core/logging.dart';
import '../../core/transport.dart';

/// Default Meshtastic TCP port per the protocol specification.
const int kMeshtasticDefaultPort = 4403;

/// TCP/IP network transport for Meshtastic devices.
///
/// Connects to a Meshtastic node via TCP socket. Uses the same
/// 0x94/0xC3 packet framing as USB serial (handled by [PacketFramer]
/// in the protocol layer via [requiresFraming] = true).
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
  /// silent disconnections (standard 15-second interval).
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 15);
  DateTime? _lastDataReceived;

  // Tuned TCP keepalive. A powered-off or vanished radio cannot ACK the
  // kernel's keepalive probes, so the OS resets the connection roughly
  // idle + interval * count seconds (~50s) after the last exchange and
  // the read stream surfaces the error immediately, foreground or
  // background. A quiet-but-alive radio's kernel still answers the
  // probes, so a silent mesh never trips a false disconnect - which is
  // why detection lives here and not in an app-level silence timeout.
  // Best-effort: a set failure only means detection falls back to the
  // much slower OS defaults.
  static const int _keepaliveIdleSeconds = 20;
  static const int _keepaliveIntervalSeconds = 10;
  static const int _keepaliveProbeCount = 3;

  // Socket option ids are platform ABI constants; dart:io exposes the
  // levels (levelSocket/levelTcp) but not these option numbers.
  static const int _soKeepaliveDarwin = 0x0008; // SO_KEEPALIVE
  static const int _tcpKeepIdleDarwin = 0x10; // TCP_KEEPALIVE (idle)
  static const int _tcpKeepIntvlDarwin = 0x101; // TCP_KEEPINTVL
  static const int _tcpKeepCntDarwin = 0x102; // TCP_KEEPCNT
  static const int _soKeepaliveLinux = 9; // SO_KEEPALIVE
  static const int _tcpKeepIdleLinux = 4; // TCP_KEEPIDLE
  static const int _tcpKeepIntvlLinux = 5; // TCP_KEEPINTVL
  static const int _tcpKeepCntLinux = 6; // TCP_KEEPCNT

  bool _keepaliveEnabled = false;

  /// Whether tuned TCP keepalive was applied to the current socket.
  /// Diagnostic and test surface only.
  bool get keepaliveEnabled => _keepaliveEnabled;

  /// Max chunk size to forward to the protocol layer. Anything larger
  /// is split into chunks of this size. A real Meshtastic device never
  /// sends more than ~520 bytes (512 payload + 4 header + padding) in
  /// a single TCP segment, so large chunks indicate a flood attack.
  static const int _maxChunkSize = 4096;

  NetworkTransport({required this.host, required this.port});

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => true;

  @override
  bool get requiresWakeSequence => false; // TCP talks to PhoneAPI directly; no UART to wake.

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

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
      _enableKeepalive(_socket!);

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

          // Split oversized chunks to limit buffer growth in PacketFramer
          if (data.length > _maxChunkSize) {
            for (
              var offset = 0;
              offset < data.length;
              offset += _maxChunkSize
            ) {
              final end = (offset + _maxChunkSize < data.length)
                  ? offset + _maxChunkSize
                  : data.length;
              _dataController.add(data.sublist(offset, end));
            }
          } else {
            _dataController.add(data);
          }
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

      // Write-side errors (e.g. EPIPE on `_socket.add`) are delivered
      // asynchronously through the IOSink, NOT to the read subscription's
      // onError above. Install a permanent listener on `done` so async
      // write failures clean up state instead of escaping to
      // PlatformDispatcher.onError. Crashlytics 7894c78d.
      unawaited(
        _socket!.done.then<void>(
          (_) {},
          onError: (Object e) {
            AppLogging.protocol('NetworkTransport: write pipeline error: $e');
            _handleSocketClose();
          },
        ),
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
      throw const TransportSendError('NetworkTransport: Not connected');
    }
    try {
      _socket!.add(data);
    } on StateError catch (e) {
      // TOCTOU: socket was closed between the pre-write null-check and
      // the add() call. We already transition state on the way out -
      // callers learn via stateStream. Swallow instead of crashing on
      // an unhandled StateError funneling to PlatformDispatcher.onError.
      AppLogging.protocol(
        '[D 7894c78d] NetworkTransport: socket closed during send: $e',
      );
      _handleSocketClose();
    } on SocketException catch (e) {
      AppLogging.protocol(
        '[D 7894c78d] NetworkTransport: SocketException during send: $e',
      );
      _handleSocketClose();
    }
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
  Future<void> refreshNotifications() async {
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
    _keepaliveEnabled = false;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    _setState(DeviceConnectionState.disconnected);
  }

  void _enableKeepalive(Socket socket) {
    _keepaliveEnabled = false;
    final (int, int, int, int) options;
    if (Platform.isIOS || Platform.isMacOS) {
      options = (
        _soKeepaliveDarwin,
        _tcpKeepIdleDarwin,
        _tcpKeepIntvlDarwin,
        _tcpKeepCntDarwin,
      );
    } else if (Platform.isAndroid || Platform.isLinux) {
      options = (
        _soKeepaliveLinux,
        _tcpKeepIdleLinux,
        _tcpKeepIntvlLinux,
        _tcpKeepCntLinux,
      );
    } else {
      return;
    }
    try {
      socket.setRawOption(
        RawSocketOption.fromBool(RawSocketOption.levelSocket, options.$1, true),
      );
      socket.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelTcp,
          options.$2,
          _keepaliveIdleSeconds,
        ),
      );
      socket.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelTcp,
          options.$3,
          _keepaliveIntervalSeconds,
        ),
      );
      socket.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelTcp,
          options.$4,
          _keepaliveProbeCount,
        ),
      );
      _keepaliveEnabled = true;
      AppLogging.protocol(
        'NetworkTransport: TCP keepalive enabled '
        '(idle=${_keepaliveIdleSeconds}s, '
        'interval=${_keepaliveIntervalSeconds}s, '
        'count=$_keepaliveProbeCount)',
      );
    } catch (e) {
      AppLogging.protocol('NetworkTransport: TCP keepalive unavailable: $e');
    }
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
