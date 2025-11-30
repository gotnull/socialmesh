// This is a generated file - do not edit.
//
// Generated from meshtastic/mesh.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// User role
class Config_DeviceConfig_Role extends $pb.ProtobufEnum {
  static const Config_DeviceConfig_Role CLIENT =
      Config_DeviceConfig_Role._(0, _omitEnumNames ? '' : 'CLIENT');
  static const Config_DeviceConfig_Role CLIENT_MUTE =
      Config_DeviceConfig_Role._(1, _omitEnumNames ? '' : 'CLIENT_MUTE');
  static const Config_DeviceConfig_Role ROUTER =
      Config_DeviceConfig_Role._(2, _omitEnumNames ? '' : 'ROUTER');
  static const Config_DeviceConfig_Role ROUTER_CLIENT =
      Config_DeviceConfig_Role._(3, _omitEnumNames ? '' : 'ROUTER_CLIENT');
  static const Config_DeviceConfig_Role REPEATER =
      Config_DeviceConfig_Role._(4, _omitEnumNames ? '' : 'REPEATER');
  static const Config_DeviceConfig_Role TRACKER =
      Config_DeviceConfig_Role._(5, _omitEnumNames ? '' : 'TRACKER');
  static const Config_DeviceConfig_Role SENSOR =
      Config_DeviceConfig_Role._(6, _omitEnumNames ? '' : 'SENSOR');
  static const Config_DeviceConfig_Role TAK =
      Config_DeviceConfig_Role._(7, _omitEnumNames ? '' : 'TAK');
  static const Config_DeviceConfig_Role CLIENT_HIDDEN =
      Config_DeviceConfig_Role._(8, _omitEnumNames ? '' : 'CLIENT_HIDDEN');
  static const Config_DeviceConfig_Role LOST_AND_FOUND =
      Config_DeviceConfig_Role._(9, _omitEnumNames ? '' : 'LOST_AND_FOUND');
  static const Config_DeviceConfig_Role TAK_TRACKER =
      Config_DeviceConfig_Role._(10, _omitEnumNames ? '' : 'TAK_TRACKER');

  static const $core.List<Config_DeviceConfig_Role> values =
      <Config_DeviceConfig_Role>[
    CLIENT,
    CLIENT_MUTE,
    ROUTER,
    ROUTER_CLIENT,
    REPEATER,
    TRACKER,
    SENSOR,
    TAK,
    CLIENT_HIDDEN,
    LOST_AND_FOUND,
    TAK_TRACKER,
  ];

  static final $core.List<Config_DeviceConfig_Role?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static Config_DeviceConfig_Role? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DeviceConfig_Role._(super.value, super.name);
}

