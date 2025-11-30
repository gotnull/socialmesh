// This is a generated file - do not edit.
//
// Generated from meshtastic/mesh.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use config_DeviceConfig_RoleDescriptor instead')
const Config_DeviceConfig_Role$json = {
  '1': 'Config_DeviceConfig_Role',
  '2': [
    {'1': 'CLIENT', '2': 0},
    {'1': 'CLIENT_MUTE', '2': 1},
    {'1': 'ROUTER', '2': 2},
    {'1': 'ROUTER_CLIENT', '2': 3},
    {'1': 'REPEATER', '2': 4},
    {'1': 'TRACKER', '2': 5},
    {'1': 'SENSOR', '2': 6},
    {'1': 'TAK', '2': 7},
    {'1': 'CLIENT_HIDDEN', '2': 8},
    {'1': 'LOST_AND_FOUND', '2': 9},
    {'1': 'TAK_TRACKER', '2': 10},
  ],
};

/// Descriptor for `Config_DeviceConfig_Role`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List config_DeviceConfig_RoleDescriptor = $convert.base64Decode(
    'ChhDb25maWdfRGV2aWNlQ29uZmlnX1JvbGUSCgoGQ0xJRU5UEAASDwoLQ0xJRU5UX01VVEUQAR'
    'IKCgZST1VURVIQAhIRCg1ST1VURVJfQ0xJRU5UEAMSDAoIUkVQRUFURVIQBBILCgdUUkFDS0VS'
    'EAUSCgoGU0VOU09SEAYSBwoDVEFLEAcSEQoNQ0xJRU5UX0hJRERFThAIEhIKDkxPU1RfQU5EX0'
    'ZPVU5EEAkSDwoLVEFLX1RSQUNLRVIQCg==');

@$core.Deprecated('Use hardwareModelDescriptor instead')
const HardwareModel$json = {
  '1': 'HardwareModel',
  '2': [
    {'1': 'UNSET', '2': 0},
    {'1': 'TLORA_V2', '2': 1},
    {'1': 'TLORA_V1', '2': 2},
    {'1': 'TLORA_V2_1_1p6', '2': 3},
    {'1': 'TBEAM', '2': 4},
    {'1': 'HELTEC_V2_0', '2': 5},
    {'1': 'TBEAM0p7', '2': 6},
    {'1': 'T_ECHO', '2': 7},
    {'1': 'TLORA_V1_1p3', '2': 8},
    {'1': 'RAK4631', '2': 9},
    {'1': 'HELTEC_V2_1', '2': 10},
    {'1': 'HELTEC_V1', '2': 11},
    {'1': 'LILYGO_TBEAM_S3_CORE', '2': 12},
    {'1': 'RAK11200', '2': 13},
    {'1': 'NANO_G1', '2': 14},
    {'1': 'TLORA_V2_1_1p8', '2': 15},
    {'1': 'TLORA_T3_S3', '2': 16},
    {'1': 'NANO_G1_EXPLORER', '2': 17},
    {'1': 'NANO_G2_ULTRA', '2': 18},
    {'1': 'LORA_TYPE', '2': 19},
    {'1': 'WIPHONE', '2': 20},
    {'1': 'WIO_WM1110', '2': 21},
    {'1': 'RAK2560', '2': 22},
    {'1': 'HELTEC_HRU_3601', '2': 23},
    {'1': 'HELTEC_WIRELESS_PAPER', '2': 24},
    {'1': 'STATION_G1', '2': 25},
    {'1': 'RAK11310', '2': 26},
    {'1': 'SENSELORA_RP2040', '2': 27},
    {'1': 'SENSELORA_S3', '2': 28},
    {'1': 'CANARYONE', '2': 29},
    {'1': 'RP2040_LORA', '2': 30},
    {'1': 'STATION_G2', '2': 31},
    {'1': 'LORA_RELAY_V1', '2': 32},
    {'1': 'NRF52840DK', '2': 33},
    {'1': 'PPR', '2': 34},
    {'1': 'GENIEBLOCKS', '2': 35},
    {'1': 'NRF52_UNKNOWN', '2': 36},
    {'1': 'PORTDUINO', '2': 37},
    {'1': 'ANDROID_SIM', '2': 38},
    {'1': 'DIY_V1', '2': 39},
    {'1': 'NRF52840_PCA10059', '2': 40},
    {'1': 'DR_DEV', '2': 41},
    {'1': 'M5STACK', '2': 42},
    {'1': 'HELTEC_V3', '2': 43},
    {'1': 'HELTEC_WSL_V3', '2': 44},
    {'1': 'BETAFPV_2400_TX', '2': 45},
    {'1': 'BETAFPV_900_NANO_TX', '2': 46},
    {'1': 'RPI_PICO', '2': 47},
    {'1': 'HELTEC_WIRELESS_TRACKER', '2': 48},
    {'1': 'HELTEC_WIRELESS_PAPER_V1_0', '2': 49},
    {'1': 'T_DECK', '2': 50},
    {'1': 'T_WATCH_S3', '2': 51},
    {'1': 'PICOMPUTER_S3', '2': 52},
    {'1': 'HELTEC_HT62', '2': 53},
    {'1': 'EBYTE_ESP32_S3', '2': 54},
    {'1': 'ESP32_S3_PICO', '2': 55},
    {'1': 'CHATTER_2', '2': 56},
    {'1': 'HELTEC_WIRELESS_PAPER_V1_1', '2': 57},
    {'1': 'HELTEC_CAPSULE_SENSOR_V3', '2': 58},
    {'1': 'HELTEC_VISION_MASTER_T190', '2': 59},
    {'1': 'HELTEC_VISION_MASTER_E213', '2': 60},
    {'1': 'HELTEC_VISION_MASTER_E290', '2': 61},
    {'1': 'HELTEC_MESH_NODE_T114', '2': 62},
    {'1': 'SENSECAP_INDICATOR', '2': 63},
    {'1': 'TRACKER_T1000_E', '2': 64},
    {'1': 'RAK3172', '2': 65},
    {'1': 'WIO_E5', '2': 66},
    {'1': 'RADIOMASTER_900_BANDIT_NANO', '2': 67},
    {'1': 'HELTEC_CAPSULE_SENSOR_V3_COMPACT', '2': 68},
    {'1': 'PRIVATE_HW', '2': 255},
  ],
};

/// Descriptor for `HardwareModel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List hardwareModelDescriptor = $convert.base64Decode(
    'Cg1IYXJkd2FyZU1vZGVsEgkKBVVOU0VUEAASDAoIVExPUkFfVjIQARIMCghUTE9SQV9WMRACEh'
    'IKDlRMT1JBX1YyXzFfMXA2EAMSCQoFVEJFQU0QBBIPCgtIRUxURUNfVjJfMBAFEgwKCFRCRUFN'
    'MHA3EAYSCgoGVF9FQ0hPEAcSEAoMVExPUkFfVjFfMXAzEAgSCwoHUkFLNDYzMRAJEg8KC0hFTF'
    'RFQ19WMl8xEAoSDQoJSEVMVEVDX1YxEAsSGAoUTElMWUdPX1RCRUFNX1MzX0NPUkUQDBIMCghS'
    'QUsxMTIwMBANEgsKB05BTk9fRzEQDhISCg5UTE9SQV9WMl8xXzFwOBAPEg8KC1RMT1JBX1QzX1'
    'MzEBASFAoQTkFOT19HMV9FWFBMT1JFUhAREhEKDU5BTk9fRzJfVUxUUkEQEhINCglMT1JBX1RZ'
    'UEUQExILCgdXSVBIT05FEBQSDgoKV0lPX1dNMTExMBAVEgsKB1JBSzI1NjAQFhITCg9IRUxURU'
    'NfSFJVXzM2MDEQFxIZChVIRUxURUNfV0lSRUxFU1NfUEFQRVIQGBIOCgpTVEFUSU9OX0cxEBkS'
    'DAoIUkFLMTEzMTAQGhIUChBTRU5TRUxPUkFfUlAyMDQwEBsSEAoMU0VOU0VMT1JBX1MzEBwSDQ'
    'oJQ0FOQVJZT05FEB0SDwoLUlAyMDQwX0xPUkEQHhIOCgpTVEFUSU9OX0cyEB8SEQoNTE9SQV9S'
    'RUxBWV9WMRAgEg4KCk5SRjUyODQwREsQIRIHCgNQUFIQIhIPCgtHRU5JRUJMT0NLUxAjEhEKDU'
    '5SRjUyX1VOS05PV04QJBINCglQT1JURFVJTk8QJRIPCgtBTkRST0lEX1NJTRAmEgoKBkRJWV9W'
    'MRAnEhUKEU5SRjUyODQwX1BDQTEwMDU5ECgSCgoGRFJfREVWECkSCwoHTTVTVEFDSxAqEg0KCU'
    'hFTFRFQ19WMxArEhEKDUhFTFRFQ19XU0xfVjMQLBITCg9CRVRBRlBWXzI0MDBfVFgQLRIXChNC'
    'RVRBRlBWXzkwMF9OQU5PX1RYEC4SDAoIUlBJX1BJQ08QLxIbChdIRUxURUNfV0lSRUxFU1NfVF'
    'JBQ0tFUhAwEh4KGkhFTFRFQ19XSVJFTEVTU19QQVBFUl9WMV8wEDESCgoGVF9ERUNLEDISDgoK'
    'VF9XQVRDSF9TMxAzEhEKDVBJQ09NUFVURVJfUzMQNBIPCgtIRUxURUNfSFQ2MhA1EhIKDkVCWV'
    'RFX0VTUDMyX1MzEDYSEQoNRVNQMzJfUzNfUElDTxA3Eg0KCUNIQVRURVJfMhA4Eh4KGkhFTFRF'
    'Q19XSVJFTEVTU19QQVBFUl9WMV8xEDkSHAoYSEVMVEVDX0NBUFNVTEVfU0VOU09SX1YzEDoSHQ'
    'oZSEVMVEVDX1ZJU0lPTl9NQVNURVJfVDE5MBA7Eh0KGUhFTFRFQ19WSVNJT05fTUFTVEVSX0Uy'
    'MTMQPBIdChlIRUxURUNfVklTSU9OX01BU1RFUl9FMjkwED0SGQoVSEVMVEVDX01FU0hfTk9ERV'
    '9UMTE0ED4SFgoSU0VOU0VDQVBfSU5ESUNBVE9SED8SEwoPVFJBQ0tFUl9UMTAwMF9FEEASCwoH'
    'UkFLMzE3MhBBEgoKBldJT19FNRBCEh8KG1JBRElPTUFTVEVSXzkwMF9CQU5ESVRfTkFOTxBDEi'
    'QKIEhFTFRFQ19DQVBTVUxFX1NFTlNPUl9WM19DT01QQUNUEEQSDwoKUFJJVkFURV9IVxD/AQ==');

@$core.Deprecated('Use routing_ErrorDescriptor instead')
const Routing_Error$json = {
  '1': 'Routing_Error',
  '2': [
    {'1': 'NONE', '2': 0},
    {'1': 'NO_ROUTE', '2': 1},
    {'1': 'GOT_NAK', '2': 2},
    {'1': 'TIMEOUT', '2': 3},
    {'1': 'NO_INTERFACE', '2': 4},
    {'1': 'MAX_RETRANSMIT', '2': 5},
    {'1': 'NO_CHANNEL', '2': 6},
    {'1': 'TOO_LARGE', '2': 7},
    {'1': 'NO_RESPONSE', '2': 8},
    {'1': 'DUTY_CYCLE_LIMIT', '2': 9},
    {'1': 'BAD_REQUEST', '2': 32},
    {'1': 'NOT_AUTHORIZED', '2': 33},
    {'1': 'PKC_FAILED', '2': 34},
    {'1': 'PKI_UNKNOWN_PUBKEY', '2': 35},
    {'1': 'ADMIN_BAD_SESSION_KEY', '2': 36},
    {'1': 'ADMIN_PUBLIC_KEY_UNAUTHORIZED', '2': 37},
  ],
};

/// Descriptor for `Routing_Error`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List routing_ErrorDescriptor = $convert.base64Decode(
    'Cg1Sb3V0aW5nX0Vycm9yEggKBE5PTkUQABIMCghOT19ST1VURRABEgsKB0dPVF9OQUsQAhILCg'
    'dUSU1FT1VUEAMSEAoMTk9fSU5URVJGQUNFEAQSEgoOTUFYX1JFVFJBTlNNSVQQBRIOCgpOT19D'
    'SEFOTkVMEAYSDQoJVE9PX0xBUkdFEAcSDwoLTk9fUkVTUE9OU0UQCBIUChBEVVRZX0NZQ0xFX0'
    'xJTUlUEAkSDwoLQkFEX1JFUVVFU1QQIBISCg5OT1RfQVVUSE9SSVpFRBAhEg4KClBLQ19GQUlM'
    'RUQQIhIWChJQS0lfVU5LTk9XTl9QVUJLRVkQIxIZChVBRE1JTl9CQURfU0VTU0lPTl9LRVkQJB'
    'IhCh1BRE1JTl9QVUJMSUNfS0VZX1VOQVVUSE9SSVpFRBAl');

@$core.Deprecated('Use portNumDescriptor instead')
const PortNum$json = {
  '1': 'PortNum',
  '2': [
    {'1': 'UNKNOWN_APP', '2': 0},
    {'1': 'TEXT_MESSAGE_APP', '2': 1},
    {'1': 'REMOTE_HARDWARE_APP', '2': 2},
    {'1': 'POSITION_APP', '2': 3},
    {'1': 'NODEINFO_APP', '2': 4},
    {'1': 'ROUTING_APP', '2': 5},
    {'1': 'ADMIN_APP', '2': 6},
    {'1': 'TEXT_MESSAGE_COMPRESSED_APP', '2': 7},
    {'1': 'WAYPOINT_APP', '2': 8},
    {'1': 'AUDIO_APP', '2': 9},
    {'1': 'DETECTION_SENSOR_APP', '2': 10},
    {'1': 'REPLY_APP', '2': 32},
    {'1': 'IP_TUNNEL_APP', '2': 33},
    {'1': 'SERIAL_APP', '2': 64},
    {'1': 'STORE_FORWARD_APP', '2': 65},
    {'1': 'RANGE_TEST_APP', '2': 66},
    {'1': 'TELEMETRY_APP', '2': 67},
    {'1': 'ZPS_APP', '2': 68},
    {'1': 'SIMULATOR_APP', '2': 69},
    {'1': 'TRACEROUTE_APP', '2': 70},
    {'1': 'NEIGHBORINFO_APP', '2': 71},
    {'1': 'ATAK_PLUGIN', '2': 72},
    {'1': 'PRIVATE_APP', '2': 256},
    {'1': 'ATAK_FORWARDER', '2': 257},
    {'1': 'MAX', '2': 511},
  ],
};

/// Descriptor for `PortNum`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List portNumDescriptor = $convert.base64Decode(
    'CgdQb3J0TnVtEg8KC1VOS05PV05fQVBQEAASFAoQVEVYVF9NRVNTQUdFX0FQUBABEhcKE1JFTU'
    '9URV9IQVJEV0FSRV9BUFAQAhIQCgxQT1NJVElPTl9BUFAQAxIQCgxOT0RFSU5GT19BUFAQBBIP'
    'CgtST1VUSU5HX0FQUBAFEg0KCUFETUlOX0FQUBAGEh8KG1RFWFRfTUVTU0FHRV9DT01QUkVTU0'
    'VEX0FQUBAHEhAKDFdBWVBPSU5UX0FQUBAIEg0KCUFVRElPX0FQUBAJEhgKFERFVEVDVElPTl9T'
    'RU5TT1JfQVBQEAoSDQoJUkVQTFlfQVBQECASEQoNSVBfVFVOTkVMX0FQUBAhEg4KClNFUklBTF'
    '9BUFAQQBIVChFTVE9SRV9GT1JXQVJEX0FQUBBBEhIKDlJBTkdFX1RFU1RfQVBQEEISEQoNVEVM'
    'RU1FVFJZX0FQUBBDEgsKB1pQU19BUFAQRBIRCg1TSU1VTEFUT1JfQVBQEEUSEgoOVFJBQ0VST1'
    'VURV9BUFAQRhIUChBORUlHSEJPUklORk9fQVBQEEcSDwoLQVRBS19QTFVHSU4QSBIQCgtQUklW'
    'QVRFX0FQUBCAAhITCg5BVEFLX0ZPUldBUkRFUhCBAhIICgNNQVgQ/wM=');

