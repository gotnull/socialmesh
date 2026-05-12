// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:socialmesh/core/net/safe_http_request.dart';

void main() {
  group('safeHttpRequest', () {
    test('returns HttpSuccess with decoded value on 200', () async {
      final result = await safeHttpRequest<String>(
        surface: 'unit-test',
        send: () async => http.Response('"ok"', 200),
        decode: (r) => r.body,
      );
      expect(result, isA<HttpSuccess<String>>());
      expect((result as HttpSuccess<String>).value, '"ok"');
    });

    test('SocketException -> HttpFailure(socket)', () async {
      final result = await safeHttpRequest<String>(
        surface: 'unit-test',
        send: () async => throw const SocketException('DNS failure'),
        decode: (r) => r.body,
      );
      expect(result, isA<HttpFailure<String>>());
      final failure = result as HttpFailure<String>;
      expect(failure.reason, HttpFailureReason.socket);
      expect(failure.error, isA<SocketException>());
    });

    test('http.ClientException -> HttpFailure(client)', () async {
      final result = await safeHttpRequest<String>(
        surface: 'unit-test',
        send: () async => throw http.ClientException('reset by peer'),
        decode: (r) => r.body,
      );
      expect(result, isA<HttpFailure<String>>());
      final failure = result as HttpFailure<String>;
      expect(failure.reason, HttpFailureReason.client);
      expect(failure.error, isA<http.ClientException>());
    });

    test('TimeoutException -> HttpFailure(timeout)', () async {
      final result = await safeHttpRequest<String>(
        surface: 'unit-test',
        send: () async => throw TimeoutException('slow', Duration(seconds: 1)),
        decode: (r) => r.body,
      );
      expect(result, isA<HttpFailure<String>>());
      final failure = result as HttpFailure<String>;
      expect(failure.reason, HttpFailureReason.timeout);
      expect(failure.error, isA<TimeoutException>());
    });

    test(
      'unrelated exceptions are NOT swallowed (e.g. decode failure rethrows)',
      () async {
        expect(
          () => safeHttpRequest<int>(
            surface: 'unit-test',
            send: () async => http.Response('not-a-number', 200),
            decode: (r) => int.parse(r.body),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'non-2xx response still reaches decode (status handling is caller policy)',
      () async {
        final result = await safeHttpRequest<int>(
          surface: 'unit-test',
          send: () async => http.Response('error', 500),
          decode: (r) => r.statusCode,
        );
        expect(result, isA<HttpSuccess<int>>());
        expect((result as HttpSuccess<int>).value, 500);
      },
    );
  });
}
