// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MQTT Client Proxy Service — connects to an MQTT broker on behalf
/// of the Meshtastic device when `proxyToClientEnabled` is true.
///
/// 1. Device sends `FromRadio.mqttClientProxyMessage` → this service
///    publishes the payload to the broker.
/// 2. This service subscribes to the device's configured topic and
///    relays inbound messages back via `ToRadio.mqttClientProxyMessage`.
library;

import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' show Uint8Buffer;

import '../../core/logging.dart';

// ---------------------------------------------------------------------------
// Diagnostics state — exposed to UI for the diagnostics surface
// ---------------------------------------------------------------------------

/// Snapshot of the MQTT client proxy connection state for diagnostics.
class MqttProxyDiagnostics {
  /// Whether the proxy is currently connected to the broker.
  final bool isConnected;

  /// The broker host we are connecting to.
  final String? brokerHost;

  /// The broker port.
  final int? brokerPort;

  /// Whether TLS is enabled.
  final bool tlsEnabled;

  /// Whether authentication credentials are configured.
  final bool hasAuth;

  /// The MQTT topic we are subscribed to.
  final String? subscribedTopic;

  /// Timestamp of the last connection attempt.
  final DateTime? lastConnectAttempt;

  /// Timestamp of the last successful connection.
  final DateTime? lastConnectedAt;

  /// Timestamp of the last disconnection.
  final DateTime? lastDisconnectedAt;

  /// The last error message encountered.
  final String? lastError;

  /// Number of messages relayed from device to broker.
  final int messagesPublished;

  /// Number of messages relayed from broker to device.
  final int messagesRelayed;

  /// Number of reconnect attempts.
  final int reconnectAttempts;

  const MqttProxyDiagnostics({
    this.isConnected = false,
    this.brokerHost,
    this.brokerPort,
    this.tlsEnabled = false,
    this.hasAuth = false,
    this.subscribedTopic,
    this.lastConnectAttempt,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    this.lastError,
    this.messagesPublished = 0,
    this.messagesRelayed = 0,
    this.reconnectAttempts = 0,
  });

