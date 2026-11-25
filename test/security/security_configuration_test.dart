// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MQTT TLS does not override certificate validation', () {
    final source = File('lib/services/mqtt/mqtt_client_proxy_service.dart')
        .readAsStringSync();
    expect(source, isNot(matches(RegExp(r'\.onBadCertificate\s*='))));
  });

  test('Analytics and Crashlytics start disabled until consent', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
      'FirebaseCrashlyticsCollectionEnabled',
    ]) {
      expect(
        plist,
        matches(RegExp('<key>$key</key>\\s*<false/>')),
        reason: '$key must be false so nothing is sent before opt-in',
      );
    }

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final name in [
      'firebase_analytics_collection_enabled',
      'firebase_crashlytics_collection_enabled',
    ]) {
      expect(
        manifest,
        matches(RegExp('android:name="$name"\\s*android:value="false"')),
        reason: '$name must be false so nothing is sent before opt-in',
      );
    }
  });

  test('crash reports cached while opted out are deleted', () {
    final source = File('lib/services/privacy_consent_service.dart')
        .readAsStringSync();
    expect(source, contains('deleteUnsentReports()'));
  });

  test('raw server environment is not a Flutter asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('    - .env\n')));
    expect(pubspec, contains('    - .env.client\n'));
  });
}
