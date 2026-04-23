// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart';
import 'package:socialmesh/services/firmware/device_hardware_catalog.dart';
import 'package:socialmesh/services/firmware/hardware_architecture.dart';

/// Parity check between the protobuf-generated HardwareModel enum and the
/// runtime DeviceArchitecture catalog (upstream JSON + supplement).
///
/// When protobufs are regenerated and new HardwareModel values appear, the
/// "every HardwareModel … has an architecture mapping" test fails until the
/// new value is added to the upstream JSON OR the supplement in
/// `device_hardware_catalog.dart`.
///
/// When the upstream JSON catches up to a HardwareModel that the supplement
/// also defines, the "no stale supplement entry" test fails — remove the
/// supplement entry to defer to the (authoritative) JSON.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    DeviceHardwareCatalog.instance.resetForTesting();
    await DeviceHardwareCatalog.instance.load();
  });

  /// All HardwareModel integer values from the protobuf enum, excluding
  /// UNSET (0) which is not a real device.
  final protobufValues = HardwareModel.values
      .where((m) => m != HardwareModel.UNSET)
      .map((m) => m.value)
      .toSet();

  test('every HardwareModel protobuf value has an architecture mapping', () {
    final mapped = mappedHwModelValues;
    final unmapped = protobufValues.difference(mapped);
    expect(
      unmapped,
      isEmpty,
      reason:
          'The following HardwareModel values lack an architecture mapping. '
          'Either the upstream catalog (assets/device_hardware.json) needs '
          'a refresh — run scripts/fetch_device_hardware.sh — or add them '
          'to the _supplement map in device_hardware_catalog.dart:\n'
          '${_describeValues(unmapped)}',
    );
  });

  test('no stale entries in architecture mapping', () {
    final mapped = mappedHwModelValues;
    final stale = mapped.difference(protobufValues);
    expect(
      stale,
      isEmpty,
      reason:
          'The following integer values are mapped but no longer exist in '
          'the HardwareModel protobuf enum. They will linger in the JSON '
          'until upstream removes them; if they are in the supplement, '
          'remove them:\n'
          '${stale.toList()..sort()}',
    );
  });

  test(
    'every catalog architecture agrees with the upstream JSON entry',
    () async {
      final raw = await rootBundle.loadString('assets/device_hardware.json');
      final entries = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final disagreements = <String>[];

      for (final entry in entries) {
        final hwModel = entry['hwModel'] as int?;
        final archStr = entry['architecture'] as String?;
        if (hwModel == null || archStr == null) continue;
        final expected = _expectFromArchString(archStr);
        if (expected == null) {
          disagreements.add(
            '$hwModel (${entry['hwModelSlug']}): JSON architecture '
            '"$archStr" has no mapping in DeviceHardwareCatalog._archFromString',
          );
          continue;
        }
        final actual = architectureFromHwModel(hwModel);
        if (actual != expected) {
          disagreements.add(
            '$hwModel (${entry['hwModelSlug']}): JSON says $expected, '
            'catalog returned $actual',
          );
        }
      }

      expect(
        disagreements,
        isEmpty,
        reason:
            'Catalog disagrees with the bundled upstream JSON for these '
            'HardwareModels. Either the supplement is overriding (and should '
            'be removed) or the JSON has an architecture string the catalog '
            'does not recognise:\n  ${disagreements.join('\n  ')}',
      );
    },
  );

  test('architectureFromHwModel returns unknown for null', () {
    expect(architectureFromHwModel(null), DeviceArchitecture.unknown);
  });

  test('architectureFromHwModel returns unknown for unmapped value', () {
    // Use a value that's very unlikely to ever be assigned
    expect(architectureFromHwModel(99999), DeviceArchitecture.unknown);
  });

  test('architectureFromHwModel maps known nRF52840 device', () {
    // RAK4631 = 9
    expect(
      architectureFromHwModel(HardwareModel.RAK4631.value),
      DeviceArchitecture.nrf52840,
    );
  });

  test('architectureFromHwModel maps known ESP32-S3 device', () {
    // HELTEC_V3 = 43
    expect(
      architectureFromHwModel(HardwareModel.HELTEC_V3.value),
      DeviceArchitecture.esp32s3,
    );
  });

  test('architectureFromHwModel maps HELTEC_HT62 to ESP32-C3', () {
    // Regression for a previously-misclassified device. Upstream JSON lists
    // HELTEC_HT62 (53) as esp32-c3; the old hand-maintained map had it as
    // esp32s3, which would have routed it to the wrong DFU asset.
    expect(
      architectureFromHwModel(HardwareModel.HELTEC_HT62.value),
      DeviceArchitecture.esp32c3,
    );
  });

  test('firmwareTargetFromHwModel returns null for unknown value', () {
    expect(firmwareTargetFromHwModel(null), isNull);
    expect(firmwareTargetFromHwModel(99999), isNull);
  });

  test('firmwareTargetFromHwModel returns correct target for RAK4631', () {
    expect(firmwareTargetFromHwModel(HardwareModel.RAK4631.value), 'rak4631');
  });

  test('nRF52840 supports Nordic DFU', () {
    expect(DeviceArchitecture.nrf52840.supportsNordicDfu, isTrue);
  });

  test('ESP32 does not support Nordic DFU', () {
    expect(DeviceArchitecture.esp32.supportsNordicDfu, isFalse);
    expect(DeviceArchitecture.esp32s3.supportsNordicDfu, isFalse);
  });

  test('all ESP32 variants support ESP OTA', () {
    expect(DeviceArchitecture.esp32.supportsEspOta, isTrue);
    expect(DeviceArchitecture.esp32s3.supportsEspOta, isTrue);
    expect(DeviceArchitecture.esp32c3.supportsEspOta, isTrue);
    expect(DeviceArchitecture.esp32c6.supportsEspOta, isTrue);
  });

  test('firmwareAssetPrefix is non-empty for real architectures', () {
    for (final arch in DeviceArchitecture.values) {
      if (arch == DeviceArchitecture.unknown) {
        expect(arch.firmwareAssetPrefix, isEmpty);
      } else {
        expect(arch.firmwareAssetPrefix, isNotEmpty);
        expect(arch.firmwareAssetPrefix, endsWith('-'));
      }
    }
  });
}

DeviceArchitecture? _expectFromArchString(String s) {
  switch (s) {
    case 'esp32':
      return DeviceArchitecture.esp32;
    case 'esp32-c3':
      return DeviceArchitecture.esp32c3;
    case 'esp32-c6':
      return DeviceArchitecture.esp32c6;
    case 'esp32-s3':
      return DeviceArchitecture.esp32s3;
    case 'nrf52840':
      return DeviceArchitecture.nrf52840;
    case 'rp2040':
      return DeviceArchitecture.rp2040;
    case 'rp2350':
      return DeviceArchitecture.rp2350;
    case 'stm32':
    case 'stm32wl':
      return DeviceArchitecture.stm32;
    case 'portduino':
      return DeviceArchitecture.unknown;
  }
  return null;
}

/// Produces a readable list of unmapped HardwareModel values with their names.
String _describeValues(Set<int> values) {
  final sorted = values.toList()..sort();
  final lines = <String>[];
  for (final v in sorted) {
    final model = HardwareModel.valueOf(v);
    lines.add('  $v (${model?.name ?? "?"})');
  }
  return lines.join('\n');
}
