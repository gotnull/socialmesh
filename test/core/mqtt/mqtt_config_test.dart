// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_config.dart';
import 'package:socialmesh/core/mqtt/mqtt_constants.dart';

void main() {
  group('GlobalLayerPrivacySettings', () {
    test('defaults have all toggles off', () {
      const privacy = GlobalLayerPrivacySettings();
      expect(privacy.shareMessages, isFalse);
      expect(privacy.shareTelemetry, isFalse);
      expect(privacy.allowInboundGlobal, isFalse);
    });

    test('allOff constant matches default constructor', () {
      expect(
        GlobalLayerPrivacySettings.allOff,
        const GlobalLayerPrivacySettings(),
      );
    });

    test('isAnythingShared returns false when all toggles off', () {
      const privacy = GlobalLayerPrivacySettings();
      expect(privacy.isAnythingShared, isFalse);
    });

    test('isAnythingShared returns true when shareMessages is on', () {
      const privacy = GlobalLayerPrivacySettings(shareMessages: true);
      expect(privacy.isAnythingShared, isTrue);
    });

    test('isAnythingShared returns true when shareTelemetry is on', () {
      const privacy = GlobalLayerPrivacySettings(shareTelemetry: true);
      expect(privacy.isAnythingShared, isTrue);
    });

    test('isAnythingShared returns true when allowInboundGlobal is on', () {
      const privacy = GlobalLayerPrivacySettings(allowInboundGlobal: true);
      expect(privacy.isAnythingShared, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const original = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      final copy = original.copyWith(shareTelemetry: true);
      expect(copy.shareMessages, isTrue);
      expect(copy.shareTelemetry, isTrue);
      expect(copy.allowInboundGlobal, isTrue);
    });

    test('copyWith with no arguments returns equivalent instance', () {
      const original = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: true,
        allowInboundGlobal: false,
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('toJson serializes all fields', () {
      const privacy = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      final json = privacy.toJson();
      expect(json['shareMessages'], isTrue);
      expect(json['shareTelemetry'], isFalse);
      expect(json['allowInboundGlobal'], isTrue);
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'shareMessages': true,
        'shareTelemetry': true,
        'allowInboundGlobal': false,
      };
      final privacy = GlobalLayerPrivacySettings.fromJson(json);
      expect(privacy.shareMessages, isTrue);
      expect(privacy.shareTelemetry, isTrue);
      expect(privacy.allowInboundGlobal, isFalse);
    });

    test('fromJson uses defaults for missing fields', () {
      final privacy = GlobalLayerPrivacySettings.fromJson({});
      expect(privacy.shareMessages, GlobalLayerConstants.defaultShareMessages);
      expect(
        privacy.shareTelemetry,
        GlobalLayerConstants.defaultShareTelemetry,
      );
      expect(
        privacy.allowInboundGlobal,
        GlobalLayerConstants.defaultAllowInboundGlobal,
      );
    });

    test('fromJson handles null values gracefully', () {
      final json = <String, dynamic>{
        'shareMessages': null,
        'shareTelemetry': null,
        'allowInboundGlobal': null,
      };
      final privacy = GlobalLayerPrivacySettings.fromJson(json);
      expect(privacy.shareMessages, GlobalLayerConstants.defaultShareMessages);
      expect(
        privacy.shareTelemetry,
        GlobalLayerConstants.defaultShareTelemetry,
      );
      expect(
        privacy.allowInboundGlobal,
        GlobalLayerConstants.defaultAllowInboundGlobal,
      );
    });

    test('roundtrip toJson -> fromJson preserves all values', () {
      const original = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      final restored = GlobalLayerPrivacySettings.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('equality works correctly', () {
      const a = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      const b = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      const c = GlobalLayerPrivacySettings(
        shareMessages: false,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      const b = GlobalLayerPrivacySettings(
        shareMessages: true,
        shareTelemetry: false,
        allowInboundGlobal: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains field names', () {
      const privacy = GlobalLayerPrivacySettings();
      final str = privacy.toString();
      expect(str, contains('shareMessages'));
      expect(str, contains('shareTelemetry'));
      expect(str, contains('allowInboundGlobal'));
    });
  });

  group('TopicSubscription', () {
    test('default values are correct', () {
      const sub = TopicSubscription(topic: 'msh/chat/+', label: 'Chat');
      expect(sub.topic, 'msh/chat/+');
      expect(sub.label, 'Chat');
      expect(sub.enabled, isFalse);
      expect(sub.lastMessageAt, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime.now();
      final original = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: true,
        lastMessageAt: now,
      );
      final copy = original.copyWith(enabled: false);
      expect(copy.topic, 'msh/chat/+');
      expect(copy.label, 'Chat');
      expect(copy.enabled, isFalse);
      expect(copy.lastMessageAt, now);
    });

    test('copyWith with no arguments returns equivalent instance', () {
      const original = TopicSubscription(
        topic: 'msh/telemetry/+',
        label: 'Telemetry',
        enabled: true,
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
    });

    test('toJson serializes all fields', () {
      final now = DateTime(2025, 6, 15, 12, 0, 0);
      final sub = TopicSubscription(
        topic: 'msh/chat/primary',
        label: 'Chat',
        enabled: true,
        lastMessageAt: now,
      );
      final json = sub.toJson();
      expect(json['topic'], 'msh/chat/primary');
      expect(json['label'], 'Chat');
      expect(json['enabled'], isTrue);
      expect(json['lastMessageAt'], now.toIso8601String());
    });

    test('toJson omits lastMessageAt when null', () {
      const sub = TopicSubscription(topic: 'msh/chat/+', label: 'Chat');
      final json = sub.toJson();
      expect(json.containsKey('lastMessageAt'), isFalse);
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'topic': 'msh/chat/primary',
        'label': 'Chat',
        'enabled': true,
        'lastMessageAt': '2025-06-15T12:00:00.000',
      };
      final sub = TopicSubscription.fromJson(json);
      expect(sub.topic, 'msh/chat/primary');
      expect(sub.label, 'Chat');
      expect(sub.enabled, isTrue);
      expect(sub.lastMessageAt, isNotNull);
    });

    test('fromJson uses defaults for missing fields', () {
      final sub = TopicSubscription.fromJson({});
      expect(sub.topic, '');
      expect(sub.label, '');
      expect(sub.enabled, isFalse);
      expect(sub.lastMessageAt, isNull);
    });

    test('fromJson handles invalid date string gracefully', () {
      final json = {
        'topic': 'test',
        'label': 'Test',
        'lastMessageAt': 'not-a-date',
      };
      final sub = TopicSubscription.fromJson(json);
      expect(sub.lastMessageAt, isNull);
    });

    test('roundtrip toJson -> fromJson preserves values', () {
      final now = DateTime(2025, 6, 15, 12, 0, 0);
      final original = TopicSubscription(
        topic: 'msh/chat/primary',
        label: 'Chat',
        enabled: true,
        lastMessageAt: now,
      );
      final restored = TopicSubscription.fromJson(original.toJson());
      expect(restored.topic, original.topic);
      expect(restored.label, original.label);
      expect(restored.enabled, original.enabled);
    });

    test('equality compares topic, label, and enabled', () {
      const a = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: true,
      );
      const b = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: true,
      );
      const c = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: false,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: true,
      );
      const b = TopicSubscription(
        topic: 'msh/chat/+',
        label: 'Chat',
        enabled: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains topic and label', () {
      const sub = TopicSubscription(topic: 'msh/chat/primary', label: 'Chat');
      final str = sub.toString();
      expect(str, contains('msh/chat/primary'));
      expect(str, contains('Chat'));
    });
  });

  group('GlobalLayerConfig', () {
    test('initial constant has expected defaults', () {
      const config = GlobalLayerConfig.initial;
      expect(config.host, '');
      expect(config.port, GlobalLayerConstants.defaultTlsPort);
      expect(config.useTls, isTrue);
      expect(config.username, '');
      expect(config.password, '');
      expect(config.clientId, '');
      expect(config.topicRoot, GlobalLayerConstants.defaultTopicRoot);
      expect(config.subscriptions, isEmpty);
      expect(config.privacy, const GlobalLayerPrivacySettings());
      expect(config.enabled, isFalse);
      expect(config.setupComplete, isFalse);
      expect(config.lastConnectedAt, isNull);
      expect(config.lastModifiedAt, isNull);
    });

    group('derived properties', () {
      test('hasBrokerConfig is false when host is empty', () {
        const config = GlobalLayerConfig();
        expect(config.hasBrokerConfig, isFalse);
      });

      test('hasBrokerConfig is false when host is whitespace only', () {
        const config = GlobalLayerConfig(host: '   ');
        expect(config.hasBrokerConfig, isFalse);
      });

      test('hasBrokerConfig is true when host is non-empty', () {
        const config = GlobalLayerConfig(host: 'broker.example.com');
        expect(config.hasBrokerConfig, isTrue);
      });

      test('hasCredentials is false when username or password is empty', () {
        const noUser = GlobalLayerConfig(password: 'pass');
        const noPass = GlobalLayerConfig(username: 'user');
        const neither = GlobalLayerConfig();
        expect(noUser.hasCredentials, isFalse);
        expect(noPass.hasCredentials, isFalse);
        expect(neither.hasCredentials, isFalse);
      });

      test('hasCredentials is true when both username and password set', () {
        const config = GlobalLayerConfig(username: 'user', password: 'pass');
        expect(config.hasCredentials, isTrue);
      });

      test('effectivePort returns configured port when valid', () {
        const config = GlobalLayerConfig(port: 9999);
        expect(config.effectivePort, 9999);
      });

      test('effectivePort returns TLS default when port is 0 and TLS on', () {
        const config = GlobalLayerConfig(port: 0, useTls: true);
        expect(config.effectivePort, GlobalLayerConstants.defaultTlsPort);
      });

      test(
        'effectivePort returns non-TLS default when port is 0 and TLS off',
        () {
          const config = GlobalLayerConfig(port: 0, useTls: false);
          expect(config.effectivePort, GlobalLayerConstants.defaultPort);
        },
      );

      test('enabledSubscriptions returns only enabled subscriptions', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: true),
            TopicSubscription(topic: 'b', label: 'B', enabled: false),
            TopicSubscription(topic: 'c', label: 'C', enabled: true),
          ],
        );
        final enabled = config.enabledSubscriptions;
        expect(enabled.length, 2);
        expect(enabled[0].topic, 'a');
        expect(enabled[1].topic, 'c');
      });

      test('hasEnabledTopics returns false when no subscriptions enabled', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: false),
          ],
        );
        expect(config.hasEnabledTopics, isFalse);
      });

      test('hasEnabledTopics returns true when at least one enabled', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: true),
          ],
        );
        expect(config.hasEnabledTopics, isTrue);
      });

      test('hasEnabledTopics returns false with empty subscriptions', () {
        const config = GlobalLayerConfig();
        expect(config.hasEnabledTopics, isFalse);
      });

      test('displayUri uses mqtts scheme when TLS enabled', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: GlobalLayerConstants.defaultTlsPort,
          useTls: true,
        );
        expect(config.displayUri, 'mqtts://broker.example.com');
      });

      test('displayUri uses mqtt scheme when TLS disabled', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: GlobalLayerConstants.defaultPort,
          useTls: false,
        );
        expect(config.displayUri, 'mqtt://broker.example.com');
      });

      test('displayUri includes port when non-default', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 9999,
          useTls: true,
        );
        expect(config.displayUri, 'mqtts://broker.example.com:9999');
      });

      test('displayUri omits default TLS port', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: GlobalLayerConstants.defaultTlsPort,
          useTls: true,
        );
        expect(
          config.displayUri,
          isNot(contains(':${GlobalLayerConstants.defaultTlsPort}')),
        );
      });

      test('displayUri omits default non-TLS port', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: GlobalLayerConstants.defaultPort,
          useTls: false,
        );
        expect(
          config.displayUri,
          isNot(contains(':${GlobalLayerConstants.defaultPort}')),
        );
      });
    });

    group('copyWith', () {
      test('creates a new instance with updated fields', () {
        const original = GlobalLayerConfig(
          host: 'old.broker.com',
          port: 1883,
          useTls: false,
        );
        final copy = original.copyWith(host: 'new.broker.com', useTls: true);
        expect(copy.host, 'new.broker.com');
        expect(copy.port, 1883);
        expect(copy.useTls, isTrue);
      });

      test('preserves all fields when no arguments provided', () {
        const original = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 8883,
          useTls: true,
          username: 'user',
          password: 'pass',
          clientId: 'client1',
          topicRoot: 'myroot',
          enabled: true,
          setupComplete: true,
        );
        final copy = original.copyWith();
        expect(copy.host, original.host);
        expect(copy.port, original.port);
        expect(copy.useTls, original.useTls);
        expect(copy.username, original.username);
        expect(copy.password, original.password);
        expect(copy.clientId, original.clientId);
        expect(copy.topicRoot, original.topicRoot);
        expect(copy.enabled, original.enabled);
        expect(copy.setupComplete, original.setupComplete);
      });

      test('can update password', () {
        const original = GlobalLayerConfig(password: 'old');
        final copy = original.copyWith(password: 'new');
        expect(copy.password, 'new');
      });

      test('can update subscriptions', () {
        const original = GlobalLayerConfig();
        final copy = original.copyWith(
          subscriptions: [
            const TopicSubscription(topic: 'test', label: 'Test'),
          ],
        );
        expect(copy.subscriptions.length, 1);
        expect(copy.subscriptions[0].topic, 'test');
      });

      test('can update privacy settings', () {
        const original = GlobalLayerConfig();
        final copy = original.copyWith(
          privacy: const GlobalLayerPrivacySettings(shareMessages: true),
        );
        expect(copy.privacy.shareMessages, isTrue);
      });

      test('can update timestamps', () {
        final now = DateTime.now();
        const original = GlobalLayerConfig();
        final copy = original.copyWith(
          lastConnectedAt: now,
          lastModifiedAt: now,
        );
        expect(copy.lastConnectedAt, now);
        expect(copy.lastModifiedAt, now);
      });
    });

    group('subscription mutations', () {
      test('withSubscription updates subscription at index', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: false),
            TopicSubscription(topic: 'b', label: 'B', enabled: false),
          ],
        );
        final updated = config.withSubscription(
          0,
          const TopicSubscription(topic: 'a', label: 'A', enabled: true),
        );
        expect(updated.subscriptions[0].enabled, isTrue);
        expect(updated.subscriptions[1].enabled, isFalse);
        expect(updated.lastModifiedAt, isNotNull);
      });

      test('withSubscription returns same config for invalid index', () {
        const config = GlobalLayerConfig(
          subscriptions: [TopicSubscription(topic: 'a', label: 'A')],
        );
        final result = config.withSubscription(
          5,
          const TopicSubscription(topic: 'x', label: 'X'),
        );
        expect(result, same(config));
      });

      test('withSubscription returns same config for negative index', () {
        const config = GlobalLayerConfig(
          subscriptions: [TopicSubscription(topic: 'a', label: 'A')],
        );
        final result = config.withSubscription(
          -1,
          const TopicSubscription(topic: 'x', label: 'X'),
        );
        expect(result, same(config));
      });

      test('addSubscription appends a new subscription', () {
        const config = GlobalLayerConfig(
          subscriptions: [TopicSubscription(topic: 'a', label: 'A')],
        );
        final updated = config.addSubscription(
          const TopicSubscription(topic: 'b', label: 'B'),
        );
        expect(updated.subscriptions.length, 2);
        expect(updated.subscriptions[1].topic, 'b');
        expect(updated.lastModifiedAt, isNotNull);
      });

      test('addSubscription on empty config works', () {
        const config = GlobalLayerConfig();
        final updated = config.addSubscription(
          const TopicSubscription(topic: 'a', label: 'A'),
        );
        expect(updated.subscriptions.length, 1);
      });

      test('removeSubscription removes subscription at index', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A'),
            TopicSubscription(topic: 'b', label: 'B'),
            TopicSubscription(topic: 'c', label: 'C'),
          ],
        );
        final updated = config.removeSubscription(1);
        expect(updated.subscriptions.length, 2);
        expect(updated.subscriptions[0].topic, 'a');
        expect(updated.subscriptions[1].topic, 'c');
        expect(updated.lastModifiedAt, isNotNull);
      });

      test('removeSubscription returns same config for invalid index', () {
        const config = GlobalLayerConfig(
          subscriptions: [TopicSubscription(topic: 'a', label: 'A')],
        );
        final result = config.removeSubscription(5);
        expect(result, same(config));
      });

      test('removeSubscription returns same config for negative index', () {
        const config = GlobalLayerConfig(
          subscriptions: [TopicSubscription(topic: 'a', label: 'A')],
        );
        final result = config.removeSubscription(-1);
        expect(result, same(config));
      });
    });

    group('serialization', () {
      test('toJson excludes password', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          username: 'user',
          password: 'super-secret-password',
        );
        final json = config.toJson();
        expect(json.containsKey('password'), isFalse);
        expect(json['username'], 'user');
        expect(json['host'], 'broker.example.com');
      });

      test('toJson includes all non-secret fields', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 8883,
          useTls: true,
          username: 'user',
          clientId: 'client1',
          topicRoot: 'myroot',
          enabled: true,
          setupComplete: true,
        );
        final json = config.toJson();
        expect(json['host'], 'broker.example.com');
        expect(json['port'], 8883);
        expect(json['useTls'], isTrue);
        expect(json['username'], 'user');
        expect(json['clientId'], 'client1');
        expect(json['topicRoot'], 'myroot');
        expect(json['enabled'], isTrue);
        expect(json['setupComplete'], isTrue);
      });

      test('toJson omits null timestamps', () {
        const config = GlobalLayerConfig();
        final json = config.toJson();
        expect(json.containsKey('lastConnectedAt'), isFalse);
        expect(json.containsKey('lastModifiedAt'), isFalse);
      });

      test('toJson includes timestamps when present', () {
        final now = DateTime(2025, 6, 15, 12, 0, 0);
        final config = GlobalLayerConfig(
          lastConnectedAt: now,
          lastModifiedAt: now,
        );
        final json = config.toJson();
        expect(json.containsKey('lastConnectedAt'), isTrue);
        expect(json.containsKey('lastModifiedAt'), isTrue);
      });

      test('toJson serializes subscriptions', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: true),
            TopicSubscription(topic: 'b', label: 'B', enabled: false),
          ],
        );
        final json = config.toJson();
        final subs = json['subscriptions'] as List;
        expect(subs.length, 2);
        expect((subs[0] as Map)['topic'], 'a');
        expect((subs[1] as Map)['topic'], 'b');
      });

      test('toJson serializes privacy settings', () {
        const config = GlobalLayerConfig(
          privacy: GlobalLayerPrivacySettings(shareMessages: true),
        );
        final json = config.toJson();
        final privacy = json['privacy'] as Map;
        expect(privacy['shareMessages'], isTrue);
      });

      test('fromJson deserializes all non-secret fields', () {
        final json = {
          'host': 'broker.example.com',
          'port': 8883,
          'useTls': true,
          'username': 'user',
          'clientId': 'client1',
          'topicRoot': 'myroot',
          'subscriptions': [
            {'topic': 'a', 'label': 'A', 'enabled': true},
          ],
          'privacy': {
            'shareMessages': true,
            'shareTelemetry': false,
            'allowInboundGlobal': false,
          },
          'enabled': true,
          'setupComplete': true,
          'lastConnectedAt': '2025-06-15T12:00:00.000',
          'lastModifiedAt': '2025-06-15T12:00:00.000',
        };
        final config = GlobalLayerConfig.fromJson(json);
        expect(config.host, 'broker.example.com');
        expect(config.port, 8883);
        expect(config.useTls, isTrue);
        expect(config.username, 'user');
        expect(config.clientId, 'client1');
        expect(config.topicRoot, 'myroot');
        expect(config.subscriptions.length, 1);
        expect(config.subscriptions[0].topic, 'a');
        expect(config.privacy.shareMessages, isTrue);
        expect(config.enabled, isTrue);
        expect(config.setupComplete, isTrue);
        expect(config.lastConnectedAt, isNotNull);
        expect(config.lastModifiedAt, isNotNull);
      });

      test('fromJson accepts password parameter', () {
        final config = GlobalLayerConfig.fromJson({
          'host': 'test',
        }, password: 'secret');
        expect(config.password, 'secret');
      });

      test('fromJson uses empty password by default', () {
        final config = GlobalLayerConfig.fromJson({'host': 'test'});
        expect(config.password, '');
      });

      test('fromJson uses defaults for missing fields', () {
        final config = GlobalLayerConfig.fromJson({});
        expect(config.host, '');
        expect(config.port, GlobalLayerConstants.defaultTlsPort);
        expect(config.useTls, isTrue);
        expect(config.username, '');
        expect(config.password, '');
        expect(config.clientId, '');
        expect(config.topicRoot, GlobalLayerConstants.defaultTopicRoot);
        expect(config.subscriptions, isEmpty);
        expect(config.enabled, isFalse);
        expect(config.setupComplete, isFalse);
        expect(config.lastConnectedAt, isNull);
        expect(config.lastModifiedAt, isNull);
      });

      test('fromJson handles invalid timestamp strings', () {
        final config = GlobalLayerConfig.fromJson({
          'lastConnectedAt': 'not-a-date',
          'lastModifiedAt': 'also-not-a-date',
        });
        expect(config.lastConnectedAt, isNull);
        expect(config.lastModifiedAt, isNull);
      });

      test('fromJson handles missing subscriptions list', () {
        final config = GlobalLayerConfig.fromJson({'host': 'test'});
        expect(config.subscriptions, isEmpty);
      });

      test('fromJson handles missing privacy object', () {
        final config = GlobalLayerConfig.fromJson({'host': 'test'});
        expect(config.privacy, const GlobalLayerPrivacySettings());
      });

      test('roundtrip toJson -> fromJson preserves non-secret fields', () {
        const original = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 8883,
          useTls: true,
          username: 'user',
          password: 'secret',
          clientId: 'client1',
          topicRoot: 'myroot',
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: true),
          ],
          privacy: GlobalLayerPrivacySettings(shareMessages: true),
          enabled: true,
          setupComplete: true,
        );
        final restored = GlobalLayerConfig.fromJson(
          original.toJson(),
          password: 'secret',
        );
        expect(restored.host, original.host);
        expect(restored.port, original.port);
        expect(restored.useTls, original.useTls);
        expect(restored.username, original.username);
        expect(restored.password, original.password);
        expect(restored.clientId, original.clientId);
        expect(restored.topicRoot, original.topicRoot);
        expect(restored.subscriptions.length, original.subscriptions.length);
        expect(restored.privacy, original.privacy);
        expect(restored.enabled, original.enabled);
        expect(restored.setupComplete, original.setupComplete);
      });

      test('toJsonString produces valid JSON', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          username: 'user',
        );
        final jsonString = config.toJsonString();
        expect(() => jsonDecode(jsonString), returnsNormally);
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(decoded['host'], 'broker.example.com');
      });

      test('toJsonString does not contain password', () {
        const config = GlobalLayerConfig(
          host: 'test',
          password: 'super-secret-value',
        );
        final jsonString = config.toJsonString();
        expect(jsonString, isNot(contains('super-secret-value')));
      });

      test('fromJsonString deserializes correctly', () {
        const original = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 1883,
          useTls: false,
        );
        final jsonString = original.toJsonString();
        final restored = GlobalLayerConfig.fromJsonString(
          jsonString,
          password: 'pw',
        );
        expect(restored.host, original.host);
        expect(restored.port, original.port);
        expect(restored.useTls, original.useTls);
        expect(restored.password, 'pw');
      });
    });

    group('redaction', () {
      test('toRedactedJson masks username when present', () {
        const config = GlobalLayerConfig(username: 'myuser');
        final redacted = config.toRedactedJson();
        expect(redacted['username'], '***');
      });

      test('toRedactedJson shows (empty) for empty username', () {
        const config = GlobalLayerConfig(username: '');
        final redacted = config.toRedactedJson();
        expect(redacted['username'], '(empty)');
      });

      test('toRedactedJson masks password when present', () {
        const config = GlobalLayerConfig(password: 'secret');
        final redacted = config.toRedactedJson();
        expect(redacted['password'], '***');
      });

      test('toRedactedJson shows (empty) for empty password', () {
        const config = GlobalLayerConfig(password: '');
        final redacted = config.toRedactedJson();
        expect(redacted['password'], '(empty)');
      });

      test('toRedactedJson shows (empty) for empty host', () {
        const config = GlobalLayerConfig(host: '');
        final redacted = config.toRedactedJson();
        expect(redacted['host'], '(empty)');
      });

      test('toRedactedJson shows actual host when present', () {
        const config = GlobalLayerConfig(host: 'broker.example.com');
        final redacted = config.toRedactedJson();
        expect(redacted['host'], 'broker.example.com');
      });

      test('toRedactedJson shows (auto) for empty clientId', () {
        const config = GlobalLayerConfig(clientId: '');
        final redacted = config.toRedactedJson();
        expect(redacted['clientId'], '(auto)');
      });

      test('toRedactedJson shows actual clientId when present', () {
        const config = GlobalLayerConfig(clientId: 'my-client');
        final redacted = config.toRedactedJson();
        expect(redacted['clientId'], 'my-client');
      });

      test('toRedactedJson includes derived properties', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A', enabled: true),
            TopicSubscription(topic: 'b', label: 'B', enabled: false),
          ],
        );
        final redacted = config.toRedactedJson();
        expect(redacted['hasEnabledTopics'], isTrue);
        expect(redacted['enabledTopicCount'], 1);
      });

      test('toRedactedJson never contains the actual password string', () {
        const config = GlobalLayerConfig(
          password: 'my-super-secret-password-12345',
        );
        final redacted = config.toRedactedJson();
        final jsonString = jsonEncode(redacted);
        expect(jsonString, isNot(contains('my-super-secret-password-12345')));
      });

      test('toRedactedString produces valid formatted JSON', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          password: 'secret',
        );
        final str = config.toRedactedString();
        expect(() => jsonDecode(str), returnsNormally);
        // Should be formatted (multi-line)
        expect(str, contains('\n'));
      });

      test('toRedactedString does not contain actual password', () {
        const config = GlobalLayerConfig(password: 'hunter2');
        final str = config.toRedactedString();
        expect(str, isNot(contains('hunter2')));
      });
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        const a = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 8883,
          useTls: true,
          username: 'user',
          password: 'pass',
          clientId: 'client1',
          topicRoot: 'msh',
          enabled: true,
          setupComplete: true,
        );
        const b = GlobalLayerConfig(
          host: 'broker.example.com',
          port: 8883,
          useTls: true,
          username: 'user',
          password: 'pass',
          clientId: 'client1',
          topicRoot: 'msh',
          enabled: true,
          setupComplete: true,
        );
        expect(a, equals(b));
      });

      test('configs with different hosts are not equal', () {
        const a = GlobalLayerConfig(host: 'broker-a.com');
        const b = GlobalLayerConfig(host: 'broker-b.com');
        expect(a, isNot(equals(b)));
      });

      test('configs with different ports are not equal', () {
        const a = GlobalLayerConfig(port: 1883);
        const b = GlobalLayerConfig(port: 8883);
        expect(a, isNot(equals(b)));
      });

      test('configs with different TLS setting are not equal', () {
        const a = GlobalLayerConfig(useTls: true);
        const b = GlobalLayerConfig(useTls: false);
        expect(a, isNot(equals(b)));
      });

      test('configs with different passwords are not equal', () {
        const a = GlobalLayerConfig(password: 'pw1');
        const b = GlobalLayerConfig(password: 'pw2');
        expect(a, isNot(equals(b)));
      });

      test('configs with different enabled status are not equal', () {
        const a = GlobalLayerConfig(enabled: true);
        const b = GlobalLayerConfig(enabled: false);
        expect(a, isNot(equals(b)));
      });

      test('configs with different privacy settings are not equal', () {
        const a = GlobalLayerConfig(
          privacy: GlobalLayerPrivacySettings(shareMessages: true),
        );
        const b = GlobalLayerConfig(
          privacy: GlobalLayerPrivacySettings(shareMessages: false),
        );
        expect(a, isNot(equals(b)));
      });

      test('hashCode is consistent for equal objects', () {
        const a = GlobalLayerConfig(host: 'test', port: 8883, useTls: true);
        const b = GlobalLayerConfig(host: 'test', port: 8883, useTls: true);
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains key field values', () {
        const config = GlobalLayerConfig(
          host: 'broker.example.com',
          topicRoot: 'myroot',
          enabled: true,
          setupComplete: true,
        );
        final str = config.toString();
        expect(str, contains('broker.example.com'));
        expect(str, contains('myroot'));
        expect(str, contains('enabled: true'));
        expect(str, contains('setupComplete: true'));
      });

      test('masks non-empty username in toString', () {
        const config = GlobalLayerConfig(username: 'myuser');
        final str = config.toString();
        expect(str, isNot(contains('myuser')));
        expect(str, contains('***'));
      });

      test('shows (empty) for empty username in toString', () {
        const config = GlobalLayerConfig(username: '');
        final str = config.toString();
        expect(str, contains('(empty)'));
      });

      test('does not contain password in toString', () {
        const config = GlobalLayerConfig(password: 'secret-value');
        final str = config.toString();
        expect(str, isNot(contains('secret-value')));
      });

      test('includes subscription count', () {
        const config = GlobalLayerConfig(
          subscriptions: [
            TopicSubscription(topic: 'a', label: 'A'),
            TopicSubscription(topic: 'b', label: 'B'),
          ],
        );
        final str = config.toString();
        expect(str, contains('2'));
      });
    });
  });

  group('BrokerPreset', () {
    test('defaults list is not empty', () {
      expect(BrokerPreset.defaults, isNotEmpty);
    });

    test('all presets have non-empty names', () {
      for (final preset in BrokerPreset.defaults) {
        expect(preset.name, isNotEmpty, reason: 'Preset has empty name');
      }
    });

    test('all presets have non-empty descriptions', () {
      for (final preset in BrokerPreset.defaults) {
        expect(
          preset.description,
          isNotEmpty,
          reason: 'Preset "${preset.name}" has empty description',
        );
      }
    });

    test('all presets have valid port numbers', () {
      for (final preset in BrokerPreset.defaults) {
        expect(
          preset.port,
          greaterThan(0),
          reason: 'Preset "${preset.name}" has invalid port',
        );
        expect(
          preset.port,
          lessThanOrEqualTo(65535),
          reason: 'Preset "${preset.name}" has port > 65535',
        );
      }
    });

    test('all presets have non-empty suggested root', () {
      for (final preset in BrokerPreset.defaults) {
        expect(
          preset.suggestedRoot,
          isNotEmpty,
          reason: 'Preset "${preset.name}" has empty suggestedRoot',
        );
      }
    });

    test('first preset is the recommended default (not custom)', () {
      final first = BrokerPreset.defaults.first;
      expect(first.isCustom, isFalse);
      expect(first.host, isNotEmpty);
      expect(first.name, 'Meshtastic (Official)');
    });

    test('custom broker preset exists in the list', () {
      final custom = BrokerPreset.defaults.where((p) => p.isCustom);
      expect(custom, hasLength(1));
      expect(custom.first.name, 'Custom Broker');
      expect(custom.first.host, isEmpty);
    });

    test('all presets have non-empty iconName', () {
      for (final preset in BrokerPreset.defaults) {
        expect(
          preset.iconName,
          isNotEmpty,
          reason: 'Preset "${preset.name}" has empty iconName',
        );
      }
    });

    test('presets with requiresAuth have default credentials', () {
      for (final preset in BrokerPreset.defaults) {
        if (preset.requiresAuth && !preset.isCustom) {
          expect(
            preset.hasDefaultCredentials,
            isTrue,
            reason:
                'Preset "${preset.name}" requires auth but has no default '
                'credentials',
          );
        }
      }
    });

    test('custom preset has no default credentials', () {
      final custom = BrokerPreset.defaults.firstWhere((p) => p.isCustom);
      expect(custom.hasDefaultCredentials, isFalse);
    });

    test('only one preset is marked isCustom', () {
      final customCount = BrokerPreset.defaults.where((p) => p.isCustom).length;
      expect(customCount, 1);
    });
  });

  group('GlobalLayerConstants defaults', () {
    test('all privacy defaults are false (safe-by-default)', () {
      expect(GlobalLayerConstants.defaultShareMessages, isFalse);
      expect(GlobalLayerConstants.defaultShareTelemetry, isFalse);
      expect(GlobalLayerConstants.defaultAllowInboundGlobal, isFalse);
    });

    test('default TLS port is 8883', () {
      expect(GlobalLayerConstants.defaultTlsPort, 8883);
    });

    test('default non-TLS port is 1883', () {
      expect(GlobalLayerConstants.defaultPort, 1883);
    });

    test('default topic root is msh', () {
      expect(GlobalLayerConstants.defaultTopicRoot, 'msh');
    });

    test('connection timeout is positive', () {
      expect(GlobalLayerConstants.connectionTimeout.inSeconds, greaterThan(0));
    });

    test('diagnostic step timeout is positive', () {
      expect(
        GlobalLayerConstants.diagnosticStepTimeout.inSeconds,
        greaterThan(0),
      );
    });

    test('max reconnect attempts is positive', () {
      expect(GlobalLayerConstants.maxReconnectAttempts, greaterThan(0));
    });

    test('metrics window is positive', () {
      expect(GlobalLayerConstants.metricsWindow.inSeconds, greaterThan(0));
    });

    test('max topic length is positive', () {
      expect(GlobalLayerConstants.maxTopicLength, greaterThan(0));
    });

    test('max topic root length is positive', () {
      expect(GlobalLayerConstants.maxTopicRootLength, greaterThan(0));
    });

    test('max topic root length is less than max topic length', () {
      expect(
        GlobalLayerConstants.maxTopicRootLength,
        lessThan(GlobalLayerConstants.maxTopicLength),
      );
    });
  });

  group('GlobalLayerCopy', () {
    test('all wizard step titles are non-empty', () {
      expect(GlobalLayerCopy.explainTitle, isNotEmpty);
      expect(GlobalLayerCopy.brokerTitle, isNotEmpty);
      expect(GlobalLayerCopy.topicsTitle, isNotEmpty);
      expect(GlobalLayerCopy.privacyTitle, isNotEmpty);
      expect(GlobalLayerCopy.testTitle, isNotEmpty);
      expect(GlobalLayerCopy.summaryTitle, isNotEmpty);
    });

    test('all wizard step bodies are non-empty', () {
      expect(GlobalLayerCopy.explainBody, isNotEmpty);
      expect(GlobalLayerCopy.brokerBody, isNotEmpty);
      expect(GlobalLayerCopy.topicsBody, isNotEmpty);
      expect(GlobalLayerCopy.privacyBody, isNotEmpty);
      expect(GlobalLayerCopy.testBody, isNotEmpty);
      expect(GlobalLayerCopy.summaryBody, isNotEmpty);
    });

    test('explain step has what it does and what it does not', () {
      expect(GlobalLayerCopy.explainWhatItDoes, isNotEmpty);
      expect(GlobalLayerCopy.explainWhatItDoesNot, isNotEmpty);
    });

    test('privacy broker trust warning is non-empty', () {
      expect(GlobalLayerCopy.privacyBrokerTrustWarning, isNotEmpty);
    });

    test('no copy text mentions MQTT before explanation', () {
      // The explainTitle and explainBody should use plain language
      // MQTT should not appear in the initial explanation title
      expect(
        GlobalLayerCopy.explainTitle.toUpperCase(),
        isNot(contains('MQTT')),
      );
    });
  });
}
