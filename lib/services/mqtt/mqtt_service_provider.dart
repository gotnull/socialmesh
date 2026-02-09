// SPDX-License-Identifier: GPL-3.0-or-later

/// Riverpod providers for the [MqttService] layer.
///
/// This module provides:
/// - [mqttServiceProvider] — singleton [MqttService] instance (mock or real)
/// - [mqttConnectionForwarderProvider] — bridges service connection events
///   to the Global Layer provider layer
/// - [mqttMessageForwarderProvider] — bridges inbound messages to metrics
///   and remote sightings providers
///
/// The service defaults to [MqttMockService] until a real MQTT client
/// library is added to the project. Swap the implementation by
/// overriding [mqttServiceProvider] in the provider container.
///
/// Usage:
/// ```dart
/// // Read the service
/// final service = ref.read(mqttServiceProvider);
/// await service.connect(config);
///
/// // Override for tests
/// final container = ProviderContainer(
///   overrides: [
///     mqttServiceProvider.overrideWithValue(
///       MqttMockService(behavior: MockBehavior.instant),
///     ),
///   ],
/// );
/// ```
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/mqtt/mqtt_connection_state.dart';
import '../../core/mqtt/mqtt_metrics.dart';
import '../../core/mqtt/mqtt_remote_sighting.dart';
import '../../providers/mqtt_nodedex_providers.dart';
import '../../providers/mqtt_providers.dart';
import 'mqtt_mock_service.dart';
import 'mqtt_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the singleton [MqttService] instance.
///
/// Defaults to [MqttMockService] with realistic delays. Override this
/// provider to inject a real MQTT client implementation or a custom
/// mock for testing.
///
/// The service is created once and shared across the app. It is
/// disposed when the provider container is disposed (app shutdown).
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttMockService();

  ref.onDispose(() {
    service.dispose();
    AppLogging.settings('MqttServiceProvider: service disposed');
  });

  return service;
});

// ---------------------------------------------------------------------------
// Connection event forwarder
// ---------------------------------------------------------------------------

/// Bridges [MqttService.connectionEvents] to the Global Layer
/// connection state and metrics providers.
///
/// This provider listens to the service's connection event stream
/// and forwards state transitions to [GlobalLayerConnectionStateNotifier]
/// and session tracking to [GlobalLayerMetricsNotifier].
///
/// It is a "fire-and-forget" provider — reading it once starts the
/// forwarding. It is typically read during app initialization or
/// when the Global Layer feature is first accessed.
///
/// The subscription is automatically cancelled when the provider
/// is disposed (e.g. app shutdown or provider container rebuild).
final mqttConnectionForwarderProvider = Provider<void>((ref) {
  final service = ref.watch(mqttServiceProvider);
  final connectionNotifier = ref.read(
    globalLayerConnectionStateProvider.notifier,
  );
  final metricsNotifier = ref.read(globalLayerMetricsProvider.notifier);
  final configNotifier = ref.read(globalLayerConfigProvider.notifier);

  StreamSubscription<MqttConnectionEvent>? subscription;

  subscription = service.connectionEvents.listen((event) {
    AppLogging.settings(
      'MqttConnectionForwarder: ${event.state.name}'
      '${event.reason != null ? ' (${event.reason})' : ''}',
    );

    // Forward state transition
    final transitioned = connectionNotifier.transitionTo(
      event.state,
      reason: event.reason,
      errorMessage: event.errorMessage,
    );

    if (!transitioned) {
      final currentState = ref.read(globalLayerConnectionStateProvider);
      AppLogging.settings(
        'MqttConnectionForwarder: state transition rejected '
        '(current: ${currentState.name}, '
        'target: ${event.state.name})',
      );
    }

    // Track session start/end in metrics
    switch (event.state) {
      case GlobalLayerConnectionState.connected:
        metricsNotifier.startSession();
        configNotifier.recordConnection();

      case GlobalLayerConnectionState.disconnected:
        metricsNotifier.endSession();

      case GlobalLayerConnectionState.reconnecting:
        metricsNotifier.incrementReconnectCount();

      case GlobalLayerConnectionState.error:
        if (event.errorMessage != null) {
          metricsNotifier.recordError(
            ConnectionErrorRecord(
              timestamp: event.timestamp,
              message: event.errorMessage!,
              type: ConnectionErrorType.brokerDisconnect,
            ),
          );
        }

      case GlobalLayerConnectionState.disabled:
      case GlobalLayerConnectionState.connecting:
      case GlobalLayerConnectionState.degraded:
      case GlobalLayerConnectionState.disconnecting:
        break; // No additional metrics action needed
    }
  });

  ref.onDispose(() {
    subscription?.cancel();
    AppLogging.settings('MqttConnectionForwarder: subscription cancelled');
  });
});

// ---------------------------------------------------------------------------
// Message forwarder
// ---------------------------------------------------------------------------

