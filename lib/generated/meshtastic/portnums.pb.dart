// This is a generated file - do not edit.
//
// Generated from meshtastic/portnums.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'mesh.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum ToRadio_PayloadVariant { packet, wantConfigId, disconnect, notSet }

/// Packets sent to/from the radio
class ToRadio extends $pb.GeneratedMessage {
  factory ToRadio({
    $0.MeshPacket? packet,
    $core.bool? wantConfigId,
    $core.bool? disconnect,
  }) {
    final result = create();
    if (packet != null) result.packet = packet;
    if (wantConfigId != null) result.wantConfigId = wantConfigId;
    if (disconnect != null) result.disconnect = disconnect;
    return result;
  }

  ToRadio._();

  factory ToRadio.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ToRadio.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ToRadio_PayloadVariant>
      _ToRadio_PayloadVariantByTag = {
    1: ToRadio_PayloadVariant.packet,
    100: ToRadio_PayloadVariant.wantConfigId,
    101: ToRadio_PayloadVariant.disconnect,
    0: ToRadio_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToRadio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 100, 101])
    ..aOM<$0.MeshPacket>(1, _omitFieldNames ? '' : 'packet',
        subBuilder: $0.MeshPacket.create)
    ..aOB(100, _omitFieldNames ? '' : 'wantConfigId')
    ..aOB(101, _omitFieldNames ? '' : 'disconnect')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToRadio clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToRadio copyWith(void Function(ToRadio) updates) =>
      super.copyWith((message) => updates(message as ToRadio)) as ToRadio;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ToRadio create() => ToRadio._();
  @$core.override
  ToRadio createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ToRadio getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ToRadio>(create);
  static ToRadio? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(100)
  @$pb.TagNumber(101)
  ToRadio_PayloadVariant whichPayloadVariant() =>
      _ToRadio_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(100)
  @$pb.TagNumber(101)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Mesh packet to send
  @$pb.TagNumber(1)
  $0.MeshPacket get packet => $_getN(0);
  @$pb.TagNumber(1)
  set packet($0.MeshPacket value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPacket() => $_has(0);
  @$pb.TagNumber(1)
  void clearPacket() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.MeshPacket ensurePacket() => $_ensure(0);

  /// Request device to send info
  @$pb.TagNumber(100)
  $core.bool get wantConfigId => $_getBF(1);
  @$pb.TagNumber(100)
  set wantConfigId($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(100)
  $core.bool hasWantConfigId() => $_has(1);
  @$pb.TagNumber(100)
  void clearWantConfigId() => $_clearField(100);

  /// Disconnect
  @$pb.TagNumber(101)
  $core.bool get disconnect => $_getBF(2);
  @$pb.TagNumber(101)
  set disconnect($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(101)
  $core.bool hasDisconnect() => $_has(2);
  @$pb.TagNumber(101)
  void clearDisconnect() => $_clearField(101);
}

enum FromRadio_PayloadVariant {
  packet,
  myInfo,
  nodeInfo,
  configCompleteId,
  loraConfig,
  channel,
  moduleConfig,
  notSet
}

/// Packets received from radio
class FromRadio extends $pb.GeneratedMessage {
  factory FromRadio({
    $core.int? id,
    $0.MeshPacket? packet,
    $0.MyNodeInfo? myInfo,
    $0.NodeInfo? nodeInfo,
    $core.int? configCompleteId,
    $0.RadioConfig_LoRaConfig? loraConfig,
    $0.Channel? channel,
    $core.List<$core.int>? moduleConfig,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (packet != null) result.packet = packet;
    if (myInfo != null) result.myInfo = myInfo;
    if (nodeInfo != null) result.nodeInfo = nodeInfo;
    if (configCompleteId != null) result.configCompleteId = configCompleteId;
    if (loraConfig != null) result.loraConfig = loraConfig;
    if (channel != null) result.channel = channel;
    if (moduleConfig != null) result.moduleConfig = moduleConfig;
    return result;
  }

  FromRadio._();

  factory FromRadio.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FromRadio.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, FromRadio_PayloadVariant>
      _FromRadio_PayloadVariantByTag = {
    2: FromRadio_PayloadVariant.packet,
    3: FromRadio_PayloadVariant.myInfo,
    4: FromRadio_PayloadVariant.nodeInfo,
    5: FromRadio_PayloadVariant.configCompleteId,
    6: FromRadio_PayloadVariant.loraConfig,
    7: FromRadio_PayloadVariant.channel,
    8: FromRadio_PayloadVariant.moduleConfig,
    0: FromRadio_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FromRadio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8])
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aOM<$0.MeshPacket>(2, _omitFieldNames ? '' : 'packet',
        subBuilder: $0.MeshPacket.create)
    ..aOM<$0.MyNodeInfo>(3, _omitFieldNames ? '' : 'myInfo',
        subBuilder: $0.MyNodeInfo.create)
    ..aOM<$0.NodeInfo>(4, _omitFieldNames ? '' : 'nodeInfo',
        subBuilder: $0.NodeInfo.create)
    ..aI(5, _omitFieldNames ? '' : 'configCompleteId',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<$0.RadioConfig_LoRaConfig>(6, _omitFieldNames ? '' : 'loraConfig',
        subBuilder: $0.RadioConfig_LoRaConfig.create)
    ..aOM<$0.Channel>(7, _omitFieldNames ? '' : 'channel',
        subBuilder: $0.Channel.create)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'moduleConfig', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FromRadio clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FromRadio copyWith(void Function(FromRadio) updates) =>
      super.copyWith((message) => updates(message as FromRadio)) as FromRadio;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FromRadio create() => FromRadio._();
  @$core.override
  FromRadio createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FromRadio getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FromRadio>(create);
  static FromRadio? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  FromRadio_PayloadVariant whichPayloadVariant() =>
      _FromRadio_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Packet ID for tracking
  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Received mesh packet
  @$pb.TagNumber(2)
  $0.MeshPacket get packet => $_getN(1);
  @$pb.TagNumber(2)
  set packet($0.MeshPacket value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPacket() => $_has(1);
  @$pb.TagNumber(2)
  void clearPacket() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.MeshPacket ensurePacket() => $_ensure(1);

  /// My node info
  @$pb.TagNumber(3)
  $0.MyNodeInfo get myInfo => $_getN(2);
  @$pb.TagNumber(3)
  set myInfo($0.MyNodeInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMyInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearMyInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.MyNodeInfo ensureMyInfo() => $_ensure(2);

  /// Node database entry
  @$pb.TagNumber(4)
  $0.NodeInfo get nodeInfo => $_getN(3);
  @$pb.TagNumber(4)
  set nodeInfo($0.NodeInfo value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasNodeInfo() => $_has(3);
  @$pb.TagNumber(4)
  void clearNodeInfo() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.NodeInfo ensureNodeInfo() => $_ensure(3);

  /// Configuration complete
  @$pb.TagNumber(5)
  $core.int get configCompleteId => $_getIZ(4);
  @$pb.TagNumber(5)
  set configCompleteId($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasConfigCompleteId() => $_has(4);
  @$pb.TagNumber(5)
  void clearConfigCompleteId() => $_clearField(5);

  /// LoRa config
  @$pb.TagNumber(6)
  $0.RadioConfig_LoRaConfig get loraConfig => $_getN(5);
  @$pb.TagNumber(6)
  set loraConfig($0.RadioConfig_LoRaConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLoraConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearLoraConfig() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.RadioConfig_LoRaConfig ensureLoraConfig() => $_ensure(5);

  /// Channel info
  @$pb.TagNumber(7)
  $0.Channel get channel => $_getN(6);
  @$pb.TagNumber(7)
  set channel($0.Channel value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasChannel() => $_has(6);
  @$pb.TagNumber(7)
  void clearChannel() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Channel ensureChannel() => $_ensure(6);

  /// Module config
  @$pb.TagNumber(8)
  $core.List<$core.int> get moduleConfig => $_getN(7);
  @$pb.TagNumber(8)
  set moduleConfig($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasModuleConfig() => $_has(7);
  @$pb.TagNumber(8)
  void clearModuleConfig() => $_clearField(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
