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

import 'lorawan_bridge.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'lorawan_bridge.pbenum.dart';

///
///  An uplink heard by the gateway, travelling towards the network server.
class LoRaWANBridge_Uplink extends $pb.GeneratedMessage {
  factory LoRaWANBridge_Uplink({
    $core.int? freqHz,
    $core.int? tmst,
    $core.int? rssiX10,
    $core.int? snrX10,
    $core.int? radioParams,
    $core.List<$core.int>? payload,
    $core.int? payloadId,
    $core.int? chunkCount,
    $core.int? fskBitrate,
  }) {
    final result = create();
    if (freqHz != null) result.freqHz = freqHz;
    if (tmst != null) result.tmst = tmst;
    if (rssiX10 != null) result.rssiX10 = rssiX10;
    if (snrX10 != null) result.snrX10 = snrX10;
    if (radioParams != null) result.radioParams = radioParams;
    if (payload != null) result.payload = payload;
    if (payloadId != null) result.payloadId = payloadId;
    if (chunkCount != null) result.chunkCount = chunkCount;
    if (fskBitrate != null) result.fskBitrate = fskBitrate;
    return result;
  }

  LoRaWANBridge_Uplink._();

  factory LoRaWANBridge_Uplink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoRaWANBridge_Uplink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoRaWANBridge.Uplink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'freqHz', fieldType: $pb.PbFieldType.OF3)
    ..aI(2, _omitFieldNames ? '' : 'tmst', fieldType: $pb.PbFieldType.OF3)
    ..aI(3, _omitFieldNames ? '' : 'rssiX10', fieldType: $pb.PbFieldType.OS3)
    ..aI(4, _omitFieldNames ? '' : 'snrX10', fieldType: $pb.PbFieldType.OS3)
    ..aI(5, _omitFieldNames ? '' : 'radioParams',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aI(7, _omitFieldNames ? '' : 'payloadId', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'chunkCount', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'fskBitrate', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_Uplink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_Uplink copyWith(void Function(LoRaWANBridge_Uplink) updates) =>
      super.copyWith((message) => updates(message as LoRaWANBridge_Uplink))
          as LoRaWANBridge_Uplink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_Uplink create() => LoRaWANBridge_Uplink._();
  @$core.override
  LoRaWANBridge_Uplink createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_Uplink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoRaWANBridge_Uplink>(create);
  static LoRaWANBridge_Uplink? _defaultInstance;

  ///
  ///  Receive frequency in Hz.
  @$pb.TagNumber(1)
  $core.int get freqHz => $_getIZ(0);
  @$pb.TagNumber(1)
  set freqHz($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFreqHz() => $_has(0);
  @$pb.TagNumber(1)
  void clearFreqHz() => $_clearField(1);

  ///
  ///  Concentrator receive timestamp in microseconds. Free running, wraps about
  ///  every 72 minutes.
  @$pb.TagNumber(2)
  $core.int get tmst => $_getIZ(1);
  @$pb.TagNumber(2)
  set tmst($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTmst() => $_has(1);
  @$pb.TagNumber(2)
  void clearTmst() => $_clearField(2);

  ///
  ///  Received signal strength in tenths of a dBm. Fits signed 16 bit.
  @$pb.TagNumber(3)
  $core.int get rssiX10 => $_getIZ(2);
  @$pb.TagNumber(3)
  set rssiX10($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRssiX10() => $_has(2);
  @$pb.TagNumber(3)
  void clearRssiX10() => $_clearField(3);

  ///
  ///  Signal to noise ratio in tenths of a dB. Fits signed 16 bit.
  @$pb.TagNumber(4)
  $core.int get snrX10 => $_getIZ(3);
  @$pb.TagNumber(4)
  set snrX10($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSnrX10() => $_has(3);
  @$pb.TagNumber(4)
  void clearSnrX10() => $_clearField(4);

  ///
  ///  Packed radio settings, 0 to 255. Meaningless when fsk_bitrate is set.
  ///    bits 7-5  0 to 7 for SF5 to SF12
  ///    bits 4-2  bandwidth in kHz: 0 125, 1 250, 2 500, 3 203.125, 4 406.25,
  ///              5 812.5, 6 1625, 7 reserved. Codes 0 to 2 are the sub-GHz set
  ///              and 3 to 6 the 2.4 GHz set; the two do not overlap. Any future
  ///              bandwidth takes the next free code rather than sorting in.
  ///    bits 1-0  0 to 3 for 4/5 to 4/8
  @$pb.TagNumber(5)
  $core.int get radioParams => $_getIZ(4);
  @$pb.TagNumber(5)
  set radioParams($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRadioParams() => $_has(4);
  @$pb.TagNumber(5)
  void clearRadioParams() => $_clearField(5);

  ///
  ///  PHY payload, or its first part when chunk_count is 2.
  @$pb.TagNumber(6)
  $core.List<$core.int> get payload => $_getN(5);
  @$pb.TagNumber(6)
  set payload($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPayload() => $_has(5);
  @$pb.TagNumber(6)
  void clearPayload() => $_clearField(6);

  ///
  ///  Groups this head with its continuation. 1 to 255, or 0 when not chunked.
  @$pb.TagNumber(7)
  $core.int get payloadId => $_getIZ(6);
  @$pb.TagNumber(7)
  set payloadId($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPayloadId() => $_has(6);
  @$pb.TagNumber(7)
  void clearPayloadId() => $_clearField(7);

  ///
  ///  0 when the frame fits one packet, otherwise 2.
  @$pb.TagNumber(8)
  $core.int get chunkCount => $_getIZ(7);
  @$pb.TagNumber(8)
  set chunkCount($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasChunkCount() => $_has(7);
  @$pb.TagNumber(8)
  void clearChunkCount() => $_clearField(8);

  ///
  ///  FSK bit rate in bits per second. Non-zero only for an FSK frame, in which
  ///  case radio_params does not apply. Fits unsigned 16 bit.
  @$pb.TagNumber(9)
  $core.int get fskBitrate => $_getIZ(8);
  @$pb.TagNumber(9)
  set fskBitrate($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFskBitrate() => $_has(8);
  @$pb.TagNumber(9)
  void clearFskBitrate() => $_clearField(9);
}

///
///  A downlink from the network server, travelling towards the gateway.
class LoRaWANBridge_Downlink extends $pb.GeneratedMessage {
  factory LoRaWANBridge_Downlink({
    $core.int? freqHz,
    $core.int? tmst,
    $core.int? radioParams,
    $core.int? powerDbm,
    $core.bool? immediate,
    $core.bool? invertPolarity,
    $core.bool? noCrc,
    $core.bool? mayDefer,
    $core.List<$core.int>? payload,
    $core.int? payloadId,
    $core.int? chunkCount,
    $core.int? requestId,
  }) {
    final result = create();
    if (freqHz != null) result.freqHz = freqHz;
    if (tmst != null) result.tmst = tmst;
    if (radioParams != null) result.radioParams = radioParams;
    if (powerDbm != null) result.powerDbm = powerDbm;
    if (immediate != null) result.immediate = immediate;
    if (invertPolarity != null) result.invertPolarity = invertPolarity;
    if (noCrc != null) result.noCrc = noCrc;
    if (mayDefer != null) result.mayDefer = mayDefer;
    if (payload != null) result.payload = payload;
    if (payloadId != null) result.payloadId = payloadId;
    if (chunkCount != null) result.chunkCount = chunkCount;
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  LoRaWANBridge_Downlink._();

  factory LoRaWANBridge_Downlink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoRaWANBridge_Downlink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoRaWANBridge.Downlink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'freqHz', fieldType: $pb.PbFieldType.OF3)
    ..aI(2, _omitFieldNames ? '' : 'tmst', fieldType: $pb.PbFieldType.OF3)
    ..aI(3, _omitFieldNames ? '' : 'radioParams',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'powerDbm', fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'immediate')
    ..aOB(6, _omitFieldNames ? '' : 'invertPolarity')
    ..aOB(7, _omitFieldNames ? '' : 'noCrc')
    ..aOB(8, _omitFieldNames ? '' : 'mayDefer')
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aI(10, _omitFieldNames ? '' : 'payloadId', fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'chunkCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(12, _omitFieldNames ? '' : 'requestId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_Downlink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_Downlink copyWith(
          void Function(LoRaWANBridge_Downlink) updates) =>
      super.copyWith((message) => updates(message as LoRaWANBridge_Downlink))
          as LoRaWANBridge_Downlink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_Downlink create() => LoRaWANBridge_Downlink._();
  @$core.override
  LoRaWANBridge_Downlink createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_Downlink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoRaWANBridge_Downlink>(create);
  static LoRaWANBridge_Downlink? _defaultInstance;

  ///
  ///  Transmit frequency in Hz.
  @$pb.TagNumber(1)
  $core.int get freqHz => $_getIZ(0);
  @$pb.TagNumber(1)
  set freqHz($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFreqHz() => $_has(0);
  @$pb.TagNumber(1)
  void clearFreqHz() => $_clearField(1);

  ///
  ///  Concentrator timestamp to transmit at. Ignored when immediate is set.
  @$pb.TagNumber(2)
  $core.int get tmst => $_getIZ(1);
  @$pb.TagNumber(2)
  set tmst($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTmst() => $_has(1);
  @$pb.TagNumber(2)
  void clearTmst() => $_clearField(2);

  ///
  ///  Packed radio settings, encoded as in Uplink.radio_params. FSK downlink is
  ///  not supported, so there is no bit rate or frequency deviation here.
  @$pb.TagNumber(3)
  $core.int get radioParams => $_getIZ(2);
  @$pb.TagNumber(3)
  set radioParams($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRadioParams() => $_has(2);
  @$pb.TagNumber(3)
  void clearRadioParams() => $_clearField(3);

  ///
  ///  Transmit power in dBm, 0 to 255. The gateway clamps it to its region.
  @$pb.TagNumber(4)
  $core.int get powerDbm => $_getIZ(3);
  @$pb.TagNumber(4)
  set powerDbm($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPowerDbm() => $_has(3);
  @$pb.TagNumber(4)
  void clearPowerDbm() => $_clearField(4);

  ///
  ///  Transmit as soon as possible instead of at tmst. Used for Class C.
  @$pb.TagNumber(5)
  $core.bool get immediate => $_getBF(4);
  @$pb.TagNumber(5)
  set immediate($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasImmediate() => $_has(4);
  @$pb.TagNumber(5)
  void clearImmediate() => $_clearField(5);

  ///
  ///  Invert LoRa polarity. True for every LoRaWAN downlink.
  @$pb.TagNumber(6)
  $core.bool get invertPolarity => $_getBF(5);
  @$pb.TagNumber(6)
  set invertPolarity($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInvertPolarity() => $_has(5);
  @$pb.TagNumber(6)
  void clearInvertPolarity() => $_clearField(6);

  ///
  ///  Disable the physical layer CRC.
  @$pb.TagNumber(7)
  $core.bool get noCrc => $_getBF(6);
  @$pb.TagNumber(7)
  set noCrc($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNoCrc() => $_has(6);
  @$pb.TagNumber(7)
  void clearNoCrc() => $_clearField(7);

  ///
  ///  Allow the gateway to send this in a later receive window if it arrives too
  ///  late. Leave clear for anything tied to a specific uplink.
  @$pb.TagNumber(8)
  $core.bool get mayDefer => $_getBF(7);
  @$pb.TagNumber(8)
  set mayDefer($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMayDefer() => $_has(7);
  @$pb.TagNumber(8)
  void clearMayDefer() => $_clearField(8);

  ///
  ///  PHY payload, or its first part when chunk_count is 2.
  @$pb.TagNumber(9)
  $core.List<$core.int> get payload => $_getN(8);
  @$pb.TagNumber(9)
  set payload($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPayload() => $_has(8);
  @$pb.TagNumber(9)
  void clearPayload() => $_clearField(9);

  ///
  ///  Groups this head with its continuation. 1 to 255, or 0 when not chunked.
  @$pb.TagNumber(10)
  $core.int get payloadId => $_getIZ(9);
  @$pb.TagNumber(10)
  set payloadId($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPayloadId() => $_has(9);
  @$pb.TagNumber(10)
  void clearPayloadId() => $_clearField(10);

  ///
  ///  0 when the frame fits one packet, otherwise 2.
  @$pb.TagNumber(11)
  $core.int get chunkCount => $_getIZ(10);
  @$pb.TagNumber(11)
  set chunkCount($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasChunkCount() => $_has(10);
  @$pb.TagNumber(11)
  void clearChunkCount() => $_clearField(11);

  ///
  ///  Identifies this downlink so its TxResult can be matched to it. 1 to 255.
  @$pb.TagNumber(12)
  $core.int get requestId => $_getIZ(11);
  @$pb.TagNumber(12)
  set requestId($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasRequestId() => $_has(11);
  @$pb.TagNumber(12)
  void clearRequestId() => $_clearField(12);
}

///
///  The remainder of a chunked Uplink or Downlink. Carries no RF metadata.
class LoRaWANBridge_PayloadChunk extends $pb.GeneratedMessage {
  factory LoRaWANBridge_PayloadChunk({
    $core.int? payloadId,
    $core.int? chunkIndex,
    $core.List<$core.int>? payloadChunk,
  }) {
    final result = create();
    if (payloadId != null) result.payloadId = payloadId;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (payloadChunk != null) result.payloadChunk = payloadChunk;
    return result;
  }

  LoRaWANBridge_PayloadChunk._();

  factory LoRaWANBridge_PayloadChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoRaWANBridge_PayloadChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoRaWANBridge.PayloadChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'payloadId', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'chunkIndex', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'payloadChunk', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_PayloadChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_PayloadChunk copyWith(
          void Function(LoRaWANBridge_PayloadChunk) updates) =>
      super.copyWith(
              (message) => updates(message as LoRaWANBridge_PayloadChunk))
          as LoRaWANBridge_PayloadChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_PayloadChunk create() => LoRaWANBridge_PayloadChunk._();
  @$core.override
  LoRaWANBridge_PayloadChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_PayloadChunk getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoRaWANBridge_PayloadChunk>(create);
  static LoRaWANBridge_PayloadChunk? _defaultInstance;

  ///
  ///  Matches payload_id in the head message. Reassembly keys on the sending
  ///  node and this value.
  @$pb.TagNumber(1)
  $core.int get payloadId => $_getIZ(0);
  @$pb.TagNumber(1)
  set payloadId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPayloadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayloadId() => $_clearField(1);

  ///
  ///  Position of this chunk. Always 1.
  @$pb.TagNumber(2)
  $core.int get chunkIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set chunkIndex($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChunkIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearChunkIndex() => $_clearField(2);

  ///
  ///  This part of the PHY payload.
  @$pb.TagNumber(3)
  $core.List<$core.int> get payloadChunk => $_getN(2);
  @$pb.TagNumber(3)
  set payloadChunk($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayloadChunk() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayloadChunk() => $_clearField(3);
}

///
///  The outcome of a downlink, reported back towards the network server.
class LoRaWANBridge_TxResult extends $pb.GeneratedMessage {
  factory LoRaWANBridge_TxResult({
    $core.int? tmst,
    LoRaWANBridge_TxResult_Status? status,
    $core.int? requestId,
  }) {
    final result = create();
    if (tmst != null) result.tmst = tmst;
    if (status != null) result.status = status;
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  LoRaWANBridge_TxResult._();

  factory LoRaWANBridge_TxResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoRaWANBridge_TxResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoRaWANBridge.TxResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'tmst', fieldType: $pb.PbFieldType.OF3)
    ..aE<LoRaWANBridge_TxResult_Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: LoRaWANBridge_TxResult_Status.values)
    ..aI(3, _omitFieldNames ? '' : 'requestId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_TxResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge_TxResult copyWith(
          void Function(LoRaWANBridge_TxResult) updates) =>
      super.copyWith((message) => updates(message as LoRaWANBridge_TxResult))
          as LoRaWANBridge_TxResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_TxResult create() => LoRaWANBridge_TxResult._();
  @$core.override
  LoRaWANBridge_TxResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge_TxResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoRaWANBridge_TxResult>(create);
  static LoRaWANBridge_TxResult? _defaultInstance;

  ///
  ///  The tmst the downlink was scheduled for. Zero when it was immediate, so
  ///  diagnostic only; correlate on request_id.
  @$pb.TagNumber(1)
  $core.int get tmst => $_getIZ(0);
  @$pb.TagNumber(1)
  set tmst($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTmst() => $_has(0);
  @$pb.TagNumber(1)
  void clearTmst() => $_clearField(1);

  ///
  ///  What happened to it.
  @$pb.TagNumber(2)
  LoRaWANBridge_TxResult_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(LoRaWANBridge_TxResult_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  ///
  ///  Echoes Downlink.request_id.
  @$pb.TagNumber(3)
  $core.int get requestId => $_getIZ(2);
  @$pb.TagNumber(3)
  set requestId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => $_clearField(3);
}

enum LoRaWANBridge_Variant { uplink, downlink, txResult, chunk, notSet }

///
///  Payload for LORAWAN_BRIDGE packets. Tunnels raw LoRaWAN PHY payloads and their
///  RF metadata so a gateway can reach a network server over a mesh.
class LoRaWANBridge extends $pb.GeneratedMessage {
  factory LoRaWANBridge({
    LoRaWANBridge_Uplink? uplink,
    LoRaWANBridge_Downlink? downlink,
    LoRaWANBridge_TxResult? txResult,
    LoRaWANBridge_PayloadChunk? chunk,
  }) {
    final result = create();
    if (uplink != null) result.uplink = uplink;
    if (downlink != null) result.downlink = downlink;
    if (txResult != null) result.txResult = txResult;
    if (chunk != null) result.chunk = chunk;
    return result;
  }

  LoRaWANBridge._();

  factory LoRaWANBridge.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoRaWANBridge.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, LoRaWANBridge_Variant>
      _LoRaWANBridge_VariantByTag = {
    1: LoRaWANBridge_Variant.uplink,
    2: LoRaWANBridge_Variant.downlink,
    3: LoRaWANBridge_Variant.txResult,
    4: LoRaWANBridge_Variant.chunk,
    0: LoRaWANBridge_Variant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoRaWANBridge',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<LoRaWANBridge_Uplink>(1, _omitFieldNames ? '' : 'uplink',
        subBuilder: LoRaWANBridge_Uplink.create)
    ..aOM<LoRaWANBridge_Downlink>(2, _omitFieldNames ? '' : 'downlink',
        subBuilder: LoRaWANBridge_Downlink.create)
    ..aOM<LoRaWANBridge_TxResult>(3, _omitFieldNames ? '' : 'txResult',
        subBuilder: LoRaWANBridge_TxResult.create)
    ..aOM<LoRaWANBridge_PayloadChunk>(4, _omitFieldNames ? '' : 'chunk',
        subBuilder: LoRaWANBridge_PayloadChunk.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoRaWANBridge copyWith(void Function(LoRaWANBridge) updates) =>
      super.copyWith((message) => updates(message as LoRaWANBridge))
          as LoRaWANBridge;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge create() => LoRaWANBridge._();
  @$core.override
  LoRaWANBridge createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoRaWANBridge getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoRaWANBridge>(create);
  static LoRaWANBridge? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  LoRaWANBridge_Variant whichVariant() =>
      _LoRaWANBridge_VariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearVariant() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  LoRaWANBridge_Uplink get uplink => $_getN(0);
  @$pb.TagNumber(1)
  set uplink(LoRaWANBridge_Uplink value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUplink() => $_has(0);
  @$pb.TagNumber(1)
  void clearUplink() => $_clearField(1);
  @$pb.TagNumber(1)
  LoRaWANBridge_Uplink ensureUplink() => $_ensure(0);

  @$pb.TagNumber(2)
  LoRaWANBridge_Downlink get downlink => $_getN(1);
  @$pb.TagNumber(2)
  set downlink(LoRaWANBridge_Downlink value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDownlink() => $_has(1);
  @$pb.TagNumber(2)
  void clearDownlink() => $_clearField(2);
  @$pb.TagNumber(2)
  LoRaWANBridge_Downlink ensureDownlink() => $_ensure(1);

  @$pb.TagNumber(3)
  LoRaWANBridge_TxResult get txResult => $_getN(2);
  @$pb.TagNumber(3)
  set txResult(LoRaWANBridge_TxResult value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTxResult() => $_has(2);
  @$pb.TagNumber(3)
  void clearTxResult() => $_clearField(3);
  @$pb.TagNumber(3)
  LoRaWANBridge_TxResult ensureTxResult() => $_ensure(2);

  @$pb.TagNumber(4)
  LoRaWANBridge_PayloadChunk get chunk => $_getN(3);
  @$pb.TagNumber(4)
  set chunk(LoRaWANBridge_PayloadChunk value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasChunk() => $_has(3);
  @$pb.TagNumber(4)
  void clearChunk() => $_clearField(4);
  @$pb.TagNumber(4)
  LoRaWANBridge_PayloadChunk ensureChunk() => $_ensure(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
