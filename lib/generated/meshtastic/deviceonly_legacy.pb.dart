// This is a generated file - do not edit.
//
// Generated from meshtastic/deviceonly_legacy.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'deviceonly.pb.dart' as $0;
import 'telemetry.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

///
///  Legacy NodeInfoLite descriptor used only to decode pre-split
///  /prefs/nodes.proto saves during the v24 -> v25 migration boot.
///  This preserves the original NodeInfoLite-compatible field numbers needed
///  to parse old wire bytes cleanly, including user (2), position (3),
///  device_metrics (6), and the legacy-only compatibility fields via_mqtt (8),
///  is_favorite (10), and is_ignored (11). Steady-state code does not use
///  this struct; it is dropped after migration completes. This file should be
///  removed once DEVICESTATE_MIN_VER advances past 24.
class NodeInfoLite_Legacy extends $pb.GeneratedMessage {
  factory NodeInfoLite_Legacy({
    $core.int? num,
    $0.UserLite? user,
    $0.PositionLite? position,
    $core.double? snr,
    $core.int? lastHeard,
    $1.DeviceMetrics? deviceMetrics,
    $core.int? channel,
    $core.bool? viaMqtt,
    $core.int? hopsAway,
    $core.bool? isFavorite,
    $core.bool? isIgnored,
    $core.int? nextHop,
    $core.int? bitfield,
  }) {
    final result = create();
    if (num != null) result.num = num;
    if (user != null) result.user = user;
    if (position != null) result.position = position;
    if (snr != null) result.snr = snr;
    if (lastHeard != null) result.lastHeard = lastHeard;
    if (deviceMetrics != null) result.deviceMetrics = deviceMetrics;
    if (channel != null) result.channel = channel;
    if (viaMqtt != null) result.viaMqtt = viaMqtt;
    if (hopsAway != null) result.hopsAway = hopsAway;
    if (isFavorite != null) result.isFavorite = isFavorite;
    if (isIgnored != null) result.isIgnored = isIgnored;
    if (nextHop != null) result.nextHop = nextHop;
    if (bitfield != null) result.bitfield = bitfield;
    return result;
  }

  NodeInfoLite_Legacy._();

  factory NodeInfoLite_Legacy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeInfoLite_Legacy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeInfoLite_Legacy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'num', fieldType: $pb.PbFieldType.OU3)
    ..aOM<$0.UserLite>(2, _omitFieldNames ? '' : 'user',
        subBuilder: $0.UserLite.create)
    ..aOM<$0.PositionLite>(3, _omitFieldNames ? '' : 'position',
        subBuilder: $0.PositionLite.create)
    ..aD(4, _omitFieldNames ? '' : 'snr', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'lastHeard', fieldType: $pb.PbFieldType.OF3)
    ..aOM<$1.DeviceMetrics>(6, _omitFieldNames ? '' : 'deviceMetrics',
        subBuilder: $1.DeviceMetrics.create)
    ..aI(7, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'viaMqtt')
    ..aI(9, _omitFieldNames ? '' : 'hopsAway', fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'isFavorite')
    ..aOB(11, _omitFieldNames ? '' : 'isIgnored')
    ..aI(12, _omitFieldNames ? '' : 'nextHop', fieldType: $pb.PbFieldType.OU3)
    ..aI(13, _omitFieldNames ? '' : 'bitfield', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfoLite_Legacy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfoLite_Legacy copyWith(void Function(NodeInfoLite_Legacy) updates) =>
      super.copyWith((message) => updates(message as NodeInfoLite_Legacy))
          as NodeInfoLite_Legacy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeInfoLite_Legacy create() => NodeInfoLite_Legacy._();
  @$core.override
  NodeInfoLite_Legacy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeInfoLite_Legacy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeInfoLite_Legacy>(create);
  static NodeInfoLite_Legacy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get num => $_getIZ(0);
  @$pb.TagNumber(1)
  set num($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearNum() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.UserLite get user => $_getN(1);
  @$pb.TagNumber(2)
  set user($0.UserLite value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.UserLite ensureUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.PositionLite get position => $_getN(2);
  @$pb.TagNumber(3)
  set position($0.PositionLite value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosition() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PositionLite ensurePosition() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.double get snr => $_getN(3);
  @$pb.TagNumber(4)
  set snr($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSnr() => $_has(3);
  @$pb.TagNumber(4)
  void clearSnr() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get lastHeard => $_getIZ(4);
  @$pb.TagNumber(5)
  set lastHeard($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastHeard() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastHeard() => $_clearField(5);

  @$pb.TagNumber(6)
  $1.DeviceMetrics get deviceMetrics => $_getN(5);
  @$pb.TagNumber(6)
  set deviceMetrics($1.DeviceMetrics value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDeviceMetrics() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceMetrics() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.DeviceMetrics ensureDeviceMetrics() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.int get channel => $_getIZ(6);
  @$pb.TagNumber(7)
  set channel($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChannel() => $_has(6);
  @$pb.TagNumber(7)
  void clearChannel() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get viaMqtt => $_getBF(7);
  @$pb.TagNumber(8)
  set viaMqtt($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasViaMqtt() => $_has(7);
  @$pb.TagNumber(8)
  void clearViaMqtt() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get hopsAway => $_getIZ(8);
  @$pb.TagNumber(9)
  set hopsAway($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHopsAway() => $_has(8);
  @$pb.TagNumber(9)
  void clearHopsAway() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isFavorite => $_getBF(9);
  @$pb.TagNumber(10)
  set isFavorite($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsFavorite() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsFavorite() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get isIgnored => $_getBF(10);
  @$pb.TagNumber(11)
  set isIgnored($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsIgnored() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsIgnored() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get nextHop => $_getIZ(11);
  @$pb.TagNumber(12)
  set nextHop($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasNextHop() => $_has(11);
  @$pb.TagNumber(12)
  void clearNextHop() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get bitfield => $_getIZ(12);
  @$pb.TagNumber(13)
  set bitfield($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasBitfield() => $_has(12);
  @$pb.TagNumber(13)
  void clearBitfield() => $_clearField(13);
}

///
///  Legacy NodeDatabase shape: one repeated array of fat NodeInfoLite_Legacy
///  with no satellite position/telemetry arrays.
class NodeDatabase_Legacy extends $pb.GeneratedMessage {
  factory NodeDatabase_Legacy({
    $core.int? version,
    $core.Iterable<NodeInfoLite_Legacy>? nodes,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (nodes != null) result.nodes.addAll(nodes);
    return result;
  }

  NodeDatabase_Legacy._();

  factory NodeDatabase_Legacy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeDatabase_Legacy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeDatabase_Legacy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'version', fieldType: $pb.PbFieldType.OU3)
    ..pPM<NodeInfoLite_Legacy>(2, _omitFieldNames ? '' : 'nodes',
        subBuilder: NodeInfoLite_Legacy.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeDatabase_Legacy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeDatabase_Legacy copyWith(void Function(NodeDatabase_Legacy) updates) =>
      super.copyWith((message) => updates(message as NodeDatabase_Legacy))
          as NodeDatabase_Legacy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeDatabase_Legacy create() => NodeDatabase_Legacy._();
  @$core.override
  NodeDatabase_Legacy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeDatabase_Legacy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeDatabase_Legacy>(create);
  static NodeDatabase_Legacy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<NodeInfoLite_Legacy> get nodes => $_getList(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
