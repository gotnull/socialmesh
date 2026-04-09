// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart';
import 'package:socialmesh/services/firmware/hardware_architecture.dart';

/// This test ensures the HardwareModel → DeviceArchitecture mapping in
/// hardware_architecture.dart stays in sync with the protobuf-generated
/// HardwareModel enum. When protobufs are regenerated and new hardware
/// models are added, this test will FAIL until the mapping is updated.
void main() {
  /// All HardwareModel integer values from the protobuf enum, excluding
  /// UNSET (0) which is not a real device.
  final protobufValues = HardwareModel.values
      .where((m) => m != HardwareModel.UNSET)
      .map((m) => m.value)
      .toSet();

  final mapped = mappedHwModelValues;

  test('every HardwareModel protobuf value has an architecture mapping', () {
    final unmapped = protobufValues.difference(mapped);
    expect(
      unmapped,
      isEmpty,
      reason:
          'The following HardwareModel values lack an architecture mapping '
          'in hardware_architecture.dart. Add them to _hwModelToArchitecture:\n'
          '${_describeValues(unmapped)}',
    );
  });

  test('no stale entries in architecture mapping', () {
    final stale = mapped.difference(protobufValues);
    expect(
      stale,
      isEmpty,
      reason:
          'The following integer values in _hwModelToArchitecture no longer '
          'exist in the HardwareModel protobuf enum. Remove them:\n'
          '${stale.toList()..sort()}',
    );
  });

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

  test('ESP32 variants support ESP OTA', () {
    expect(DeviceArchitecture.esp32.supportsEspOta, isTrue);
    expect(DeviceArchitecture.esp32s3.supportsEspOta, isTrue);
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
