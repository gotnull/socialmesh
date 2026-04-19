// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/tak/certificate_manager.dart';

/// In-memory stub for [FlutterSecureStorage] used in tests.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.remove(key);

  /// Exposes stored keys for test assertions.
  Set<String> get keys => _store.keys.toSet();
}

void main() {
  late FakeSecureStorage storage;
  late TakCertificateManager manager;

  setUp(() {
    storage = FakeSecureStorage();
    manager = TakCertificateManager(storage: storage);
  });

  group('TakCertificateManager', () {
    test(
      'initialize generates root CA and server cert on fresh storage',
      () async {
        await manager.initialize();

        // CA cert and key should be stored
        expect(storage.keys, contains('tak_ca_cert_pem'));
        expect(storage.keys, contains('tak_ca_key_pem'));
        // Server cert and key should be stored
        expect(storage.keys, contains('tak_server_cert_pem'));
        expect(storage.keys, contains('tak_server_key_pem'));
      },
    );

    test('initialize loads existing certs without regenerating', () async {
      // First init generates
      await manager.initialize();
      final caPem = await manager.getCaCertificatePem();

      // Second init on a new manager with same storage should load, not regenerate
      final manager2 = TakCertificateManager(storage: storage);
      await manager2.initialize();
      final caPem2 = await manager2.getCaCertificatePem();

      expect(caPem2, caPem);
    });

    test('getCaCertificatePem returns valid PEM', () async {
      await manager.initialize();
      final pem = await manager.getCaCertificatePem();

      expect(pem, startsWith('-----BEGIN CERTIFICATE-----'));
      expect(pem, endsWith('-----END CERTIFICATE-----'));
    });

    test('getCaPrivateKeyPem returns valid PEM', () async {
      await manager.initialize();
      final pem = await manager.getCaPrivateKeyPem();

      expect(pem, startsWith('-----BEGIN PRIVATE KEY-----'));
      expect(pem, endsWith('-----END PRIVATE KEY-----'));
    });

    test('getServerCertificateAndKey returns valid PEM pair', () async {
      await manager.initialize();
      final serverCreds = await manager.getServerCertificateAndKey();

      expect(serverCreds.certPem, startsWith('-----BEGIN CERTIFICATE-----'));
      expect(serverCreds.keyPem, startsWith('-----BEGIN PRIVATE KEY-----'));
    });

    test('getCaCertificatePem throws before initialize', () async {
      expect(() => manager.getCaCertificatePem(), throwsA(isA<StateError>()));
    });

    test('getServerCertificateAndKey throws before initialize', () async {
      expect(
        () => manager.getServerCertificateAndKey(),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'generateClientCertificate produces different cert than server',
      () async {
        await manager.initialize();
        final client = await manager.generateClientCertificate('ALPHA-1');

        expect(client.certPem, startsWith('-----BEGIN CERTIFICATE-----'));
        expect(client.keyPem, startsWith('-----BEGIN PRIVATE KEY-----'));

        // Server cert should differ from client cert
        final server = await manager.getServerCertificateAndKey();
        expect(client.certPem, isNot(server.certPem));
        expect(client.keyPem, isNot(server.keyPem));
      },
    );

    test(
      'generateClientCertificate produces unique certs per callsign',
      () async {
        await manager.initialize();
        final alpha = await manager.generateClientCertificate('ALPHA-1');
        final bravo = await manager.generateClientCertificate('BRAVO-2');

        expect(alpha.certPem, isNot(bravo.certPem));
        expect(alpha.keyPem, isNot(bravo.keyPem));
      },
    );

    test('clear removes all certs from storage', () async {
      await manager.initialize();
      expect(storage.keys, isNotEmpty);

      await manager.clear();
      expect(storage.keys, isEmpty);
    });

    test('clear followed by getCaCertificatePem throws', () async {
      await manager.initialize();
      await manager.clear();

      expect(() => manager.getCaCertificatePem(), throwsA(isA<StateError>()));
    });

    test('checkAndRenew does not regenerate when expiry is far', () async {
      await manager.initialize();
      final pem = await manager.getCaCertificatePem();

      await manager.checkAndRenew();
      final pemAfter = await manager.getCaCertificatePem();

      expect(pemAfter, pem);
    });

    test('CA cert PEM lines are <= 64 chars wide', () async {
      await manager.initialize();
      final pem = await manager.getCaCertificatePem();
      final lines = pem.split('\n');
      for (final line in lines) {
        if (line.startsWith('-----')) continue;
        expect(line.length, lessThanOrEqualTo(65)); // 64 + possible \r
      }
    });
  });
}
