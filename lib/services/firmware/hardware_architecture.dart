// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Chipset architecture family for firmware updates.
///
/// Determines the update method (Nordic DFU, ESP OTA, web flasher)
/// and which firmware archive to download from GitHub releases.
enum DeviceArchitecture {
  nrf52840,
  esp32,
  esp32s3,
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
DeviceArchitecture architectureFromHwModel(int? hwModelValue) {
  if (hwModelValue == null) return DeviceArchitecture.unknown;
  return _hwModelToArchitecture[hwModelValue] ?? DeviceArchitecture.unknown;
}

/// The set of HardwareModel integer values that have explicit architecture
/// mappings. Used by tests to verify coverage against the protobuf enum.
Set<int> get mappedHwModelValues => _hwModelToArchitecture.keys.toSet();

/// Returns the firmware target name for a given HardwareModel protobuf
/// enum integer value.
///
/// The target name is the device-specific portion of firmware file names
/// inside the architecture zip. e.g., `rak4631` for files named
/// `firmware-rak4631-2.7.15.567b8ea.zip`.
///
/// Returns `null` for unmapped hardware models.
String? firmwareTargetFromHwModel(int? hwModelValue) {
  if (hwModelValue == null) return null;
  return _hwModelToFirmwareTarget[hwModelValue];
}

// ---------------------------------------------------------------------------
// HardwareModel enum value → DeviceArchitecture
// ---------------------------------------------------------------------------
// Values from lib/generated/meshtastic/mesh.pbenum.dart (HardwareModel).
// Keep this mapping in sync when protobufs are regenerated.
const _hwModelToArchitecture = <int, DeviceArchitecture>{
  // nRF52840
  7: DeviceArchitecture.nrf52840, // T_ECHO
  9: DeviceArchitecture.nrf52840, // RAK4631
  21: DeviceArchitecture.nrf52840, // WIO_WM1110
  22: DeviceArchitecture.nrf52840, // RAK2560
  23: DeviceArchitecture.nrf52840, // HELTEC_HRU_3601
  29: DeviceArchitecture.nrf52840, // CANARYONE
  33: DeviceArchitecture.nrf52840, // T_ECHO_PLUS
  34: DeviceArchitecture.nrf52840, // PPR
  36: DeviceArchitecture.nrf52840, // NRF52_UNKNOWN
  40: DeviceArchitecture.nrf52840, // NRF52840_PCA10059
  63: DeviceArchitecture.nrf52840, // NRF52_PROMICRO_DIY
  69: DeviceArchitecture.nrf52840, // HELTEC_MESH_NODE_T114
  71: DeviceArchitecture.nrf52840, // TRACKER_T1000_E
  75: DeviceArchitecture.nrf52840, // ME25LS01_4Y10TD
  82: DeviceArchitecture.nrf52840, // MS24SF1
  84: DeviceArchitecture.nrf52840, // WISMESH_TAP
  88: DeviceArchitecture.nrf52840, // XIAO_NRF52_KIT
  105: DeviceArchitecture.nrf52840, // WISMESH_TAG
  106: DeviceArchitecture.nrf52840, // RAK3312
  109: DeviceArchitecture.nrf52840, // T_ECHO_LITE
  116: DeviceArchitecture.nrf52840, // WISMESH_TAP_V2
  117: DeviceArchitecture.nrf52840, // RAK3401
  118: DeviceArchitecture.nrf52840, // RAK6421
  119: DeviceArchitecture.nrf52840, // THINKNODE_M4
  120: DeviceArchitecture.nrf52840, // THINKNODE_M6
  121: DeviceArchitecture.nrf52840, // MESHSTICK_1262
  127: DeviceArchitecture.nrf52840, // HELTEC_MESH_NODE_T096
  // ESP32
  1: DeviceArchitecture.esp32, // TLORA_V2
  2: DeviceArchitecture.esp32, // TLORA_V1
  3: DeviceArchitecture.esp32, // TLORA_V2_1_1P6
  4: DeviceArchitecture.esp32, // TBEAM
  5: DeviceArchitecture.esp32, // HELTEC_V2_0
  6: DeviceArchitecture.esp32, // TBEAM_V0P7
  8: DeviceArchitecture.esp32, // TLORA_V1_1P3
  10: DeviceArchitecture.esp32, // HELTEC_V2_1
  11: DeviceArchitecture.esp32, // HELTEC_V1
  13: DeviceArchitecture.esp32, // RAK11200
  14: DeviceArchitecture.esp32, // NANO_G1
  17: DeviceArchitecture.esp32, // NANO_G1_EXPLORER
  18: DeviceArchitecture.esp32, // NANO_G2_ULTRA
  19: DeviceArchitecture.esp32, // LORA_TYPE
  20: DeviceArchitecture.esp32, // WIPHONE
  24: DeviceArchitecture.esp32, // HELTEC_WIRELESS_BRIDGE
  25: DeviceArchitecture.esp32, // STATION_G1
  32: DeviceArchitecture.esp32, // LORA_RELAY_V1
  35: DeviceArchitecture.esp32, // GENIEBLOCKS
  39: DeviceArchitecture.esp32, // DIY_V1
  41: DeviceArchitecture.esp32, // DR_DEV
  42: DeviceArchitecture.esp32, // M5STACK
  45: DeviceArchitecture.esp32, // BETAFPV_2400_TX
  46: DeviceArchitecture.esp32, // BETAFPV_900_NANO_TX
  56: DeviceArchitecture.esp32, // CHATTER_2
  64: DeviceArchitecture.esp32, // RADIOMASTER_900_BANDIT_NANO
  74: DeviceArchitecture.esp32, // RADIOMASTER_900_BANDIT
  77: DeviceArchitecture.esp32, // M5STACK_COREBASIC
  78: DeviceArchitecture.esp32, // M5STACK_CORE2
  122: DeviceArchitecture.esp32, // TBEAM_1_WATT
  124: DeviceArchitecture.esp32, // TBEAM_BPF
  // ESP32-S3
  12: DeviceArchitecture.esp32s3, // LILYGO_TBEAM_S3_CORE
  15: DeviceArchitecture.esp32s3, // TLORA_V2_1_1P8
  16: DeviceArchitecture.esp32s3, // TLORA_T3_S3
  28: DeviceArchitecture.esp32s3, // SENSELORA_S3
  31: DeviceArchitecture.esp32s3, // STATION_G2
  43: DeviceArchitecture.esp32s3, // HELTEC_V3
  44: DeviceArchitecture.esp32s3, // HELTEC_WSL_V3
  48: DeviceArchitecture.esp32s3, // HELTEC_WIRELESS_TRACKER
  49: DeviceArchitecture.esp32s3, // HELTEC_WIRELESS_PAPER
  50: DeviceArchitecture.esp32s3, // T_DECK
  51: DeviceArchitecture.esp32s3, // T_WATCH_S3
  52: DeviceArchitecture.esp32s3, // PICOMPUTER_S3
  53: DeviceArchitecture.esp32s3, // HELTEC_HT62
  54: DeviceArchitecture.esp32s3, // EBYTE_ESP32_S3
  55: DeviceArchitecture.esp32s3, // ESP32_S3_PICO
  57: DeviceArchitecture.esp32s3, // HELTEC_WIRELESS_PAPER_V1_0
  58: DeviceArchitecture.esp32s3, // HELTEC_WIRELESS_TRACKER_V1_0
  59: DeviceArchitecture.esp32s3, // UNPHONE
  60: DeviceArchitecture.esp32s3, // TD_LORAC
  61: DeviceArchitecture.esp32s3, // CDEBYTE_EORA_S3
  62: DeviceArchitecture.esp32s3, // TWC_MESH_V4
  65: DeviceArchitecture.esp32s3, // HELTEC_CAPSULE_SENSOR_V3
  66: DeviceArchitecture.esp32s3, // HELTEC_VISION_MASTER_T190
  67: DeviceArchitecture.esp32s3, // HELTEC_VISION_MASTER_E213
  68: DeviceArchitecture.esp32s3, // HELTEC_VISION_MASTER_E290
  70: DeviceArchitecture.esp32s3, // SENSECAP_INDICATOR
  80: DeviceArchitecture.esp32s3, // M5STACK_CORES3
  81: DeviceArchitecture.esp32s3, // SEEED_XIAO_S3
  85: DeviceArchitecture.esp32s3, // ROUTASTIC
  86: DeviceArchitecture.esp32s3, // MESH_TAB
  89: DeviceArchitecture.esp32s3, // THINKNODE_M1
  90: DeviceArchitecture.esp32s3, // THINKNODE_M2
  91: DeviceArchitecture.esp32s3, // T_ETH_ELITE
  92: DeviceArchitecture.esp32s3, // HELTEC_SENSOR_HUB
  93: DeviceArchitecture.esp32s3, // MUZI_BASE
  94: DeviceArchitecture.esp32s3, // HELTEC_MESH_POCKET
  95: DeviceArchitecture.esp32s3, // SEEED_SOLAR_NODE
  96: DeviceArchitecture.esp32s3, // NOMADSTAR_METEOR_PRO
  97: DeviceArchitecture.esp32s3, // CROWPANEL
  98: DeviceArchitecture.esp32s3, // LINK_32
  99: DeviceArchitecture.esp32s3, // SEEED_WIO_TRACKER_L1
  100: DeviceArchitecture.esp32s3, // SEEED_WIO_TRACKER_L1_EINK
  101: DeviceArchitecture.esp32s3, // MUZI_R1_NEO
  102: DeviceArchitecture.esp32s3, // T_DECK_PRO
  103: DeviceArchitecture.esp32s3, // T_LORA_PAGER
  104: DeviceArchitecture.esp32s3, // M5STACK_RESERVED
  107: DeviceArchitecture.esp32s3, // THINKNODE_M5
  108: DeviceArchitecture.esp32s3, // HELTEC_MESH_SOLAR
  110: DeviceArchitecture.esp32s3, // HELTEC_V4
  112: DeviceArchitecture.esp32s3, // M5STACK_CARDPUTER_ADV
  113: DeviceArchitecture.esp32s3, // HELTEC_WIRELESS_TRACKER_V2
  114: DeviceArchitecture.esp32s3, // T_WATCH_ULTRA
  115: DeviceArchitecture.esp32s3, // THINKNODE_M3
  123: DeviceArchitecture.esp32s3, // T5_S3_EPAPER_PRO
  125: DeviceArchitecture.esp32s3, // MINI_EPAPER_S3
  126: DeviceArchitecture.esp32s3, // TDISPLAY_S3_PRO
  // ESP32-C6
  83: DeviceArchitecture.esp32c6, // TLORA_C6
  87: DeviceArchitecture.esp32c6, // MESHLINK
  111: DeviceArchitecture.esp32c6, // M5STACK_C6L
  // RP2040
  26: DeviceArchitecture.rp2040, // RAK11310
  27: DeviceArchitecture.rp2040, // SENSELORA_RP2040
  30: DeviceArchitecture.rp2040, // RP2040_LORA
  47: DeviceArchitecture.rp2040, // RPI_PICO
  76: DeviceArchitecture.rp2040, // RP2040_FEATHER_RFM95
  // RP2350
  79: DeviceArchitecture.rp2350, // RPI_PICO2
  // STM32
  72: DeviceArchitecture.stm32, // RAK3172
  73: DeviceArchitecture.stm32, // WIO_E5
  // Special / not flashable in-app
  37: DeviceArchitecture.unknown, // PORTDUINO (Linux native)
  38: DeviceArchitecture.unknown, // ANDROID_SIM
  255: DeviceArchitecture.unknown, // PRIVATE_HW
};

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
