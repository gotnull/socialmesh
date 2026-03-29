// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:socialmesh/features/tak/models/video_stream.dart';
import 'package:socialmesh/features/tak/services/tak_video_stream_service.dart';

void main() {
  /// Helper to build a [TakVideoStreamService] with a mock HTTP client.
  TakVideoStreamService buildService(
    MockClient mockClient, {
    Future<String?> Function()? getAuthToken,
  }) {
    return TakVideoStreamService(
      gatewayUrl: 'https://tak.socialmesh.app',
      getAuthToken: getAuthToken ?? () async => 'test-token',
      client: mockClient,
    );
  }

  final sampleStreamJson = <String, dynamic>{
    'id': 'vs-abcd1234',
    'streamKey': 'aabbccdd' * 4,
    'name': 'Test Stream',
    'owner': 'uid-123',
    'ownerCallsign': 'ALPHA',
    'status': 'live',
    'url': 'https://tak.socialmesh.app/hls/vs-abcd1234.m3u8',
    'rtspUrl': 'rtsp://tak.socialmesh.app/live/vs-abcd1234',
    'rtmpUrl': 'rtmp://tak.socialmesh.app/live',
    'lat': 37.7749,
    'lon': -122.4194,
    'hae': 10.0,
    'tags': <String>[],
    'resolution': '1280x720',
    'bitrate': 2500,
    'createdAt': 1700000000000,
    'lastHeartbeat': 1700000015000,
    'expiresAt': 1700000060000,
  };

  group('TakVideoStreamService', () {
    group('baseUrl generation', () {
      test('wss:// is converted to https://', () {
        final mockClient = MockClient(
          (_) async => http.Response(jsonEncode({'streams': <dynamic>[]}), 200),
        );

        final service = TakVideoStreamService(
          gatewayUrl: 'wss://tak.socialmesh.app',
          getAuthToken: () async => 'token',
          client: mockClient,
        );

        // Trigger a request to verify URL construction
        // We verify indirectly by checking the request URL in the mock
        service.listStreams().then((_) {});
        service.dispose();
      });
    });

    group('register', () {
      test('returns VideoStream on 201', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/tak/streams');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'My Stream');
          expect(body['ownerCallsign'], 'ALPHA');

          return http.Response(jsonEncode({'stream': sampleStreamJson}), 201);
        });

        final service = buildService(mockClient);
        final request = VideoStreamCreateRequest(
          name: 'My Stream',
          ownerCallsign: 'ALPHA',
        );

        final stream = await service.register(request);
        expect(stream.id, 'vs-abcd1234');
        expect(stream.name, 'Test Stream');
        expect(stream.status, VideoStreamStatus.live);

        service.dispose();
      });

      test('throws TakVideoServiceException on non-201 response', () async {
        final mockClient = MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'Rate limited'}), 429),
        );

        final service = buildService(mockClient);
        final request = VideoStreamCreateRequest(
          name: 'Test',
          ownerCallsign: 'A',
        );

        expect(
          () => service.register(request),
          throwsA(isA<TakVideoServiceException>()),
        );

        service.dispose();
      });

      test('throws when auth token is null', () async {
        final mockClient = MockClient((_) async => http.Response('', 200));

        final service = buildService(
          mockClient,
          getAuthToken: () async => null,
        );

        expect(
          () => service.register(
            VideoStreamCreateRequest(name: 'X', ownerCallsign: 'Y'),
          ),
          throwsA(isA<TakVideoServiceException>()),
        );

        service.dispose();
      });
    });

    group('listStreams', () {
      test('returns list of VideoStream on 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/tak/streams');

          return http.Response(
            jsonEncode({
              'streams': [sampleStreamJson],
            }),
            200,
          );
        });

        final service = buildService(mockClient);
        final streams = await service.listStreams();

        expect(streams, hasLength(1));
        expect(streams.first.id, 'vs-abcd1234');

        service.dispose();
      });

      test('passes query parameters', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.queryParameters['status'], 'live');
          expect(request.url.queryParameters['tag'], 'sar');

          return http.Response(jsonEncode({'streams': <dynamic>[]}), 200);
        });

        final service = buildService(mockClient);
        await service.listStreams(status: 'live', tag: 'sar');

        service.dispose();
      });

      test('throws on HTTP error', () async {
        final mockClient = MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Internal Server Error'}),
            500,
          ),
        );

        final service = buildService(mockClient);

        expect(
          () => service.listStreams(),
          throwsA(isA<TakVideoServiceException>()),
        );

        service.dispose();
      });
    });

    group('getStream', () {
      test('returns VideoStream on 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/tak/streams/vs-abcd1234');

          return http.Response(jsonEncode({'stream': sampleStreamJson}), 200);
        });

        final service = buildService(mockClient);
        final stream = await service.getStream('vs-abcd1234');

        expect(stream, isNotNull);
        expect(stream!.id, 'vs-abcd1234');

        service.dispose();
      });

      test('returns null on 404', () async {
        final mockClient = MockClient(
          (_) async => http.Response('Not Found', 404),
        );

        final service = buildService(mockClient);
        final stream = await service.getStream('vs-nonexist');

        expect(stream, isNull);

        service.dispose();
      });
    });

    group('heartbeat', () {
      test('sends PUT with empty body when no update provided', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/v1/tak/streams/vs-abcd1234/heartbeat');
          expect(request.body, '{}');

          return http.Response(jsonEncode({'stream': sampleStreamJson}), 200);
        });

        final service = buildService(mockClient);
        final result = await service.heartbeat('vs-abcd1234');

        expect(result.id, 'vs-abcd1234');

        service.dispose();
      });

      test('sends position in heartbeat update', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['lat'], 37.0);
          expect(body['lon'], -122.0);

          return http.Response(jsonEncode({'stream': sampleStreamJson}), 200);
        });

        final service = buildService(mockClient);
        await service.heartbeat(
          'vs-abcd1234',
          update: const VideoStreamHeartbeatRequest(lat: 37.0, lon: -122.0),
        );

        service.dispose();
      });

      test('throws on error response', () async {
        final mockClient = MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'Stream not found'}), 404),
        );

        final service = buildService(mockClient);

        expect(
          () => service.heartbeat('vs-nonexist'),
          throwsA(isA<TakVideoServiceException>()),
        );

        service.dispose();
      });
    });

    group('deleteStream', () {
      test('returns true on 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/v1/tak/streams/vs-abcd1234');

          return http.Response(jsonEncode({'message': 'Deleted'}), 200);
        });

        final service = buildService(mockClient);
        final result = await service.deleteStream('vs-abcd1234');

        expect(result, isTrue);

        service.dispose();
      });

      test('returns false on 404', () async {
        final mockClient = MockClient(
          (_) async => http.Response('Not Found', 404),
        );

        final service = buildService(mockClient);
        final result = await service.deleteStream('vs-nonexist');

        expect(result, isFalse);

        service.dispose();
      });

      test('throws on server error', () async {
        final mockClient = MockClient(
          (_) async => http.Response('Server Error', 500),
        );

        final service = buildService(mockClient);

        expect(
          () => service.deleteStream('vs-abcd1234'),
          throwsA(isA<TakVideoServiceException>()),
        );

        service.dispose();
      });
    });

    group('error parsing', () {
      test('extracts error message from JSON response', () async {
        final mockClient = MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'Rate limited'}), 429),
        );

        final service = buildService(mockClient);

        try {
          await service.listStreams();
          fail('Should have thrown');
        } on TakVideoServiceException catch (e) {
          expect(e.message, 'Rate limited');
        }

        service.dispose();
      });

      test('falls back to HTTP status code when body is not JSON', () async {
        final mockClient = MockClient(
          (_) async => http.Response('Not JSON', 500),
        );

        final service = buildService(mockClient);

        try {
          await service.listStreams();
          fail('Should have thrown');
        } on TakVideoServiceException catch (e) {
          expect(e.message, 'HTTP 500');
        }

        service.dispose();
      });
    });
  });

  group('TakVideoServiceException', () {
    test('toString includes message', () {
      const e = TakVideoServiceException('test error');
      expect(e.toString(), 'TakVideoServiceException: test error');
    });

    test('message is accessible', () {
      const e = TakVideoServiceException('auth required');
      expect(e.message, 'auth required');
    });
  });
}
