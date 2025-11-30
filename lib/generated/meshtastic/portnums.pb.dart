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
import 'portnums.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'portnums.pbenum.dart';

enum ToRadio_PayloadVariant {
  packet,
  wantConfigId,
  disconnect,
  heartbeat,
  notSet
}

/// Packets sent to the radio
class ToRadio extends $pb.GeneratedMessage {
  factory ToRadio({
    $0.MeshPacket? packet,
    $core.int? wantConfigId,
    $core.bool? disconnect,
    Heartbeat? heartbeat,
  }) {
    final result = create();
    if (packet != null) result.packet = packet;
    if (wantConfigId != null) result.wantConfigId = wantConfigId;
    if (disconnect != null) result.disconnect = disconnect;
    if (heartbeat != null) result.heartbeat = heartbeat;
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
    3: ToRadio_PayloadVariant.wantConfigId,
    4: ToRadio_PayloadVariant.disconnect,
    7: ToRadio_PayloadVariant.heartbeat,
    0: ToRadio_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToRadio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 3, 4, 7])
    ..aOM<$0.MeshPacket>(1, _omitFieldNames ? '' : 'packet',
        subBuilder: $0.MeshPacket.create)
    ..aI(3, _omitFieldNames ? '' : 'wantConfigId',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'disconnect')
    ..aOM<Heartbeat>(7, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.create)
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
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(7)
  ToRadio_PayloadVariant whichPayloadVariant() =>
      _ToRadio_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(7)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Send this packet on the mesh
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

  /// Phone wants radio to send full node db to the phone.
  /// The integer you write into this field will be reported back in the
  /// config_complete_id response - allows clients to never be confused by
  /// a stale old partially sent config.
  @$pb.TagNumber(3)
  $core.int get wantConfigId => $_getIZ(1);
  @$pb.TagNumber(3)
  set wantConfigId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(3)
  $core.bool hasWantConfigId() => $_has(1);
  @$pb.TagNumber(3)
  void clearWantConfigId() => $_clearField(3);

  /// Tell API server we are disconnecting now.
  @$pb.TagNumber(4)
  $core.bool get disconnect => $_getBF(2);
  @$pb.TagNumber(4)
  set disconnect($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(4)
  $core.bool hasDisconnect() => $_has(2);
  @$pb.TagNumber(4)
  void clearDisconnect() => $_clearField(4);

  /// Heartbeat message (keeps serial connections alive)
  @$pb.TagNumber(7)
  Heartbeat get heartbeat => $_getN(3);
  @$pb.TagNumber(7)
  set heartbeat(Heartbeat value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasHeartbeat() => $_has(3);
  @$pb.TagNumber(7)
  void clearHeartbeat() => $_clearField(7);
  @$pb.TagNumber(7)
  Heartbeat ensureHeartbeat() => $_ensure(3);
}

/// Heartbeat message
class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat({
    $core.int? nonce,
  }) {
    final result = create();
    if (nonce != null) result.nonce = nonce;
    return result;
  }

  Heartbeat._();

  factory Heartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Heartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'nonce', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat copyWith(void Function(Heartbeat) updates) =>
      super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Heartbeat create() => Heartbeat._();
  @$core.override
  Heartbeat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get nonce => $_getIZ(0);
  @$pb.TagNumber(1)
  set nonce($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNonce() => $_has(0);
  @$pb.TagNumber(1)
  void clearNonce() => $_clearField(1);
}

enum FromRadio_PayloadVariant {
  packet,
  myInfo,
  nodeInfo,
  config,
  logRecord,
  configCompleteId,
  rebooted,
  moduleConfig,
  channel,
  queueStatus,
  metadata,
  notSet
}

/// Packets received from radio
class FromRadio extends $pb.GeneratedMessage {
  factory FromRadio({
    $core.int? id,
    $0.MeshPacket? packet,
    $0.MyNodeInfo? myInfo,
    $0.NodeInfo? nodeInfo,
    $0.Config? config,
    LogRecord? logRecord,
    $core.int? configCompleteId,
    $core.bool? rebooted,
    $0.ModuleConfig? moduleConfig,
    $0.Channel? channel,
    QueueStatus? queueStatus,
    $0.DeviceMetadata? metadata,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (packet != null) result.packet = packet;
    if (myInfo != null) result.myInfo = myInfo;
    if (nodeInfo != null) result.nodeInfo = nodeInfo;
    if (config != null) result.config = config;
    if (logRecord != null) result.logRecord = logRecord;
    if (configCompleteId != null) result.configCompleteId = configCompleteId;
    if (rebooted != null) result.rebooted = rebooted;
    if (moduleConfig != null) result.moduleConfig = moduleConfig;
    if (channel != null) result.channel = channel;
    if (queueStatus != null) result.queueStatus = queueStatus;
    if (metadata != null) result.metadata = metadata;
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
    5: FromRadio_PayloadVariant.config,
    6: FromRadio_PayloadVariant.logRecord,
    7: FromRadio_PayloadVariant.configCompleteId,
    8: FromRadio_PayloadVariant.rebooted,
    9: FromRadio_PayloadVariant.moduleConfig,
    10: FromRadio_PayloadVariant.channel,
    11: FromRadio_PayloadVariant.queueStatus,
    13: FromRadio_PayloadVariant.metadata,
    0: FromRadio_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FromRadio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13])
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aOM<$0.MeshPacket>(2, _omitFieldNames ? '' : 'packet',
        subBuilder: $0.MeshPacket.create)
    ..aOM<$0.MyNodeInfo>(3, _omitFieldNames ? '' : 'myInfo',
        subBuilder: $0.MyNodeInfo.create)
    ..aOM<$0.NodeInfo>(4, _omitFieldNames ? '' : 'nodeInfo',
        subBuilder: $0.NodeInfo.create)
    ..aOM<$0.Config>(5, _omitFieldNames ? '' : 'config',
        subBuilder: $0.Config.create)
    ..aOM<LogRecord>(6, _omitFieldNames ? '' : 'logRecord',
        subBuilder: LogRecord.create)
    ..aI(7, _omitFieldNames ? '' : 'configCompleteId',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'rebooted')
    ..aOM<$0.ModuleConfig>(9, _omitFieldNames ? '' : 'moduleConfig',
        protoName: 'moduleConfig', subBuilder: $0.ModuleConfig.create)
    ..aOM<$0.Channel>(10, _omitFieldNames ? '' : 'channel',
        subBuilder: $0.Channel.create)
    ..aOM<QueueStatus>(11, _omitFieldNames ? '' : 'queueStatus',
        protoName: 'queueStatus', subBuilder: QueueStatus.create)
    ..aOM<$0.DeviceMetadata>(13, _omitFieldNames ? '' : 'metadata',
        subBuilder: $0.DeviceMetadata.create)
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
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(13)
  FromRadio_PayloadVariant whichPayloadVariant() =>
      _FromRadio_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(13)
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

  /// My node info - tells the phone what our node number is
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

  /// One packet is sent for each node in the on radio DB
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

  /// Include a part of the config
  @$pb.TagNumber(5)
  $0.Config get config => $_getN(4);
  @$pb.TagNumber(5)
  set config($0.Config value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearConfig() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Config ensureConfig() => $_ensure(4);

  /// Debug console output over protobuf stream
  @$pb.TagNumber(6)
  LogRecord get logRecord => $_getN(5);
  @$pb.TagNumber(6)
  set logRecord(LogRecord value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLogRecord() => $_has(5);
  @$pb.TagNumber(6)
  void clearLogRecord() => $_clearField(6);
  @$pb.TagNumber(6)
  LogRecord ensureLogRecord() => $_ensure(5);

  /// Sent as true once the device has finished sending all of the
  /// responses to want_config - contains the config_id sent in wantConfigId
  @$pb.TagNumber(7)
  $core.int get configCompleteId => $_getIZ(6);
  @$pb.TagNumber(7)
  set configCompleteId($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasConfigCompleteId() => $_has(6);
  @$pb.TagNumber(7)
  void clearConfigCompleteId() => $_clearField(7);

  /// Sent to tell clients the radio has just rebooted
  @$pb.TagNumber(8)
  $core.bool get rebooted => $_getBF(7);
  @$pb.TagNumber(8)
  set rebooted($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRebooted() => $_has(7);
  @$pb.TagNumber(8)
  void clearRebooted() => $_clearField(8);

  /// Include module config
  @$pb.TagNumber(9)
  $0.ModuleConfig get moduleConfig => $_getN(8);
  @$pb.TagNumber(9)
  set moduleConfig($0.ModuleConfig value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasModuleConfig() => $_has(8);
  @$pb.TagNumber(9)
  void clearModuleConfig() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.ModuleConfig ensureModuleConfig() => $_ensure(8);

  /// One packet is sent for each channel
  @$pb.TagNumber(10)
  $0.Channel get channel => $_getN(9);
  @$pb.TagNumber(10)
  set channel($0.Channel value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasChannel() => $_has(9);
  @$pb.TagNumber(10)
  void clearChannel() => $_clearField(10);
  @$pb.TagNumber(10)
  $0.Channel ensureChannel() => $_ensure(9);

  /// Queue status info
  @$pb.TagNumber(11)
  QueueStatus get queueStatus => $_getN(10);
  @$pb.TagNumber(11)
  set queueStatus(QueueStatus value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasQueueStatus() => $_has(10);
  @$pb.TagNumber(11)
  void clearQueueStatus() => $_clearField(11);
  @$pb.TagNumber(11)
  QueueStatus ensureQueueStatus() => $_ensure(10);

  /// Device metadata
  @$pb.TagNumber(13)
  $0.DeviceMetadata get metadata => $_getN(11);
  @$pb.TagNumber(13)
  set metadata($0.DeviceMetadata value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasMetadata() => $_has(11);
  @$pb.TagNumber(13)
  void clearMetadata() => $_clearField(13);
  @$pb.TagNumber(13)
  $0.DeviceMetadata ensureMetadata() => $_ensure(11);
}

/// Log record for debug output
class LogRecord extends $pb.GeneratedMessage {
  factory LogRecord({
    $core.String? message,
    $core.int? time,
    $core.String? source,
    LogRecord_Level? level,
  }) {
    final result = create();
    if (message != null) result.message = message;
    if (time != null) result.time = time;
    if (source != null) result.source = source;
    if (level != null) result.level = level;
    return result;
  }

  LogRecord._();

  factory LogRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..aI(2, _omitFieldNames ? '' : 'time', fieldType: $pb.PbFieldType.OF3)
    ..aOS(3, _omitFieldNames ? '' : 'source')
    ..aE<LogRecord_Level>(4, _omitFieldNames ? '' : 'level',
        enumValues: LogRecord_Level.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRecord copyWith(void Function(LogRecord) updates) =>
      super.copyWith((message) => updates(message as LogRecord)) as LogRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogRecord create() => LogRecord._();
  @$core.override
  LogRecord createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogRecord>(create);
  static LogRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get time => $_getIZ(1);
  @$pb.TagNumber(2)
  set time($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearTime() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get source => $_getSZ(2);
  @$pb.TagNumber(3)
  set source($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => $_clearField(3);

  @$pb.TagNumber(4)
  LogRecord_Level get level => $_getN(3);
  @$pb.TagNumber(4)
  set level(LogRecord_Level value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearLevel() => $_clearField(4);
}

/// Queue status
class QueueStatus extends $pb.GeneratedMessage {
  factory QueueStatus({
    $core.int? res,
    $core.int? free,
    $core.int? maxlen,
    $core.int? meshPacketId,
  }) {
    final result = create();
    if (res != null) result.res = res;
    if (free != null) result.free = free;
    if (maxlen != null) result.maxlen = maxlen;
    if (meshPacketId != null) result.meshPacketId = meshPacketId;
    return result;
  }

  QueueStatus._();

  factory QueueStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QueueStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueueStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'res')
    ..aI(2, _omitFieldNames ? '' : 'free', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'maxlen', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'meshPacketId',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueueStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueueStatus copyWith(void Function(QueueStatus) updates) =>
      super.copyWith((message) => updates(message as QueueStatus))
          as QueueStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueueStatus create() => QueueStatus._();
  @$core.override
  QueueStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QueueStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QueueStatus>(create);
  static QueueStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get res => $_getIZ(0);
  @$pb.TagNumber(1)
  set res($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRes() => $_has(0);
  @$pb.TagNumber(1)
  void clearRes() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get free => $_getIZ(1);
  @$pb.TagNumber(2)
  set free($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFree() => $_has(1);
  @$pb.TagNumber(2)
  void clearFree() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxlen => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxlen($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxlen() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxlen() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get meshPacketId => $_getIZ(3);
  @$pb.TagNumber(4)
  set meshPacketId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMeshPacketId() => $_has(3);
  @$pb.TagNumber(4)
  void clearMeshPacketId() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