@$core.Deprecated('Use remoteHardwarePinTypeDescriptor instead')
const RemoteHardwarePinType$json = {
  '1': 'RemoteHardwarePinType',
  '2': [
    {'1': 'UNKNOWN_TYPE', '2': 0},
    {'1': 'DIGITAL_READ', '2': 1},
    {'1': 'DIGITAL_WRITE', '2': 2},
  ],
};

/// Descriptor for `RemoteHardwarePinType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List remoteHardwarePinTypeDescriptor = $convert.base64Decode(
    'ChVSZW1vdGVIYXJkd2FyZVBpblR5cGUSEAoMVU5LTk9XTl9UWVBFEAASEAoMRElHSVRBTF9SRU'
    'FEEAESEQoNRElHSVRBTF9XUklURRAC');

@$core.Deprecated('Use modemPresetDescriptor instead')
const ModemPreset$json = {
  '1': 'ModemPreset',
  '2': [
    {'1': 'LONG_FAST', '2': 0},
    {'1': 'LONG_SLOW', '2': 1},
    {'1': 'VERY_LONG_SLOW', '2': 2},
    {'1': 'MEDIUM_SLOW', '2': 3},
    {'1': 'MEDIUM_FAST', '2': 4},
    {'1': 'SHORT_SLOW', '2': 5},
    {'1': 'SHORT_FAST', '2': 6},
    {'1': 'LONG_MODERATE', '2': 7},
  ],
};

/// Descriptor for `ModemPreset`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List modemPresetDescriptor = $convert.base64Decode(
    'CgtNb2RlbVByZXNldBINCglMT05HX0ZBU1QQABINCglMT05HX1NMT1cQARISCg5WRVJZX0xPTk'
    'dfU0xPVxACEg8KC01FRElVTV9TTE9XEAMSDwoLTUVESVVNX0ZBU1QQBBIOCgpTSE9SVF9TTE9X'
    'EAUSDgoKU0hPUlRfRkFTVBAGEhEKDUxPTkdfTU9ERVJBVEUQBw==');

@$core.Deprecated('Use regionCodeDescriptor instead')
const RegionCode$json = {
  '1': 'RegionCode',
  '2': [
    {'1': 'UNSET_REGION', '2': 0},
    {'1': 'US', '2': 1},
    {'1': 'EU_433', '2': 2},
    {'1': 'EU_868', '2': 3},
    {'1': 'CN', '2': 4},
    {'1': 'JP', '2': 5},
    {'1': 'ANZ', '2': 6},
    {'1': 'KR', '2': 7},
    {'1': 'TW', '2': 8},
    {'1': 'RU', '2': 9},
    {'1': 'IN', '2': 10},
    {'1': 'NZ_865', '2': 11},
    {'1': 'TH', '2': 12},
    {'1': 'LORA_24', '2': 13},
    {'1': 'UA_433', '2': 14},
    {'1': 'UA_868', '2': 15},
    {'1': 'MY_433', '2': 16},
    {'1': 'MY_919', '2': 17},
    {'1': 'SG_923', '2': 18},
  ],
};

/// Descriptor for `RegionCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List regionCodeDescriptor = $convert.base64Decode(
    'CgpSZWdpb25Db2RlEhAKDFVOU0VUX1JFR0lPThAAEgYKAlVTEAESCgoGRVVfNDMzEAISCgoGRV'
    'VfODY4EAMSBgoCQ04QBBIGCgJKUBAFEgcKA0FOWhAGEgYKAktSEAcSBgoCVFcQCBIGCgJSVRAJ'
    'EgYKAklOEAoSCgoGTlpfODY1EAsSBgoCVEgQDBILCgdMT1JBXzI0EA0SCgoGVUFfNDMzEA4SCg'
    'oGVUFfODY4EA8SCgoGTVlfNDMzEBASCgoGTVlfOTE5EBESCgoGU0dfOTIzEBI=');

@$core.Deprecated('Use positionDescriptor instead')
const Position$json = {
  '1': 'Position',
  '2': [
    {'1': 'latitude_i', '3': 1, '4': 1, '5': 15, '10': 'latitudeI'},
    {'1': 'longitude_i', '3': 2, '4': 1, '5': 15, '10': 'longitudeI'},
    {'1': 'altitude', '3': 3, '4': 1, '5': 5, '10': 'altitude'},
    {'1': 'time', '3': 4, '4': 1, '5': 7, '10': 'time'},
  ],
};

/// Descriptor for `Position`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List positionDescriptor = $convert.base64Decode(
    'CghQb3NpdGlvbhIdCgpsYXRpdHVkZV9pGAEgASgPUglsYXRpdHVkZUkSHwoLbG9uZ2l0dWRlX2'
    'kYAiABKA9SCmxvbmdpdHVkZUkSGgoIYWx0aXR1ZGUYAyABKAVSCGFsdGl0dWRlEhIKBHRpbWUY'
    'BCABKAdSBHRpbWU=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'long_name', '3': 2, '4': 1, '5': 9, '10': 'longName'},
    {'1': 'short_name', '3': 3, '4': 1, '5': 9, '10': 'shortName'},
    {'1': 'macaddr', '3': 4, '4': 1, '5': 12, '10': 'macaddr'},
    {
      '1': 'hw_model',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.HardwareModel',
      '10': 'hwModel'
    },
    {'1': 'is_licensed', '3': 6, '4': 1, '5': 8, '10': 'isLicensed'},
    {
      '1': 'role',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config_DeviceConfig_Role',
      '10': 'role'
    },
    {'1': 'public_key', '3': 8, '4': 1, '5': 12, '10': 'publicKey'},
    {'1': 'is_unmessagable', '3': 9, '4': 1, '5': 8, '10': 'isUnmessagable'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBIbCglsb25nX25hbWUYAiABKAlSCGxvbmdOYW1lEh0KCn'
    'Nob3J0X25hbWUYAyABKAlSCXNob3J0TmFtZRIYCgdtYWNhZGRyGAQgASgMUgdtYWNhZGRyEjQK'
    'CGh3X21vZGVsGAUgASgOMhkubWVzaHRhc3RpYy5IYXJkd2FyZU1vZGVsUgdod01vZGVsEh8KC2'
    'lzX2xpY2Vuc2VkGAYgASgIUgppc0xpY2Vuc2VkEjgKBHJvbGUYByABKA4yJC5tZXNodGFzdGlj'
    'LkNvbmZpZ19EZXZpY2VDb25maWdfUm9sZVIEcm9sZRIdCgpwdWJsaWNfa2V5GAggASgMUglwdW'
    'JsaWNLZXkSJwoPaXNfdW5tZXNzYWdhYmxlGAkgASgIUg5pc1VubWVzc2FnYWJsZQ==');

@$core.Deprecated('Use routeDiscoveryDescriptor instead')
const RouteDiscovery$json = {
  '1': 'RouteDiscovery',
  '2': [
    {'1': 'route', '3': 1, '4': 3, '5': 7, '10': 'route'},
  ],
};

/// Descriptor for `RouteDiscovery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routeDiscoveryDescriptor = $convert
    .base64Decode('Cg5Sb3V0ZURpc2NvdmVyeRIUCgVyb3V0ZRgBIAMoB1IFcm91dGU=');

@$core.Deprecated('Use routingDescriptor instead')
const Routing$json = {
  '1': 'Routing',
  '2': [
    {
      '1': 'route_request',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RouteDiscovery',
      '9': 0,
      '10': 'routeRequest'
    },
    {
      '1': 'route_reply',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RouteDiscovery',
      '9': 0,
      '10': 'routeReply'
    },
    {
      '1': 'error_reason',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Routing_Error',
      '9': 0,
      '10': 'errorReason'
    },
  ],
  '8': [
    {'1': 'variant'},
  ],
};

/// Descriptor for `Routing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routingDescriptor = $convert.base64Decode(
    'CgdSb3V0aW5nEkEKDXJvdXRlX3JlcXVlc3QYASABKAsyGi5tZXNodGFzdGljLlJvdXRlRGlzY2'
    '92ZXJ5SABSDHJvdXRlUmVxdWVzdBI9Cgtyb3V0ZV9yZXBseRgCIAEoCzIaLm1lc2h0YXN0aWMu'
    'Um91dGVEaXNjb3ZlcnlIAFIKcm91dGVSZXBseRI+CgxlcnJvcl9yZWFzb24YAyABKA4yGS5tZX'
    'NodGFzdGljLlJvdXRpbmdfRXJyb3JIAFILZXJyb3JSZWFzb25CCQoHdmFyaWFudA==');

@$core.Deprecated('Use dataDescriptor instead')
const Data$json = {
  '1': 'Data',
  '2': [
    {
      '1': 'portnum',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.PortNum',
      '10': 'portnum'
    },
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'want_response', '3': 3, '4': 1, '5': 8, '10': 'wantResponse'},
    {'1': 'dest', '3': 4, '4': 1, '5': 7, '10': 'dest'},
    {'1': 'source', '3': 5, '4': 1, '5': 7, '10': 'source'},
    {'1': 'request_id', '3': 6, '4': 1, '5': 7, '10': 'requestId'},
    {'1': 'reply_id', '3': 7, '4': 1, '5': 7, '10': 'replyId'},
    {'1': 'emoji', '3': 8, '4': 1, '5': 7, '10': 'emoji'},
  ],
};

/// Descriptor for `Data`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataDescriptor = $convert.base64Decode(
    'CgREYXRhEi0KB3BvcnRudW0YASABKA4yEy5tZXNodGFzdGljLlBvcnROdW1SB3BvcnRudW0SGA'
    'oHcGF5bG9hZBgCIAEoDFIHcGF5bG9hZBIjCg13YW50X3Jlc3BvbnNlGAMgASgIUgx3YW50UmVz'
    'cG9uc2USEgoEZGVzdBgEIAEoB1IEZGVzdBIWCgZzb3VyY2UYBSABKAdSBnNvdXJjZRIdCgpyZX'
    'F1ZXN0X2lkGAYgASgHUglyZXF1ZXN0SWQSGQoIcmVwbHlfaWQYByABKAdSB3JlcGx5SWQSFAoF'
    'ZW1vamkYCCABKAdSBWVtb2pp');

@$core.Deprecated('Use meshPacketDescriptor instead')
const MeshPacket$json = {
  '1': 'MeshPacket',
  '2': [
    {'1': 'from', '3': 1, '4': 1, '5': 7, '10': 'from'},
    {'1': 'to', '3': 2, '4': 1, '5': 7, '10': 'to'},
    {'1': 'channel', '3': 3, '4': 1, '5': 13, '10': 'channel'},
    {
      '1': 'decoded',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Data',
      '9': 0,
      '10': 'decoded'
    },
    {'1': 'encrypted', '3': 5, '4': 1, '5': 12, '9': 0, '10': 'encrypted'},
    {'1': 'id', '3': 6, '4': 1, '5': 7, '10': 'id'},
    {'1': 'rx_time', '3': 7, '4': 1, '5': 7, '10': 'rxTime'},
    {'1': 'rx_snr', '3': 8, '4': 1, '5': 2, '10': 'rxSnr'},
    {'1': 'hop_limit', '3': 9, '4': 1, '5': 13, '10': 'hopLimit'},
    {'1': 'want_ack', '3': 10, '4': 1, '5': 8, '10': 'wantAck'},
    {'1': 'priority', '3': 11, '4': 1, '5': 13, '10': 'priority'},
    {'1': 'delayed', '3': 12, '4': 1, '5': 13, '10': 'delayed'},
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `MeshPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meshPacketDescriptor = $convert.base64Decode(
    'CgpNZXNoUGFja2V0EhIKBGZyb20YASABKAdSBGZyb20SDgoCdG8YAiABKAdSAnRvEhgKB2NoYW'
    '5uZWwYAyABKA1SB2NoYW5uZWwSLAoHZGVjb2RlZBgEIAEoCzIQLm1lc2h0YXN0aWMuRGF0YUgA'
    'UgdkZWNvZGVkEh4KCWVuY3J5cHRlZBgFIAEoDEgAUgllbmNyeXB0ZWQSDgoCaWQYBiABKAdSAm'
    'lkEhcKB3J4X3RpbWUYByABKAdSBnJ4VGltZRIVCgZyeF9zbnIYCCABKAJSBXJ4U25yEhsKCWhv'
    'cF9saW1pdBgJIAEoDVIIaG9wTGltaXQSGQoId2FudF9hY2sYCiABKAhSB3dhbnRBY2sSGgoIcH'
    'Jpb3JpdHkYCyABKA1SCHByaW9yaXR5EhgKB2RlbGF5ZWQYDCABKA1SB2RlbGF5ZWRCEQoPcGF5'
    'bG9hZF92YXJpYW50');

@$core.Deprecated('Use nodeInfoDescriptor instead')
const NodeInfo$json = {
  '1': 'NodeInfo',
  '2': [
    {'1': 'num', '3': 1, '4': 1, '5': 13, '10': 'num'},
    {
      '1': 'user',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.User',
      '10': 'user'
    },
    {
      '1': 'position',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Position',
      '10': 'position'
    },
    {'1': 'snr', '3': 4, '4': 1, '5': 2, '10': 'snr'},
    {'1': 'last_heard', '3': 5, '4': 1, '5': 7, '10': 'lastHeard'},
    {
      '1': 'device_metrics',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DeviceMetrics',
      '10': 'deviceMetrics'
    },
  ],
};

/// Descriptor for `NodeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeInfoDescriptor = $convert.base64Decode(
    'CghOb2RlSW5mbxIQCgNudW0YASABKA1SA251bRIkCgR1c2VyGAIgASgLMhAubWVzaHRhc3RpYy'
    '5Vc2VyUgR1c2VyEjAKCHBvc2l0aW9uGAMgASgLMhQubWVzaHRhc3RpYy5Qb3NpdGlvblIIcG9z'
    'aXRpb24SEAoDc25yGAQgASgCUgNzbnISHQoKbGFzdF9oZWFyZBgFIAEoB1IJbGFzdEhlYXJkEk'
    'AKDmRldmljZV9tZXRyaWNzGAYgASgLMhkubWVzaHRhc3RpYy5EZXZpY2VNZXRyaWNzUg1kZXZp'
    'Y2VNZXRyaWNz');

@$core.Deprecated('Use myNodeInfoDescriptor instead')
const MyNodeInfo$json = {
  '1': 'MyNodeInfo',
  '2': [
    {'1': 'my_node_num', '3': 1, '4': 1, '5': 13, '10': 'myNodeNum'},
    {'1': 'reboot_count', '3': 8, '4': 1, '5': 13, '10': 'rebootCount'},
    {'1': 'min_app_version', '3': 11, '4': 1, '5': 13, '10': 'minAppVersion'},
    {'1': 'device_id', '3': 12, '4': 1, '5': 12, '10': 'deviceId'},
    {'1': 'pio_env', '3': 13, '4': 1, '5': 9, '10': 'pioEnv'},
    {'1': 'firmware_edition', '3': 14, '4': 1, '5': 9, '10': 'firmwareEdition'},
    {'1': 'nodedb_count', '3': 15, '4': 1, '5': 13, '10': 'nodedbCount'},
  ],
};

/// Descriptor for `MyNodeInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List myNodeInfoDescriptor = $convert.base64Decode(
    'CgpNeU5vZGVJbmZvEh4KC215X25vZGVfbnVtGAEgASgNUglteU5vZGVOdW0SIQoMcmVib290X2'
    'NvdW50GAggASgNUgtyZWJvb3RDb3VudBImCg9taW5fYXBwX3ZlcnNpb24YCyABKA1SDW1pbkFw'
    'cFZlcnNpb24SGwoJZGV2aWNlX2lkGAwgASgMUghkZXZpY2VJZBIXCgdwaW9fZW52GA0gASgJUg'
    'ZwaW9FbnYSKQoQZmlybXdhcmVfZWRpdGlvbhgOIAEoCVIPZmlybXdhcmVFZGl0aW9uEiEKDG5v'
    'ZGVkYl9jb3VudBgPIAEoDVILbm9kZWRiQ291bnQ=');

@$core.Deprecated('Use channelDescriptor instead')
const Channel$json = {
  '1': 'Channel',
  '2': [
    {'1': 'index', '3': 1, '4': 1, '5': 5, '10': 'index'},
    {
      '1': 'settings',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ChannelSettings',
      '10': 'settings'
    },
    {
      '1': 'role',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Channel.Role',
      '10': 'role'
    },
  ],
  '4': [Channel_Role$json],
};

@$core.Deprecated('Use channelDescriptor instead')
const Channel_Role$json = {
  '1': 'Role',
  '2': [
    {'1': 'DISABLED', '2': 0},
    {'1': 'PRIMARY', '2': 1},
    {'1': 'SECONDARY', '2': 2},
  ],
};

/// Descriptor for `Channel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelDescriptor = $convert.base64Decode(
    'CgdDaGFubmVsEhQKBWluZGV4GAEgASgFUgVpbmRleBI3CghzZXR0aW5ncxgCIAEoCzIbLm1lc2'
    'h0YXN0aWMuQ2hhbm5lbFNldHRpbmdzUghzZXR0aW5ncxIsCgRyb2xlGAMgASgOMhgubWVzaHRh'
    'c3RpYy5DaGFubmVsLlJvbGVSBHJvbGUiMAoEUm9sZRIMCghESVNBQkxFRBAAEgsKB1BSSU1BUl'
    'kQARINCglTRUNPTkRBUlkQAg==');

