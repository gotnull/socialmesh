// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/settings/mqtt_topics/mqtt_root_topic.dart';
import 'package:socialmesh/features/settings/mqtt_topics/mqtt_topic_discovery.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as mesh_pb;
import 'package:socialmesh/generated/meshtastic/mqtt.pb.dart' as mqtt_pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart';

Uint8List _packetEnvelope({required int from}) => mqtt_pb.ServiceEnvelope(
  packet: mesh_pb.MeshPacket(from: from),
  channelId: 'LongFast',
  gatewayId: '!0a0b0c0d',
).writeToBuffer();

Uint8List _mapReportEnvelope({
  required String gateway,
  required double lat,
  required double lon,
  int online = 0,
}) => mqtt_pb.ServiceEnvelope(
  gatewayId: gateway,
  packet: mesh_pb.MeshPacket(
    from: 0x11223344,
    decoded: mesh_pb.Data(
      portnum: PortNum.MAP_REPORT_APP,
      payload: mqtt_pb.MapReport(
        longName: 'Coburg Hill',
        latitudeI: (lat * 1e7).round(),
        longitudeI: (lon * 1e7).round(),
        numOnlineLocalNodes: online,
      ).writeToBuffer(),
    ),
  ),
).writeToBuffer();

void main() {
  group('root topic rules', () {
    test('accepts ordinary roots and the 31-byte maximum', () {
      expect(mqttRootTopicProblem('msh'), isNull);
      expect(mqttRootTopicProblem('msh/ANZ/VIC/coburg'), isNull);
      expect(mqttRootTopicProblem('m' * 31), isNull);
    });

    test('reports the first rule broken', () {
      expect(mqttRootTopicProblem(''), MqttRootTopicProblem.empty);
      expect(mqttRootTopicProblem('msh/AN Z'), MqttRootTopicProblem.whitespace);
      expect(
        mqttRootTopicProblem('msh/münchen'),
        MqttRootTopicProblem.nonAscii,
      );
      expect(mqttRootTopicProblem('msh/+'), MqttRootTopicProblem.wildcard);
      expect(mqttRootTopicProblem('msh/#'), MqttRootTopicProblem.wildcard);
      expect(mqttRootTopicProblem('/msh'), MqttRootTopicProblem.leadingSlash);
      expect(mqttRootTopicProblem('msh/'), MqttRootTopicProblem.trailingSlash);
      expect(
        mqttRootTopicProblem('msh//ANZ'),
        MqttRootTopicProblem.emptySegment,
      );
      expect(
        mqttRootTopicProblem('msh/ANZ/2'),
        MqttRootTopicProblem.endsWithVersion,
      );
      expect(mqttRootTopicProblem('m' * 32), MqttRootTopicProblem.tooLong);
    });

    test('sanitising trims, collapses slashes and drops one trailing', () {
      expect(sanitizeMqttRootTopic('  msh//ANZ///VIC/ '), 'msh/ANZ/VIC');
    });

    test('prefix matching is segment-wise and case-insensitive', () {
      expect(mqttRootHasPrefix('msh/ANZ/VIC/coburg', 'msh/anz/vic'), isTrue);
      expect(mqttRootHasPrefix('msh/ANZ/VICX', 'msh/ANZ/VIC'), isFalse);
      expect(mqttRootHasPrefix('msh/ANZ', 'msh/ANZ/VIC'), isFalse);
    });
  });

  group('topic parsing', () {
    test('packet and map topics give their root', () {
      final packet = parseMqttTopic('msh/ANZ/VIC/2/e/LongFast/!0a0b0c0d')!;
      expect(packet.root, 'msh/ANZ/VIC');
      final kind = packet.kind as MqttPacketTopic;
      expect(kind.channel, 'LongFast');
      expect(kind.gateway, '!0a0b0c0d');
      final map = parseMqttTopic('msh/ANZ/2/map/')!;
      expect(map.root, 'msh/ANZ');
      expect(map.kind, isA<MqttMapReportTopic>());
    });

    test('junk, other versions and foreign roots are ignored', () {
      expect(parseMqttTopic('msh/ANZ/2/e/LongFast/!0A0B0C0D'), isNull);
      expect(parseMqttTopic('msh/ANZ/1/c/LongFast/!0a0b0c0d'), isNull);
      expect(parseMqttTopic('msh/ANZ/2/json/LongFast/!0a0b0c0d'), isNull);
      expect(parseMqttTopic('other/ANZ/2/map/'), isNull);
    });

    test('stray spaces and doubled slashes credit the saveable spelling', () {
      expect(parseMqttTopic(' msh/ANZ //2/map/')!.root, 'msh/ANZ');
    });
  });

  group('ladder', () {
    test('region, state and lowercase city', () {
      final ladder = mqttTopicLadder(
        regionTopic: 'msh/ANZ',
        regionName: 'Australia/NZ',
        state: 'VIC',
        city: 'Coburg',
      );
      expect(ladder.map((r) => r.topic), [
        'msh/ANZ',
        'msh/ANZ/VIC',
        'msh/ANZ/VIC/coburg',
      ]);
      expect(ladder.last.placeName, 'Coburg');
    });

    test('a long city is trimmed to the byte cap', () {
      final ladder = mqttTopicLadder(
        regionTopic: 'msh/ANZ',
        regionName: 'Australia/NZ',
        state: 'NSW',
        city: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
      );
      expect(ladder.last.topic.length, kMqttRootTopicByteCap);
      expect(mqttRootTopicProblem(ladder.last.topic), isNull);
    });

    test('a non-Latin state drops itself and the city', () {
      final ladder = mqttTopicLadder(
        regionTopic: 'msh/JP',
        regionName: 'Japan',
        state: '東京都',
        city: 'Shibuya',
      );
      expect(ladder.map((r) => r.topic), ['msh/JP']);
    });

    test('place names fold Latin diacritics and drop punctuation', () {
      expect(mqttTopicSegmentFromPlace('München', lowercase: true), 'munchen');
      expect(
        mqttTopicSegmentFromPlace("St. John's", lowercase: true),
        'stjohns',
      );
      expect(mqttTopicSegmentFromPlace('Kraków', lowercase: false), 'Krakow');
      expect(mqttTopicSegmentFromPlace('東京都', lowercase: true), isNull);
    });
  });

  group('tally', () {
    test('packets count gateways, senders and channels', () {
      final tally = MqttTopicTally();
      tally.record(
        'msh/ANZ/VIC/2/e/LongFast/!0a0b0c0d',
        _packetEnvelope(from: 0x55667788),
      );
      final activity = tally.activity['msh/ANZ/VIC']!;
      expect(activity.packets, 1);
      expect(activity.nodes, {'!0a0b0c0d', '!55667788'});
      expect(activity.channels, {'LongFast'});
    });

    test('map reports record the reporter, position and local nodes', () {
      final tally = MqttTopicTally();
      tally.record(
        'msh/ANZ/VIC/2/map/',
        _mapReportEnvelope(gateway: '!aa', lat: -37.74, lon: 144.96, online: 7),
      );
      final activity = tally.activity['msh/ANZ/VIC']!;
      expect(activity.mapReports, 1);
      expect(activity.positions['!aa']!.latitude, closeTo(-37.74, 1e-6));
      expect(activity.onlineLocalNodes, 7);
      expect(
        activity.nearestDistance(const LatLng(-37.74, 144.96)),
        closeTo(0, 1),
      );
    });

    test('a new root past the cap is counted as dropped', () {
      final tally = MqttTopicTally();
      for (var i = 0; i < MqttTopicTally.maxRoots; i++) {
        tally.record('msh/ANZ/r$i/2/map/', Uint8List(0));
      }
      tally.record('msh/ANZ/extra/2/map/', Uint8List(0));
      expect(tally.activity.length, MqttTopicTally.maxRoots);
      expect(tally.droppedRoots, 1);
    });

    test('a payload that is not an envelope still counts the topic', () {
      final tally = MqttTopicTally();
      tally.record(
        'msh/ANZ/2/e/LongFast/!0a0b0c0d',
        Uint8List.fromList([0xFF, 0xFF, 0xFF]),
      );
      expect(tally.activity['msh/ANZ']!.nodes, {'!0a0b0c0d'});
    });
  });

  group('ranking', () {
    MqttRootActivity activity({int nodes = 0, LatLng? at}) {
      final a = MqttRootActivity();
      for (var i = 0; i < nodes; i++) {
        a.nodes.add('!$i');
      }
      if (at != null) a.positions['!p'] = at;
      return a;
    }

    test('ladder depth, then distance, then node count, then name', () {
      final ladder = mqttTopicLadder(
        regionTopic: 'msh/ANZ',
        regionName: 'Australia/NZ',
        state: 'VIC',
      );
      const here = LatLng(-37.74, 144.96);
      final ranked = rankMqttRoots(
        {
          'msh/ANZ': activity(nodes: 99),
          'msh/ANZ/NSW': activity(nodes: 50),
          'msh/ANZ/VIC/bendigo': activity(
            nodes: 2,
            at: const LatLng(-36.76, 144.28),
          ),
          'msh/ANZ/VIC/coburg': activity(nodes: 1, at: here),
          'msh/ANZ/QLD': activity(nodes: 50),
          'msh/ANZ/bad/2': activity(nodes: 500),
        },
        ladder: ladder,
        from: here,
      );
      expect(ranked.map((r) => r.root), [
        'msh/ANZ/VIC/coburg',
        'msh/ANZ/VIC/bendigo',
        'msh/ANZ/NSW',
        'msh/ANZ/QLD',
      ]);
    });

    test('a rung shows the broker spelling when its own is absent', () {
      const rung = MqttLadderRung(
        level: MqttLadderLevel.city,
        topic: 'msh/ANZ/VIC/coburg',
        placeName: 'Coburg',
      );
      final live = mqttActivityForRung(rung, {
        'msh/ANZ/VIC/Coburg': MqttRootActivity(),
      });
      expect(live!.topic, 'msh/ANZ/VIC/Coburg');
    });
  });
}