  /// Creates a redacted copy safe for display (no secrets).
  MqttProxyDiagnostics copyWith({
    bool? isConnected,
    String? brokerHost,
    int? brokerPort,
    bool? tlsEnabled,
    bool? hasAuth,
    String? subscribedTopic,
    DateTime? lastConnectAttempt,
    DateTime? lastConnectedAt,
    DateTime? lastDisconnectedAt,
    String? lastError,
    int? messagesPublished,
    int? messagesRelayed,
    int? reconnectAttempts,
  }) {
    return MqttProxyDiagnostics(
      isConnected: isConnected ?? this.isConnected,
      brokerHost: brokerHost ?? this.brokerHost,
      brokerPort: brokerPort ?? this.brokerPort,
      tlsEnabled: tlsEnabled ?? this.tlsEnabled,
      hasAuth: hasAuth ?? this.hasAuth,
      subscribedTopic: subscribedTopic ?? this.subscribedTopic,
      lastConnectAttempt: lastConnectAttempt ?? this.lastConnectAttempt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastDisconnectedAt: lastDisconnectedAt ?? this.lastDisconnectedAt,
      lastError: lastError ?? this.lastError,
      messagesPublished: messagesPublished ?? this.messagesPublished,
      messagesRelayed: messagesRelayed ?? this.messagesRelayed,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

// ---------------------------------------------------------------------------
// Callback for sending ToRadio messages back to the device
// ---------------------------------------------------------------------------

/// Callback when the service receives a message from the MQTT broker
/// that needs to be forwarded to the device.
typedef OnBrokerMessageFn =
    Future<void> Function(String topic, List<int> data, bool retained);

// ---------------------------------------------------------------------------
// MQTT Client Proxy Service
// ---------------------------------------------------------------------------

/// Manages an MQTT client connection on behalf of the Meshtastic device.
///
/// When the device has `proxyToClientEnabled = true`, the device will
/// not connect to MQTT itself. Instead, it sends/receives MQTT messages
/// through the phone app using `MqttClientProxyMessage` protobufs.
///
/// This service:
/// - Parses the device's MQTT config to extract broker details
/// - Connects to the broker using the `mqtt_client` package
/// - Subscribes to the appropriate topic
/// - Relays inbound broker messages to the device via [sendToRadio]
/// - Publishes outbound device messages to the broker
class MqttClientProxyService {
  MqttServerClient? _client;
  OnBrokerMessageFn? _onBrokerMessage;
  bool _isConnecting = false;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionalDisconnect = false;

  // Diagnostics state
  bool _isConnected = false;
  String? _brokerHost;
  int? _brokerPort;
  bool _tlsEnabled = false;
  bool _hasAuth = false;
  String? _subscribedTopic;
  DateTime? _lastConnectAttempt;
  DateTime? _lastConnectedAt;
  DateTime? _lastDisconnectedAt;
  String? _lastError;
  int _messagesPublished = 0;
  int _messagesRelayed = 0;
  int _reconnectAttempts = 0;

  /// Stream controller for diagnostics updates.
  final StreamController<MqttProxyDiagnostics> _diagnosticsController =
      StreamController<MqttProxyDiagnostics>.broadcast();

  /// Stream of diagnostics updates.
  Stream<MqttProxyDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Current diagnostics snapshot.
  MqttProxyDiagnostics get diagnostics => MqttProxyDiagnostics(
    isConnected: _isConnected,
    brokerHost: _brokerHost,
    brokerPort: _brokerPort,
    tlsEnabled: _tlsEnabled,
    hasAuth: _hasAuth,
    subscribedTopic: _subscribedTopic,
    lastConnectAttempt: _lastConnectAttempt,
    lastConnectedAt: _lastConnectedAt,
    lastDisconnectedAt: _lastDisconnectedAt,
    lastError: _lastError,
    messagesPublished: _messagesPublished,
    messagesRelayed: _messagesRelayed,
    reconnectAttempts: _reconnectAttempts,
  );

  /// Whether the proxy is currently connected.
  bool get isConnected => _isConnected;

  /// Sets the callback for forwarding broker messages to the device.
  void setOnBrokerMessage(OnBrokerMessageFn fn) {
    _onBrokerMessage = fn;
  }

  /// Connects to the broker.
  ///
  /// [address] is `host:port` or just `host` (defaults to mqtt.meshtastic.org).
  /// [topicPrefix] is the topic prefix to subscribe to (e.g. `msh/2/e`).
  /// [nodeUserId] is the user ID string for client identification.
  Future<void> connect({
    required String address,
    required bool tlsEnabled,
    required String username,
    required String password,
    required String topicPrefix,
    String? nodeUserId,
  }) async {
    if (_disposed) return;
    if (_isConnecting) {
      AppLogging.mqttProxy('Connect already in progress, ignoring duplicate');
      return;
    }
    _isConnecting = true;
    _intentionalDisconnect = false;

    _lastConnectAttempt = DateTime.now();
    _lastError = null;
    _emitDiagnostics();

    // Parse host and port from address field.
    // Address may be "host:port" or just "host".
    // Default: mqtt.meshtastic.org
    final defaultAddress =
        'mqtt.meshtastic.org'; // lint-allow: hardcoded-string
    final resolvedAddress = address.isNotEmpty ? address : defaultAddress;
    String host;
    int port;
    bool userSpecifiedPort = false;

    if (resolvedAddress.contains(':')) {
      final parts = resolvedAddress.split(':');
      host = parts[0];
      final parsed = int.tryParse(parts[1]);
      userSpecifiedPort = parsed != null;
      port = parsed ?? (tlsEnabled ? 8883 : 1883);
    } else {
      host = resolvedAddress;
      port = tlsEnabled ? 8883 : 1883;
    }

    // Force TLS for the default Meshtastic server
    final useTls = tlsEnabled || host.toLowerCase() == defaultAddress;

    // If TLS was force-enabled and the user did not explicitly set a port,
    // upgrade from the plain-text default (1883) to the TLS default (8883).
    if (useTls && !userSpecifiedPort && port == 1883) {
      port = 8883;
    }

    _brokerHost = host;
    _brokerPort = port;
    _tlsEnabled = useTls;
    _hasAuth = username.isNotEmpty;

    AppLogging.mqttProxy(
      'Connecting to $host:$port '
      '(TLS: $useTls, auth: ${username.isNotEmpty})',
    );

    // Disconnect any existing client
    await _disconnectClient();

    // Create MQTT client
    final clientId =
        'SocialmeshMqttProxy-${nodeUserId ?? DateTime.now().millisecondsSinceEpoch}'; // lint-allow: hardcoded-string
    final client = MqttServerClient.withPort(host, clientId, port);

    client.keepAlivePeriod = 60;
    client.connectTimeoutPeriod = 15000;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;

    client.onAutoReconnect = _onAutoReconnect;
    client.onAutoReconnected = _onAutoReconnected;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    // TLS configuration
    // The iOS app accepts self-signed certificates
    if (useTls) {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
      client.onBadCertificate = (Object _) => true; // Accept self-signed certs
    }

    // Authentication
    if (username.isNotEmpty) {
      AppLogging.mqttProxy('Auth configured (username: $username)');
    }

    // Connection message
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    if (username.isNotEmpty) {
      connMessage.authenticateAs(username, password);
    }

    client.connectionMessage = connMessage;

    _client = client;

    try {
      final status = await client.connect();
      if (status?.state == MqttConnectionState.connected) {
        AppLogging.mqttProxy('Connected to broker $host:$port');
        _isConnected = true;
        _lastConnectedAt = DateTime.now();
        _reconnectAttempts = 0;
        _lastError = null;

        // Subscribe to the topic
        // Topic format: {root}/2/e/#
        final subscriptionTopic = '$topicPrefix/#';
        _subscribedTopic = subscriptionTopic;
        AppLogging.mqttProxy('Subscribing to $subscriptionTopic');
        client.subscribe(subscriptionTopic, MqttQos.atLeastOnce);

        // Listen for inbound messages
        _subscription = client.updates?.listen(_handleInboundMessage);

        _emitDiagnostics();
      } else {
        final errorMsg =
            'Connection failed: ${status?.state.name ?? "unknown"}'; // lint-allow: hardcoded-string
        AppLogging.mqttProxyError(errorMsg);
        _lastError = errorMsg;
        _isConnected = false;
        await _disconnectClient();
        _emitDiagnostics();
      }
    } on NoConnectionException catch (e) {
      final errorMsg =
          'Connection refused: ${e.toString()}'; // lint-allow: hardcoded-string
      AppLogging.mqttProxyError(errorMsg);
      _lastError = _sanitizeError(e.toString());
      _isConnected = false;
      await _disconnectClient();
      _emitDiagnostics();
    } on SocketException catch (e) {
      final errorMsg =
          'Socket error: ${e.message}'; // lint-allow: hardcoded-string
      AppLogging.mqttProxyError(errorMsg);
      _lastError = _sanitizeError(e.message);
      _isConnected = false;
      await _disconnectClient();
      _emitDiagnostics();
    } on HandshakeException catch (e) {
      final errorMsg =
          'TLS handshake failed: ${e.message}'; // lint-allow: hardcoded-string
      AppLogging.mqttProxyError(errorMsg);
      _lastError = _sanitizeError(e.message);
      _isConnected = false;
      await _disconnectClient();
      _emitDiagnostics();
    } catch (e) {
      final errorMsg =
          'Unexpected error: ${e.toString()}'; // lint-allow: hardcoded-string
      AppLogging.mqttProxyError(errorMsg);
      _lastError = _sanitizeError(e.toString());
      _isConnected = false;
      await _disconnectClient();
      _emitDiagnostics();
    } finally {
      _isConnecting = false;
    }
  }

  /// Handles a device publish request (publish to broker).
  ///
  /// Called by the provider layer when it receives a
  /// `FromRadio.mqttClientProxyMessage` from the device.
  ///
  /// Provide either [data] (binary) or [text] (UTF-8 string).
  void handleDevicePublish({
    required String topic,
    List<int>? data,
    String? text,
    bool retained = false,
  }) {
    if (_disposed || _client == null || !_isConnected) {
      AppLogging.mqttProxyWarning(
        'Cannot publish: not connected (topic: $topic)',
      );
      return;
    }

    // Guard against race where _isConnected is true but the MQTT client's
    // internal state is still 'connecting' (e.g. reconnect in progress).
    // Publishing in this state throws a ConnectionException.
    final clientState =
        _client!.connectionStatus?.state ?? MqttConnectionState.disconnected;
    if (clientState != MqttConnectionState.connected) {
      AppLogging.mqttProxyWarning(
        'Cannot publish: client state is $clientState (topic: $topic)',
      );
      return;
    }

    if (data == null && text == null) {
      AppLogging.mqttProxy(
        'Ignoring proxy message with no payload '
        '(topic: $topic)',
      );
      return;
    }

    final builder = MqttClientPayloadBuilder();

    if (data != null) {
      final buffer = Uint8Buffer()..addAll(data);
      builder.addBuffer(buffer);
    } else if (text != null) {
      builder.addUTF8String(text);
    }

    AppLogging.mqttProxy(
      'Publishing to $topic '
      '(${builder.payload?.length ?? 0} bytes, '
      'retained: $retained)',
    );

    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retained,
    );

    _messagesPublished++;
    _emitDiagnostics();
  }

  /// Disconnects from the broker.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    await _disconnectClient();
    _isConnected = false;
    _lastDisconnectedAt = DateTime.now();
    _subscribedTopic = null;
    AppLogging.mqttProxy('Disconnected from broker');
    _emitDiagnostics();
  }

  /// Releases all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _client?.disconnect();
    _diagnosticsController.close();
    AppLogging.mqttProxy('Service disposed');
  }

