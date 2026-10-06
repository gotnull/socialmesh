// This is a generated file - do not edit.
//
// Generated from meshtastic/lorawan_bridge.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

///
///  Values 0 to 7 mirror the Semtech TX_ACK error field. Keep every value non
///  negative; enums encode as int32.
class LoRaWANBridge_TxResult_Status extends $pb.ProtobufEnum {
  static const LoRaWANBridge_TxResult_Status NONE =
      LoRaWANBridge_TxResult_Status._(0, _omitEnumNames ? '' : 'NONE');
  static const LoRaWANBridge_TxResult_Status TOO_LATE =
      LoRaWANBridge_TxResult_Status._(1, _omitEnumNames ? '' : 'TOO_LATE');
  static const LoRaWANBridge_TxResult_Status TOO_EARLY =
      LoRaWANBridge_TxResult_Status._(2, _omitEnumNames ? '' : 'TOO_EARLY');
  static const LoRaWANBridge_TxResult_Status COLLISION_PACKET =
      LoRaWANBridge_TxResult_Status._(
          3, _omitEnumNames ? '' : 'COLLISION_PACKET');
  static const LoRaWANBridge_TxResult_Status COLLISION_BEACON =
      LoRaWANBridge_TxResult_Status._(
          4, _omitEnumNames ? '' : 'COLLISION_BEACON');
  static const LoRaWANBridge_TxResult_Status TX_FREQ =
      LoRaWANBridge_TxResult_Status._(5, _omitEnumNames ? '' : 'TX_FREQ');
  static const LoRaWANBridge_TxResult_Status TX_POWER =
      LoRaWANBridge_TxResult_Status._(6, _omitEnumNames ? '' : 'TX_POWER');
  static const LoRaWANBridge_TxResult_Status GPS_UNLOCKED =
      LoRaWANBridge_TxResult_Status._(7, _omitEnumNames ? '' : 'GPS_UNLOCKED');

  ///
  ///  Held by the gateway for a later receive window.
  static const LoRaWANBridge_TxResult_Status DEFERRED =
      LoRaWANBridge_TxResult_Status._(8, _omitEnumNames ? '' : 'DEFERRED');

  ///
  ///  Discarded, either undeferrable or refused by an authorization check.
  static const LoRaWANBridge_TxResult_Status DROPPED =
      LoRaWANBridge_TxResult_Status._(9, _omitEnumNames ? '' : 'DROPPED');

  static const $core.List<LoRaWANBridge_TxResult_Status> values =
      <LoRaWANBridge_TxResult_Status>[
    NONE,
    TOO_LATE,
    TOO_EARLY,
    COLLISION_PACKET,
    COLLISION_BEACON,
    TX_FREQ,
    TX_POWER,
    GPS_UNLOCKED,
    DEFERRED,
    DROPPED,
  ];

  static final $core.List<LoRaWANBridge_TxResult_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static LoRaWANBridge_TxResult_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const LoRaWANBridge_TxResult_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
