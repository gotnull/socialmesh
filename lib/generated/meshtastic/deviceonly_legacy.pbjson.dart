// This is a generated file - do not edit.
//
// Generated from meshtastic/deviceonly_legacy.proto.

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

@$core.Deprecated('Use nodeInfoLite_LegacyDescriptor instead')
const NodeInfoLite_Legacy$json = {
  '1': 'NodeInfoLite_Legacy',
  '2': [
    {'1': 'num', '3': 1, '4': 1, '5': 13, '10': 'num'},
    {
      '1': 'user',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.UserLite',
      '10': 'user'
    },
    {
      '1': 'position',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.PositionLite',
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
    {'1': 'channel', '3': 7, '4': 1, '5': 13, '10': 'channel'},
    {'1': 'via_mqtt', '3': 8, '4': 1, '5': 8, '10': 'viaMqtt'},
    {
      '1': 'hops_away',
      '3': 9,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'hopsAway',
      '17': true
    },
    {'1': 'is_favorite', '3': 10, '4': 1, '5': 8, '10': 'isFavorite'},
    {'1': 'is_ignored', '3': 11, '4': 1, '5': 8, '10': 'isIgnored'},
    {'1': 'next_hop', '3': 12, '4': 1, '5': 13, '10': 'nextHop'},
    {'1': 'bitfield', '3': 13, '4': 1, '5': 13, '10': 'bitfield'},
  ],
  '8': [
    {'1': '_hops_away'},
  ],
};

/// Descriptor for `NodeInfoLite_Legacy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeInfoLite_LegacyDescriptor = $convert.base64Decode(
    'ChNOb2RlSW5mb0xpdGVfTGVnYWN5EhAKA251bRgBIAEoDVIDbnVtEigKBHVzZXIYAiABKAsyFC'
    '5tZXNodGFzdGljLlVzZXJMaXRlUgR1c2VyEjQKCHBvc2l0aW9uGAMgASgLMhgubWVzaHRhc3Rp'
    'Yy5Qb3NpdGlvbkxpdGVSCHBvc2l0aW9uEhAKA3NuchgEIAEoAlIDc25yEh0KCmxhc3RfaGVhcm'
    'QYBSABKAdSCWxhc3RIZWFyZBJACg5kZXZpY2VfbWV0cmljcxgGIAEoCzIZLm1lc2h0YXN0aWMu'
    'RGV2aWNlTWV0cmljc1INZGV2aWNlTWV0cmljcxIYCgdjaGFubmVsGAcgASgNUgdjaGFubmVsEh'
    'kKCHZpYV9tcXR0GAggASgIUgd2aWFNcXR0EiAKCWhvcHNfYXdheRgJIAEoDUgAUghob3BzQXdh'
    'eYgBARIfCgtpc19mYXZvcml0ZRgKIAEoCFIKaXNGYXZvcml0ZRIdCgppc19pZ25vcmVkGAsgAS'
    'gIUglpc0lnbm9yZWQSGQoIbmV4dF9ob3AYDCABKA1SB25leHRIb3ASGgoIYml0ZmllbGQYDSAB'
    'KA1SCGJpdGZpZWxkQgwKCl9ob3BzX2F3YXk=');

@$core.Deprecated('Use nodeDatabase_LegacyDescriptor instead')
const NodeDatabase_Legacy$json = {
  '1': 'NodeDatabase_Legacy',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 13, '10': 'version'},
    {
      '1': 'nodes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.NodeInfoLite_Legacy',
      '8': {},
      '10': 'nodes'
    },
  ],
};

/// Descriptor for `NodeDatabase_Legacy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDatabase_LegacyDescriptor = $convert.base64Decode(
    'ChNOb2RlRGF0YWJhc2VfTGVnYWN5EhgKB3ZlcnNpb24YASABKA1SB3ZlcnNpb24SaAoFbm9kZX'
    'MYAiADKAsyHy5tZXNodGFzdGljLk5vZGVJbmZvTGl0ZV9MZWdhY3lCMZI/LpIBK3N0ZDo6dmVj'
    'dG9yPG1lc2h0YXN0aWNfTm9kZUluZm9MaXRlX0xlZ2FjeT5SBW5vZGVz');
