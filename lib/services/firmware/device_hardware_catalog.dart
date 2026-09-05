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
    135: DeviceArchitecture.nrf52840, // T_IMPULSE_PLUS
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
    // esp32s3
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
    126: DeviceArchitecture.esp32s3, // TDISPLAY_S3_PRO
    132: DeviceArchitecture.esp32s3, // HELTEC_V4_R8 (proto comment)
    // esp32c6
    87: DeviceArchitecture.esp32c6, // MESHLINK
    // rp2040
    76: DeviceArchitecture.rp2040, // RP2040_FEATHER_RFM95
    // rp2350
    79: DeviceArchitecture.rp2350, // RPI_PICO2
    // stm32 (not in upstream JSON)
    72: DeviceArchitecture.stm32, // RAK3172
    73: DeviceArchitecture.stm32, // WIO_E5
    // unknown / not flashable in-app
    37: DeviceArchitecture.unknown, // PORTDUINO (Linux native)
    38: DeviceArchitecture.unknown, // ANDROID_SIM
    // Protobuf 2.8 reassigned values 27 and 28 from the retired SenseLoRa
    // boards to Makerfabs hardware. Neither the upstream JSON nor a firmware
    // variant exists for them yet, so the MCU is unconfirmed. Mapped to
    // unknown rather than inheriting the SenseLoRa architectures that used
    // to sit on these numbers.
    27: DeviceArchitecture.unknown, // MAKERFABS_TRACKER
    28: DeviceArchitecture.unknown, // MAKERFABS_RESERVED
    // Elecrow CrowPanel Advance P4 — ESP32-P4, an architecture meshtastic
    // firmware does not yet publish a release asset for. Mapped to unknown so
    // the update flow reports "not supported" instead of routing to a
    // nonexistent firmware-esp32p4- archive (404 on OTA).
    138: DeviceArchitecture.unknown, // CROWPANEL_P4
    // MeshPager X2: protobuf 2.8 adds the hwModel but neither the upstream
    // JSON nor a firmware variant lists it yet, so the MCU is unconfirmed.
    // Mapped to unknown until verified rather than guessing a DFU path.
    146: DeviceArchitecture.unknown, // MESHPAGER_X2
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
