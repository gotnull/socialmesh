// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// A subscribe-only broker connection that listens for a fixed time and
// tallies the root topics it hears. Separate from the MQTT client proxy,
// which forwards everything it receives to the radio: nothing heard here
// reaches the radio, and nothing is ever published.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../../core/logging.dart';
import '../../../core/mqtt/mqtt_constants.dart';
import 'mqtt_topic_discovery.dart';

/// Where the sampler connects, worked out from the MQTT form's draft the
/// way the firmware applies it: a blank address means the public server,
/// `host:port` is split, and the public server always uses TLS on 8883
/// with its fixed credentials, whatever was typed.
class MqttBrokerSettings {
  final String host;
  final int port;
  final bool useTls;
  final String? username;
  final String? password;

  const MqttBrokerSettings({
    required this.host,
    required this.port,
    required this.useTls,
    this.username,
    this.password,
  });

  factory MqttBrokerSettings.fromForm({
    required String address,
    required bool tlsEnabled,
    required String username,
    required String password,
  }) {
    final publicServer = BrokerPreset.defaults.first;
    var host = address.trim().isEmpty ? publicServer.host : address.trim();
    int? typedPort;
    final colon = host.indexOf(':');
    if (colon >= 0) {
      typedPort = int.tryParse(host.substring(colon + 1));
      host = host.substring(0, colon);
    }
    if (host.toLowerCase() == publicServer.host.toLowerCase()) {
      return MqttBrokerSettings(
        host: host,
        port: GlobalLayerConstants.defaultTlsPort,
        useTls: true,
        username: publicServer.defaultUsername,
        password: publicServer.defaultPassword,
      );
    }
    return MqttBrokerSettings(
      host: host,
      port:
          typedPort ??
          (tlsEnabled
              ? GlobalLayerConstants.defaultTlsPort
              : GlobalLayerConstants.defaultPort),
      useTls: tlsEnabled,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );
  }
}

/// The broker connection the sampler drives. [MqttServerSampleClient] is
/// the real one; tests supply their own.
abstract class MqttSampleClient {
  set onSubscribed(void Function(String topic) callback);
  set onSubscribeFail(void Function(String topic) callback);
  set onDisconnected(void Function() callback);

  /// Topic and payload of every message received.
  Stream<(String, Uint8List)> get messages;

  /// Completes once the broker accepted the connection; throws otherwise.
  Future<void> connect(MqttBrokerSettings settings);
  void subscribe(String filter);
  void unsubscribe(String filter);
  void disconnect();
}

/// [MqttSampleClient] over an `mqtt_client` server connection.
class MqttServerSampleClient implements MqttSampleClient {
  MqttServerClient? _client;
  final StreamController<(String, Uint8List)> _messages =
      StreamController.broadcast();
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  void Function(String)? _onSubscribed;
  void Function(String)? _onSubscribeFail;
  void Function()? _onDisconnected;

  @override
  set onSubscribed(void Function(String topic) callback) =>
      _onSubscribed = callback;
  @override
  set onSubscribeFail(void Function(String topic) callback) =>
      _onSubscribeFail = callback;
  @override
  set onDisconnected(void Function() callback) => _onDisconnected = callback;

  @override
  Stream<(String, Uint8List)> get messages => _messages.stream;

  @override
  Future<void> connect(MqttBrokerSettings settings) async {
    // A random id, so the broker sees nothing that identifies the node.
    final random = Random.secure();
    final clientId =
        'smtopics-${List.generate(4, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final client = MqttServerClient.withPort(
      settings.host,
      clientId,
      settings.port,
    );
    client.setProtocolV311();
    client.keepAlivePeriod = GlobalLayerConstants.keepAliveSeconds;
    client.connectTimeoutPeriod =
        GlobalLayerConstants.connectionTimeout.inMilliseconds;
    client.autoReconnect = false;
    client.logging(on: false);
    // Do not install an onBadCertificate callback: the platform trust
    // store must reject invalid chains and hostnames.
    if (settings.useTls) {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
    }
    client.onSubscribed = (topic) => _onSubscribed?.call(topic);
    client.onSubscribeFail = (topic) => _onSubscribeFail?.call(topic);
    client.onDisconnected = () => _onDisconnected?.call();
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    _client = client;
    final status = await client.connect(settings.username, settings.password);
    if (status?.state != MqttConnectionState.connected) {
      throw StateError('connect refused: ${status?.returnCode}');
    }
    _updates = client.updates?.listen((batch) {
      for (final received in batch) {
        final message = received.payload;
        if (message is! MqttPublishMessage) continue;
        _messages.add((
          received.topic,
          Uint8List.fromList(message.payload.message),
        ));
      }
    });
  }

  @override
  void subscribe(String filter) =>
      _client?.subscribe(filter, MqttQos.atMostOnce);

  @override
  void unsubscribe(String filter) => _client?.unsubscribe(filter);

  @override
  void disconnect() {
    _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    client?.onDisconnected = null;
    client?.disconnect();
    _messages.close();
  }
}