@$core.Deprecated('Use channelSettingsDescriptor instead')
const ChannelSettings$json = {
  '1': 'ChannelSettings',
  '2': [
    {'1': 'channel_num', '3': 1, '4': 1, '5': 13, '10': 'channelNum'},
    {'1': 'psk', '3': 2, '4': 1, '5': 12, '10': 'psk'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'id', '3': 4, '4': 1, '5': 7, '10': 'id'},
    {'1': 'uplink_enabled', '3': 5, '4': 1, '5': 8, '10': 'uplinkEnabled'},
    {'1': 'downlink_enabled', '3': 6, '4': 1, '5': 8, '10': 'downlinkEnabled'},
    {
      '1': 'module_settings',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleSettings',
      '10': 'moduleSettings'
    },
  ],
};

/// Descriptor for `ChannelSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelSettingsDescriptor = $convert.base64Decode(
    'Cg9DaGFubmVsU2V0dGluZ3MSHwoLY2hhbm5lbF9udW0YASABKA1SCmNoYW5uZWxOdW0SEAoDcH'
    'NrGAIgASgMUgNwc2sSEgoEbmFtZRgDIAEoCVIEbmFtZRIOCgJpZBgEIAEoB1ICaWQSJQoOdXBs'
    'aW5rX2VuYWJsZWQYBSABKAhSDXVwbGlua0VuYWJsZWQSKQoQZG93bmxpbmtfZW5hYmxlZBgGIA'
    'EoCFIPZG93bmxpbmtFbmFibGVkEkMKD21vZHVsZV9zZXR0aW5ncxgHIAEoCzIaLm1lc2h0YXN0'
    'aWMuTW9kdWxlU2V0dGluZ3NSDm1vZHVsZVNldHRpbmdz');

@$core.Deprecated('Use moduleSettingsDescriptor instead')
const ModuleSettings$json = {
  '1': 'ModuleSettings',
  '2': [
    {
      '1': 'position_precision',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'positionPrecision'
    },
    {'1': 'is_muted', '3': 2, '4': 1, '5': 8, '10': 'isMuted'},
  ],
};

/// Descriptor for `ModuleSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moduleSettingsDescriptor = $convert.base64Decode(
    'Cg5Nb2R1bGVTZXR0aW5ncxItChJwb3NpdGlvbl9wcmVjaXNpb24YASABKA1SEXBvc2l0aW9uUH'
    'JlY2lzaW9uEhkKCGlzX211dGVkGAIgASgIUgdpc011dGVk');

@$core.Deprecated('Use adminMessageDescriptor instead')
const AdminMessage$json = {
  '1': 'AdminMessage',
  '2': [
    {'1': 'session_passkey', '3': 101, '4': 1, '5': 12, '10': 'sessionPasskey'},
    {
      '1': 'get_channel_request',
      '3': 1,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'getChannelRequest'
    },
    {
      '1': 'get_channel_response',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Channel',
      '9': 0,
      '10': 'getChannelResponse'
    },
    {
      '1': 'get_owner_request',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getOwnerRequest'
    },
    {
      '1': 'get_owner_response',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.User',
      '9': 0,
      '10': 'getOwnerResponse'
    },
    {
      '1': 'get_config_request',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.AdminMessage.ConfigType',
      '9': 0,
      '10': 'getConfigRequest'
    },
    {
      '1': 'get_config_response',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config',
      '9': 0,
      '10': 'getConfigResponse'
    },
    {
      '1': 'get_module_config_request',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.AdminMessage.ModuleConfigType',
      '9': 0,
      '10': 'getModuleConfigRequest'
    },
    {
      '1': 'get_module_config_response',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig',
      '9': 0,
      '10': 'getModuleConfigResponse'
    },
    {
      '1': 'get_canned_message_module_messages_request',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getCannedMessageModuleMessagesRequest'
    },
    {
      '1': 'get_canned_message_module_messages_response',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'getCannedMessageModuleMessagesResponse'
    },
    {
      '1': 'get_device_metadata_request',
      '3': 12,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getDeviceMetadataRequest'
    },
    {
      '1': 'get_device_metadata_response',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DeviceMetadata',
      '9': 0,
      '10': 'getDeviceMetadataResponse'
    },
    {
      '1': 'get_ringtone_request',
      '3': 14,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getRingtoneRequest'
    },
    {
      '1': 'get_ringtone_response',
      '3': 15,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'getRingtoneResponse'
    },
    {
      '1': 'get_device_connection_status_request',
      '3': 16,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getDeviceConnectionStatusRequest'
    },
    {
      '1': 'get_device_connection_status_response',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DeviceConnectionStatus',
      '9': 0,
      '10': 'getDeviceConnectionStatusResponse'
    },
    {
      '1': 'set_ham_mode',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.HamParameters',
      '9': 0,
      '10': 'setHamMode'
    },
    {
      '1': 'get_node_remote_hardware_pins_request',
      '3': 19,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getNodeRemoteHardwarePinsRequest'
    },
    {
      '1': 'get_node_remote_hardware_pins_response',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.NodeRemoteHardwarePinsResponse',
      '9': 0,
      '10': 'getNodeRemoteHardwarePinsResponse'
    },
    {
      '1': 'enter_dfu_mode_request',
      '3': 21,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'enterDfuModeRequest'
    },
    {
      '1': 'delete_file_request',
      '3': 22,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'deleteFileRequest'
    },
    {'1': 'set_scale', '3': 23, '4': 1, '5': 13, '9': 0, '10': 'setScale'},
    {
      '1': 'set_owner',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.User',
      '9': 0,
      '10': 'setOwner'
    },
    {
      '1': 'set_channel',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Channel',
      '9': 0,
      '10': 'setChannel'
    },
    {
      '1': 'set_config',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config',
      '9': 0,
      '10': 'setConfig'
    },
    {
      '1': 'set_module_config',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig',
      '9': 0,
      '10': 'setModuleConfig'
    },
    {
      '1': 'set_canned_message_module_messages',
      '3': 36,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'setCannedMessageModuleMessages'
    },
    {
      '1': 'set_ringtone_message',
      '3': 37,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'setRingtoneMessage'
    },
    {
      '1': 'remove_by_nodenum',
      '3': 38,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'removeByNodenum'
    },
    {
      '1': 'set_favorite_node',
      '3': 39,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'setFavoriteNode'
    },
    {
      '1': 'remove_favorite_node',
      '3': 40,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'removeFavoriteNode'
    },
    {
      '1': 'set_fixed_position',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Position',
      '9': 0,
      '10': 'setFixedPosition'
    },
    {
      '1': 'remove_fixed_position',
      '3': 42,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'removeFixedPosition'
    },
    {
      '1': 'set_time_only',
      '3': 43,
      '4': 1,
      '5': 7,
      '9': 0,
      '10': 'setTimeOnly'
    },
    {
      '1': 'begin_edit_settings',
      '3': 64,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'beginEditSettings'
    },
    {
      '1': 'commit_edit_settings',
      '3': 65,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'commitEditSettings'
    },
    {
      '1': 'factory_reset_device',
      '3': 94,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'factoryResetDevice'
    },
    {
      '1': 'reboot_ota_seconds',
      '3': 95,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'rebootOtaSeconds'
    },
    {
      '1': 'exit_simulator',
      '3': 96,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'exitSimulator'
    },
    {
      '1': 'reboot_seconds',
      '3': 97,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'rebootSeconds'
    },
    {
      '1': 'shutdown_seconds',
      '3': 98,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'shutdownSeconds'
    },
    {
      '1': 'factory_reset_config',
      '3': 99,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'factoryResetConfig'
    },
    {
      '1': 'nodedb_reset',
      '3': 100,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'nodedbReset'
    },
  ],
  '4': [AdminMessage_ConfigType$json, AdminMessage_ModuleConfigType$json],
  '8': [
    {'1': 'payload_variant'},
  ],
};

@$core.Deprecated('Use adminMessageDescriptor instead')
const AdminMessage_ConfigType$json = {
  '1': 'ConfigType',
  '2': [
    {'1': 'DEVICE_CONFIG', '2': 0},
    {'1': 'POSITION_CONFIG', '2': 1},
    {'1': 'POWER_CONFIG', '2': 2},
    {'1': 'NETWORK_CONFIG', '2': 3},
    {'1': 'DISPLAY_CONFIG', '2': 4},
    {'1': 'LORA_CONFIG', '2': 5},
    {'1': 'BLUETOOTH_CONFIG', '2': 6},
    {'1': 'SECURITY_CONFIG', '2': 7},
    {'1': 'SESSIONKEY_CONFIG', '2': 8},
    {'1': 'DEVICEUI_CONFIG', '2': 9},
  ],
};

@$core.Deprecated('Use adminMessageDescriptor instead')
const AdminMessage_ModuleConfigType$json = {
  '1': 'ModuleConfigType',
  '2': [
    {'1': 'MQTT_CONFIG', '2': 0},
    {'1': 'SERIAL_CONFIG', '2': 1},
    {'1': 'EXTNOTIF_CONFIG', '2': 2},
    {'1': 'STOREFORWARD_CONFIG', '2': 3},
    {'1': 'RANGETEST_CONFIG', '2': 4},
    {'1': 'TELEMETRY_CONFIG', '2': 5},
    {'1': 'CANNEDMSG_CONFIG', '2': 6},
    {'1': 'AUDIO_CONFIG', '2': 7},
    {'1': 'REMOTEHARDWARE_CONFIG', '2': 8},
    {'1': 'NEIGHBORINFO_CONFIG', '2': 9},
    {'1': 'AMBIENTLIGHTING_CONFIG', '2': 10},
    {'1': 'DETECTIONSENSOR_CONFIG', '2': 11},
    {'1': 'PAXCOUNTER_CONFIG', '2': 12},
  ],
};

/// Descriptor for `AdminMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminMessageDescriptor = $convert.base64Decode(
    'CgxBZG1pbk1lc3NhZ2USJwoPc2Vzc2lvbl9wYXNza2V5GGUgASgMUg5zZXNzaW9uUGFzc2tleR'
    'IwChNnZXRfY2hhbm5lbF9yZXF1ZXN0GAEgASgNSABSEWdldENoYW5uZWxSZXF1ZXN0EkcKFGdl'
    'dF9jaGFubmVsX3Jlc3BvbnNlGAIgASgLMhMubWVzaHRhc3RpYy5DaGFubmVsSABSEmdldENoYW'
    '5uZWxSZXNwb25zZRIsChFnZXRfb3duZXJfcmVxdWVzdBgDIAEoCEgAUg9nZXRPd25lclJlcXVl'
    'c3QSQAoSZ2V0X293bmVyX3Jlc3BvbnNlGAQgASgLMhAubWVzaHRhc3RpYy5Vc2VySABSEGdldE'
    '93bmVyUmVzcG9uc2USUwoSZ2V0X2NvbmZpZ19yZXF1ZXN0GAUgASgOMiMubWVzaHRhc3RpYy5B'
    'ZG1pbk1lc3NhZ2UuQ29uZmlnVHlwZUgAUhBnZXRDb25maWdSZXF1ZXN0EkQKE2dldF9jb25maW'
    'dfcmVzcG9uc2UYBiABKAsyEi5tZXNodGFzdGljLkNvbmZpZ0gAUhFnZXRDb25maWdSZXNwb25z'
    'ZRJmChlnZXRfbW9kdWxlX2NvbmZpZ19yZXF1ZXN0GAcgASgOMikubWVzaHRhc3RpYy5BZG1pbk'
    '1lc3NhZ2UuTW9kdWxlQ29uZmlnVHlwZUgAUhZnZXRNb2R1bGVDb25maWdSZXF1ZXN0ElcKGmdl'
    'dF9tb2R1bGVfY29uZmlnX3Jlc3BvbnNlGAggASgLMhgubWVzaHRhc3RpYy5Nb2R1bGVDb25maW'
    'dIAFIXZ2V0TW9kdWxlQ29uZmlnUmVzcG9uc2USWwoqZ2V0X2Nhbm5lZF9tZXNzYWdlX21vZHVs'
    'ZV9tZXNzYWdlc19yZXF1ZXN0GAogASgISABSJWdldENhbm5lZE1lc3NhZ2VNb2R1bGVNZXNzYW'
    'dlc1JlcXVlc3QSXQorZ2V0X2Nhbm5lZF9tZXNzYWdlX21vZHVsZV9tZXNzYWdlc19yZXNwb25z'
    'ZRgLIAEoCUgAUiZnZXRDYW5uZWRNZXNzYWdlTW9kdWxlTWVzc2FnZXNSZXNwb25zZRI/ChtnZX'
    'RfZGV2aWNlX21ldGFkYXRhX3JlcXVlc3QYDCABKAhIAFIYZ2V0RGV2aWNlTWV0YWRhdGFSZXF1'
    'ZXN0El0KHGdldF9kZXZpY2VfbWV0YWRhdGFfcmVzcG9uc2UYDSABKAsyGi5tZXNodGFzdGljLk'
    'RldmljZU1ldGFkYXRhSABSGWdldERldmljZU1ldGFkYXRhUmVzcG9uc2USMgoUZ2V0X3Jpbmd0'
    'b25lX3JlcXVlc3QYDiABKAhIAFISZ2V0UmluZ3RvbmVSZXF1ZXN0EjQKFWdldF9yaW5ndG9uZV'
    '9yZXNwb25zZRgPIAEoCUgAUhNnZXRSaW5ndG9uZVJlc3BvbnNlElAKJGdldF9kZXZpY2VfY29u'
    'bmVjdGlvbl9zdGF0dXNfcmVxdWVzdBgQIAEoCEgAUiBnZXREZXZpY2VDb25uZWN0aW9uU3RhdH'
    'VzUmVxdWVzdBJ2CiVnZXRfZGV2aWNlX2Nvbm5lY3Rpb25fc3RhdHVzX3Jlc3BvbnNlGBEgASgL'
    'MiIubWVzaHRhc3RpYy5EZXZpY2VDb25uZWN0aW9uU3RhdHVzSABSIWdldERldmljZUNvbm5lY3'
    'Rpb25TdGF0dXNSZXNwb25zZRI9CgxzZXRfaGFtX21vZGUYEiABKAsyGS5tZXNodGFzdGljLkhh'
    'bVBhcmFtZXRlcnNIAFIKc2V0SGFtTW9kZRJRCiVnZXRfbm9kZV9yZW1vdGVfaGFyZHdhcmVfcG'
    'luc19yZXF1ZXN0GBMgASgISABSIGdldE5vZGVSZW1vdGVIYXJkd2FyZVBpbnNSZXF1ZXN0En8K'
    'JmdldF9ub2RlX3JlbW90ZV9oYXJkd2FyZV9waW5zX3Jlc3BvbnNlGBQgASgLMioubWVzaHRhc3'
    'RpYy5Ob2RlUmVtb3RlSGFyZHdhcmVQaW5zUmVzcG9uc2VIAFIhZ2V0Tm9kZVJlbW90ZUhhcmR3'
    'YXJlUGluc1Jlc3BvbnNlEjUKFmVudGVyX2RmdV9tb2RlX3JlcXVlc3QYFSABKAhIAFITZW50ZX'
    'JEZnVNb2RlUmVxdWVzdBIwChNkZWxldGVfZmlsZV9yZXF1ZXN0GBYgASgJSABSEWRlbGV0ZUZp'
    'bGVSZXF1ZXN0Eh0KCXNldF9zY2FsZRgXIAEoDUgAUghzZXRTY2FsZRIvCglzZXRfb3duZXIYIC'
    'ABKAsyEC5tZXNodGFzdGljLlVzZXJIAFIIc2V0T3duZXISNgoLc2V0X2NoYW5uZWwYISABKAsy'
    'Ey5tZXNodGFzdGljLkNoYW5uZWxIAFIKc2V0Q2hhbm5lbBIzCgpzZXRfY29uZmlnGCIgASgLMh'
    'IubWVzaHRhc3RpYy5Db25maWdIAFIJc2V0Q29uZmlnEkYKEXNldF9tb2R1bGVfY29uZmlnGCMg'
    'ASgLMhgubWVzaHRhc3RpYy5Nb2R1bGVDb25maWdIAFIPc2V0TW9kdWxlQ29uZmlnEkwKInNldF'
    '9jYW5uZWRfbWVzc2FnZV9tb2R1bGVfbWVzc2FnZXMYJCABKAlIAFIec2V0Q2FubmVkTWVzc2Fn'
    'ZU1vZHVsZU1lc3NhZ2VzEjIKFHNldF9yaW5ndG9uZV9tZXNzYWdlGCUgASgJSABSEnNldFJpbm'
    'd0b25lTWVzc2FnZRIsChFyZW1vdmVfYnlfbm9kZW51bRgmIAEoDUgAUg9yZW1vdmVCeU5vZGVu'
    'dW0SLAoRc2V0X2Zhdm9yaXRlX25vZGUYJyABKA1IAFIPc2V0RmF2b3JpdGVOb2RlEjIKFHJlbW'
    '92ZV9mYXZvcml0ZV9ub2RlGCggASgNSABSEnJlbW92ZUZhdm9yaXRlTm9kZRJEChJzZXRfZml4'
    'ZWRfcG9zaXRpb24YKSABKAsyFC5tZXNodGFzdGljLlBvc2l0aW9uSABSEHNldEZpeGVkUG9zaX'
    'Rpb24SNAoVcmVtb3ZlX2ZpeGVkX3Bvc2l0aW9uGCogASgISABSE3JlbW92ZUZpeGVkUG9zaXRp'
    'b24SJAoNc2V0X3RpbWVfb25seRgrIAEoB0gAUgtzZXRUaW1lT25seRIwChNiZWdpbl9lZGl0X3'
    'NldHRpbmdzGEAgASgISABSEWJlZ2luRWRpdFNldHRpbmdzEjIKFGNvbW1pdF9lZGl0X3NldHRp'
    'bmdzGEEgASgISABSEmNvbW1pdEVkaXRTZXR0aW5ncxIyChRmYWN0b3J5X3Jlc2V0X2RldmljZR'
    'heIAEoBUgAUhJmYWN0b3J5UmVzZXREZXZpY2USLgoScmVib290X290YV9zZWNvbmRzGF8gASgF'
    'SABSEHJlYm9vdE90YVNlY29uZHMSJwoOZXhpdF9zaW11bGF0b3IYYCABKAhIAFINZXhpdFNpbX'
    'VsYXRvchInCg5yZWJvb3Rfc2Vjb25kcxhhIAEoBUgAUg1yZWJvb3RTZWNvbmRzEisKEHNodXRk'
    'b3duX3NlY29uZHMYYiABKAVIAFIPc2h1dGRvd25TZWNvbmRzEjIKFGZhY3RvcnlfcmVzZXRfY2'
    '9uZmlnGGMgASgFSABSEmZhY3RvcnlSZXNldENvbmZpZxIjCgxub2RlZGJfcmVzZXQYZCABKAhI'
    'AFILbm9kZWRiUmVzZXQi1gEKCkNvbmZpZ1R5cGUSEQoNREVWSUNFX0NPTkZJRxAAEhMKD1BPU0'
    'lUSU9OX0NPTkZJRxABEhAKDFBPV0VSX0NPTkZJRxACEhIKDk5FVFdPUktfQ09ORklHEAMSEgoO'
    'RElTUExBWV9DT05GSUcQBBIPCgtMT1JBX0NPTkZJRxAFEhQKEEJMVUVUT09USF9DT05GSUcQBh'
    'ITCg9TRUNVUklUWV9DT05GSUcQBxIVChFTRVNTSU9OS0VZX0NPTkZJRxAIEhMKD0RFVklDRVVJ'
    'X0NPTkZJRxAJIrsCChBNb2R1bGVDb25maWdUeXBlEg8KC01RVFRfQ09ORklHEAASEQoNU0VSSU'
    'FMX0NPTkZJRxABEhMKD0VYVE5PVElGX0NPTkZJRxACEhcKE1NUT1JFRk9SV0FSRF9DT05GSUcQ'
    'AxIUChBSQU5HRVRFU1RfQ09ORklHEAQSFAoQVEVMRU1FVFJZX0NPTkZJRxAFEhQKEENBTk5FRE'
    '1TR19DT05GSUcQBhIQCgxBVURJT19DT05GSUcQBxIZChVSRU1PVEVIQVJEV0FSRV9DT05GSUcQ'
    'CBIXChNORUlHSEJPUklORk9fQ09ORklHEAkSGgoWQU1CSUVOVExJR0hUSU5HX0NPTkZJRxAKEh'
    'oKFkRFVEVDVElPTlNFTlNPUl9DT05GSUcQCxIVChFQQVhDT1VOVEVSX0NPTkZJRxAMQhEKD3Bh'
    'eWxvYWRfdmFyaWFudA==');

