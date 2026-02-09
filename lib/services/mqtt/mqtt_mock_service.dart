// SPDX-License-Identifier: GPL-3.0-or-later

/// MqttMockService — deterministic mock implementation of [MqttService].
///
/// This service simulates all MQTT operations with configurable delays
/// and outcomes, enabling:
///
/// - Deterministic UI development without a real broker
/// - Unit and widget tests with controlled timing
/// - V1 Global Layer feature development before adding mqtt_client
///
/// All operations respect the configured [MockBehavior] which controls
/// whether operations succeed, fail, or timeout. Default behavior is
/// "happy path" where everything succeeds with realistic delays.
///
/// Usage:
/// ```dart
/// final service = MqttMockService();
/// await service.connect(config);         // simulates connection
/// await service.subscribe('msh/chat/+'); // simulates subscription
///
/// // Inject a fake inbound message
/// service.injectMessage(MqttInboundMessage(...));
///
/// await service.disconnect();
/// service.dispose();
/// ```
///
/// For failure testing:
/// ```dart
/// final service = MqttMockService(
///   behavior: MockBehavior(
///     connectResult: MockResult.failure,
///     connectErrorMessage: 'Connection refused',
///   ),
/// );
/// ```
library;

import 'dart:async';

import '../../core/logging.dart';
import '../../core/mqtt/mqtt_config.dart';
import '../../core/mqtt/mqtt_connection_state.dart';
import '../../core/mqtt/mqtt_constants.dart';
import '../../core/mqtt/mqtt_diagnostics.dart';
import 'mqtt_service.dart';

// ---------------------------------------------------------------------------
// Mock behavior configuration
// ---------------------------------------------------------------------------

/// Outcome for a mock operation.
enum MockResult {
  /// The operation succeeds after the configured delay.
  success,

  /// The operation fails with the configured error message.
  failure,

  /// The operation times out (delay exceeds the caller's timeout).
  timeout,
}

/// Configuration for mock service behavior.
///
/// Each field controls the outcome and timing of a specific operation.
/// Defaults produce a "happy path" where all operations succeed with
/// realistic delays.
class MockBehavior {
  // -- Connection --
  final MockResult connectResult;
  final Duration connectDelay;
  final String? connectErrorMessage;

  // -- Disconnection --
  final MockResult disconnectResult;
  final Duration disconnectDelay;

  // -- Subscribe --
  final MockResult subscribeResult;
  final Duration subscribeDelay;
  final int grantedQos;
  final String? subscribeErrorMessage;

  // -- Unsubscribe --
  final Duration unsubscribeDelay;

  // -- Publish --
  final MockResult publishResult;
  final Duration publishDelay;
  final String? publishErrorMessage;

  // -- Ping --
  final MockResult pingResult;
  final Duration pingDelay;
  final int pingRoundTripMs;
  final String? pingErrorMessage;

  // -- Diagnostics --
  final Duration diagnosticStepDelay;
  final Map<DiagnosticCheckType, MockResult> diagnosticOverrides;

  // -- Auto-disconnect simulation --
  /// When non-null, the connection will be "lost" after this duration
  /// to simulate an unexpected broker disconnect.
  final Duration? simulateDisconnectAfter;

  const MockBehavior({
    this.connectResult = MockResult.success,
    this.connectDelay = const Duration(milliseconds: 800),
    this.connectErrorMessage,
    this.disconnectResult = MockResult.success,
    this.disconnectDelay = const Duration(milliseconds: 300),
    this.subscribeResult = MockResult.success,
    this.subscribeDelay = const Duration(milliseconds: 200),
    this.grantedQos = 0,
    this.subscribeErrorMessage,
    this.unsubscribeDelay = const Duration(milliseconds: 100),
    this.publishResult = MockResult.success,
    this.publishDelay = const Duration(milliseconds: 150),
    this.publishErrorMessage,
    this.pingResult = MockResult.success,
    this.pingDelay = const Duration(milliseconds: 50),
    this.pingRoundTripMs = 42,
    this.pingErrorMessage,
    this.diagnosticStepDelay = const Duration(milliseconds: 400),
    this.diagnosticOverrides = const {},
    this.simulateDisconnectAfter,
  });

