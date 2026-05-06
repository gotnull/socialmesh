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

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart' show Uint8Buffer;

import '../../core/logging.dart';

// ---------------------------------------------------------------------------
// Diagnostics state — exposed to UI for the diagnostics surface
// ---------------------------------------------------------------------------

/// High-level lifecycle phase of the MQTT client proxy. The mqtt_client
/// package does not expose discrete DNS/TCP/TLS/AUTH stages, so this is a
/// best-effort projection: `connecting` covers everything between the
/// connect call and either a successful CONNACK or a thrown exception.
enum MqttProxyConnectionPhase {
  /// Proxy mode is off (or MQTT module disabled). No connection is desired.
  disabled,

  /// Proxy is desired but config is incomplete (host/topic root missing).
  missingConfig,

  /// Proxy is desired and configured but no connect has been attempted yet.
  idle,

  /// Connect call in flight (DNS / TCP / TLS / auth all collapse here).
  connecting,

  /// Connected — publish is allowed.
  connected,

  /// Cleanly disconnected (intentional or by remote with no error to report).
  disconnected,

  /// Last attempt failed. See [MqttProxyFailureReason] for the cause.
  failed,
}

/// Reason for the last failure or for why a connect/publish was suppressed.
/// `none` is used in healthy states (idle / connecting / connected).
enum MqttProxyFailureReason {
  none,
  missingHost,
  missingTopicRoot,
  invalidPort,
  dnsFailure,
  tcpConnectionRefused,
  tcpTimeout,
  tlsHandshakeFailed,
  tlsCertificateRejected,
  authenticationFailed,
  protocolRejected,
  brokerDisconnected,
  clientDisposed,
  // User has enabled "Map Reporting" but has not opted-in to the
  // privacy disclaimer that authorizes the unencrypted broadcast of
  // their device's real-time location. The proxy refuses to come up at
  // all in this state — the radio's MQTT config can still publish on
  // its own (if the device has WiFi), but the app-side bridge stays
  // disconnected until consent is recorded.
  mapReportingConsentRequired,
  unknown,
}

/// Snapshot of the MQTT client proxy connection state for diagnostics.
class MqttProxyDiagnostics {
  /// High-level phase. Source of truth for UI status row.
  final MqttProxyConnectionPhase phase;

  /// Reason for the last failure / suppression. `none` when healthy.
  final MqttProxyFailureReason failureReason;

  /// Whether the proxy is currently connected to the broker. Derived from
  /// [phase] but kept as a top-level field for backwards-compat callers.
  final bool isConnected;

  /// The broker host we are connecting to.
  final String? brokerHost;

  /// The broker port.
  final int? brokerPort;

  /// Whether TLS is enabled.
  final bool tlsEnabled;

  /// Whether authentication credentials are configured.
  final bool hasAuth;

  /// The MQTT topic root currently in effect (e.g. `msh/US/OVMesh`).
  final String? topicRoot;

  /// The MQTT topic we are subscribed to.
  final String? subscribedTopic;

  /// Timestamp of the last connection attempt.
  final DateTime? lastConnectAttempt;

  /// Timestamp of the last successful connection.
  final DateTime? lastConnectedAt;

  /// Timestamp of the last disconnection.
  final DateTime? lastDisconnectedAt;

  /// Timestamp of the last failure transition.
  final DateTime? lastFailureAt;

  /// The last error message encountered (sanitized — no secrets).
  final String? lastError;

  /// Number of messages relayed from device to broker.
  final int messagesPublished;

  /// Number of messages relayed from broker to device.
  final int messagesRelayed;

  /// Number of reconnect attempts.
  final int reconnectAttempts;

  const MqttProxyDiagnostics({
    this.phase = MqttProxyConnectionPhase.idle,
    this.failureReason = MqttProxyFailureReason.none,
    this.isConnected = false,
    this.brokerHost,
    this.brokerPort,
    this.tlsEnabled = false,
    this.hasAuth = false,
    this.topicRoot,
    this.subscribedTopic,
    this.lastConnectAttempt,
    this.lastConnectedAt,
    this.lastDisconnectedAt,
    this.lastFailureAt,
    this.lastError,
    this.messagesPublished = 0,
    this.messagesRelayed = 0,
    this.reconnectAttempts = 0,
  });

  /// Whether a publish attempt should be allowed right now.
  bool get canPublish => phase == MqttProxyConnectionPhase.connected;

