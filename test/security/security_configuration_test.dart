// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MQTT TLS does not override certificate validation', () {
    final source = File(
      'lib/services/mqtt/mqtt_client_proxy_service.dart',
    ).readAsStringSync();
    expect(source, isNot(matches(RegExp(r'\.onBadCertificate\s*='))));
  });

  test('raw server environment is not a Flutter asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('    - .env\n')));
    expect(pubspec, contains('    - .env.client\n'));
  });
}
