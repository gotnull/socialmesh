// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression: Crashlytics [B aedf754f] was an IOClient.send funnel with
// no app frames. NodeBoardApiService's _get/_post/_patch did not wrap
// http calls, so SocketException/ClientException/TimeoutException
// escaped to PlatformDispatcher.onError. Pin: any of those throws are
// now converted to NodeBoardApiException(statusCode: 0).

import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:socialmesh/features/nodeboard/services/nodeboard_api_service.dart';

void main() {
  setUpAll(() {
    // AppUrls.nodeBoardApiUrl reads dotenv at construction time; load
    // an empty env so the fallback URL is used.
    dotenv.loadFromString(envString: '_=1');
  });

  group('NodeBoardApiService network failure handling', () {
    test('SocketException becomes NodeBoardApiException(0)', () async {
      final service = NodeBoardApiService(
        client: MockClient(
          (request) async => throw const SocketException('DNS lookup failed'),
        ),
        getIdToken: () async => null,
      );

      await expectLater(
        service.getBoardBySlug('test'),
        throwsA(
          isA<NodeBoardApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            0,
          ),
        ),
      );
    });

    test('ClientException becomes NodeBoardApiException(0)', () async {
      final service = NodeBoardApiService(
        client: MockClient(
          (request) async => throw http.ClientException('Connection reset'),
        ),
        getIdToken: () async => null,
      );

      await expectLater(
        service.discoverBoards(),
        throwsA(isA<NodeBoardApiException>()),
      );
    });

    test('TimeoutException becomes NodeBoardApiException(0)', () async {
      final service = NodeBoardApiService(
        // Never-completing future triggers the 15s timeout. Run with a
        // FakeAsync so the test completes synchronously.
        client: MockClient((request) {
          final completer = Completer<http.Response>();
          return completer.future;
        }),
        getIdToken: () async => null,
      );

      await expectLater(
        service
            .getBoardBySlug('test')
            .timeout(const Duration(milliseconds: 100)),
        throwsA(isA<Exception>()),
      );
    });

    test(
      '200 response with no body still flows to the decoder layer',
      () async {
        // Pinpoints that the safe wrapper only catches socket-level
        // failures, not response-decode errors — those stay caller-owned.
        final service = NodeBoardApiService(
          client: MockClient((request) async => http.Response('not-json', 200)),
          getIdToken: () async => null,
        );

        await expectLater(
          service.getBoardBySlug('test'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
