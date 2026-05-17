// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q6: `buildMeshCoreDiagnosticsPayload` + redaction-helper pins.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/diagnostics/meshcore_diagnostics_bundle.dart';

Map<String, dynamic> _full({Uint8List? pubKey, String? crashlyticsUserId}) {
  return buildMeshCoreDiagnosticsPayload(
    now: DateTime.utc(2026, 5, 15, 12, 0, 0),
    appVersion: '1.40.0',
    appBuildNumber: '177',
    selfNodeName: 'TestDevice',
    selfPubKey: pubKey ?? Uint8List.fromList(List<int>.generate(32, (i) => i)),
    selfBatteryMv: 3700,
    selfFreqKhz: 868000,
    selfBandwidthHz: 125000,
    selfSpreadingFactor: 11,
    selfCodingRate: 5,
    selfTxPowerDbm: 22,
    linkProtocolName: 'meshcore',
    linkStateName: 'connected',
    frameCount: 42,
    rateLimiterCurrentWindowUsedBytes: 120,
    rateLimiterWindowCapacityBytes: 1024,
    rateLimiterRemainingBytes: 904,
    rateLimiterCurrentWindowRejectedBytes: 0,
    rateLimiterPeakWindowUsage: 360,
    crashlyticsUserId: crashlyticsUserId,
  );
}

void main() {
  group('redactPubKeyFingerprint - D-Q6', () {
    test('32-byte pubKey -> head4 + ellipsis + tail4 hex (17 chars)', () {
      final pub = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final out = redactPubKeyFingerprint(pub);
      expect(out, '00010203…1c1d1e1f');
      expect(out.length, 17);
    });

    test('shorter than 8 bytes returns the raw hex (no separator)', () {
      final pub = Uint8List.fromList([0xab, 0xcd]);
      final out = redactPubKeyFingerprint(pub);
      expect(out, 'abcd');
    });
  });

  group('redactCrashlyticsId - D-Q6', () {
    test('null in -> null out', () {
      expect(redactCrashlyticsId(null), isNull);
    });

    test('empty in -> null out', () {
      expect(redactCrashlyticsId(''), isNull);
    });

    test('short id passes through verbatim', () {
      expect(redactCrashlyticsId('abc123'), 'abc123');
    });

    test('long id is truncated to leading 8 chars + ellipsis', () {
      expect(
        redactCrashlyticsId('e20436b6a738dc2e52cba727f13652b2'),
        'e20436b6…',
      );
    });
  });

  group('buildMeshCoreDiagnosticsPayload - D-Q6', () {
    test('schema version is the canonical constant', () {
      final p = _full();
      expect(p['schemaVersion'], kMeshCoreDiagnosticsBundleSchemaVersion);
      expect(kMeshCoreDiagnosticsBundleSchemaVersion, 1);
    });

    test('generatedAt is ISO-8601', () {
      final p = _full();
      expect(p['generatedAt'], '2026-05-15T12:00:00.000Z');
    });

    test('selfInfo carries name + redacted fingerprint + radio params', () {
      final p = _full();
      final self = p['selfInfo'] as Map<String, dynamic>;
      expect(self['name'], 'TestDevice');
      expect(self['pubKeyFingerprint'], '00010203…1c1d1e1f');
      expect(self['batteryMv'], 3700);
      expect(self['freqKhz'], 868000);
      expect(self['bandwidthHz'], 125000);
      expect(self['spreadingFactor'], 11);
      expect(self['codingRate'], 5);
      expect(self['txPowerDbm'], 22);
    });

    test('rateLimiter block surfaces every D34a field', () {
      final p = _full();
      final rl = p['rateLimiter'] as Map<String, dynamic>;
      expect(rl['currentWindowUsedBytes'], 120);
      expect(rl['windowCapacityBytes'], 1024);
      expect(rl['remainingBytes'], 904);
      expect(rl['currentWindowRejectedBytes'], 0);
      expect(rl['peakWindowUsage'], 360);
    });

    test('missing Crashlytics id renders null (no exception)', () {
      final p = _full();
      final c = p['crashlytics'] as Map<String, dynamic>;
      expect(c['userIdPrefix'], isNull);
    });

    test('long Crashlytics id is truncated', () {
      final p = _full(crashlyticsUserId: 'e20436b6a738dc2e52cba727f13652b2');
      final c = p['crashlytics'] as Map<String, dynamic>;
      expect(c['userIdPrefix'], 'e20436b6…');
    });

    test(
      'exclusions block is present + names every privacy-redacted source',
      () {
        final p = _full();
        final ex = p['exclusions'] as Map<String, dynamic>;
        for (final key in const [
          'chatBodies',
          'fullPubKeys',
          'passwords',
          'channelPsks',
          'gpsCoordinates',
          'pathHistory',
          'appLogger',
        ]) {
          expect(
            ex.containsKey(key),
            isTrue,
            reason: 'exclusions must document "$key"',
          );
        }
      },
    );

    test('payload NEVER contains a full 64-char pubkey', () {
      final p = _full();
      final json = p.toString();
      // The test pubKey is 0x00..0x1f, full hex = 32 * 2 = 64 chars
      // starting with "000102030405060708090a0b0c0d0e0f10..."
      const full =
          '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
      expect(json.contains(full), isFalse);
    });

    test('frameLog block notes the attachment filename', () {
      final p = _full();
      final fl = p['frameLog'] as Map<String, dynamic>;
      expect(fl['frameCount'], 42);
      expect(fl['attachment'], 'frame-log.txt');
    });
  });
}