/// Hardware models
class HardwareModel extends $pb.ProtobufEnum {
  static const HardwareModel UNSET =
      HardwareModel._(0, _omitEnumNames ? '' : 'UNSET');
  static const HardwareModel TLORA_V2 =
      HardwareModel._(1, _omitEnumNames ? '' : 'TLORA_V2');
  static const HardwareModel TLORA_V1 =
      HardwareModel._(2, _omitEnumNames ? '' : 'TLORA_V1');
  static const HardwareModel TLORA_V2_1_1p6 =
      HardwareModel._(3, _omitEnumNames ? '' : 'TLORA_V2_1_1p6');
  static const HardwareModel TBEAM =
      HardwareModel._(4, _omitEnumNames ? '' : 'TBEAM');
  static const HardwareModel HELTEC_V2_0 =
      HardwareModel._(5, _omitEnumNames ? '' : 'HELTEC_V2_0');
  static const HardwareModel TBEAM0p7 =
      HardwareModel._(6, _omitEnumNames ? '' : 'TBEAM0p7');
  static const HardwareModel T_ECHO =
      HardwareModel._(7, _omitEnumNames ? '' : 'T_ECHO');
  static const HardwareModel TLORA_V1_1p3 =
      HardwareModel._(8, _omitEnumNames ? '' : 'TLORA_V1_1p3');
  static const HardwareModel RAK4631 =
      HardwareModel._(9, _omitEnumNames ? '' : 'RAK4631');
  static const HardwareModel HELTEC_V2_1 =
      HardwareModel._(10, _omitEnumNames ? '' : 'HELTEC_V2_1');
  static const HardwareModel HELTEC_V1 =
      HardwareModel._(11, _omitEnumNames ? '' : 'HELTEC_V1');
  static const HardwareModel LILYGO_TBEAM_S3_CORE =
      HardwareModel._(12, _omitEnumNames ? '' : 'LILYGO_TBEAM_S3_CORE');
  static const HardwareModel RAK11200 =
      HardwareModel._(13, _omitEnumNames ? '' : 'RAK11200');
  static const HardwareModel NANO_G1 =
      HardwareModel._(14, _omitEnumNames ? '' : 'NANO_G1');
  static const HardwareModel TLORA_V2_1_1p8 =
      HardwareModel._(15, _omitEnumNames ? '' : 'TLORA_V2_1_1p8');
  static const HardwareModel TLORA_T3_S3 =
      HardwareModel._(16, _omitEnumNames ? '' : 'TLORA_T3_S3');
  static const HardwareModel NANO_G1_EXPLORER =
      HardwareModel._(17, _omitEnumNames ? '' : 'NANO_G1_EXPLORER');
  static const HardwareModel NANO_G2_ULTRA =
      HardwareModel._(18, _omitEnumNames ? '' : 'NANO_G2_ULTRA');
  static const HardwareModel LORA_TYPE =
      HardwareModel._(19, _omitEnumNames ? '' : 'LORA_TYPE');
  static const HardwareModel WIPHONE =
      HardwareModel._(20, _omitEnumNames ? '' : 'WIPHONE');
  static const HardwareModel WIO_WM1110 =
      HardwareModel._(21, _omitEnumNames ? '' : 'WIO_WM1110');
  static const HardwareModel RAK2560 =
      HardwareModel._(22, _omitEnumNames ? '' : 'RAK2560');
  static const HardwareModel HELTEC_HRU_3601 =
      HardwareModel._(23, _omitEnumNames ? '' : 'HELTEC_HRU_3601');
  static const HardwareModel HELTEC_WIRELESS_PAPER =
      HardwareModel._(24, _omitEnumNames ? '' : 'HELTEC_WIRELESS_PAPER');
  static const HardwareModel STATION_G1 =
      HardwareModel._(25, _omitEnumNames ? '' : 'STATION_G1');
  static const HardwareModel RAK11310 =
      HardwareModel._(26, _omitEnumNames ? '' : 'RAK11310');
  static const HardwareModel SENSELORA_RP2040 =
      HardwareModel._(27, _omitEnumNames ? '' : 'SENSELORA_RP2040');
  static const HardwareModel SENSELORA_S3 =
      HardwareModel._(28, _omitEnumNames ? '' : 'SENSELORA_S3');
  static const HardwareModel CANARYONE =
      HardwareModel._(29, _omitEnumNames ? '' : 'CANARYONE');
  static const HardwareModel RP2040_LORA =
      HardwareModel._(30, _omitEnumNames ? '' : 'RP2040_LORA');
  static const HardwareModel STATION_G2 =
      HardwareModel._(31, _omitEnumNames ? '' : 'STATION_G2');
  static const HardwareModel LORA_RELAY_V1 =
      HardwareModel._(32, _omitEnumNames ? '' : 'LORA_RELAY_V1');
  static const HardwareModel NRF52840DK =
      HardwareModel._(33, _omitEnumNames ? '' : 'NRF52840DK');
  static const HardwareModel PPR =
      HardwareModel._(34, _omitEnumNames ? '' : 'PPR');
  static const HardwareModel GENIEBLOCKS =
      HardwareModel._(35, _omitEnumNames ? '' : 'GENIEBLOCKS');
  static const HardwareModel NRF52_UNKNOWN =
      HardwareModel._(36, _omitEnumNames ? '' : 'NRF52_UNKNOWN');
  static const HardwareModel PORTDUINO =
      HardwareModel._(37, _omitEnumNames ? '' : 'PORTDUINO');
  static const HardwareModel ANDROID_SIM =
      HardwareModel._(38, _omitEnumNames ? '' : 'ANDROID_SIM');
  static const HardwareModel DIY_V1 =
      HardwareModel._(39, _omitEnumNames ? '' : 'DIY_V1');
  static const HardwareModel NRF52840_PCA10059 =
      HardwareModel._(40, _omitEnumNames ? '' : 'NRF52840_PCA10059');
  static const HardwareModel DR_DEV =
      HardwareModel._(41, _omitEnumNames ? '' : 'DR_DEV');
  static const HardwareModel M5STACK =
      HardwareModel._(42, _omitEnumNames ? '' : 'M5STACK');
  static const HardwareModel HELTEC_V3 =
      HardwareModel._(43, _omitEnumNames ? '' : 'HELTEC_V3');
  static const HardwareModel HELTEC_WSL_V3 =
      HardwareModel._(44, _omitEnumNames ? '' : 'HELTEC_WSL_V3');
  static const HardwareModel BETAFPV_2400_TX =
      HardwareModel._(45, _omitEnumNames ? '' : 'BETAFPV_2400_TX');
  static const HardwareModel BETAFPV_900_NANO_TX =
      HardwareModel._(46, _omitEnumNames ? '' : 'BETAFPV_900_NANO_TX');
  static const HardwareModel RPI_PICO =
      HardwareModel._(47, _omitEnumNames ? '' : 'RPI_PICO');
  static const HardwareModel HELTEC_WIRELESS_TRACKER =
      HardwareModel._(48, _omitEnumNames ? '' : 'HELTEC_WIRELESS_TRACKER');
  static const HardwareModel HELTEC_WIRELESS_PAPER_V1_0 =
      HardwareModel._(49, _omitEnumNames ? '' : 'HELTEC_WIRELESS_PAPER_V1_0');
  static const HardwareModel T_DECK =
      HardwareModel._(50, _omitEnumNames ? '' : 'T_DECK');
  static const HardwareModel T_WATCH_S3 =
      HardwareModel._(51, _omitEnumNames ? '' : 'T_WATCH_S3');
  static const HardwareModel PICOMPUTER_S3 =
      HardwareModel._(52, _omitEnumNames ? '' : 'PICOMPUTER_S3');
  static const HardwareModel HELTEC_HT62 =
      HardwareModel._(53, _omitEnumNames ? '' : 'HELTEC_HT62');
  static const HardwareModel EBYTE_ESP32_S3 =
      HardwareModel._(54, _omitEnumNames ? '' : 'EBYTE_ESP32_S3');
  static const HardwareModel ESP32_S3_PICO =
      HardwareModel._(55, _omitEnumNames ? '' : 'ESP32_S3_PICO');
  static const HardwareModel CHATTER_2 =
      HardwareModel._(56, _omitEnumNames ? '' : 'CHATTER_2');
  static const HardwareModel HELTEC_WIRELESS_PAPER_V1_1 =
      HardwareModel._(57, _omitEnumNames ? '' : 'HELTEC_WIRELESS_PAPER_V1_1');
  static const HardwareModel HELTEC_CAPSULE_SENSOR_V3 =
      HardwareModel._(58, _omitEnumNames ? '' : 'HELTEC_CAPSULE_SENSOR_V3');
  static const HardwareModel HELTEC_VISION_MASTER_T190 =
      HardwareModel._(59, _omitEnumNames ? '' : 'HELTEC_VISION_MASTER_T190');
  static const HardwareModel HELTEC_VISION_MASTER_E213 =
      HardwareModel._(60, _omitEnumNames ? '' : 'HELTEC_VISION_MASTER_E213');
  static const HardwareModel HELTEC_VISION_MASTER_E290 =
      HardwareModel._(61, _omitEnumNames ? '' : 'HELTEC_VISION_MASTER_E290');
  static const HardwareModel HELTEC_MESH_NODE_T114 =
      HardwareModel._(62, _omitEnumNames ? '' : 'HELTEC_MESH_NODE_T114');
  static const HardwareModel SENSECAP_INDICATOR =
      HardwareModel._(63, _omitEnumNames ? '' : 'SENSECAP_INDICATOR');
  static const HardwareModel TRACKER_T1000_E =
      HardwareModel._(64, _omitEnumNames ? '' : 'TRACKER_T1000_E');
  static const HardwareModel RAK3172 =
      HardwareModel._(65, _omitEnumNames ? '' : 'RAK3172');
  static const HardwareModel WIO_E5 =
      HardwareModel._(66, _omitEnumNames ? '' : 'WIO_E5');
  static const HardwareModel RADIOMASTER_900_BANDIT_NANO =
      HardwareModel._(67, _omitEnumNames ? '' : 'RADIOMASTER_900_BANDIT_NANO');
  static const HardwareModel HELTEC_CAPSULE_SENSOR_V3_COMPACT = HardwareModel._(
      68, _omitEnumNames ? '' : 'HELTEC_CAPSULE_SENSOR_V3_COMPACT');
  static const HardwareModel PRIVATE_HW =
      HardwareModel._(255, _omitEnumNames ? '' : 'PRIVATE_HW');