/// Bridges [MqttService.messages] to the metrics and remote sightings
/// providers.
///
/// For each inbound message:
/// 1. Records a [ThroughputSample] in [GlobalLayerMetricsNotifier]
/// 2. Attempts to parse and record a [RemoteSighting] if the message
///    contains node identity data and privacy settings allow it
///
/// Like [mqttConnectionForwarderProvider], this is a fire-and-forget
/// provider that starts forwarding when first read.
final mqttMessageForwarderProvider = Provider<void>((ref) {
  final service = ref.watch(mqttServiceProvider);
  final metricsNotifier = ref.read(globalLayerMetricsProvider.notifier);
  final sightingsNotifier = ref.read(remoteSightingsProvider.notifier);
  final configAsync = ref.read(globalLayerConfigProvider);

  StreamSubscription<MqttInboundMessage>? subscription;

  subscription = service.messages.listen((message) {
    // Record throughput sample
    metricsNotifier.recordSample(
      ThroughputSample(
        timestamp: message.receivedAt,
        direction: MessageDirection.inbound,
        payloadBytes: message.payloadSize,
        topic: message.topic,
      ),
    );

    // Attempt to record a remote sighting
    // The sightings notifier handles privacy gating internally
    final config = configAsync.value;
    if (config != null) {
      sightingsNotifier.recordSighting(
        RemoteSighting.now(
          nodeNum: _extractNodeNum(message),
          topic: message.topic,
          brokerUri: config.displayUri,
          channelContext: _extractChannelContext(message.topic),
        ),
      );
    }
  });

  ref.onDispose(() {
    subscription?.cancel();
    AppLogging.settings('MqttMessageForwarder: subscription cancelled');
  });
});

/// Extracts a node number from an inbound MQTT message.
///
/// In a real implementation, this would parse the Meshtastic protobuf
/// payload. For now, returns a hash of the topic as a placeholder
/// node number. The real parser will be added with the mqtt_client
/// integration.
int _extractNodeNum(MqttInboundMessage message) {
  // Placeholder: use a deterministic hash of topic + payload length
  // Real implementation will parse the ServiceEnvelope protobuf
  return message.topic.hashCode.abs() % 0xFFFFFFFF;
}

/// Extracts a channel context from an MQTT topic string.
///
/// For standard Meshtastic topics like `msh/chat/LongFast`, this
/// returns the last segment ("LongFast"). For topics with node IDs
/// like `msh/telemetry/!a1b2c3d4`, returns the node ID segment.
///
/// Returns null if the topic has fewer than 3 segments.
String? _extractChannelContext(String topic) {
  final segments = topic.split('/');
  if (segments.length < 3) return null;
  return segments.last;
}

// ---------------------------------------------------------------------------
// Service lifecycle helpers
// ---------------------------------------------------------------------------

/// Connects the MQTT service using the current Global Layer config.
///
/// This is a convenience function that reads the config from the
/// provider, loads the password from secure storage, and calls
/// [MqttService.connect].
///
/// Returns `true` if the connection was initiated successfully,
/// `false` if the config is not ready or the service is already
/// connected.
///
/// Usage:
/// ```dart
/// final success = await connectMqttService(ref);
/// ```
Future<bool> connectMqttService(Ref ref) async {
  final service = ref.read(mqttServiceProvider);
  if (service.isConnected) {
    AppLogging.settings('connectMqttService: already connected');
    return false;
  }

  final configAsync = ref.read(globalLayerConfigProvider);
  final config = configAsync.value;
  if (config == null || !config.hasBrokerConfig) {
    AppLogging.settings('connectMqttService: no valid config available');
    return false;
  }

  try {
    await service.connect(config);
    AppLogging.settings('connectMqttService: connection initiated');

    // Subscribe to all enabled topics
    for (final sub in config.enabledSubscriptions) {
      try {
        await service.subscribe(sub.topic);
        AppLogging.settings('connectMqttService: subscribed to ${sub.topic}');
      } on MqttServiceException catch (e) {
        AppLogging.settings(
          'connectMqttService: failed to subscribe to ${sub.topic}: '
          '${e.message}',
        );
      }
    }

    return true;
  } on MqttServiceException catch (e) {
    AppLogging.settings('connectMqttService: connection failed: ${e.message}');
    return false;
  }
}

/// Disconnects the MQTT service gracefully.
///
/// Returns `true` if the disconnection was initiated, `false` if
/// the service was already disconnected.
Future<bool> disconnectMqttService(Ref ref) async {
  final service = ref.read(mqttServiceProvider);
  if (!service.isConnected) {
    AppLogging.settings('disconnectMqttService: already disconnected');
    return false;
  }

  try {
    await service.disconnect();
    AppLogging.settings('disconnectMqttService: disconnected');
    return true;
  } on MqttServiceException catch (e) {
    AppLogging.settings(
      'disconnectMqttService: error during disconnect: ${e.message}',
    );
    return false;
  }
}
