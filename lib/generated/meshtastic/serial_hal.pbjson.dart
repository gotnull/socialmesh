// This is a generated file - do not edit.
//
// Generated from meshtastic/serial_hal.proto.

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

@$core.Deprecated('Use serialHalCommandDescriptor instead')
const SerialHalCommand$json = {
  '1': 'SerialHalCommand',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 13, '10': 'transactionId'},
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.SerialHalCommand.Type',
      '10': 'type'
    },
    {'1': 'pin', '3': 3, '4': 1, '5': 13, '10': 'pin'},
    {'1': 'value', '3': 4, '4': 1, '5': 13, '10': 'value'},
    {'1': 'mode', '3': 5, '4': 1, '5': 13, '10': 'mode'},
    {'1': 'data', '3': 6, '4': 1, '5': 12, '10': 'data'},
  ],
  '4': [SerialHalCommand_Type$json],
};

@$core.Deprecated('Use serialHalCommandDescriptor instead')
const SerialHalCommand_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'UNSET', '2': 0},
    {'1': 'PIN_MODE', '2': 1},
    {'1': 'DIGITAL_WRITE', '2': 2},
    {'1': 'DIGITAL_READ', '2': 3},
    {'1': 'ATTACH_INTERRUPT', '2': 4},
    {'1': 'DETACH_INTERRUPT', '2': 5},
    {'1': 'SPI_TRANSFER', '2': 6},
    {'1': 'NOOP', '2': 7},
  ],
};

/// Descriptor for `SerialHalCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serialHalCommandDescriptor = $convert.base64Decode(
    'ChBTZXJpYWxIYWxDb21tYW5kEiUKDnRyYW5zYWN0aW9uX2lkGAEgASgNUg10cmFuc2FjdGlvbk'
    'lkEjUKBHR5cGUYAiABKA4yIS5tZXNodGFzdGljLlNlcmlhbEhhbENvbW1hbmQuVHlwZVIEdHlw'
    'ZRIQCgNwaW4YAyABKA1SA3BpbhIUCgV2YWx1ZRgEIAEoDVIFdmFsdWUSEgoEbW9kZRgFIAEoDV'
    'IEbW9kZRISCgRkYXRhGAYgASgMUgRkYXRhIowBCgRUeXBlEgkKBVVOU0VUEAASDAoIUElOX01P'
    'REUQARIRCg1ESUdJVEFMX1dSSVRFEAISEAoMRElHSVRBTF9SRUFEEAMSFAoQQVRUQUNIX0lOVE'
    'VSUlVQVBAEEhQKEERFVEFDSF9JTlRFUlJVUFQQBRIQCgxTUElfVFJBTlNGRVIQBhIICgROT09Q'
    'EAc=');

@$core.Deprecated('Use serialHalResponseDescriptor instead')
const SerialHalResponse$json = {
  '1': 'SerialHalResponse',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 13, '10': 'transactionId'},
    {
      '1': 'result',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.SerialHalResponse.Result',
      '10': 'result'
    },
    {'1': 'value', '3': 3, '4': 1, '5': 13, '10': 'value'},
    {'1': 'data', '3': 4, '4': 1, '5': 12, '10': 'data'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '10': 'error'},
  ],
  '4': [SerialHalResponse_Result$json],
};

@$core.Deprecated('Use serialHalResponseDescriptor instead')
const SerialHalResponse_Result$json = {
  '1': 'Result',
  '2': [
    {'1': 'OK', '2': 0},
    {'1': 'ERROR', '2': 1},
    {'1': 'BAD_REQUEST', '2': 2},
    {'1': 'UNSUPPORTED', '2': 3},
  ],
};

/// Descriptor for `SerialHalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serialHalResponseDescriptor = $convert.base64Decode(
    'ChFTZXJpYWxIYWxSZXNwb25zZRIlCg50cmFuc2FjdGlvbl9pZBgBIAEoDVINdHJhbnNhY3Rpb2'
    '5JZBI8CgZyZXN1bHQYAiABKA4yJC5tZXNodGFzdGljLlNlcmlhbEhhbFJlc3BvbnNlLlJlc3Vs'
    'dFIGcmVzdWx0EhQKBXZhbHVlGAMgASgNUgV2YWx1ZRISCgRkYXRhGAQgASgMUgRkYXRhEhQKBW'
    'Vycm9yGAUgASgJUgVlcnJvciI9CgZSZXN1bHQSBgoCT0sQABIJCgVFUlJPUhABEg8KC0JBRF9S'
    'RVFVRVNUEAISDwoLVU5TVVBQT1JURUQQAw==');