enum MqttSamplerPhase {
  idle,
  connecting,
  subscribing,
  sampling,
  finished,
  failed,
}

enum MqttSamplerFailure { connect, filtersRefused, closed }

/// What the sheet shows: the phase, the tally so far and the countdown.
class MqttSamplerSnapshot {
  final MqttSamplerPhase phase;
  final MqttSamplerFailure? failure;
  final Map<String, MqttRootActivity> activity;
  final int secondsRemaining;
  final int messageCount;

  const MqttSamplerSnapshot({
    required this.phase,
    this.failure,
    this.activity = const {},
    this.secondsRemaining = 0,
    this.messageCount = 0,
  });
}

/// Listens to a broker for [duration] and tallies the roots it hears.
class MqttTopicSampler {
  static const Duration defaultDuration = Duration(seconds: 60);
  static const Duration defaultSubscribeDeadline = Duration(seconds: 10);

  /// A flooding broker ends the sample early rather than filling memory.
  static const int messageCap = 20000;

  /// The region's own packet stream (around 100 messages a second on the
  /// busiest regions) is unsubscribed after this many packets; the region
  /// row then reads as a floor.
  static const int regionPacketCap = 300;

  final MqttSampleClient Function() _clientFactory;
  final Duration duration;
  final Duration subscribeDeadline;

  MqttTopicSampler({
    MqttSampleClient Function()? clientFactory,
    this.duration = defaultDuration,
    this.subscribeDeadline = defaultSubscribeDeadline,
  }) : _clientFactory = clientFactory ?? MqttServerSampleClient.new;

  final StreamController<MqttSamplerSnapshot> _snapshots =
      StreamController.broadcast();
  MqttSamplerSnapshot _current = const MqttSamplerSnapshot(
    phase: MqttSamplerPhase.idle,
  );

  MqttSampleClient? _client;
  StreamSubscription<(String, Uint8List)>? _messageSub;
  Timer? _deadline;
  Timer? _ticker;
  DateTime? _endsAt;
  MqttTopicTally _tally = MqttTopicTally();
  final Set<String> _pending = {};
  final Set<String> _granted = {};
  String _regionTopic = '';
  int _regionPackets = 0;
  int _messageCount = 0;
  bool _disposed = false;

  Stream<MqttSamplerSnapshot> get snapshots => _snapshots.stream;
  MqttSamplerSnapshot get current => _current;

  /// Eight filters: the region's own map and packet topics, then map and
  /// packet topics one to three levels below it. Never `#`: the public
  /// broker drops the whole connection for it.
  static List<String> filters(String regionTopic) {
    const levels = ['', '/+', '/+/+', '/+/+/+'];
    return [
      for (final level in levels) '$regionTopic$level/2/map/',
      for (final level in levels) '$regionTopic$level/2/e/+/+',
    ];
  }

  /// Connects, subscribes and samples. Calling it again restarts.
  Future<void> start(MqttBrokerSettings settings, String regionTopic) async {
    _tearDown();
    _tally = MqttTopicTally();
    _regionTopic = regionTopic;
    _regionPackets = 0;
    _messageCount = 0;
    _pending.clear();
    _granted.clear();
    _emit(const MqttSamplerSnapshot(phase: MqttSamplerPhase.connecting));
    final client = _clientFactory();
    _client = client;
    client.onSubscribed = (topic) => _handleSubscribeResult(topic, true);
    client.onSubscribeFail = (topic) => _handleSubscribeResult(topic, false);
    client.onDisconnected = _handleDisconnected;
    AppLogging.mqttProxy(
      'TOPIC_FINDER: connect host=${settings.host} port=${settings.port} '
      'tls=${settings.useTls}',
    );
    try {
      await client.connect(settings);
    } on Object catch (e) {
      if (!identical(_client, client) || _disposed) return;
      AppLogging.mqttProxyWarning('TOPIC_FINDER: connect failed: $e');
      _fail(MqttSamplerFailure.connect);
      return;
    }
    if (!identical(_client, client) || _disposed) return;
    _messageSub = client.messages.listen(_handleMessage);
    final all = filters(regionTopic);
    _pending.addAll(all);
    _emit(const MqttSamplerSnapshot(phase: MqttSamplerPhase.subscribing));
    for (final filter in all) {
      client.subscribe(filter);
    }
    _deadline = Timer(subscribeDeadline, _settleSubscriptions);
  }

