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
  static const HardwareModel STATION_G1 =
      HardwareModel._(25, _omitEnumNames ? '' : 'STATION_G1');
  static const HardwareModel RAK11310 =
      HardwareModel._(26, _omitEnumNames ? '' : 'RAK11310');
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
    STATION_G1,
    RAK11310,
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

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
