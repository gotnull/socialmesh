// This is a generated file - do not edit.
//
// Generated from meshtastic/mesh_beacon.proto.

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

@$core.Deprecated('Use meshBeaconDescriptor instead')
const MeshBeacon$json = {
  '1': 'MeshBeacon',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'offer_channel',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ChannelSettings',
      '10': 'offerChannel'
    },
    {
      '1': 'offer_region',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.RegionCode',
      '10': 'offerRegion'
    },
    {
      '1': 'offer_preset',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.ModemPreset',
      '9': 0,
      '10': 'offerPreset',
      '17': true
    },
  ],
  '8': [
    {'1': '_offer_preset'},
  ],
};

/// Descriptor for `MeshBeacon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List meshBeaconDescriptor = $convert.base64Decode(
    'CgpNZXNoQmVhY29uEhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2USQAoNb2ZmZXJfY2hhbm5lbB'
    'gCIAEoCzIbLm1lc2h0YXN0aWMuQ2hhbm5lbFNldHRpbmdzUgxvZmZlckNoYW5uZWwSSwoMb2Zm'
    'ZXJfcmVnaW9uGAMgASgOMigubWVzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5SZWdpb25Db2'
    'RlUgtvZmZlclJlZ2lvbhJRCgxvZmZlcl9wcmVzZXQYBCABKA4yKS5tZXNodGFzdGljLkNvbmZp'
    'Zy5Mb1JhQ29uZmlnLk1vZGVtUHJlc2V0SABSC29mZmVyUHJlc2V0iAEBQg8KDV9vZmZlcl9wcm'
    'VzZXQ=');
