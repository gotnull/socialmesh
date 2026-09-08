// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/ble_system_devices.dart';

void main() {
  const noDelay = Duration.zero;

  group('negotiateMeshBleMtu', () {
    test('skips the request where the OS negotiates on its own', () async {
      var requests = 0;
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        final mtu = await negotiateMeshBleMtu(
          requestMtu: (_) async {
            requests++;
            return 247;
          },
          isConnected: () => true,
          platform: platform,
          retryDelay: noDelay,
        );
        expect(mtu, isNull, reason: platform.name);
      }
      expect(requests, 0);
    });

    test(
      'asks for the shared MTU and returns what the radio granted',
      () async {
        int? requested;
        final mtu = await negotiateMeshBleMtu(
          requestMtu: (desired) async {
            requested = desired;
            return 247;
          },
          isConnected: () => true,
          platform: TargetPlatform.android,
          retryDelay: noDelay,
        );
        expect(requested, kMeshBleRequestedMtu);
        expect(mtu, 247);
      },
    );

    test('retries a failed request while the link is still up', () async {
      var calls = 0;
      final mtu = await negotiateMeshBleMtu(
        requestMtu: (_) async {
          calls++;
          if (calls < 3) throw Exception('gatt busy');
          return 185;
        },
        isConnected: () => true,
        platform: TargetPlatform.android,
        retryDelay: noDelay,
      );
      expect(calls, 3);
      expect(mtu, 185);
    });

    test('gives up after the attempt budget and returns null', () async {
      var calls = 0;
      final mtu = await negotiateMeshBleMtu(
        requestMtu: (_) async {
          calls++;
          throw Exception('unsupported');
        },
        isConnected: () => true,
        platform: TargetPlatform.android,
        attempts: 3,
        retryDelay: noDelay,
      );
      expect(calls, 3);
      expect(mtu, isNull);
    });

    test('throws when the link drops between attempts', () async {
      var calls = 0;
      await expectLater(
        negotiateMeshBleMtu(
          requestMtu: (_) async {
            calls++;
            throw Exception('device is disconnected');
          },
          isConnected: () => false,
          platform: TargetPlatform.android,
          retryDelay: noDelay,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('MTU negotiation'),
          ),
        ),
      );
      expect(calls, 1);
    });
  });
}
