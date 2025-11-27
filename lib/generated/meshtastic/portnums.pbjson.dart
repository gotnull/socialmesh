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
      '3': 100,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'wantConfigId'
    },
    {'1': 'disconnect', '3': 101, '4': 1, '5': 8, '9': 0, '10': 'disconnect'},
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `ToRadio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toRadioDescriptor = $convert.base64Decode(
    'CgdUb1JhZGlvEjAKBnBhY2tldBgBIAEoCzIWLm1lc2h0YXN0aWMuTWVzaFBhY2tldEgAUgZwYW'
    'NrZXQSJgoOd2FudF9jb25maWdfaWQYZCABKAhIAFIMd2FudENvbmZpZ0lkEiAKCmRpc2Nvbm5l'
    'Y3QYZSABKAhIAFIKZGlzY29ubmVjdEIRCg9wYXlsb2FkX3ZhcmlhbnQ=');

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
      '1': 'config_complete_id',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'configCompleteId'
    },
    {
      '1': 'lora_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RadioConfig.LoRaConfig',
      '9': 0,
      '10': 'loraConfig'
    },
    {
      '1': 'channel',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Channel',
      '9': 0,
      '10': 'channel'
    },
    {
      '1': 'module_config',
      '3': 8,
      '4': 1,
      '5': 12,
      '9': 0,
      '10': 'moduleConfig'
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
    '5mb0gAUghub2RlSW5mbxIuChJjb25maWdfY29tcGxldGVfaWQYBSABKA1IAFIQY29uZmlnQ29t'
    'cGxldGVJZBJFCgtsb3JhX2NvbmZpZxgGIAEoCzIiLm1lc2h0YXN0aWMuUmFkaW9Db25maWcuTG'
    '9SYUNvbmZpZ0gAUgpsb3JhQ29uZmlnEi8KB2NoYW5uZWwYByABKAsyEy5tZXNodGFzdGljLkNo'
    'YW5uZWxIAFIHY2hhbm5lbBIlCg1tb2R1bGVfY29uZmlnGAggASgMSABSDG1vZHVsZUNvbmZpZ0'
    'IRCg9wYXlsb2FkX3ZhcmlhbnQ=');
