// This is a generated file - do not edit.
//
// Generated from meshtastic/serial_hal.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'serial_hal.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'serial_hal.pbenum.dart';

class SerialHalCommand extends $pb.GeneratedMessage {
  factory SerialHalCommand({
    $core.int? transactionId,
    SerialHalCommand_Type? type,
    $core.int? pin,
    $core.int? value,
    $core.int? mode,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    if (type != null) result.type = type;
    if (pin != null) result.pin = pin;
    if (value != null) result.value = value;
    if (mode != null) result.mode = mode;
    if (data != null) result.data = data;
    return result;
  }

  SerialHalCommand._();

  factory SerialHalCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SerialHalCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SerialHalCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'transactionId',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<SerialHalCommand_Type>(2, _omitFieldNames ? '' : 'type',
        enumValues: SerialHalCommand_Type.values)
    ..aI(3, _omitFieldNames ? '' : 'pin', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'value', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'mode', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SerialHalCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SerialHalCommand copyWith(void Function(SerialHalCommand) updates) =>
      super.copyWith((message) => updates(message as SerialHalCommand))
          as SerialHalCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SerialHalCommand create() => SerialHalCommand._();
  @$core.override
  SerialHalCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SerialHalCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SerialHalCommand>(create);
  static SerialHalCommand? _defaultInstance;

  /// Host-assigned request id. Replies echo this id back in
  /// SerialHalResponse.transaction_id.
  @$pb.TagNumber(1)
  $core.int get transactionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SerialHalCommand_Type get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(SerialHalCommand_Type value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get pin => $_getIZ(2);
  @$pb.TagNumber(3)
  set pin($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPin() => $_has(2);
  @$pb.TagNumber(3)
  void clearPin() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get value => $_getIZ(3);
  @$pb.TagNumber(4)
  set value($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearValue() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get mode => $_getIZ(4);
  @$pb.TagNumber(5)
  set mode($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get data => $_getN(5);
  @$pb.TagNumber(6)
  set data($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasData() => $_has(5);
  @$pb.TagNumber(6)
  void clearData() => $_clearField(6);
}

class SerialHalResponse extends $pb.GeneratedMessage {
  factory SerialHalResponse({
    $core.int? transactionId,
    SerialHalResponse_Result? result,
    $core.int? value,
    $core.List<$core.int>? data,
    $core.String? error,
  }) {
    final result$ = create();
    if (transactionId != null) result$.transactionId = transactionId;
    if (result != null) result$.result = result;
    if (value != null) result$.value = value;
    if (data != null) result$.data = data;
    if (error != null) result$.error = error;
    return result$;
  }

  SerialHalResponse._();

  factory SerialHalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SerialHalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SerialHalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'transactionId',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<SerialHalResponse_Result>(2, _omitFieldNames ? '' : 'result',
        enumValues: SerialHalResponse_Result.values)
    ..aI(3, _omitFieldNames ? '' : 'value', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SerialHalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SerialHalResponse copyWith(void Function(SerialHalResponse) updates) =>
      super.copyWith((message) => updates(message as SerialHalResponse))
          as SerialHalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SerialHalResponse create() => SerialHalResponse._();
  @$core.override
  SerialHalResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SerialHalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SerialHalResponse>(create);
  static SerialHalResponse? _defaultInstance;

  /// Matches the originating SerialHalCommand.transaction_id for normal
  /// request/response traffic.
  ///
  /// A value of 0 indicates an unsolicited interrupt notification generated by
  /// the device. In that case, the host should interpret value as the GPIO pin
  /// that triggered.
  @$pb.TagNumber(1)
  $core.int get transactionId => $_getIZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SerialHalResponse_Result get result => $_getN(1);
  @$pb.TagNumber(2)
  set result(SerialHalResponse_Result value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResult() => $_has(1);
  @$pb.TagNumber(2)
  void clearResult() => $_clearField(2);

  /// Used by DIGITAL_READ replies and interrupt notifications. For interrupt
  /// notifications (transaction_id == 0), this carries the pin number.
  @$pb.TagNumber(3)
  $core.int get value => $_getIZ(2);
  @$pb.TagNumber(3)
  set value($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get data => $_getN(3);
  @$pb.TagNumber(4)
  set data($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasData() => $_has(3);
  @$pb.TagNumber(4)
  void clearData() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
