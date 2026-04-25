// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:socialmesh/services/rns_companion/rns_companion_client.dart';

RnsCompanionClient _client(MockClient mock) {
  return RnsCompanionClient(httpClient: mock);
}

void main() {
  group('RnsCompanionClient — happy path parsing', () {
    test('listServices parses the stub response shape', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/services');
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'destination': '8f3ac21bdeadbeef0001',
              'name': 'Field Ops Board',
              'type': 'nomadnet',
              'lastSeen': 1714040000,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final services = await _client(mock).listServices();
      expect(services, hasLength(1));
      expect(services[0].destination, '8f3ac21bdeadbeef0001');
      expect(services[0].name, 'Field Ops Board');
      expect(services[0].type, 'nomadnet');
      expect(services[0].lastSeen, 1714040000);
    });

    test('listPages parses the stub response shape', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/services/abc/pages');
        return http.Response(
          jsonEncode([
            <String, dynamic>{
              'pageId': 'welcome',
              'title': 'Welcome',
              'updatedAt': 1714040000,
            },
          ]),
          200,
        );
      });
      final pages = await _client(mock).listPages('abc');
      expect(pages, hasLength(1));
      expect(pages.single.pageId, 'welcome');
      expect(pages.single.title, 'Welcome');
      expect(pages.single.updatedAt, 1714040000);
    });

    test('getPage parses the stub response shape', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/services/abc/pages/welcome');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'pageId': 'welcome',
            'title': 'Welcome',
            'body': 'Body text',
            'updatedAt': 1714040000,
          }),
          200,
        );
      });
      final page = await _client(mock).getPage('abc', 'welcome');
      expect(page.pageId, 'welcome');
      expect(page.title, 'Welcome');
      expect(page.body, 'Body text');
      expect(page.updatedAt, 1714040000);
    });

    test('getHealth parses the stub response shape', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/health');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'ok': true,
            'service': 'rns_companion',
            'version': '0.1',
            'mode': 'stub',
          }),
          200,
        );
      });
      final h = await _client(mock).getHealth();
      expect(h.ok, isTrue);
      expect(h.service, 'rns_companion');
      expect(h.version, '0.1');
      expect(h.mode, 'stub');
    });

    test('getHealth tolerates missing mode field (older companion)', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'ok': true,
            'service': 'rns_companion',
            'version': '0.1',
          }),
          200,
        ),
      );
      final h = await _client(mock).getHealth();
      expect(h.mode, 'unknown');
    });

    test('getHealth recognises live mode', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'ok': true,
            'service': 'rns_companion',
            'version': '0.1',
            'mode': 'live',
          }),
          200,
        ),
      );
      final h = await _client(mock).getHealth();
      expect(h.mode, 'live');
    });
  });

  group('RnsCompanionClient — error mapping', () {
    test('404 maps to RnsCompanionNotFoundError', () async {
      final mock = MockClient((_) async => http.Response('not found', 404));
      expect(
        () => _client(mock).getPage('unknown', 'nope'),
        throwsA(isA<RnsCompanionNotFoundError>()),
      );
    });

    test('malformed JSON maps to RnsCompanionParseError', () async {
      final mock = MockClient((_) async => http.Response('not json {{', 200));
      expect(
        () => _client(mock).listServices(),
        throwsA(isA<RnsCompanionParseError>()),
      );
    });

    test(
      'JSON object instead of array maps to RnsCompanionParseError on listServices',
      () async {
        final mock = MockClient((_) async => http.Response('{"foo": 1}', 200));
        expect(
          () => _client(mock).listServices(),
          throwsA(isA<RnsCompanionParseError>()),
        );
      },
    );

    test('SocketException maps to RnsCompanionConnectionError', () async {
      final mock = MockClient(
        (_) async => throw const SocketException('connection refused'),
      );
      expect(
        () => _client(mock).listServices(),
        throwsA(isA<RnsCompanionConnectionError>()),
      );
    });

    test('http.ClientException maps to RnsCompanionConnectionError', () async {
      final mock = MockClient((_) async => throw http.ClientException('boom'));
      expect(
        () => _client(mock).listServices(),
        throwsA(isA<RnsCompanionConnectionError>()),
      );
    });

    test('TimeoutException maps to RnsCompanionTimeoutError', () async {
      // Build a mock that never returns; use a tiny timeout in the
      // client to force the await to time out.
      final never = Completer<http.Response>();
      addTearDown(() {
        if (!never.isCompleted) {
          never.complete(http.Response('', 200));
        }
      });
      final mock = MockClient((_) => never.future);
      final client = RnsCompanionClient(
        httpClient: mock,
        timeout: const Duration(milliseconds: 50),
      );
      expect(
        () => client.listServices(),
        throwsA(isA<RnsCompanionTimeoutError>()),
      );
    });

    test('non-200/404 maps to RnsCompanionServerError', () async {
      final mock = MockClient((_) async => http.Response('bad gateway', 502));
      expect(
        () => _client(mock).listServices(),
        throwsA(
          isA<RnsCompanionServerError>().having(
            (e) => e.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });
  });

  group('RnsCompanionClient — base URI', () {
    test('respects an injected baseUri', () async {
      final captured = <Uri>[];
      final mock = MockClient((req) async {
        captured.add(req.url);
        return http.Response('[]', 200);
      });
      final client = RnsCompanionClient(
        baseUri: Uri.parse('http://10.0.0.1:9000'),
        httpClient: mock,
      );
      await client.listServices();
      expect(captured.single.host, '10.0.0.1');
      expect(captured.single.port, 9000);
      expect(captured.single.path, '/services');
    });
  });
}