  void _handleSubscribeResult(String topic, bool granted) {
    if (_current.phase != MqttSamplerPhase.subscribing) return;
    if (!_pending.remove(topic)) return;
    if (granted) _granted.add(topic);
    if (_pending.isEmpty) _settleSubscriptions();
  }

  void _settleSubscriptions() {
    if (_current.phase != MqttSamplerPhase.subscribing) return;
    _deadline?.cancel();
    if (_granted.isEmpty) {
      AppLogging.mqttProxyWarning('TOPIC_FINDER: every filter refused');
      _fail(MqttSamplerFailure.filtersRefused);
      return;
    }
    AppLogging.mqttProxy(
      'TOPIC_FINDER: subscribed granted=${_granted.length} '
      'unanswered=${_pending.length}',
    );
    _endsAt = DateTime.now().add(duration);
    _emitSampling();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining() <= 0) {
        _finish();
      } else {
        _emitSampling();
      }
    });
  }

  void _handleMessage((String, Uint8List) message) {
    if (_current.phase != MqttSamplerPhase.sampling) return;
    _messageCount++;
    final observation = _tally.record(message.$1, message.$2);
    if (observation != null &&
        observation.root == _regionTopic &&
        observation.kind is MqttPacketTopic) {
      _regionPackets++;
      if (_regionPackets == regionPacketCap) {
        _client?.unsubscribe('$_regionTopic/2/e/+/+');
        _tally.markTruncated(_regionTopic);
      }
    }
    if (_messageCount >= messageCap) _finish();
  }

  void _handleDisconnected() {
    switch (_current.phase) {
      case MqttSamplerPhase.connecting:
        _fail(MqttSamplerFailure.connect);
      case MqttSamplerPhase.subscribing:
        // How the public broker refuses a filter: the socket closes with
        // no SUBACK.
        _fail(MqttSamplerFailure.filtersRefused);
      case MqttSamplerPhase.sampling:
        // Partial results are still useful.
        if (_messageCount > 0) {
          _finish();
        } else {
          _fail(MqttSamplerFailure.closed);
        }
      case MqttSamplerPhase.idle:
      case MqttSamplerPhase.finished:
      case MqttSamplerPhase.failed:
        return;
    }
  }

  int _remaining() {
    final endsAt = _endsAt;
    if (endsAt == null) return 0;
    final ms = endsAt.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _emitSampling() => _emit(
    MqttSamplerSnapshot(
      phase: MqttSamplerPhase.sampling,
      activity: Map.of(_tally.activity),
      secondsRemaining: _remaining(),
      messageCount: _messageCount,
    ),
  );

  void _finish() {
    AppLogging.mqttProxy(
      'TOPIC_FINDER: finished messages=$_messageCount '
      'roots=${_tally.activity.length} dropped=${_tally.droppedRoots}',
    );
    final activity = Map.of(_tally.activity);
    _tearDown();
    _emit(
      MqttSamplerSnapshot(
        phase: MqttSamplerPhase.finished,
        activity: activity,
        messageCount: _messageCount,
      ),
    );
  }

  void _fail(MqttSamplerFailure failure) {
    final activity = Map.of(_tally.activity);
    _tearDown();
    _emit(
      MqttSamplerSnapshot(
        phase: MqttSamplerPhase.failed,
        failure: failure,
        activity: activity,
        messageCount: _messageCount,
      ),
    );
  }

  /// Ends the sample without a result.
  void stop() {
    _tearDown();
    if (_current.phase != MqttSamplerPhase.finished &&
        _current.phase != MqttSamplerPhase.failed) {
      _emit(const MqttSamplerSnapshot(phase: MqttSamplerPhase.idle));
    }
  }

  void _tearDown() {
    _deadline?.cancel();
    _deadline = null;
    _ticker?.cancel();
    _ticker = null;
    _messageSub?.cancel();
    _messageSub = null;
    final client = _client;
    _client = null;
    client?.disconnect();
  }

  void _emit(MqttSamplerSnapshot snapshot) {
    _current = snapshot;
    if (!_disposed) _snapshots.add(snapshot);
  }

  void dispose() {
    _tearDown();
    _disposed = true;
    _snapshots.close();
  }
}
