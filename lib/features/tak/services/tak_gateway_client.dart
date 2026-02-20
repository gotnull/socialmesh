// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/logging.dart';
import '../models/tak_event.dart';

/// Connection state for the gateway WebSocket.
enum TakConnectionState { disconnected, connecting, connected, reconnecting }

/// WebSocket client that connects to the Socialmesh TAK Gateway
/// and streams normalized CoT events.
///
/// Usage:
/// ```dart
/// final client = TakGatewayClient(
///   gatewayUrl: 'wss://tak.socialmesh.app',
///   getAuthToken: () => authService.getIdToken(),
/// );
/// client.eventStream.listen((event) { ... });
/// await client.connect();
/// ```
class TakGatewayClient {
  /// Base gateway URL (e.g. "wss://tak.socialmesh.app" or "ws://localhost:3004")
  final String gatewayUrl;

  /// Callback to retrieve a fresh Firebase ID token.
  final Future<String?> Function() getAuthToken;

  /// Optional scope parameter for multi-tenancy.
  final String? scope;

  /// Maximum reconnection attempts before giving up. 0 = unlimited.
  final int maxReconnectAttempts;

  WebSocket? _socket;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  // Stream controllers
  final _eventController = StreamController<TakEvent>.broadcast();
  final _snapshotController = StreamController<List<TakEvent>>.broadcast();
  final _stateController = StreamController<TakConnectionState>.broadcast();

  TakConnectionState _state = TakConnectionState.disconnected;
  bool _disposed = false;

  // Counters
  int _totalEventsReceived = 0;
  int _totalReconnects = 0;
  String? _lastError;
  DateTime? _connectedSince;

  TakGatewayClient({
    required this.gatewayUrl,
    required this.getAuthToken,
    this.scope,
    this.maxReconnectAttempts = 0,
  });

  /// Stream of individual CoT events as they arrive.
  Stream<TakEvent> get eventStream => _eventController.stream;

  /// Stream of snapshot backfills (sent on connect).
  Stream<List<TakEvent>> get snapshotStream => _snapshotController.stream;

  /// Stream of connection state changes.
  Stream<TakConnectionState> get stateStream => _stateController.stream;

  /// Current connection state.
  TakConnectionState get state => _state;

  /// Total events received since client creation.
  int get totalEventsReceived => _totalEventsReceived;

  /// Total reconnection attempts.
  int get totalReconnects => _totalReconnects;

  /// Last error message, if any.
  String? get lastError => _lastError;

  /// Time when current connection was established.
  DateTime? get connectedSince => _connectedSince;

