// This is a generated file - do not edit.
//
// Generated from meshtastic/lorawan_bridge.proto.

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

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge$json = {
  '1': 'LoRaWANBridge',
  '2': [
    {
      '1': 'uplink',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LoRaWANBridge.Uplink',
      '9': 0,
      '10': 'uplink'
    },
    {
      '1': 'downlink',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LoRaWANBridge.Downlink',
      '9': 0,
      '10': 'downlink'
    },
    {
      '1': 'tx_result',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LoRaWANBridge.TxResult',
      '9': 0,
      '10': 'txResult'
    },
    {
      '1': 'chunk',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LoRaWANBridge.PayloadChunk',
      '9': 0,
      '10': 'chunk'
    },
  ],
  '3': [
    LoRaWANBridge_Uplink$json,
    LoRaWANBridge_Downlink$json,
    LoRaWANBridge_PayloadChunk$json,
    LoRaWANBridge_TxResult$json
  ],
  '8': [
    {'1': 'variant'},
  ],
};

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge_Uplink$json = {
  '1': 'Uplink',
  '2': [
    {'1': 'freq_hz', '3': 1, '4': 1, '5': 7, '10': 'freqHz'},
    {'1': 'tmst', '3': 2, '4': 1, '5': 7, '10': 'tmst'},
    {'1': 'rssi_x10', '3': 3, '4': 1, '5': 17, '10': 'rssiX10'},
    {'1': 'snr_x10', '3': 4, '4': 1, '5': 17, '10': 'snrX10'},
    {'1': 'radio_params', '3': 5, '4': 1, '5': 13, '10': 'radioParams'},
    {'1': 'fsk_bitrate', '3': 9, '4': 1, '5': 13, '10': 'fskBitrate'},
    {'1': 'payload', '3': 6, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'payload_id', '3': 7, '4': 1, '5': 13, '10': 'payloadId'},
    {'1': 'chunk_count', '3': 8, '4': 1, '5': 13, '10': 'chunkCount'},
  ],
};

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge_Downlink$json = {
  '1': 'Downlink',
  '2': [
    {'1': 'freq_hz', '3': 1, '4': 1, '5': 7, '10': 'freqHz'},
    {'1': 'tmst', '3': 2, '4': 1, '5': 7, '10': 'tmst'},
    {'1': 'radio_params', '3': 3, '4': 1, '5': 13, '10': 'radioParams'},
    {'1': 'power_dbm', '3': 4, '4': 1, '5': 13, '10': 'powerDbm'},
    {'1': 'immediate', '3': 5, '4': 1, '5': 8, '10': 'immediate'},
    {'1': 'invert_polarity', '3': 6, '4': 1, '5': 8, '10': 'invertPolarity'},
    {'1': 'no_crc', '3': 7, '4': 1, '5': 8, '10': 'noCrc'},
    {'1': 'may_defer', '3': 8, '4': 1, '5': 8, '10': 'mayDefer'},
    {'1': 'request_id', '3': 12, '4': 1, '5': 13, '10': 'requestId'},
    {'1': 'payload', '3': 9, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'payload_id', '3': 10, '4': 1, '5': 13, '10': 'payloadId'},
    {'1': 'chunk_count', '3': 11, '4': 1, '5': 13, '10': 'chunkCount'},
  ],
};

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge_PayloadChunk$json = {
  '1': 'PayloadChunk',
  '2': [
    {'1': 'payload_id', '3': 1, '4': 1, '5': 13, '10': 'payloadId'},
    {'1': 'chunk_index', '3': 2, '4': 1, '5': 13, '10': 'chunkIndex'},
    {'1': 'payload_chunk', '3': 3, '4': 1, '5': 12, '10': 'payloadChunk'},
  ],
};

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge_TxResult$json = {
  '1': 'TxResult',
  '2': [
    {'1': 'tmst', '3': 1, '4': 1, '5': 7, '10': 'tmst'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.LoRaWANBridge.TxResult.Status',
      '10': 'status'
    },
    {'1': 'request_id', '3': 3, '4': 1, '5': 13, '10': 'requestId'},
  ],
  '4': [LoRaWANBridge_TxResult_Status$json],
};

@$core.Deprecated('Use loRaWANBridgeDescriptor instead')
const LoRaWANBridge_TxResult_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'NONE', '2': 0},
    {'1': 'TOO_LATE', '2': 1},
    {'1': 'TOO_EARLY', '2': 2},
    {'1': 'COLLISION_PACKET', '2': 3},
    {'1': 'COLLISION_BEACON', '2': 4},
    {'1': 'TX_FREQ', '2': 5},
    {'1': 'TX_POWER', '2': 6},
    {'1': 'GPS_UNLOCKED', '2': 7},
    {'1': 'DEFERRED', '2': 8},
    {'1': 'DROPPED', '2': 9},
  ],
};

