// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/certificate_manager.dart';
import 'package:socialmesh/services/tak/data_package_builder.dart';

import 'certificate_manager_test.dart';

void main() {
  group('TakDataPackageBuilder', () {
    late TakCertificateManager certManager;
    late TakDataPackageBuilder builder;

    setUp(() async {
      certManager = TakCertificateManager(storage: FakeSecureStorage());
      await certManager.initialize();
      builder = TakDataPackageBuilder(certManager);
    });

    test('build produces valid ZIP', () async {
      final zipBytes = await builder.build(
        serverHost: '192.168.1.100',
        serverPort: 8089,
        callsign: 'ALPHA-1',
      );

      expect(zipBytes, isNotEmpty);

      // Verify ZIP structure.
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('manifest.xml'));
      expect(names, contains('certs/truststore-root.p12'));
      expect(names, contains('certs/user.p12'));
      expect(names, contains('preference.pref'));
    });

    test('manifest.xml has correct structure', () async {
      final zipBytes = await builder.build(
        serverHost: '10.0.0.1',
        serverPort: 8089,
        callsign: 'BRAVO-2',
      );

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final manifest = archive.files.firstWhere(
        (f) => f.name == 'manifest.xml',
      );
      final content = utf8.decode(manifest.content as List<int>);

      expect(content, contains('MissionPackageManifest'));
      expect(content, contains('socialmesh-tak-server'));
      expect(content, contains('truststore-root.p12'));
      expect(content, contains('user.p12'));
      expect(content, contains('preference.pref'));
    });

    test('preference.pref contains server connection', () async {
      final zipBytes = await builder.build(
        serverHost: '192.168.42.1',
        serverPort: 9090,
        callsign: 'CHARLIE-3',
      );

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final prefs = archive.files.firstWhere(
        (f) => f.name == 'preference.pref',
      );
      final content = utf8.decode(prefs.content as List<int>);

      expect(content, contains('192.168.42.1:9090:ssl'));
      expect(content, contains('CHARLIE-3'));
      expect(content, contains('preferences'));
    });

    test('certs directory contains PEM data', () async {
      final zipBytes = await builder.build(
        serverHost: '10.0.0.1',
        serverPort: 8089,
        callsign: 'TEST',
      );

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final ca = archive.files.firstWhere(
        (f) => f.name == 'certs/truststore-root.p12',
      );
      final user = archive.files.firstWhere((f) => f.name == 'certs/user.p12');

      final caPem = utf8.decode(ca.content as List<int>);
      final userPem = utf8.decode(user.content as List<int>);

      expect(caPem, contains('BEGIN CERTIFICATE'));
      expect(userPem, contains('BEGIN CERTIFICATE'));
      expect(userPem, contains('BEGIN PRIVATE KEY'));
    });
  });
}
