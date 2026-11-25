// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/mqtt_topics/mqtt_topic_sampler.dart';

class _FakeClient implements MqttSampleClient {
  _FakeClient({this.failConnect = false});

  final bool failConnect;
  final StreamController<(String, Uint8List)> _messages =
      StreamController.broadcast();
  final List<String> subscribed = [];
  final List<String> unsubscribed = [];
  bool disconnected = false;
  void Function(String)? subscribedCb;
  void Function(String)? failCb;
  void Function()? disconnectedCb;

  @override
  set onSubscribed(void Function(String topic) callback) =>
      subscribedCb = callback;
  @override
  set onSubscribeFail(void Function(String topic) callback) =>
      failCb = callback;
  @override
  set onDisconnected(void Function() callback) => disconnectedCb = callback;
  @override
  Stream<(String, Uint8List)> get messages => _messages.stream;

  @override
  Future<void> connect(MqttBrokerSettings settings) async {
    if (failConnect) throw StateError('refused');
  }

  @override
  void subscribe(String filter) => subscribed.add(filter);
  @override
  void unsubscribe(String filter) => unsubscribed.add(filter);
  @override
  void disconnect() => disconnected = true;

  void grantAll() => [...subscribed].forEach(subscribedCb!);
  void send(String topic) => _messages.add((topic, Uint8List(0)));
}

const _settings = MqttBrokerSettings(
  host: 'broker.example',
  port: 1883,
  useTls: false,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('eight filters under the region, never #', () {
    final filters = MqttTopicSampler.filters('msh/ANZ');
    expect(filters, hasLength(8));
    expect(filters, contains('msh/ANZ/2/map/'));
    expect(filters, contains('msh/ANZ/+/+/+/2/e/+/+'));
    expect(filters.any((f) => f.contains('#')), isFalse);
  });

  test('a refused connection fails with the connect reason', () async {
    final sampler = MqttTopicSampler(
      clientFactory: () => _FakeClient(failConnect: true),
    );
    addTearDown(sampler.dispose);
    await sampler.start(_settings, 'msh/ANZ');
    expect(sampler.current.phase, MqttSamplerPhase.failed);
    expect(sampler.current.failure, MqttSamplerFailure.connect);
  });

  test('granted filters start the sample and messages are tallied', () async {
    final client = _FakeClient();
    final sampler = MqttTopicSampler(clientFactory: () => client);
    addTearDown(sampler.dispose);
    await sampler.start(_settings, 'msh/ANZ');
    expect(sampler.current.phase, MqttSamplerPhase.subscribing);
    client.grantAll();
    expect(sampler.current.phase, MqttSamplerPhase.sampling);
    client.send('msh/ANZ/VIC/2/e/LongFast/!0a0b0c0d');
    client.send('msh/ANZ/VIC/2/map/');
    await _settle();
    sampler.stop();
    expect(client.disconnected, isTrue);
    client.disconnectedCb?.call();
    expect(sampler.current.phase, MqttSamplerPhase.idle);
  });

  test('the region packet stream is unsubscribed at its cap', () async {
    final client = _FakeClient();
    final sampler = MqttTopicSampler(clientFactory: () => client);
    addTearDown(sampler.dispose);
    await sampler.start(_settings, 'msh/ANZ');
    client.grantAll();
    for (var i = 0; i < MqttTopicSampler.regionPacketCap; i++) {
      client.send('msh/ANZ/2/e/LongFast/!0a0b0c0d');
    }
    await _settle();
    expect(client.unsubscribed, ['msh/ANZ/2/e/+/+']);
    client.disconnectedCb!();
    expect(sampler.current.phase, MqttSamplerPhase.finished);
    expect(sampler.current.activity['msh/ANZ']!.truncated, isTrue);
  });

  test('every filter refused, or the socket closed while subscribing, '
      'is a filter refusal', () async {
    final refused = _FakeClient();
    final a = MqttTopicSampler(clientFactory: () => refused);
    addTearDown(a.dispose);
    await a.start(_settings, 'msh/ANZ');
    for (final f in [...refused.subscribed]) {
      refused.failCb!(f);
    }
    expect(a.current.failure, MqttSamplerFailure.filtersRefused);

    final closed = _FakeClient();
    final b = MqttTopicSampler(clientFactory: () => closed);
    addTearDown(b.dispose);
    await b.start(_settings, 'msh/ANZ');
    closed.disconnectedCb!();
    expect(b.current.failure, MqttSamplerFailure.filtersRefused);
  });

  test('a close mid-sample keeps what was heard, or fails when nothing '
      'was', () async {
    final quiet = _FakeClient();
    final a = MqttTopicSampler(clientFactory: () => quiet);
    addTearDown(a.dispose);
    await a.start(_settings, 'msh/ANZ');
    quiet.grantAll();
    quiet.disconnectedCb!();
    expect(a.current.failure, MqttSamplerFailure.closed);

    final busy = _FakeClient();
    final b = MqttTopicSampler(clientFactory: () => busy);
    addTearDown(b.dispose);
    await b.start(_settings, 'msh/ANZ');
    busy.grantAll();
    busy.send('msh/ANZ/VIC/2/map/');
    await _settle();
    busy.disconnectedCb!();
    expect(b.current.phase, MqttSamplerPhase.finished);
    expect(b.current.activity.keys, ['msh/ANZ/VIC']);
  });

  test('the sample ends on its own after the duration', () async {
    final client = _FakeClient();
    final sampler = MqttTopicSampler(
      clientFactory: () => client,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(sampler.dispose);
    await sampler.start(_settings, 'msh/ANZ');
    client.grantAll();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(sampler.current.phase, MqttSamplerPhase.finished);
    expect(client.disconnected, isTrue);
  });

  group('broker settings from the form', () {
    test('a blank address is the public server with its credentials', () {
      final s = MqttBrokerSettings.fromForm(
        address: '',
        tlsEnabled: false,
        username: 'me',
        password: 'pw',
      );
      expect(s.host, 'mqtt.meshtastic.org');
      expect(s.port, 8883);
      expect(s.useTls, isTrue);
      expect(s.username, 'meshdev');
    });

    test('a custom host keeps the form TLS, port and credentials', () {
      final plain = MqttBrokerSettings.fromForm(
        address: 'broker.example:1884',
        tlsEnabled: false,
        username: '',
        password: '',
      );
      expect(plain.host, 'broker.example');
      expect(plain.port, 1884);
      expect(plain.useTls, isFalse);
      expect(plain.username, isNull);
      final tls = MqttBrokerSettings.fromForm(
        address: 'broker.example',
        tlsEnabled: true,
        username: 'u',
        password: 'p',
      );
      expect(tls.port, 8883);
      expect(tls.password, 'p');
    });
  });
}