  /// All operations succeed instantly (for fast unit tests).
  static const instant = MockBehavior(
    connectDelay: Duration.zero,
    disconnectDelay: Duration.zero,
    subscribeDelay: Duration.zero,
    unsubscribeDelay: Duration.zero,
    publishDelay: Duration.zero,
    pingDelay: Duration.zero,
    diagnosticStepDelay: Duration.zero,
  );

  /// All operations fail (for error path testing).
  static const allFailing = MockBehavior(
    connectResult: MockResult.failure,
    connectErrorMessage: 'Mock: connection refused',
    subscribeResult: MockResult.failure,
    subscribeErrorMessage: 'Mock: subscription rejected',
    publishResult: MockResult.failure,
    publishErrorMessage: 'Mock: publish failed',
    pingResult: MockResult.failure,
    pingErrorMessage: 'Mock: ping timeout',
  );

  /// Creates a copy with overridden fields.
  MockBehavior copyWith({
    MockResult? connectResult,
    Duration? connectDelay,
    String? connectErrorMessage,
    MockResult? disconnectResult,
    Duration? disconnectDelay,
    MockResult? subscribeResult,
    Duration? subscribeDelay,
    int? grantedQos,
    String? subscribeErrorMessage,
    Duration? unsubscribeDelay,
    MockResult? publishResult,
    Duration? publishDelay,
    String? publishErrorMessage,
    MockResult? pingResult,
    Duration? pingDelay,
    int? pingRoundTripMs,
    String? pingErrorMessage,
    Duration? diagnosticStepDelay,
    Map<DiagnosticCheckType, MockResult>? diagnosticOverrides,
    Duration? simulateDisconnectAfter,
  }) {
    return MockBehavior(
      connectResult: connectResult ?? this.connectResult,
      connectDelay: connectDelay ?? this.connectDelay,
      connectErrorMessage: connectErrorMessage ?? this.connectErrorMessage,
      disconnectResult: disconnectResult ?? this.disconnectResult,
      disconnectDelay: disconnectDelay ?? this.disconnectDelay,
      subscribeResult: subscribeResult ?? this.subscribeResult,
      subscribeDelay: subscribeDelay ?? this.subscribeDelay,
      grantedQos: grantedQos ?? this.grantedQos,
      subscribeErrorMessage:
          subscribeErrorMessage ?? this.subscribeErrorMessage,
      unsubscribeDelay: unsubscribeDelay ?? this.unsubscribeDelay,
      publishResult: publishResult ?? this.publishResult,
      publishDelay: publishDelay ?? this.publishDelay,
      publishErrorMessage: publishErrorMessage ?? this.publishErrorMessage,
      pingResult: pingResult ?? this.pingResult,
      pingDelay: pingDelay ?? this.pingDelay,
      pingRoundTripMs: pingRoundTripMs ?? this.pingRoundTripMs,
      pingErrorMessage: pingErrorMessage ?? this.pingErrorMessage,
      diagnosticStepDelay: diagnosticStepDelay ?? this.diagnosticStepDelay,
      diagnosticOverrides: diagnosticOverrides ?? this.diagnosticOverrides,
      simulateDisconnectAfter:
          simulateDisconnectAfter ?? this.simulateDisconnectAfter,
    );
  }
}

// ---------------------------------------------------------------------------
// Mock service implementation
// ---------------------------------------------------------------------------

/// Deterministic mock implementation of [MqttService].
///
/// Simulates all MQTT operations with configurable delays and outcomes.
/// Use [behavior] to control success/failure for each operation type.
///
/// The mock provides additional methods for test control:
/// - [injectMessage] — simulate an inbound message from the broker
/// - [injectConnectionEvent] — simulate a connection state change
/// - [updateBehavior] — change mock behavior at runtime
/// - [publishHistory] — inspect messages that were "published"
/// - [subscriptionHistory] — inspect subscription attempts
class MqttMockService implements MqttService {
  /// Current mock behavior configuration.
  MockBehavior _behavior;

  /// Stream controller for connection events.
  final StreamController<MqttConnectionEvent> _connectionEventsController =
      StreamController<MqttConnectionEvent>.broadcast();

  /// Stream controller for inbound messages.
  final StreamController<MqttInboundMessage> _messagesController =
      StreamController<MqttInboundMessage>.broadcast();

  /// Current connection state.
  GlobalLayerConnectionState _connectionState =
      GlobalLayerConnectionState.disabled;

  /// Active topic subscriptions.
  final Set<String> _subscriptions = {};