  static const $core.List<HardwareModel> values = <HardwareModel>[
    UNSET,
    TLORA_V2,
    TLORA_V1,
    TLORA_V2_1_1p6,
    TBEAM,
    HELTEC_V2_0,
    TBEAM0p7,
    T_ECHO,
    TLORA_V1_1p3,
    RAK4631,
    HELTEC_V2_1,
    HELTEC_V1,
    LILYGO_TBEAM_S3_CORE,
    RAK11200,
    NANO_G1,
    TLORA_V2_1_1p8,
    TLORA_T3_S3,
    NANO_G1_EXPLORER,
    NANO_G2_ULTRA,
    LORA_TYPE,
    WIPHONE,
    WIO_WM1110,
    RAK2560,
    HELTEC_HRU_3601,
    HELTEC_WIRELESS_PAPER,
    STATION_G1,
    RAK11310,
    SENSELORA_RP2040,
    SENSELORA_S3,
    CANARYONE,
    RP2040_LORA,
    STATION_G2,
    LORA_RELAY_V1,
    NRF52840DK,
    PPR,
    GENIEBLOCKS,
    NRF52_UNKNOWN,
    PORTDUINO,
    ANDROID_SIM,
    DIY_V1,
    NRF52840_PCA10059,
    DR_DEV,
    M5STACK,
    HELTEC_V3,
    HELTEC_WSL_V3,
    BETAFPV_2400_TX,
    BETAFPV_900_NANO_TX,
    RPI_PICO,
    HELTEC_WIRELESS_TRACKER,
    HELTEC_WIRELESS_PAPER_V1_0,
    T_DECK,
    T_WATCH_S3,
    PICOMPUTER_S3,
    HELTEC_HT62,
    EBYTE_ESP32_S3,
    ESP32_S3_PICO,
    CHATTER_2,
    HELTEC_WIRELESS_PAPER_V1_1,
    HELTEC_CAPSULE_SENSOR_V3,
    HELTEC_VISION_MASTER_T190,
    HELTEC_VISION_MASTER_E213,
    HELTEC_VISION_MASTER_E290,
    HELTEC_MESH_NODE_T114,
    SENSECAP_INDICATOR,
    TRACKER_T1000_E,
    RAK3172,
    WIO_E5,
    RADIOMASTER_900_BANDIT_NANO,
    HELTEC_CAPSULE_SENSOR_V3_COMPACT,
    PRIVATE_HW,
  ];

  static final $core.Map<$core.int, HardwareModel> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static HardwareModel? valueOf($core.int value) => _byValue[value];

  const HardwareModel._(super.value, super.name);
}

/// Data packet types
class PortNum extends $pb.ProtobufEnum {
  static const PortNum UNKNOWN_APP =
      PortNum._(0, _omitEnumNames ? '' : 'UNKNOWN_APP');
  static const PortNum TEXT_MESSAGE_APP =
      PortNum._(1, _omitEnumNames ? '' : 'TEXT_MESSAGE_APP');
  static const PortNum REMOTE_HARDWARE_APP =
      PortNum._(2, _omitEnumNames ? '' : 'REMOTE_HARDWARE_APP');
  static const PortNum POSITION_APP =
      PortNum._(3, _omitEnumNames ? '' : 'POSITION_APP');
  static const PortNum NODEINFO_APP =
      PortNum._(4, _omitEnumNames ? '' : 'NODEINFO_APP');
  static const PortNum ROUTING_APP =
      PortNum._(5, _omitEnumNames ? '' : 'ROUTING_APP');
  static const PortNum ADMIN_APP =
      PortNum._(6, _omitEnumNames ? '' : 'ADMIN_APP');
  static const PortNum TEXT_MESSAGE_COMPRESSED_APP =
      PortNum._(7, _omitEnumNames ? '' : 'TEXT_MESSAGE_COMPRESSED_APP');
  static const PortNum WAYPOINT_APP =
      PortNum._(8, _omitEnumNames ? '' : 'WAYPOINT_APP');
  static const PortNum AUDIO_APP =
      PortNum._(9, _omitEnumNames ? '' : 'AUDIO_APP');
  static const PortNum DETECTION_SENSOR_APP =
      PortNum._(10, _omitEnumNames ? '' : 'DETECTION_SENSOR_APP');
  static const PortNum REPLY_APP =
      PortNum._(32, _omitEnumNames ? '' : 'REPLY_APP');
  static const PortNum IP_TUNNEL_APP =
      PortNum._(33, _omitEnumNames ? '' : 'IP_TUNNEL_APP');
  static const PortNum SERIAL_APP =
      PortNum._(64, _omitEnumNames ? '' : 'SERIAL_APP');
  static const PortNum STORE_FORWARD_APP =
      PortNum._(65, _omitEnumNames ? '' : 'STORE_FORWARD_APP');
  static const PortNum RANGE_TEST_APP =
      PortNum._(66, _omitEnumNames ? '' : 'RANGE_TEST_APP');
  static const PortNum TELEMETRY_APP =
      PortNum._(67, _omitEnumNames ? '' : 'TELEMETRY_APP');
  static const PortNum ZPS_APP = PortNum._(68, _omitEnumNames ? '' : 'ZPS_APP');
  static const PortNum SIMULATOR_APP =
      PortNum._(69, _omitEnumNames ? '' : 'SIMULATOR_APP');
  static const PortNum TRACEROUTE_APP =
      PortNum._(70, _omitEnumNames ? '' : 'TRACEROUTE_APP');
  static const PortNum NEIGHBORINFO_APP =
      PortNum._(71, _omitEnumNames ? '' : 'NEIGHBORINFO_APP');
  static const PortNum ATAK_PLUGIN =
      PortNum._(72, _omitEnumNames ? '' : 'ATAK_PLUGIN');
  static const PortNum PRIVATE_APP =
      PortNum._(256, _omitEnumNames ? '' : 'PRIVATE_APP');
  static const PortNum ATAK_FORWARDER =
      PortNum._(257, _omitEnumNames ? '' : 'ATAK_FORWARDER');
  static const PortNum MAX = PortNum._(511, _omitEnumNames ? '' : 'MAX');

  static const $core.List<PortNum> values = <PortNum>[
    UNKNOWN_APP,
    TEXT_MESSAGE_APP,
    REMOTE_HARDWARE_APP,
    POSITION_APP,
    NODEINFO_APP,
    ROUTING_APP,
    ADMIN_APP,
    TEXT_MESSAGE_COMPRESSED_APP,
    WAYPOINT_APP,
    AUDIO_APP,
    DETECTION_SENSOR_APP,
    REPLY_APP,
    IP_TUNNEL_APP,
    SERIAL_APP,
    STORE_FORWARD_APP,
    RANGE_TEST_APP,
    TELEMETRY_APP,
    ZPS_APP,
    SIMULATOR_APP,
    TRACEROUTE_APP,
    NEIGHBORINFO_APP,
    ATAK_PLUGIN,
    PRIVATE_APP,
    ATAK_FORWARDER,
    MAX,
  ];

  static final $core.Map<$core.int, PortNum> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static PortNum? valueOf($core.int value) => _byValue[value];

  const PortNum._(super.value, super.name);
}

/// Remote hardware pin type
class RemoteHardwarePinType extends $pb.ProtobufEnum {
  static const RemoteHardwarePinType UNKNOWN_TYPE =
      RemoteHardwarePinType._(0, _omitEnumNames ? '' : 'UNKNOWN_TYPE');
  static const RemoteHardwarePinType DIGITAL_READ =
      RemoteHardwarePinType._(1, _omitEnumNames ? '' : 'DIGITAL_READ');
  static const RemoteHardwarePinType DIGITAL_WRITE =
      RemoteHardwarePinType._(2, _omitEnumNames ? '' : 'DIGITAL_WRITE');

  static const $core.List<RemoteHardwarePinType> values =
      <RemoteHardwarePinType>[
    UNKNOWN_TYPE,
    DIGITAL_READ,
    DIGITAL_WRITE,
  ];

  static final $core.List<RemoteHardwarePinType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RemoteHardwarePinType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RemoteHardwarePinType._(super.value, super.name);
}