@$core.Deprecated('Use hamParametersDescriptor instead')
const HamParameters$json = {
  '1': 'HamParameters',
  '2': [
    {'1': 'call_sign', '3': 1, '4': 1, '5': 9, '10': 'callSign'},
    {'1': 'tx_power', '3': 2, '4': 1, '5': 5, '10': 'txPower'},
    {'1': 'frequency', '3': 3, '4': 1, '5': 2, '10': 'frequency'},
    {'1': 'short_name', '3': 4, '4': 1, '5': 9, '10': 'shortName'},
  ],
};

/// Descriptor for `HamParameters`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hamParametersDescriptor = $convert.base64Decode(
    'Cg1IYW1QYXJhbWV0ZXJzEhsKCWNhbGxfc2lnbhgBIAEoCVIIY2FsbFNpZ24SGQoIdHhfcG93ZX'
    'IYAiABKAVSB3R4UG93ZXISHAoJZnJlcXVlbmN5GAMgASgCUglmcmVxdWVuY3kSHQoKc2hvcnRf'
    'bmFtZRgEIAEoCVIJc2hvcnROYW1l');

@$core.Deprecated('Use deviceConnectionStatusDescriptor instead')
const DeviceConnectionStatus$json = {
  '1': 'DeviceConnectionStatus',
  '2': [
    {'1': 'wifi_connected', '3': 1, '4': 1, '5': 8, '10': 'wifiConnected'},
    {
      '1': 'ethernet_connected',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'ethernetConnected'
    },
    {
      '1': 'bluetooth_connected',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'bluetoothConnected'
    },
    {'1': 'serial_connected', '3': 4, '4': 1, '5': 8, '10': 'serialConnected'},
  ],
};

/// Descriptor for `DeviceConnectionStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceConnectionStatusDescriptor = $convert.base64Decode(
    'ChZEZXZpY2VDb25uZWN0aW9uU3RhdHVzEiUKDndpZmlfY29ubmVjdGVkGAEgASgIUg13aWZpQ2'
    '9ubmVjdGVkEi0KEmV0aGVybmV0X2Nvbm5lY3RlZBgCIAEoCFIRZXRoZXJuZXRDb25uZWN0ZWQS'
    'LwoTYmx1ZXRvb3RoX2Nvbm5lY3RlZBgDIAEoCFISYmx1ZXRvb3RoQ29ubmVjdGVkEikKEHNlcm'
    'lhbF9jb25uZWN0ZWQYBCABKAhSD3NlcmlhbENvbm5lY3RlZA==');

@$core.Deprecated('Use deviceMetadataDescriptor instead')
const DeviceMetadata$json = {
  '1': 'DeviceMetadata',
  '2': [
    {'1': 'firmware_version', '3': 1, '4': 1, '5': 9, '10': 'firmwareVersion'},
    {
      '1': 'device_state_version',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'deviceStateVersion'
    },
    {'1': 'can_shutdown', '3': 3, '4': 1, '5': 8, '10': 'canShutdown'},
    {'1': 'has_wifi', '3': 4, '4': 1, '5': 8, '10': 'hasWifi'},
    {'1': 'has_bluetooth', '3': 5, '4': 1, '5': 8, '10': 'hasBluetooth'},
    {'1': 'has_ethernet', '3': 6, '4': 1, '5': 8, '10': 'hasEthernet'},
    {
      '1': 'role',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config_DeviceConfig_Role',
      '10': 'role'
    },
    {'1': 'position_flags', '3': 8, '4': 1, '5': 13, '10': 'positionFlags'},
    {
      '1': 'hw_model',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.HardwareModel',
      '10': 'hwModel'
    },
    {
      '1': 'has_remote_hardware',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'hasRemoteHardware'
    },
    {'1': 'has_pkc', '3': 11, '4': 1, '5': 8, '10': 'hasPkc'},
  ],
};

/// Descriptor for `DeviceMetadata`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceMetadataDescriptor = $convert.base64Decode(
    'Cg5EZXZpY2VNZXRhZGF0YRIpChBmaXJtd2FyZV92ZXJzaW9uGAEgASgJUg9maXJtd2FyZVZlcn'
    'Npb24SMAoUZGV2aWNlX3N0YXRlX3ZlcnNpb24YAiABKA1SEmRldmljZVN0YXRlVmVyc2lvbhIh'
    'CgxjYW5fc2h1dGRvd24YAyABKAhSC2NhblNodXRkb3duEhkKCGhhc193aWZpGAQgASgIUgdoYX'
    'NXaWZpEiMKDWhhc19ibHVldG9vdGgYBSABKAhSDGhhc0JsdWV0b290aBIhCgxoYXNfZXRoZXJu'
    'ZXQYBiABKAhSC2hhc0V0aGVybmV0EjgKBHJvbGUYByABKA4yJC5tZXNodGFzdGljLkNvbmZpZ1'
    '9EZXZpY2VDb25maWdfUm9sZVIEcm9sZRIlCg5wb3NpdGlvbl9mbGFncxgIIAEoDVINcG9zaXRp'
    'b25GbGFncxI0Cghod19tb2RlbBgJIAEoDjIZLm1lc2h0YXN0aWMuSGFyZHdhcmVNb2RlbFIHaH'
    'dNb2RlbBIuChNoYXNfcmVtb3RlX2hhcmR3YXJlGAogASgIUhFoYXNSZW1vdGVIYXJkd2FyZRIX'
    'CgdoYXNfcGtjGAsgASgIUgZoYXNQa2M=');

@$core.Deprecated('Use nodeRemoteHardwarePinDescriptor instead')
const NodeRemoteHardwarePin$json = {
  '1': 'NodeRemoteHardwarePin',
  '2': [
    {'1': 'node_num', '3': 1, '4': 1, '5': 13, '10': 'nodeNum'},
    {
      '1': 'pin',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RemoteHardwarePin',
      '10': 'pin'
    },
  ],
};

/// Descriptor for `NodeRemoteHardwarePin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeRemoteHardwarePinDescriptor = $convert.base64Decode(
    'ChVOb2RlUmVtb3RlSGFyZHdhcmVQaW4SGQoIbm9kZV9udW0YASABKA1SB25vZGVOdW0SLwoDcG'
    'luGAIgASgLMh0ubWVzaHRhc3RpYy5SZW1vdGVIYXJkd2FyZVBpblIDcGlu');

@$core.Deprecated('Use remoteHardwarePinDescriptor instead')
const RemoteHardwarePin$json = {
  '1': 'RemoteHardwarePin',
  '2': [
    {'1': 'gpio_pin', '3': 1, '4': 1, '5': 13, '10': 'gpioPin'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.RemoteHardwarePinType',
      '10': 'type'
    },
  ],
};

/// Descriptor for `RemoteHardwarePin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteHardwarePinDescriptor = $convert.base64Decode(
    'ChFSZW1vdGVIYXJkd2FyZVBpbhIZCghncGlvX3BpbhgBIAEoDVIHZ3Bpb1BpbhISCgRuYW1lGA'
    'IgASgJUgRuYW1lEjUKBHR5cGUYAyABKA4yIS5tZXNodGFzdGljLlJlbW90ZUhhcmR3YXJlUGlu'
    'VHlwZVIEdHlwZQ==');

@$core.Deprecated('Use nodeRemoteHardwarePinsResponseDescriptor instead')
const NodeRemoteHardwarePinsResponse$json = {
  '1': 'NodeRemoteHardwarePinsResponse',
  '2': [
    {
      '1': 'node_remote_hardware_pins',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.NodeRemoteHardwarePin',
      '10': 'nodeRemoteHardwarePins'
    },
  ],
};

/// Descriptor for `NodeRemoteHardwarePinsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeRemoteHardwarePinsResponseDescriptor =
    $convert.base64Decode(
        'Ch5Ob2RlUmVtb3RlSGFyZHdhcmVQaW5zUmVzcG9uc2USXAoZbm9kZV9yZW1vdGVfaGFyZHdhcm'
        'VfcGlucxgBIAMoCzIhLm1lc2h0YXN0aWMuTm9kZVJlbW90ZUhhcmR3YXJlUGluUhZub2RlUmVt'
        'b3RlSGFyZHdhcmVQaW5z');

