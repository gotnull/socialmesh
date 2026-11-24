// This is a generated file - do not edit.
//
// Generated from meshtastic/clientonly.proto.

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

@$core.Deprecated('Use deviceProfileDescriptor instead')
const DeviceProfile$json = {
  '1': 'DeviceProfile',
  '2': [
    {
      '1': 'long_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'longName',
      '17': true
    },
    {
      '1': 'short_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'shortName',
      '17': true
    },
    {
      '1': 'channel_url',
      '3': 3,
      '4': 1,
      '5': 9,
      '8': {},
      '9': 2,
      '10': 'channelUrl',
      '17': true
    },
    {
      '1': 'config',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LocalConfig',
      '9': 3,
      '10': 'config',
      '17': true
    },
    {
      '1': 'module_config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.LocalModuleConfig',
      '9': 4,
      '10': 'moduleConfig',
      '17': true
    },
    {
      '1': 'fixed_position',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Position',
      '9': 5,
      '10': 'fixedPosition',
      '17': true
    },
    {
      '1': 'ringtone',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'ringtone',
      '17': true
    },
    {
      '1': 'canned_messages',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 7,
      '10': 'cannedMessages',
      '17': true
    },
    {
      '1': 'is_unmessagable',
      '3': 9,
      '4': 1,
      '5': 8,
      '9': 8,
      '10': 'isUnmessagable',
      '17': true
    },
    {
      '1': 'is_licensed',
      '3': 10,
      '4': 1,
      '5': 8,
      '9': 9,
      '10': 'isLicensed',
      '17': true
    },
  ],
  '8': [
    {'1': '_long_name'},
    {'1': '_short_name'},
    {'1': '_channel_url'},
    {'1': '_config'},
    {'1': '_module_config'},
    {'1': '_fixed_position'},
    {'1': '_ringtone'},
    {'1': '_canned_messages'},
    {'1': '_is_unmessagable'},
    {'1': '_is_licensed'},
  ],
};

/// Descriptor for `DeviceProfile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceProfileDescriptor = $convert.base64Decode(
    'Cg1EZXZpY2VQcm9maWxlEiAKCWxvbmdfbmFtZRgBIAEoCUgAUghsb25nTmFtZYgBARIiCgpzaG'
    '9ydF9uYW1lGAIgASgJSAFSCXNob3J0TmFtZYgBARIsCgtjaGFubmVsX3VybBgDIAEoCUIGyvMY'
    'AmgBSAJSCmNoYW5uZWxVcmyIAQESNAoGY29uZmlnGAQgASgLMhcubWVzaHRhc3RpYy5Mb2NhbE'
    'NvbmZpZ0gDUgZjb25maWeIAQESRwoNbW9kdWxlX2NvbmZpZxgFIAEoCzIdLm1lc2h0YXN0aWMu'
    'TG9jYWxNb2R1bGVDb25maWdIBFIMbW9kdWxlQ29uZmlniAEBEkAKDmZpeGVkX3Bvc2l0aW9uGA'
    'YgASgLMhQubWVzaHRhc3RpYy5Qb3NpdGlvbkgFUg1maXhlZFBvc2l0aW9uiAEBEh8KCHJpbmd0'
    'b25lGAcgASgJSAZSCHJpbmd0b25liAEBEiwKD2Nhbm5lZF9tZXNzYWdlcxgIIAEoCUgHUg5jYW'
    '5uZWRNZXNzYWdlc4gBARIsCg9pc191bm1lc3NhZ2FibGUYCSABKAhICFIOaXNVbm1lc3NhZ2Fi'
    'bGWIAQESJAoLaXNfbGljZW5zZWQYCiABKAhICVIKaXNMaWNlbnNlZIgBAUIMCgpfbG9uZ19uYW'
    '1lQg0KC19zaG9ydF9uYW1lQg4KDF9jaGFubmVsX3VybEIJCgdfY29uZmlnQhAKDl9tb2R1bGVf'
    'Y29uZmlnQhEKD19maXhlZF9wb3NpdGlvbkILCglfcmluZ3RvbmVCEgoQX2Nhbm5lZF9tZXNzYW'
    'dlc0ISChBfaXNfdW5tZXNzYWdhYmxlQg4KDF9pc19saWNlbnNlZA==');