/// Modem presets
class ModemPreset extends $pb.ProtobufEnum {
  static const ModemPreset LONG_FAST =
      ModemPreset._(0, _omitEnumNames ? '' : 'LONG_FAST');
  static const ModemPreset LONG_SLOW =
      ModemPreset._(1, _omitEnumNames ? '' : 'LONG_SLOW');
  static const ModemPreset VERY_LONG_SLOW =
      ModemPreset._(2, _omitEnumNames ? '' : 'VERY_LONG_SLOW');
  static const ModemPreset MEDIUM_SLOW =
      ModemPreset._(3, _omitEnumNames ? '' : 'MEDIUM_SLOW');
  static const ModemPreset MEDIUM_FAST =
      ModemPreset._(4, _omitEnumNames ? '' : 'MEDIUM_FAST');
  static const ModemPreset SHORT_SLOW =
      ModemPreset._(5, _omitEnumNames ? '' : 'SHORT_SLOW');
  static const ModemPreset SHORT_FAST =
      ModemPreset._(6, _omitEnumNames ? '' : 'SHORT_FAST');
  static const ModemPreset LONG_MODERATE =
      ModemPreset._(7, _omitEnumNames ? '' : 'LONG_MODERATE');

  static const $core.List<ModemPreset> values = <ModemPreset>[
    LONG_FAST,
    LONG_SLOW,
    VERY_LONG_SLOW,
    MEDIUM_SLOW,
    MEDIUM_FAST,
    SHORT_SLOW,
    SHORT_FAST,
    LONG_MODERATE,
  ];

  static final $core.List<ModemPreset?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static ModemPreset? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModemPreset._(super.value, super.name);
}

/// Region codes
class RegionCode extends $pb.ProtobufEnum {
  static const RegionCode UNSET_REGION =
      RegionCode._(0, _omitEnumNames ? '' : 'UNSET_REGION');
  static const RegionCode US = RegionCode._(1, _omitEnumNames ? '' : 'US');
  static const RegionCode EU_433 =
      RegionCode._(2, _omitEnumNames ? '' : 'EU_433');
  static const RegionCode EU_868 =
      RegionCode._(3, _omitEnumNames ? '' : 'EU_868');
  static const RegionCode CN = RegionCode._(4, _omitEnumNames ? '' : 'CN');
  static const RegionCode JP = RegionCode._(5, _omitEnumNames ? '' : 'JP');
  static const RegionCode ANZ = RegionCode._(6, _omitEnumNames ? '' : 'ANZ');
  static const RegionCode KR = RegionCode._(7, _omitEnumNames ? '' : 'KR');
  static const RegionCode TW = RegionCode._(8, _omitEnumNames ? '' : 'TW');
  static const RegionCode RU = RegionCode._(9, _omitEnumNames ? '' : 'RU');
  static const RegionCode IN = RegionCode._(10, _omitEnumNames ? '' : 'IN');
  static const RegionCode NZ_865 =
      RegionCode._(11, _omitEnumNames ? '' : 'NZ_865');
  static const RegionCode TH = RegionCode._(12, _omitEnumNames ? '' : 'TH');
  static const RegionCode LORA_24 =
      RegionCode._(13, _omitEnumNames ? '' : 'LORA_24');
  static const RegionCode UA_433 =
      RegionCode._(14, _omitEnumNames ? '' : 'UA_433');
  static const RegionCode UA_868 =
      RegionCode._(15, _omitEnumNames ? '' : 'UA_868');
  static const RegionCode MY_433 =
      RegionCode._(16, _omitEnumNames ? '' : 'MY_433');
  static const RegionCode MY_919 =
      RegionCode._(17, _omitEnumNames ? '' : 'MY_919');
  static const RegionCode SG_923 =
      RegionCode._(18, _omitEnumNames ? '' : 'SG_923');

  static const $core.List<RegionCode> values = <RegionCode>[
    UNSET_REGION,
    US,
    EU_433,
    EU_868,
    CN,
    JP,
    ANZ,
    KR,
    TW,
    RU,
    IN,
    NZ_865,
    TH,
    LORA_24,
    UA_433,
    UA_868,
    MY_433,
    MY_919,
    SG_923,
  ];

  static final $core.List<RegionCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 18);
  static RegionCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RegionCode._(super.value, super.name);
}

class Channel_Role extends $pb.ProtobufEnum {
  static const Channel_Role DISABLED =
      Channel_Role._(0, _omitEnumNames ? '' : 'DISABLED');
  static const Channel_Role PRIMARY =
      Channel_Role._(1, _omitEnumNames ? '' : 'PRIMARY');
  static const Channel_Role SECONDARY =
      Channel_Role._(2, _omitEnumNames ? '' : 'SECONDARY');

  static const $core.List<Channel_Role> values = <Channel_Role>[
    DISABLED,
    PRIMARY,
    SECONDARY,
  ];

  static final $core.List<Channel_Role?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Channel_Role? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Channel_Role._(super.value, super.name);
}

/// Config type enum for get_config_request
class AdminMessage_ConfigType extends $pb.ProtobufEnum {
  static const AdminMessage_ConfigType DEVICE_CONFIG =
      AdminMessage_ConfigType._(0, _omitEnumNames ? '' : 'DEVICE_CONFIG');
  static const AdminMessage_ConfigType POSITION_CONFIG =
      AdminMessage_ConfigType._(1, _omitEnumNames ? '' : 'POSITION_CONFIG');
  static const AdminMessage_ConfigType POWER_CONFIG =
      AdminMessage_ConfigType._(2, _omitEnumNames ? '' : 'POWER_CONFIG');
  static const AdminMessage_ConfigType NETWORK_CONFIG =
      AdminMessage_ConfigType._(3, _omitEnumNames ? '' : 'NETWORK_CONFIG');
  static const AdminMessage_ConfigType DISPLAY_CONFIG =
      AdminMessage_ConfigType._(4, _omitEnumNames ? '' : 'DISPLAY_CONFIG');
  static const AdminMessage_ConfigType LORA_CONFIG =
      AdminMessage_ConfigType._(5, _omitEnumNames ? '' : 'LORA_CONFIG');
  static const AdminMessage_ConfigType BLUETOOTH_CONFIG =
      AdminMessage_ConfigType._(6, _omitEnumNames ? '' : 'BLUETOOTH_CONFIG');
  static const AdminMessage_ConfigType SECURITY_CONFIG =
      AdminMessage_ConfigType._(7, _omitEnumNames ? '' : 'SECURITY_CONFIG');
  static const AdminMessage_ConfigType SESSIONKEY_CONFIG =
      AdminMessage_ConfigType._(8, _omitEnumNames ? '' : 'SESSIONKEY_CONFIG');
  static const AdminMessage_ConfigType DEVICEUI_CONFIG =
      AdminMessage_ConfigType._(9, _omitEnumNames ? '' : 'DEVICEUI_CONFIG');

  static const $core.List<AdminMessage_ConfigType> values =
      <AdminMessage_ConfigType>[
    DEVICE_CONFIG,
    POSITION_CONFIG,
    POWER_CONFIG,
    NETWORK_CONFIG,
    DISPLAY_CONFIG,
    LORA_CONFIG,
    BLUETOOTH_CONFIG,
    SECURITY_CONFIG,
    SESSIONKEY_CONFIG,
    DEVICEUI_CONFIG,
  ];

