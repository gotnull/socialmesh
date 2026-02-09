// SPDX-License-Identifier: GPL-3.0-or-later

/// MqttService — mockable abstraction for MQTT client operations.
///
/// This interface decouples the Global Layer UI and provider layers
/// from any specific MQTT client library. All network-touching MQTT
/// operations flow through this interface, enabling:
///
/// - Deterministic unit and widget tests via [MqttServiceMock]
/// - Swappable client implementations (mqtt_client, mqtt5_client, etc.)
/// - Clean separation between connection lifecycle and UI state
///
/// The service is stateful — it holds a single broker connection
/// and exposes streams for connection events and inbound messages.
/// Callers should not instantiate multiple services for the same
/// broker; use the Riverpod provider layer to manage the singleton.
///
/// Lifecycle:
/// ```
/// create → configure → connect → subscribe → publish → disconnect → dispose
/// ```
///
/// Error handling:
/// - Methods throw [MqttServiceException] for recoverable errors
/// - Fatal errors (e.g. invalid config) throw [ArgumentError]
/// - The [onConnectionLost] stream fires when the broker drops
library;

import 'dart:async';

import '../../../core/mqtt/mqtt_config.dart';
import '../../../core/mqtt/mqtt_connection_state.dart';
import '../../../core/mqtt/mqtt_diagnostics.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// An inbound MQTT message received on a subscribed topic.
class MqttInboundMessage {
  /// The topic on which the message was received.
  final String topic;

  /// The raw payload bytes.
  final List<int> payload;

  /// When this message was received (local device time).
  final DateTime receivedAt;

  /// The MQTT QoS level of the message (0, 1, or 2).
  final int qos;

  /// Whether this message was retained by the broker.
  final bool retained;

  const MqttInboundMessage({
    required this.topic,
    required this.payload,
    required this.receivedAt,
    this.qos = 0,
    this.retained = false,
  });

  /// Payload decoded as a UTF-8 string, or null if decoding fails.
  String? get payloadString {
    try {
      return String.fromCharCodes(payload);
    } catch (_) {
      return null;
    }
  }

  /// Payload size in bytes.
  int get payloadSize => payload.length;

  @override
  String toString() =>
      'MqttInboundMessage(topic: $topic, size: $payloadSize, '
      'qos: $qos, retained: $retained)';
}

/// Result of a publish operation.
class MqttPublishResult {
  /// Whether the publish was accepted by the client.
  ///
  /// For QoS 0 this is always true (fire-and-forget).
  /// For QoS 1+ this indicates broker acknowledgement.
  final bool accepted;

  /// The message identifier assigned by the client, if applicable.
  final int? messageId;

  /// Error message if the publish failed.
  final String? error;

  const MqttPublishResult({required this.accepted, this.messageId, this.error});

  const MqttPublishResult.success({this.messageId})
    : accepted = true,
      error = null;

  const MqttPublishResult.failure(this.error)
    : accepted = false,
      messageId = null;

  @override
  String toString() =>
      'MqttPublishResult(accepted: $accepted'
      '${messageId != null ? ', id: $messageId' : ''}'
      '${error != null ? ', error: $error' : ''})';
}

/// Result of a subscribe operation.
class MqttSubscribeResult {
  /// The topic that was subscribed to.
  final String topic;

  /// Whether the subscription was accepted by the broker.
  final bool accepted;

  /// The granted QoS level (may differ from requested).
  final int? grantedQos;

  /// Error message if the subscription was rejected.
  final String? error;

  const MqttSubscribeResult({
    required this.topic,
    required this.accepted,
    this.grantedQos,
    this.error,
  });

  const MqttSubscribeResult.success({required this.topic, this.grantedQos})
    : accepted = true,
      error = null;

  const MqttSubscribeResult.failure({required this.topic, required this.error})
    : accepted = false,
      grantedQos = null;

  @override
  String toString() =>
      'MqttSubscribeResult(topic: $topic, accepted: $accepted'
      '${grantedQos != null ? ', qos: $grantedQos' : ''}'
      '${error != null ? ', error: $error' : ''})';
}

/// Represents a connection event fired by the service.
class MqttConnectionEvent {
  /// The new connection state.
  final GlobalLayerConnectionState state;

  /// Human-readable reason for the state change.
  final String? reason;

  /// Error message, if the event represents an error.
  final String? errorMessage;

  /// When this event occurred.
  final DateTime timestamp;

