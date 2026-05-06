// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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

    // D16: parser must read freq + bw from SELF_INFO. Pre-D16 these were
    // silently dropped, which forced the radio sheet to invent its own
    // SharedPreferences cache (D11). The firmware was always sending
    // them.
    test('D16: extracts freq (kHz) from SELF_INFO offsets 47..50', () {
      // Build a payload with freq = 869618 kHz (EU868 sub-band; what
      // Radio A is on per devices.yaml).
      final payload = <int>[
        0x01, // advType
        22, // tx_power
        22, // MAX_LORA_TX_POWER
        ...List.filled(meshCorePubKeySize, 0xAA), // pub_key
        0, 0, 0, 0, // lat
        0, 0, 0, 0, // lon
        0, 0, 0, 0, // multi_acks, advert_loc_policy, telemetry, manual_add
        // freq = 869618 kHz, u32 LE: 0x000D44F2
        0xF2, 0x44, 0x0D, 0x00,
        // bw = 62500 Hz, u32 LE: 0x0000F424
        0x24, 0xF4, 0x00, 0x00,
        8, // sf
        5, // cr
      ];
      final result = parseSelfInfo(Uint8List.fromList(payload));

      expect(result.isSuccess, isTrue);
      expect(result.value!.freqKhz, equals(869618));
      expect(result.value!.bandwidthHz, equals(62500));
      expect(result.value!.spreadingFactor, equals(8));
      expect(result.value!.codingRate, equals(5));
      expect(result.value!.txPowerDbm, equals(22));
    });

    test('D16: extracts AU915 / 250kHz canonical defaults', () {
      // Build a payload with the MeshCore companion-radio defaults
      // (LORA_FREQ 915.0 / LORA_BW 250 / LORA_SF 10 / LORA_CR 5).
      // This is what a fresh-flashed AU/US radio would broadcast.
      final payload = <int>[
        0x01, 9, 22, // advType, tx_power, MAX_LORA_TX_POWER
        ...List.filled(meshCorePubKeySize, 0xAA),
        0, 0, 0, 0, 0, 0, 0, 0, // lat, lon
        0, 0, 0, 0, // misc
        // freq = 915000 kHz, u32 LE: 0x000DF638
        0x38, 0xF6, 0x0D, 0x00,
        // bw = 250000 Hz, u32 LE: 0x0003D090
        0x90, 0xD0, 0x03, 0x00,
        10, // sf
        5, // cr
      ];
      final result = parseSelfInfo(Uint8List.fromList(payload));

      expect(result.isSuccess, isTrue);
      expect(result.value!.freqKhz, equals(915000));
      expect(result.value!.bandwidthHz, equals(250000));
      expect(result.value!.spreadingFactor, equals(10));
      expect(result.value!.codingRate, equals(5));
    });

    test('D16: short payload leaves freq+bw null without throwing', () {
      // Payload truncated before offset 47. Parser must NOT throw and
      // MUST leave freqKhz / bandwidthHz null. Pre-existing minimal-
      // payload behaviour (advType + tx_power + max + pubKey only)
      // exercised this implicitly; D16 makes it explicit.
      final payload = Uint8List.fromList([
        0x01, 20, 22,
        ...List.filled(meshCorePubKeySize, 0xBB),
        // No further fields.
      ]);
      final result = parseSelfInfo(payload);

      expect(result.isSuccess, isTrue);
      expect(result.value!.freqKhz, isNull);
      expect(result.value!.bandwidthHz, isNull);
      expect(result.value!.spreadingFactor, isNull);
      expect(result.value!.codingRate, isNull);
    });

    test('D16: payload long enough for freq but not bw leaves bw null', () {
      // Edge case: 51-byte payload contains everything up to and
      // including freq[47..50] but is one byte short of bw[51..54].
      // Parser MUST surface freq while leaving bw null instead of
      // misreading or throwing.
      final payload = <int>[
        0x01, 20, 22,
        ...List.filled(meshCorePubKeySize, 0xCC),
        0, 0, 0, 0, 0, 0, 0, 0, // lat, lon (8)
        0, 0, 0, 0, // misc (4) -> position 47
        0xF2, 0x44, 0x0D, 0x00, // freq 869618 (4) -> position 51
        // (no bw bytes)
      ];
      expect(payload.length, equals(51));
      final result = parseSelfInfo(Uint8List.fromList(payload));

      expect(result.isSuccess, isTrue);
      expect(result.value!.freqKhz, equals(869618));
      expect(result.value!.bandwidthHz, isNull);
    });

    test(
      'D16: SELF_INFO toString surfaces all radio params for diag bundles',
      () {
        // Diag bundles need a single-line dump of the full radio state.
        // Pre-D16 toString only carried name/advType/txPower so a diag
        // log never showed freq/bw/sf/cr. Verify the new shape.
        final payload = <int>[
          0x01, 22, 22,
          ...List.filled(meshCorePubKeySize, 0xAA),
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0,
          0xF2, 0x44, 0x0D, 0x00, // freq 869618
          0x24, 0xF4, 0x00, 0x00, // bw 62500
          8, // sf
          5, // cr
        ];
        final result = parseSelfInfo(Uint8List.fromList(payload));
        expect(result.isSuccess, isTrue);
        final s = result.value!.toString();

        expect(s, contains('freqKhz=869618'));
        expect(s, contains('bw=62500'));
        expect(s, contains('sf=8'));
        expect(s, contains('cr=5'));
        expect(s, contains('txPower=22'));
      },
    );
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