  /// Connect to the TAK Gateway WebSocket.
  Future<void> connect() async {
    if (_disposed) {
      AppLogging.tak('connect() called on disposed client, ignoring');
      return;
    }
    if (_state == TakConnectionState.connected ||
        _state == TakConnectionState.connecting) {
      AppLogging.tak('connect() called but already ${_state.name}, ignoring');
      return;
    }

    _setState(TakConnectionState.connecting);
    AppLogging.tak('Connecting to gateway: $gatewayUrl');

    try {
      AppLogging.tak('Requesting auth token...');
      final token = await getAuthToken();

      // Guard: client may have been disposed while awaiting the token.
      if (_disposed) {
        AppLogging.tak('Client disposed during auth token request, aborting');
        return;
      }

      AppLogging.tak(
        'Auth token ${token != null ? 'obtained (${token.length} chars)' : 'is null (anonymous)'}',
      );
      final wsUrl = _buildWsUrl(token);
      AppLogging.tak(
        'WebSocket URL: ${wsUrl.replaceAll(RegExp(r'token=[^&]+'), 'token=***')}',
      );

      _socket = await WebSocket.connect(
        wsUrl,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );

      // Guard: client may have been disposed while awaiting the connection.
      if (_disposed) {
        AppLogging.tak('Client disposed during WebSocket connect, closing');
        _socket?.close(WebSocketStatus.normalClosure, 'Client disposed');
        _socket = null;
        return;
      }

      // Enable WebSocket-level keepalive pings every 30 seconds so the
      // connection is not silently dropped by intermediaries (load balancers,
      // NATs, mobile radios). dart:io handles pong responses automatically.
      _socket!.pingInterval = const Duration(seconds: 30);

      _reconnectAttempts = 0;
      _connectedSince = DateTime.now();
      _setState(TakConnectionState.connected);

      AppLogging.tak('Connected to gateway successfully');

      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _lastError = e.toString();
      AppLogging.tak('Connection failed: $e');
      _setState(TakConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Disconnect from the gateway.
  void disconnect() {
    AppLogging.tak('Disconnecting from gateway (manual)');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _socket?.close(WebSocketStatus.normalClosure, 'Client disconnect');
    _socket = null;
    _connectedSince = null;
    _setState(TakConnectionState.disconnected);
    AppLogging.tak(
      'Disconnected. Total events received this session: $_totalEventsReceived',
    );
  }

  /// Clean up all resources.
  void dispose() {
    AppLogging.tak('Disposing TakGatewayClient');
    _disposed = true;
    disconnect();
    _eventController.close();
    _snapshotController.close();
    _stateController.close();
    AppLogging.tak('TakGatewayClient disposed');
  }

  /// Publish local node position to the TAK Gateway via REST POST.
  ///
  /// Returns `true` on success (HTTP 200/201), `false` otherwise.
  Future<bool> publishPosition({
    required String uid,
    required String type,
    required String callsign,
    required double lat,
    required double lon,
    double hae = 0.0,
    double ce = 10.0,
    double le = 10.0,
  }) async {
    final httpBase = gatewayUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://');
    final url = Uri.parse('$httpBase/v1/tak/publish');

    try {
      final token = await getAuthToken();
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }

      final body = jsonEncode({
        'uid': uid,
        'type': type,
        'callsign': callsign,
        'lat': lat,
        'lon': lon,
        'hae': hae,
        'ce': ce,
        'le': le,
      });
      request.write(body);

      final response = await request.close();
      client.close(force: false);

      final success = response.statusCode == 200 || response.statusCode == 201;
      AppLogging.tak(
        'PositionPublisher: POST /v1/tak/publish -> '
        '${response.statusCode} ${success ? "OK" : "FAILED"}',
      );
      return success;
    } catch (e) {
      AppLogging.tak('PositionPublisher: POST /v1/tak/publish failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  String _buildWsUrl(String? token) {
    final base = gatewayUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final params = <String, String>{};
    if (scope != null) params['scope'] = scope!;
    // Pass token as query param for environments where WS headers are not supported
    if (token != null) params['token'] = token;

    final uri = Uri.parse('$base/v1/tak/stream');
    return uri
        .replace(queryParameters: params.isNotEmpty ? params : null)
        .toString();
  }

  void _onMessage(dynamic data) {
    if (_disposed) return;
    try {
      final raw = data as String;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final msgType = json['type'] as String?;
      AppLogging.tak(
        'WS message received: type=$msgType, size=${raw.length} bytes',
      );

      if (msgType == 'event') {
        final eventJson = json['event'] as Map<String, dynamic>;
        final event = TakEvent.fromJson(eventJson);
        _totalEventsReceived++;
        AppLogging.tak(
          'Event: uid=${event.uid}, type=${event.type}, '
          'callsign=${event.callsign ?? "none"}, '
          'lat=${event.lat.toStringAsFixed(4)}, '
          'lon=${event.lon.toStringAsFixed(4)}, '
          'total=$_totalEventsReceived',
        );
        if (!_eventController.isClosed) {
          _eventController.add(event);
        }
      } else if (msgType == 'snapshot') {
        final eventsJson = json['events'] as List<dynamic>;
        final events = eventsJson
            .map((e) => TakEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalEventsReceived += events.length;
        AppLogging.tak(
          'Snapshot backfill: ${events.length} events, total=$_totalEventsReceived',
        );
        if (!_snapshotController.isClosed) {
          _snapshotController.add(events);
        }
      } else {
        AppLogging.tak('Unknown message type: $msgType');
      }
    } catch (e) {
      AppLogging.tak('Failed to parse message: $e');
    }
  }

  void _onError(Object error) {
    _lastError = error.toString();
    AppLogging.tak('WebSocket error: $error');
  }

  void _onDone() {
    _socket = null;
    _connectedSince = null;
    if (_state != TakConnectionState.disconnected) {
      AppLogging.tak('Connection closed unexpectedly, scheduling reconnect');
      _scheduleReconnect();
    } else {
      AppLogging.tak('Connection closed (expected)');
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (maxReconnectAttempts > 0 &&
        _reconnectAttempts >= maxReconnectAttempts) {
      AppLogging.tak(
        'Max reconnect attempts reached ($maxReconnectAttempts), giving up',
      );
      _setState(TakConnectionState.disconnected);
      return;
    }

    _setState(TakConnectionState.reconnecting);
    _reconnectAttempts++;
    _totalReconnects++;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    final delaySeconds = min(pow(2, _reconnectAttempts - 1).toInt(), 30);
    AppLogging.tak(
      'Reconnecting in ${delaySeconds}s '
      '(attempt $_reconnectAttempts, total reconnects: $_totalReconnects)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  void _setState(TakConnectionState newState) {
    if (_disposed || _state == newState) return;
    AppLogging.tak('State: ${_state.name} -> ${newState.name}');
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