  static final $core.List<AdminMessage_ConfigType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static AdminMessage_ConfigType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AdminMessage_ConfigType._(super.value, super.name);
}

/// Module config type enum for get_module_config_request
class AdminMessage_ModuleConfigType extends $pb.ProtobufEnum {
  static const AdminMessage_ModuleConfigType MQTT_CONFIG =
      AdminMessage_ModuleConfigType._(0, _omitEnumNames ? '' : 'MQTT_CONFIG');
  static const AdminMessage_ModuleConfigType SERIAL_CONFIG =
      AdminMessage_ModuleConfigType._(1, _omitEnumNames ? '' : 'SERIAL_CONFIG');
  static const AdminMessage_ModuleConfigType EXTNOTIF_CONFIG =
      AdminMessage_ModuleConfigType._(
          2, _omitEnumNames ? '' : 'EXTNOTIF_CONFIG');
  static const AdminMessage_ModuleConfigType STOREFORWARD_CONFIG =
      AdminMessage_ModuleConfigType._(
          3, _omitEnumNames ? '' : 'STOREFORWARD_CONFIG');
  static const AdminMessage_ModuleConfigType RANGETEST_CONFIG =
      AdminMessage_ModuleConfigType._(
          4, _omitEnumNames ? '' : 'RANGETEST_CONFIG');
  static const AdminMessage_ModuleConfigType TELEMETRY_CONFIG =
      AdminMessage_ModuleConfigType._(
          5, _omitEnumNames ? '' : 'TELEMETRY_CONFIG');
  static const AdminMessage_ModuleConfigType CANNEDMSG_CONFIG =
      AdminMessage_ModuleConfigType._(
          6, _omitEnumNames ? '' : 'CANNEDMSG_CONFIG');
  static const AdminMessage_ModuleConfigType AUDIO_CONFIG =
      AdminMessage_ModuleConfigType._(7, _omitEnumNames ? '' : 'AUDIO_CONFIG');
  static const AdminMessage_ModuleConfigType REMOTEHARDWARE_CONFIG =
      AdminMessage_ModuleConfigType._(
          8, _omitEnumNames ? '' : 'REMOTEHARDWARE_CONFIG');
  static const AdminMessage_ModuleConfigType NEIGHBORINFO_CONFIG =
      AdminMessage_ModuleConfigType._(
          9, _omitEnumNames ? '' : 'NEIGHBORINFO_CONFIG');
  static const AdminMessage_ModuleConfigType AMBIENTLIGHTING_CONFIG =
      AdminMessage_ModuleConfigType._(
          10, _omitEnumNames ? '' : 'AMBIENTLIGHTING_CONFIG');
  static const AdminMessage_ModuleConfigType DETECTIONSENSOR_CONFIG =
      AdminMessage_ModuleConfigType._(
          11, _omitEnumNames ? '' : 'DETECTIONSENSOR_CONFIG');
  static const AdminMessage_ModuleConfigType PAXCOUNTER_CONFIG =
      AdminMessage_ModuleConfigType._(
          12, _omitEnumNames ? '' : 'PAXCOUNTER_CONFIG');

  static const $core.List<AdminMessage_ModuleConfigType> values =
      <AdminMessage_ModuleConfigType>[
    MQTT_CONFIG,
    SERIAL_CONFIG,
    EXTNOTIF_CONFIG,
    STOREFORWARD_CONFIG,
    RANGETEST_CONFIG,
    TELEMETRY_CONFIG,
    CANNEDMSG_CONFIG,
    AUDIO_CONFIG,
    REMOTEHARDWARE_CONFIG,
    NEIGHBORINFO_CONFIG,
    AMBIENTLIGHTING_CONFIG,
    DETECTIONSENSOR_CONFIG,
    PAXCOUNTER_CONFIG,
  ];

  static final $core.List<AdminMessage_ModuleConfigType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static AdminMessage_ModuleConfigType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AdminMessage_ModuleConfigType._(super.value, super.name);
}

/// Device role on mesh network
class Config_DeviceConfig_Role_ extends $pb.ProtobufEnum {
  static const Config_DeviceConfig_Role_ CLIENT =
      Config_DeviceConfig_Role_._(0, _omitEnumNames ? '' : 'CLIENT');
  static const Config_DeviceConfig_Role_ CLIENT_MUTE =
      Config_DeviceConfig_Role_._(1, _omitEnumNames ? '' : 'CLIENT_MUTE');
  static const Config_DeviceConfig_Role_ ROUTER =
      Config_DeviceConfig_Role_._(2, _omitEnumNames ? '' : 'ROUTER');
  static const Config_DeviceConfig_Role_ ROUTER_CLIENT =
      Config_DeviceConfig_Role_._(3, _omitEnumNames ? '' : 'ROUTER_CLIENT');
  static const Config_DeviceConfig_Role_ REPEATER =
      Config_DeviceConfig_Role_._(4, _omitEnumNames ? '' : 'REPEATER');
  static const Config_DeviceConfig_Role_ TRACKER =
      Config_DeviceConfig_Role_._(5, _omitEnumNames ? '' : 'TRACKER');
  static const Config_DeviceConfig_Role_ SENSOR =
      Config_DeviceConfig_Role_._(6, _omitEnumNames ? '' : 'SENSOR');
  static const Config_DeviceConfig_Role_ TAK =
      Config_DeviceConfig_Role_._(7, _omitEnumNames ? '' : 'TAK');
  static const Config_DeviceConfig_Role_ CLIENT_HIDDEN =
      Config_DeviceConfig_Role_._(8, _omitEnumNames ? '' : 'CLIENT_HIDDEN');
  static const Config_DeviceConfig_Role_ LOST_AND_FOUND =
      Config_DeviceConfig_Role_._(9, _omitEnumNames ? '' : 'LOST_AND_FOUND');
  static const Config_DeviceConfig_Role_ TAK_TRACKER =
      Config_DeviceConfig_Role_._(10, _omitEnumNames ? '' : 'TAK_TRACKER');
  static const Config_DeviceConfig_Role_ ROUTER_LATE =
      Config_DeviceConfig_Role_._(11, _omitEnumNames ? '' : 'ROUTER_LATE');
  static const Config_DeviceConfig_Role_ CLIENT_BASE =
      Config_DeviceConfig_Role_._(12, _omitEnumNames ? '' : 'CLIENT_BASE');

  static const $core.List<Config_DeviceConfig_Role_> values =
      <Config_DeviceConfig_Role_>[
    CLIENT,
    CLIENT_MUTE,
    ROUTER,
    ROUTER_CLIENT,
    REPEATER,
    TRACKER,
    SENSOR,
    TAK,
    CLIENT_HIDDEN,
    LOST_AND_FOUND,
    TAK_TRACKER,
    ROUTER_LATE,
    CLIENT_BASE,
  ];

  static final $core.List<Config_DeviceConfig_Role_?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static Config_DeviceConfig_Role_? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DeviceConfig_Role_._(super.value, super.name);
}

