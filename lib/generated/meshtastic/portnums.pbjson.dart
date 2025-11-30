// This is a generated file - do not edit.
//
// Generated from meshtastic/portnums.proto.

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

@$core.Deprecated('Use toRadioDescriptor instead')
const ToRadio$json = {
  '1': 'ToRadio',
  '2': [
    {
      '1': 'packet',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.MeshPacket',
      '9': 0,
      '10': 'packet'
    },
    {
      '1': 'want_config_id',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'wantConfigId'
    },
    {'1': 'disconnect', '3': 4, '4': 1, '5': 8, '9': 0, '10': 'disconnect'},
    {
      '1': 'heartbeat',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `ToRadio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toRadioDescriptor = $convert.base64Decode(
    'CgdUb1JhZGlvEjAKBnBhY2tldBgBIAEoCzIWLm1lc2h0YXN0aWMuTWVzaFBhY2tldEgAUgZwYW'
    'NrZXQSJgoOd2FudF9jb25maWdfaWQYAyABKA1IAFIMd2FudENvbmZpZ0lkEiAKCmRpc2Nvbm5l'
    'Y3QYBCABKAhIAFIKZGlzY29ubmVjdBI1CgloZWFydGJlYXQYByABKAsyFS5tZXNodGFzdGljLk'
    'hlYXJ0YmVhdEgAUgloZWFydGJlYXRCEQoPcGF5bG9hZF92YXJpYW50');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'nonce', '3': 1, '4': 1, '5': 13, '10': 'nonce'},
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor =
    $convert.base64Decode('CglIZWFydGJlYXQSFAoFbm9uY2UYASABKA1SBW5vbmNl');

@$core.Deprecated('Use fromRadioDescriptor instead')
const FromRadio$json = {
  '1': 'FromRadio',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 13, '10': 'id'},
    {
      '1': 'packet',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.MeshPacket',
      '9': 0,
      '10': 'packet'
    },
    {
      '1': 'my_info',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.MyNodeInfo',
      '9': 0,
      '10': 'myInfo'
    },
    {
      '1': 'node_info',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.NodeInfo',
      '9': 0,
      '10': 'nodeInfo'
    },
    {
      '1': 'config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config',
      '9': 0,
      '10': 'config'
    },
    {
      '1': 'log_record',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LogRecord',
      '9': 0,
      '10': 'logRecord'
    },
    {
      '1': 'config_complete_id',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'configCompleteId'
    },
    {'1': 'rebooted', '3': 8, '4': 1, '5': 8, '9': 0, '10': 'rebooted'},
    {
      '1': 'moduleConfig',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig',
      '9': 0,
      '10': 'moduleConfig'
    },
    {
      '1': 'channel',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Channel',
      '9': 0,
      '10': 'channel'
    },
    {
      '1': 'queueStatus',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.QueueStatus',
      '9': 0,
      '10': 'queueStatus'
    },
    {
      '1': 'metadata',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DeviceMetadata',
      '9': 0,
      '10': 'metadata'
    },
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `FromRadio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fromRadioDescriptor = $convert.base64Decode(
    'CglGcm9tUmFkaW8SDgoCaWQYASABKA1SAmlkEjAKBnBhY2tldBgCIAEoCzIWLm1lc2h0YXN0aW'
    'MuTWVzaFBhY2tldEgAUgZwYWNrZXQSMQoHbXlfaW5mbxgDIAEoCzIWLm1lc2h0YXN0aWMuTXlO'
    'b2RlSW5mb0gAUgZteUluZm8SMwoJbm9kZV9pbmZvGAQgASgLMhQubWVzaHRhc3RpYy5Ob2RlSW'
    '5mb0gAUghub2RlSW5mbxIsCgZjb25maWcYBSABKAsyEi5tZXNodGFzdGljLkNvbmZpZ0gAUgZj'
    'b25maWcSNgoKbG9nX3JlY29yZBgGIAEoCzIVLm1lc2h0YXN0aWMuTG9nUmVjb3JkSABSCWxvZ1'
    'JlY29yZBIuChJjb25maWdfY29tcGxldGVfaWQYByABKA1IAFIQY29uZmlnQ29tcGxldGVJZBIc'
    'CghyZWJvb3RlZBgIIAEoCEgAUghyZWJvb3RlZBI+Cgxtb2R1bGVDb25maWcYCSABKAsyGC5tZX'
    'NodGFzdGljLk1vZHVsZUNvbmZpZ0gAUgxtb2R1bGVDb25maWcSLwoHY2hhbm5lbBgKIAEoCzIT'
    'Lm1lc2h0YXN0aWMuQ2hhbm5lbEgAUgdjaGFubmVsEjsKC3F1ZXVlU3RhdHVzGAsgASgLMhcubW'
    'VzaHRhc3RpYy5RdWV1ZVN0YXR1c0gAUgtxdWV1ZVN0YXR1cxI4CghtZXRhZGF0YRgNIAEoCzIa'
    'Lm1lc2h0YXN0aWMuRGV2aWNlTWV0YWRhdGFIAFIIbWV0YWRhdGFCEQoPcGF5bG9hZF92YXJpYW'
    '50');

@$core.Deprecated('Use logRecordDescriptor instead')
const LogRecord$json = {
  '1': 'LogRecord',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    {'1': 'time', '3': 2, '4': 1, '5': 7, '10': 'time'},
    {'1': 'source', '3': 3, '4': 1, '5': 9, '10': 'source'},
    {
      '1': 'level',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.LogRecord.Level',
      '10': 'level'
    },
  ],
  '4': [LogRecord_Level$json],
};

@$core.Deprecated('Use logRecordDescriptor instead')
const LogRecord_Level$json = {
  '1': 'Level',
  '2': [
    {'1': 'UNSET', '2': 0},
    {'1': 'CRITICAL', '2': 50},
    {'1': 'ERROR', '2': 40},
    {'1': 'WARNING', '2': 30},
    {'1': 'INFO', '2': 20},
    {'1': 'DEBUG', '2': 10},
    {'1': 'TRACE', '2': 5},
  ],
};

/// Descriptor for `LogRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logRecordDescriptor = $convert.base64Decode(
    'CglMb2dSZWNvcmQSGAoHbWVzc2FnZRgBIAEoCVIHbWVzc2FnZRISCgR0aW1lGAIgASgHUgR0aW'
    '1lEhYKBnNvdXJjZRgDIAEoCVIGc291cmNlEjEKBWxldmVsGAQgASgOMhsubWVzaHRhc3RpYy5M'
    'b2dSZWNvcmQuTGV2ZWxSBWxldmVsIlgKBUxldmVsEgkKBVVOU0VUEAASDAoIQ1JJVElDQUwQMh'
    'IJCgVFUlJPUhAoEgsKB1dBUk5JTkcQHhIICgRJTkZPEBQSCQoFREVCVUcQChIJCgVUUkFDRRAF');

@$core.Deprecated('Use queueStatusDescriptor instead')
const QueueStatus$json = {
  '1': 'QueueStatus',
  '2': [
    {'1': 'res', '3': 1, '4': 1, '5': 5, '10': 'res'},
    {'1': 'free', '3': 2, '4': 1, '5': 13, '10': 'free'},
    {'1': 'maxlen', '3': 3, '4': 1, '5': 13, '10': 'maxlen'},
    {'1': 'mesh_packet_id', '3': 4, '4': 1, '5': 13, '10': 'meshPacketId'},
  ],
};

/// Descriptor for `QueueStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queueStatusDescriptor = $convert.base64Decode(
    'CgtRdWV1ZVN0YXR1cxIQCgNyZXMYASABKAVSA3JlcxISCgRmcmVlGAIgASgNUgRmcmVlEhYKBm'
    '1heGxlbhgDIAEoDVIGbWF4bGVuEiQKDm1lc2hfcGFja2V0X2lkGAQgASgNUgxtZXNoUGFja2V0'
    'SWQ=');