  /// Creates a redacted copy safe for display (no secrets).
  MqttProxyDiagnostics copyWith({
    MqttProxyConnectionPhase? phase,
    MqttProxyFailureReason? failureReason,
    bool? isConnected,
    String? brokerHost,
    int? brokerPort,
    bool? tlsEnabled,
    bool? hasAuth,
    String? topicRoot,
    String? subscribedTopic,
    DateTime? lastConnectAttempt,
    DateTime? lastConnectedAt,
    DateTime? lastDisconnectedAt,
    DateTime? lastFailureAt,
    String? lastError,
    int? messagesPublished,
    int? messagesRelayed,
    int? reconnectAttempts,
  }) {
    return MqttProxyDiagnostics(
      phase: phase ?? this.phase,
      failureReason: failureReason ?? this.failureReason,
      isConnected: isConnected ?? this.isConnected,
      brokerHost: brokerHost ?? this.brokerHost,
      brokerPort: brokerPort ?? this.brokerPort,
      tlsEnabled: tlsEnabled ?? this.tlsEnabled,
      hasAuth: hasAuth ?? this.hasAuth,
      topicRoot: topicRoot ?? this.topicRoot,
      subscribedTopic: subscribedTopic ?? this.subscribedTopic,
      lastConnectAttempt: lastConnectAttempt ?? this.lastConnectAttempt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastDisconnectedAt: lastDisconnectedAt ?? this.lastDisconnectedAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      lastError: lastError ?? this.lastError,
      messagesPublished: messagesPublished ?? this.messagesPublished,
      messagesRelayed: messagesRelayed ?? this.messagesRelayed,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

/// Result of [MqttClientProxyService.preflight]: either a passing config
/// with the resolved host/port, or a failing reason. Returned to callers
/// so they can both log the structured outcome and pass through.
class MqttProxyPreflightResult {
  const MqttProxyPreflightResult.ok({
    required this.host,
    required this.port,
    required this.tlsEnabled,
    required this.topicRoot,
    required this.usernamePresent,
  }) : reason = MqttProxyFailureReason.none;

  const MqttProxyPreflightResult.fail(this.reason)
    : host = null,
      port = null,
      tlsEnabled = false,
      topicRoot = null,
      usernamePresent = false;

  final MqttProxyFailureReason reason;
  final String? host;
  final int? port;
  final bool tlsEnabled;
  final String? topicRoot;
  final bool usernamePresent;

  bool get ok => reason == MqttProxyFailureReason.none;
}

// ---------------------------------------------------------------------------
// Connect args — used for idempotency checks (settled + in-flight)
// ---------------------------------------------------------------------------

/// Snapshot of the parameters used for a [MqttClientProxyService.connect]
/// invocation. Used internally to short-circuit redundant connect calls
/// when (a) the service is already settled with these exact args and the
/// live socket agrees, or (b) an in-flight attempt with these exact args
/// is already running.
///
/// The password is intentionally NOT part of equality — credentials must
/// not influence reconnect decisions and must never be logged via the
/// generated `toString`.
class _ConnectArgs {
  const _ConnectArgs({
    required this.host,
    required this.port,
    required this.tlsEnabled,
    required this.hasAuth,
    required this.username,
    required this.topicPrefix,
    required this.shouldSubscribe,
    required this.nodeUserId,
  });

  final String host;
  final int port;
  final bool tlsEnabled;
  final bool hasAuth;
  final String username;
  final String topicPrefix;
  final bool shouldSubscribe;
  final String? nodeUserId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ConnectArgs &&
          other.host == host &&
          other.port == port &&
          other.tlsEnabled == tlsEnabled &&
          other.hasAuth == hasAuth &&
          other.username == username &&
          other.topicPrefix == topicPrefix &&
          other.shouldSubscribe == shouldSubscribe &&
          other.nodeUserId == nodeUserId;

  @override
  int get hashCode => Object.hash(
    host,
    port,
    tlsEnabled,
    hasAuth,
    username,
    topicPrefix,
    shouldSubscribe,
    nodeUserId,
  );

  @override
  String toString() =>
      '_ConnectArgs(host: $host, port: $port, tls: $tlsEnabled, ' // lint-allow: hardcoded-string
      'auth: $hasAuth, topic: $topicPrefix, sub: $shouldSubscribe)'; // lint-allow: hardcoded-string
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

  // Idempotency state — see _ConnectArgs.
  // _lastConnectArgs: the args of the currently settled connection.
  // _pendingConnectArgs: the args of an in-flight connect attempt.
  _ConnectArgs? _lastConnectArgs;
  _ConnectArgs? _pendingConnectArgs;

  // Test-only seam: lets unit tests simulate "live socket connected"
  // without holding a real MqttServerClient. Always false in production.
  bool _debugSimulateLiveSocket = false;

  // Test observability: counts how many times connect() proceeded past
  // the idempotency short-circuits and started actual destructive work.
  int _debugConnectAttemptsStarted = 0;

  // Diagnostics state
  MqttProxyConnectionPhase _phase = MqttProxyConnectionPhase.idle;
  MqttProxyFailureReason _failureReason = MqttProxyFailureReason.none;
  String? _brokerHost;
  int? _brokerPort;
  bool _tlsEnabled = false;
  bool _hasAuth = false;
  String? _topicRoot;
  String? _subscribedTopic;
  DateTime? _lastConnectAttempt;
  DateTime? _lastConnectedAt;
  DateTime? _lastDisconnectedAt;
  DateTime? _lastFailureAt;
  String? _lastError;
  int _messagesPublished = 0;
  int _messagesRelayed = 0;
  int _reconnectAttempts = 0;

  // Publish suppression dedupe — collapse repeated identical warnings on
  // the same (phase, reason, topic-family) tuple to avoid log spam when
  // the device fires bursts during an outage.
  String? _lastSuppressionKey;
  DateTime? _lastSuppressionLogAt;
  static const Duration _suppressionDedupeWindow = Duration(seconds: 5);

  /// Stream controller for diagnostics updates.
  final StreamController<MqttProxyDiagnostics> _diagnosticsController =
      StreamController<MqttProxyDiagnostics>.broadcast();

  /// Stream of diagnostics updates.
  Stream<MqttProxyDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Current diagnostics snapshot.
  MqttProxyDiagnostics get diagnostics => MqttProxyDiagnostics(
    phase: _phase,
    failureReason: _failureReason,
    isConnected: _phase == MqttProxyConnectionPhase.connected,
    brokerHost: _brokerHost,
    brokerPort: _brokerPort,
    tlsEnabled: _tlsEnabled,
    hasAuth: _hasAuth,
    topicRoot: _topicRoot,
    subscribedTopic: _subscribedTopic,
    lastConnectAttempt: _lastConnectAttempt,
    lastConnectedAt: _lastConnectedAt,
    lastDisconnectedAt: _lastDisconnectedAt,
    lastFailureAt: _lastFailureAt,
    lastError: _lastError,
    messagesPublished: _messagesPublished,
    messagesRelayed: _messagesRelayed,
    reconnectAttempts: _reconnectAttempts,
  );

  /// Whether the proxy is currently connected.
  bool get isConnected => _phase == MqttProxyConnectionPhase.connected;

  /// Current high-level lifecycle phase.
  MqttProxyConnectionPhase get phase => _phase;

  /// Current structured failure reason.
  MqttProxyFailureReason get failureReason => _failureReason;

  /// Test-only: number of times [connect] proceeded past idempotency
  /// short-circuits and started actual reconnect work.
  @visibleForTesting
  int get debugConnectAttemptsStarted => _debugConnectAttemptsStarted;

  /// Test-only: primes the service into a "settled connected" state
  /// without holding a real [MqttServerClient]. Lets unit tests verify
  /// that an immediately-following [connect] call with matching args
  /// short-circuits as a no-op, without requiring a live broker.
  @visibleForTesting
  void debugMarkSettledForTest({
    required String host,
    required int port,
    required bool tlsEnabled,
    required String username,
    required String topicPrefix,
    required bool shouldSubscribe,
    String? nodeUserId,
  }) {
    _phase = MqttProxyConnectionPhase.connected;
    _failureReason = MqttProxyFailureReason.none;
    _brokerHost = host;
    _brokerPort = port;
    _tlsEnabled = tlsEnabled;
    _hasAuth = username.isNotEmpty;
    _lastConnectArgs = _ConnectArgs(
      host: host,
      port: port,
      tlsEnabled: tlsEnabled,
      hasAuth: username.isNotEmpty,
      username: username,
      topicPrefix: topicPrefix,
      shouldSubscribe: shouldSubscribe,
      nodeUserId: nodeUserId,
    );
    _debugSimulateLiveSocket = true;
  }

  /// Sets the callback for forwarding broker messages to the device.
  void setOnBrokerMessage(OnBrokerMessageFn fn) {
    _onBrokerMessage = fn;
  }

  /// Connects to the broker.
  ///
  /// [address] is `host:port` or just `host` (defaults to mqtt.meshtastic.org).
  /// [topicPrefix] is the topic prefix to subscribe to (e.g. `msh/2/e`).
  /// [nodeUserId] is the user ID string for client identification.
  /// [shouldSubscribe] controls whether to subscribe to inbound topics.
  /// Per the official Meshtastic app, subscribe only when at least one
  /// channel has downlink enabled. When false, the proxy can still publish
  /// (uplink) but will not receive messages from the broker.
  Future<void> connect({
    required String address,
    required bool tlsEnabled,
    required String username,
    required String password,
    required String topicPrefix,
    String? nodeUserId,
    bool shouldSubscribe = false,
  }) async {
    if (_disposed) return;

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

    final newArgs = _ConnectArgs(
      host: host,
      port: port,
      tlsEnabled: useTls,
      hasAuth: username.isNotEmpty,
      username: username,
      topicPrefix: topicPrefix,
      shouldSubscribe: shouldSubscribe,
      nodeUserId: nodeUserId,
    );

    // Settled idempotency: already connected with these exact args AND
    // the live socket agrees. The third clause guards iOS background
    // socket teardown where the phase may be stale `connected`.
    final liveSocketConnected =
        _client?.connectionStatus?.state == MqttConnectionState.connected ||
        _debugSimulateLiveSocket;
    if (_phase == MqttProxyConnectionPhase.connected &&
        _lastConnectArgs == newArgs &&
        liveSocketConnected) {
      AppLogging.mqttProxy(
        'connect: idempotent no-op (settled, args match $newArgs)',
      );
      _emitDiagnostics();
      return;
    }

    // In-flight idempotency: an attempt with these exact args is already
    // running. Coalesce — let the first attempt finish; do not start a
    // duplicate destructive reconnect.
    if (_isConnecting && _pendingConnectArgs == newArgs) {
      AppLogging.mqttProxy(
        'connect: in-flight attempt with same args; coalescing',
      );
      _emitDiagnostics();
      return;
    }

    // Generic safety: an attempt with DIFFERENT args is already running.
    // Reject duplicates while in-flight (preserves the original guard).
    if (_isConnecting) {
      AppLogging.mqttProxy(
        'connect: already in progress (different args); ignoring',
      );
      return;
    }

    _isConnecting = true;
    _pendingConnectArgs = newArgs;
    _debugConnectAttemptsStarted++;
    _intentionalDisconnect = false;

    _lastConnectAttempt = DateTime.now();
    _lastError = null;
    _failureReason = MqttProxyFailureReason.none;
    _phase = MqttProxyConnectionPhase.connecting;

    _brokerHost = host;
    _brokerPort = port;
    _tlsEnabled = useTls;
    _hasAuth = username.isNotEmpty;
    // topicPrefix is "<root>/2/e" — strip the suffix so diagnostics
    // surface the user-configured root, not the derived publish prefix.
    _topicRoot = topicPrefix.endsWith('/2/e')
        ? topicPrefix.substring(0, topicPrefix.length - 4)
        : topicPrefix;
    _emitDiagnostics();

    AppLogging.mqttProxy(
      'Connecting to $host:$port '
      '(TLS: $useTls, auth: ${username.isNotEmpty})',
    );

    // Disconnect any existing client
    await _disconnectClient();

    // Create MQTT client
    final clientId =
        'SocialMeshMqttProxy-${nodeUserId ?? DateTime.now().millisecondsSinceEpoch}'; // lint-allow: hardcoded-string
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

    // Connection message.
    //
    // Will message: topic="/will", payload="dieout". Setting Will Topic
    // + Will Message turns Will Flag=1 with default Will QoS=0, which
    // is spec-compliant per MQTT-3.1.2-13.
    //
    // Do NOT add `.withWillQos(MqttQos.atLeastOnce)` here unless you
    // also call `.withWillTopic` + `.withWillMessage` — without those,
    // the Will Flag stays 0 and a non-zero Will QoS violates the spec,
    // causing strict brokers (ovmesh.com, EMQX) to silently TCP-close
    // the CONNECT and surface as a "Missing Connection Acknowledgement"
    // timeout 47 s later. Lenient brokers (mosquitto default,
    // mqtt.meshtastic.org) accept it — which is why an earlier version
    // of this code shipped the violation undetected.
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('/will') // lint-allow: hardcoded-string
        .withWillMessage('dieout') // lint-allow: hardcoded-string
        .startClean();

    if (username.isNotEmpty) {
      connMessage.authenticateAs(username, password);
    }

    client.connectionMessage = connMessage;

    _client = client;

    try {
      final status = await client.connect();
      if (status?.state == MqttConnectionState.connected) {
        AppLogging.mqttProxy('Connected to broker $host:$port');
        _phase = MqttProxyConnectionPhase.connected;
        _failureReason = MqttProxyFailureReason.none;
        _lastConnectArgs = newArgs;
        _lastConnectedAt = DateTime.now();
        _reconnectAttempts = 0;
        _lastError = null;

        // Subscribe to the topic only if downlink is enabled on at least
        // one channel.  This matches the official Meshtastic iOS app: when no
        // channel has downlinkEnabled, the proxy connects (allowing the device
        // to publish / uplink) but does NOT subscribe (no inbound MQTT
        // messages are relayed to the device).
        if (shouldSubscribe) {
          final subscriptionTopic = '$topicPrefix/#';
          _subscribedTopic = subscriptionTopic;
          AppLogging.mqttProxy('Subscribing to $subscriptionTopic');
          client.subscribe(subscriptionTopic, MqttQos.atLeastOnce);
        } else {
          _subscribedTopic = null;
          AppLogging.mqttProxy(
            'Connected but NOT subscribing '
            '(no channel has downlink enabled)',
          );
        }

        // Listen for inbound messages
        _subscription = client.updates?.listen(_handleInboundMessage);

        _emitDiagnostics();
      } else {
        final stateName = status?.state.name ?? 'unknown';
        final reason = _mapNoConnectionStatus(status);
        await _failConnect(
          reason: reason,
          summary: 'Connection failed: $stateName',
          rawDetail: stateName,
        );
      }
    } on NoConnectionException catch (e) {
      final reason = debugMapNoConnectionExceptionMessage(e.toString());
      await _failConnect(
        reason: reason,
        summary: 'Connection refused', // lint-allow: hardcoded-string
        rawDetail: e.toString(),
      );
    } on SocketException catch (e) {
      final reason = _mapSocketException(e);
      await _failConnect(
        reason: reason,
        summary: 'Socket error', // lint-allow: hardcoded-string
        rawDetail: e.message,
      );
    } on HandshakeException catch (e) {
      final reason = _mapHandshakeException(e);
      await _failConnect(
        reason: reason,
        summary: 'TLS handshake failed', // lint-allow: hardcoded-string
        rawDetail: e.message,
      );
    } on TlsException catch (e) {
      // SecureSocket / cert-store level failures (rare; handshake covers most).
      await _failConnect(
        reason: MqttProxyFailureReason.tlsHandshakeFailed,
        summary: 'TLS error', // lint-allow: hardcoded-string
        rawDetail: e.message,
      );
    } catch (e) {
      await _failConnect(
        reason: MqttProxyFailureReason.unknown,
        summary: 'Unexpected error', // lint-allow: hardcoded-string
        rawDetail: e.toString(),
      );
    } finally {
      _isConnecting = false;
      _pendingConnectArgs = null;
    }
  }

  /// Marks the service as failed with a structured reason, sanitizes and
  /// records the raw detail, logs it, and tears down the underlying client.
  Future<void> _failConnect({
    required MqttProxyFailureReason reason,
    required String summary,
    required String rawDetail,
  }) async {
    final sanitized = _sanitizeError(rawDetail);
    AppLogging.mqttProxyError('$summary [reason=${reason.name}]: $sanitized');
    _phase = MqttProxyConnectionPhase.failed;
    _failureReason = reason;
    _lastError = sanitized;
    _lastFailureAt = DateTime.now();
    _lastConnectArgs = null;
    await _disconnectClient();
    _emitDiagnostics();
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
    if (_disposed) {
      _logSuppressedPublish(
        topic: topic,
        phase: MqttProxyConnectionPhase.disabled,
        reason: MqttProxyFailureReason.clientDisposed,
        kind: 'suppressed',
      );
      return;
    }

    // Reason-aware gating: surface the actual phase/reason instead of a
    // bare "not connected" so support can distinguish disabled vs missing
    // config vs in-flight vs failed-with-reason.
    if (_phase != MqttProxyConnectionPhase.connected || _client == null) {
      _logSuppressedPublish(
        topic: topic,
        phase: _phase,
        reason: _failureReason,
        kind: _phase == MqttProxyConnectionPhase.connecting
            ? 'deferred'
            : 'suppressed',
      );
      return;
    }

    // Guard against race where phase is `connected` but the MQTT client's
    // internal state is still 'connecting' (e.g. reconnect in progress).
    // Publishing in this state throws a ConnectionException.
    final clientState =
        _client!.connectionStatus?.state ?? MqttConnectionState.disconnected;
    if (clientState != MqttConnectionState.connected) {
      _logSuppressedPublish(
        topic: topic,
        phase: MqttProxyConnectionPhase.connecting,
        reason: MqttProxyFailureReason.none,
        kind: 'deferred',
        clientStateLabel: clientState.name,
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
    _phase = MqttProxyConnectionPhase.disconnected;
    _failureReason = MqttProxyFailureReason.none;
    _lastDisconnectedAt = DateTime.now();
    _subscribedTopic = null;
    _lastConnectArgs = null;
    _debugSimulateLiveSocket = false;
    AppLogging.mqttProxy('Disconnected from broker');
    _emitDiagnostics();
  }

  /// Marks the service as `disabled` — proxy mode is off. Used by the
  /// provider when MQTT or the proxy toggle is turned off so the UI can
  /// distinguish "off" from "failed".
  void markDisabled() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _phase = MqttProxyConnectionPhase.disabled;
    _failureReason = MqttProxyFailureReason.none;
    _lastError = null;
    _subscribedTopic = null;
    _lastConnectArgs = null;
    _debugSimulateLiveSocket = false;
    _emitDiagnostics();
  }

  /// Marks the service as `missingConfig` with a structured reason. Used
  /// by the provider when preflight fails so the UI surfaces *why* the
  /// proxy never attempted a connection.
  void markMissingConfig(MqttProxyFailureReason reason) {
    _phase = MqttProxyConnectionPhase.missingConfig;
    _failureReason = reason;
    _lastFailureAt = DateTime.now();
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
    _phase = MqttProxyConnectionPhase.disconnected;
    _failureReason = MqttProxyFailureReason.clientDisposed;
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

      // Drop broker stat / heartbeat traffic before forwarding to the
      // radio. The public Meshtastic broker (and many compatible
      // brokers) publishes node-status updates on `…/stat/…`
      // subtopics — these are not LoRa frames and have no value to the
      // radio's downlink path. Forwarding them wastes airtime + battery.
      if (topic.contains('/stat/')) {
        AppLogging.mqttProxy(
          'Skipped broker stat topic: $topic (${payload.length} bytes)',
        );
        continue;
      }

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
    _phase = MqttProxyConnectionPhase.connected;
    _failureReason = MqttProxyFailureReason.none;
    _lastConnectedAt = DateTime.now();
    _lastError = null;
    _emitDiagnostics();
  }

  void _onDisconnected() {
    _lastDisconnectedAt = DateTime.now();
    if (_intentionalDisconnect) {
      _phase = MqttProxyConnectionPhase.disconnected;
      _failureReason = MqttProxyFailureReason.none;
    } else {
      // Unexpected drop after a previously good connection. Preserve any
      // existing failureReason from a recent connect failure; otherwise
      // attribute it to the broker.
      _phase = MqttProxyConnectionPhase.failed;
      if (_failureReason == MqttProxyFailureReason.none) {
        _failureReason = MqttProxyFailureReason.brokerDisconnected;
      }
      _lastError ??= 'Connection lost'; // lint-allow: hardcoded-string
      _lastFailureAt = DateTime.now();
    }
    AppLogging.mqttProxyWarning(
      'Broker callback: disconnected'
      '${_intentionalDisconnect ? ' (intentional)' : ' (unexpected)'}', // lint-allow: hardcoded-string
    );
    _emitDiagnostics();
  }

  void _onAutoReconnect() {
    _reconnectAttempts++;
    _phase = MqttProxyConnectionPhase.connecting;
    AppLogging.mqttProxy('Auto-reconnect attempt $_reconnectAttempts');
    _emitDiagnostics();
  }

  void _onAutoReconnected() {
    AppLogging.mqttProxy('Auto-reconnected successfully');
    _phase = MqttProxyConnectionPhase.connected;
    _failureReason = MqttProxyFailureReason.none;
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

  /// Reason-aware publish suppression log with dedupe.
  ///
  /// Collapses bursts of identical (phase, reason, topic-family) warnings
  /// inside [_suppressionDedupeWindow] so a sustained outage does not
  /// flood the log. The first hit always logs; subsequent hits within the
  /// window for the same key are dropped.
  void _logSuppressedPublish({
    required String topic,
    required MqttProxyConnectionPhase phase,
    required MqttProxyFailureReason reason,
    required String kind, // 'suppressed' | 'deferred'
    String? clientStateLabel,
  }) {
    final family = _topicFamily(topic);
    final key =
        '$kind|${phase.name}|${reason.name}|$family|${clientStateLabel ?? ''}';
    final now = DateTime.now();
    if (_lastSuppressionKey == key &&
        _lastSuppressionLogAt != null &&
        now.difference(_lastSuppressionLogAt!) < _suppressionDedupeWindow) {
      return;
    }
    _lastSuppressionKey = key;
    _lastSuppressionLogAt = now;

    final phaseTag = phase.name;
    final reasonTag = reason.name;
    final clientTag = clientStateLabel != null
        ? ' clientState=$clientStateLabel'
        : '';
    final msg =
        'publish $kind: phase=$phaseTag reason=$reasonTag topic=$topic$clientTag'; // lint-allow: hardcoded-string
    AppLogging.mqttProxyWarning(msg);
  }

  /// Strips the trailing node-id (or other unique tail) so dedupe keys
  /// collapse `msh/.../!aaaa` and `msh/.../!bbbb` to one family.
  String _topicFamily(String topic) {
    final lastSlash = topic.lastIndexOf('/');
    if (lastSlash <= 0) return topic;
    return topic.substring(0, lastSlash);
  }

  /// Maps `NoConnectionException` to the most plausible structured reason.
  /// The mqtt_client package uses this for both "max retries exceeded" and
  /// "broker rejected CONNACK" — text inspection is the only way to tell.
  @visibleForTesting
  static MqttProxyFailureReason debugMapNoConnectionExceptionMessage(
    String exceptionText,
  ) {
    final msg = exceptionText.toLowerCase();
    if (msg.contains('not authori') || // lint-allow: hardcoded-string
        msg.contains('bad username') || // lint-allow: hardcoded-string
        msg.contains('bad password')) {
      return MqttProxyFailureReason.authenticationFailed;
    }
    // Strict brokers (ovmesh, EMQX) silently TCP-close on a protocol-violating
    // CONNECT. mqtt_client surfaces this as "Missing Connection Acknowledgement"
    // after maxConnectionAttempts retries. Map to protocolRejected so the
    // diagnostics card shows something actionable instead of "unknown".
    if (msg.contains(
          'missing connection acknowledgement',
        ) || // lint-allow: hardcoded-string
        msg.contains(
          'broker is not responding',
        ) || // lint-allow: hardcoded-string
        msg.contains('maximum allowed connection attempts')) {
      return MqttProxyFailureReason.protocolRejected;
    }
    if (msg.contains('refused') || msg.contains('rejected')) {
      return MqttProxyFailureReason.protocolRejected;
    }
    return MqttProxyFailureReason.unknown;
  }

  /// Maps a non-connected [MqttClientConnectionStatus] to a reason. The
  /// mqtt_client package surfaces broker CONNACK refusal via the status'
  /// `returnCode` enum.
  MqttProxyFailureReason _mapNoConnectionStatus(
    MqttClientConnectionStatus? status,
  ) {
    final code = status?.returnCode;
    if (code == null) return MqttProxyFailureReason.unknown;
    switch (code) {
      case MqttConnectReturnCode.badUsernameOrPassword:
      case MqttConnectReturnCode.notAuthorized:
        return MqttProxyFailureReason.authenticationFailed;
      case MqttConnectReturnCode.brokerUnavailable:
      case MqttConnectReturnCode.identifierRejected:
      case MqttConnectReturnCode.unacceptedProtocolVersion:
        return MqttProxyFailureReason.protocolRejected;
      case MqttConnectReturnCode.noneSpecified:
      case MqttConnectReturnCode.connectionAccepted:
        return MqttProxyFailureReason.unknown;
    }
  }

  /// Maps a [SocketException] to DNS / TCP-refused / TCP-timeout where
  /// possible. dart:io does not give us a structured error code, so we
  /// inspect the [OSError.message] / message text as a best-effort.
  MqttProxyFailureReason _mapSocketException(SocketException e) {
    final raw = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    if (raw.contains('failed host lookup') || // lint-allow: hardcoded-string
        raw.contains('nodename nor servname') || // lint-allow: hardcoded-string
        raw.contains('no address associated') || // lint-allow: hardcoded-string
        raw.contains('name or service not known')) {
      return MqttProxyFailureReason.dnsFailure;
    }
    if (raw.contains('timed out') || raw.contains('timeout')) {
      return MqttProxyFailureReason.tcpTimeout;
    }
    if (raw.contains('connection refused') || // lint-allow: hardcoded-string
        raw.contains('connection reset') || // lint-allow: hardcoded-string
        raw.contains(
          'network is unreachable',
        ) || // lint-allow: hardcoded-string
        raw.contains('host is unreachable')) {
      return MqttProxyFailureReason.tcpConnectionRefused;
    }
    return MqttProxyFailureReason.unknown;
  }

  /// Maps a [HandshakeException] to a TLS-cert vs generic-handshake reason.
  /// dart:io reports cert-chain failures via `CERTIFICATE_VERIFY_FAILED`
  /// embedded in the message.
  MqttProxyFailureReason _mapHandshakeException(HandshakeException e) {
    final raw = e.message.toLowerCase();
    if (raw.contains(
          'certificate_verify_failed',
        ) || // lint-allow: hardcoded-string
        raw.contains(
          'certificate verify failed',
        ) || // lint-allow: hardcoded-string
        raw.contains('hostname mismatch') || // lint-allow: hardcoded-string
        raw.contains(
          'unable to get local issuer',
        ) || // lint-allow: hardcoded-string
        raw.contains('self signed certificate')) {
      return MqttProxyFailureReason.tlsCertificateRejected;
    }
    return MqttProxyFailureReason.tlsHandshakeFailed;
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

  // ---------------------------------------------------------------------------
  // Static — preflight
  // ---------------------------------------------------------------------------

  /// Validates a candidate MQTT proxy configuration before any connect
  /// is attempted. Pure / side-effect-free so the provider layer can
  /// invoke it cheaply and call [markMissingConfig] on failure.
  ///
  /// Validates:
  /// - MQTT module enabled
  /// - Proxy-to-client toggle enabled
  /// - host non-empty
  /// - topic root non-empty
  /// - port (if specified inline as `host:port`) is in `[1, 65535]`
  ///
  /// Returns the resolved host/port/TLS/topic-root on success, or a
  /// structured failure reason on failure.
  static MqttProxyPreflightResult preflight({
    required bool mqttEnabled,
    required bool proxyToClientEnabled,
    required String address,
    required String topicRoot,
    required bool tlsEnabled,
    required String username,
  }) {
    if (!mqttEnabled || !proxyToClientEnabled) {
      // Caller should use markDisabled in this case; preflight returns a
      // benign "missingHost" only as a stable failure path. The provider
      // distinguishes disabled vs invalid before calling preflight.
      return const MqttProxyPreflightResult.fail(
        MqttProxyFailureReason.missingHost,
      );
    }
    if (address.trim().isEmpty) {
      return const MqttProxyPreflightResult.fail(
        MqttProxyFailureReason.missingHost,
      );
    }
    if (topicRoot.trim().isEmpty) {
      return const MqttProxyPreflightResult.fail(
        MqttProxyFailureReason.missingTopicRoot,
      );
    }

    String host;
    int port;
    bool userSpecifiedPort = false;
    if (address.contains(':')) {
      final parts = address.split(':');
      if (parts.length != 2 || parts[0].trim().isEmpty) {
        return const MqttProxyPreflightResult.fail(
          MqttProxyFailureReason.missingHost,
        );
      }
      host = parts[0];
      final parsed = int.tryParse(parts[1]);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        return const MqttProxyPreflightResult.fail(
          MqttProxyFailureReason.invalidPort,
        );
      }
      userSpecifiedPort = true;
      port = parsed;
    } else {
      host = address;
      port = tlsEnabled ? 8883 : 1883;
    }
    // Force TLS for the default Meshtastic broker.
    final useTls = tlsEnabled || host.toLowerCase() == 'mqtt.meshtastic.org';
    if (useTls && !userSpecifiedPort && port == 1883) {
      port = 8883;
    }

    return MqttProxyPreflightResult.ok(
      host: host,
      port: port,
      tlsEnabled: useTls,
      topicRoot: topicRoot,
      usernamePresent: username.isNotEmpty,
    );
  }
}
