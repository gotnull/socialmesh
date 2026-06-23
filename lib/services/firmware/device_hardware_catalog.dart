// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'hardware_architecture.dart' show DeviceArchitecture;

// Singleton catalog that resolves Meshtastic HardwareModel integers into
// DeviceArchitecture values. The authoritative source is the upstream
// hardware table at api.meshtastic.org/resource/deviceHardware, bundled
// here as `assets/device_hardware.json` and refreshed by
// `scripts/fetch_device_hardware.sh`.
//
// The bundled table does not cover every HardwareModel value in our
// protobufs (stm32, rp2350, specials such as PORTDUINO/PRIVATE_HW, and
// any HardwareModel added after the last upstream refresh). Those live
// in `_supplement` below. JSON entries always win when both exist —
// enforced by `test/services/firmware/hardware_architecture_test.dart`.
//
// `load()` must be awaited before `runApp` (see `lib/main.dart`).
// Lookups before load() return DeviceArchitecture.unknown so the firmware
// update flow degrades gracefully rather than crashing.
class DeviceHardwareCatalog {
  DeviceHardwareCatalog._();

  static final DeviceHardwareCatalog instance = DeviceHardwareCatalog._();

  static const _assetPath = 'assets/device_hardware.json';

  Map<int, DeviceArchitecture>? _archByHwModel;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Maps the upstream `architecture` string field to our DeviceArchitecture
  // enum. `stm32wl` is treated the same as `stm32` since both are STM32
  // variants from our DFU perspective. `portduino` is a Linux native build
  // and is not flashable from the app.
  static const _archFromString = <String, DeviceArchitecture>{
    'esp32': DeviceArchitecture.esp32,
    'esp32-c3': DeviceArchitecture.esp32c3,
    'esp32-c6': DeviceArchitecture.esp32c6,
    'esp32-s3': DeviceArchitecture.esp32s3,
    'nrf52840': DeviceArchitecture.nrf52840,
    'rp2040': DeviceArchitecture.rp2040,
    'rp2350': DeviceArchitecture.rp2350,
    'stm32': DeviceArchitecture.stm32,
    'stm32wl': DeviceArchitecture.stm32,
    'portduino': DeviceArchitecture.unknown,
  };

