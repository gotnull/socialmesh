// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

void main() {
  group('parseSelfInfo', () {
    /// Build a valid SELF_INFO payload.
    Uint8List buildSelfInfoPayload({
      int advType = 0x01,
      int txPower = 20,
      int maxLoraTxPower = 22,
      String nodeName = 'TestNode',
    }) {
      final payload = <int>[
        advType,
        txPower,
        maxLoraTxPower,
        ...List.filled(meshCorePubKeySize, 0xAA), // pub_key (32 bytes)
        0, 0, 0, 0, // lat
        0, 0, 0, 0, // lon
        0, // multi_acks
        0, // advert_loc_policy
        0, // telemetry modes
        0, // manual_add_contacts
        0, 0, 0, 0, // freq (uint32 LE)
        0, 0, 0, 0, // bw (uint32 LE)
        12, // sf
        5, // cr
      ];

      // Pad to offset 57 where node_name starts
      while (payload.length < 57) {
        payload.add(0);
      }

      // Add node name (null-terminated)
      payload.addAll(nodeName.codeUnits);
      payload.add(0); // null terminator

      return Uint8List.fromList(payload);
    }

    test('parses valid payload with node name', () {
      final payload = buildSelfInfoPayload(nodeName: 'MyDevice');
      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value, isNotNull);
      expect(result.value!.nodeName, equals('MyDevice'));
      expect(result.value!.advType, equals(0x01));
      expect(result.value!.txPowerDbm, equals(20));
      expect(result.value!.maxLoraTxPower, equals(22));
    });

    test('parses minimal payload (just required fields)', () {
      // Minimum: ADV_TYPE + tx_power + MAX_LORA_TX_POWER + pub_key = 35 bytes
      final payload = Uint8List.fromList([
        0x02, // ADV_TYPE
        15, // tx_power
        20, // MAX_LORA_TX_POWER
        ...List.filled(meshCorePubKeySize, 0xBB), // pub_key
      ]);

      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.advType, equals(0x02));
      expect(result.value!.txPowerDbm, equals(15));
      expect(result.value!.pubKey.length, equals(meshCorePubKeySize));
      expect(result.value!.nodeName, isEmpty); // No name in minimal payload
    });

    test('fails on payload too short', () {
      final payload = Uint8List.fromList([0x01, 0x02]); // Only 2 bytes

      final result = parseSelfInfo(payload);

      expect(result.isFailure, isTrue);
      expect(result.error, contains('too short'));
    });

    test('extracts lat/lon when present', () {
      final payload = Uint8List.fromList([
        0x01, // ADV_TYPE
        20, // tx_power
        22, // MAX_LORA_TX_POWER
        ...List.filled(meshCorePubKeySize, 0xAA), // pub_key
        0x01, 0x00, 0x00, 0x00, // lat = 1
        0x02, 0x00, 0x00, 0x00, // lon = 2
      ]);

      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.latitude, equals(1));
      expect(result.value!.longitude, equals(2));
    });

    test('preserves raw payload', () {
      final payload = buildSelfInfoPayload();
      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.rawPayload, equals(payload));
    });

    test('handles empty node name', () {
      final payload = buildSelfInfoPayload(nodeName: '');
      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.nodeName, isEmpty);
    });

    test('extracts spreading factor and coding rate', () {
      final payload = buildSelfInfoPayload();
      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.spreadingFactor, equals(12));
      expect(result.value!.codingRate, equals(5));
    });
  });

  group('parseBattAndStorage', () {
    test('parses valid payload', () {
      final payload = Uint8List.fromList([
        0x00, 0x10, // battery millivolts = 4096 (0x1000)
        0x64, 0x00, // storage used = 100
        0xE8, 0x03, // storage total = 1000
      ]);

      final result = parseBattAndStorage(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value, isNotNull);
      expect(result.value!.batteryMillivolts, equals(4096));
      expect(result.value!.storageUsed, equals(100));
      expect(result.value!.storageTotal, equals(1000));
    });

    test('fails on payload too short', () {
      final payload = Uint8List.fromList([0x00, 0x10, 0x64]); // Only 3 bytes

      final result = parseBattAndStorage(payload);

      expect(result.isFailure, isTrue);
      expect(result.error, contains('too short'));
    });

    test('calculates battery percentage estimate', () {
      // 3600 mV should be about 50% (range 3000-4200)
      final payload = Uint8List.fromList([
        0x10, 0x0E, // battery = 3600 (0x0E10)
        0x00, 0x00, // storage used
        0x00, 0x00, // storage total
      ]);

      final result = parseBattAndStorage(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.batteryPercentEstimate, equals(50));
    });

    test('battery percentage clamped to 0-100', () {
      // Test below minimum (2500 mV)
      final lowPayload = Uint8List.fromList([
        0xC4, 0x09, // battery = 2500
        0x00, 0x00,
        0x00, 0x00,
      ]);
      expect(parseBattAndStorage(lowPayload).value!.batteryPercentEstimate, 0);

      // Test above maximum (4500 mV)
      final highPayload = Uint8List.fromList([
        0x94, 0x11, // battery = 4500
        0x00, 0x00,
        0x00, 0x00,
      ]);
      expect(
        parseBattAndStorage(highPayload).value!.batteryPercentEstimate,
        100,
      );
    });

    test('calculates storage percentage', () {
      final payload = Uint8List.fromList([
        0x00, 0x00, // battery
        0x32, 0x00, // storage used = 50
        0xC8, 0x00, // storage total = 200
      ]);

      final result = parseBattAndStorage(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.storagePercentUsed, equals(25)); // 50/200 = 25%
    });

    test('storage percentage is null when total is zero', () {
      final payload = Uint8List.fromList([
        0x00, 0x00, // battery
        0x32, 0x00, // storage used = 50
        0x00, 0x00, // storage total = 0
      ]);

      final result = parseBattAndStorage(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.storagePercentUsed, isNull);
    });

    test('preserves raw payload', () {
      final payload = Uint8List.fromList([0x00, 0x10, 0x64, 0x00, 0xE8, 0x03]);
      final result = parseBattAndStorage(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.rawPayload, equals(payload));
    });
  });

  group('MeshCoreSelfInfo', () {
    test('toString includes key fields', () {
      final info = MeshCoreSelfInfo(
        advType: 1,
        txPowerDbm: 20,
        maxLoraTxPower: 22,
        pubKey: Uint8List(32),
        nodeName: 'TestNode',
        rawPayload: Uint8List(0),
      );

      final str = info.toString();

      expect(str, contains('TestNode'));
      expect(str, contains('advType=1'));
      expect(str, contains('txPower=20'));
    });
  });

  group('MeshCoreBattAndStorage', () {
    test('toString includes key fields', () {
      final info = MeshCoreBattAndStorage(
        batteryMillivolts: 3700,
        storageUsed: 100,
        storageTotal: 500,
        rawPayload: Uint8List(0),
      );

      final str = info.toString();

      expect(str, contains('3700mV'));
      expect(str, contains('100/500'));
    });
  });

  group('ParseResult', () {
    test('success contains value', () {
      final result = ParseResult.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.value, equals(42));
      expect(result.error, isNull);
    });

    test('failure contains error', () {
      final result = ParseResult<int>.failure('Something went wrong');

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.value, isNull);
      expect(result.error, equals('Something went wrong'));
    });
  });
}