/// Rebroadcast mode
class Config_DeviceConfig_RebroadcastMode extends $pb.ProtobufEnum {
  static const Config_DeviceConfig_RebroadcastMode ALL =
      Config_DeviceConfig_RebroadcastMode._(0, _omitEnumNames ? '' : 'ALL');
  static const Config_DeviceConfig_RebroadcastMode ALL_SKIP_DECODING =
      Config_DeviceConfig_RebroadcastMode._(
          1, _omitEnumNames ? '' : 'ALL_SKIP_DECODING');
  static const Config_DeviceConfig_RebroadcastMode LOCAL_ONLY =
      Config_DeviceConfig_RebroadcastMode._(
          2, _omitEnumNames ? '' : 'LOCAL_ONLY');
  static const Config_DeviceConfig_RebroadcastMode KNOWN_ONLY =
      Config_DeviceConfig_RebroadcastMode._(
          3, _omitEnumNames ? '' : 'KNOWN_ONLY');
  static const Config_DeviceConfig_RebroadcastMode NONE =
      Config_DeviceConfig_RebroadcastMode._(4, _omitEnumNames ? '' : 'NONE');
  static const Config_DeviceConfig_RebroadcastMode CORE_PORTNUMS_ONLY =
      Config_DeviceConfig_RebroadcastMode._(
          5, _omitEnumNames ? '' : 'CORE_PORTNUMS_ONLY');

  static const $core.List<Config_DeviceConfig_RebroadcastMode> values =
      <Config_DeviceConfig_RebroadcastMode>[
    ALL,
    ALL_SKIP_DECODING,
    LOCAL_ONLY,
    KNOWN_ONLY,
    NONE,
    CORE_PORTNUMS_ONLY,
  ];

  static final $core.List<Config_DeviceConfig_RebroadcastMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static Config_DeviceConfig_RebroadcastMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DeviceConfig_RebroadcastMode._(super.value, super.name);
}

class Config_PositionConfig_GpsMode extends $pb.ProtobufEnum {
  static const Config_PositionConfig_GpsMode DISABLED =
      Config_PositionConfig_GpsMode._(0, _omitEnumNames ? '' : 'DISABLED');
  static const Config_PositionConfig_GpsMode ENABLED =
      Config_PositionConfig_GpsMode._(1, _omitEnumNames ? '' : 'ENABLED');
  static const Config_PositionConfig_GpsMode NOT_PRESENT =
      Config_PositionConfig_GpsMode._(2, _omitEnumNames ? '' : 'NOT_PRESENT');

  static const $core.List<Config_PositionConfig_GpsMode> values =
      <Config_PositionConfig_GpsMode>[
    DISABLED,
    ENABLED,
    NOT_PRESENT,
  ];

  static final $core.List<Config_PositionConfig_GpsMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Config_PositionConfig_GpsMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_PositionConfig_GpsMode._(super.value, super.name);
}

class Config_NetworkConfig_AddressMode extends $pb.ProtobufEnum {
  static const Config_NetworkConfig_AddressMode DHCP =
      Config_NetworkConfig_AddressMode._(0, _omitEnumNames ? '' : 'DHCP');
  static const Config_NetworkConfig_AddressMode STATIC =
      Config_NetworkConfig_AddressMode._(1, _omitEnumNames ? '' : 'STATIC');

  static const $core.List<Config_NetworkConfig_AddressMode> values =
      <Config_NetworkConfig_AddressMode>[
    DHCP,
    STATIC,
  ];

  static final $core.List<Config_NetworkConfig_AddressMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Config_NetworkConfig_AddressMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_NetworkConfig_AddressMode._(super.value, super.name);
}

class Config_DisplayConfig_DisplayUnits extends $pb.ProtobufEnum {
  static const Config_DisplayConfig_DisplayUnits METRIC =
      Config_DisplayConfig_DisplayUnits._(0, _omitEnumNames ? '' : 'METRIC');
  static const Config_DisplayConfig_DisplayUnits IMPERIAL =
      Config_DisplayConfig_DisplayUnits._(1, _omitEnumNames ? '' : 'IMPERIAL');

  static const $core.List<Config_DisplayConfig_DisplayUnits> values =
      <Config_DisplayConfig_DisplayUnits>[
    METRIC,
    IMPERIAL,
  ];

  static final $core.List<Config_DisplayConfig_DisplayUnits?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Config_DisplayConfig_DisplayUnits? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DisplayConfig_DisplayUnits._(super.value, super.name);
}

class Config_DisplayConfig_OledType extends $pb.ProtobufEnum {
  static const Config_DisplayConfig_OledType OLED_AUTO =
      Config_DisplayConfig_OledType._(0, _omitEnumNames ? '' : 'OLED_AUTO');
  static const Config_DisplayConfig_OledType OLED_SSD1306 =
      Config_DisplayConfig_OledType._(1, _omitEnumNames ? '' : 'OLED_SSD1306');
  static const Config_DisplayConfig_OledType OLED_SH1106 =
      Config_DisplayConfig_OledType._(2, _omitEnumNames ? '' : 'OLED_SH1106');
  static const Config_DisplayConfig_OledType OLED_SH1107 =
      Config_DisplayConfig_OledType._(3, _omitEnumNames ? '' : 'OLED_SH1107');
  static const Config_DisplayConfig_OledType OLED_SH1107_128_128 =
      Config_DisplayConfig_OledType._(
          4, _omitEnumNames ? '' : 'OLED_SH1107_128_128');

  static const $core.List<Config_DisplayConfig_OledType> values =
      <Config_DisplayConfig_OledType>[
    OLED_AUTO,
    OLED_SSD1306,
    OLED_SH1106,
    OLED_SH1107,
    OLED_SH1107_128_128,
  ];

  static final $core.List<Config_DisplayConfig_OledType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Config_DisplayConfig_OledType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DisplayConfig_OledType._(super.value, super.name);
}

class Config_DisplayConfig_DisplayMode extends $pb.ProtobufEnum {
  static const Config_DisplayConfig_DisplayMode DEFAULT =
      Config_DisplayConfig_DisplayMode._(0, _omitEnumNames ? '' : 'DEFAULT');
  static const Config_DisplayConfig_DisplayMode TWOCOLOR =
      Config_DisplayConfig_DisplayMode._(1, _omitEnumNames ? '' : 'TWOCOLOR');
  static const Config_DisplayConfig_DisplayMode INVERTED =
      Config_DisplayConfig_DisplayMode._(2, _omitEnumNames ? '' : 'INVERTED');
  static const Config_DisplayConfig_DisplayMode COLOR =
      Config_DisplayConfig_DisplayMode._(3, _omitEnumNames ? '' : 'COLOR');

  static const $core.List<Config_DisplayConfig_DisplayMode> values =
      <Config_DisplayConfig_DisplayMode>[
    DEFAULT,
    TWOCOLOR,
    INVERTED,
    COLOR,
  ];

  static final $core.List<Config_DisplayConfig_DisplayMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Config_DisplayConfig_DisplayMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DisplayConfig_DisplayMode._(super.value, super.name);
}