@$core.Deprecated('Use configDescriptor instead')
const Config$json = {
  '1': 'Config',
  '2': [
    {
      '1': 'device',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.DeviceConfig',
      '9': 0,
      '10': 'device'
    },
    {
      '1': 'position',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.PositionConfig',
      '9': 0,
      '10': 'position'
    },
    {
      '1': 'power',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.PowerConfig',
      '9': 0,
      '10': 'power'
    },
    {
      '1': 'network',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.NetworkConfig',
      '9': 0,
      '10': 'network'
    },
    {
      '1': 'display',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.DisplayConfig',
      '9': 0,
      '10': 'display'
    },
    {
      '1': 'lora',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.LoRaConfig',
      '9': 0,
      '10': 'lora'
    },
    {
      '1': 'bluetooth',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.BluetoothConfig',
      '9': 0,
      '10': 'bluetooth'
    },
    {
      '1': 'security',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.SecurityConfig',
      '9': 0,
      '10': 'security'
    },
    {
      '1': 'sessionkey',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.SessionkeyConfig',
      '9': 0,
      '10': 'sessionkey'
    },
  ],
  '3': [
    Config_DeviceConfig$json,
    Config_PositionConfig$json,
    Config_PowerConfig$json,
    Config_NetworkConfig$json,
    Config_DisplayConfig$json,
    Config_LoRaConfig$json,
    Config_BluetoothConfig$json,
    Config_SecurityConfig$json,
    Config_SessionkeyConfig$json
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig$json = {
  '1': 'DeviceConfig',
  '2': [
    {
      '1': 'role',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.Role',
      '10': 'role'
    },
    {'1': 'serial_enabled', '3': 2, '4': 1, '5': 8, '10': 'serialEnabled'},
    {'1': 'button_gpio', '3': 4, '4': 1, '5': 13, '10': 'buttonGpio'},
    {'1': 'buzzer_gpio', '3': 5, '4': 1, '5': 13, '10': 'buzzerGpio'},
    {
      '1': 'rebroadcast_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.RebroadcastMode',
      '10': 'rebroadcastMode'
    },
    {
      '1': 'node_info_broadcast_secs',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'nodeInfoBroadcastSecs'
    },
    {
      '1': 'double_tap_as_button_press',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'doubleTapAsButtonPress'
    },
    {'1': 'is_managed', '3': 9, '4': 1, '5': 8, '10': 'isManaged'},
    {
      '1': 'disable_triple_click',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'disableTripleClick'
    },
    {'1': 'tzdef', '3': 11, '4': 1, '5': 9, '10': 'tzdef'},
    {
      '1': 'led_heartbeat_disabled',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'ledHeartbeatDisabled'
    },
  ],
  '4': [
    Config_DeviceConfig_Role_$json,
    Config_DeviceConfig_RebroadcastMode$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_Role_$json = {
  '1': 'Role',
  '2': [
    {'1': 'CLIENT', '2': 0},
    {'1': 'CLIENT_MUTE', '2': 1},
    {'1': 'ROUTER', '2': 2},
    {'1': 'ROUTER_CLIENT', '2': 3},
    {'1': 'REPEATER', '2': 4},
    {'1': 'TRACKER', '2': 5},
    {'1': 'SENSOR', '2': 6},
    {'1': 'TAK', '2': 7},
    {'1': 'CLIENT_HIDDEN', '2': 8},
    {'1': 'LOST_AND_FOUND', '2': 9},
    {'1': 'TAK_TRACKER', '2': 10},
    {'1': 'ROUTER_LATE', '2': 11},
    {'1': 'CLIENT_BASE', '2': 12},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_RebroadcastMode$json = {
  '1': 'RebroadcastMode',
  '2': [
    {'1': 'ALL', '2': 0},
    {'1': 'ALL_SKIP_DECODING', '2': 1},
    {'1': 'LOCAL_ONLY', '2': 2},
    {'1': 'KNOWN_ONLY', '2': 3},
    {'1': 'NONE', '2': 4},
    {'1': 'CORE_PORTNUMS_ONLY', '2': 5},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig$json = {
  '1': 'PositionConfig',
  '2': [
    {
      '1': 'position_broadcast_secs',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'positionBroadcastSecs'
    },
    {
      '1': 'position_broadcast_smart_enabled',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'positionBroadcastSmartEnabled'
    },
    {'1': 'fixed_position', '3': 3, '4': 1, '5': 8, '10': 'fixedPosition'},
    {'1': 'gps_enabled', '3': 4, '4': 1, '5': 8, '10': 'gpsEnabled'},
    {
      '1': 'gps_update_interval',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'gpsUpdateInterval'
    },
    {'1': 'gps_attempt_time', '3': 6, '4': 1, '5': 13, '10': 'gpsAttemptTime'},
    {'1': 'position_flags', '3': 7, '4': 1, '5': 13, '10': 'positionFlags'},
    {'1': 'rx_gpio', '3': 8, '4': 1, '5': 13, '10': 'rxGpio'},
    {'1': 'tx_gpio', '3': 9, '4': 1, '5': 13, '10': 'txGpio'},
    {
      '1': 'broadcast_smart_minimum_distance',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'broadcastSmartMinimumDistance'
    },
    {
      '1': 'broadcast_smart_minimum_interval_secs',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'broadcastSmartMinimumIntervalSecs'
    },
    {'1': 'gps_en_gpio', '3': 12, '4': 1, '5': 13, '10': 'gpsEnGpio'},
    {
      '1': 'gps_mode',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.PositionConfig.GpsMode',
      '10': 'gpsMode'
    },
  ],
  '4': [Config_PositionConfig_GpsMode$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig_GpsMode$json = {
  '1': 'GpsMode',
  '2': [
    {'1': 'DISABLED', '2': 0},
    {'1': 'ENABLED', '2': 1},
    {'1': 'NOT_PRESENT', '2': 2},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PowerConfig$json = {
  '1': 'PowerConfig',
  '2': [
    {'1': 'is_power_saving', '3': 1, '4': 1, '5': 8, '10': 'isPowerSaving'},
    {
      '1': 'on_battery_shutdown_after_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'onBatteryShutdownAfterSecs'
    },
    {
      '1': 'adc_multiplier_override',
      '3': 3,
      '4': 1,
      '5': 2,
      '10': 'adcMultiplierOverride'
    },
    {
      '1': 'wait_bluetooth_secs',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'waitBluetoothSecs'
    },
    {'1': 'sds_secs', '3': 6, '4': 1, '5': 13, '10': 'sdsSecs'},
    {'1': 'ls_secs', '3': 7, '4': 1, '5': 13, '10': 'lsSecs'},
    {'1': 'min_wake_secs', '3': 8, '4': 1, '5': 13, '10': 'minWakeSecs'},
    {
      '1': 'device_battery_ina_address',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'deviceBatteryInaAddress'
    },
    {'1': 'powermon_enables', '3': 32, '4': 1, '5': 4, '10': 'powermonEnables'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig$json = {
  '1': 'NetworkConfig',
  '2': [
    {'1': 'wifi_enabled', '3': 1, '4': 1, '5': 8, '10': 'wifiEnabled'},
    {'1': 'wifi_ssid', '3': 3, '4': 1, '5': 9, '10': 'wifiSsid'},
    {'1': 'wifi_psk', '3': 4, '4': 1, '5': 9, '10': 'wifiPsk'},
    {'1': 'ntp_server', '3': 5, '4': 1, '5': 9, '10': 'ntpServer'},
    {'1': 'eth_enabled', '3': 6, '4': 1, '5': 8, '10': 'ethEnabled'},
    {
      '1': 'address_mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.NetworkConfig.AddressMode',
      '10': 'addressMode'
    },
    {
      '1': 'ipv4_config',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.NetworkConfig.IpV4Config',
      '10': 'ipv4Config'
    },
    {'1': 'rsyslog_server', '3': 9, '4': 1, '5': 9, '10': 'rsyslogServer'},
    {
      '1': 'enabled_protocols',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'enabledProtocols'
    },
    {'1': 'ipv6_enabled', '3': 11, '4': 1, '5': 8, '10': 'ipv6Enabled'},
  ],
  '3': [Config_NetworkConfig_IpV4Config$json],
  '4': [Config_NetworkConfig_AddressMode$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_IpV4Config$json = {
  '1': 'IpV4Config',
  '2': [
    {'1': 'ip', '3': 1, '4': 1, '5': 7, '10': 'ip'},
    {'1': 'gateway', '3': 2, '4': 1, '5': 7, '10': 'gateway'},
    {'1': 'subnet', '3': 3, '4': 1, '5': 7, '10': 'subnet'},
    {'1': 'dns', '3': 4, '4': 1, '5': 7, '10': 'dns'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_AddressMode$json = {
  '1': 'AddressMode',
  '2': [
    {'1': 'DHCP', '2': 0},
    {'1': 'STATIC', '2': 1},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig$json = {
  '1': 'DisplayConfig',
  '2': [
    {'1': 'screen_on_secs', '3': 1, '4': 1, '5': 13, '10': 'screenOnSecs'},
    {'1': 'gps_format', '3': 2, '4': 1, '5': 13, '10': 'gpsFormat'},
    {
      '1': 'auto_screen_carousel_secs',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'autoScreenCarouselSecs'
    },
    {'1': 'compass_north_top', '3': 4, '4': 1, '5': 8, '10': 'compassNorthTop'},
    {'1': 'flip_screen', '3': 5, '4': 1, '5': 8, '10': 'flipScreen'},
    {
      '1': 'units',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayUnits',
      '10': 'units'
    },
    {
      '1': 'oled',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.OledType',
      '10': 'oled'
    },
    {
      '1': 'displaymode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayMode',
      '10': 'displaymode'
    },
    {'1': 'heading_bold', '3': 9, '4': 1, '5': 8, '10': 'headingBold'},
    {
      '1': 'wake_on_tap_or_motion',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'wakeOnTapOrMotion'
    },
    {
      '1': 'compass_orientation',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.CompassOrientation',
      '10': 'compassOrientation'
    },
    {'1': 'use_12h_clock', '3': 12, '4': 1, '5': 8, '10': 'use12hClock'},
    {
      '1': 'use_long_node_name',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'useLongNodeName'
    },
  ],
  '4': [
    Config_DisplayConfig_DisplayUnits$json,
    Config_DisplayConfig_OledType$json,
    Config_DisplayConfig_DisplayMode$json,
    Config_DisplayConfig_CompassOrientation$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DisplayUnits$json = {
  '1': 'DisplayUnits',
  '2': [
    {'1': 'METRIC', '2': 0},
    {'1': 'IMPERIAL', '2': 1},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_OledType$json = {
  '1': 'OledType',
  '2': [
    {'1': 'OLED_AUTO', '2': 0},
    {'1': 'OLED_SSD1306', '2': 1},
    {'1': 'OLED_SH1106', '2': 2},
    {'1': 'OLED_SH1107', '2': 3},
    {'1': 'OLED_SH1107_128_128', '2': 4},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DisplayMode$json = {
  '1': 'DisplayMode',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'TWOCOLOR', '2': 1},
    {'1': 'INVERTED', '2': 2},
    {'1': 'COLOR', '2': 3},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_CompassOrientation$json = {
  '1': 'CompassOrientation',
  '2': [
    {'1': 'DEGREES_0', '2': 0},
    {'1': 'DEGREES_90', '2': 1},
    {'1': 'DEGREES_180', '2': 2},
    {'1': 'DEGREES_270', '2': 3},
    {'1': 'DEGREES_0_INVERTED', '2': 4},
    {'1': 'DEGREES_90_INVERTED', '2': 5},
    {'1': 'DEGREES_180_INVERTED', '2': 6},
    {'1': 'DEGREES_270_INVERTED', '2': 7},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig$json = {
  '1': 'LoRaConfig',
  '2': [
    {'1': 'use_preset', '3': 1, '4': 1, '5': 8, '10': 'usePreset'},
    {
      '1': 'modem_preset',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModemPreset',
      '10': 'modemPreset'
    },
    {'1': 'bandwidth', '3': 3, '4': 1, '5': 13, '10': 'bandwidth'},
    {'1': 'spread_factor', '3': 4, '4': 1, '5': 13, '10': 'spreadFactor'},
    {'1': 'coding_rate', '3': 5, '4': 1, '5': 13, '10': 'codingRate'},
    {'1': 'frequency_offset', '3': 6, '4': 1, '5': 2, '10': 'frequencyOffset'},
    {
      '1': 'region',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.RegionCode',
      '10': 'region'
    },
    {'1': 'hop_limit', '3': 8, '4': 1, '5': 13, '10': 'hopLimit'},
    {'1': 'tx_enabled', '3': 9, '4': 1, '5': 8, '10': 'txEnabled'},
    {'1': 'tx_power', '3': 10, '4': 1, '5': 5, '10': 'txPower'},
    {'1': 'channel_num', '3': 11, '4': 1, '5': 13, '10': 'channelNum'},
    {
      '1': 'override_duty_cycle',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'overrideDutyCycle'
    },
    {
      '1': 'sx126x_rx_boosted_gain',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'sx126xRxBoostedGain'
    },
    {
      '1': 'override_frequency',
      '3': 14,
      '4': 1,
      '5': 2,
      '10': 'overrideFrequency'
    },
    {'1': 'pa_fan_disabled', '3': 15, '4': 1, '5': 8, '10': 'paFanDisabled'},
    {'1': 'ignore_incoming', '3': 103, '4': 3, '5': 13, '10': 'ignoreIncoming'},
    {'1': 'ignore_mqtt', '3': 104, '4': 1, '5': 8, '10': 'ignoreMqtt'},
    {
      '1': 'config_ok_to_mqtt',
      '3': 105,
      '4': 1,
      '5': 8,
      '10': 'configOkToMqtt'
    },
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig$json = {
  '1': 'BluetoothConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'mode',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.BluetoothConfig.PairingMode',
      '10': 'mode'
    },
    {'1': 'fixed_pin', '3': 3, '4': 1, '5': 13, '10': 'fixedPin'},
  ],
  '4': [Config_BluetoothConfig_PairingMode$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig_PairingMode$json = {
  '1': 'PairingMode',
  '2': [
    {'1': 'RANDOM_PIN', '2': 0},
    {'1': 'FIXED_PIN', '2': 1},
    {'1': 'NO_PIN', '2': 2},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SecurityConfig$json = {
  '1': 'SecurityConfig',
  '2': [
    {'1': 'public_key', '3': 1, '4': 1, '5': 12, '10': 'publicKey'},
    {'1': 'private_key', '3': 2, '4': 1, '5': 12, '10': 'privateKey'},
    {'1': 'admin_key', '3': 3, '4': 3, '5': 12, '10': 'adminKey'},
    {'1': 'is_managed', '3': 4, '4': 1, '5': 8, '10': 'isManaged'},
    {'1': 'serial_enabled', '3': 5, '4': 1, '5': 8, '10': 'serialEnabled'},
    {
      '1': 'debug_log_api_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'debugLogApiEnabled'
    },
    {
      '1': 'admin_channel_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'adminChannelEnabled'
    },
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SessionkeyConfig$json = {
  '1': 'SessionkeyConfig',
};

/// Descriptor for `Config`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configDescriptor = $convert.base64Decode(
    'CgZDb25maWcSOQoGZGV2aWNlGAEgASgLMh8ubWVzaHRhc3RpYy5Db25maWcuRGV2aWNlQ29uZm'
    'lnSABSBmRldmljZRI/Cghwb3NpdGlvbhgCIAEoCzIhLm1lc2h0YXN0aWMuQ29uZmlnLlBvc2l0'
    'aW9uQ29uZmlnSABSCHBvc2l0aW9uEjYKBXBvd2VyGAMgASgLMh4ubWVzaHRhc3RpYy5Db25maW'
    'cuUG93ZXJDb25maWdIAFIFcG93ZXISPAoHbmV0d29yaxgEIAEoCzIgLm1lc2h0YXN0aWMuQ29u'
    'ZmlnLk5ldHdvcmtDb25maWdIAFIHbmV0d29yaxI8CgdkaXNwbGF5GAUgASgLMiAubWVzaHRhc3'
    'RpYy5Db25maWcuRGlzcGxheUNvbmZpZ0gAUgdkaXNwbGF5EjMKBGxvcmEYBiABKAsyHS5tZXNo'
    'dGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnSABSBGxvcmESQgoJYmx1ZXRvb3RoGAcgASgLMiIubW'
    'VzaHRhc3RpYy5Db25maWcuQmx1ZXRvb3RoQ29uZmlnSABSCWJsdWV0b290aBI/CghzZWN1cml0'
    'eRgIIAEoCzIhLm1lc2h0YXN0aWMuQ29uZmlnLlNlY3VyaXR5Q29uZmlnSABSCHNlY3VyaXR5Ek'
    'UKCnNlc3Npb25rZXkYCSABKAsyIy5tZXNodGFzdGljLkNvbmZpZy5TZXNzaW9ua2V5Q29uZmln'
    'SABSCnNlc3Npb25rZXka4wYKDERldmljZUNvbmZpZxI4CgRyb2xlGAEgASgOMiQubWVzaHRhc3'
    'RpYy5Db25maWcuRGV2aWNlQ29uZmlnLlJvbGVSBHJvbGUSJQoOc2VyaWFsX2VuYWJsZWQYAiAB'
    'KAhSDXNlcmlhbEVuYWJsZWQSHwoLYnV0dG9uX2dwaW8YBCABKA1SCmJ1dHRvbkdwaW8SHwoLYn'
    'V6emVyX2dwaW8YBSABKA1SCmJ1enplckdwaW8SWgoQcmVicm9hZGNhc3RfbW9kZRgGIAEoDjIv'
    'Lm1lc2h0YXN0aWMuQ29uZmlnLkRldmljZUNvbmZpZy5SZWJyb2FkY2FzdE1vZGVSD3JlYnJvYW'
    'RjYXN0TW9kZRI3Chhub2RlX2luZm9fYnJvYWRjYXN0X3NlY3MYByABKA1SFW5vZGVJbmZvQnJv'
    'YWRjYXN0U2VjcxI6Chpkb3VibGVfdGFwX2FzX2J1dHRvbl9wcmVzcxgIIAEoCFIWZG91YmxlVG'
    'FwQXNCdXR0b25QcmVzcxIdCgppc19tYW5hZ2VkGAkgASgIUglpc01hbmFnZWQSMAoUZGlzYWJs'
    'ZV90cmlwbGVfY2xpY2sYCiABKAhSEmRpc2FibGVUcmlwbGVDbGljaxIUCgV0emRlZhgLIAEoCV'
    'IFdHpkZWYSNAoWbGVkX2hlYXJ0YmVhdF9kaXNhYmxlZBgMIAEoCFIUbGVkSGVhcnRiZWF0RGlz'
    'YWJsZWQizAEKBFJvbGUSCgoGQ0xJRU5UEAASDwoLQ0xJRU5UX01VVEUQARIKCgZST1VURVIQAh'
    'IRCg1ST1VURVJfQ0xJRU5UEAMSDAoIUkVQRUFURVIQBBILCgdUUkFDS0VSEAUSCgoGU0VOU09S'
    'EAYSBwoDVEFLEAcSEQoNQ0xJRU5UX0hJRERFThAIEhIKDkxPU1RfQU5EX0ZPVU5EEAkSDwoLVE'
    'FLX1RSQUNLRVIQChIPCgtST1VURVJfTEFURRALEg8KC0NMSUVOVF9CQVNFEAwicwoPUmVicm9h'
    'ZGNhc3RNb2RlEgcKA0FMTBAAEhUKEUFMTF9TS0lQX0RFQ09ESU5HEAESDgoKTE9DQUxfT05MWR'
    'ACEg4KCktOT1dOX09OTFkQAxIICgROT05FEAQSFgoSQ09SRV9QT1JUTlVNU19PTkxZEAUaxAUK'
    'DlBvc2l0aW9uQ29uZmlnEjYKF3Bvc2l0aW9uX2Jyb2FkY2FzdF9zZWNzGAEgASgNUhVwb3NpdG'
    'lvbkJyb2FkY2FzdFNlY3MSRwogcG9zaXRpb25fYnJvYWRjYXN0X3NtYXJ0X2VuYWJsZWQYAiAB'
    'KAhSHXBvc2l0aW9uQnJvYWRjYXN0U21hcnRFbmFibGVkEiUKDmZpeGVkX3Bvc2l0aW9uGAMgAS'
    'gIUg1maXhlZFBvc2l0aW9uEh8KC2dwc19lbmFibGVkGAQgASgIUgpncHNFbmFibGVkEi4KE2dw'
    'c191cGRhdGVfaW50ZXJ2YWwYBSABKA1SEWdwc1VwZGF0ZUludGVydmFsEigKEGdwc19hdHRlbX'
    'B0X3RpbWUYBiABKA1SDmdwc0F0dGVtcHRUaW1lEiUKDnBvc2l0aW9uX2ZsYWdzGAcgASgNUg1w'
    'b3NpdGlvbkZsYWdzEhcKB3J4X2dwaW8YCCABKA1SBnJ4R3BpbxIXCgd0eF9ncGlvGAkgASgNUg'
    'Z0eEdwaW8SRwogYnJvYWRjYXN0X3NtYXJ0X21pbmltdW1fZGlzdGFuY2UYCiABKA1SHWJyb2Fk'
    'Y2FzdFNtYXJ0TWluaW11bURpc3RhbmNlElAKJWJyb2FkY2FzdF9zbWFydF9taW5pbXVtX2ludG'
    'VydmFsX3NlY3MYCyABKA1SIWJyb2FkY2FzdFNtYXJ0TWluaW11bUludGVydmFsU2VjcxIeCgtn'
    'cHNfZW5fZ3BpbxgMIAEoDVIJZ3BzRW5HcGlvEkQKCGdwc19tb2RlGA0gASgOMikubWVzaHRhc3'
    'RpYy5Db25maWcuUG9zaXRpb25Db25maWcuR3BzTW9kZVIHZ3BzTW9kZSI1CgdHcHNNb2RlEgwK'
    'CERJU0FCTEVEEAASCwoHRU5BQkxFRBABEg8KC05PVF9QUkVTRU5UEAIaoQMKC1Bvd2VyQ29uZm'
    'lnEiYKD2lzX3Bvd2VyX3NhdmluZxgBIAEoCFINaXNQb3dlclNhdmluZxJCCh5vbl9iYXR0ZXJ5'
    'X3NodXRkb3duX2FmdGVyX3NlY3MYAiABKA1SGm9uQmF0dGVyeVNodXRkb3duQWZ0ZXJTZWNzEj'
    'YKF2FkY19tdWx0aXBsaWVyX292ZXJyaWRlGAMgASgCUhVhZGNNdWx0aXBsaWVyT3ZlcnJpZGUS'
    'LgoTd2FpdF9ibHVldG9vdGhfc2VjcxgEIAEoDVIRd2FpdEJsdWV0b290aFNlY3MSGQoIc2RzX3'
    'NlY3MYBiABKA1SB3Nkc1NlY3MSFwoHbHNfc2VjcxgHIAEoDVIGbHNTZWNzEiIKDW1pbl93YWtl'
    'X3NlY3MYCCABKA1SC21pbldha2VTZWNzEjsKGmRldmljZV9iYXR0ZXJ5X2luYV9hZGRyZXNzGA'
    'kgASgNUhdkZXZpY2VCYXR0ZXJ5SW5hQWRkcmVzcxIpChBwb3dlcm1vbl9lbmFibGVzGCAgASgE'
    'Ug9wb3dlcm1vbkVuYWJsZXMaxwQKDU5ldHdvcmtDb25maWcSIQoMd2lmaV9lbmFibGVkGAEgAS'
    'gIUgt3aWZpRW5hYmxlZBIbCgl3aWZpX3NzaWQYAyABKAlSCHdpZmlTc2lkEhkKCHdpZmlfcHNr'
    'GAQgASgJUgd3aWZpUHNrEh0KCm50cF9zZXJ2ZXIYBSABKAlSCW50cFNlcnZlchIfCgtldGhfZW'
    '5hYmxlZBgGIAEoCFIKZXRoRW5hYmxlZBJPCgxhZGRyZXNzX21vZGUYByABKA4yLC5tZXNodGFz'
    'dGljLkNvbmZpZy5OZXR3b3JrQ29uZmlnLkFkZHJlc3NNb2RlUgthZGRyZXNzTW9kZRJMCgtpcH'
    'Y0X2NvbmZpZxgIIAEoCzIrLm1lc2h0YXN0aWMuQ29uZmlnLk5ldHdvcmtDb25maWcuSXBWNENv'
    'bmZpZ1IKaXB2NENvbmZpZxIlCg5yc3lzbG9nX3NlcnZlchgJIAEoCVINcnN5c2xvZ1NlcnZlch'
    'IrChFlbmFibGVkX3Byb3RvY29scxgKIAEoDVIQZW5hYmxlZFByb3RvY29scxIhCgxpcHY2X2Vu'
    'YWJsZWQYCyABKAhSC2lwdjZFbmFibGVkGmAKCklwVjRDb25maWcSDgoCaXAYASABKAdSAmlwEh'
    'gKB2dhdGV3YXkYAiABKAdSB2dhdGV3YXkSFgoGc3VibmV0GAMgASgHUgZzdWJuZXQSEAoDZG5z'
    'GAQgASgHUgNkbnMiIwoLQWRkcmVzc01vZGUSCAoEREhDUBAAEgoKBlNUQVRJQxABGs4ICg1EaX'
    'NwbGF5Q29uZmlnEiQKDnNjcmVlbl9vbl9zZWNzGAEgASgNUgxzY3JlZW5PblNlY3MSHQoKZ3Bz'
    'X2Zvcm1hdBgCIAEoDVIJZ3BzRm9ybWF0EjkKGWF1dG9fc2NyZWVuX2Nhcm91c2VsX3NlY3MYAy'
    'ABKA1SFmF1dG9TY3JlZW5DYXJvdXNlbFNlY3MSKgoRY29tcGFzc19ub3J0aF90b3AYBCABKAhS'
    'D2NvbXBhc3NOb3J0aFRvcBIfCgtmbGlwX3NjcmVlbhgFIAEoCFIKZmxpcFNjcmVlbhJDCgV1bm'
    'l0cxgGIAEoDjItLm1lc2h0YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcuRGlzcGxheVVuaXRz'
    'UgV1bml0cxI9CgRvbGVkGAcgASgOMikubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy'
    '5PbGVkVHlwZVIEb2xlZBJOCgtkaXNwbGF5bW9kZRgIIAEoDjIsLm1lc2h0YXN0aWMuQ29uZmln'
    'LkRpc3BsYXlDb25maWcuRGlzcGxheU1vZGVSC2Rpc3BsYXltb2RlEiEKDGhlYWRpbmdfYm9sZB'
    'gJIAEoCFILaGVhZGluZ0JvbGQSMAoVd2FrZV9vbl90YXBfb3JfbW90aW9uGAogASgIUhF3YWtl'
    'T25UYXBPck1vdGlvbhJkChNjb21wYXNzX29yaWVudGF0aW9uGAsgASgOMjMubWVzaHRhc3RpYy'
    '5Db25maWcuRGlzcGxheUNvbmZpZy5Db21wYXNzT3JpZW50YXRpb25SEmNvbXBhc3NPcmllbnRh'
    'dGlvbhIiCg11c2VfMTJoX2Nsb2NrGAwgASgIUgt1c2UxMmhDbG9jaxIrChJ1c2VfbG9uZ19ub2'
    'RlX25hbWUYDSABKAhSD3VzZUxvbmdOb2RlTmFtZSIoCgxEaXNwbGF5VW5pdHMSCgoGTUVUUklD'
    'EAASDAoISU1QRVJJQUwQASJmCghPbGVkVHlwZRINCglPTEVEX0FVVE8QABIQCgxPTEVEX1NTRD'
    'EzMDYQARIPCgtPTEVEX1NIMTEwNhACEg8KC09MRURfU0gxMTA3EAMSFwoTT0xFRF9TSDExMDdf'
    'MTI4XzEyOBAEIkEKC0Rpc3BsYXlNb2RlEgsKB0RFRkFVTFQQABIMCghUV09DT0xPUhABEgwKCE'
    'lOVkVSVEVEEAISCQoFQ09MT1IQAyK6AQoSQ29tcGFzc09yaWVudGF0aW9uEg0KCURFR1JFRVNf'
    'MBAAEg4KCkRFR1JFRVNfOTAQARIPCgtERUdSRUVTXzE4MBACEg8KC0RFR1JFRVNfMjcwEAMSFg'
    'oSREVHUkVFU18wX0lOVkVSVEVEEAQSFwoTREVHUkVFU185MF9JTlZFUlRFRBAFEhgKFERFR1JF'
    'RVNfMTgwX0lOVkVSVEVEEAYSGAoUREVHUkVFU18yNzBfSU5WRVJURUQQBxrPBQoKTG9SYUNvbm'
    'ZpZxIdCgp1c2VfcHJlc2V0GAEgASgIUgl1c2VQcmVzZXQSOgoMbW9kZW1fcHJlc2V0GAIgASgO'
    'MhcubWVzaHRhc3RpYy5Nb2RlbVByZXNldFILbW9kZW1QcmVzZXQSHAoJYmFuZHdpZHRoGAMgAS'
    'gNUgliYW5kd2lkdGgSIwoNc3ByZWFkX2ZhY3RvchgEIAEoDVIMc3ByZWFkRmFjdG9yEh8KC2Nv'
    'ZGluZ19yYXRlGAUgASgNUgpjb2RpbmdSYXRlEikKEGZyZXF1ZW5jeV9vZmZzZXQYBiABKAJSD2'
    'ZyZXF1ZW5jeU9mZnNldBIuCgZyZWdpb24YByABKA4yFi5tZXNodGFzdGljLlJlZ2lvbkNvZGVS'
    'BnJlZ2lvbhIbCglob3BfbGltaXQYCCABKA1SCGhvcExpbWl0Eh0KCnR4X2VuYWJsZWQYCSABKA'
    'hSCXR4RW5hYmxlZBIZCgh0eF9wb3dlchgKIAEoBVIHdHhQb3dlchIfCgtjaGFubmVsX251bRgL'
    'IAEoDVIKY2hhbm5lbE51bRIuChNvdmVycmlkZV9kdXR5X2N5Y2xlGAwgASgIUhFvdmVycmlkZU'
    'R1dHlDeWNsZRIzChZzeDEyNnhfcnhfYm9vc3RlZF9nYWluGA0gASgIUhNzeDEyNnhSeEJvb3N0'
    'ZWRHYWluEi0KEm92ZXJyaWRlX2ZyZXF1ZW5jeRgOIAEoAlIRb3ZlcnJpZGVGcmVxdWVuY3kSJg'
    'oPcGFfZmFuX2Rpc2FibGVkGA8gASgIUg1wYUZhbkRpc2FibGVkEicKD2lnbm9yZV9pbmNvbWlu'
    'ZxhnIAMoDVIOaWdub3JlSW5jb21pbmcSHwoLaWdub3JlX21xdHQYaCABKAhSCmlnbm9yZU1xdH'
    'QSKQoRY29uZmlnX29rX3RvX21xdHQYaSABKAhSDmNvbmZpZ09rVG9NcXR0GsYBCg9CbHVldG9v'
    'dGhDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBJCCgRtb2RlGAIgASgOMi4ubWVzaH'
    'Rhc3RpYy5Db25maWcuQmx1ZXRvb3RoQ29uZmlnLlBhaXJpbmdNb2RlUgRtb2RlEhsKCWZpeGVk'
    'X3BpbhgDIAEoDVIIZml4ZWRQaW4iOAoLUGFpcmluZ01vZGUSDgoKUkFORE9NX1BJThAAEg0KCU'
    'ZJWEVEX1BJThABEgoKBk5PX1BJThACGpoCCg5TZWN1cml0eUNvbmZpZxIdCgpwdWJsaWNfa2V5'
    'GAEgASgMUglwdWJsaWNLZXkSHwoLcHJpdmF0ZV9rZXkYAiABKAxSCnByaXZhdGVLZXkSGwoJYW'
    'RtaW5fa2V5GAMgAygMUghhZG1pbktleRIdCgppc19tYW5hZ2VkGAQgASgIUglpc01hbmFnZWQS'
    'JQoOc2VyaWFsX2VuYWJsZWQYBSABKAhSDXNlcmlhbEVuYWJsZWQSMQoVZGVidWdfbG9nX2FwaV'
    '9lbmFibGVkGAYgASgIUhJkZWJ1Z0xvZ0FwaUVuYWJsZWQSMgoVYWRtaW5fY2hhbm5lbF9lbmFi'
    'bGVkGAggASgIUhNhZG1pbkNoYW5uZWxFbmFibGVkGhIKEFNlc3Npb25rZXlDb25maWdCEQoPcG'
    'F5bG9hZF92YXJpYW50');

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig$json = {
  '1': 'ModuleConfig',
  '2': [
    {
      '1': 'mqtt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MQTTConfig',
      '9': 0,
      '10': 'mqtt'
    },
    {
      '1': 'serial',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.SerialConfig',
      '9': 0,
      '10': 'serial'
    },
    {
      '1': 'external_notification',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.ExternalNotificationConfig',
      '9': 0,
      '10': 'externalNotification'
    },
    {
      '1': 'store_forward',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.StoreForwardConfig',
      '9': 0,
      '10': 'storeForward'
    },
    {
      '1': 'range_test',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.RangeTestConfig',
      '9': 0,
      '10': 'rangeTest'
    },
    {
      '1': 'telemetry',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TelemetryConfig',
      '9': 0,
      '10': 'telemetry'
    },
    {
      '1': 'canned_message',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig',
      '9': 0,
      '10': 'cannedMessage'
    },
    {
      '1': 'audio',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.AudioConfig',
      '9': 0,
      '10': 'audio'
    },
    {
      '1': 'remote_hardware',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.RemoteHardwareConfig',
      '9': 0,
      '10': 'remoteHardware'
    },
    {
      '1': 'neighbor_info',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.NeighborInfoConfig',
      '9': 0,
      '10': 'neighborInfo'
    },
    {
      '1': 'ambient_lighting',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.AmbientLightingConfig',
      '9': 0,
      '10': 'ambientLighting'
    },
    {
      '1': 'detection_sensor',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.DetectionSensorConfig',
      '9': 0,
      '10': 'detectionSensor'
    },
    {
      '1': 'paxcounter',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.PaxcounterConfig',
      '9': 0,
      '10': 'paxcounter'
    },
  ],
  '3': [
    ModuleConfig_MQTTConfig$json,
    ModuleConfig_MapReportSettings$json,
    ModuleConfig_SerialConfig$json,
    ModuleConfig_ExternalNotificationConfig$json,
    ModuleConfig_StoreForwardConfig$json,
    ModuleConfig_RangeTestConfig$json,
    ModuleConfig_TelemetryConfig$json,
    ModuleConfig_CannedMessageConfig$json,
    ModuleConfig_AudioConfig$json,
    ModuleConfig_RemoteHardwareConfig$json,
    ModuleConfig_NeighborInfoConfig$json,
    ModuleConfig_AmbientLightingConfig$json,
    ModuleConfig_DetectionSensorConfig$json,
    ModuleConfig_PaxcounterConfig$json
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MQTTConfig$json = {
  '1': 'MQTTConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'address', '3': 2, '4': 1, '5': 9, '10': 'address'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 4, '4': 1, '5': 9, '10': 'password'},
    {
      '1': 'encryption_enabled',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'encryptionEnabled'
    },
    {'1': 'json_enabled', '3': 6, '4': 1, '5': 8, '10': 'jsonEnabled'},
    {'1': 'tls_enabled', '3': 7, '4': 1, '5': 8, '10': 'tlsEnabled'},
    {'1': 'root', '3': 8, '4': 1, '5': 9, '10': 'root'},
    {
      '1': 'proxy_to_client_enabled',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'proxyToClientEnabled'
    },
    {
      '1': 'map_reporting_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'mapReportingEnabled'
    },
    {
      '1': 'map_report_settings',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MapReportSettings',
      '10': 'mapReportSettings'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MapReportSettings$json = {
  '1': 'MapReportSettings',
  '2': [
    {
      '1': 'publish_interval_secs',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'publishIntervalSecs'
    },
    {
      '1': 'position_precision',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'positionPrecision'
    },
    {
      '1': 'should_report_location',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'shouldReportLocation'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig$json = {
  '1': 'SerialConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'echo', '3': 2, '4': 1, '5': 8, '10': 'echo'},
    {'1': 'rxd', '3': 3, '4': 1, '5': 13, '10': 'rxd'},
    {'1': 'txd', '3': 4, '4': 1, '5': 13, '10': 'txd'},
    {
      '1': 'baud',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Baud',
      '10': 'baud'
    },
    {'1': 'timeout', '3': 6, '4': 1, '5': 13, '10': 'timeout'},
    {
      '1': 'mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Mode',
      '10': 'mode'
    },
    {
      '1': 'override_console_serial_port',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'overrideConsoleSerialPort'
    },
  ],
  '4': [
    ModuleConfig_SerialConfig_Serial_Baud$json,
    ModuleConfig_SerialConfig_Serial_Mode$json
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig_Serial_Baud$json = {
  '1': 'Serial_Baud',
  '2': [
    {'1': 'BAUD_DEFAULT', '2': 0},
    {'1': 'BAUD_110', '2': 1},
    {'1': 'BAUD_300', '2': 2},
    {'1': 'BAUD_600', '2': 3},
    {'1': 'BAUD_1200', '2': 4},
    {'1': 'BAUD_2400', '2': 5},
    {'1': 'BAUD_4800', '2': 6},
    {'1': 'BAUD_9600', '2': 7},
    {'1': 'BAUD_19200', '2': 8},
    {'1': 'BAUD_38400', '2': 9},
    {'1': 'BAUD_57600', '2': 10},
    {'1': 'BAUD_115200', '2': 11},
    {'1': 'BAUD_230400', '2': 12},
    {'1': 'BAUD_460800', '2': 13},
    {'1': 'BAUD_576000', '2': 14},
    {'1': 'BAUD_921600', '2': 15},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig_Serial_Mode$json = {
  '1': 'Serial_Mode',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'SIMPLE', '2': 1},
    {'1': 'PROTO', '2': 2},
    {'1': 'TEXTMSG', '2': 3},
    {'1': 'NMEA', '2': 4},
    {'1': 'CALTOPO', '2': 5},
    {'1': 'WS85', '2': 6},
    {'1': 'VE_DIRECT', '2': 7},
    {'1': 'MS_CONFIG', '2': 8},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_ExternalNotificationConfig$json = {
  '1': 'ExternalNotificationConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'output_ms', '3': 2, '4': 1, '5': 13, '10': 'outputMs'},
    {'1': 'output', '3': 3, '4': 1, '5': 13, '10': 'output'},
    {'1': 'active', '3': 4, '4': 1, '5': 8, '10': 'active'},
    {'1': 'alert_message', '3': 5, '4': 1, '5': 8, '10': 'alertMessage'},
    {'1': 'alert_bell', '3': 6, '4': 1, '5': 8, '10': 'alertBell'},
    {'1': 'use_pwm', '3': 7, '4': 1, '5': 8, '10': 'usePwm'},
    {'1': 'output_vibra', '3': 8, '4': 1, '5': 13, '10': 'outputVibra'},
    {'1': 'output_buzzer', '3': 9, '4': 1, '5': 13, '10': 'outputBuzzer'},
    {
      '1': 'alert_message_vibra',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'alertMessageVibra'
    },
    {
      '1': 'alert_message_buzzer',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'alertMessageBuzzer'
    },
    {'1': 'alert_bell_vibra', '3': 12, '4': 1, '5': 8, '10': 'alertBellVibra'},
    {
      '1': 'alert_bell_buzzer',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'alertBellBuzzer'
    },
    {'1': 'nag_timeout', '3': 14, '4': 1, '5': 13, '10': 'nagTimeout'},
    {'1': 'use_i2s_as_buzzer', '3': 15, '4': 1, '5': 8, '10': 'useI2sAsBuzzer'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_StoreForwardConfig$json = {
  '1': 'StoreForwardConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'heartbeat', '3': 2, '4': 1, '5': 8, '10': 'heartbeat'},
    {'1': 'records', '3': 3, '4': 1, '5': 13, '10': 'records'},
    {
      '1': 'history_return_max',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'historyReturnMax'
    },
    {
      '1': 'history_return_window',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'historyReturnWindow'
    },
    {'1': 'is_server', '3': 6, '4': 1, '5': 8, '10': 'isServer'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_RangeTestConfig$json = {
  '1': 'RangeTestConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'sender', '3': 2, '4': 1, '5': 13, '10': 'sender'},
    {'1': 'save', '3': 3, '4': 1, '5': 8, '10': 'save'},
    {'1': 'clear_on_reboot', '3': 4, '4': 1, '5': 8, '10': 'clearOnReboot'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_TelemetryConfig$json = {
  '1': 'TelemetryConfig',
  '2': [
    {
      '1': 'device_update_interval',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'deviceUpdateInterval'
    },
    {
      '1': 'environment_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'environmentUpdateInterval'
    },
    {
      '1': 'environment_measurement_enabled',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'environmentMeasurementEnabled'
    },
    {
      '1': 'environment_screen_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'environmentScreenEnabled'
    },
    {
      '1': 'environment_display_fahrenheit',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'environmentDisplayFahrenheit'
    },
    {
      '1': 'air_quality_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'airQualityEnabled'
    },
    {
      '1': 'air_quality_interval',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'airQualityInterval'
    },
    {
      '1': 'power_measurement_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'powerMeasurementEnabled'
    },
    {
      '1': 'power_update_interval',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'powerUpdateInterval'
    },
    {
      '1': 'power_screen_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'powerScreenEnabled'
    },
    {
      '1': 'health_measurement_enabled',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'healthMeasurementEnabled'
    },
    {
      '1': 'health_update_interval',
      '3': 12,
      '4': 1,
      '5': 13,
      '10': 'healthUpdateInterval'
    },
    {
      '1': 'health_screen_enabled',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'healthScreenEnabled'
    },
    {
      '1': 'device_telemetry_enabled',
      '3': 14,
      '4': 1,
      '5': 8,
      '10': 'deviceTelemetryEnabled'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig$json = {
  '1': 'CannedMessageConfig',
  '2': [
    {'1': 'rotary1_enabled', '3': 1, '4': 1, '5': 8, '10': 'rotary1Enabled'},
    {
      '1': 'inputbroker_pin_a',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinA'
    },
    {
      '1': 'inputbroker_pin_b',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinB'
    },
    {
      '1': 'inputbroker_pin_press',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinPress'
    },
    {
      '1': 'inputbroker_event_cw',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventCw'
    },
    {
      '1': 'inputbroker_event_ccw',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventCcw'
    },
    {
      '1': 'inputbroker_event_press',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventPress'
    },
    {'1': 'updown1_enabled', '3': 8, '4': 1, '5': 8, '10': 'updown1Enabled'},
    {'1': 'enabled', '3': 9, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'allow_input_source',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'allowInputSource'
    },
    {'1': 'send_bell', '3': 11, '4': 1, '5': 8, '10': 'sendBell'},
  ],
  '4': [ModuleConfig_CannedMessageConfig_InputEventChar$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig_InputEventChar$json = {
  '1': 'InputEventChar',
  '2': [
    {'1': 'NONE', '2': 0},
    {'1': 'UP', '2': 17},
    {'1': 'DOWN', '2': 18},
    {'1': 'LEFT', '2': 19},
    {'1': 'RIGHT', '2': 20},
    {'1': 'SELECT', '2': 10},
    {'1': 'BACK', '2': 27},
    {'1': 'CANCEL', '2': 24},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig$json = {
  '1': 'AudioConfig',
  '2': [
    {'1': 'codec2_enabled', '3': 1, '4': 1, '5': 8, '10': 'codec2Enabled'},
    {'1': 'ptt_pin', '3': 2, '4': 1, '5': 13, '10': 'pttPin'},
    {
      '1': 'bitrate',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.AudioConfig.Audio_Baud',
      '10': 'bitrate'
    },
    {'1': 'i2s_ws', '3': 4, '4': 1, '5': 13, '10': 'i2sWs'},
    {'1': 'i2s_sd', '3': 5, '4': 1, '5': 13, '10': 'i2sSd'},
    {'1': 'i2s_din', '3': 6, '4': 1, '5': 13, '10': 'i2sDin'},
    {'1': 'i2s_sck', '3': 7, '4': 1, '5': 13, '10': 'i2sSck'},
  ],
  '4': [ModuleConfig_AudioConfig_Audio_Baud$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig_Audio_Baud$json = {
  '1': 'Audio_Baud',
  '2': [
    {'1': 'CODEC2_DEFAULT', '2': 0},
    {'1': 'CODEC2_3200', '2': 1},
    {'1': 'CODEC2_2400', '2': 2},
    {'1': 'CODEC2_1600', '2': 3},
    {'1': 'CODEC2_1400', '2': 4},
    {'1': 'CODEC2_1300', '2': 5},
    {'1': 'CODEC2_1200', '2': 6},
    {'1': 'CODEC2_700', '2': 7},
    {'1': 'CODEC2_700B', '2': 8},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_RemoteHardwareConfig$json = {
  '1': 'RemoteHardwareConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'allow_undefined_pin_access',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'allowUndefinedPinAccess'
    },
    {
      '1': 'available_pins',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.RemoteHardwarePin',
      '10': 'availablePins'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_NeighborInfoConfig$json = {
  '1': 'NeighborInfoConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'update_interval', '3': 2, '4': 1, '5': 13, '10': 'updateInterval'},
    {
      '1': 'transmit_over_lora',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'transmitOverLora'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AmbientLightingConfig$json = {
  '1': 'AmbientLightingConfig',
  '2': [
    {'1': 'led_state', '3': 1, '4': 1, '5': 8, '10': 'ledState'},
    {'1': 'current', '3': 2, '4': 1, '5': 13, '10': 'current'},
    {'1': 'red', '3': 3, '4': 1, '5': 13, '10': 'red'},
    {'1': 'green', '3': 4, '4': 1, '5': 13, '10': 'green'},
    {'1': 'blue', '3': 5, '4': 1, '5': 13, '10': 'blue'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig$json = {
  '1': 'DetectionSensorConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'minimum_broadcast_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'minimumBroadcastSecs'
    },
    {
      '1': 'state_broadcast_secs',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'stateBroadcastSecs'
    },
    {'1': 'send_bell', '3': 4, '4': 1, '5': 8, '10': 'sendBell'},
    {'1': 'name', '3': 5, '4': 1, '5': 9, '10': 'name'},
    {'1': 'monitor_pin', '3': 6, '4': 1, '5': 13, '10': 'monitorPin'},
    {
      '1': 'detection_trigger_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.DetectionSensorConfig.TriggerType',
      '10': 'detectionTriggerType'
    },
    {'1': 'use_pullup', '3': 8, '4': 1, '5': 8, '10': 'usePullup'},
  ],
  '4': [ModuleConfig_DetectionSensorConfig_TriggerType$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig_TriggerType$json = {
  '1': 'TriggerType',
  '2': [
    {'1': 'LOGIC_LOW', '2': 0},
    {'1': 'LOGIC_HIGH', '2': 1},
    {'1': 'FALLING_EDGE', '2': 2},
    {'1': 'RISING_EDGE', '2': 3},
    {'1': 'EITHER_EDGE_ACTIVE_LOW', '2': 4},
    {'1': 'EITHER_EDGE_ACTIVE_HIGH', '2': 5},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_PaxcounterConfig$json = {
  '1': 'PaxcounterConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'paxcounter_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'paxcounterUpdateInterval'
    },
    {'1': 'wifi_threshold', '3': 3, '4': 1, '5': 5, '10': 'wifiThreshold'},
    {'1': 'ble_threshold', '3': 4, '4': 1, '5': 5, '10': 'bleThreshold'},
  ],
};

/// Descriptor for `ModuleConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moduleConfigDescriptor = $convert.base64Decode(
    'CgxNb2R1bGVDb25maWcSOQoEbXF0dBgBIAEoCzIjLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLk'
    '1RVFRDb25maWdIAFIEbXF0dBI/CgZzZXJpYWwYAiABKAsyJS5tZXNodGFzdGljLk1vZHVsZUNv'
    'bmZpZy5TZXJpYWxDb25maWdIAFIGc2VyaWFsEmoKFWV4dGVybmFsX25vdGlmaWNhdGlvbhgDIA'
    'EoCzIzLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkV4dGVybmFsTm90aWZpY2F0aW9uQ29uZmln'
    'SABSFGV4dGVybmFsTm90aWZpY2F0aW9uElIKDXN0b3JlX2ZvcndhcmQYBCABKAsyKy5tZXNodG'
    'FzdGljLk1vZHVsZUNvbmZpZy5TdG9yZUZvcndhcmRDb25maWdIAFIMc3RvcmVGb3J3YXJkEkkK'
    'CnJhbmdlX3Rlc3QYBSABKAsyKC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5SYW5nZVRlc3RDb2'
    '5maWdIAFIJcmFuZ2VUZXN0EkgKCXRlbGVtZXRyeRgGIAEoCzIoLm1lc2h0YXN0aWMuTW9kdWxl'
    'Q29uZmlnLlRlbGVtZXRyeUNvbmZpZ0gAUgl0ZWxlbWV0cnkSVQoOY2FubmVkX21lc3NhZ2UYBy'
    'ABKAsyLC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnSABSDWNh'
    'bm5lZE1lc3NhZ2USPAoFYXVkaW8YCCABKAsyJC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5BdW'
    'Rpb0NvbmZpZ0gAUgVhdWRpbxJYCg9yZW1vdGVfaGFyZHdhcmUYCSABKAsyLS5tZXNodGFzdGlj'
    'Lk1vZHVsZUNvbmZpZy5SZW1vdGVIYXJkd2FyZUNvbmZpZ0gAUg5yZW1vdGVIYXJkd2FyZRJSCg'
    '1uZWlnaGJvcl9pbmZvGAogASgLMisubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuTmVpZ2hib3JJ'
    'bmZvQ29uZmlnSABSDG5laWdoYm9ySW5mbxJbChBhbWJpZW50X2xpZ2h0aW5nGAsgASgLMi4ubW'
    'VzaHRhc3RpYy5Nb2R1bGVDb25maWcuQW1iaWVudExpZ2h0aW5nQ29uZmlnSABSD2FtYmllbnRM'
    'aWdodGluZxJbChBkZXRlY3Rpb25fc2Vuc29yGAwgASgLMi4ubWVzaHRhc3RpYy5Nb2R1bGVDb2'
    '5maWcuRGV0ZWN0aW9uU2Vuc29yQ29uZmlnSABSD2RldGVjdGlvblNlbnNvchJLCgpwYXhjb3Vu'
    'dGVyGA0gASgLMikubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuUGF4Y291bnRlckNvbmZpZ0gAUg'
    'pwYXhjb3VudGVyGsYDCgpNUVRUQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSGAoH'
    'YWRkcmVzcxgCIAEoCVIHYWRkcmVzcxIaCgh1c2VybmFtZRgDIAEoCVIIdXNlcm5hbWUSGgoIcG'
    'Fzc3dvcmQYBCABKAlSCHBhc3N3b3JkEi0KEmVuY3J5cHRpb25fZW5hYmxlZBgFIAEoCFIRZW5j'
    'cnlwdGlvbkVuYWJsZWQSIQoManNvbl9lbmFibGVkGAYgASgIUgtqc29uRW5hYmxlZBIfCgt0bH'
    'NfZW5hYmxlZBgHIAEoCFIKdGxzRW5hYmxlZBISCgRyb290GAggASgJUgRyb290EjUKF3Byb3h5'
    'X3RvX2NsaWVudF9lbmFibGVkGAkgASgIUhRwcm94eVRvQ2xpZW50RW5hYmxlZBIyChVtYXBfcm'
    'Vwb3J0aW5nX2VuYWJsZWQYCiABKAhSE21hcFJlcG9ydGluZ0VuYWJsZWQSWgoTbWFwX3JlcG9y'
    'dF9zZXR0aW5ncxgLIAEoCzIqLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLk1hcFJlcG9ydFNldH'
    'RpbmdzUhFtYXBSZXBvcnRTZXR0aW5ncxqsAQoRTWFwUmVwb3J0U2V0dGluZ3MSMgoVcHVibGlz'
    'aF9pbnRlcnZhbF9zZWNzGAEgASgNUhNwdWJsaXNoSW50ZXJ2YWxTZWNzEi0KEnBvc2l0aW9uX3'
    'ByZWNpc2lvbhgCIAEoDVIRcG9zaXRpb25QcmVjaXNpb24SNAoWc2hvdWxkX3JlcG9ydF9sb2Nh'
    'dGlvbhgDIAEoCFIUc2hvdWxkUmVwb3J0TG9jYXRpb24a1QUKDFNlcmlhbENvbmZpZxIYCgdlbm'
    'FibGVkGAEgASgIUgdlbmFibGVkEhIKBGVjaG8YAiABKAhSBGVjaG8SEAoDcnhkGAMgASgNUgNy'
    'eGQSEAoDdHhkGAQgASgNUgN0eGQSRQoEYmF1ZBgFIAEoDjIxLm1lc2h0YXN0aWMuTW9kdWxlQ2'
    '9uZmlnLlNlcmlhbENvbmZpZy5TZXJpYWxfQmF1ZFIEYmF1ZBIYCgd0aW1lb3V0GAYgASgNUgd0'
    'aW1lb3V0EkUKBG1vZGUYByABKA4yMS5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5TZXJpYWxDb2'
    '5maWcuU2VyaWFsX01vZGVSBG1vZGUSPwocb3ZlcnJpZGVfY29uc29sZV9zZXJpYWxfcG9ydBgI'
    'IAEoCFIZb3ZlcnJpZGVDb25zb2xlU2VyaWFsUG9ydCKKAgoLU2VyaWFsX0JhdWQSEAoMQkFVRF'
    '9ERUZBVUxUEAASDAoIQkFVRF8xMTAQARIMCghCQVVEXzMwMBACEgwKCEJBVURfNjAwEAMSDQoJ'
    'QkFVRF8xMjAwEAQSDQoJQkFVRF8yNDAwEAUSDQoJQkFVRF80ODAwEAYSDQoJQkFVRF85NjAwEA'
    'cSDgoKQkFVRF8xOTIwMBAIEg4KCkJBVURfMzg0MDAQCRIOCgpCQVVEXzU3NjAwEAoSDwoLQkFV'
    'RF8xMTUyMDAQCxIPCgtCQVVEXzIzMDQwMBAMEg8KC0JBVURfNDYwODAwEA0SDwoLQkFVRF81Nz'
    'YwMDAQDhIPCgtCQVVEXzkyMTYwMBAPIn0KC1NlcmlhbF9Nb2RlEgsKB0RFRkFVTFQQABIKCgZT'
    'SU1QTEUQARIJCgVQUk9UTxACEgsKB1RFWFRNU0cQAxIICgROTUVBEAQSCwoHQ0FMVE9QTxAFEg'
    'gKBFdTODUQBhINCglWRV9ESVJFQ1QQBxINCglNU19DT05GSUcQCBqsBAoaRXh0ZXJuYWxOb3Rp'
    'ZmljYXRpb25Db25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBIbCglvdXRwdXRfbXMYAi'
    'ABKA1SCG91dHB1dE1zEhYKBm91dHB1dBgDIAEoDVIGb3V0cHV0EhYKBmFjdGl2ZRgEIAEoCFIG'
    'YWN0aXZlEiMKDWFsZXJ0X21lc3NhZ2UYBSABKAhSDGFsZXJ0TWVzc2FnZRIdCgphbGVydF9iZW'
    'xsGAYgASgIUglhbGVydEJlbGwSFwoHdXNlX3B3bRgHIAEoCFIGdXNlUHdtEiEKDG91dHB1dF92'
    'aWJyYRgIIAEoDVILb3V0cHV0VmlicmESIwoNb3V0cHV0X2J1enplchgJIAEoDVIMb3V0cHV0Qn'
    'V6emVyEi4KE2FsZXJ0X21lc3NhZ2VfdmlicmEYCiABKAhSEWFsZXJ0TWVzc2FnZVZpYnJhEjAK'
    'FGFsZXJ0X21lc3NhZ2VfYnV6emVyGAsgASgIUhJhbGVydE1lc3NhZ2VCdXp6ZXISKAoQYWxlcn'
    'RfYmVsbF92aWJyYRgMIAEoCFIOYWxlcnRCZWxsVmlicmESKgoRYWxlcnRfYmVsbF9idXp6ZXIY'
    'DSABKAhSD2FsZXJ0QmVsbEJ1enplchIfCgtuYWdfdGltZW91dBgOIAEoDVIKbmFnVGltZW91dB'
    'IpChF1c2VfaTJzX2FzX2J1enplchgPIAEoCFIOdXNlSTJzQXNCdXp6ZXIa5QEKElN0b3JlRm9y'
    'd2FyZENvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEhwKCWhlYXJ0YmVhdBgCIAEoCF'
    'IJaGVhcnRiZWF0EhgKB3JlY29yZHMYAyABKA1SB3JlY29yZHMSLAoSaGlzdG9yeV9yZXR1cm5f'
    'bWF4GAQgASgNUhBoaXN0b3J5UmV0dXJuTWF4EjIKFWhpc3RvcnlfcmV0dXJuX3dpbmRvdxgFIA'
    'EoDVITaGlzdG9yeVJldHVybldpbmRvdxIbCglpc19zZXJ2ZXIYBiABKAhSCGlzU2VydmVyGn8K'
    'D1JhbmdlVGVzdENvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEhYKBnNlbmRlchgCIA'
    'EoDVIGc2VuZGVyEhIKBHNhdmUYAyABKAhSBHNhdmUSJgoPY2xlYXJfb25fcmVib290GAQgASgI'
    'Ug1jbGVhck9uUmVib290GrkGCg9UZWxlbWV0cnlDb25maWcSNAoWZGV2aWNlX3VwZGF0ZV9pbn'
    'RlcnZhbBgBIAEoDVIUZGV2aWNlVXBkYXRlSW50ZXJ2YWwSPgobZW52aXJvbm1lbnRfdXBkYXRl'
    'X2ludGVydmFsGAIgASgNUhllbnZpcm9ubWVudFVwZGF0ZUludGVydmFsEkYKH2Vudmlyb25tZW'
    '50X21lYXN1cmVtZW50X2VuYWJsZWQYAyABKAhSHWVudmlyb25tZW50TWVhc3VyZW1lbnRFbmFi'
    'bGVkEjwKGmVudmlyb25tZW50X3NjcmVlbl9lbmFibGVkGAQgASgIUhhlbnZpcm9ubWVudFNjcm'
    'VlbkVuYWJsZWQSRAoeZW52aXJvbm1lbnRfZGlzcGxheV9mYWhyZW5oZWl0GAUgASgIUhxlbnZp'
    'cm9ubWVudERpc3BsYXlGYWhyZW5oZWl0Ei4KE2Fpcl9xdWFsaXR5X2VuYWJsZWQYBiABKAhSEW'
    'FpclF1YWxpdHlFbmFibGVkEjAKFGFpcl9xdWFsaXR5X2ludGVydmFsGAcgASgNUhJhaXJRdWFs'
    'aXR5SW50ZXJ2YWwSOgoZcG93ZXJfbWVhc3VyZW1lbnRfZW5hYmxlZBgIIAEoCFIXcG93ZXJNZW'
    'FzdXJlbWVudEVuYWJsZWQSMgoVcG93ZXJfdXBkYXRlX2ludGVydmFsGAkgASgNUhNwb3dlclVw'
    'ZGF0ZUludGVydmFsEjAKFHBvd2VyX3NjcmVlbl9lbmFibGVkGAogASgIUhJwb3dlclNjcmVlbk'
    'VuYWJsZWQSPAoaaGVhbHRoX21lYXN1cmVtZW50X2VuYWJsZWQYCyABKAhSGGhlYWx0aE1lYXN1'
    'cmVtZW50RW5hYmxlZBI0ChZoZWFsdGhfdXBkYXRlX2ludGVydmFsGAwgASgNUhRoZWFsdGhVcG'
    'RhdGVJbnRlcnZhbBIyChVoZWFsdGhfc2NyZWVuX2VuYWJsZWQYDSABKAhSE2hlYWx0aFNjcmVl'
    'bkVuYWJsZWQSOAoYZGV2aWNlX3RlbGVtZXRyeV9lbmFibGVkGA4gASgIUhZkZXZpY2VUZWxlbW'
    'V0cnlFbmFibGVkGpIGChNDYW5uZWRNZXNzYWdlQ29uZmlnEicKD3JvdGFyeTFfZW5hYmxlZBgB'
    'IAEoCFIOcm90YXJ5MUVuYWJsZWQSKgoRaW5wdXRicm9rZXJfcGluX2EYAiABKA1SD2lucHV0Yn'
    'Jva2VyUGluQRIqChFpbnB1dGJyb2tlcl9waW5fYhgDIAEoDVIPaW5wdXRicm9rZXJQaW5CEjIK'
    'FWlucHV0YnJva2VyX3Bpbl9wcmVzcxgEIAEoDVITaW5wdXRicm9rZXJQaW5QcmVzcxJtChRpbn'
    'B1dGJyb2tlcl9ldmVudF9jdxgFIAEoDjI7Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkNhbm5l'
    'ZE1lc3NhZ2VDb25maWcuSW5wdXRFdmVudENoYXJSEmlucHV0YnJva2VyRXZlbnRDdxJvChVpbn'
    'B1dGJyb2tlcl9ldmVudF9jY3cYBiABKA4yOy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5u'
    'ZWRNZXNzYWdlQ29uZmlnLklucHV0RXZlbnRDaGFyUhNpbnB1dGJyb2tlckV2ZW50Q2N3EnMKF2'
    'lucHV0YnJva2VyX2V2ZW50X3ByZXNzGAcgASgOMjsubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcu'
    'Q2FubmVkTWVzc2FnZUNvbmZpZy5JbnB1dEV2ZW50Q2hhclIVaW5wdXRicm9rZXJFdmVudFByZX'
    'NzEicKD3VwZG93bjFfZW5hYmxlZBgIIAEoCFIOdXBkb3duMUVuYWJsZWQSGAoHZW5hYmxlZBgJ'
    'IAEoCFIHZW5hYmxlZBIsChJhbGxvd19pbnB1dF9zb3VyY2UYCiABKAlSEGFsbG93SW5wdXRTb3'
    'VyY2USGwoJc2VuZF9iZWxsGAsgASgIUghzZW5kQmVsbCJjCg5JbnB1dEV2ZW50Q2hhchIICgRO'
    'T05FEAASBgoCVVAQERIICgRET1dOEBISCAoETEVGVBATEgkKBVJJR0hUEBQSCgoGU0VMRUNUEA'
    'oSCAoEQkFDSxAbEgoKBkNBTkNFTBAYGqIDCgtBdWRpb0NvbmZpZxIlCg5jb2RlYzJfZW5hYmxl'
    'ZBgBIAEoCFINY29kZWMyRW5hYmxlZBIXCgdwdHRfcGluGAIgASgNUgZwdHRQaW4SSQoHYml0cm'
    'F0ZRgDIAEoDjIvLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkF1ZGlvQ29uZmlnLkF1ZGlvX0Jh'
    'dWRSB2JpdHJhdGUSFQoGaTJzX3dzGAQgASgNUgVpMnNXcxIVCgZpMnNfc2QYBSABKA1SBWkyc1'
    'NkEhcKB2kyc19kaW4YBiABKA1SBmkyc0RpbhIXCgdpMnNfc2NrGAcgASgNUgZpMnNTY2sipwEK'
    'CkF1ZGlvX0JhdWQSEgoOQ09ERUMyX0RFRkFVTFQQABIPCgtDT0RFQzJfMzIwMBABEg8KC0NPRE'
    'VDMl8yNDAwEAISDwoLQ09ERUMyXzE2MDAQAxIPCgtDT0RFQzJfMTQwMBAEEg8KC0NPREVDMl8x'
    'MzAwEAUSDwoLQ09ERUMyXzEyMDAQBhIOCgpDT0RFQzJfNzAwEAcSDwoLQ09ERUMyXzcwMEIQCB'
    'qzAQoUUmVtb3RlSGFyZHdhcmVDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBI7Chph'
    'bGxvd191bmRlZmluZWRfcGluX2FjY2VzcxgCIAEoCFIXYWxsb3dVbmRlZmluZWRQaW5BY2Nlc3'
    'MSRAoOYXZhaWxhYmxlX3BpbnMYAyADKAsyHS5tZXNodGFzdGljLlJlbW90ZUhhcmR3YXJlUGlu'
    'Ug1hdmFpbGFibGVQaW5zGoUBChJOZWlnaGJvckluZm9Db25maWcSGAoHZW5hYmxlZBgBIAEoCF'
    'IHZW5hYmxlZBInCg91cGRhdGVfaW50ZXJ2YWwYAiABKA1SDnVwZGF0ZUludGVydmFsEiwKEnRy'
    'YW5zbWl0X292ZXJfbG9yYRgDIAEoCFIQdHJhbnNtaXRPdmVyTG9yYRqKAQoVQW1iaWVudExpZ2'
    'h0aW5nQ29uZmlnEhsKCWxlZF9zdGF0ZRgBIAEoCFIIbGVkU3RhdGUSGAoHY3VycmVudBgCIAEo'
    'DVIHY3VycmVudBIQCgNyZWQYAyABKA1SA3JlZBIUCgVncmVlbhgEIAEoDVIFZ3JlZW4SEgoEYm'
    'x1ZRgFIAEoDVIEYmx1ZRqHBAoVRGV0ZWN0aW9uU2Vuc29yQ29uZmlnEhgKB2VuYWJsZWQYASAB'
    'KAhSB2VuYWJsZWQSNAoWbWluaW11bV9icm9hZGNhc3Rfc2VjcxgCIAEoDVIUbWluaW11bUJyb2'
    'FkY2FzdFNlY3MSMAoUc3RhdGVfYnJvYWRjYXN0X3NlY3MYAyABKA1SEnN0YXRlQnJvYWRjYXN0'
    'U2VjcxIbCglzZW5kX2JlbGwYBCABKAhSCHNlbmRCZWxsEhIKBG5hbWUYBSABKAlSBG5hbWUSHw'
    'oLbW9uaXRvcl9waW4YBiABKA1SCm1vbml0b3JQaW4ScAoWZGV0ZWN0aW9uX3RyaWdnZXJfdHlw'
    'ZRgHIAEoDjI6Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkRldGVjdGlvblNlbnNvckNvbmZpZy'
    '5UcmlnZ2VyVHlwZVIUZGV0ZWN0aW9uVHJpZ2dlclR5cGUSHQoKdXNlX3B1bGx1cBgIIAEoCFIJ'
    'dXNlUHVsbHVwIogBCgtUcmlnZ2VyVHlwZRINCglMT0dJQ19MT1cQABIOCgpMT0dJQ19ISUdIEA'
    'ESEAoMRkFMTElOR19FREdFEAISDwoLUklTSU5HX0VER0UQAxIaChZFSVRIRVJfRURHRV9BQ1RJ'
    'VkVfTE9XEAQSGwoXRUlUSEVSX0VER0VfQUNUSVZFX0hJR0gQBRq2AQoQUGF4Y291bnRlckNvbm'
    'ZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEjwKGnBheGNvdW50ZXJfdXBkYXRlX2ludGVy'
    'dmFsGAIgASgNUhhwYXhjb3VudGVyVXBkYXRlSW50ZXJ2YWwSJQoOd2lmaV90aHJlc2hvbGQYAy'
    'ABKAVSDXdpZmlUaHJlc2hvbGQSIwoNYmxlX3RocmVzaG9sZBgEIAEoBVIMYmxlVGhyZXNob2xk'
    'QhEKD3BheWxvYWRfdmFyaWFudA==');