  MqttConnectionEvent({
    required this.state,
    this.reason,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'MqttConnectionEvent(${state.name}'
      '${reason != null ? ', reason: $reason' : ''}'
      '${errorMessage != null ? ', error: $errorMessage' : ''})';
}

/// Configuration for a diagnostic check run performed by the service.
class DiagnosticCheckRequest {
  /// The type of check to perform.
  final DiagnosticCheckType type;

  /// Maximum time to wait for this check to complete.
  final Duration timeout;

  const DiagnosticCheckRequest({
    required this.type,
    this.timeout = const Duration(seconds: 10),
  });
}

/// Result of a single ping operation.
class MqttPingResult {
  /// Whether the broker responded to the ping.
  final bool success;

  /// Round-trip time in milliseconds.
  final int? roundTripMs;

  /// Error message if the ping failed.
  final String? error;

  const MqttPingResult({required this.success, this.roundTripMs, this.error});

  const MqttPingResult.success(this.roundTripMs) : success = true, error = null;

  const MqttPingResult.failure(this.error)
    : success = false,
      roundTripMs = null;

  @override
  String toString() =>
      'MqttPingResult(success: $success'
      '${roundTripMs != null ? ', rtt: ${roundTripMs}ms' : ''}'
      '${error != null ? ', error: $error' : ''})';
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Exception thrown by [MqttService] for recoverable MQTT errors.
///
/// Callers should catch this and surface it to the user or retry,
/// depending on the [type].
class MqttServiceException implements Exception {
  /// A classification of the error for programmatic handling.
  final MqttServiceErrorType type;

  /// Human-readable error message.
  final String message;

  /// The underlying exception, if any.
  final Object? cause;

  const MqttServiceException({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'MqttServiceException($type): $message';
}

/// Classification of MQTT service errors.
enum MqttServiceErrorType {
  /// DNS resolution failed — host not found.
  dnsResolution,

  /// TCP connection failed — host unreachable or port refused.
  tcpConnection,

  /// TLS handshake failed — certificate issue or protocol mismatch.
  tlsHandshake,

  /// Authentication rejected by the broker.
  authenticationFailed,

  /// Subscription rejected by the broker.
  subscriptionRejected,

  /// Publish failed — broker NACK or timeout.
  publishFailed,

  /// Connection lost unexpectedly.
  connectionLost,

  /// Operation timed out.
  timeout,

  /// The client is not in a valid state for the requested operation.
  invalidState,

  /// An unknown or unclassified error occurred.
  unknown,
}

// ---------------------------------------------------------------------------
// Service interface
// ---------------------------------------------------------------------------

/// Abstract interface for all MQTT client operations.
///
/// Implementations:
/// - `MqttClientService` — real MQTT client using the `mqtt_client` package
/// - `MqttMockService` — deterministic mock for tests and V1 UI development
///
/// All methods are asynchronous. Connection state changes are broadcast
/// via [connectionEvents]. Inbound messages are broadcast via [messages].
///
/// Usage:
/// ```dart
/// final service = MqttMockService(); // or MqttClientService()
/// await service.connect(config);
/// await service.subscribe('msh/chat/+');
///
/// service.messages.listen((msg) {
///   print('Received on ${msg.topic}: ${msg.payloadString}');
/// });
///
/// await service.publish('msh/chat/LongFast', payload);
/// await service.disconnect();
/// service.dispose();
/// ```
abstract class MqttService {
  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// Connects to the broker specified in [config].
  ///
  /// The password should be provided in the config object (loaded from
  /// secure storage by the caller). The service does not access secure
  /// storage directly.
  ///
  /// Throws [MqttServiceException] if the connection fails.
  /// Fires a [MqttConnectionEvent] via [connectionEvents] on state changes.
  Future<void> connect(GlobalLayerConfig config);

  /// Disconnects from the broker gracefully.
  ///
  /// If already disconnected, this is a no-op.
  /// Fires a [MqttConnectionEvent] with [GlobalLayerConnectionState.disconnected].
  Future<void> disconnect();

  /// Releases all resources held by the service.
  ///
  /// After calling dispose, the service instance must not be reused.
  /// Closes all stream controllers and cancels pending operations.
  void dispose();

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  /// The current connection state of the service.
  GlobalLayerConnectionState get connectionState;

  /// Whether the service is currently connected to the broker.
  bool get isConnected;

  /// Stream of connection state change events.
  ///
  /// Fires whenever the connection state changes, including:
  /// - Successful connection
  /// - Disconnection (graceful or unexpected)
  /// - Degradation detection
  /// - Reconnection attempts
  /// - Errors
  Stream<MqttConnectionEvent> get connectionEvents;

  // ---------------------------------------------------------------------------
  // Subscriptions
  // ---------------------------------------------------------------------------

  /// Subscribes to an MQTT topic.
  ///
  /// [topic] may contain MQTT wildcards (`+`, `#`).
  /// [qos] specifies the requested Quality of Service level (0, 1, or 2).
  ///
  /// Returns a [MqttSubscribeResult] indicating whether the broker
  /// accepted the subscription and the granted QoS level.
  ///
  /// Throws [MqttServiceException] if not connected.
  Future<MqttSubscribeResult> subscribe(String topic, {int qos = 0});

  /// Unsubscribes from an MQTT topic.
  ///
  /// If the topic was not previously subscribed, this is a no-op.
  ///
  /// Throws [MqttServiceException] if not connected.
  Future<void> unsubscribe(String topic);

  /// Returns the set of currently active topic subscriptions.
  Set<String> get activeSubscriptions;

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  /// Publishes a message to the specified topic.
  ///
  /// [topic] must not contain wildcards.
  /// [payload] is the raw byte content of the message.
  /// [qos] specifies the Quality of Service level (0, 1, or 2).
  /// [retain] specifies whether the broker should retain this message.
  ///
  /// Returns a [MqttPublishResult] indicating acceptance.
  ///
  /// Throws [MqttServiceException] if not connected.
  Future<MqttPublishResult> publish(
    String topic,
    List<int> payload, {
    int qos = 0,
    bool retain = false,
  });

  /// Stream of inbound messages on all subscribed topics.
  ///
  /// Messages are delivered in the order they are received from
  /// the broker. Each message includes the topic, payload, QoS,
  /// and retain flag.
  Stream<MqttInboundMessage> get messages;

  // ---------------------------------------------------------------------------
  // Health & diagnostics
  // ---------------------------------------------------------------------------

  /// Sends a ping to the broker and waits for a response.
  ///
  /// Returns a [MqttPingResult] with the round-trip time on success,
  /// or an error message on failure.
  ///
  /// Throws [MqttServiceException] if not connected.
  Future<MqttPingResult> ping();

  /// Runs a single diagnostic check against the broker.
  ///
  /// Each [DiagnosticCheckType] maps to a specific network operation:
  /// - [DiagnosticCheckType.configValidation] — validates config locally
  /// - [DiagnosticCheckType.dnsResolution] — resolves broker hostname
  /// - [DiagnosticCheckType.tcpConnection] — opens TCP socket to broker
  /// - [DiagnosticCheckType.tlsHandshake] — performs TLS negotiation
  /// - [DiagnosticCheckType.authentication] — sends MQTT CONNECT
  /// - [DiagnosticCheckType.subscribe] — subscribes to a test topic
  /// - [DiagnosticCheckType.publish] — publishes to a test topic
  ///
  /// Returns a [DiagnosticCheckResult] with status, message, and timing.
  ///
  /// This method does NOT require an active connection — it creates
  /// temporary connections/sockets as needed for each check.
  Future<DiagnosticCheckResult> runDiagnosticCheck(
    DiagnosticCheckRequest request,
    GlobalLayerConfig config,
  );

  /// Runs the full diagnostic sequence and returns a complete report.
  ///
  /// Checks are run in prerequisite order. If a prerequisite check
  /// fails, subsequent checks that depend on it are skipped.
  ///
  /// [onProgress] is called after each check completes, allowing the
  /// UI to update incrementally.
  Future<DiagnosticReport> runFullDiagnostics(
    GlobalLayerConfig config, {
    void Function(DiagnosticCheckResult result)? onProgress,
  });

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  /// Enables automatic reconnection with exponential backoff.
  ///
  /// When enabled, the service will attempt to reconnect after
  /// unexpected disconnections using the following strategy:
  /// - Initial delay: 2 seconds
  /// - Maximum delay: 60 seconds (capped exponential backoff)
  /// - Maximum attempts: 10 before giving up
  ///
  /// Reconnection events are broadcast via [connectionEvents].
  ///
  /// Pass `false` to disable auto-reconnection.
  void setAutoReconnect(bool enabled);

  /// Whether automatic reconnection is currently enabled.
  bool get autoReconnectEnabled;

  /// The number of reconnection attempts made in the current session.
  int get reconnectAttempts;
}