class Config_DisplayConfig_CompassOrientation extends $pb.ProtobufEnum {
  static const Config_DisplayConfig_CompassOrientation DEGREES_0 =
      Config_DisplayConfig_CompassOrientation._(
          0, _omitEnumNames ? '' : 'DEGREES_0');
  static const Config_DisplayConfig_CompassOrientation DEGREES_90 =
      Config_DisplayConfig_CompassOrientation._(
          1, _omitEnumNames ? '' : 'DEGREES_90');
  static const Config_DisplayConfig_CompassOrientation DEGREES_180 =
      Config_DisplayConfig_CompassOrientation._(
          2, _omitEnumNames ? '' : 'DEGREES_180');
  static const Config_DisplayConfig_CompassOrientation DEGREES_270 =
      Config_DisplayConfig_CompassOrientation._(
          3, _omitEnumNames ? '' : 'DEGREES_270');
  static const Config_DisplayConfig_CompassOrientation DEGREES_0_INVERTED =
      Config_DisplayConfig_CompassOrientation._(
          4, _omitEnumNames ? '' : 'DEGREES_0_INVERTED');
  static const Config_DisplayConfig_CompassOrientation DEGREES_90_INVERTED =
      Config_DisplayConfig_CompassOrientation._(
          5, _omitEnumNames ? '' : 'DEGREES_90_INVERTED');
  static const Config_DisplayConfig_CompassOrientation DEGREES_180_INVERTED =
      Config_DisplayConfig_CompassOrientation._(
          6, _omitEnumNames ? '' : 'DEGREES_180_INVERTED');
  static const Config_DisplayConfig_CompassOrientation DEGREES_270_INVERTED =
      Config_DisplayConfig_CompassOrientation._(
          7, _omitEnumNames ? '' : 'DEGREES_270_INVERTED');

  static const $core.List<Config_DisplayConfig_CompassOrientation> values =
      <Config_DisplayConfig_CompassOrientation>[
    DEGREES_0,
    DEGREES_90,
    DEGREES_180,
    DEGREES_270,
    DEGREES_0_INVERTED,
    DEGREES_90_INVERTED,
    DEGREES_180_INVERTED,
    DEGREES_270_INVERTED,
  ];

  static final $core.List<Config_DisplayConfig_CompassOrientation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static Config_DisplayConfig_CompassOrientation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_DisplayConfig_CompassOrientation._(super.value, super.name);
}

class Config_BluetoothConfig_PairingMode extends $pb.ProtobufEnum {
  static const Config_BluetoothConfig_PairingMode RANDOM_PIN =
      Config_BluetoothConfig_PairingMode._(
          0, _omitEnumNames ? '' : 'RANDOM_PIN');
  static const Config_BluetoothConfig_PairingMode FIXED_PIN =
      Config_BluetoothConfig_PairingMode._(
          1, _omitEnumNames ? '' : 'FIXED_PIN');
  static const Config_BluetoothConfig_PairingMode NO_PIN =
      Config_BluetoothConfig_PairingMode._(2, _omitEnumNames ? '' : 'NO_PIN');

  static const $core.List<Config_BluetoothConfig_PairingMode> values =
      <Config_BluetoothConfig_PairingMode>[
    RANDOM_PIN,
    FIXED_PIN,
    NO_PIN,
  ];

  static final $core.List<Config_BluetoothConfig_PairingMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Config_BluetoothConfig_PairingMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Config_BluetoothConfig_PairingMode._(super.value, super.name);
}

class ModuleConfig_SerialConfig_Serial_Baud extends $pb.ProtobufEnum {
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_DEFAULT =
      ModuleConfig_SerialConfig_Serial_Baud._(
          0, _omitEnumNames ? '' : 'BAUD_DEFAULT');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_110 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          1, _omitEnumNames ? '' : 'BAUD_110');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_300 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          2, _omitEnumNames ? '' : 'BAUD_300');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_600 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          3, _omitEnumNames ? '' : 'BAUD_600');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_1200 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          4, _omitEnumNames ? '' : 'BAUD_1200');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_2400 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          5, _omitEnumNames ? '' : 'BAUD_2400');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_4800 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          6, _omitEnumNames ? '' : 'BAUD_4800');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_9600 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          7, _omitEnumNames ? '' : 'BAUD_9600');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_19200 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          8, _omitEnumNames ? '' : 'BAUD_19200');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_38400 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          9, _omitEnumNames ? '' : 'BAUD_38400');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_57600 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          10, _omitEnumNames ? '' : 'BAUD_57600');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_115200 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          11, _omitEnumNames ? '' : 'BAUD_115200');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_230400 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          12, _omitEnumNames ? '' : 'BAUD_230400');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_460800 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          13, _omitEnumNames ? '' : 'BAUD_460800');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_576000 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          14, _omitEnumNames ? '' : 'BAUD_576000');
  static const ModuleConfig_SerialConfig_Serial_Baud BAUD_921600 =
      ModuleConfig_SerialConfig_Serial_Baud._(
          15, _omitEnumNames ? '' : 'BAUD_921600');

  static const $core.List<ModuleConfig_SerialConfig_Serial_Baud> values =
      <ModuleConfig_SerialConfig_Serial_Baud>[
    BAUD_DEFAULT,
    BAUD_110,
    BAUD_300,
    BAUD_600,
    BAUD_1200,
    BAUD_2400,
    BAUD_4800,
    BAUD_9600,
    BAUD_19200,
    BAUD_38400,
    BAUD_57600,
    BAUD_115200,
    BAUD_230400,
    BAUD_460800,
    BAUD_576000,
    BAUD_921600,
  ];

  static final $core.List<ModuleConfig_SerialConfig_Serial_Baud?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 15);
  static ModuleConfig_SerialConfig_Serial_Baud? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModuleConfig_SerialConfig_Serial_Baud._(super.value, super.name);
}

class ModuleConfig_SerialConfig_Serial_Mode extends $pb.ProtobufEnum {
  static const ModuleConfig_SerialConfig_Serial_Mode DEFAULT =
      ModuleConfig_SerialConfig_Serial_Mode._(
          0, _omitEnumNames ? '' : 'DEFAULT');
  static const ModuleConfig_SerialConfig_Serial_Mode SIMPLE =
      ModuleConfig_SerialConfig_Serial_Mode._(
          1, _omitEnumNames ? '' : 'SIMPLE');
  static const ModuleConfig_SerialConfig_Serial_Mode PROTO =
      ModuleConfig_SerialConfig_Serial_Mode._(2, _omitEnumNames ? '' : 'PROTO');
  static const ModuleConfig_SerialConfig_Serial_Mode TEXTMSG =
      ModuleConfig_SerialConfig_Serial_Mode._(
          3, _omitEnumNames ? '' : 'TEXTMSG');
  static const ModuleConfig_SerialConfig_Serial_Mode NMEA =
      ModuleConfig_SerialConfig_Serial_Mode._(4, _omitEnumNames ? '' : 'NMEA');
  static const ModuleConfig_SerialConfig_Serial_Mode CALTOPO =
      ModuleConfig_SerialConfig_Serial_Mode._(
          5, _omitEnumNames ? '' : 'CALTOPO');
  static const ModuleConfig_SerialConfig_Serial_Mode WS85 =
      ModuleConfig_SerialConfig_Serial_Mode._(6, _omitEnumNames ? '' : 'WS85');
  static const ModuleConfig_SerialConfig_Serial_Mode VE_DIRECT =
      ModuleConfig_SerialConfig_Serial_Mode._(
          7, _omitEnumNames ? '' : 'VE_DIRECT');
  static const ModuleConfig_SerialConfig_Serial_Mode MS_CONFIG =
      ModuleConfig_SerialConfig_Serial_Mode._(
          8, _omitEnumNames ? '' : 'MS_CONFIG');

