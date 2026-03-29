// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tak/models/video_stream.dart';

void main() {
  final sampleJson = <String, dynamic>{
    'id': 'vs-abcd1234',
    'streamKey': 'aabbccdd' * 4,
    'name': 'My Test Stream',
    'owner': 'uid-123',
    'ownerCallsign': 'ALPHA',
    'status': 'live',
    'url': 'https://tak.socialmesh.app/hls/vs-abcd1234.m3u8',
    'rtspUrl': 'rtsp://tak.socialmesh.app/live/vs-abcd1234',
    'rtmpUrl': 'rtmp://tak.socialmesh.app/live',
    'lat': 37.7749,
    'lon': -122.4194,
    'hae': 10.0,
    'tags': ['test', 'sar'],
    'resolution': '1280x720',
    'bitrate': 2500,
    'createdAt': 1700000000000,
    'lastHeartbeat': 1700000015000,
    'expiresAt': 1700000060000,
  };

  group('VideoStream', () {
    test('fromJson parses all fields', () {
      final stream = VideoStream.fromJson(sampleJson);

      expect(stream.id, 'vs-abcd1234');
      expect(stream.streamKey, 'aabbccdd' * 4);
      expect(stream.name, 'My Test Stream');
      expect(stream.owner, 'uid-123');
      expect(stream.ownerCallsign, 'ALPHA');
      expect(stream.status, VideoStreamStatus.live);
      expect(stream.url, 'https://tak.socialmesh.app/hls/vs-abcd1234.m3u8');
      expect(stream.rtspUrl, 'rtsp://tak.socialmesh.app/live/vs-abcd1234');
      expect(stream.rtmpUrl, 'rtmp://tak.socialmesh.app/live');
      expect(stream.lat, 37.7749);
      expect(stream.lon, -122.4194);
      expect(stream.hae, 10.0);
      expect(stream.tags, ['test', 'sar']);
      expect(stream.resolution, '1280x720');
      expect(stream.bitrate, 2500);
      expect(stream.createdAt, 1700000000000);
      expect(stream.lastHeartbeat, 1700000015000);
      expect(stream.expiresAt, 1700000060000);
    });

    test('fromJson handles missing optional fields', () {
      final minimal = <String, dynamic>{
        'id': 'vs-00000000',
        'name': 'Minimal Stream',
        'owner': 'uid-000',
        'ownerCallsign': 'BRAVO',
        'status': 'offline',
        'url': 'https://example.com/hls/test.m3u8',
        'createdAt': 1700000000000,
        'lastHeartbeat': 1700000000000,
        'expiresAt': 1700000060000,
      };

      final stream = VideoStream.fromJson(minimal);

      expect(stream.streamKey, '');
      expect(stream.rtspUrl, '');
      expect(stream.rtmpUrl, '');
      expect(stream.lat, isNull);
      expect(stream.lon, isNull);
      expect(stream.hae, isNull);
      expect(stream.tags, isEmpty);
      expect(stream.resolution, isNull);
      expect(stream.bitrate, isNull);
    });

    test('toJson produces correct map', () {
      final stream = VideoStream.fromJson(sampleJson);
      final json = stream.toJson();

      expect(json['id'], 'vs-abcd1234');
      expect(json['streamKey'], 'aabbccdd' * 4);
      expect(json['name'], 'My Test Stream');
      expect(json['status'], 'live');
      expect(json['tags'], ['test', 'sar']);
      expect(json['lat'], 37.7749);
      expect(json['lon'], -122.4194);
      expect(json['bitrate'], 2500);
    });

    test('toJson round-trips through fromJson', () {
      final original = VideoStream.fromJson(sampleJson);
      final roundTripped = VideoStream.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.status, original.status);
      expect(roundTripped.lat, original.lat);
      expect(roundTripped.lon, original.lon);
      expect(roundTripped.tags, original.tags);
    });

    test('equality based on id, status, lastHeartbeat', () {
      final a = VideoStream.fromJson(sampleJson);
      final b = VideoStream.fromJson(sampleJson);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when status differs', () {
      final a = VideoStream.fromJson(sampleJson);
      final modified = Map<String, dynamic>.from(sampleJson)
        ..['status'] = 'offline';
      final b = VideoStream.fromJson(modified);

      expect(a, isNot(equals(b)));
    });

    test('hasPosition returns true when lat and lon present', () {
      final stream = VideoStream.fromJson(sampleJson);
      expect(stream.hasPosition, isTrue);
    });

    test('hasPosition returns false when lat is null', () {
      final noLat = Map<String, dynamic>.from(sampleJson)..['lat'] = null;
      final stream = VideoStream.fromJson(noLat);
      expect(stream.hasPosition, isFalse);
    });

    test('isExpired returns true for past expiry', () {
      final expired = Map<String, dynamic>.from(sampleJson)..['expiresAt'] = 0;
      final stream = VideoStream.fromJson(expired);
      expect(stream.isExpired, isTrue);
    });

    test('isExpired returns false for future expiry', () {
      final future = Map<String, dynamic>.from(
        sampleJson,
      )..['expiresAt'] = DateTime.now().millisecondsSinceEpoch + 60 * 60 * 1000;
      final stream = VideoStream.fromJson(future);
      expect(stream.isExpired, isFalse);
    });

    test('toString contains key info', () {
      final stream = VideoStream.fromJson(sampleJson);
      final str = stream.toString();

      expect(str, contains('vs-abcd1234'));
      expect(str, contains('My Test Stream'));
      expect(str, contains('live'));
    });
  });

  group('VideoStreamStatus', () {
    test('fromString parses known values', () {
      expect(VideoStreamStatus.fromString('live'), VideoStreamStatus.live);
      expect(
        VideoStreamStatus.fromString('offline'),
        VideoStreamStatus.offline,
      );
      expect(VideoStreamStatus.fromString('error'), VideoStreamStatus.error);
    });

    test('fromString defaults to offline for unknown values', () {
      expect(
        VideoStreamStatus.fromString('unknown'),
        VideoStreamStatus.offline,
      );
      expect(VideoStreamStatus.fromString(''), VideoStreamStatus.offline);
    });
  });

  group('VideoStreamCreateRequest', () {
    test('toJson includes required fields', () {
      final request = VideoStreamCreateRequest(
        name: 'Test',
        ownerCallsign: 'ALPHA',
      );
      final json = request.toJson();

      expect(json['name'], 'Test');
      expect(json['ownerCallsign'], 'ALPHA');
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lon'), isFalse);
      expect(json.containsKey('tags'), isFalse);
    });

    test('toJson includes optional fields when present', () {
      final request = VideoStreamCreateRequest(
        name: 'Test',
        ownerCallsign: 'ALPHA',
        lat: 37.0,
        lon: -122.0,
        hae: 5.0,
        tags: ['tag1'],
        resolution: '720p',
        bitrate: 1000,
      );
      final json = request.toJson();

      expect(json['lat'], 37.0);
      expect(json['lon'], -122.0);
      expect(json['hae'], 5.0);
      expect(json['tags'], ['tag1']);
      expect(json['resolution'], '720p');
      expect(json['bitrate'], 1000);
    });

    test('toJson excludes empty tags list', () {
      final request = VideoStreamCreateRequest(
        name: 'Test',
        ownerCallsign: 'ALPHA',
        tags: [],
      );
      final json = request.toJson();
      expect(json.containsKey('tags'), isFalse);
    });
  });

  group('VideoStreamHeartbeatRequest', () {
    test('toJson with no fields produces empty map', () {
      const request = VideoStreamHeartbeatRequest();
      expect(request.toJson(), isEmpty);
    });

    test('toJson includes position when present', () {
      const request = VideoStreamHeartbeatRequest(
        lat: 37.0,
        lon: -122.0,
        hae: 10.0,
      );
      final json = request.toJson();

      expect(json['lat'], 37.0);
      expect(json['lon'], -122.0);
      expect(json['hae'], 10.0);
    });

    test('toJson excludes null fields', () {
      const request = VideoStreamHeartbeatRequest(lat: 37.0);
      final json = request.toJson();

      expect(json.containsKey('lat'), isTrue);
      expect(json.containsKey('lon'), isFalse);
      expect(json.containsKey('hae'), isFalse);
    });
  });
}
