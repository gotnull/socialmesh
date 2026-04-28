// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/rns_companion_providers.dart';
import 'package:socialmesh/services/rns_companion/rns_companion_client.dart';

/// Subscribes to [provider] and returns a Future that completes with
/// the first AsyncValue carrying data or error. Avoids the
/// "disposed during loading state" StateError that family /
/// auto-disposing FutureProviders raise from `.future` when no
/// keep-alive listener is active.
Future<AsyncValue<T>> _waitForResolution<T>(
  ProviderContainer c,
  FutureProvider<T> provider,
) {
  final completer = Completer<AsyncValue<T>>();
  c.listen<AsyncValue<T>>(provider, (prev, next) {
    if ((next.hasValue || next.hasError) && !completer.isCompleted) {
      completer.complete(next);
    }
  }, fireImmediately: true);
  return completer.future;
}

ProviderContainer _container({required RnsCompanionClient client}) {
  final c = ProviderContainer(
    overrides: [rnsCompanionClientProvider.overrideWithValue(client)],
  );
  addTearDown(c.dispose);
  return c;
}

RnsCompanionClient _clientFor(MockClient mock) =>
    RnsCompanionClient(httpClient: mock);

void main() {
  group('rnsCompanionServicesProvider', () {
    test('returns parsed services from a fake client', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode([
            <String, dynamic>{
              'destination': 'd1',
              'name': 'svc',
              'type': 'nomadnet',
              'lastSeen': 1,
            },
          ]),
          200,
        ),
      );
      final c = _container(client: _clientFor(mock));
      final services = await c.read(rnsCompanionServicesProvider.future);
      expect(services, hasLength(1));
      expect(services.single.destination, 'd1');
    });

    test('connection error propagates as AsyncError on the provider', () async {
      final mock = MockClient(
        (_) async => throw http.ClientException('refused'),
      );
      final c = _container(client: _clientFor(mock));
      final result = await _waitForResolution(c, rnsCompanionServicesProvider);
      expect(result.hasError, isTrue);
      expect(result.error, isA<RnsCompanionConnectionError>());
    });
  });

  group('rnsCompanionPagesProvider(family)', () {
    test('returns parsed pages for a destination', () async {
      final mock = MockClient(
        (req) async => http.Response(
          jsonEncode([
            <String, dynamic>{'pageId': 'p1', 'title': 'Page', 'updatedAt': 42},
          ]),
          200,
        ),
      );
      final c = _container(client: _clientFor(mock));
      final pages = await c.read(rnsCompanionPagesProvider('dst').future);
      expect(pages.single.pageId, 'p1');
      expect(pages.single.updatedAt, 42);
    });
  });

  group('rnsCompanionPageProvider(family)', () {
    test('returns the body for (destination, pageId)', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'pageId': 'p1',
            'title': 'Page',
            'body': 'Hello',
            'updatedAt': 42,
          }),
          200,
        ),
      );
      final c = _container(client: _clientFor(mock));
      final page = await c.read(
        rnsCompanionPageProvider((destination: 'dst', pageId: 'p1')).future,
      );
      expect(page.body, 'Hello');
    });

    test('404 propagates as RnsCompanionNotFoundError', () async {
      final mock = MockClient((_) async => http.Response('', 404));
      final c = _container(client: _clientFor(mock));
      final pp = rnsCompanionPageProvider((destination: 'dst', pageId: 'nope'));
      final result = await _waitForResolution(c, pp);
      expect(result.hasError, isTrue);
      expect(result.error, isA<RnsCompanionNotFoundError>());
    });
  });

  group('rnsCompanionBaseUrlProvider', () {
    test('default value matches kRnsCompanionDefaultBaseUrl', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(rnsCompanionBaseUrlProvider), kRnsCompanionDefaultBaseUrl);
    });

    test('override is honored by the client provider', () {
      final c = ProviderContainer(
        overrides: [
          rnsCompanionBaseUrlProvider.overrideWithValue(
            'http://other.local:9999',
          ),
        ],
      );
      addTearDown(c.dispose);
      final client = c.read(rnsCompanionClientProvider);
      expect(client.baseUri.host, 'other.local');
      expect(client.baseUri.port, 9999);
    });
  });

  group('rnsCompanionEndpointProvider — persisted host/port', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('default host and port match the codebase constants', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ep = c.read(rnsCompanionEndpointProvider);
      expect(ep.host, kRnsCompanionDefaultHost);
      expect(ep.port, kRnsCompanionDefaultPort);
    });

    test('loads persisted values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'rnsCompanion.host': '10.0.0.42',
        'rnsCompanion.port': 1337,
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      // Read once to build, then await the microtask-driven prefs load.
      c.read(rnsCompanionEndpointProvider);
      await Future<void>.delayed(Duration.zero);
      final ep = c.read(rnsCompanionEndpointProvider);
      expect(ep.host, '10.0.0.42');
      expect(ep.port, 1337);
    });

    test('setEndpoint persists and updates baseUrl', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c
          .read(rnsCompanionEndpointProvider.notifier)
          .setEndpoint('192.168.1.50', 8888);

      final ep = c.read(rnsCompanionEndpointProvider);
      expect(ep.host, '192.168.1.50');
      expect(ep.port, 8888);
      expect(c.read(rnsCompanionBaseUrlProvider), 'http://192.168.1.50:8888');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rnsCompanion.host'), '192.168.1.50');
      expect(prefs.getInt('rnsCompanion.port'), 8888);
    });
  });
}