  static const $core.List<ModuleConfig_SerialConfig_Serial_Mode> values =
      <ModuleConfig_SerialConfig_Serial_Mode>[
    DEFAULT,
    SIMPLE,
    PROTO,
    TEXTMSG,
    NMEA,
    CALTOPO,
    WS85,
    VE_DIRECT,
    MS_CONFIG,
  ];

  static final $core.List<ModuleConfig_SerialConfig_Serial_Mode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static ModuleConfig_SerialConfig_Serial_Mode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModuleConfig_SerialConfig_Serial_Mode._(super.value, super.name);
}

class ModuleConfig_CannedMessageConfig_InputEventChar extends $pb.ProtobufEnum {
  static const ModuleConfig_CannedMessageConfig_InputEventChar NONE =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          0, _omitEnumNames ? '' : 'NONE');
  static const ModuleConfig_CannedMessageConfig_InputEventChar UP =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          17, _omitEnumNames ? '' : 'UP');
  static const ModuleConfig_CannedMessageConfig_InputEventChar DOWN =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          18, _omitEnumNames ? '' : 'DOWN');
  static const ModuleConfig_CannedMessageConfig_InputEventChar LEFT =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          19, _omitEnumNames ? '' : 'LEFT');
  static const ModuleConfig_CannedMessageConfig_InputEventChar RIGHT =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          20, _omitEnumNames ? '' : 'RIGHT');
  static const ModuleConfig_CannedMessageConfig_InputEventChar SELECT =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          10, _omitEnumNames ? '' : 'SELECT');
  static const ModuleConfig_CannedMessageConfig_InputEventChar BACK =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          27, _omitEnumNames ? '' : 'BACK');
  static const ModuleConfig_CannedMessageConfig_InputEventChar CANCEL =
      ModuleConfig_CannedMessageConfig_InputEventChar._(
          24, _omitEnumNames ? '' : 'CANCEL');

  static const $core.List<ModuleConfig_CannedMessageConfig_InputEventChar>
      values = <ModuleConfig_CannedMessageConfig_InputEventChar>[
    NONE,
    UP,
    DOWN,
    LEFT,
    RIGHT,
    SELECT,
    BACK,
    CANCEL,
  ];

  static final $core
      .Map<$core.int, ModuleConfig_CannedMessageConfig_InputEventChar>
      _byValue = $pb.ProtobufEnum.initByValue(values);
  static ModuleConfig_CannedMessageConfig_InputEventChar? valueOf(
          $core.int value) =>
      _byValue[value];

  const ModuleConfig_CannedMessageConfig_InputEventChar._(
      super.value, super.name);
}

class ModuleConfig_AudioConfig_Audio_Baud extends $pb.ProtobufEnum {
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_DEFAULT =
      ModuleConfig_AudioConfig_Audio_Baud._(
          0, _omitEnumNames ? '' : 'CODEC2_DEFAULT');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_3200 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          1, _omitEnumNames ? '' : 'CODEC2_3200');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_2400 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          2, _omitEnumNames ? '' : 'CODEC2_2400');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_1600 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          3, _omitEnumNames ? '' : 'CODEC2_1600');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_1400 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          4, _omitEnumNames ? '' : 'CODEC2_1400');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_1300 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          5, _omitEnumNames ? '' : 'CODEC2_1300');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_1200 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          6, _omitEnumNames ? '' : 'CODEC2_1200');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_700 =
      ModuleConfig_AudioConfig_Audio_Baud._(
          7, _omitEnumNames ? '' : 'CODEC2_700');
  static const ModuleConfig_AudioConfig_Audio_Baud CODEC2_700B =
      ModuleConfig_AudioConfig_Audio_Baud._(
          8, _omitEnumNames ? '' : 'CODEC2_700B');

  static const $core.List<ModuleConfig_AudioConfig_Audio_Baud> values =
      <ModuleConfig_AudioConfig_Audio_Baud>[
    CODEC2_DEFAULT,
    CODEC2_3200,
    CODEC2_2400,
    CODEC2_1600,
    CODEC2_1400,
    CODEC2_1300,
    CODEC2_1200,
    CODEC2_700,
    CODEC2_700B,
  ];

  static final $core.List<ModuleConfig_AudioConfig_Audio_Baud?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static ModuleConfig_AudioConfig_Audio_Baud? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModuleConfig_AudioConfig_Audio_Baud._(super.value, super.name);
}

class ModuleConfig_DetectionSensorConfig_TriggerType extends $pb.ProtobufEnum {
  static const ModuleConfig_DetectionSensorConfig_TriggerType LOGIC_LOW =
      ModuleConfig_DetectionSensorConfig_TriggerType._(
          0, _omitEnumNames ? '' : 'LOGIC_LOW');
  static const ModuleConfig_DetectionSensorConfig_TriggerType LOGIC_HIGH =
      ModuleConfig_DetectionSensorConfig_TriggerType._(
          1, _omitEnumNames ? '' : 'LOGIC_HIGH');
  static const ModuleConfig_DetectionSensorConfig_TriggerType FALLING_EDGE =
      ModuleConfig_DetectionSensorConfig_TriggerType._(
          2, _omitEnumNames ? '' : 'FALLING_EDGE');
  static const ModuleConfig_DetectionSensorConfig_TriggerType RISING_EDGE =
      ModuleConfig_DetectionSensorConfig_TriggerType._(
          3, _omitEnumNames ? '' : 'RISING_EDGE');
  static const ModuleConfig_DetectionSensorConfig_TriggerType
      EITHER_EDGE_ACTIVE_LOW = ModuleConfig_DetectionSensorConfig_TriggerType._(
          4, _omitEnumNames ? '' : 'EITHER_EDGE_ACTIVE_LOW');
  static const ModuleConfig_DetectionSensorConfig_TriggerType
      EITHER_EDGE_ACTIVE_HIGH =
      ModuleConfig_DetectionSensorConfig_TriggerType._(
          5, _omitEnumNames ? '' : 'EITHER_EDGE_ACTIVE_HIGH');

  static const $core.List<ModuleConfig_DetectionSensorConfig_TriggerType>
      values = <ModuleConfig_DetectionSensorConfig_TriggerType>[
    LOGIC_LOW,
    LOGIC_HIGH,
    FALLING_EDGE,
    RISING_EDGE,
    EITHER_EDGE_ACTIVE_LOW,
    EITHER_EDGE_ACTIVE_HIGH,
  ];

  static final $core.List<ModuleConfig_DetectionSensorConfig_TriggerType?>
      _byValue = $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ModuleConfig_DetectionSensorConfig_TriggerType? valueOf(
          $core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ModuleConfig_DetectionSensorConfig_TriggerType._(
      super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