  /// Whether auto-reconnect is enabled.
  bool _autoReconnect = false;

  /// Number of reconnection attempts in the current session.
  int _reconnectAttempts = 0;

  /// Whether [dispose] has been called.
  bool _disposed = false;

  /// Timer for simulated disconnection.
  Timer? _disconnectTimer;

  // -- Test inspection --

  /// History of all published messages for test assertions.
  final List<MockPublishRecord> _publishHistory = [];

  /// History of all subscription attempts for test assertions.
  final List<MockSubscriptionRecord> _subscriptionHistory = [];

  /// Number of connect calls made.
  int _connectCount = 0;

  /// Number of disconnect calls made.
  int _disconnectCount = 0;

  /// Creates a mock service with the given behavior.
  ///
  /// Defaults to [MockBehavior] which simulates a happy path.
  MqttMockService({MockBehavior behavior = const MockBehavior()})
    : _behavior = behavior;

  // ---------------------------------------------------------------------------
  // Test control methods
  // ---------------------------------------------------------------------------

  /// Returns the current behavior configuration.
  MockBehavior get behavior => _behavior;

  /// Updates the mock behavior at runtime.
  ///
  /// This allows tests to change behavior between operations, e.g.
  /// connect successfully then make the next publish fail.
  void updateBehavior(MockBehavior behavior) {
    _behavior = behavior;
  }

  /// Injects a fake inbound message as if it came from the broker.
  ///
  /// The message is delivered to the [messages] stream. If no
  /// subscribers are listening, the message is dropped (broadcast
  /// stream semantics).
  ///
  /// The topic does not need to match any active subscription —
  /// this is intentional to allow testing edge cases.
  void injectMessage(MqttInboundMessage message) {
    _assertNotDisposed();
    if (!_messagesController.isClosed) {
      _messagesController.add(message);
    }
  }

  /// Injects a fake connection event.
  ///
  /// This updates the internal [_connectionState] and fires the event
  /// on the [connectionEvents] stream.
  void injectConnectionEvent(MqttConnectionEvent event) {
    _assertNotDisposed();
    _connectionState = event.state;
    if (!_connectionEventsController.isClosed) {
      _connectionEventsController.add(event);
    }
  }

  /// Returns a copy of all published messages for test assertions.
  List<MockPublishRecord> get publishHistory =>
      List.unmodifiable(_publishHistory);

  /// Returns a copy of all subscription attempts for test assertions.
  List<MockSubscriptionRecord> get subscriptionHistory =>
      List.unmodifiable(_subscriptionHistory);

  /// Number of [connect] calls made during this service's lifetime.
  int get connectCount => _connectCount;

  /// Number of [disconnect] calls made during this service's lifetime.
  int get disconnectCount => _disconnectCount;

  /// Clears all test inspection state (publish history, etc.).
  void clearHistory() {
    _publishHistory.clear();
    _subscriptionHistory.clear();
    _connectCount = 0;
    _disconnectCount = 0;
  }

  // ---------------------------------------------------------------------------
  // MqttService implementation — Connection lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(GlobalLayerConfig config) async {
    _assertNotDisposed();
    _connectCount++;

    AppLogging.settings(
      'MqttMockService: connect called (host: ${config.host})',
    );

    // Fire connecting event
    _connectionState = GlobalLayerConnectionState.connecting;
    _connectionEventsController.add(
      MqttConnectionEvent(
        state: GlobalLayerConnectionState.connecting,
        reason: 'Mock: connecting to ${config.host}',
      ),
    );

