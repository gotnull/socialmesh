// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_remote_sighting.dart';

void main() {
  group('NodeDiscoverySource', () {
    test('displayLabel returns correct labels', () {
      expect(NodeDiscoverySource.local.displayLabel, 'Local');
      expect(NodeDiscoverySource.remote.displayLabel, 'Remote');
      expect(NodeDiscoverySource.mixed.displayLabel, 'Mixed');
    });

    test('description returns non-empty strings', () {
      for (final source in NodeDiscoverySource.values) {
        expect(source.description.isNotEmpty, true);
      }
    });

    test('key round-trips through fromKey', () {
      for (final source in NodeDiscoverySource.values) {
        expect(NodeDiscoverySource.fromKey(source.key), source);
      }
    });

    test('fromKey returns local for null', () {
      expect(NodeDiscoverySource.fromKey(null), NodeDiscoverySource.local);
    });

    test('fromKey returns local for unrecognised values', () {
      expect(NodeDiscoverySource.fromKey('unknown'), NodeDiscoverySource.local);
      expect(NodeDiscoverySource.fromKey(''), NodeDiscoverySource.local);
      expect(
        NodeDiscoverySource.fromKey('satellite'),
        NodeDiscoverySource.local,
      );
    });
  });

  group('RemoteSighting', () {
    late RemoteSighting sighting;
    late DateTime timestamp;

    setUp(() {
      timestamp = DateTime(2025, 6, 15, 14, 30);
      sighting = RemoteSighting(
        nodeNum: 0xA1B2C3D4,
        timestamp: timestamp,
        topic: 'msh/chat/LongFast',
        brokerUri: 'mqtts://broker.example.com',
        displayName: 'TestNode',
        shortName: 'TST',
        hardwareModel: 'HELTEC_V3',
        firmwareVersion: '2.3.4',
        channelContext: 'LongFast',
      );
    });

    test('constructor stores all fields', () {
      expect(sighting.nodeNum, 0xA1B2C3D4);
      expect(sighting.timestamp, timestamp);
      expect(sighting.topic, 'msh/chat/LongFast');
      expect(sighting.brokerUri, 'mqtts://broker.example.com');
      expect(sighting.displayName, 'TestNode');
      expect(sighting.shortName, 'TST');
      expect(sighting.hardwareModel, 'HELTEC_V3');
      expect(sighting.firmwareVersion, '2.3.4');
      expect(sighting.channelContext, 'LongFast');
    });

    test('now factory creates sighting with current timestamp', () {
      final before = DateTime.now();
      final nowSighting = RemoteSighting.now(
        nodeNum: 42,
        topic: 'msh/test',
        brokerUri: 'mqtt://localhost',
      );
      final after = DateTime.now();

      expect(nowSighting.nodeNum, 42);
      expect(nowSighting.topic, 'msh/test');
      expect(nowSighting.brokerUri, 'mqtt://localhost');
      expect(
        nowSighting.timestamp.isAfter(before) ||
            nowSighting.timestamp.isAtSameMomentAs(before),
        true,
      );
      expect(
        nowSighting.timestamp.isBefore(after) ||
            nowSighting.timestamp.isAtSameMomentAs(after),
        true,
      );
    });

    test('now factory accepts optional identity fields', () {
      final s = RemoteSighting.now(
        nodeNum: 100,
        topic: 'msh/info',
        brokerUri: 'mqtt://local',
        displayName: 'MyNode',
        shortName: 'MN',
        hardwareModel: 'RAK4631',
        firmwareVersion: '1.0.0',
        channelContext: 'Primary',
      );

      expect(s.displayName, 'MyNode');
      expect(s.shortName, 'MN');
      expect(s.hardwareModel, 'RAK4631');
      expect(s.firmwareVersion, '1.0.0');
      expect(s.channelContext, 'Primary');
    });

    test('hasIdentity is true when displayName is set', () {
      expect(sighting.hasIdentity, true);
    });

    test('hasIdentity is true when only shortName is set', () {
      final s = RemoteSighting(
        nodeNum: 1,
        timestamp: timestamp,
        topic: 'msh/test',
        brokerUri: 'mqtt://test',
        shortName: 'AB',
      );
      expect(s.hasIdentity, true);
    });

    test('hasIdentity is false when no name fields are set', () {
      final s = RemoteSighting(
        nodeNum: 1,
        timestamp: timestamp,
        topic: 'msh/test',
        brokerUri: 'mqtt://test',
      );
      expect(s.hasIdentity, false);
    });

    test('age returns correct duration', () {
      final old = RemoteSighting(
        nodeNum: 1,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        topic: 'msh/test',
        brokerUri: 'mqtt://test',
      );
      expect(old.age.inHours, greaterThanOrEqualTo(2));
    });

    test('isRecent is true for sightings within last hour', () {
      final recent = RemoteSighting(
        nodeNum: 1,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        topic: 'msh/test',
        brokerUri: 'mqtt://test',
      );
      expect(recent.isRecent, true);
    });

    test('isRecent is false for sightings older than one hour', () {
      final old = RemoteSighting(
        nodeNum: 1,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        topic: 'msh/test',
        brokerUri: 'mqtt://test',
      );
      expect(old.isRecent, false);
    });

    group('serialization', () {
      test('toJson includes all non-null fields', () {
        final json = sighting.toJson();

        expect(json['nn'], 0xA1B2C3D4);
        expect(json['ts'], timestamp.millisecondsSinceEpoch);
        expect(json['tp'], 'msh/chat/LongFast');
        expect(json['bu'], 'mqtts://broker.example.com');
        expect(json['dn'], 'TestNode');
        expect(json['sn'], 'TST');
        expect(json['hw'], 'HELTEC_V3');
        expect(json['fw'], '2.3.4');
        expect(json['ch'], 'LongFast');
      });

      test('toJson omits null optional fields', () {
        final minimal = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        final json = minimal.toJson();

        expect(json.containsKey('dn'), false);
        expect(json.containsKey('sn'), false);
        expect(json.containsKey('hw'), false);
        expect(json.containsKey('fw'), false);
        expect(json.containsKey('ch'), false);
      });

      test('fromJson round-trips correctly', () {
        final json = sighting.toJson();
        final restored = RemoteSighting.fromJson(json);

        expect(restored.nodeNum, sighting.nodeNum);
        expect(restored.timestamp, sighting.timestamp);
        expect(restored.topic, sighting.topic);
        expect(restored.brokerUri, sighting.brokerUri);
        expect(restored.displayName, sighting.displayName);
        expect(restored.shortName, sighting.shortName);
        expect(restored.hardwareModel, sighting.hardwareModel);
        expect(restored.firmwareVersion, sighting.firmwareVersion);
        expect(restored.channelContext, sighting.channelContext);
      });

      test('fromJson handles missing optional fields', () {
        final json = <String, dynamic>{
          'nn': 42,
          'ts': timestamp.millisecondsSinceEpoch,
          'tp': 'msh/test',
          'bu': 'mqtt://test',
        };
        final restored = RemoteSighting.fromJson(json);

        expect(restored.nodeNum, 42);
        expect(restored.displayName, null);
        expect(restored.shortName, null);
        expect(restored.hardwareModel, null);
        expect(restored.firmwareVersion, null);
        expect(restored.channelContext, null);
      });

      test('fromJson handles missing topic and broker gracefully', () {
        final json = <String, dynamic>{
          'nn': 42,
          'ts': timestamp.millisecondsSinceEpoch,
        };
        final restored = RemoteSighting.fromJson(json);

        expect(restored.topic, '');
        expect(restored.brokerUri, '');
      });

      test('encodeList and decodeList round-trip correctly', () {
        final sightings = [
          sighting,
          RemoteSighting(
            nodeNum: 99,
            timestamp: timestamp.add(const Duration(minutes: 5)),
            topic: 'msh/telemetry/node99',
            brokerUri: 'mqtt://broker2',
            displayName: 'Node99',
          ),
        ];

        final encoded = RemoteSighting.encodeList(sightings);
        final decoded = RemoteSighting.decodeList(encoded);

        expect(decoded.length, 2);
        expect(decoded[0].nodeNum, sightings[0].nodeNum);
        expect(decoded[0].displayName, sightings[0].displayName);
        expect(decoded[1].nodeNum, 99);
        expect(decoded[1].displayName, 'Node99');
      });
    });

    group('toRedactedJson', () {
      test('includes nodeNum and topic but not display names', () {
        final redacted = sighting.toRedactedJson();

        expect(redacted['nodeNum'], sighting.nodeNum);
        expect(redacted['topic'], sighting.topic);
        expect(redacted['broker'], sighting.brokerUri);
        expect(redacted['hasDisplayName'], true);
        expect(redacted['hasShortName'], true);
        expect(redacted['hardwareModel'], sighting.hardwareModel);
        expect(redacted['channelContext'], sighting.channelContext);
        // Display name value should not be in redacted output
        expect(redacted.containsKey('displayName'), false);
        expect(redacted.containsKey('shortName'), false);
      });

      test('reports false when names are absent', () {
        final minimal = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        final redacted = minimal.toRedactedJson();

        expect(redacted['hasDisplayName'], false);
        expect(redacted['hasShortName'], false);
      });
    });

    group('copyWith', () {
      test('returns identical copy with no arguments', () {
        final copy = sighting.copyWith();

        expect(copy.nodeNum, sighting.nodeNum);
        expect(copy.timestamp, sighting.timestamp);
        expect(copy.topic, sighting.topic);
        expect(copy.brokerUri, sighting.brokerUri);
        expect(copy.displayName, sighting.displayName);
        expect(copy.shortName, sighting.shortName);
        expect(copy.hardwareModel, sighting.hardwareModel);
        expect(copy.firmwareVersion, sighting.firmwareVersion);
        expect(copy.channelContext, sighting.channelContext);
      });

      test('overrides specified fields', () {
        final copy = sighting.copyWith(
          displayName: 'NewName',
          hardwareModel: 'RAK4631',
        );

        expect(copy.displayName, 'NewName');
        expect(copy.hardwareModel, 'RAK4631');
        // Other fields unchanged
        expect(copy.nodeNum, sighting.nodeNum);
        expect(copy.topic, sighting.topic);
        expect(copy.shortName, sighting.shortName);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        final a = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        final b = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different nodeNum produces inequality', () {
        final a = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        final b = RemoteSighting(
          nodeNum: 2,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        expect(a, isNot(equals(b)));
      });

      test('different topic produces inequality', () {
        final a = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        );
        final b = RemoteSighting(
          nodeNum: 1,
          timestamp: timestamp,
          topic: 'msh/other',
          brokerUri: 'mqtt://test',
        );
        expect(a, isNot(equals(b)));
      });
    });

    test('toString includes key fields', () {
      final s = sighting.toString();
      expect(s.contains('RemoteSighting'), true);
      expect(s.contains('TestNode'), true);
      expect(s.contains(sighting.nodeNum.toString()), true);
    });
  });

  group('RemoteSightingStats', () {
    test('empty returns zeroes', () {
      const stats = RemoteSightingStats.empty;
      expect(stats.uniqueNodes, 0);
      expect(stats.totalSightings, 0);
      expect(stats.recentSightings, 0);
      expect(stats.lastSightingAt, null);
      expect(stats.hasData, false);
      expect(stats.sightingsByTopic, isEmpty);
      expect(stats.sightingsByBroker, isEmpty);
    });

    test('fromSightings with empty list returns empty', () {
      final stats = RemoteSightingStats.fromSightings([]);
      expect(stats.uniqueNodes, 0);
      expect(stats.totalSightings, 0);
      expect(stats.hasData, false);
    });

    test('fromSightings computes unique nodes correctly', () {
      final now = DateTime.now();
      final sightings = [
        RemoteSighting(
          nodeNum: 1,
          timestamp: now,
          topic: 'msh/chat/A',
          brokerUri: 'mqtt://broker1',
        ),
        RemoteSighting(
          nodeNum: 2,
          timestamp: now,
          topic: 'msh/chat/A',
          brokerUri: 'mqtt://broker1',
        ),
        RemoteSighting(
          nodeNum: 1,
          timestamp: now.add(const Duration(minutes: 10)),
          topic: 'msh/chat/B',
          brokerUri: 'mqtt://broker1',
        ),
      ];

      final stats = RemoteSightingStats.fromSightings(sightings);

      expect(stats.uniqueNodes, 2); // node 1 and 2
      expect(stats.totalSightings, 3);
      expect(stats.hasData, true);
    });

    test('fromSightings tracks latest timestamp', () {
      final early = DateTime(2025, 1, 1);
      final late_ = DateTime(2025, 6, 15);

      final sightings = [
        RemoteSighting(
          nodeNum: 1,
          timestamp: early,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
        RemoteSighting(
          nodeNum: 2,
          timestamp: late_,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
      ];

      final stats = RemoteSightingStats.fromSightings(sightings);
      expect(stats.lastSightingAt, late_);
    });

    test('fromSightings counts recent sightings', () {
      final now = DateTime.now();
      final recent = now.subtract(const Duration(minutes: 30));
      final old = now.subtract(const Duration(hours: 2));

      final sightings = [
        RemoteSighting(
          nodeNum: 1,
          timestamp: recent,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
        RemoteSighting(
          nodeNum: 2,
          timestamp: old,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
        RemoteSighting(
          nodeNum: 3,
          timestamp: now,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
      ];

      final stats = RemoteSightingStats.fromSightings(sightings);
      expect(stats.recentSightings, 2); // recent and now, not old
    });

    test('fromSightings groups sightings by topic', () {
      final now = DateTime.now();
      final sightings = [
        RemoteSighting(
          nodeNum: 1,
          timestamp: now,
          topic: 'msh/chat/A',
          brokerUri: 'mqtt://b',
        ),
        RemoteSighting(
          nodeNum: 2,
          timestamp: now,
          topic: 'msh/chat/A',
          brokerUri: 'mqtt://b',
        ),
        RemoteSighting(
          nodeNum: 3,
          timestamp: now,
          topic: 'msh/telemetry/X',
          brokerUri: 'mqtt://b',
        ),
      ];

      final stats = RemoteSightingStats.fromSightings(sightings);
      expect(stats.sightingsByTopic['msh/chat/A'], 2);
      expect(stats.sightingsByTopic['msh/telemetry/X'], 1);
    });

    test('toJson includes all fields', () {
      final now = DateTime.now();
      final sightings = [
        RemoteSighting(
          nodeNum: 1,
          timestamp: now,
          topic: 'msh/test',
          brokerUri: 'mqtt://test',
        ),
      ];

      final stats = RemoteSightingStats.fromSightings(sightings);
      final json = stats.toJson();

      expect(json['uniqueNodes'], 1);
      expect(json['totalSightings'], 1);
      expect(json.containsKey('lastSightingAt'), true);
      expect(json.containsKey('sightingsByTopic'), true);
      expect(json.containsKey('sightingsByBroker'), true);
    });

    test('toString includes key numbers', () {
      const stats = RemoteSightingStats(
        uniqueNodes: 5,
        totalSightings: 12,
        recentSightings: 3,
      );
      final s = stats.toString();
      expect(s.contains('5'), true);
      expect(s.contains('12'), true);
      expect(s.contains('3'), true);
    });
  });

  group('constants', () {
    test('maxRemoteSightingsRetained is positive', () {
      expect(maxRemoteSightingsRetained, greaterThan(0));
    });

    test('remoteSightingCooldown is positive', () {
      expect(remoteSightingCooldown.inSeconds, greaterThan(0));
    });

    test('maxRemoteSightingsRetained has reasonable bounds', () {
      // Should be generous but not unbounded
      expect(maxRemoteSightingsRetained, greaterThanOrEqualTo(1000));
      expect(maxRemoteSightingsRetained, lessThanOrEqualTo(100000));
    });

    test('remoteSightingCooldown is at least 1 minute', () {
      expect(remoteSightingCooldown.inMinutes, greaterThanOrEqualTo(1));
    });
  });
}
