// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'device_hardware_catalog.dart';

/// Chipset architecture family for firmware updates.
///
/// Determines the update method (Nordic DFU, ESP OTA, web flasher)
/// and which firmware archive to download from GitHub releases.
enum DeviceArchitecture {
  nrf52840,
  esp32,
  esp32s3,
  esp32c3,
  esp32c6,
  rp2040,
  rp2350,
  stm32,
  unknown,
}

/// Extension methods for [DeviceArchitecture].
extension DeviceArchitectureX on DeviceArchitecture {
  /// Whether this architecture supports in-app Nordic DFU over BLE.
  bool get supportsNordicDfu => this == DeviceArchitecture.nrf52840;

  /// Whether this architecture supports ESP OTA updates.
  bool get supportsEspOta =>
      this == DeviceArchitecture.esp32 ||
      this == DeviceArchitecture.esp32s3 ||
      this == DeviceArchitecture.esp32c3 ||
      this == DeviceArchitecture.esp32c6;

  /// The firmware zip asset name prefix in GitHub releases.
  ///
  /// e.g., `firmware-nrf52840-` matches `firmware-nrf52840-2.7.15.567b8ea.zip`.
  String get firmwareAssetPrefix {
    switch (this) {
      case DeviceArchitecture.nrf52840:
        return 'firmware-nrf52840-';
      case DeviceArchitecture.esp32:
        return 'firmware-esp32-';
      case DeviceArchitecture.esp32s3:
        return 'firmware-esp32s3-';
      case DeviceArchitecture.esp32c3:
        return 'firmware-esp32c3-';
      case DeviceArchitecture.esp32c6:
        return 'firmware-esp32c6-';
      case DeviceArchitecture.rp2040:
        return 'firmware-rp2040-';
      case DeviceArchitecture.rp2350:
        return 'firmware-rp2350-';
      case DeviceArchitecture.stm32:
        return 'firmware-stm32-';
      case DeviceArchitecture.unknown:
        return '';
    }
  }
}

/// Returns the [DeviceArchitecture] for a given HardwareModel protobuf
/// enum integer value.
///
/// Resolves via [DeviceHardwareCatalog], which loads the upstream meshtastic
/// hardware table at boot. Returns [DeviceArchitecture.unknown] for any
/// hwModel not covered (including all hwModels if the catalog has not been
/// loaded yet — see `lib/main.dart`).
DeviceArchitecture architectureFromHwModel(int? hwModelValue) {
  return DeviceHardwareCatalog.instance.architectureFor(hwModelValue);
}

/// The set of HardwareModel integer values that have explicit architecture
/// mappings. Used by tests to verify coverage against the protobuf enum.
Set<int> get mappedHwModelValues =>
    DeviceHardwareCatalog.instance.mappedHwModelValues;

/// Returns the firmware target name for a given HardwareModel protobuf
/// enum integer value.
///
/// The target name is the device-specific portion of firmware file names
/// inside the architecture zip. e.g., `rak4631` for files named
/// `firmware-rak4631-2.7.15.567b8ea.zip`.
///
/// Returns `null` for unmapped hardware models. Hand-curated below — entries
/// are only added once verified against an actual GitHub firmware release
/// asset, otherwise users get 404s during OTA. Do not source this from the
/// upstream JSON's `platformioTarget` field without per-entry verification.
String? firmwareTargetFromHwModel(int? hwModelValue) {
  if (hwModelValue == null) return null;
  return _hwModelToFirmwareTarget[hwModelValue];
}

// ---------------------------------------------------------------------------
// HardwareModel enum value → firmware target name
// ---------------------------------------------------------------------------
// The target name is the device identifier used in firmware filenames
// inside the architecture zip. e.g., for RAK4631 the zip contains
// `firmware-rak4631-2.7.15.567b8ea.zip` (the Nordic DFU package).
const _hwModelToFirmwareTarget = <int, String>{
  // nRF52840
  7: 't-echo',
  9: 'rak4631',
  21: 'wio-tracker-wm1110',
  22: 'rak2560',
  29: 'canaryone',
  33: 't-echo',
  34: 'ppr',
  40: 'pca10059-trackerboard',
  63: 'meshtastic-diy-v1',
  69: 'heltec-mesh-node-t114',
  71: 'tracker-t1000-e',
  82: 'ms24sf1',
  84: 'wismesh-tap',
  88: 'xiao-ble',
  105: 'rak10701',
  109: 't-echo-lite',
  116: 'wismesh-tap',
  117: 'rak3401',
  121: 'meshstick-diy',
  127: 'heltec-mesh-node-t096',

  // ESP32 (common)
  4: 'tbeam',
  5: 'heltec-v2.0',
  25: 'station-g1',
  42: 'm5stack-coreink',
  122: 'tbeam',

  // ESP32-S3 (common)
  12: 'tbeam-s3-core',
  16: 'tlora-t3s3-v1',
  43: 'heltec-v3',
  44: 'heltec-wsl-v3',
  48: 'heltec-wireless-tracker',
  49: 'heltec-wireless-paper',
  50: 't-deck',
  51: 't-watch-s3',
  54: 'ebyte-esp32-s3',
  70: 'sensecap-indicator',
  80: 'm5stack-cores3',
  91: 't-eth-elite',
  102: 't-deck-pro',
  110: 'heltec-v4',
  113: 'heltec-wireless-tracker-v2',
  114: 't-watch-ultra',
};