/// Descriptor for `LoRaWANBridge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loRaWANBridgeDescriptor = $convert.base64Decode(
    'Cg1Mb1JhV0FOQnJpZGdlEjoKBnVwbGluaxgBIAEoCzIgLm1lc2h0YXN0aWMuTG9SYVdBTkJyaW'
    'RnZS5VcGxpbmtIAFIGdXBsaW5rEkAKCGRvd25saW5rGAIgASgLMiIubWVzaHRhc3RpYy5Mb1Jh'
    'V0FOQnJpZGdlLkRvd25saW5rSABSCGRvd25saW5rEkEKCXR4X3Jlc3VsdBgDIAEoCzIiLm1lc2'
    'h0YXN0aWMuTG9SYVdBTkJyaWRnZS5UeFJlc3VsdEgAUgh0eFJlc3VsdBI+CgVjaHVuaxgEIAEo'
    'CzImLm1lc2h0YXN0aWMuTG9SYVdBTkJyaWRnZS5QYXlsb2FkQ2h1bmtIAFIFY2h1bmsahwIKBl'
    'VwbGluaxIXCgdmcmVxX2h6GAEgASgHUgZmcmVxSHoSEgoEdG1zdBgCIAEoB1IEdG1zdBIZCghy'
    'c3NpX3gxMBgDIAEoEVIHcnNzaVgxMBIXCgdzbnJfeDEwGAQgASgRUgZzbnJYMTASIQoMcmFkaW'
    '9fcGFyYW1zGAUgASgNUgtyYWRpb1BhcmFtcxIfCgtmc2tfYml0cmF0ZRgJIAEoDVIKZnNrQml0'
    'cmF0ZRIYCgdwYXlsb2FkGAYgASgMUgdwYXlsb2FkEh0KCnBheWxvYWRfaWQYByABKA1SCXBheW'
    'xvYWRJZBIfCgtjaHVua19jb3VudBgIIAEoDVIKY2h1bmtDb3VudBrrAgoIRG93bmxpbmsSFwoH'
    'ZnJlcV9oehgBIAEoB1IGZnJlcUh6EhIKBHRtc3QYAiABKAdSBHRtc3QSIQoMcmFkaW9fcGFyYW'
    '1zGAMgASgNUgtyYWRpb1BhcmFtcxIbCglwb3dlcl9kYm0YBCABKA1SCHBvd2VyRGJtEhwKCWlt'
    'bWVkaWF0ZRgFIAEoCFIJaW1tZWRpYXRlEicKD2ludmVydF9wb2xhcml0eRgGIAEoCFIOaW52ZX'
    'J0UG9sYXJpdHkSFQoGbm9fY3JjGAcgASgIUgVub0NyYxIbCgltYXlfZGVmZXIYCCABKAhSCG1h'
    'eURlZmVyEh0KCnJlcXVlc3RfaWQYDCABKA1SCXJlcXVlc3RJZBIYCgdwYXlsb2FkGAkgASgMUg'
    'dwYXlsb2FkEh0KCnBheWxvYWRfaWQYCiABKA1SCXBheWxvYWRJZBIfCgtjaHVua19jb3VudBgL'
    'IAEoDVIKY2h1bmtDb3VudBpzCgxQYXlsb2FkQ2h1bmsSHQoKcGF5bG9hZF9pZBgBIAEoDVIJcG'
    'F5bG9hZElkEh8KC2NodW5rX2luZGV4GAIgASgNUgpjaHVua0luZGV4EiMKDXBheWxvYWRfY2h1'
    'bmsYAyABKAxSDHBheWxvYWRDaHVuaxqmAgoIVHhSZXN1bHQSEgoEdG1zdBgBIAEoB1IEdG1zdB'
    'JBCgZzdGF0dXMYAiABKA4yKS5tZXNodGFzdGljLkxvUmFXQU5CcmlkZ2UuVHhSZXN1bHQuU3Rh'
    'dHVzUgZzdGF0dXMSHQoKcmVxdWVzdF9pZBgDIAEoDVIJcmVxdWVzdElkIqMBCgZTdGF0dXMSCA'
    'oETk9ORRAAEgwKCFRPT19MQVRFEAESDQoJVE9PX0VBUkxZEAISFAoQQ09MTElTSU9OX1BBQ0tF'
    'VBADEhQKEENPTExJU0lPTl9CRUFDT04QBBILCgdUWF9GUkVREAUSDAoIVFhfUE9XRVIQBhIQCg'
    'xHUFNfVU5MT0NLRUQQBxIMCghERUZFUlJFRBAIEgsKB0RST1BQRUQQCUIJCgd2YXJpYW50');