  // ---------------------------------------------------------------------------
  // Private — message handling
  // ---------------------------------------------------------------------------

  /// Handles an inbound MQTT message from the broker.
  /// Calls the [_onBrokerMessage] callback to forward to the device.
  void _handleInboundMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    if (_disposed || _onBrokerMessage == null) return;

    for (final msg in messages) {
      final publishMsg = msg.payload as MqttPublishMessage;
      final payload = publishMsg.payload.message;
      final topic = msg.topic;
      final retained = publishMsg.header!.retain;

      AppLogging.mqttProxy(
        'Received from broker: $topic (${payload.length} bytes)',
      );

      _onBrokerMessage!(topic, List<int>.from(payload), retained);
      _messagesRelayed++;
    }

    _emitDiagnostics();
  }

  // ---------------------------------------------------------------------------
  // Private — connection callbacks
  // ---------------------------------------------------------------------------

  void _onConnected() {
    AppLogging.mqttProxy('Broker callback: connected');
    _isConnected = true;
    _lastConnectedAt = DateTime.now();
    _lastError = null;
    _emitDiagnostics();
  }

  void _onDisconnected() {
    _isConnected = false;
    _lastDisconnectedAt = DateTime.now();
    if (!_intentionalDisconnect) {
      _lastError = 'Connection lost'; // lint-allow: hardcoded-string
    }
    AppLogging.mqttProxyWarning(
      'Broker callback: disconnected'
      '${_intentionalDisconnect ? ' (intentional)' : ' (unexpected)'}', // lint-allow: hardcoded-string
    );
    _emitDiagnostics();
  }

  void _onAutoReconnect() {
    _reconnectAttempts++;
    AppLogging.mqttProxy('Auto-reconnect attempt $_reconnectAttempts');
    _emitDiagnostics();
  }

  void _onAutoReconnected() {
    AppLogging.mqttProxy('Auto-reconnected successfully');
    _isConnected = true;
    _lastConnectedAt = DateTime.now();
    _lastError = null;
    _emitDiagnostics();
  }

  // ---------------------------------------------------------------------------
  // Private — helpers
  // ---------------------------------------------------------------------------

  Future<void> _disconnectClient() async {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;
  }

  void _emitDiagnostics() {
    if (!_diagnosticsController.isClosed) {
      _diagnosticsController.add(diagnostics);
    }
  }

  /// Sanitizes error messages to avoid leaking credentials.
  String _sanitizeError(String error) {
    // Strip any embedded passwords or auth tokens
    return error
        .replaceAll(
          RegExp(r'password[=:]\S+', caseSensitive: false),
          'password=***',
        )
        .replaceAll(RegExp(r'token[=:]\S+', caseSensitive: false), 'token=***');
  }
}
