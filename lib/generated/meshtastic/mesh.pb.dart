// This is a generated file - do not edit.
//
// Generated from meshtastic/mesh.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'mesh.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'mesh.pbenum.dart';

/// Unique identifier for a node
class Position extends $pb.GeneratedMessage {
  factory Position({
    $core.int? latitudeI,
    $core.int? longitudeI,
    $core.int? altitude,
    $core.int? time,
  }) {
    final result = create();
    if (latitudeI != null) result.latitudeI = latitudeI;
    if (longitudeI != null) result.longitudeI = longitudeI;
    if (altitude != null) result.altitude = altitude;
    if (time != null) result.time = time;
    return result;
  }

  Position._();

  factory Position.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Position.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Position',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'latitudeI', fieldType: $pb.PbFieldType.OSF3)
    ..aI(2, _omitFieldNames ? '' : 'longitudeI',
        fieldType: $pb.PbFieldType.OSF3)
    ..aI(3, _omitFieldNames ? '' : 'altitude')
    ..aI(4, _omitFieldNames ? '' : 'time', fieldType: $pb.PbFieldType.OF3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position copyWith(void Function(Position) updates) =>
      super.copyWith((message) => updates(message as Position)) as Position;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Position create() => Position._();
  @$core.override
  Position createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Position getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Position>(create);
  static Position? _defaultInstance;

  /// Latitude in degrees * 1e-7
  @$pb.TagNumber(1)
  $core.int get latitudeI => $_getIZ(0);
  @$pb.TagNumber(1)
  set latitudeI($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLatitudeI() => $_has(0);
  @$pb.TagNumber(1)
  void clearLatitudeI() => $_clearField(1);

  /// Longitude in degrees * 1e-7
  @$pb.TagNumber(2)
  $core.int get longitudeI => $_getIZ(1);
  @$pb.TagNumber(2)
  set longitudeI($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLongitudeI() => $_has(1);
  @$pb.TagNumber(2)
  void clearLongitudeI() => $_clearField(2);

  /// Altitude in meters above MSL
  @$pb.TagNumber(3)
  $core.int get altitude => $_getIZ(2);
  @$pb.TagNumber(3)
  set altitude($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAltitude() => $_has(2);
  @$pb.TagNumber(3)
  void clearAltitude() => $_clearField(3);

  /// Timestamp in seconds since 1970
  @$pb.TagNumber(4)
  $core.int get time => $_getIZ(3);
  @$pb.TagNumber(4)
  set time($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearTime() => $_clearField(4);
}

/// User information
class User extends $pb.GeneratedMessage {
  factory User({
    $core.String? id,
    $core.String? longName,
    $core.String? shortName,
    $core.List<$core.int>? macaddr,
    HardwareModel? hwModel,
    $core.bool? isLicensed,
    Config_DeviceConfig_Role? role,
    $core.List<$core.int>? publicKey,
    $core.bool? isUnmessagable,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (longName != null) result.longName = longName;
    if (shortName != null) result.shortName = shortName;
    if (macaddr != null) result.macaddr = macaddr;
    if (hwModel != null) result.hwModel = hwModel;
    if (isLicensed != null) result.isLicensed = isLicensed;
    if (role != null) result.role = role;
    if (publicKey != null) result.publicKey = publicKey;
    if (isUnmessagable != null) result.isUnmessagable = isUnmessagable;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'longName')
    ..aOS(3, _omitFieldNames ? '' : 'shortName')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'macaddr', $pb.PbFieldType.OY)
    ..aE<HardwareModel>(5, _omitFieldNames ? '' : 'hwModel',
        enumValues: HardwareModel.values)
    ..aOB(6, _omitFieldNames ? '' : 'isLicensed')
    ..aE<Config_DeviceConfig_Role>(7, _omitFieldNames ? '' : 'role',
        enumValues: Config_DeviceConfig_Role.values)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
    ..aOB(9, _omitFieldNames ? '' : 'isUnmessagable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) =>
      super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  @$core.override
  User createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static User getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

  /// Unique ID (8 hex chars)
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Long name
  @$pb.TagNumber(2)
  $core.String get longName => $_getSZ(1);
  @$pb.TagNumber(2)
  set longName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLongName() => $_has(1);
  @$pb.TagNumber(2)
  void clearLongName() => $_clearField(2);

  /// Short name (max 4 chars)
  @$pb.TagNumber(3)
  $core.String get shortName => $_getSZ(2);
  @$pb.TagNumber(3)
  set shortName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShortName() => $_has(2);
  @$pb.TagNumber(3)
  void clearShortName() => $_clearField(3);

  /// MAC address (6 bytes) - deprecated but still sent
  @$pb.TagNumber(4)
  $core.List<$core.int> get macaddr => $_getN(3);
  @$pb.TagNumber(4)
  set macaddr($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMacaddr() => $_has(3);
  @$pb.TagNumber(4)
  void clearMacaddr() => $_clearField(4);

  /// Hardware model
  @$pb.TagNumber(5)
  HardwareModel get hwModel => $_getN(4);
  @$pb.TagNumber(5)
  set hwModel(HardwareModel value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasHwModel() => $_has(4);
  @$pb.TagNumber(5)
  void clearHwModel() => $_clearField(5);

  /// Licensed ham operator
  @$pb.TagNumber(6)
  $core.bool get isLicensed => $_getBF(5);
  @$pb.TagNumber(6)
  set isLicensed($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsLicensed() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsLicensed() => $_clearField(6);

  /// User's role
  @$pb.TagNumber(7)
  Config_DeviceConfig_Role get role => $_getN(6);
  @$pb.TagNumber(7)
  set role(Config_DeviceConfig_Role value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRole() => $_has(6);
  @$pb.TagNumber(7)
  void clearRole() => $_clearField(7);

  /// Public key for encryption (32 bytes)
  @$pb.TagNumber(8)
  $core.List<$core.int> get publicKey => $_getN(7);
  @$pb.TagNumber(8)
  set publicKey($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPublicKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearPublicKey() => $_clearField(8);

  /// Whether the node can be messaged
  @$pb.TagNumber(9)
  $core.bool get isUnmessagable => $_getBF(8);
  @$pb.TagNumber(9)
  set isUnmessagable($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsUnmessagable() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsUnmessagable() => $_clearField(9);
}

/// Route discovery information
class RouteDiscovery extends $pb.GeneratedMessage {
  factory RouteDiscovery({
    $core.Iterable<$core.int>? route,
  }) {
    final result = create();
    if (route != null) result.route.addAll(route);
    return result;
  }

  RouteDiscovery._();

  factory RouteDiscovery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RouteDiscovery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RouteDiscovery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'route', $pb.PbFieldType.KF3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RouteDiscovery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RouteDiscovery copyWith(void Function(RouteDiscovery) updates) =>
      super.copyWith((message) => updates(message as RouteDiscovery))
          as RouteDiscovery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RouteDiscovery create() => RouteDiscovery._();
  @$core.override
  RouteDiscovery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RouteDiscovery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RouteDiscovery>(create);
  static RouteDiscovery? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get route => $_getList(0);
}

/// Data payload
class Data extends $pb.GeneratedMessage {
  factory Data({
    PortNum? portnum,
    $core.List<$core.int>? payload,
    $core.bool? wantResponse,
    $core.int? dest,
    $core.int? source,
    $core.int? requestId,
    $core.int? replyId,
    $core.int? emoji,
  }) {
    final result = create();
    if (portnum != null) result.portnum = portnum;
    if (payload != null) result.payload = payload;
    if (wantResponse != null) result.wantResponse = wantResponse;
    if (dest != null) result.dest = dest;
    if (source != null) result.source = source;
    if (requestId != null) result.requestId = requestId;
    if (replyId != null) result.replyId = replyId;
    if (emoji != null) result.emoji = emoji;
    return result;
  }

  Data._();

  factory Data.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Data.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Data',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aE<PortNum>(1, _omitFieldNames ? '' : 'portnum',
        enumValues: PortNum.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOB(3, _omitFieldNames ? '' : 'wantResponse')
    ..aI(4, _omitFieldNames ? '' : 'dest', fieldType: $pb.PbFieldType.OF3)
    ..aI(5, _omitFieldNames ? '' : 'source', fieldType: $pb.PbFieldType.OF3)
    ..aI(6, _omitFieldNames ? '' : 'requestId', fieldType: $pb.PbFieldType.OF3)
    ..aI(7, _omitFieldNames ? '' : 'replyId', fieldType: $pb.PbFieldType.OF3)
    ..aI(8, _omitFieldNames ? '' : 'emoji', fieldType: $pb.PbFieldType.OF3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Data clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Data copyWith(void Function(Data) updates) =>
      super.copyWith((message) => updates(message as Data)) as Data;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Data create() => Data._();
  @$core.override
  Data createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Data getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Data>(create);
  static Data? _defaultInstance;

  /// The type of payload
  @$pb.TagNumber(1)
  PortNum get portnum => $_getN(0);
  @$pb.TagNumber(1)
  set portnum(PortNum value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPortnum() => $_has(0);
  @$pb.TagNumber(1)
  void clearPortnum() => $_clearField(1);

  /// Payload data
  @$pb.TagNumber(2)
  $core.List<$core.int> get payload => $_getN(1);
  @$pb.TagNumber(2)
  set payload($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPayload() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayload() => $_clearField(2);

  /// If true, request a receipt/ACK
  @$pb.TagNumber(3)
  $core.bool get wantResponse => $_getBF(2);
  @$pb.TagNumber(3)
  set wantResponse($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWantResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearWantResponse() => $_clearField(3);

  /// Destination for replies
  @$pb.TagNumber(4)
  $core.int get dest => $_getIZ(3);
  @$pb.TagNumber(4)
  set dest($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDest() => $_has(3);
  @$pb.TagNumber(4)
  void clearDest() => $_clearField(4);

  /// Source of the message
  @$pb.TagNumber(5)
  $core.int get source => $_getIZ(4);
  @$pb.TagNumber(5)
  set source($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSource() => $_has(4);
  @$pb.TagNumber(5)
  void clearSource() => $_clearField(5);

  /// Request ID for tracking
  @$pb.TagNumber(6)
  $core.int get requestId => $_getIZ(5);
  @$pb.TagNumber(6)
  set requestId($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRequestId() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestId() => $_clearField(6);

  /// For responses
  @$pb.TagNumber(7)
  $core.int get replyId => $_getIZ(6);
  @$pb.TagNumber(7)
  set replyId($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReplyId() => $_has(6);
  @$pb.TagNumber(7)
  void clearReplyId() => $_clearField(7);

  /// For emoji reactions
  @$pb.TagNumber(8)
  $core.int get emoji => $_getIZ(7);
  @$pb.TagNumber(8)
  set emoji($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEmoji() => $_has(7);
  @$pb.TagNumber(8)
  void clearEmoji() => $_clearField(8);
}

enum MeshPacket_PayloadVariant { decoded, encrypted, notSet }

/// Mesh packet
class MeshPacket extends $pb.GeneratedMessage {
  factory MeshPacket({
    $core.int? from,
    $core.int? to,
    $core.int? channel,
    Data? decoded,
    $core.List<$core.int>? encrypted,
    $core.int? id,
    $core.int? rxTime,
    $core.double? rxSnr,
    $core.int? hopLimit,
    $core.bool? wantAck,
    $core.int? priority,
    $core.int? delayed,
  }) {
    final result = create();
    if (from != null) result.from = from;
    if (to != null) result.to = to;
    if (channel != null) result.channel = channel;
    if (decoded != null) result.decoded = decoded;
    if (encrypted != null) result.encrypted = encrypted;
    if (id != null) result.id = id;
    if (rxTime != null) result.rxTime = rxTime;
    if (rxSnr != null) result.rxSnr = rxSnr;
    if (hopLimit != null) result.hopLimit = hopLimit;
    if (wantAck != null) result.wantAck = wantAck;
    if (priority != null) result.priority = priority;
    if (delayed != null) result.delayed = delayed;
    return result;
  }

  MeshPacket._();

  factory MeshPacket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MeshPacket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MeshPacket_PayloadVariant>
      _MeshPacket_PayloadVariantByTag = {
    4: MeshPacket_PayloadVariant.decoded,
    5: MeshPacket_PayloadVariant.encrypted,
    0: MeshPacket_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MeshPacket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [4, 5])
    ..aI(1, _omitFieldNames ? '' : 'from', fieldType: $pb.PbFieldType.OF3)
    ..aI(2, _omitFieldNames ? '' : 'to', fieldType: $pb.PbFieldType.OF3)
    ..aI(3, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aOM<Data>(4, _omitFieldNames ? '' : 'decoded', subBuilder: Data.create)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'encrypted', $pb.PbFieldType.OY)
    ..aI(6, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OF3)
    ..aI(7, _omitFieldNames ? '' : 'rxTime', fieldType: $pb.PbFieldType.OF3)
    ..aD(8, _omitFieldNames ? '' : 'rxSnr', fieldType: $pb.PbFieldType.OF)
    ..aI(9, _omitFieldNames ? '' : 'hopLimit', fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'wantAck')
    ..aI(11, _omitFieldNames ? '' : 'priority', fieldType: $pb.PbFieldType.OU3)
    ..aI(12, _omitFieldNames ? '' : 'delayed', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshPacket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshPacket copyWith(void Function(MeshPacket) updates) =>
      super.copyWith((message) => updates(message as MeshPacket)) as MeshPacket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MeshPacket create() => MeshPacket._();
  @$core.override
  MeshPacket createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MeshPacket getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MeshPacket>(create);
  static MeshPacket? _defaultInstance;

  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  MeshPacket_PayloadVariant whichPayloadVariant() =>
      _MeshPacket_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Sender
  @$pb.TagNumber(1)
  $core.int get from => $_getIZ(0);
  @$pb.TagNumber(1)
  set from($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFrom() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrom() => $_clearField(1);

  /// Destination (0 = broadcast)
  @$pb.TagNumber(2)
  $core.int get to => $_getIZ(1);
  @$pb.TagNumber(2)
  set to($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTo() => $_has(1);
  @$pb.TagNumber(2)
  void clearTo() => $_clearField(2);

  /// Channel index
  @$pb.TagNumber(3)
  $core.int get channel => $_getIZ(2);
  @$pb.TagNumber(3)
  set channel($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChannel() => $_has(2);
  @$pb.TagNumber(3)
  void clearChannel() => $_clearField(3);

  @$pb.TagNumber(4)
  Data get decoded => $_getN(3);
  @$pb.TagNumber(4)
  set decoded(Data value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDecoded() => $_has(3);
  @$pb.TagNumber(4)
  void clearDecoded() => $_clearField(4);
  @$pb.TagNumber(4)
  Data ensureDecoded() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.List<$core.int> get encrypted => $_getN(4);
  @$pb.TagNumber(5)
  set encrypted($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEncrypted() => $_has(4);
  @$pb.TagNumber(5)
  void clearEncrypted() => $_clearField(5);

  /// Unique packet ID
  @$pb.TagNumber(6)
  $core.int get id => $_getIZ(5);
  @$pb.TagNumber(6)
  set id($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasId() => $_has(5);
  @$pb.TagNumber(6)
  void clearId() => $_clearField(6);

  /// Time received (local, not from packet)
  @$pb.TagNumber(7)
  $core.int get rxTime => $_getIZ(6);
  @$pb.TagNumber(7)
  set rxTime($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRxTime() => $_has(6);
  @$pb.TagNumber(7)
  void clearRxTime() => $_clearField(7);

  /// SNR of received packet
  @$pb.TagNumber(8)
  $core.double get rxSnr => $_getN(7);
  @$pb.TagNumber(8)
  set rxSnr($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRxSnr() => $_has(7);
  @$pb.TagNumber(8)
  void clearRxSnr() => $_clearField(8);

  /// Number of hops
  @$pb.TagNumber(9)
  $core.int get hopLimit => $_getIZ(8);
  @$pb.TagNumber(9)
  set hopLimit($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHopLimit() => $_has(8);
  @$pb.TagNumber(9)
  void clearHopLimit() => $_clearField(9);

  /// For prioritization
  @$pb.TagNumber(10)
  $core.bool get wantAck => $_getBF(9);
  @$pb.TagNumber(10)
  set wantAck($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasWantAck() => $_has(9);
  @$pb.TagNumber(10)
  void clearWantAck() => $_clearField(10);

  /// Priority level
  @$pb.TagNumber(11)
  $core.int get priority => $_getIZ(10);
  @$pb.TagNumber(11)
  set priority($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPriority() => $_has(10);
  @$pb.TagNumber(11)
  void clearPriority() => $_clearField(11);

  /// Delayed broadcast seconds
  @$pb.TagNumber(12)
  $core.int get delayed => $_getIZ(11);
  @$pb.TagNumber(12)
  set delayed($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDelayed() => $_has(11);
  @$pb.TagNumber(12)
  void clearDelayed() => $_clearField(12);
}

/// Node information
class NodeInfo extends $pb.GeneratedMessage {
  factory NodeInfo({
    $core.int? num,
    User? user,
    Position? position,
    $core.double? snr,
    $core.int? lastHeard,
    DeviceMetrics? deviceMetrics,
  }) {
    final result = create();
    if (num != null) result.num = num;
    if (user != null) result.user = user;
    if (position != null) result.position = position;
    if (snr != null) result.snr = snr;
    if (lastHeard != null) result.lastHeard = lastHeard;
    if (deviceMetrics != null) result.deviceMetrics = deviceMetrics;
    return result;
  }

  NodeInfo._();

  factory NodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'num', fieldType: $pb.PbFieldType.OU3)
    ..aOM<User>(2, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..aOM<Position>(3, _omitFieldNames ? '' : 'position',
        subBuilder: Position.create)
    ..aD(4, _omitFieldNames ? '' : 'snr', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'lastHeard', fieldType: $pb.PbFieldType.OF3)
    ..aOM<DeviceMetrics>(6, _omitFieldNames ? '' : 'deviceMetrics',
        subBuilder: DeviceMetrics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeInfo copyWith(void Function(NodeInfo) updates) =>
      super.copyWith((message) => updates(message as NodeInfo)) as NodeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeInfo create() => NodeInfo._();
  @$core.override
  NodeInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeInfo>(create);
  static NodeInfo? _defaultInstance;

  /// Node number
  @$pb.TagNumber(1)
  $core.int get num => $_getIZ(0);
  @$pb.TagNumber(1)
  set num($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearNum() => $_clearField(1);

  /// User info
  @$pb.TagNumber(2)
  User get user => $_getN(1);
  @$pb.TagNumber(2)
  set user(User value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearUser() => $_clearField(2);
  @$pb.TagNumber(2)
  User ensureUser() => $_ensure(1);

  /// Position
  @$pb.TagNumber(3)
  Position get position => $_getN(2);
  @$pb.TagNumber(3)
  set position(Position value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearPosition() => $_clearField(3);
  @$pb.TagNumber(3)
  Position ensurePosition() => $_ensure(2);

  /// SNR of last received packet
  @$pb.TagNumber(4)
  $core.double get snr => $_getN(3);
  @$pb.TagNumber(4)
  set snr($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSnr() => $_has(3);
  @$pb.TagNumber(4)
  void clearSnr() => $_clearField(4);

  /// Last heard timestamp
  @$pb.TagNumber(5)
  $core.int get lastHeard => $_getIZ(4);
  @$pb.TagNumber(5)
  set lastHeard($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastHeard() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastHeard() => $_clearField(5);

  /// Device metrics
  @$pb.TagNumber(6)
  DeviceMetrics get deviceMetrics => $_getN(5);
  @$pb.TagNumber(6)
  set deviceMetrics(DeviceMetrics value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDeviceMetrics() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceMetrics() => $_clearField(6);
  @$pb.TagNumber(6)
  DeviceMetrics ensureDeviceMetrics() => $_ensure(5);
}

/// Device telemetry
class DeviceMetrics extends $pb.GeneratedMessage {
  factory DeviceMetrics({
    $core.int? batteryLevel,
    $core.double? voltage,
    $core.double? channelUtilization,
    $core.double? airUtilTx,
    $core.int? uptimeSeconds,
  }) {
    final result = create();
    if (batteryLevel != null) result.batteryLevel = batteryLevel;
    if (voltage != null) result.voltage = voltage;
    if (channelUtilization != null)
      result.channelUtilization = channelUtilization;
    if (airUtilTx != null) result.airUtilTx = airUtilTx;
    if (uptimeSeconds != null) result.uptimeSeconds = uptimeSeconds;
    return result;
  }

  DeviceMetrics._();

  factory DeviceMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceMetrics',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'batteryLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(2, _omitFieldNames ? '' : 'voltage', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'channelUtilization',
        fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'airUtilTx', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'uptimeSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMetrics copyWith(void Function(DeviceMetrics) updates) =>
      super.copyWith((message) => updates(message as DeviceMetrics))
          as DeviceMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceMetrics create() => DeviceMetrics._();
  @$core.override
  DeviceMetrics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceMetrics>(create);
  static DeviceMetrics? _defaultInstance;

  /// Battery level 0-100
  @$pb.TagNumber(1)
  $core.int get batteryLevel => $_getIZ(0);
  @$pb.TagNumber(1)
  set batteryLevel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatteryLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatteryLevel() => $_clearField(1);

  /// Voltage in millivolts
  @$pb.TagNumber(2)
  $core.double get voltage => $_getN(1);
  @$pb.TagNumber(2)
  set voltage($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVoltage() => $_has(1);
  @$pb.TagNumber(2)
  void clearVoltage() => $_clearField(2);

  /// Channel utilization
  @$pb.TagNumber(3)
  $core.double get channelUtilization => $_getN(2);
  @$pb.TagNumber(3)
  set channelUtilization($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChannelUtilization() => $_has(2);
  @$pb.TagNumber(3)
  void clearChannelUtilization() => $_clearField(3);

  /// Air utilization TX
  @$pb.TagNumber(4)
  $core.double get airUtilTx => $_getN(3);
  @$pb.TagNumber(4)
  set airUtilTx($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAirUtilTx() => $_has(3);
  @$pb.TagNumber(4)
  void clearAirUtilTx() => $_clearField(4);

  /// Uptime in seconds
  @$pb.TagNumber(5)
  $core.int get uptimeSeconds => $_getIZ(4);
  @$pb.TagNumber(5)
  set uptimeSeconds($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUptimeSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearUptimeSeconds() => $_clearField(5);
}

/// My node information
class MyNodeInfo extends $pb.GeneratedMessage {
  factory MyNodeInfo({
    $core.int? myNodeNum,
    $core.int? rebootCount,
    $core.int? minAppVersion,
    $core.List<$core.int>? deviceId,
    $core.String? pioEnv,
    $core.String? firmwareEdition,
    $core.int? nodedbCount,
  }) {
    final result = create();
    if (myNodeNum != null) result.myNodeNum = myNodeNum;
    if (rebootCount != null) result.rebootCount = rebootCount;
    if (minAppVersion != null) result.minAppVersion = minAppVersion;
    if (deviceId != null) result.deviceId = deviceId;
    if (pioEnv != null) result.pioEnv = pioEnv;
    if (firmwareEdition != null) result.firmwareEdition = firmwareEdition;
    if (nodedbCount != null) result.nodedbCount = nodedbCount;
    return result;
  }

  MyNodeInfo._();

  factory MyNodeInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MyNodeInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MyNodeInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'myNodeNum', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'rebootCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'minAppVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        12, _omitFieldNames ? '' : 'deviceId', $pb.PbFieldType.OY)
    ..aOS(13, _omitFieldNames ? '' : 'pioEnv')
    ..aOS(14, _omitFieldNames ? '' : 'firmwareEdition')
    ..aI(15, _omitFieldNames ? '' : 'nodedbCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyNodeInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MyNodeInfo copyWith(void Function(MyNodeInfo) updates) =>
      super.copyWith((message) => updates(message as MyNodeInfo)) as MyNodeInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MyNodeInfo create() => MyNodeInfo._();
  @$core.override
  MyNodeInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MyNodeInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MyNodeInfo>(create);
  static MyNodeInfo? _defaultInstance;

  /// The node number assigned to this node (unique on mesh)
  @$pb.TagNumber(1)
  $core.int get myNodeNum => $_getIZ(0);
  @$pb.TagNumber(1)
  set myNodeNum($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMyNodeNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearMyNodeNum() => $_clearField(1);

  /// The total number of reboots this node has ever encountered (wraps at MAXINT)
  @$pb.TagNumber(8)
  $core.int get rebootCount => $_getIZ(1);
  @$pb.TagNumber(8)
  set rebootCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(8)
  $core.bool hasRebootCount() => $_has(1);
  @$pb.TagNumber(8)
  void clearRebootCount() => $_clearField(8);

  /// The minimum app version that can talk to this device
  @$pb.TagNumber(11)
  $core.int get minAppVersion => $_getIZ(2);
  @$pb.TagNumber(11)
  set minAppVersion($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(11)
  $core.bool hasMinAppVersion() => $_has(2);
  @$pb.TagNumber(11)
  void clearMinAppVersion() => $_clearField(11);

  /// Unique hardware identifier for this device
  @$pb.TagNumber(12)
  $core.List<$core.int> get deviceId => $_getN(3);
  @$pb.TagNumber(12)
  set deviceId($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(12)
  $core.bool hasDeviceId() => $_has(3);
  @$pb.TagNumber(12)
  void clearDeviceId() => $_clearField(12);

  /// The PlatformIO build environment used
  @$pb.TagNumber(13)
  $core.String get pioEnv => $_getSZ(4);
  @$pb.TagNumber(13)
  set pioEnv($core.String value) => $_setString(4, value);
  @$pb.TagNumber(13)
  $core.bool hasPioEnv() => $_has(4);
  @$pb.TagNumber(13)
  void clearPioEnv() => $_clearField(13);

  /// Firmware edition (e.g. tracker, tcxo, etc.)
  @$pb.TagNumber(14)
  $core.String get firmwareEdition => $_getSZ(5);
  @$pb.TagNumber(14)
  set firmwareEdition($core.String value) => $_setString(5, value);
  @$pb.TagNumber(14)
  $core.bool hasFirmwareEdition() => $_has(5);
  @$pb.TagNumber(14)
  void clearFirmwareEdition() => $_clearField(14);

  /// Number of entries in the local node DB
  @$pb.TagNumber(15)
  $core.int get nodedbCount => $_getIZ(6);
  @$pb.TagNumber(15)
  set nodedbCount($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(15)
  $core.bool hasNodedbCount() => $_has(6);
  @$pb.TagNumber(15)
  void clearNodedbCount() => $_clearField(15);
}

/// Channel configuration
class Channel extends $pb.GeneratedMessage {
  factory Channel({
    $core.int? index,
    ChannelSettings? settings,
    Channel_Role? role,
  }) {
    final result = create();
    if (index != null) result.index = index;
    if (settings != null) result.settings = settings;
    if (role != null) result.role = role;
    return result;
  }

  Channel._();

  factory Channel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Channel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Channel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'index')
    ..aOM<ChannelSettings>(2, _omitFieldNames ? '' : 'settings',
        subBuilder: ChannelSettings.create)
    ..aE<Channel_Role>(3, _omitFieldNames ? '' : 'role',
        enumValues: Channel_Role.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Channel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Channel copyWith(void Function(Channel) updates) =>
      super.copyWith((message) => updates(message as Channel)) as Channel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Channel create() => Channel._();
  @$core.override
  Channel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Channel getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Channel>(create);
  static Channel? _defaultInstance;

  /// Channel index
  @$pb.TagNumber(1)
  $core.int get index => $_getIZ(0);
  @$pb.TagNumber(1)
  set index($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearIndex() => $_clearField(1);

  /// Channel settings
  @$pb.TagNumber(2)
  ChannelSettings get settings => $_getN(1);
  @$pb.TagNumber(2)
  set settings(ChannelSettings value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSettings() => $_has(1);
  @$pb.TagNumber(2)
  void clearSettings() => $_clearField(2);
  @$pb.TagNumber(2)
  ChannelSettings ensureSettings() => $_ensure(1);

  /// Role
  @$pb.TagNumber(3)
  Channel_Role get role => $_getN(2);
  @$pb.TagNumber(3)
  set role(Channel_Role value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => $_clearField(3);
}

/// Channel settings
class ChannelSettings extends $pb.GeneratedMessage {
  factory ChannelSettings({
    $core.int? channelNum,
    $core.List<$core.int>? psk,
    $core.String? name,
    $core.int? id,
    $core.bool? uplinkEnabled,
    $core.bool? downlinkEnabled,
    ModuleSettings? moduleSettings,
  }) {
    final result = create();
    if (channelNum != null) result.channelNum = channelNum;
    if (psk != null) result.psk = psk;
    if (name != null) result.name = name;
    if (id != null) result.id = id;
    if (uplinkEnabled != null) result.uplinkEnabled = uplinkEnabled;
    if (downlinkEnabled != null) result.downlinkEnabled = downlinkEnabled;
    if (moduleSettings != null) result.moduleSettings = moduleSettings;
    return result;
  }

  ChannelSettings._();

  factory ChannelSettings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChannelSettings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelSettings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'channelNum', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'psk', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OF3)
    ..aOB(5, _omitFieldNames ? '' : 'uplinkEnabled')
    ..aOB(6, _omitFieldNames ? '' : 'downlinkEnabled')
    ..aOM<ModuleSettings>(7, _omitFieldNames ? '' : 'moduleSettings',
        subBuilder: ModuleSettings.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelSettings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelSettings copyWith(void Function(ChannelSettings) updates) =>
      super.copyWith((message) => updates(message as ChannelSettings))
          as ChannelSettings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChannelSettings create() => ChannelSettings._();
  @$core.override
  ChannelSettings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChannelSettings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelSettings>(create);
  static ChannelSettings? _defaultInstance;

  /// Deprecated channel_num
  @$pb.TagNumber(1)
  $core.int get channelNum => $_getIZ(0);
  @$pb.TagNumber(1)
  set channelNum($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChannelNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannelNum() => $_clearField(1);

  /// Pre-shared key (up to 256 bits)
  @$pb.TagNumber(2)
  $core.List<$core.int> get psk => $_getN(1);
  @$pb.TagNumber(2)
  set psk($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPsk() => $_has(1);
  @$pb.TagNumber(2)
  void clearPsk() => $_clearField(2);

  /// Channel name
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// Unique channel ID
  @$pb.TagNumber(4)
  $core.int get id => $_getIZ(3);
  @$pb.TagNumber(4)
  set id($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasId() => $_has(3);
  @$pb.TagNumber(4)
  void clearId() => $_clearField(4);

  /// Uplink enabled
  @$pb.TagNumber(5)
  $core.bool get uplinkEnabled => $_getBF(4);
  @$pb.TagNumber(5)
  set uplinkEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUplinkEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearUplinkEnabled() => $_clearField(5);

  /// Downlink enabled
  @$pb.TagNumber(6)
  $core.bool get downlinkEnabled => $_getBF(5);
  @$pb.TagNumber(6)
  set downlinkEnabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDownlinkEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearDownlinkEnabled() => $_clearField(6);

  /// Module settings
  @$pb.TagNumber(7)
  ModuleSettings get moduleSettings => $_getN(6);
  @$pb.TagNumber(7)
  set moduleSettings(ModuleSettings value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasModuleSettings() => $_has(6);
  @$pb.TagNumber(7)
  void clearModuleSettings() => $_clearField(7);
  @$pb.TagNumber(7)
  ModuleSettings ensureModuleSettings() => $_ensure(6);
}

/// Module settings for channels
class ModuleSettings extends $pb.GeneratedMessage {
  factory ModuleSettings({
    $core.int? positionPrecision,
    $core.bool? isMuted,
  }) {
    final result = create();
    if (positionPrecision != null) result.positionPrecision = positionPrecision;
    if (isMuted != null) result.isMuted = isMuted;
    return result;
  }

  ModuleSettings._();

  factory ModuleSettings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleSettings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleSettings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'positionPrecision',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'isMuted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleSettings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleSettings copyWith(void Function(ModuleSettings) updates) =>
      super.copyWith((message) => updates(message as ModuleSettings))
          as ModuleSettings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleSettings create() => ModuleSettings._();
  @$core.override
  ModuleSettings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleSettings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleSettings>(create);
  static ModuleSettings? _defaultInstance;

  /// Position precision bits
  @$pb.TagNumber(1)
  $core.int get positionPrecision => $_getIZ(0);
  @$pb.TagNumber(1)
  set positionPrecision($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPositionPrecision() => $_has(0);
  @$pb.TagNumber(1)
  void clearPositionPrecision() => $_clearField(1);

  /// Mute channel
  @$pb.TagNumber(2)
  $core.bool get isMuted => $_getBF(1);
  @$pb.TagNumber(2)
  set isMuted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsMuted() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsMuted() => $_clearField(2);
}

enum AdminMessage_PayloadVariant {
  getChannelRequest,
  getChannelResponse,
  getOwnerRequest,
  getOwnerResponse,
  getConfigRequest,
  getConfigResponse,
  getModuleConfigRequest,
  getModuleConfigResponse,
  setOwner,
  setChannel,
  setConfig,
  setModuleConfig,
  beginEditSettings,
  commitEditSettings,
  rebootSeconds,
  shutdownSeconds,
  factoryResetConfig,
  nodedbReset,
  notSet
}

/// Configuration requests
class AdminMessage extends $pb.GeneratedMessage {
  factory AdminMessage({
    $core.int? getChannelRequest,
    Channel? getChannelResponse,
    $core.bool? getOwnerRequest,
    User? getOwnerResponse,
    $core.int? getConfigRequest,
    Config? getConfigResponse,
    $core.int? getModuleConfigRequest,
    ModuleConfig? getModuleConfigResponse,
    User? setOwner,
    Channel? setChannel,
    Config? setConfig,
    ModuleConfig? setModuleConfig,
    $core.bool? beginEditSettings,
    $core.bool? commitEditSettings,
    $core.int? rebootSeconds,
    $core.int? shutdownSeconds,
    $core.int? factoryResetConfig,
    $core.bool? nodedbReset,
  }) {
    final result = create();
    if (getChannelRequest != null) result.getChannelRequest = getChannelRequest;
    if (getChannelResponse != null)
      result.getChannelResponse = getChannelResponse;
    if (getOwnerRequest != null) result.getOwnerRequest = getOwnerRequest;
    if (getOwnerResponse != null) result.getOwnerResponse = getOwnerResponse;
    if (getConfigRequest != null) result.getConfigRequest = getConfigRequest;
    if (getConfigResponse != null) result.getConfigResponse = getConfigResponse;
    if (getModuleConfigRequest != null)
      result.getModuleConfigRequest = getModuleConfigRequest;
    if (getModuleConfigResponse != null)
      result.getModuleConfigResponse = getModuleConfigResponse;
    if (setOwner != null) result.setOwner = setOwner;
    if (setChannel != null) result.setChannel = setChannel;
    if (setConfig != null) result.setConfig = setConfig;
    if (setModuleConfig != null) result.setModuleConfig = setModuleConfig;
    if (beginEditSettings != null) result.beginEditSettings = beginEditSettings;
    if (commitEditSettings != null)
      result.commitEditSettings = commitEditSettings;
    if (rebootSeconds != null) result.rebootSeconds = rebootSeconds;
    if (shutdownSeconds != null) result.shutdownSeconds = shutdownSeconds;
    if (factoryResetConfig != null)
      result.factoryResetConfig = factoryResetConfig;
    if (nodedbReset != null) result.nodedbReset = nodedbReset;
    return result;
  }

  AdminMessage._();

  factory AdminMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AdminMessage_PayloadVariant>
      _AdminMessage_PayloadVariantByTag = {
    1: AdminMessage_PayloadVariant.getChannelRequest,
    2: AdminMessage_PayloadVariant.getChannelResponse,
    3: AdminMessage_PayloadVariant.getOwnerRequest,
    4: AdminMessage_PayloadVariant.getOwnerResponse,
    5: AdminMessage_PayloadVariant.getConfigRequest,
    6: AdminMessage_PayloadVariant.getConfigResponse,
    7: AdminMessage_PayloadVariant.getModuleConfigRequest,
    8: AdminMessage_PayloadVariant.getModuleConfigResponse,
    32: AdminMessage_PayloadVariant.setOwner,
    33: AdminMessage_PayloadVariant.setChannel,
    34: AdminMessage_PayloadVariant.setConfig,
    35: AdminMessage_PayloadVariant.setModuleConfig,
    64: AdminMessage_PayloadVariant.beginEditSettings,
    65: AdminMessage_PayloadVariant.commitEditSettings,
    97: AdminMessage_PayloadVariant.rebootSeconds,
    98: AdminMessage_PayloadVariant.shutdownSeconds,
    99: AdminMessage_PayloadVariant.factoryResetConfig,
    100: AdminMessage_PayloadVariant.nodedbReset,
    0: AdminMessage_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 32, 33, 34, 35, 64, 65, 97, 98, 99, 100])
    ..aI(1, _omitFieldNames ? '' : 'getChannelRequest',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Channel>(2, _omitFieldNames ? '' : 'getChannelResponse',
        subBuilder: Channel.create)
    ..aOB(3, _omitFieldNames ? '' : 'getOwnerRequest')
    ..aOM<User>(4, _omitFieldNames ? '' : 'getOwnerResponse',
        subBuilder: User.create)
    ..aI(5, _omitFieldNames ? '' : 'getConfigRequest',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Config>(6, _omitFieldNames ? '' : 'getConfigResponse',
        subBuilder: Config.create)
    ..aI(7, _omitFieldNames ? '' : 'getModuleConfigRequest',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<ModuleConfig>(8, _omitFieldNames ? '' : 'getModuleConfigResponse',
        subBuilder: ModuleConfig.create)
    ..aOM<User>(32, _omitFieldNames ? '' : 'setOwner', subBuilder: User.create)
    ..aOM<Channel>(33, _omitFieldNames ? '' : 'setChannel',
        subBuilder: Channel.create)
    ..aOM<Config>(34, _omitFieldNames ? '' : 'setConfig',
        subBuilder: Config.create)
    ..aOM<ModuleConfig>(35, _omitFieldNames ? '' : 'setModuleConfig',
        subBuilder: ModuleConfig.create)
    ..aOB(64, _omitFieldNames ? '' : 'beginEditSettings')
    ..aOB(65, _omitFieldNames ? '' : 'commitEditSettings')
    ..aI(97, _omitFieldNames ? '' : 'rebootSeconds')
    ..aI(98, _omitFieldNames ? '' : 'shutdownSeconds')
    ..aI(99, _omitFieldNames ? '' : 'factoryResetConfig')
    ..aOB(100, _omitFieldNames ? '' : 'nodedbReset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminMessage copyWith(void Function(AdminMessage) updates) =>
      super.copyWith((message) => updates(message as AdminMessage))
          as AdminMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminMessage create() => AdminMessage._();
  @$core.override
  AdminMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminMessage>(create);
  static AdminMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(64)
  @$pb.TagNumber(65)
  @$pb.TagNumber(97)
  @$pb.TagNumber(98)
  @$pb.TagNumber(99)
  @$pb.TagNumber(100)
  AdminMessage_PayloadVariant whichPayloadVariant() =>
      _AdminMessage_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(64)
  @$pb.TagNumber(65)
  @$pb.TagNumber(97)
  @$pb.TagNumber(98)
  @$pb.TagNumber(99)
  @$pb.TagNumber(100)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Get channel request (index + 1, so 0 is never sent)
  @$pb.TagNumber(1)
  $core.int get getChannelRequest => $_getIZ(0);
  @$pb.TagNumber(1)
  set getChannelRequest($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGetChannelRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearGetChannelRequest() => $_clearField(1);

  /// Get channel response
  @$pb.TagNumber(2)
  Channel get getChannelResponse => $_getN(1);
  @$pb.TagNumber(2)
  set getChannelResponse(Channel value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasGetChannelResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearGetChannelResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  Channel ensureGetChannelResponse() => $_ensure(1);

  /// Get owner request
  @$pb.TagNumber(3)
  $core.bool get getOwnerRequest => $_getBF(2);
  @$pb.TagNumber(3)
  set getOwnerRequest($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGetOwnerRequest() => $_has(2);
  @$pb.TagNumber(3)
  void clearGetOwnerRequest() => $_clearField(3);

  /// Get owner response
  @$pb.TagNumber(4)
  User get getOwnerResponse => $_getN(3);
  @$pb.TagNumber(4)
  set getOwnerResponse(User value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGetOwnerResponse() => $_has(3);
  @$pb.TagNumber(4)
  void clearGetOwnerResponse() => $_clearField(4);
  @$pb.TagNumber(4)
  User ensureGetOwnerResponse() => $_ensure(3);

  /// Get config request
  @$pb.TagNumber(5)
  $core.int get getConfigRequest => $_getIZ(4);
  @$pb.TagNumber(5)
  set getConfigRequest($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGetConfigRequest() => $_has(4);
  @$pb.TagNumber(5)
  void clearGetConfigRequest() => $_clearField(5);

  /// Get config response
  @$pb.TagNumber(6)
  Config get getConfigResponse => $_getN(5);
  @$pb.TagNumber(6)
  set getConfigResponse(Config value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasGetConfigResponse() => $_has(5);
  @$pb.TagNumber(6)
  void clearGetConfigResponse() => $_clearField(6);
  @$pb.TagNumber(6)
  Config ensureGetConfigResponse() => $_ensure(5);

  /// Get module config request
  @$pb.TagNumber(7)
  $core.int get getModuleConfigRequest => $_getIZ(6);
  @$pb.TagNumber(7)
  set getModuleConfigRequest($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGetModuleConfigRequest() => $_has(6);
  @$pb.TagNumber(7)
  void clearGetModuleConfigRequest() => $_clearField(7);

  /// Get module config response
  @$pb.TagNumber(8)
  ModuleConfig get getModuleConfigResponse => $_getN(7);
  @$pb.TagNumber(8)
  set getModuleConfigResponse(ModuleConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasGetModuleConfigResponse() => $_has(7);
  @$pb.TagNumber(8)
  void clearGetModuleConfigResponse() => $_clearField(8);
  @$pb.TagNumber(8)
  ModuleConfig ensureGetModuleConfigResponse() => $_ensure(7);

  /// Set owner
  @$pb.TagNumber(32)
  User get setOwner => $_getN(8);
  @$pb.TagNumber(32)
  set setOwner(User value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasSetOwner() => $_has(8);
  @$pb.TagNumber(32)
  void clearSetOwner() => $_clearField(32);
  @$pb.TagNumber(32)
  User ensureSetOwner() => $_ensure(8);

  /// Set channel
  @$pb.TagNumber(33)
  Channel get setChannel => $_getN(9);
  @$pb.TagNumber(33)
  set setChannel(Channel value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasSetChannel() => $_has(9);
  @$pb.TagNumber(33)
  void clearSetChannel() => $_clearField(33);
  @$pb.TagNumber(33)
  Channel ensureSetChannel() => $_ensure(9);

  /// Set config
  @$pb.TagNumber(34)
  Config get setConfig => $_getN(10);
  @$pb.TagNumber(34)
  set setConfig(Config value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasSetConfig() => $_has(10);
  @$pb.TagNumber(34)
  void clearSetConfig() => $_clearField(34);
  @$pb.TagNumber(34)
  Config ensureSetConfig() => $_ensure(10);

  /// Set module config
  @$pb.TagNumber(35)
  ModuleConfig get setModuleConfig => $_getN(11);
  @$pb.TagNumber(35)
  set setModuleConfig(ModuleConfig value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasSetModuleConfig() => $_has(11);
  @$pb.TagNumber(35)
  void clearSetModuleConfig() => $_clearField(35);
  @$pb.TagNumber(35)
  ModuleConfig ensureSetModuleConfig() => $_ensure(11);

  /// Begin edit settings transaction
  @$pb.TagNumber(64)
  $core.bool get beginEditSettings => $_getBF(12);
  @$pb.TagNumber(64)
  set beginEditSettings($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(64)
  $core.bool hasBeginEditSettings() => $_has(12);
  @$pb.TagNumber(64)
  void clearBeginEditSettings() => $_clearField(64);

  /// Commit edit settings transaction
  @$pb.TagNumber(65)
  $core.bool get commitEditSettings => $_getBF(13);
  @$pb.TagNumber(65)
  set commitEditSettings($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(65)
  $core.bool hasCommitEditSettings() => $_has(13);
  @$pb.TagNumber(65)
  void clearCommitEditSettings() => $_clearField(65);

  /// Reboot in N seconds
  @$pb.TagNumber(97)
  $core.int get rebootSeconds => $_getIZ(14);
  @$pb.TagNumber(97)
  set rebootSeconds($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(97)
  $core.bool hasRebootSeconds() => $_has(14);
  @$pb.TagNumber(97)
  void clearRebootSeconds() => $_clearField(97);

  /// Shutdown in N seconds
  @$pb.TagNumber(98)
  $core.int get shutdownSeconds => $_getIZ(15);
  @$pb.TagNumber(98)
  set shutdownSeconds($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(98)
  $core.bool hasShutdownSeconds() => $_has(15);
  @$pb.TagNumber(98)
  void clearShutdownSeconds() => $_clearField(98);

  /// Factory reset config
  @$pb.TagNumber(99)
  $core.int get factoryResetConfig => $_getIZ(16);
  @$pb.TagNumber(99)
  set factoryResetConfig($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(99)
  $core.bool hasFactoryResetConfig() => $_has(16);
  @$pb.TagNumber(99)
  void clearFactoryResetConfig() => $_clearField(99);

  /// Reset nodedb
  @$pb.TagNumber(100)
  $core.bool get nodedbReset => $_getBF(17);
  @$pb.TagNumber(100)
  set nodedbReset($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(100)
  $core.bool hasNodedbReset() => $_has(17);
  @$pb.TagNumber(100)
  void clearNodedbReset() => $_clearField(100);
}

class Config_DeviceConfig extends $pb.GeneratedMessage {
  factory Config_DeviceConfig({
    $core.String? role,
  }) {
    final result = create();
    if (role != null) result.role = role;
    return result;
  }

  Config_DeviceConfig._();

  factory Config_DeviceConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_DeviceConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.DeviceConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'role')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_DeviceConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_DeviceConfig copyWith(void Function(Config_DeviceConfig) updates) =>
      super.copyWith((message) => updates(message as Config_DeviceConfig))
          as Config_DeviceConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_DeviceConfig create() => Config_DeviceConfig._();
  @$core.override
  Config_DeviceConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_DeviceConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_DeviceConfig>(create);
  static Config_DeviceConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get role => $_getSZ(0);
  @$pb.TagNumber(1)
  set role($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearRole() => $_clearField(1);
}

class Config_PositionConfig extends $pb.GeneratedMessage {
  factory Config_PositionConfig({
    $core.bool? gpsEnabled,
  }) {
    final result = create();
    if (gpsEnabled != null) result.gpsEnabled = gpsEnabled;
    return result;
  }

  Config_PositionConfig._();

  factory Config_PositionConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_PositionConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.PositionConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'gpsEnabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_PositionConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_PositionConfig copyWith(
          void Function(Config_PositionConfig) updates) =>
      super.copyWith((message) => updates(message as Config_PositionConfig))
          as Config_PositionConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_PositionConfig create() => Config_PositionConfig._();
  @$core.override
  Config_PositionConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_PositionConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_PositionConfig>(create);
  static Config_PositionConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get gpsEnabled => $_getBF(0);
  @$pb.TagNumber(1)
  set gpsEnabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGpsEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearGpsEnabled() => $_clearField(1);
}

class Config_PowerConfig extends $pb.GeneratedMessage {
  factory Config_PowerConfig({
    $core.bool? isPowerSaving,
  }) {
    final result = create();
    if (isPowerSaving != null) result.isPowerSaving = isPowerSaving;
    return result;
  }

  Config_PowerConfig._();

  factory Config_PowerConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_PowerConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.PowerConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isPowerSaving')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_PowerConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_PowerConfig copyWith(void Function(Config_PowerConfig) updates) =>
      super.copyWith((message) => updates(message as Config_PowerConfig))
          as Config_PowerConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_PowerConfig create() => Config_PowerConfig._();
  @$core.override
  Config_PowerConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_PowerConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_PowerConfig>(create);
  static Config_PowerConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isPowerSaving => $_getBF(0);
  @$pb.TagNumber(1)
  set isPowerSaving($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsPowerSaving() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsPowerSaving() => $_clearField(1);
}

class Config_NetworkConfig extends $pb.GeneratedMessage {
  factory Config_NetworkConfig({
    $core.bool? wifiEnabled,
  }) {
    final result = create();
    if (wifiEnabled != null) result.wifiEnabled = wifiEnabled;
    return result;
  }

  Config_NetworkConfig._();

  factory Config_NetworkConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_NetworkConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.NetworkConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'wifiEnabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_NetworkConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_NetworkConfig copyWith(void Function(Config_NetworkConfig) updates) =>
      super.copyWith((message) => updates(message as Config_NetworkConfig))
          as Config_NetworkConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_NetworkConfig create() => Config_NetworkConfig._();
  @$core.override
  Config_NetworkConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_NetworkConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_NetworkConfig>(create);
  static Config_NetworkConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get wifiEnabled => $_getBF(0);
  @$pb.TagNumber(1)
  set wifiEnabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWifiEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearWifiEnabled() => $_clearField(1);
}

class Config_DisplayConfig extends $pb.GeneratedMessage {
  factory Config_DisplayConfig({
    $core.int? screenOnSecs,
  }) {
    final result = create();
    if (screenOnSecs != null) result.screenOnSecs = screenOnSecs;
    return result;
  }

  Config_DisplayConfig._();

  factory Config_DisplayConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_DisplayConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.DisplayConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'screenOnSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_DisplayConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_DisplayConfig copyWith(void Function(Config_DisplayConfig) updates) =>
      super.copyWith((message) => updates(message as Config_DisplayConfig))
          as Config_DisplayConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_DisplayConfig create() => Config_DisplayConfig._();
  @$core.override
  Config_DisplayConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_DisplayConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_DisplayConfig>(create);
  static Config_DisplayConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get screenOnSecs => $_getIZ(0);
  @$pb.TagNumber(1)
  set screenOnSecs($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScreenOnSecs() => $_has(0);
  @$pb.TagNumber(1)
  void clearScreenOnSecs() => $_clearField(1);
}

class Config_LoRaConfig extends $pb.GeneratedMessage {
  factory Config_LoRaConfig({
    $core.bool? usePreset,
    ModemPreset? modemPreset,
    $core.int? bandwidth,
    $core.int? spreadFactor,
    $core.int? codingRate,
    $core.double? frequencyOffset,
    RegionCode? region,
    $core.int? hopLimit,
    $core.bool? txEnabled,
    $core.int? txPower,
  }) {
    final result = create();
    if (usePreset != null) result.usePreset = usePreset;
    if (modemPreset != null) result.modemPreset = modemPreset;
    if (bandwidth != null) result.bandwidth = bandwidth;
    if (spreadFactor != null) result.spreadFactor = spreadFactor;
    if (codingRate != null) result.codingRate = codingRate;
    if (frequencyOffset != null) result.frequencyOffset = frequencyOffset;
    if (region != null) result.region = region;
    if (hopLimit != null) result.hopLimit = hopLimit;
    if (txEnabled != null) result.txEnabled = txEnabled;
    if (txPower != null) result.txPower = txPower;
    return result;
  }

  Config_LoRaConfig._();

  factory Config_LoRaConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_LoRaConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.LoRaConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'usePreset')
    ..aE<ModemPreset>(2, _omitFieldNames ? '' : 'modemPreset',
        enumValues: ModemPreset.values)
    ..aI(3, _omitFieldNames ? '' : 'bandwidth', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'spreadFactor',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'codingRate', fieldType: $pb.PbFieldType.OU3)
    ..aD(6, _omitFieldNames ? '' : 'frequencyOffset',
        fieldType: $pb.PbFieldType.OF)
    ..aE<RegionCode>(7, _omitFieldNames ? '' : 'region',
        enumValues: RegionCode.values)
    ..aI(8, _omitFieldNames ? '' : 'hopLimit', fieldType: $pb.PbFieldType.OU3)
    ..aOB(9, _omitFieldNames ? '' : 'txEnabled')
    ..aI(10, _omitFieldNames ? '' : 'txPower')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_LoRaConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_LoRaConfig copyWith(void Function(Config_LoRaConfig) updates) =>
      super.copyWith((message) => updates(message as Config_LoRaConfig))
          as Config_LoRaConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_LoRaConfig create() => Config_LoRaConfig._();
  @$core.override
  Config_LoRaConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_LoRaConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_LoRaConfig>(create);
  static Config_LoRaConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get usePreset => $_getBF(0);
  @$pb.TagNumber(1)
  set usePreset($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsePreset() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsePreset() => $_clearField(1);

  @$pb.TagNumber(2)
  ModemPreset get modemPreset => $_getN(1);
  @$pb.TagNumber(2)
  set modemPreset(ModemPreset value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasModemPreset() => $_has(1);
  @$pb.TagNumber(2)
  void clearModemPreset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get bandwidth => $_getIZ(2);
  @$pb.TagNumber(3)
  set bandwidth($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBandwidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearBandwidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get spreadFactor => $_getIZ(3);
  @$pb.TagNumber(4)
  set spreadFactor($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpreadFactor() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpreadFactor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get codingRate => $_getIZ(4);
  @$pb.TagNumber(5)
  set codingRate($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCodingRate() => $_has(4);
  @$pb.TagNumber(5)
  void clearCodingRate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get frequencyOffset => $_getN(5);
  @$pb.TagNumber(6)
  set frequencyOffset($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFrequencyOffset() => $_has(5);
  @$pb.TagNumber(6)
  void clearFrequencyOffset() => $_clearField(6);

  @$pb.TagNumber(7)
  RegionCode get region => $_getN(6);
  @$pb.TagNumber(7)
  set region(RegionCode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRegion() => $_has(6);
  @$pb.TagNumber(7)
  void clearRegion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get hopLimit => $_getIZ(7);
  @$pb.TagNumber(8)
  set hopLimit($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHopLimit() => $_has(7);
  @$pb.TagNumber(8)
  void clearHopLimit() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get txEnabled => $_getBF(8);
  @$pb.TagNumber(9)
  set txEnabled($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTxEnabled() => $_has(8);
  @$pb.TagNumber(9)
  void clearTxEnabled() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get txPower => $_getIZ(9);
  @$pb.TagNumber(10)
  set txPower($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTxPower() => $_has(9);
  @$pb.TagNumber(10)
  void clearTxPower() => $_clearField(10);
}

class Config_BluetoothConfig extends $pb.GeneratedMessage {
  factory Config_BluetoothConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  Config_BluetoothConfig._();

  factory Config_BluetoothConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_BluetoothConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.BluetoothConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_BluetoothConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_BluetoothConfig copyWith(
          void Function(Config_BluetoothConfig) updates) =>
      super.copyWith((message) => updates(message as Config_BluetoothConfig))
          as Config_BluetoothConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_BluetoothConfig create() => Config_BluetoothConfig._();
  @$core.override
  Config_BluetoothConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_BluetoothConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_BluetoothConfig>(create);
  static Config_BluetoothConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class Config_SecurityConfig extends $pb.GeneratedMessage {
  factory Config_SecurityConfig({
    $core.List<$core.int>? publicKey,
    $core.List<$core.int>? privateKey,
  }) {
    final result = create();
    if (publicKey != null) result.publicKey = publicKey;
    if (privateKey != null) result.privateKey = privateKey;
    return result;
  }

  Config_SecurityConfig._();

  factory Config_SecurityConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_SecurityConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.SecurityConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'privateKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_SecurityConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_SecurityConfig copyWith(
          void Function(Config_SecurityConfig) updates) =>
      super.copyWith((message) => updates(message as Config_SecurityConfig))
          as Config_SecurityConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_SecurityConfig create() => Config_SecurityConfig._();
  @$core.override
  Config_SecurityConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_SecurityConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_SecurityConfig>(create);
  static Config_SecurityConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get publicKey => $_getN(0);
  @$pb.TagNumber(1)
  set publicKey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPublicKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearPublicKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get privateKey => $_getN(1);
  @$pb.TagNumber(2)
  set privateKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPrivateKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrivateKey() => $_clearField(2);
}

enum Config_PayloadVariant {
  device,
  position,
  power,
  network,
  display,
  lora,
  bluetooth,
  security,
  notSet
}

/// Config message wrapper
class Config extends $pb.GeneratedMessage {
  factory Config({
    Config_DeviceConfig? device,
    Config_PositionConfig? position,
    Config_PowerConfig? power,
    Config_NetworkConfig? network,
    Config_DisplayConfig? display,
    Config_LoRaConfig? lora,
    Config_BluetoothConfig? bluetooth,
    Config_SecurityConfig? security,
  }) {
    final result = create();
    if (device != null) result.device = device;
    if (position != null) result.position = position;
    if (power != null) result.power = power;
    if (network != null) result.network = network;
    if (display != null) result.display = display;
    if (lora != null) result.lora = lora;
    if (bluetooth != null) result.bluetooth = bluetooth;
    if (security != null) result.security = security;
    return result;
  }

  Config._();

  factory Config.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Config_PayloadVariant>
      _Config_PayloadVariantByTag = {
    1: Config_PayloadVariant.device,
    2: Config_PayloadVariant.position,
    3: Config_PayloadVariant.power,
    4: Config_PayloadVariant.network,
    5: Config_PayloadVariant.display,
    6: Config_PayloadVariant.lora,
    7: Config_PayloadVariant.bluetooth,
    8: Config_PayloadVariant.security,
    0: Config_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
    ..aOM<Config_DeviceConfig>(1, _omitFieldNames ? '' : 'device',
        subBuilder: Config_DeviceConfig.create)
    ..aOM<Config_PositionConfig>(2, _omitFieldNames ? '' : 'position',
        subBuilder: Config_PositionConfig.create)
    ..aOM<Config_PowerConfig>(3, _omitFieldNames ? '' : 'power',
        subBuilder: Config_PowerConfig.create)
    ..aOM<Config_NetworkConfig>(4, _omitFieldNames ? '' : 'network',
        subBuilder: Config_NetworkConfig.create)
    ..aOM<Config_DisplayConfig>(5, _omitFieldNames ? '' : 'display',
        subBuilder: Config_DisplayConfig.create)
    ..aOM<Config_LoRaConfig>(6, _omitFieldNames ? '' : 'lora',
        subBuilder: Config_LoRaConfig.create)
    ..aOM<Config_BluetoothConfig>(7, _omitFieldNames ? '' : 'bluetooth',
        subBuilder: Config_BluetoothConfig.create)
    ..aOM<Config_SecurityConfig>(8, _omitFieldNames ? '' : 'security',
        subBuilder: Config_SecurityConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config copyWith(void Function(Config) updates) =>
      super.copyWith((message) => updates(message as Config)) as Config;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config create() => Config._();
  @$core.override
  Config createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Config>(create);
  static Config? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  Config_PayloadVariant whichPayloadVariant() =>
      _Config_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Config_DeviceConfig get device => $_getN(0);
  @$pb.TagNumber(1)
  set device(Config_DeviceConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDevice() => $_has(0);
  @$pb.TagNumber(1)
  void clearDevice() => $_clearField(1);
  @$pb.TagNumber(1)
  Config_DeviceConfig ensureDevice() => $_ensure(0);

  @$pb.TagNumber(2)
  Config_PositionConfig get position => $_getN(1);
  @$pb.TagNumber(2)
  set position(Config_PositionConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPosition() => $_has(1);
  @$pb.TagNumber(2)
  void clearPosition() => $_clearField(2);
  @$pb.TagNumber(2)
  Config_PositionConfig ensurePosition() => $_ensure(1);

  @$pb.TagNumber(3)
  Config_PowerConfig get power => $_getN(2);
  @$pb.TagNumber(3)
  set power(Config_PowerConfig value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPower() => $_has(2);
  @$pb.TagNumber(3)
  void clearPower() => $_clearField(3);
  @$pb.TagNumber(3)
  Config_PowerConfig ensurePower() => $_ensure(2);

  @$pb.TagNumber(4)
  Config_NetworkConfig get network => $_getN(3);
  @$pb.TagNumber(4)
  set network(Config_NetworkConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasNetwork() => $_has(3);
  @$pb.TagNumber(4)
  void clearNetwork() => $_clearField(4);
  @$pb.TagNumber(4)
  Config_NetworkConfig ensureNetwork() => $_ensure(3);

  @$pb.TagNumber(5)
  Config_DisplayConfig get display => $_getN(4);
  @$pb.TagNumber(5)
  set display(Config_DisplayConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDisplay() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplay() => $_clearField(5);
  @$pb.TagNumber(5)
  Config_DisplayConfig ensureDisplay() => $_ensure(4);

  @$pb.TagNumber(6)
  Config_LoRaConfig get lora => $_getN(5);
  @$pb.TagNumber(6)
  set lora(Config_LoRaConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLora() => $_has(5);
  @$pb.TagNumber(6)
  void clearLora() => $_clearField(6);
  @$pb.TagNumber(6)
  Config_LoRaConfig ensureLora() => $_ensure(5);

  @$pb.TagNumber(7)
  Config_BluetoothConfig get bluetooth => $_getN(6);
  @$pb.TagNumber(7)
  set bluetooth(Config_BluetoothConfig value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasBluetooth() => $_has(6);
  @$pb.TagNumber(7)
  void clearBluetooth() => $_clearField(7);
  @$pb.TagNumber(7)
  Config_BluetoothConfig ensureBluetooth() => $_ensure(6);

  @$pb.TagNumber(8)
  Config_SecurityConfig get security => $_getN(7);
  @$pb.TagNumber(8)
  set security(Config_SecurityConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSecurity() => $_has(7);
  @$pb.TagNumber(8)
  void clearSecurity() => $_clearField(8);
  @$pb.TagNumber(8)
  Config_SecurityConfig ensureSecurity() => $_ensure(7);
}

class ModuleConfig_MQTTConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_MQTTConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_MQTTConfig._();

  factory ModuleConfig_MQTTConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_MQTTConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.MQTTConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_MQTTConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_MQTTConfig copyWith(
          void Function(ModuleConfig_MQTTConfig) updates) =>
      super.copyWith((message) => updates(message as ModuleConfig_MQTTConfig))
          as ModuleConfig_MQTTConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_MQTTConfig create() => ModuleConfig_MQTTConfig._();
  @$core.override
  ModuleConfig_MQTTConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_MQTTConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_MQTTConfig>(create);
  static ModuleConfig_MQTTConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_SerialConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_SerialConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_SerialConfig._();

  factory ModuleConfig_SerialConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_SerialConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.SerialConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_SerialConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_SerialConfig copyWith(
          void Function(ModuleConfig_SerialConfig) updates) =>
      super.copyWith((message) => updates(message as ModuleConfig_SerialConfig))
          as ModuleConfig_SerialConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_SerialConfig create() => ModuleConfig_SerialConfig._();
  @$core.override
  ModuleConfig_SerialConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_SerialConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_SerialConfig>(create);
  static ModuleConfig_SerialConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_ExternalNotificationConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_ExternalNotificationConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_ExternalNotificationConfig._();

  factory ModuleConfig_ExternalNotificationConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_ExternalNotificationConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.ExternalNotificationConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_ExternalNotificationConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_ExternalNotificationConfig copyWith(
          void Function(ModuleConfig_ExternalNotificationConfig) updates) =>
      super.copyWith((message) =>
              updates(message as ModuleConfig_ExternalNotificationConfig))
          as ModuleConfig_ExternalNotificationConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_ExternalNotificationConfig create() =>
      ModuleConfig_ExternalNotificationConfig._();
  @$core.override
  ModuleConfig_ExternalNotificationConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_ExternalNotificationConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          ModuleConfig_ExternalNotificationConfig>(create);
  static ModuleConfig_ExternalNotificationConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_StoreForwardConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_StoreForwardConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_StoreForwardConfig._();

  factory ModuleConfig_StoreForwardConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_StoreForwardConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.StoreForwardConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_StoreForwardConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_StoreForwardConfig copyWith(
          void Function(ModuleConfig_StoreForwardConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_StoreForwardConfig))
          as ModuleConfig_StoreForwardConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_StoreForwardConfig create() =>
      ModuleConfig_StoreForwardConfig._();
  @$core.override
  ModuleConfig_StoreForwardConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_StoreForwardConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_StoreForwardConfig>(
          create);
  static ModuleConfig_StoreForwardConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_RangeTestConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_RangeTestConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_RangeTestConfig._();

  factory ModuleConfig_RangeTestConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_RangeTestConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.RangeTestConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_RangeTestConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_RangeTestConfig copyWith(
          void Function(ModuleConfig_RangeTestConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_RangeTestConfig))
          as ModuleConfig_RangeTestConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_RangeTestConfig create() =>
      ModuleConfig_RangeTestConfig._();
  @$core.override
  ModuleConfig_RangeTestConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_RangeTestConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_RangeTestConfig>(create);
  static ModuleConfig_RangeTestConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_TelemetryConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_TelemetryConfig({
    $core.int? deviceUpdateInterval,
  }) {
    final result = create();
    if (deviceUpdateInterval != null)
      result.deviceUpdateInterval = deviceUpdateInterval;
    return result;
  }

  ModuleConfig_TelemetryConfig._();

  factory ModuleConfig_TelemetryConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_TelemetryConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.TelemetryConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'deviceUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_TelemetryConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_TelemetryConfig copyWith(
          void Function(ModuleConfig_TelemetryConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_TelemetryConfig))
          as ModuleConfig_TelemetryConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_TelemetryConfig create() =>
      ModuleConfig_TelemetryConfig._();
  @$core.override
  ModuleConfig_TelemetryConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_TelemetryConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_TelemetryConfig>(create);
  static ModuleConfig_TelemetryConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get deviceUpdateInterval => $_getIZ(0);
  @$pb.TagNumber(1)
  set deviceUpdateInterval($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceUpdateInterval() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceUpdateInterval() => $_clearField(1);
}

class ModuleConfig_CannedMessageConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_CannedMessageConfig({
    $core.bool? enabled,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ModuleConfig_CannedMessageConfig._();

  factory ModuleConfig_CannedMessageConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_CannedMessageConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.CannedMessageConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_CannedMessageConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_CannedMessageConfig copyWith(
          void Function(ModuleConfig_CannedMessageConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_CannedMessageConfig))
          as ModuleConfig_CannedMessageConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_CannedMessageConfig create() =>
      ModuleConfig_CannedMessageConfig._();
  @$core.override
  ModuleConfig_CannedMessageConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_CannedMessageConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_CannedMessageConfig>(
          create);
  static ModuleConfig_CannedMessageConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);
}

class ModuleConfig_AudioConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_AudioConfig({
    $core.bool? codec2Enabled,
  }) {
    final result = create();
    if (codec2Enabled != null) result.codec2Enabled = codec2Enabled;
    return result;
  }

  ModuleConfig_AudioConfig._();

  factory ModuleConfig_AudioConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_AudioConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.AudioConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'codec2Enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_AudioConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_AudioConfig copyWith(
          void Function(ModuleConfig_AudioConfig) updates) =>
      super.copyWith((message) => updates(message as ModuleConfig_AudioConfig))
          as ModuleConfig_AudioConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_AudioConfig create() => ModuleConfig_AudioConfig._();
  @$core.override
  ModuleConfig_AudioConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_AudioConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_AudioConfig>(create);
  static ModuleConfig_AudioConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get codec2Enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set codec2Enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCodec2Enabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearCodec2Enabled() => $_clearField(1);
}

enum ModuleConfig_PayloadVariant {
  mqtt,
  serial,
  extNotification,
  storeForward,
  rangeTest,
  telemetry,
  cannedMessage,
  audio,
  notSet
}

/// Module config message wrapper
class ModuleConfig extends $pb.GeneratedMessage {
  factory ModuleConfig({
    ModuleConfig_MQTTConfig? mqtt,
    ModuleConfig_SerialConfig? serial,
    ModuleConfig_ExternalNotificationConfig? extNotification,
    ModuleConfig_StoreForwardConfig? storeForward,
    ModuleConfig_RangeTestConfig? rangeTest,
    ModuleConfig_TelemetryConfig? telemetry,
    ModuleConfig_CannedMessageConfig? cannedMessage,
    ModuleConfig_AudioConfig? audio,
  }) {
    final result = create();
    if (mqtt != null) result.mqtt = mqtt;
    if (serial != null) result.serial = serial;
    if (extNotification != null) result.extNotification = extNotification;
    if (storeForward != null) result.storeForward = storeForward;
    if (rangeTest != null) result.rangeTest = rangeTest;
    if (telemetry != null) result.telemetry = telemetry;
    if (cannedMessage != null) result.cannedMessage = cannedMessage;
    if (audio != null) result.audio = audio;
    return result;
  }

  ModuleConfig._();

  factory ModuleConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ModuleConfig_PayloadVariant>
      _ModuleConfig_PayloadVariantByTag = {
    1: ModuleConfig_PayloadVariant.mqtt,
    2: ModuleConfig_PayloadVariant.serial,
    3: ModuleConfig_PayloadVariant.extNotification,
    4: ModuleConfig_PayloadVariant.storeForward,
    5: ModuleConfig_PayloadVariant.rangeTest,
    6: ModuleConfig_PayloadVariant.telemetry,
    7: ModuleConfig_PayloadVariant.cannedMessage,
    8: ModuleConfig_PayloadVariant.audio,
    0: ModuleConfig_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
    ..aOM<ModuleConfig_MQTTConfig>(1, _omitFieldNames ? '' : 'mqtt',
        subBuilder: ModuleConfig_MQTTConfig.create)
    ..aOM<ModuleConfig_SerialConfig>(2, _omitFieldNames ? '' : 'serial',
        subBuilder: ModuleConfig_SerialConfig.create)
    ..aOM<ModuleConfig_ExternalNotificationConfig>(
        3, _omitFieldNames ? '' : 'extNotification',
        subBuilder: ModuleConfig_ExternalNotificationConfig.create)
    ..aOM<ModuleConfig_StoreForwardConfig>(
        4, _omitFieldNames ? '' : 'storeForward',
        subBuilder: ModuleConfig_StoreForwardConfig.create)
    ..aOM<ModuleConfig_RangeTestConfig>(5, _omitFieldNames ? '' : 'rangeTest',
        subBuilder: ModuleConfig_RangeTestConfig.create)
    ..aOM<ModuleConfig_TelemetryConfig>(6, _omitFieldNames ? '' : 'telemetry',
        subBuilder: ModuleConfig_TelemetryConfig.create)
    ..aOM<ModuleConfig_CannedMessageConfig>(
        7, _omitFieldNames ? '' : 'cannedMessage',
        subBuilder: ModuleConfig_CannedMessageConfig.create)
    ..aOM<ModuleConfig_AudioConfig>(8, _omitFieldNames ? '' : 'audio',
        subBuilder: ModuleConfig_AudioConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig copyWith(void Function(ModuleConfig) updates) =>
      super.copyWith((message) => updates(message as ModuleConfig))
          as ModuleConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig create() => ModuleConfig._();
  @$core.override
  ModuleConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig>(create);
  static ModuleConfig? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  ModuleConfig_PayloadVariant whichPayloadVariant() =>
      _ModuleConfig_PayloadVariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ModuleConfig_MQTTConfig get mqtt => $_getN(0);
  @$pb.TagNumber(1)
  set mqtt(ModuleConfig_MQTTConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMqtt() => $_has(0);
  @$pb.TagNumber(1)
  void clearMqtt() => $_clearField(1);
  @$pb.TagNumber(1)
  ModuleConfig_MQTTConfig ensureMqtt() => $_ensure(0);

  @$pb.TagNumber(2)
  ModuleConfig_SerialConfig get serial => $_getN(1);
  @$pb.TagNumber(2)
  set serial(ModuleConfig_SerialConfig value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSerial() => $_has(1);
  @$pb.TagNumber(2)
  void clearSerial() => $_clearField(2);
  @$pb.TagNumber(2)
  ModuleConfig_SerialConfig ensureSerial() => $_ensure(1);

  @$pb.TagNumber(3)
  ModuleConfig_ExternalNotificationConfig get extNotification => $_getN(2);
  @$pb.TagNumber(3)
  set extNotification(ModuleConfig_ExternalNotificationConfig value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExtNotification() => $_has(2);
  @$pb.TagNumber(3)
  void clearExtNotification() => $_clearField(3);
  @$pb.TagNumber(3)
  ModuleConfig_ExternalNotificationConfig ensureExtNotification() =>
      $_ensure(2);

  @$pb.TagNumber(4)
  ModuleConfig_StoreForwardConfig get storeForward => $_getN(3);
  @$pb.TagNumber(4)
  set storeForward(ModuleConfig_StoreForwardConfig value) =>
      $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStoreForward() => $_has(3);
  @$pb.TagNumber(4)
  void clearStoreForward() => $_clearField(4);
  @$pb.TagNumber(4)
  ModuleConfig_StoreForwardConfig ensureStoreForward() => $_ensure(3);

  @$pb.TagNumber(5)
  ModuleConfig_RangeTestConfig get rangeTest => $_getN(4);
  @$pb.TagNumber(5)
  set rangeTest(ModuleConfig_RangeTestConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRangeTest() => $_has(4);
  @$pb.TagNumber(5)
  void clearRangeTest() => $_clearField(5);
  @$pb.TagNumber(5)
  ModuleConfig_RangeTestConfig ensureRangeTest() => $_ensure(4);

  @$pb.TagNumber(6)
  ModuleConfig_TelemetryConfig get telemetry => $_getN(5);
  @$pb.TagNumber(6)
  set telemetry(ModuleConfig_TelemetryConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTelemetry() => $_has(5);
  @$pb.TagNumber(6)
  void clearTelemetry() => $_clearField(6);
  @$pb.TagNumber(6)
  ModuleConfig_TelemetryConfig ensureTelemetry() => $_ensure(5);

  @$pb.TagNumber(7)
  ModuleConfig_CannedMessageConfig get cannedMessage => $_getN(6);
  @$pb.TagNumber(7)
  set cannedMessage(ModuleConfig_CannedMessageConfig value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCannedMessage() => $_has(6);
  @$pb.TagNumber(7)
  void clearCannedMessage() => $_clearField(7);
  @$pb.TagNumber(7)
  ModuleConfig_CannedMessageConfig ensureCannedMessage() => $_ensure(6);

  @$pb.TagNumber(8)
  ModuleConfig_AudioConfig get audio => $_getN(7);
  @$pb.TagNumber(8)
  set audio(ModuleConfig_AudioConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAudio() => $_has(7);
  @$pb.TagNumber(8)
  void clearAudio() => $_clearField(8);
  @$pb.TagNumber(8)
  ModuleConfig_AudioConfig ensureAudio() => $_ensure(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
