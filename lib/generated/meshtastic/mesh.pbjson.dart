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

@$core.Deprecated('Use deviceMetricsDescriptor instead')
const DeviceMetrics$json = {
  '1': 'DeviceMetrics',
  '2': [
    {'1': 'battery_level', '3': 1, '4': 1, '5': 13, '10': 'batteryLevel'},
    {'1': 'voltage', '3': 2, '4': 1, '5': 2, '10': 'voltage'},
    {
      '1': 'channel_utilization',
      '3': 3,
      '4': 1,
      '5': 2,
      '10': 'channelUtilization'
    },
    {'1': 'air_util_tx', '3': 4, '4': 1, '5': 2, '10': 'airUtilTx'},
    {'1': 'uptime_seconds', '3': 5, '4': 1, '5': 13, '10': 'uptimeSeconds'},
  ],
};

/// Descriptor for `DeviceMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceMetricsDescriptor = $convert.base64Decode(
    'Cg1EZXZpY2VNZXRyaWNzEiMKDWJhdHRlcnlfbGV2ZWwYASABKA1SDGJhdHRlcnlMZXZlbBIYCg'
    'd2b2x0YWdlGAIgASgCUgd2b2x0YWdlEi8KE2NoYW5uZWxfdXRpbGl6YXRpb24YAyABKAJSEmNo'
    'YW5uZWxVdGlsaXphdGlvbhIeCgthaXJfdXRpbF90eBgEIAEoAlIJYWlyVXRpbFR4EiUKDnVwdG'
    'ltZV9zZWNvbmRzGAUgASgNUg11cHRpbWVTZWNvbmRz');

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
      '1': 'get_radio_request',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getRadioRequest'
    },
    {
      '1': 'get_radio_response',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RadioConfig',
      '9': 0,
      '10': 'getRadioResponse'
    },
    {
      '1': 'get_owner_request',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'getOwnerRequest'
    },
    {
      '1': 'get_owner_response',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.User',
      '9': 0,
      '10': 'getOwnerResponse'
    },
    {
      '1': 'set_owner',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.User',
      '9': 0,
      '10': 'setOwner'
    },
    {
      '1': 'set_channel',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Channel',
      '9': 0,
      '10': 'setChannel'
    },
    {
      '1': 'set_radio',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RadioConfig',
      '9': 0,
      '10': 'setRadio'
    },
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `AdminMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminMessageDescriptor = $convert.base64Decode(
    'CgxBZG1pbk1lc3NhZ2USMAoTZ2V0X2NoYW5uZWxfcmVxdWVzdBgBIAEoDUgAUhFnZXRDaGFubm'
    'VsUmVxdWVzdBJHChRnZXRfY2hhbm5lbF9yZXNwb25zZRgCIAEoCzITLm1lc2h0YXN0aWMuQ2hh'
    'bm5lbEgAUhJnZXRDaGFubmVsUmVzcG9uc2USLAoRZ2V0X3JhZGlvX3JlcXVlc3QYAyABKAhIAF'
    'IPZ2V0UmFkaW9SZXF1ZXN0EkcKEmdldF9yYWRpb19yZXNwb25zZRgEIAEoCzIXLm1lc2h0YXN0'
    'aWMuUmFkaW9Db25maWdIAFIQZ2V0UmFkaW9SZXNwb25zZRIsChFnZXRfb3duZXJfcmVxdWVzdB'
    'gFIAEoCEgAUg9nZXRPd25lclJlcXVlc3QSQAoSZ2V0X293bmVyX3Jlc3BvbnNlGAYgASgLMhAu'
    'bWVzaHRhc3RpYy5Vc2VySABSEGdldE93bmVyUmVzcG9uc2USLwoJc2V0X293bmVyGAcgASgLMh'
    'AubWVzaHRhc3RpYy5Vc2VySABSCHNldE93bmVyEjYKC3NldF9jaGFubmVsGAggASgLMhMubWVz'
    'aHRhc3RpYy5DaGFubmVsSABSCnNldENoYW5uZWwSNgoJc2V0X3JhZGlvGAkgASgLMhcubWVzaH'
    'Rhc3RpYy5SYWRpb0NvbmZpZ0gAUghzZXRSYWRpb0IRCg9wYXlsb2FkX3ZhcmlhbnQ=');

@$core.Deprecated('Use radioConfigDescriptor instead')
const RadioConfig$json = {
  '1': 'RadioConfig',
  '2': [
    {
      '1': 'lora',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RadioConfig.LoRaConfig',
      '10': 'lora'
    },
  ],
  '3': [RadioConfig_LoRaConfig$json],
};

@$core.Deprecated('Use radioConfigDescriptor instead')
const RadioConfig_LoRaConfig$json = {
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
  ],
};

/// Descriptor for `RadioConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List radioConfigDescriptor = $convert.base64Decode(
    'CgtSYWRpb0NvbmZpZxI2CgRsb3JhGAEgASgLMiIubWVzaHRhc3RpYy5SYWRpb0NvbmZpZy5Mb1'
    'JhQ29uZmlnUgRsb3JhGv0CCgpMb1JhQ29uZmlnEh0KCnVzZV9wcmVzZXQYASABKAhSCXVzZVBy'
    'ZXNldBI6Cgxtb2RlbV9wcmVzZXQYAiABKA4yFy5tZXNodGFzdGljLk1vZGVtUHJlc2V0Ugttb2'
    'RlbVByZXNldBIcCgliYW5kd2lkdGgYAyABKA1SCWJhbmR3aWR0aBIjCg1zcHJlYWRfZmFjdG9y'
    'GAQgASgNUgxzcHJlYWRGYWN0b3ISHwoLY29kaW5nX3JhdGUYBSABKA1SCmNvZGluZ1JhdGUSKQ'
    'oQZnJlcXVlbmN5X29mZnNldBgGIAEoAlIPZnJlcXVlbmN5T2Zmc2V0Ei4KBnJlZ2lvbhgHIAEo'
    'DjIWLm1lc2h0YXN0aWMuUmVnaW9uQ29kZVIGcmVnaW9uEhsKCWhvcF9saW1pdBgIIAEoDVIIaG'
    '9wTGltaXQSHQoKdHhfZW5hYmxlZBgJIAEoCFIJdHhFbmFibGVkEhkKCHR4X3Bvd2VyGAogASgF'
    'Ugd0eFBvd2Vy');