    // Simulate delay
    if (_behavior.connectDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.connectDelay);
    }

    switch (_behavior.connectResult) {
      case MockResult.success:
        _connectionState = GlobalLayerConnectionState.connected;
        _reconnectAttempts = 0;
        _connectionEventsController.add(
          MqttConnectionEvent(
            state: GlobalLayerConnectionState.connected,
            reason: 'Mock: connected successfully',
          ),
        );

        // Schedule simulated disconnect if configured
        _startDisconnectTimer();

        AppLogging.settings('MqttMockService: connected');

      case MockResult.failure:
        _connectionState = GlobalLayerConnectionState.error;
        final errorMsg =
            _behavior.connectErrorMessage ?? 'Mock: connection failed';
        _connectionEventsController.add(
          MqttConnectionEvent(
            state: GlobalLayerConnectionState.error,
            reason: 'Mock: connection failed',
            errorMessage: errorMsg,
          ),
        );
        throw MqttServiceException(
          type: MqttServiceErrorType.tcpConnection,
          message: errorMsg,
        );

      case MockResult.timeout:
        _connectionState = GlobalLayerConnectionState.error;
        const errorMsg = 'Mock: connection timed out';
        _connectionEventsController.add(
          MqttConnectionEvent(
            state: GlobalLayerConnectionState.error,
            reason: errorMsg,
            errorMessage: errorMsg,
          ),
        );
        throw const MqttServiceException(
          type: MqttServiceErrorType.timeout,
          message: errorMsg,
        );
    }
  }

  @override
  Future<void> disconnect() async {
    _assertNotDisposed();
    _disconnectCount++;
    _disconnectTimer?.cancel();

    AppLogging.settings('MqttMockService: disconnect called');

    if (_connectionState == GlobalLayerConnectionState.disconnected ||
        _connectionState == GlobalLayerConnectionState.disabled) {
      return; // Already disconnected
    }

    _connectionState = GlobalLayerConnectionState.disconnecting;
    _connectionEventsController.add(
      MqttConnectionEvent(
        state: GlobalLayerConnectionState.disconnecting,
        reason: 'Mock: disconnecting',
      ),
    );

    if (_behavior.disconnectDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.disconnectDelay);
    }

    _subscriptions.clear();
    _connectionState = GlobalLayerConnectionState.disconnected;
    _connectionEventsController.add(
      MqttConnectionEvent(
        state: GlobalLayerConnectionState.disconnected,
        reason: 'Mock: disconnected',
      ),
    );

    AppLogging.settings('MqttMockService: disconnected');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disconnectTimer?.cancel();
    _subscriptions.clear();
    _connectionEventsController.close();
    _messagesController.close();
    AppLogging.settings('MqttMockService: disposed');
  }

  // ---------------------------------------------------------------------------
  // MqttService implementation — Connection state
  // ---------------------------------------------------------------------------

  @override
  GlobalLayerConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected =>
      _connectionState == GlobalLayerConnectionState.connected ||
      _connectionState == GlobalLayerConnectionState.degraded;

  @override
  Stream<MqttConnectionEvent> get connectionEvents =>
      _connectionEventsController.stream;

  // ---------------------------------------------------------------------------
  // MqttService implementation — Subscriptions
  // ---------------------------------------------------------------------------

  @override
  Future<MqttSubscribeResult> subscribe(String topic, {int qos = 0}) async {
    _assertNotDisposed();
    _assertConnected('subscribe');

    AppLogging.settings('MqttMockService: subscribe($topic, qos=$qos)');

    _subscriptionHistory.add(
      MockSubscriptionRecord(
        topic: topic,
        qos: qos,
        timestamp: DateTime.now(),
        isSubscribe: true,
      ),
    );

    if (_behavior.subscribeDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.subscribeDelay);
    }

    switch (_behavior.subscribeResult) {
      case MockResult.success:
        _subscriptions.add(topic);
        return MqttSubscribeResult.success(
          topic: topic,
          grantedQos: _behavior.grantedQos,
        );

      case MockResult.failure:
        final errorMsg =
            _behavior.subscribeErrorMessage ?? 'Mock: subscription rejected';
        return MqttSubscribeResult.failure(topic: topic, error: errorMsg);

      case MockResult.timeout:
        throw const MqttServiceException(
          type: MqttServiceErrorType.timeout,
          message: 'Mock: subscribe timed out',
        );
    }
  }

  @override
  Future<void> unsubscribe(String topic) async {
    _assertNotDisposed();
    _assertConnected('unsubscribe');

    _subscriptionHistory.add(
      MockSubscriptionRecord(
        topic: topic,
        qos: 0,
        timestamp: DateTime.now(),
        isSubscribe: false,
      ),
    );

    if (_behavior.unsubscribeDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.unsubscribeDelay);
    }

    _subscriptions.remove(topic);
    AppLogging.settings('MqttMockService: unsubscribed from $topic');
  }

  @override
  Set<String> get activeSubscriptions => Set.unmodifiable(_subscriptions);

  // ---------------------------------------------------------------------------
  // MqttService implementation — Messaging
  // ---------------------------------------------------------------------------

  @override
  Future<MqttPublishResult> publish(
    String topic,
    List<int> payload, {
    int qos = 0,
    bool retain = false,
  }) async {
    _assertNotDisposed();
    _assertConnected('publish');

    _publishHistory.add(
      MockPublishRecord(
        topic: topic,
        payload: payload,
        qos: qos,
        retain: retain,
        timestamp: DateTime.now(),
      ),
    );

    AppLogging.settings(
      'MqttMockService: publish($topic, ${payload.length} bytes, '
      'qos=$qos, retain=$retain)',
    );

    if (_behavior.publishDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.publishDelay);
    }

    switch (_behavior.publishResult) {
      case MockResult.success:
        return MqttPublishResult.success(messageId: _publishHistory.length);

      case MockResult.failure:
        final errorMsg =
            _behavior.publishErrorMessage ?? 'Mock: publish rejected';
        return MqttPublishResult.failure(errorMsg);

      case MockResult.timeout:
        throw const MqttServiceException(
          type: MqttServiceErrorType.timeout,
          message: 'Mock: publish timed out',
        );
    }
  }

  @override
  Stream<MqttInboundMessage> get messages => _messagesController.stream;

  // ---------------------------------------------------------------------------
  // MqttService implementation — Health & diagnostics
  // ---------------------------------------------------------------------------

  @override
  Future<MqttPingResult> ping() async {
    _assertNotDisposed();
    _assertConnected('ping');

    if (_behavior.pingDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.pingDelay);
    }

    switch (_behavior.pingResult) {
      case MockResult.success:
        return MqttPingResult.success(_behavior.pingRoundTripMs);

      case MockResult.failure:
        return MqttPingResult.failure(
          _behavior.pingErrorMessage ?? 'Mock: ping failed',
        );

      case MockResult.timeout:
        return const MqttPingResult.failure('Mock: ping timed out');
    }
  }

  @override
  Future<DiagnosticCheckResult> runDiagnosticCheck(
    DiagnosticCheckRequest request,
    GlobalLayerConfig config,
  ) async {
    _assertNotDisposed();

    final stopwatch = Stopwatch()..start();

    if (_behavior.diagnosticStepDelay > Duration.zero) {
      await Future<void>.delayed(_behavior.diagnosticStepDelay);
    }

    stopwatch.stop();

    // Check for per-type overrides
    final overrideResult = _behavior.diagnosticOverrides[request.type];

    // Config validation is handled locally (no mock override needed)
    if (request.type == DiagnosticCheckType.configValidation) {
      final result = ConfigDiagnostics.validateConfig(config);
      return result.copyWith(duration: stopwatch.elapsed);
    }

    // TLS check — skip if TLS is not enabled
    if (request.type == DiagnosticCheckType.tlsHandshake && !config.useTls) {
      return DiagnosticCheckResult(
        type: request.type,
        status: DiagnosticStatus.skipped,
        message: 'TLS is not enabled — skipped.',
        duration: stopwatch.elapsed,
        completedAt: DateTime.now(),
      );
    }

    // Apply override or default success
    final result = overrideResult ?? MockResult.success;

    switch (result) {
      case MockResult.success:
        return DiagnosticCheckResult(
          type: request.type,
          status: DiagnosticStatus.passed,
          message: 'Mock: ${request.type.title} passed.',
          duration: stopwatch.elapsed,
          completedAt: DateTime.now(),
        );

      case MockResult.failure:
        return DiagnosticCheckResult(
          type: request.type,
          status: DiagnosticStatus.failed,
          message: 'Mock: ${request.type.title} failed.',
          suggestion: 'This is a simulated failure for testing.',
          duration: stopwatch.elapsed,
          completedAt: DateTime.now(),
        );

      case MockResult.timeout:
        return DiagnosticCheckResult(
          type: request.type,
          status: DiagnosticStatus.failed,
          message: 'Mock: ${request.type.title} timed out.',
          suggestion: 'Check network connectivity and broker availability.',
          duration: stopwatch.elapsed,
          completedAt: DateTime.now(),
        );
    }
  }

  @override
  Future<DiagnosticReport> runFullDiagnostics(
    GlobalLayerConfig config, {
    void Function(DiagnosticCheckResult result)? onProgress,
  }) async {
    _assertNotDisposed();

    final report = DiagnosticReport.initial(
      tlsEnabled: config.useTls,
      connectionState: _connectionState,
      configSnapshot: config.toRedactedJson(),
    );

    var currentReport = report;

    for (final checkResult in report.results) {
      // Skip checks whose prerequisites failed
      final prerequisite = checkResult.type.effectivePrerequisite(
        tlsEnabled: config.useTls,
      );
      if (prerequisite != null) {
        final prereqResult = currentReport.resultFor(prerequisite);
        if (prereqResult != null && prereqResult.status.isProblem) {
          final skippedResult = checkResult.copyWith(
            status: DiagnosticStatus.skipped,
            message:
                'Skipped — prerequisite '
                '${prerequisite.title} failed.',
            completedAt: DateTime.now(),
          );
          currentReport = currentReport.updateResult(skippedResult);
          onProgress?.call(skippedResult);
          continue;
        }
      }

      final request = DiagnosticCheckRequest(
        type: checkResult.type,
        timeout: GlobalLayerConstants.diagnosticStepTimeout,
      );

      final result = await runDiagnosticCheck(request, config);
      currentReport = currentReport.updateResult(result);
      onProgress?.call(result);
    }

    return currentReport.markComplete();
  }

  // ---------------------------------------------------------------------------
  // MqttService implementation — Reconnection
  // ---------------------------------------------------------------------------

  @override
  void setAutoReconnect(bool enabled) {
    _autoReconnect = enabled;
    AppLogging.settings(
      'MqttMockService: auto-reconnect ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  @override
  bool get autoReconnectEnabled => _autoReconnect;

  @override
  int get reconnectAttempts => _reconnectAttempts;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _assertNotDisposed() {
    if (_disposed) {
      throw const MqttServiceException(
        type: MqttServiceErrorType.invalidState,
        message: 'MqttMockService has been disposed.',
      );
    }
  }

  void _assertConnected(String operation) {
    if (!isConnected) {
      throw MqttServiceException(
        type: MqttServiceErrorType.invalidState,
        message:
            'Cannot $operation: not connected '
            '(state: ${_connectionState.name}).',
      );
    }
  }

  void _startDisconnectTimer() {
    final delay = _behavior.simulateDisconnectAfter;
    if (delay == null) return;

    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(delay, () {
      if (_disposed) return;
      if (!isConnected) return;

      AppLogging.settings('MqttMockService: simulating unexpected disconnect');

      _connectionState = GlobalLayerConnectionState.reconnecting;
      _connectionEventsController.add(
        MqttConnectionEvent(
          state: GlobalLayerConnectionState.reconnecting,
          reason: 'Mock: simulated connection loss',
          errorMessage: 'Broker closed connection unexpectedly',
        ),
      );

      if (_autoReconnect) {
        _reconnectAttempts++;
        // Simulate a successful reconnect after a delay
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (_disposed) return;
          _connectionState = GlobalLayerConnectionState.connected;
          _connectionEventsController.add(
            MqttConnectionEvent(
              state: GlobalLayerConnectionState.connected,
              reason: 'Mock: reconnected (attempt $_reconnectAttempts)',
            ),
          );
        });
      } else {
        _connectionState = GlobalLayerConnectionState.disconnected;
        _connectionEventsController.add(
          MqttConnectionEvent(
            state: GlobalLayerConnectionState.disconnected,
            reason: 'Mock: disconnected (auto-reconnect disabled)',
          ),
        );
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Test inspection records
// ---------------------------------------------------------------------------

/// Record of a publish operation for test inspection.
class MockPublishRecord {
  final String topic;
  final List<int> payload;
  final int qos;
  final bool retain;
  final DateTime timestamp;

  const MockPublishRecord({
    required this.topic,
    required this.payload,
    required this.qos,
    required this.retain,
    required this.timestamp,
  });

  @override
  String toString() =>
      'MockPublishRecord(topic: $topic, size: ${payload.length}, '
      'qos: $qos, retain: $retain)';
}

/// Record of a subscription operation for test inspection.
class MockSubscriptionRecord {
  final String topic;
  final int qos;
  final DateTime timestamp;
  final bool isSubscribe; // true = subscribe, false = unsubscribe

  const MockSubscriptionRecord({
    required this.topic,
    required this.qos,
    required this.timestamp,
    required this.isSubscribe,
  });

  @override
  String toString() =>
      'MockSubscriptionRecord(topic: $topic, '
      '${isSubscribe ? "subscribe" : "unsubscribe"}, qos: $qos)';
}