  // Entries not covered by the upstream JSON catalog. Carries the
  // architecture values that the previous hand-maintained map asserted for
  // these hwModels — not authoritatively verified against upstream, but
  // preserved to avoid regressions until the upstream JSON catches up.
  // Shrink this table when upstream adds coverage; the parity test will
  // flag any supplement entry that the JSON now covers.
  static const _supplement = <int, DeviceArchitecture>{
    // nrf52840
    23: DeviceArchitecture.nrf52840, // HELTEC_HRU_3601
    34: DeviceArchitecture.nrf52840, // PPR
    36: DeviceArchitecture.nrf52840, // NRF52_UNKNOWN
    40: DeviceArchitecture.nrf52840, // NRF52840_PCA10059
    75: DeviceArchitecture.nrf52840, // ME25LS01_4Y10TD
    82: DeviceArchitecture.nrf52840, // MS24SF1
    118: DeviceArchitecture.nrf52840, // RAK6421
    121: DeviceArchitecture.nrf52840, // MESHSTICK_1262
    127: DeviceArchitecture.nrf52840, // HELTEC_MESH_NODE_T096
    128: DeviceArchitecture.nrf52840, // TRACKER_T1000_E_PRO (proto comment)
    133: DeviceArchitecture.nrf52840, // HELTEC_MESH_NODE_T1 (proto comment)
    135: DeviceArchitecture.nrf52840, // T_IMPULSE_PLUS
    136: DeviceArchitecture.nrf52840, // T_ECHO_CARD
    139: DeviceArchitecture.nrf52840, // HELTEC_MESH_TOWER_V2 (firmware variant)
    // esp32
    19: DeviceArchitecture.esp32, // LORA_TYPE
    20: DeviceArchitecture.esp32, // WIPHONE
    24: DeviceArchitecture.esp32, // HELTEC_WIRELESS_BRIDGE
    32: DeviceArchitecture.esp32, // LORA_RELAY_V1
    35: DeviceArchitecture.esp32, // GENIEBLOCKS
    45: DeviceArchitecture.esp32, // BETAFPV_2400_TX
    46: DeviceArchitecture.esp32, // BETAFPV_900_NANO_TX
    56: DeviceArchitecture.esp32, // CHATTER_2
    74: DeviceArchitecture.esp32, // RADIOMASTER_900_BANDIT
    77: DeviceArchitecture.esp32, // M5STACK_COREBASIC
    78: DeviceArchitecture.esp32, // M5STACK_CORE2
    124: DeviceArchitecture.esp32, // TBEAM_BPF
    // esp32s3
    28: DeviceArchitecture.esp32s3, // SENSELORA_S3
    54: DeviceArchitecture.esp32s3, // EBYTE_ESP32_S3
    55: DeviceArchitecture.esp32s3, // ESP32_S3_PICO
    60: DeviceArchitecture.esp32s3, // TD_LORAC
    62: DeviceArchitecture.esp32s3, // TWC_MESH_V4
    65: DeviceArchitecture.esp32s3, // HELTEC_CAPSULE_SENSOR_V3
    80: DeviceArchitecture.esp32s3, // M5STACK_CORES3
    85: DeviceArchitecture.esp32s3, // ROUTASTIC
    86: DeviceArchitecture.esp32s3, // MESH_TAB
    91: DeviceArchitecture.esp32s3, // T_ETH_ELITE
    92: DeviceArchitecture.esp32s3, // HELTEC_SENSOR_HUB
    98: DeviceArchitecture.esp32s3, // LINK_32
    104: DeviceArchitecture.esp32s3, // M5STACK_RESERVED
    114: DeviceArchitecture.esp32s3, // T_WATCH_ULTRA
    126: DeviceArchitecture.esp32s3, // TDISPLAY_S3_PRO
    132: DeviceArchitecture.esp32s3, // HELTEC_V4_R8 (proto comment)
    134: DeviceArchitecture.esp32s3, // STATION_G3 (firmware variant)
    // esp32c6
    83: DeviceArchitecture.esp32c6, // TLORA_C6
    87: DeviceArchitecture.esp32c6, // MESHLINK
    // rp2040
    27: DeviceArchitecture.rp2040, // SENSELORA_RP2040
    76: DeviceArchitecture.rp2040, // RP2040_FEATHER_RFM95
    // rp2350
    79: DeviceArchitecture.rp2350, // RPI_PICO2
    // stm32 (not in upstream JSON)
    72: DeviceArchitecture.stm32, // RAK3172
    73: DeviceArchitecture.stm32, // WIO_E5
    // unknown / not flashable in-app
    37: DeviceArchitecture.unknown, // PORTDUINO (Linux native)
    38: DeviceArchitecture.unknown, // ANDROID_SIM
    // Chipset unconfirmed — proto comment bundles M7/M8/M9 with no MCU and
    // upstream JSON has not yet listed them. Mapped to unknown so the DFU
    // flow correctly reports "update not supported" instead of routing to
    // the wrong update path.
    129: DeviceArchitecture.unknown, // THINKNODE_M7
    130: DeviceArchitecture.unknown, // THINKNODE_M8
    131: DeviceArchitecture.unknown, // THINKNODE_M9
    // Seeed Tracker L2 — proto comment omits the MCU and the upstream JSON
    // has not listed it yet, so the chipset is unconfirmed. Mapped to unknown
    // until verified rather than guessing a DFU path.
    137: DeviceArchitecture.unknown, // SEEED_WIO_TRACKER_L2
    // Elecrow CrowPanel Advance P4 — ESP32-P4, an architecture meshtastic
    // firmware does not yet publish a release asset for. Mapped to unknown so
    // the update flow reports "not supported" instead of routing to a
    // nonexistent firmware-esp32p4- archive (404 on OTA).
    138: DeviceArchitecture.unknown, // CROWPANEL_P4
    // Meshnology W10: proto adds the hwModel but the upstream firmware has not
    // published a variant or board file yet, so the MCU is unconfirmed. Mapped
    // to unknown until verified rather than guessing a DFU path.
    140: DeviceArchitecture.unknown, // MESHNOLOGY_W10
    255: DeviceArchitecture.unknown, // PRIVATE_HW
  };

  // Loads `assets/device_hardware.json` and merges it with the supplement
  // map. Idempotent. Call once from `main()` before `runApp` (mirrors
  // `ProfanityChecker.instance.load()`).
  Future<void> load() async {
    if (_isLoaded) return;
    final merged = <int, DeviceArchitecture>{..._supplement};
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final entries = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      for (final entry in entries) {
        final hwModel = entry['hwModel'];
        final archStr = entry['architecture'];
        if (hwModel is! int || archStr is! String) continue;
        final arch = _archFromString[archStr];
        if (arch == null) continue;
        merged[hwModel] = arch;
      }
    } catch (_) {
      // Fall back to supplement-only if the asset is missing or corrupt.
      // Keeps the firmware flow operable for stm32/rp2350/specials.
    }
    _archByHwModel = merged;
    _isLoaded = true;
  }

  // Synchronous lookup. Returns DeviceArchitecture.unknown for any
  // hwModel not covered (including all hwModels if `load()` has not run).
  DeviceArchitecture architectureFor(int? hwModel) {
    if (hwModel == null) return DeviceArchitecture.unknown;
    return _archByHwModel?[hwModel] ?? DeviceArchitecture.unknown;
  }

  // The set of hwModel integers this catalog can resolve. Used by the
  // parity test to enforce coverage of every protobuf HardwareModel value.
  Set<int> get mappedHwModelValues => _archByHwModel?.keys.toSet() ?? const {};

  // Test hook: resets to unloaded state so a test group can re-run load()
  // against a fresh fixture. Production code should never call this.
  void resetForTesting() {
    _archByHwModel = null;
    _isLoaded = false;
  }
}
