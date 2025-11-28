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
    HardwareModel? hwModel,
    $core.List<$core.int>? macaddr,
    $core.String? hwModelString,
    $core.bool? isLicensed,
    Config_DeviceConfig_Role? role,
    $core.List<$core.int>? publicKey,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (longName != null) result.longName = longName;
    if (shortName != null) result.shortName = shortName;
    if (hwModel != null) result.hwModel = hwModel;
    if (macaddr != null) result.macaddr = macaddr;
    if (hwModelString != null) result.hwModelString = hwModelString;
    if (isLicensed != null) result.isLicensed = isLicensed;
    if (role != null) result.role = role;
    if (publicKey != null) result.publicKey = publicKey;
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
    ..aE<HardwareModel>(4, _omitFieldNames ? '' : 'hwModel',
        enumValues: HardwareModel.values)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'macaddr', $pb.PbFieldType.OY)
    ..aOS(6, _omitFieldNames ? '' : 'hwModelString')
    ..aOB(7, _omitFieldNames ? '' : 'isLicensed')
    ..aE<Config_DeviceConfig_Role>(8, _omitFieldNames ? '' : 'role',
        enumValues: Config_DeviceConfig_Role.values)
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
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

  /// Hardware model
  @$pb.TagNumber(4)
  HardwareModel get hwModel => $_getN(3);
  @$pb.TagNumber(4)
  set hwModel(HardwareModel value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasHwModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearHwModel() => $_clearField(4);

  /// MAC address (6 bytes)
  @$pb.TagNumber(5)
  $core.List<$core.int> get macaddr => $_getN(4);
  @$pb.TagNumber(5)
  set macaddr($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMacaddr() => $_has(4);
  @$pb.TagNumber(5)
  void clearMacaddr() => $_clearField(5);

  /// Hardware model as string (for newer/unknown models)
  @$pb.TagNumber(6)
  $core.String get hwModelString => $_getSZ(5);
  @$pb.TagNumber(6)
  set hwModelString($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHwModelString() => $_has(5);
  @$pb.TagNumber(6)
  void clearHwModelString() => $_clearField(6);

  /// Licensed ham operator
  @$pb.TagNumber(7)
  $core.bool get isLicensed => $_getBF(6);
  @$pb.TagNumber(7)
  set isLicensed($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsLicensed() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsLicensed() => $_clearField(7);

  /// User's role
  @$pb.TagNumber(8)
  Config_DeviceConfig_Role get role => $_getN(7);
  @$pb.TagNumber(8)
  set role(Config_DeviceConfig_Role value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasRole() => $_has(7);
  @$pb.TagNumber(8)
  void clearRole() => $_clearField(8);

  /// Public key for encryption (32 bytes)
  @$pb.TagNumber(9)
  $core.List<$core.int> get publicKey => $_getN(8);
  @$pb.TagNumber(9)
  set publicKey($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPublicKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearPublicKey() => $_clearField(9);
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
    $core.int? maxChannels,
    $core.bool? hasGps,
    $core.int? rebootCount,
    $core.String? firmwareVersion,
  }) {
    final result = create();
    if (myNodeNum != null) result.myNodeNum = myNodeNum;
    if (maxChannels != null) result.maxChannels = maxChannels;
    if (hasGps != null) result.hasGps = hasGps;
    if (rebootCount != null) result.rebootCount = rebootCount;
    if (firmwareVersion != null) result.firmwareVersion = firmwareVersion;
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
    ..aI(2, _omitFieldNames ? '' : 'maxChannels',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'hasGps')
    ..aI(4, _omitFieldNames ? '' : 'rebootCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'firmwareVersion')
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

  /// My node number
  @$pb.TagNumber(1)
  $core.int get myNodeNum => $_getIZ(0);
  @$pb.TagNumber(1)
  set myNodeNum($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMyNodeNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearMyNodeNum() => $_clearField(1);

  /// Max channels
  @$pb.TagNumber(2)
  $core.int get maxChannels => $_getIZ(1);
  @$pb.TagNumber(2)
  set maxChannels($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxChannels() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxChannels() => $_clearField(2);

  /// Has GPS
  @$pb.TagNumber(3)
  $core.bool get hasGps => $_getBF(2);
  @$pb.TagNumber(3)
  set hasGps($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasGps() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasGps() => $_clearField(3);

  /// Reboot count
  @$pb.TagNumber(4)
  $core.int get rebootCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set rebootCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRebootCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRebootCount() => $_clearField(4);

  /// Firmware version
  @$pb.TagNumber(5)
  $core.String get firmwareVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set firmwareVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFirmwareVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearFirmwareVersion() => $_clearField(5);
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
    $core.List<$core.int>? psk,
    $core.String? name,
    $core.int? id,
    $core.bool? uplinkEnabled,
    $core.bool? downlinkEnabled,
    $core.List<$core.int>? moduleSettings,
  }) {
    final result = create();
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
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'psk', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OF3)
    ..aOB(4, _omitFieldNames ? '' : 'uplinkEnabled')
    ..aOB(5, _omitFieldNames ? '' : 'downlinkEnabled')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'moduleSettings', $pb.PbFieldType.OY)
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

  /// Pre-shared key (up to 256 bits)
  @$pb.TagNumber(1)
  $core.List<$core.int> get psk => $_getN(0);
  @$pb.TagNumber(1)
  set psk($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPsk() => $_has(0);
  @$pb.TagNumber(1)
  void clearPsk() => $_clearField(1);

  /// Channel name
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// Unique channel ID
  @$pb.TagNumber(3)
  $core.int get id => $_getIZ(2);
  @$pb.TagNumber(3)
  set id($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasId() => $_has(2);
  @$pb.TagNumber(3)
  void clearId() => $_clearField(3);

  /// Uplink enabled
  @$pb.TagNumber(4)
  $core.bool get uplinkEnabled => $_getBF(3);
  @$pb.TagNumber(4)
  set uplinkEnabled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUplinkEnabled() => $_has(3);
  @$pb.TagNumber(4)
  void clearUplinkEnabled() => $_clearField(4);

  /// Downlink enabled
  @$pb.TagNumber(5)
  $core.bool get downlinkEnabled => $_getBF(4);
  @$pb.TagNumber(5)
  set downlinkEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDownlinkEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearDownlinkEnabled() => $_clearField(5);

  /// Module settings (JSON)
  @$pb.TagNumber(6)
  $core.List<$core.int> get moduleSettings => $_getN(5);
  @$pb.TagNumber(6)
  set moduleSettings($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasModuleSettings() => $_has(5);
  @$pb.TagNumber(6)
  void clearModuleSettings() => $_clearField(6);
}

enum AdminMessage_PayloadVariant {
  getChannelRequest,
  getChannelResponse,
  getRadioRequest,
  getRadioResponse,
  getOwnerRequest,
  getOwnerResponse,
  setOwner,
  setChannel,
  setRadio,
  notSet
}

/// Configuration requests
class AdminMessage extends $pb.GeneratedMessage {
  factory AdminMessage({
    $core.int? getChannelRequest,
    Channel? getChannelResponse,
    $core.bool? getRadioRequest,
    RadioConfig? getRadioResponse,
    $core.bool? getOwnerRequest,
    User? getOwnerResponse,
    User? setOwner,
    Channel? setChannel,
    RadioConfig? setRadio,
  }) {
    final result = create();
    if (getChannelRequest != null) result.getChannelRequest = getChannelRequest;
    if (getChannelResponse != null)
      result.getChannelResponse = getChannelResponse;
    if (getRadioRequest != null) result.getRadioRequest = getRadioRequest;
    if (getRadioResponse != null) result.getRadioResponse = getRadioResponse;
    if (getOwnerRequest != null) result.getOwnerRequest = getOwnerRequest;
    if (getOwnerResponse != null) result.getOwnerResponse = getOwnerResponse;
    if (setOwner != null) result.setOwner = setOwner;
    if (setChannel != null) result.setChannel = setChannel;
    if (setRadio != null) result.setRadio = setRadio;
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
    3: AdminMessage_PayloadVariant.getRadioRequest,
    4: AdminMessage_PayloadVariant.getRadioResponse,
    5: AdminMessage_PayloadVariant.getOwnerRequest,
    6: AdminMessage_PayloadVariant.getOwnerResponse,
    7: AdminMessage_PayloadVariant.setOwner,
    8: AdminMessage_PayloadVariant.setChannel,
    9: AdminMessage_PayloadVariant.setRadio,
    0: AdminMessage_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9])
    ..aI(1, _omitFieldNames ? '' : 'getChannelRequest',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Channel>(2, _omitFieldNames ? '' : 'getChannelResponse',
        subBuilder: Channel.create)
    ..aOB(3, _omitFieldNames ? '' : 'getRadioRequest')
    ..aOM<RadioConfig>(4, _omitFieldNames ? '' : 'getRadioResponse',
        subBuilder: RadioConfig.create)
    ..aOB(5, _omitFieldNames ? '' : 'getOwnerRequest')
    ..aOM<User>(6, _omitFieldNames ? '' : 'getOwnerResponse',
        subBuilder: User.create)
    ..aOM<User>(7, _omitFieldNames ? '' : 'setOwner', subBuilder: User.create)
    ..aOM<Channel>(8, _omitFieldNames ? '' : 'setChannel',
        subBuilder: Channel.create)
    ..aOM<RadioConfig>(9, _omitFieldNames ? '' : 'setRadio',
        subBuilder: RadioConfig.create)
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
  @$pb.TagNumber(9)
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
  @$pb.TagNumber(9)
  void clearPayloadVariant() => $_clearField($_whichOneof(0));

  /// Get channel request
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

  /// Get radio request
  @$pb.TagNumber(3)
  $core.bool get getRadioRequest => $_getBF(2);
  @$pb.TagNumber(3)
  set getRadioRequest($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGetRadioRequest() => $_has(2);
  @$pb.TagNumber(3)
  void clearGetRadioRequest() => $_clearField(3);

  /// Get radio response
  @$pb.TagNumber(4)
  RadioConfig get getRadioResponse => $_getN(3);
  @$pb.TagNumber(4)
  set getRadioResponse(RadioConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGetRadioResponse() => $_has(3);
  @$pb.TagNumber(4)
  void clearGetRadioResponse() => $_clearField(4);
  @$pb.TagNumber(4)
  RadioConfig ensureGetRadioResponse() => $_ensure(3);

  /// Get owner request
  @$pb.TagNumber(5)
  $core.bool get getOwnerRequest => $_getBF(4);
  @$pb.TagNumber(5)
  set getOwnerRequest($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGetOwnerRequest() => $_has(4);
  @$pb.TagNumber(5)
  void clearGetOwnerRequest() => $_clearField(5);

  /// Get owner response
  @$pb.TagNumber(6)
  User get getOwnerResponse => $_getN(5);
  @$pb.TagNumber(6)
  set getOwnerResponse(User value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasGetOwnerResponse() => $_has(5);
  @$pb.TagNumber(6)
  void clearGetOwnerResponse() => $_clearField(6);
  @$pb.TagNumber(6)
  User ensureGetOwnerResponse() => $_ensure(5);

  /// Set owner
  @$pb.TagNumber(7)
  User get setOwner => $_getN(6);
  @$pb.TagNumber(7)
  set setOwner(User value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSetOwner() => $_has(6);
  @$pb.TagNumber(7)
  void clearSetOwner() => $_clearField(7);
  @$pb.TagNumber(7)
  User ensureSetOwner() => $_ensure(6);

  /// Set channel
  @$pb.TagNumber(8)
  Channel get setChannel => $_getN(7);
  @$pb.TagNumber(8)
  set setChannel(Channel value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSetChannel() => $_has(7);
  @$pb.TagNumber(8)
  void clearSetChannel() => $_clearField(8);
  @$pb.TagNumber(8)
  Channel ensureSetChannel() => $_ensure(7);

  /// Set radio
  @$pb.TagNumber(9)
  RadioConfig get setRadio => $_getN(8);
  @$pb.TagNumber(9)
  set setRadio(RadioConfig value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSetRadio() => $_has(8);
  @$pb.TagNumber(9)
  void clearSetRadio() => $_clearField(9);
  @$pb.TagNumber(9)
  RadioConfig ensureSetRadio() => $_ensure(8);
}

/// LoRa settings
class RadioConfig_LoRaConfig extends $pb.GeneratedMessage {
  factory RadioConfig_LoRaConfig({
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

  RadioConfig_LoRaConfig._();

  factory RadioConfig_LoRaConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RadioConfig_LoRaConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RadioConfig.LoRaConfig',
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
  RadioConfig_LoRaConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadioConfig_LoRaConfig copyWith(
          void Function(RadioConfig_LoRaConfig) updates) =>
      super.copyWith((message) => updates(message as RadioConfig_LoRaConfig))
          as RadioConfig_LoRaConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RadioConfig_LoRaConfig create() => RadioConfig_LoRaConfig._();
  @$core.override
  RadioConfig_LoRaConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RadioConfig_LoRaConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RadioConfig_LoRaConfig>(create);
  static RadioConfig_LoRaConfig? _defaultInstance;

  /// Use preset
  @$pb.TagNumber(1)
  $core.bool get usePreset => $_getBF(0);
  @$pb.TagNumber(1)
  set usePreset($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsePreset() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsePreset() => $_clearField(1);

  /// Modem preset
  @$pb.TagNumber(2)
  ModemPreset get modemPreset => $_getN(1);
  @$pb.TagNumber(2)
  set modemPreset(ModemPreset value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasModemPreset() => $_has(1);
  @$pb.TagNumber(2)
  void clearModemPreset() => $_clearField(2);

  /// Bandwidth
  @$pb.TagNumber(3)
  $core.int get bandwidth => $_getIZ(2);
  @$pb.TagNumber(3)
  set bandwidth($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBandwidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearBandwidth() => $_clearField(3);

  /// Spread factor
  @$pb.TagNumber(4)
  $core.int get spreadFactor => $_getIZ(3);
  @$pb.TagNumber(4)
  set spreadFactor($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSpreadFactor() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpreadFactor() => $_clearField(4);

  /// Coding rate
  @$pb.TagNumber(5)
  $core.int get codingRate => $_getIZ(4);
  @$pb.TagNumber(5)
  set codingRate($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCodingRate() => $_has(4);
  @$pb.TagNumber(5)
  void clearCodingRate() => $_clearField(5);

  /// Frequency offset
  @$pb.TagNumber(6)
  $core.double get frequencyOffset => $_getN(5);
  @$pb.TagNumber(6)
  set frequencyOffset($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFrequencyOffset() => $_has(5);
  @$pb.TagNumber(6)
  void clearFrequencyOffset() => $_clearField(6);

  /// Region
  @$pb.TagNumber(7)
  RegionCode get region => $_getN(6);
  @$pb.TagNumber(7)
  set region(RegionCode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRegion() => $_has(6);
  @$pb.TagNumber(7)
  void clearRegion() => $_clearField(7);

  /// Hop limit
  @$pb.TagNumber(8)
  $core.int get hopLimit => $_getIZ(7);
  @$pb.TagNumber(8)
  set hopLimit($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHopLimit() => $_has(7);
  @$pb.TagNumber(8)
  void clearHopLimit() => $_clearField(8);

  /// TX enabled
  @$pb.TagNumber(9)
  $core.bool get txEnabled => $_getBF(8);
  @$pb.TagNumber(9)
  set txEnabled($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTxEnabled() => $_has(8);
  @$pb.TagNumber(9)
  void clearTxEnabled() => $_clearField(9);

  /// TX power
  @$pb.TagNumber(10)
  $core.int get txPower => $_getIZ(9);
  @$pb.TagNumber(10)
  set txPower($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTxPower() => $_has(9);
  @$pb.TagNumber(10)
  void clearTxPower() => $_clearField(10);
}

/// Radio configuration
class RadioConfig extends $pb.GeneratedMessage {
  factory RadioConfig({
    RadioConfig_LoRaConfig? lora,
  }) {
    final result = create();
    if (lora != null) result.lora = lora;
    return result;
  }

  RadioConfig._();

  factory RadioConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RadioConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RadioConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOM<RadioConfig_LoRaConfig>(1, _omitFieldNames ? '' : 'lora',
        subBuilder: RadioConfig_LoRaConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadioConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadioConfig copyWith(void Function(RadioConfig) updates) =>
      super.copyWith((message) => updates(message as RadioConfig))
          as RadioConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RadioConfig create() => RadioConfig._();
  @$core.override
  RadioConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RadioConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RadioConfig>(create);
  static RadioConfig? _defaultInstance;

  @$pb.TagNumber(1)
  RadioConfig_LoRaConfig get lora => $_getN(0);
  @$pb.TagNumber(1)
  set lora(RadioConfig_LoRaConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLora() => $_has(0);
  @$pb.TagNumber(1)
  void clearLora() => $_clearField(1);
  @$pb.TagNumber(1)
  RadioConfig_LoRaConfig ensureLora() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
