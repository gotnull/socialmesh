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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'mesh.pbenum.dart';
import 'telemetry.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'mesh.pbenum.dart';

/// A GPS Position
class Position extends $pb.GeneratedMessage {
  factory Position({
    $core.int? latitudeI,
    $core.int? longitudeI,
    $core.int? altitude,
    $core.int? time,
    $core.int? gpsAccuracy,
    $core.int? groundSpeed,
    $core.int? groundTrack,
    $core.int? satsInView,
    $core.int? seqNumber,
    $core.int? precisionBits,
  }) {
    final result = create();
    if (latitudeI != null) result.latitudeI = latitudeI;
    if (longitudeI != null) result.longitudeI = longitudeI;
    if (altitude != null) result.altitude = altitude;
    if (time != null) result.time = time;
    if (gpsAccuracy != null) result.gpsAccuracy = gpsAccuracy;
    if (groundSpeed != null) result.groundSpeed = groundSpeed;
    if (groundTrack != null) result.groundTrack = groundTrack;
    if (satsInView != null) result.satsInView = satsInView;
    if (seqNumber != null) result.seqNumber = seqNumber;
    if (precisionBits != null) result.precisionBits = precisionBits;
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
    ..aI(14, _omitFieldNames ? '' : 'gpsAccuracy',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(15, _omitFieldNames ? '' : 'groundSpeed',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(16, _omitFieldNames ? '' : 'groundTrack',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(19, _omitFieldNames ? '' : 'satsInView',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(22, _omitFieldNames ? '' : 'seqNumber', fieldType: $pb.PbFieldType.OU3)
    ..aI(23, _omitFieldNames ? '' : 'precisionBits',
        fieldType: $pb.PbFieldType.OU3)
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

  /// GPS accuracy in mm multiplied with DOP
  @$pb.TagNumber(14)
  $core.int get gpsAccuracy => $_getIZ(4);
  @$pb.TagNumber(14)
  set gpsAccuracy($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(14)
  $core.bool hasGpsAccuracy() => $_has(4);
  @$pb.TagNumber(14)
  void clearGpsAccuracy() => $_clearField(14);

  /// Ground speed in m/s
  @$pb.TagNumber(15)
  $core.int get groundSpeed => $_getIZ(5);
  @$pb.TagNumber(15)
  set groundSpeed($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(15)
  $core.bool hasGroundSpeed() => $_has(5);
  @$pb.TagNumber(15)
  void clearGroundSpeed() => $_clearField(15);

  /// True North TRACK in 1/100 degrees
  @$pb.TagNumber(16)
  $core.int get groundTrack => $_getIZ(6);
  @$pb.TagNumber(16)
  set groundTrack($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(16)
  $core.bool hasGroundTrack() => $_has(6);
  @$pb.TagNumber(16)
  void clearGroundTrack() => $_clearField(16);

  /// GPS Satellites in View
  @$pb.TagNumber(19)
  $core.int get satsInView => $_getIZ(7);
  @$pb.TagNumber(19)
  set satsInView($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(19)
  $core.bool hasSatsInView() => $_has(7);
  @$pb.TagNumber(19)
  void clearSatsInView() => $_clearField(19);

  /// Sequence number
  @$pb.TagNumber(22)
  $core.int get seqNumber => $_getIZ(8);
  @$pb.TagNumber(22)
  set seqNumber($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(22)
  $core.bool hasSeqNumber() => $_has(8);
  @$pb.TagNumber(22)
  void clearSeqNumber() => $_clearField(22);

  /// Precision bits
  @$pb.TagNumber(23)
  $core.int get precisionBits => $_getIZ(9);
  @$pb.TagNumber(23)
  set precisionBits($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(23)
  $core.bool hasPrecisionBits() => $_has(9);
  @$pb.TagNumber(23)
  void clearPrecisionBits() => $_clearField(23);
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

enum Routing_Variant { routeRequest, routeReply, errorReason, notSet }

/// Routing message for ACK/NAK delivery status
class Routing extends $pb.GeneratedMessage {
  factory Routing({
    RouteDiscovery? routeRequest,
    RouteDiscovery? routeReply,
    Routing_Error? errorReason,
  }) {
    final result = create();
    if (routeRequest != null) result.routeRequest = routeRequest;
    if (routeReply != null) result.routeReply = routeReply;
    if (errorReason != null) result.errorReason = errorReason;
    return result;
  }

  Routing._();

  factory Routing.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Routing.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Routing_Variant> _Routing_VariantByTag = {
    1: Routing_Variant.routeRequest,
    2: Routing_Variant.routeReply,
    3: Routing_Variant.errorReason,
    0: Routing_Variant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Routing',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<RouteDiscovery>(1, _omitFieldNames ? '' : 'routeRequest',
        subBuilder: RouteDiscovery.create)
    ..aOM<RouteDiscovery>(2, _omitFieldNames ? '' : 'routeReply',
        subBuilder: RouteDiscovery.create)
    ..aE<Routing_Error>(3, _omitFieldNames ? '' : 'errorReason',
        enumValues: Routing_Error.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Routing clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Routing copyWith(void Function(Routing) updates) =>
      super.copyWith((message) => updates(message as Routing)) as Routing;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Routing create() => Routing._();
  @$core.override
  Routing createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Routing getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Routing>(create);
  static Routing? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  Routing_Variant whichVariant() => _Routing_VariantByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearVariant() => $_clearField($_whichOneof(0));

  ///
  ///  Route request
  @$pb.TagNumber(1)
  RouteDiscovery get routeRequest => $_getN(0);
  @$pb.TagNumber(1)
  set routeRequest(RouteDiscovery value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRouteRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearRouteRequest() => $_clearField(1);
  @$pb.TagNumber(1)
  RouteDiscovery ensureRouteRequest() => $_ensure(0);

  ///
  ///  Route reply
  @$pb.TagNumber(2)
  RouteDiscovery get routeReply => $_getN(1);
  @$pb.TagNumber(2)
  set routeReply(RouteDiscovery value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRouteReply() => $_has(1);
  @$pb.TagNumber(2)
  void clearRouteReply() => $_clearField(2);
  @$pb.TagNumber(2)
  RouteDiscovery ensureRouteReply() => $_ensure(1);

  ///
  ///  Error reason for message delivery failure
  @$pb.TagNumber(3)
  Routing_Error get errorReason => $_getN(2);
  @$pb.TagNumber(3)
  set errorReason(Routing_Error value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasErrorReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearErrorReason() => $_clearField(3);
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
    $0.DeviceMetrics? deviceMetrics,
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
    ..aOM<$0.DeviceMetrics>(6, _omitFieldNames ? '' : 'deviceMetrics',
        subBuilder: $0.DeviceMetrics.create)
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
  $0.DeviceMetrics get deviceMetrics => $_getN(5);
  @$pb.TagNumber(6)
  set deviceMetrics($0.DeviceMetrics value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDeviceMetrics() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeviceMetrics() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.DeviceMetrics ensureDeviceMetrics() => $_ensure(5);
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
  getCannedMessageModuleMessagesRequest,
  getCannedMessageModuleMessagesResponse,
  getDeviceMetadataRequest,
  getDeviceMetadataResponse,
  getRingtoneRequest,
  getRingtoneResponse,
  getDeviceConnectionStatusRequest,
  getDeviceConnectionStatusResponse,
  setHamMode,
  getNodeRemoteHardwarePinsRequest,
  getNodeRemoteHardwarePinsResponse,
  enterDfuModeRequest,
  deleteFileRequest,
  setScale,
  setOwner,
  setChannel,
  setConfig,
  setModuleConfig,
  setCannedMessageModuleMessages,
  setRingtoneMessage,
  removeByNodenum,
  setFavoriteNode,
  removeFavoriteNode,
  setFixedPosition,
  removeFixedPosition,
  setTimeOnly,
  beginEditSettings,
  commitEditSettings,
  factoryResetDevice,
  rebootOtaSeconds,
  exitSimulator,
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
    AdminMessage_ConfigType? getConfigRequest,
    Config? getConfigResponse,
    AdminMessage_ModuleConfigType? getModuleConfigRequest,
    ModuleConfig? getModuleConfigResponse,
    $core.bool? getCannedMessageModuleMessagesRequest,
    $core.String? getCannedMessageModuleMessagesResponse,
    $core.bool? getDeviceMetadataRequest,
    DeviceMetadata? getDeviceMetadataResponse,
    $core.bool? getRingtoneRequest,
    $core.String? getRingtoneResponse,
    $core.bool? getDeviceConnectionStatusRequest,
    DeviceConnectionStatus? getDeviceConnectionStatusResponse,
    HamParameters? setHamMode,
    $core.bool? getNodeRemoteHardwarePinsRequest,
    NodeRemoteHardwarePinsResponse? getNodeRemoteHardwarePinsResponse,
    $core.bool? enterDfuModeRequest,
    $core.String? deleteFileRequest,
    $core.int? setScale,
    User? setOwner,
    Channel? setChannel,
    Config? setConfig,
    ModuleConfig? setModuleConfig,
    $core.String? setCannedMessageModuleMessages,
    $core.String? setRingtoneMessage,
    $core.int? removeByNodenum,
    $core.int? setFavoriteNode,
    $core.int? removeFavoriteNode,
    Position? setFixedPosition,
    $core.bool? removeFixedPosition,
    $core.int? setTimeOnly,
    $core.bool? beginEditSettings,
    $core.bool? commitEditSettings,
    $core.int? factoryResetDevice,
    $core.int? rebootOtaSeconds,
    $core.bool? exitSimulator,
    $core.int? rebootSeconds,
    $core.int? shutdownSeconds,
    $core.int? factoryResetConfig,
    $core.bool? nodedbReset,
    $core.List<$core.int>? sessionPasskey,
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
    if (getCannedMessageModuleMessagesRequest != null)
      result.getCannedMessageModuleMessagesRequest =
          getCannedMessageModuleMessagesRequest;
    if (getCannedMessageModuleMessagesResponse != null)
      result.getCannedMessageModuleMessagesResponse =
          getCannedMessageModuleMessagesResponse;
    if (getDeviceMetadataRequest != null)
      result.getDeviceMetadataRequest = getDeviceMetadataRequest;
    if (getDeviceMetadataResponse != null)
      result.getDeviceMetadataResponse = getDeviceMetadataResponse;
    if (getRingtoneRequest != null)
      result.getRingtoneRequest = getRingtoneRequest;
    if (getRingtoneResponse != null)
      result.getRingtoneResponse = getRingtoneResponse;
    if (getDeviceConnectionStatusRequest != null)
      result.getDeviceConnectionStatusRequest =
          getDeviceConnectionStatusRequest;
    if (getDeviceConnectionStatusResponse != null)
      result.getDeviceConnectionStatusResponse =
          getDeviceConnectionStatusResponse;
    if (setHamMode != null) result.setHamMode = setHamMode;
    if (getNodeRemoteHardwarePinsRequest != null)
      result.getNodeRemoteHardwarePinsRequest =
          getNodeRemoteHardwarePinsRequest;
    if (getNodeRemoteHardwarePinsResponse != null)
      result.getNodeRemoteHardwarePinsResponse =
          getNodeRemoteHardwarePinsResponse;
    if (enterDfuModeRequest != null)
      result.enterDfuModeRequest = enterDfuModeRequest;
    if (deleteFileRequest != null) result.deleteFileRequest = deleteFileRequest;
    if (setScale != null) result.setScale = setScale;
    if (setOwner != null) result.setOwner = setOwner;
    if (setChannel != null) result.setChannel = setChannel;
    if (setConfig != null) result.setConfig = setConfig;
    if (setModuleConfig != null) result.setModuleConfig = setModuleConfig;
    if (setCannedMessageModuleMessages != null)
      result.setCannedMessageModuleMessages = setCannedMessageModuleMessages;
    if (setRingtoneMessage != null)
      result.setRingtoneMessage = setRingtoneMessage;
    if (removeByNodenum != null) result.removeByNodenum = removeByNodenum;
    if (setFavoriteNode != null) result.setFavoriteNode = setFavoriteNode;
    if (removeFavoriteNode != null)
      result.removeFavoriteNode = removeFavoriteNode;
    if (setFixedPosition != null) result.setFixedPosition = setFixedPosition;
    if (removeFixedPosition != null)
      result.removeFixedPosition = removeFixedPosition;
    if (setTimeOnly != null) result.setTimeOnly = setTimeOnly;
    if (beginEditSettings != null) result.beginEditSettings = beginEditSettings;
    if (commitEditSettings != null)
      result.commitEditSettings = commitEditSettings;
    if (factoryResetDevice != null)
      result.factoryResetDevice = factoryResetDevice;
    if (rebootOtaSeconds != null) result.rebootOtaSeconds = rebootOtaSeconds;
    if (exitSimulator != null) result.exitSimulator = exitSimulator;
    if (rebootSeconds != null) result.rebootSeconds = rebootSeconds;
    if (shutdownSeconds != null) result.shutdownSeconds = shutdownSeconds;
    if (factoryResetConfig != null)
      result.factoryResetConfig = factoryResetConfig;
    if (nodedbReset != null) result.nodedbReset = nodedbReset;
    if (sessionPasskey != null) result.sessionPasskey = sessionPasskey;
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
    10: AdminMessage_PayloadVariant.getCannedMessageModuleMessagesRequest,
    11: AdminMessage_PayloadVariant.getCannedMessageModuleMessagesResponse,
    12: AdminMessage_PayloadVariant.getDeviceMetadataRequest,
    13: AdminMessage_PayloadVariant.getDeviceMetadataResponse,
    14: AdminMessage_PayloadVariant.getRingtoneRequest,
    15: AdminMessage_PayloadVariant.getRingtoneResponse,
    16: AdminMessage_PayloadVariant.getDeviceConnectionStatusRequest,
    17: AdminMessage_PayloadVariant.getDeviceConnectionStatusResponse,
    18: AdminMessage_PayloadVariant.setHamMode,
    19: AdminMessage_PayloadVariant.getNodeRemoteHardwarePinsRequest,
    20: AdminMessage_PayloadVariant.getNodeRemoteHardwarePinsResponse,
    21: AdminMessage_PayloadVariant.enterDfuModeRequest,
    22: AdminMessage_PayloadVariant.deleteFileRequest,
    23: AdminMessage_PayloadVariant.setScale,
    32: AdminMessage_PayloadVariant.setOwner,
    33: AdminMessage_PayloadVariant.setChannel,
    34: AdminMessage_PayloadVariant.setConfig,
    35: AdminMessage_PayloadVariant.setModuleConfig,
    36: AdminMessage_PayloadVariant.setCannedMessageModuleMessages,
    37: AdminMessage_PayloadVariant.setRingtoneMessage,
    38: AdminMessage_PayloadVariant.removeByNodenum,
    39: AdminMessage_PayloadVariant.setFavoriteNode,
    40: AdminMessage_PayloadVariant.removeFavoriteNode,
    41: AdminMessage_PayloadVariant.setFixedPosition,
    42: AdminMessage_PayloadVariant.removeFixedPosition,
    43: AdminMessage_PayloadVariant.setTimeOnly,
    64: AdminMessage_PayloadVariant.beginEditSettings,
    65: AdminMessage_PayloadVariant.commitEditSettings,
    94: AdminMessage_PayloadVariant.factoryResetDevice,
    95: AdminMessage_PayloadVariant.rebootOtaSeconds,
    96: AdminMessage_PayloadVariant.exitSimulator,
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
    ..oo(0, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      64,
      65,
      94,
      95,
      96,
      97,
      98,
      99,
      100
    ])
    ..aI(1, _omitFieldNames ? '' : 'getChannelRequest',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Channel>(2, _omitFieldNames ? '' : 'getChannelResponse',
        subBuilder: Channel.create)
    ..aOB(3, _omitFieldNames ? '' : 'getOwnerRequest')
    ..aOM<User>(4, _omitFieldNames ? '' : 'getOwnerResponse',
        subBuilder: User.create)
    ..aE<AdminMessage_ConfigType>(5, _omitFieldNames ? '' : 'getConfigRequest',
        enumValues: AdminMessage_ConfigType.values)
    ..aOM<Config>(6, _omitFieldNames ? '' : 'getConfigResponse',
        subBuilder: Config.create)
    ..aE<AdminMessage_ModuleConfigType>(
        7, _omitFieldNames ? '' : 'getModuleConfigRequest',
        enumValues: AdminMessage_ModuleConfigType.values)
    ..aOM<ModuleConfig>(8, _omitFieldNames ? '' : 'getModuleConfigResponse',
        subBuilder: ModuleConfig.create)
    ..aOB(10, _omitFieldNames ? '' : 'getCannedMessageModuleMessagesRequest')
    ..aOS(11, _omitFieldNames ? '' : 'getCannedMessageModuleMessagesResponse')
    ..aOB(12, _omitFieldNames ? '' : 'getDeviceMetadataRequest')
    ..aOM<DeviceMetadata>(
        13, _omitFieldNames ? '' : 'getDeviceMetadataResponse',
        subBuilder: DeviceMetadata.create)
    ..aOB(14, _omitFieldNames ? '' : 'getRingtoneRequest')
    ..aOS(15, _omitFieldNames ? '' : 'getRingtoneResponse')
    ..aOB(16, _omitFieldNames ? '' : 'getDeviceConnectionStatusRequest')
    ..aOM<DeviceConnectionStatus>(
        17, _omitFieldNames ? '' : 'getDeviceConnectionStatusResponse',
        subBuilder: DeviceConnectionStatus.create)
    ..aOM<HamParameters>(18, _omitFieldNames ? '' : 'setHamMode',
        subBuilder: HamParameters.create)
    ..aOB(19, _omitFieldNames ? '' : 'getNodeRemoteHardwarePinsRequest')
    ..aOM<NodeRemoteHardwarePinsResponse>(
        20, _omitFieldNames ? '' : 'getNodeRemoteHardwarePinsResponse',
        subBuilder: NodeRemoteHardwarePinsResponse.create)
    ..aOB(21, _omitFieldNames ? '' : 'enterDfuModeRequest')
    ..aOS(22, _omitFieldNames ? '' : 'deleteFileRequest')
    ..aI(23, _omitFieldNames ? '' : 'setScale', fieldType: $pb.PbFieldType.OU3)
    ..aOM<User>(32, _omitFieldNames ? '' : 'setOwner', subBuilder: User.create)
    ..aOM<Channel>(33, _omitFieldNames ? '' : 'setChannel',
        subBuilder: Channel.create)
    ..aOM<Config>(34, _omitFieldNames ? '' : 'setConfig',
        subBuilder: Config.create)
    ..aOM<ModuleConfig>(35, _omitFieldNames ? '' : 'setModuleConfig',
        subBuilder: ModuleConfig.create)
    ..aOS(36, _omitFieldNames ? '' : 'setCannedMessageModuleMessages')
    ..aOS(37, _omitFieldNames ? '' : 'setRingtoneMessage')
    ..aI(38, _omitFieldNames ? '' : 'removeByNodenum',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(39, _omitFieldNames ? '' : 'setFavoriteNode',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(40, _omitFieldNames ? '' : 'removeFavoriteNode',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<Position>(41, _omitFieldNames ? '' : 'setFixedPosition',
        subBuilder: Position.create)
    ..aOB(42, _omitFieldNames ? '' : 'removeFixedPosition')
    ..aI(43, _omitFieldNames ? '' : 'setTimeOnly',
        fieldType: $pb.PbFieldType.OF3)
    ..aOB(64, _omitFieldNames ? '' : 'beginEditSettings')
    ..aOB(65, _omitFieldNames ? '' : 'commitEditSettings')
    ..aI(94, _omitFieldNames ? '' : 'factoryResetDevice')
    ..aI(95, _omitFieldNames ? '' : 'rebootOtaSeconds')
    ..aOB(96, _omitFieldNames ? '' : 'exitSimulator')
    ..aI(97, _omitFieldNames ? '' : 'rebootSeconds')
    ..aI(98, _omitFieldNames ? '' : 'shutdownSeconds')
    ..aI(99, _omitFieldNames ? '' : 'factoryResetConfig')
    ..aOB(100, _omitFieldNames ? '' : 'nodedbReset')
    ..a<$core.List<$core.int>>(
        101, _omitFieldNames ? '' : 'sessionPasskey', $pb.PbFieldType.OY)
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
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  @$pb.TagNumber(42)
  @$pb.TagNumber(43)
  @$pb.TagNumber(64)
  @$pb.TagNumber(65)
  @$pb.TagNumber(94)
  @$pb.TagNumber(95)
  @$pb.TagNumber(96)
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
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(32)
  @$pb.TagNumber(33)
  @$pb.TagNumber(34)
  @$pb.TagNumber(35)
  @$pb.TagNumber(36)
  @$pb.TagNumber(37)
  @$pb.TagNumber(38)
  @$pb.TagNumber(39)
  @$pb.TagNumber(40)
  @$pb.TagNumber(41)
  @$pb.TagNumber(42)
  @$pb.TagNumber(43)
  @$pb.TagNumber(64)
  @$pb.TagNumber(65)
  @$pb.TagNumber(94)
  @$pb.TagNumber(95)
  @$pb.TagNumber(96)
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

  /// Get config request - use ConfigType enum value
  @$pb.TagNumber(5)
  AdminMessage_ConfigType get getConfigRequest => $_getN(4);
  @$pb.TagNumber(5)
  set getConfigRequest(AdminMessage_ConfigType value) => $_setField(5, value);
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

  /// Get module config request - use ModuleConfigType enum value
  @$pb.TagNumber(7)
  AdminMessage_ModuleConfigType get getModuleConfigRequest => $_getN(6);
  @$pb.TagNumber(7)
  set getModuleConfigRequest(AdminMessage_ModuleConfigType value) =>
      $_setField(7, value);
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

  /// Get canned message module messages request
  @$pb.TagNumber(10)
  $core.bool get getCannedMessageModuleMessagesRequest => $_getBF(8);
  @$pb.TagNumber(10)
  set getCannedMessageModuleMessagesRequest($core.bool value) =>
      $_setBool(8, value);
  @$pb.TagNumber(10)
  $core.bool hasGetCannedMessageModuleMessagesRequest() => $_has(8);
  @$pb.TagNumber(10)
  void clearGetCannedMessageModuleMessagesRequest() => $_clearField(10);

  /// Get canned message module messages response
  @$pb.TagNumber(11)
  $core.String get getCannedMessageModuleMessagesResponse => $_getSZ(9);
  @$pb.TagNumber(11)
  set getCannedMessageModuleMessagesResponse($core.String value) =>
      $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasGetCannedMessageModuleMessagesResponse() => $_has(9);
  @$pb.TagNumber(11)
  void clearGetCannedMessageModuleMessagesResponse() => $_clearField(11);

  /// Get device metadata request
  @$pb.TagNumber(12)
  $core.bool get getDeviceMetadataRequest => $_getBF(10);
  @$pb.TagNumber(12)
  set getDeviceMetadataRequest($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(12)
  $core.bool hasGetDeviceMetadataRequest() => $_has(10);
  @$pb.TagNumber(12)
  void clearGetDeviceMetadataRequest() => $_clearField(12);

  /// Get device metadata response
  @$pb.TagNumber(13)
  DeviceMetadata get getDeviceMetadataResponse => $_getN(11);
  @$pb.TagNumber(13)
  set getDeviceMetadataResponse(DeviceMetadata value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasGetDeviceMetadataResponse() => $_has(11);
  @$pb.TagNumber(13)
  void clearGetDeviceMetadataResponse() => $_clearField(13);
  @$pb.TagNumber(13)
  DeviceMetadata ensureGetDeviceMetadataResponse() => $_ensure(11);

  /// Get ringtone request
  @$pb.TagNumber(14)
  $core.bool get getRingtoneRequest => $_getBF(12);
  @$pb.TagNumber(14)
  set getRingtoneRequest($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(14)
  $core.bool hasGetRingtoneRequest() => $_has(12);
  @$pb.TagNumber(14)
  void clearGetRingtoneRequest() => $_clearField(14);

  /// Get ringtone response
  @$pb.TagNumber(15)
  $core.String get getRingtoneResponse => $_getSZ(13);
  @$pb.TagNumber(15)
  set getRingtoneResponse($core.String value) => $_setString(13, value);
  @$pb.TagNumber(15)
  $core.bool hasGetRingtoneResponse() => $_has(13);
  @$pb.TagNumber(15)
  void clearGetRingtoneResponse() => $_clearField(15);

  /// Get device connection status request
  @$pb.TagNumber(16)
  $core.bool get getDeviceConnectionStatusRequest => $_getBF(14);
  @$pb.TagNumber(16)
  set getDeviceConnectionStatusRequest($core.bool value) =>
      $_setBool(14, value);
  @$pb.TagNumber(16)
  $core.bool hasGetDeviceConnectionStatusRequest() => $_has(14);
  @$pb.TagNumber(16)
  void clearGetDeviceConnectionStatusRequest() => $_clearField(16);

  /// Get device connection status response
  @$pb.TagNumber(17)
  DeviceConnectionStatus get getDeviceConnectionStatusResponse => $_getN(15);
  @$pb.TagNumber(17)
  set getDeviceConnectionStatusResponse(DeviceConnectionStatus value) =>
      $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasGetDeviceConnectionStatusResponse() => $_has(15);
  @$pb.TagNumber(17)
  void clearGetDeviceConnectionStatusResponse() => $_clearField(17);
  @$pb.TagNumber(17)
  DeviceConnectionStatus ensureGetDeviceConnectionStatusResponse() =>
      $_ensure(15);

  /// Setup a node for licensed amateur (ham) radio operation
  @$pb.TagNumber(18)
  HamParameters get setHamMode => $_getN(16);
  @$pb.TagNumber(18)
  set setHamMode(HamParameters value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasSetHamMode() => $_has(16);
  @$pb.TagNumber(18)
  void clearSetHamMode() => $_clearField(18);
  @$pb.TagNumber(18)
  HamParameters ensureSetHamMode() => $_ensure(16);

  /// Get node remote hardware pins request
  @$pb.TagNumber(19)
  $core.bool get getNodeRemoteHardwarePinsRequest => $_getBF(17);
  @$pb.TagNumber(19)
  set getNodeRemoteHardwarePinsRequest($core.bool value) =>
      $_setBool(17, value);
  @$pb.TagNumber(19)
  $core.bool hasGetNodeRemoteHardwarePinsRequest() => $_has(17);
  @$pb.TagNumber(19)
  void clearGetNodeRemoteHardwarePinsRequest() => $_clearField(19);

  /// Get node remote hardware pins response
  @$pb.TagNumber(20)
  NodeRemoteHardwarePinsResponse get getNodeRemoteHardwarePinsResponse =>
      $_getN(18);
  @$pb.TagNumber(20)
  set getNodeRemoteHardwarePinsResponse(NodeRemoteHardwarePinsResponse value) =>
      $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasGetNodeRemoteHardwarePinsResponse() => $_has(18);
  @$pb.TagNumber(20)
  void clearGetNodeRemoteHardwarePinsResponse() => $_clearField(20);
  @$pb.TagNumber(20)
  NodeRemoteHardwarePinsResponse ensureGetNodeRemoteHardwarePinsResponse() =>
      $_ensure(18);

  /// Enter DFU mode request (NRF52 only)
  @$pb.TagNumber(21)
  $core.bool get enterDfuModeRequest => $_getBF(19);
  @$pb.TagNumber(21)
  set enterDfuModeRequest($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(21)
  $core.bool hasEnterDfuModeRequest() => $_has(19);
  @$pb.TagNumber(21)
  void clearEnterDfuModeRequest() => $_clearField(21);

  /// Delete file by path from device
  @$pb.TagNumber(22)
  $core.String get deleteFileRequest => $_getSZ(20);
  @$pb.TagNumber(22)
  set deleteFileRequest($core.String value) => $_setString(20, value);
  @$pb.TagNumber(22)
  $core.bool hasDeleteFileRequest() => $_has(20);
  @$pb.TagNumber(22)
  void clearDeleteFileRequest() => $_clearField(22);

  /// Set zero and offset for scale chips
  @$pb.TagNumber(23)
  $core.int get setScale => $_getIZ(21);
  @$pb.TagNumber(23)
  set setScale($core.int value) => $_setUnsignedInt32(21, value);
  @$pb.TagNumber(23)
  $core.bool hasSetScale() => $_has(21);
  @$pb.TagNumber(23)
  void clearSetScale() => $_clearField(23);

  /// Set owner
  @$pb.TagNumber(32)
  User get setOwner => $_getN(22);
  @$pb.TagNumber(32)
  set setOwner(User value) => $_setField(32, value);
  @$pb.TagNumber(32)
  $core.bool hasSetOwner() => $_has(22);
  @$pb.TagNumber(32)
  void clearSetOwner() => $_clearField(32);
  @$pb.TagNumber(32)
  User ensureSetOwner() => $_ensure(22);

  /// Set channel
  @$pb.TagNumber(33)
  Channel get setChannel => $_getN(23);
  @$pb.TagNumber(33)
  set setChannel(Channel value) => $_setField(33, value);
  @$pb.TagNumber(33)
  $core.bool hasSetChannel() => $_has(23);
  @$pb.TagNumber(33)
  void clearSetChannel() => $_clearField(33);
  @$pb.TagNumber(33)
  Channel ensureSetChannel() => $_ensure(23);

  /// Set config
  @$pb.TagNumber(34)
  Config get setConfig => $_getN(24);
  @$pb.TagNumber(34)
  set setConfig(Config value) => $_setField(34, value);
  @$pb.TagNumber(34)
  $core.bool hasSetConfig() => $_has(24);
  @$pb.TagNumber(34)
  void clearSetConfig() => $_clearField(34);
  @$pb.TagNumber(34)
  Config ensureSetConfig() => $_ensure(24);

  /// Set module config
  @$pb.TagNumber(35)
  ModuleConfig get setModuleConfig => $_getN(25);
  @$pb.TagNumber(35)
  set setModuleConfig(ModuleConfig value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasSetModuleConfig() => $_has(25);
  @$pb.TagNumber(35)
  void clearSetModuleConfig() => $_clearField(35);
  @$pb.TagNumber(35)
  ModuleConfig ensureSetModuleConfig() => $_ensure(25);

  /// Set canned message module messages
  @$pb.TagNumber(36)
  $core.String get setCannedMessageModuleMessages => $_getSZ(26);
  @$pb.TagNumber(36)
  set setCannedMessageModuleMessages($core.String value) =>
      $_setString(26, value);
  @$pb.TagNumber(36)
  $core.bool hasSetCannedMessageModuleMessages() => $_has(26);
  @$pb.TagNumber(36)
  void clearSetCannedMessageModuleMessages() => $_clearField(36);

  /// Set ringtone for external notification
  @$pb.TagNumber(37)
  $core.String get setRingtoneMessage => $_getSZ(27);
  @$pb.TagNumber(37)
  set setRingtoneMessage($core.String value) => $_setString(27, value);
  @$pb.TagNumber(37)
  $core.bool hasSetRingtoneMessage() => $_has(27);
  @$pb.TagNumber(37)
  void clearSetRingtoneMessage() => $_clearField(37);

  /// Remove node by nodenum from NodeDB
  @$pb.TagNumber(38)
  $core.int get removeByNodenum => $_getIZ(28);
  @$pb.TagNumber(38)
  set removeByNodenum($core.int value) => $_setUnsignedInt32(28, value);
  @$pb.TagNumber(38)
  $core.bool hasRemoveByNodenum() => $_has(28);
  @$pb.TagNumber(38)
  void clearRemoveByNodenum() => $_clearField(38);

  /// Set node as favorite
  @$pb.TagNumber(39)
  $core.int get setFavoriteNode => $_getIZ(29);
  @$pb.TagNumber(39)
  set setFavoriteNode($core.int value) => $_setUnsignedInt32(29, value);
  @$pb.TagNumber(39)
  $core.bool hasSetFavoriteNode() => $_has(29);
  @$pb.TagNumber(39)
  void clearSetFavoriteNode() => $_clearField(39);

  /// Remove node from favorites
  @$pb.TagNumber(40)
  $core.int get removeFavoriteNode => $_getIZ(30);
  @$pb.TagNumber(40)
  set removeFavoriteNode($core.int value) => $_setUnsignedInt32(30, value);
  @$pb.TagNumber(40)
  $core.bool hasRemoveFavoriteNode() => $_has(30);
  @$pb.TagNumber(40)
  void clearRemoveFavoriteNode() => $_clearField(40);

  /// Set fixed position
  @$pb.TagNumber(41)
  Position get setFixedPosition => $_getN(31);
  @$pb.TagNumber(41)
  set setFixedPosition(Position value) => $_setField(41, value);
  @$pb.TagNumber(41)
  $core.bool hasSetFixedPosition() => $_has(31);
  @$pb.TagNumber(41)
  void clearSetFixedPosition() => $_clearField(41);
  @$pb.TagNumber(41)
  Position ensureSetFixedPosition() => $_ensure(31);

  /// Remove fixed position
  @$pb.TagNumber(42)
  $core.bool get removeFixedPosition => $_getBF(32);
  @$pb.TagNumber(42)
  set removeFixedPosition($core.bool value) => $_setBool(32, value);
  @$pb.TagNumber(42)
  $core.bool hasRemoveFixedPosition() => $_has(32);
  @$pb.TagNumber(42)
  void clearRemoveFixedPosition() => $_clearField(42);

  /// Set time only
  @$pb.TagNumber(43)
  $core.int get setTimeOnly => $_getIZ(33);
  @$pb.TagNumber(43)
  set setTimeOnly($core.int value) => $_setUnsignedInt32(33, value);
  @$pb.TagNumber(43)
  $core.bool hasSetTimeOnly() => $_has(33);
  @$pb.TagNumber(43)
  void clearSetTimeOnly() => $_clearField(43);

  /// Begin edit settings transaction
  @$pb.TagNumber(64)
  $core.bool get beginEditSettings => $_getBF(34);
  @$pb.TagNumber(64)
  set beginEditSettings($core.bool value) => $_setBool(34, value);
  @$pb.TagNumber(64)
  $core.bool hasBeginEditSettings() => $_has(34);
  @$pb.TagNumber(64)
  void clearBeginEditSettings() => $_clearField(64);

  /// Commit edit settings transaction
  @$pb.TagNumber(65)
  $core.bool get commitEditSettings => $_getBF(35);
  @$pb.TagNumber(65)
  set commitEditSettings($core.bool value) => $_setBool(35, value);
  @$pb.TagNumber(65)
  $core.bool hasCommitEditSettings() => $_has(35);
  @$pb.TagNumber(65)
  void clearCommitEditSettings() => $_clearField(65);

  /// Factory reset device (including BLE bonds)
  @$pb.TagNumber(94)
  $core.int get factoryResetDevice => $_getIZ(36);
  @$pb.TagNumber(94)
  set factoryResetDevice($core.int value) => $_setSignedInt32(36, value);
  @$pb.TagNumber(94)
  $core.bool hasFactoryResetDevice() => $_has(36);
  @$pb.TagNumber(94)
  void clearFactoryResetDevice() => $_clearField(94);

  /// Reboot to OTA firmware in N seconds
  @$pb.TagNumber(95)
  $core.int get rebootOtaSeconds => $_getIZ(37);
  @$pb.TagNumber(95)
  set rebootOtaSeconds($core.int value) => $_setSignedInt32(37, value);
  @$pb.TagNumber(95)
  $core.bool hasRebootOtaSeconds() => $_has(37);
  @$pb.TagNumber(95)
  void clearRebootOtaSeconds() => $_clearField(95);

  /// Exit simulator (Portduino only)
  @$pb.TagNumber(96)
  $core.bool get exitSimulator => $_getBF(38);
  @$pb.TagNumber(96)
  set exitSimulator($core.bool value) => $_setBool(38, value);
  @$pb.TagNumber(96)
  $core.bool hasExitSimulator() => $_has(38);
  @$pb.TagNumber(96)
  void clearExitSimulator() => $_clearField(96);

  /// Reboot in N seconds
  @$pb.TagNumber(97)
  $core.int get rebootSeconds => $_getIZ(39);
  @$pb.TagNumber(97)
  set rebootSeconds($core.int value) => $_setSignedInt32(39, value);
  @$pb.TagNumber(97)
  $core.bool hasRebootSeconds() => $_has(39);
  @$pb.TagNumber(97)
  void clearRebootSeconds() => $_clearField(97);

  /// Shutdown in N seconds
  @$pb.TagNumber(98)
  $core.int get shutdownSeconds => $_getIZ(40);
  @$pb.TagNumber(98)
  set shutdownSeconds($core.int value) => $_setSignedInt32(40, value);
  @$pb.TagNumber(98)
  $core.bool hasShutdownSeconds() => $_has(40);
  @$pb.TagNumber(98)
  void clearShutdownSeconds() => $_clearField(98);

  /// Factory reset config (preserves BLE bonds)
  @$pb.TagNumber(99)
  $core.int get factoryResetConfig => $_getIZ(41);
  @$pb.TagNumber(99)
  set factoryResetConfig($core.int value) => $_setSignedInt32(41, value);
  @$pb.TagNumber(99)
  $core.bool hasFactoryResetConfig() => $_has(41);
  @$pb.TagNumber(99)
  void clearFactoryResetConfig() => $_clearField(99);

  /// Reset nodedb (favorites preserved when true)
  @$pb.TagNumber(100)
  $core.bool get nodedbReset => $_getBF(42);
  @$pb.TagNumber(100)
  set nodedbReset($core.bool value) => $_setBool(42, value);
  @$pb.TagNumber(100)
  $core.bool hasNodedbReset() => $_has(42);
  @$pb.TagNumber(100)
  void clearNodedbReset() => $_clearField(100);

  /// Session passkey for admin message replay attack prevention
  @$pb.TagNumber(101)
  $core.List<$core.int> get sessionPasskey => $_getN(43);
  @$pb.TagNumber(101)
  set sessionPasskey($core.List<$core.int> value) => $_setBytes(43, value);
  @$pb.TagNumber(101)
  $core.bool hasSessionPasskey() => $_has(43);
  @$pb.TagNumber(101)
  void clearSessionPasskey() => $_clearField(101);
}

/// Parameters for amateur radio setup
class HamParameters extends $pb.GeneratedMessage {
  factory HamParameters({
    $core.String? callSign,
    $core.int? txPower,
    $core.double? frequency,
    $core.String? shortName,
  }) {
    final result = create();
    if (callSign != null) result.callSign = callSign;
    if (txPower != null) result.txPower = txPower;
    if (frequency != null) result.frequency = frequency;
    if (shortName != null) result.shortName = shortName;
    return result;
  }

  HamParameters._();

  factory HamParameters.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HamParameters.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HamParameters',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'callSign')
    ..aI(2, _omitFieldNames ? '' : 'txPower')
    ..aD(3, _omitFieldNames ? '' : 'frequency', fieldType: $pb.PbFieldType.OF)
    ..aOS(4, _omitFieldNames ? '' : 'shortName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HamParameters clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HamParameters copyWith(void Function(HamParameters) updates) =>
      super.copyWith((message) => updates(message as HamParameters))
          as HamParameters;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HamParameters create() => HamParameters._();
  @$core.override
  HamParameters createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HamParameters getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HamParameters>(create);
  static HamParameters? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get callSign => $_getSZ(0);
  @$pb.TagNumber(1)
  set callSign($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCallSign() => $_has(0);
  @$pb.TagNumber(1)
  void clearCallSign() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get txPower => $_getIZ(1);
  @$pb.TagNumber(2)
  set txPower($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTxPower() => $_has(1);
  @$pb.TagNumber(2)
  void clearTxPower() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get frequency => $_getN(2);
  @$pb.TagNumber(3)
  set frequency($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFrequency() => $_has(2);
  @$pb.TagNumber(3)
  void clearFrequency() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get shortName => $_getSZ(3);
  @$pb.TagNumber(4)
  set shortName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShortName() => $_has(3);
  @$pb.TagNumber(4)
  void clearShortName() => $_clearField(4);
}

/// Device connection status
class DeviceConnectionStatus extends $pb.GeneratedMessage {
  factory DeviceConnectionStatus({
    $core.bool? wifiConnected,
    $core.bool? ethernetConnected,
    $core.bool? bluetoothConnected,
    $core.bool? serialConnected,
  }) {
    final result = create();
    if (wifiConnected != null) result.wifiConnected = wifiConnected;
    if (ethernetConnected != null) result.ethernetConnected = ethernetConnected;
    if (bluetoothConnected != null)
      result.bluetoothConnected = bluetoothConnected;
    if (serialConnected != null) result.serialConnected = serialConnected;
    return result;
  }

  DeviceConnectionStatus._();

  factory DeviceConnectionStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceConnectionStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceConnectionStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'wifiConnected')
    ..aOB(2, _omitFieldNames ? '' : 'ethernetConnected')
    ..aOB(3, _omitFieldNames ? '' : 'bluetoothConnected')
    ..aOB(4, _omitFieldNames ? '' : 'serialConnected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceConnectionStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceConnectionStatus copyWith(
          void Function(DeviceConnectionStatus) updates) =>
      super.copyWith((message) => updates(message as DeviceConnectionStatus))
          as DeviceConnectionStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceConnectionStatus create() => DeviceConnectionStatus._();
  @$core.override
  DeviceConnectionStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceConnectionStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceConnectionStatus>(create);
  static DeviceConnectionStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get wifiConnected => $_getBF(0);
  @$pb.TagNumber(1)
  set wifiConnected($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWifiConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearWifiConnected() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get ethernetConnected => $_getBF(1);
  @$pb.TagNumber(2)
  set ethernetConnected($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEthernetConnected() => $_has(1);
  @$pb.TagNumber(2)
  void clearEthernetConnected() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get bluetoothConnected => $_getBF(2);
  @$pb.TagNumber(3)
  set bluetoothConnected($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBluetoothConnected() => $_has(2);
  @$pb.TagNumber(3)
  void clearBluetoothConnected() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get serialConnected => $_getBF(3);
  @$pb.TagNumber(4)
  set serialConnected($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSerialConnected() => $_has(3);
  @$pb.TagNumber(4)
  void clearSerialConnected() => $_clearField(4);
}

/// Device metadata
class DeviceMetadata extends $pb.GeneratedMessage {
  factory DeviceMetadata({
    $core.String? firmwareVersion,
    $core.int? deviceStateVersion,
    $core.bool? canShutdown,
    $core.bool? hasWifi,
    $core.bool? hasBluetooth,
    $core.bool? hasEthernet,
    Config_DeviceConfig_Role? role,
    $core.int? positionFlags,
    HardwareModel? hwModel,
    $core.bool? hasRemoteHardware,
    $core.bool? hasPkc,
  }) {
    final result = create();
    if (firmwareVersion != null) result.firmwareVersion = firmwareVersion;
    if (deviceStateVersion != null)
      result.deviceStateVersion = deviceStateVersion;
    if (canShutdown != null) result.canShutdown = canShutdown;
    if (hasWifi != null) result.hasWifi = hasWifi;
    if (hasBluetooth != null) result.hasBluetooth = hasBluetooth;
    if (hasEthernet != null) result.hasEthernet = hasEthernet;
    if (role != null) result.role = role;
    if (positionFlags != null) result.positionFlags = positionFlags;
    if (hwModel != null) result.hwModel = hwModel;
    if (hasRemoteHardware != null) result.hasRemoteHardware = hasRemoteHardware;
    if (hasPkc != null) result.hasPkc = hasPkc;
    return result;
  }

  DeviceMetadata._();

  factory DeviceMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'firmwareVersion')
    ..aI(2, _omitFieldNames ? '' : 'deviceStateVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'canShutdown')
    ..aOB(4, _omitFieldNames ? '' : 'hasWifi')
    ..aOB(5, _omitFieldNames ? '' : 'hasBluetooth')
    ..aOB(6, _omitFieldNames ? '' : 'hasEthernet')
    ..aE<Config_DeviceConfig_Role>(7, _omitFieldNames ? '' : 'role',
        enumValues: Config_DeviceConfig_Role.values)
    ..aI(8, _omitFieldNames ? '' : 'positionFlags',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<HardwareModel>(9, _omitFieldNames ? '' : 'hwModel',
        enumValues: HardwareModel.values)
    ..aOB(10, _omitFieldNames ? '' : 'hasRemoteHardware')
    ..aOB(11, _omitFieldNames ? '' : 'hasPkc')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceMetadata copyWith(void Function(DeviceMetadata) updates) =>
      super.copyWith((message) => updates(message as DeviceMetadata))
          as DeviceMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceMetadata create() => DeviceMetadata._();
  @$core.override
  DeviceMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceMetadata>(create);
  static DeviceMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get firmwareVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set firmwareVersion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFirmwareVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearFirmwareVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get deviceStateVersion => $_getIZ(1);
  @$pb.TagNumber(2)
  set deviceStateVersion($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceStateVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceStateVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get canShutdown => $_getBF(2);
  @$pb.TagNumber(3)
  set canShutdown($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCanShutdown() => $_has(2);
  @$pb.TagNumber(3)
  void clearCanShutdown() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get hasWifi => $_getBF(3);
  @$pb.TagNumber(4)
  set hasWifi($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHasWifi() => $_has(3);
  @$pb.TagNumber(4)
  void clearHasWifi() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get hasBluetooth => $_getBF(4);
  @$pb.TagNumber(5)
  set hasBluetooth($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHasBluetooth() => $_has(4);
  @$pb.TagNumber(5)
  void clearHasBluetooth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get hasEthernet => $_getBF(5);
  @$pb.TagNumber(6)
  set hasEthernet($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHasEthernet() => $_has(5);
  @$pb.TagNumber(6)
  void clearHasEthernet() => $_clearField(6);

  @$pb.TagNumber(7)
  Config_DeviceConfig_Role get role => $_getN(6);
  @$pb.TagNumber(7)
  set role(Config_DeviceConfig_Role value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRole() => $_has(6);
  @$pb.TagNumber(7)
  void clearRole() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get positionFlags => $_getIZ(7);
  @$pb.TagNumber(8)
  set positionFlags($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPositionFlags() => $_has(7);
  @$pb.TagNumber(8)
  void clearPositionFlags() => $_clearField(8);

  @$pb.TagNumber(9)
  HardwareModel get hwModel => $_getN(8);
  @$pb.TagNumber(9)
  set hwModel(HardwareModel value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasHwModel() => $_has(8);
  @$pb.TagNumber(9)
  void clearHwModel() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get hasRemoteHardware => $_getBF(9);
  @$pb.TagNumber(10)
  set hasRemoteHardware($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasHasRemoteHardware() => $_has(9);
  @$pb.TagNumber(10)
  void clearHasRemoteHardware() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get hasPkc => $_getBF(10);
  @$pb.TagNumber(11)
  set hasPkc($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHasPkc() => $_has(10);
  @$pb.TagNumber(11)
  void clearHasPkc() => $_clearField(11);
}

/// Node remote hardware pin
class NodeRemoteHardwarePin extends $pb.GeneratedMessage {
  factory NodeRemoteHardwarePin({
    $core.int? nodeNum,
    RemoteHardwarePin? pin,
  }) {
    final result = create();
    if (nodeNum != null) result.nodeNum = nodeNum;
    if (pin != null) result.pin = pin;
    return result;
  }

  NodeRemoteHardwarePin._();

  factory NodeRemoteHardwarePin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeRemoteHardwarePin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeRemoteHardwarePin',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'nodeNum', fieldType: $pb.PbFieldType.OU3)
    ..aOM<RemoteHardwarePin>(2, _omitFieldNames ? '' : 'pin',
        subBuilder: RemoteHardwarePin.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRemoteHardwarePin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRemoteHardwarePin copyWith(
          void Function(NodeRemoteHardwarePin) updates) =>
      super.copyWith((message) => updates(message as NodeRemoteHardwarePin))
          as NodeRemoteHardwarePin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeRemoteHardwarePin create() => NodeRemoteHardwarePin._();
  @$core.override
  NodeRemoteHardwarePin createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeRemoteHardwarePin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeRemoteHardwarePin>(create);
  static NodeRemoteHardwarePin? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get nodeNum => $_getIZ(0);
  @$pb.TagNumber(1)
  set nodeNum($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeNum() => $_clearField(1);

  @$pb.TagNumber(2)
  RemoteHardwarePin get pin => $_getN(1);
  @$pb.TagNumber(2)
  set pin(RemoteHardwarePin value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPin() => $_has(1);
  @$pb.TagNumber(2)
  void clearPin() => $_clearField(2);
  @$pb.TagNumber(2)
  RemoteHardwarePin ensurePin() => $_ensure(1);
}

/// Remote hardware pin definition
class RemoteHardwarePin extends $pb.GeneratedMessage {
  factory RemoteHardwarePin({
    $core.int? gpioPin,
    $core.String? name,
    RemoteHardwarePinType? type,
  }) {
    final result = create();
    if (gpioPin != null) result.gpioPin = gpioPin;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    return result;
  }

  RemoteHardwarePin._();

  factory RemoteHardwarePin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoteHardwarePin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoteHardwarePin',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gpioPin', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<RemoteHardwarePinType>(3, _omitFieldNames ? '' : 'type',
        enumValues: RemoteHardwarePinType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteHardwarePin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteHardwarePin copyWith(void Function(RemoteHardwarePin) updates) =>
      super.copyWith((message) => updates(message as RemoteHardwarePin))
          as RemoteHardwarePin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoteHardwarePin create() => RemoteHardwarePin._();
  @$core.override
  RemoteHardwarePin createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoteHardwarePin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteHardwarePin>(create);
  static RemoteHardwarePin? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gpioPin => $_getIZ(0);
  @$pb.TagNumber(1)
  set gpioPin($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGpioPin() => $_has(0);
  @$pb.TagNumber(1)
  void clearGpioPin() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  RemoteHardwarePinType get type => $_getN(2);
  @$pb.TagNumber(3)
  set type(RemoteHardwarePinType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);
}

/// Response for node remote hardware pins
class NodeRemoteHardwarePinsResponse extends $pb.GeneratedMessage {
  factory NodeRemoteHardwarePinsResponse({
    $core.Iterable<NodeRemoteHardwarePin>? nodeRemoteHardwarePins,
  }) {
    final result = create();
    if (nodeRemoteHardwarePins != null)
      result.nodeRemoteHardwarePins.addAll(nodeRemoteHardwarePins);
    return result;
  }

  NodeRemoteHardwarePinsResponse._();

  factory NodeRemoteHardwarePinsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeRemoteHardwarePinsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeRemoteHardwarePinsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..pPM<NodeRemoteHardwarePin>(
        1, _omitFieldNames ? '' : 'nodeRemoteHardwarePins',
        subBuilder: NodeRemoteHardwarePin.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRemoteHardwarePinsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRemoteHardwarePinsResponse copyWith(
          void Function(NodeRemoteHardwarePinsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as NodeRemoteHardwarePinsResponse))
          as NodeRemoteHardwarePinsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeRemoteHardwarePinsResponse create() =>
      NodeRemoteHardwarePinsResponse._();
  @$core.override
  NodeRemoteHardwarePinsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeRemoteHardwarePinsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeRemoteHardwarePinsResponse>(create);
  static NodeRemoteHardwarePinsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<NodeRemoteHardwarePin> get nodeRemoteHardwarePins => $_getList(0);
}

class Config_DeviceConfig extends $pb.GeneratedMessage {
  factory Config_DeviceConfig({
    Config_DeviceConfig_Role_? role,
    $core.bool? serialEnabled,
    $core.int? buttonGpio,
    $core.int? buzzerGpio,
    Config_DeviceConfig_RebroadcastMode? rebroadcastMode,
    $core.int? nodeInfoBroadcastSecs,
    $core.bool? doubleTapAsButtonPress,
    $core.bool? isManaged,
    $core.bool? disableTripleClick,
    $core.String? tzdef,
    $core.bool? ledHeartbeatDisabled,
  }) {
    final result = create();
    if (role != null) result.role = role;
    if (serialEnabled != null) result.serialEnabled = serialEnabled;
    if (buttonGpio != null) result.buttonGpio = buttonGpio;
    if (buzzerGpio != null) result.buzzerGpio = buzzerGpio;
    if (rebroadcastMode != null) result.rebroadcastMode = rebroadcastMode;
    if (nodeInfoBroadcastSecs != null)
      result.nodeInfoBroadcastSecs = nodeInfoBroadcastSecs;
    if (doubleTapAsButtonPress != null)
      result.doubleTapAsButtonPress = doubleTapAsButtonPress;
    if (isManaged != null) result.isManaged = isManaged;
    if (disableTripleClick != null)
      result.disableTripleClick = disableTripleClick;
    if (tzdef != null) result.tzdef = tzdef;
    if (ledHeartbeatDisabled != null)
      result.ledHeartbeatDisabled = ledHeartbeatDisabled;
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
    ..aE<Config_DeviceConfig_Role_>(1, _omitFieldNames ? '' : 'role',
        enumValues: Config_DeviceConfig_Role_.values)
    ..aOB(2, _omitFieldNames ? '' : 'serialEnabled')
    ..aI(4, _omitFieldNames ? '' : 'buttonGpio', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'buzzerGpio', fieldType: $pb.PbFieldType.OU3)
    ..aE<Config_DeviceConfig_RebroadcastMode>(
        6, _omitFieldNames ? '' : 'rebroadcastMode',
        enumValues: Config_DeviceConfig_RebroadcastMode.values)
    ..aI(7, _omitFieldNames ? '' : 'nodeInfoBroadcastSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'doubleTapAsButtonPress')
    ..aOB(9, _omitFieldNames ? '' : 'isManaged')
    ..aOB(10, _omitFieldNames ? '' : 'disableTripleClick')
    ..aOS(11, _omitFieldNames ? '' : 'tzdef')
    ..aOB(12, _omitFieldNames ? '' : 'ledHeartbeatDisabled')
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
  Config_DeviceConfig_Role_ get role => $_getN(0);
  @$pb.TagNumber(1)
  set role(Config_DeviceConfig_Role_ value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearRole() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get serialEnabled => $_getBF(1);
  @$pb.TagNumber(2)
  set serialEnabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSerialEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearSerialEnabled() => $_clearField(2);

  @$pb.TagNumber(4)
  $core.int get buttonGpio => $_getIZ(2);
  @$pb.TagNumber(4)
  set buttonGpio($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(4)
  $core.bool hasButtonGpio() => $_has(2);
  @$pb.TagNumber(4)
  void clearButtonGpio() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get buzzerGpio => $_getIZ(3);
  @$pb.TagNumber(5)
  set buzzerGpio($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasBuzzerGpio() => $_has(3);
  @$pb.TagNumber(5)
  void clearBuzzerGpio() => $_clearField(5);

  @$pb.TagNumber(6)
  Config_DeviceConfig_RebroadcastMode get rebroadcastMode => $_getN(4);
  @$pb.TagNumber(6)
  set rebroadcastMode(Config_DeviceConfig_RebroadcastMode value) =>
      $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRebroadcastMode() => $_has(4);
  @$pb.TagNumber(6)
  void clearRebroadcastMode() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get nodeInfoBroadcastSecs => $_getIZ(5);
  @$pb.TagNumber(7)
  set nodeInfoBroadcastSecs($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(7)
  $core.bool hasNodeInfoBroadcastSecs() => $_has(5);
  @$pb.TagNumber(7)
  void clearNodeInfoBroadcastSecs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get doubleTapAsButtonPress => $_getBF(6);
  @$pb.TagNumber(8)
  set doubleTapAsButtonPress($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(8)
  $core.bool hasDoubleTapAsButtonPress() => $_has(6);
  @$pb.TagNumber(8)
  void clearDoubleTapAsButtonPress() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isManaged => $_getBF(7);
  @$pb.TagNumber(9)
  set isManaged($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(9)
  $core.bool hasIsManaged() => $_has(7);
  @$pb.TagNumber(9)
  void clearIsManaged() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get disableTripleClick => $_getBF(8);
  @$pb.TagNumber(10)
  set disableTripleClick($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(10)
  $core.bool hasDisableTripleClick() => $_has(8);
  @$pb.TagNumber(10)
  void clearDisableTripleClick() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get tzdef => $_getSZ(9);
  @$pb.TagNumber(11)
  set tzdef($core.String value) => $_setString(9, value);
  @$pb.TagNumber(11)
  $core.bool hasTzdef() => $_has(9);
  @$pb.TagNumber(11)
  void clearTzdef() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get ledHeartbeatDisabled => $_getBF(10);
  @$pb.TagNumber(12)
  set ledHeartbeatDisabled($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(12)
  $core.bool hasLedHeartbeatDisabled() => $_has(10);
  @$pb.TagNumber(12)
  void clearLedHeartbeatDisabled() => $_clearField(12);
}

class Config_PositionConfig extends $pb.GeneratedMessage {
  factory Config_PositionConfig({
    $core.int? positionBroadcastSecs,
    $core.bool? positionBroadcastSmartEnabled,
    $core.bool? fixedPosition,
    $core.bool? gpsEnabled,
    $core.int? gpsUpdateInterval,
    $core.int? gpsAttemptTime,
    $core.int? positionFlags,
    $core.int? rxGpio,
    $core.int? txGpio,
    $core.int? broadcastSmartMinimumDistance,
    $core.int? broadcastSmartMinimumIntervalSecs,
    $core.int? gpsEnGpio,
    Config_PositionConfig_GpsMode? gpsMode,
  }) {
    final result = create();
    if (positionBroadcastSecs != null)
      result.positionBroadcastSecs = positionBroadcastSecs;
    if (positionBroadcastSmartEnabled != null)
      result.positionBroadcastSmartEnabled = positionBroadcastSmartEnabled;
    if (fixedPosition != null) result.fixedPosition = fixedPosition;
    if (gpsEnabled != null) result.gpsEnabled = gpsEnabled;
    if (gpsUpdateInterval != null) result.gpsUpdateInterval = gpsUpdateInterval;
    if (gpsAttemptTime != null) result.gpsAttemptTime = gpsAttemptTime;
    if (positionFlags != null) result.positionFlags = positionFlags;
    if (rxGpio != null) result.rxGpio = rxGpio;
    if (txGpio != null) result.txGpio = txGpio;
    if (broadcastSmartMinimumDistance != null)
      result.broadcastSmartMinimumDistance = broadcastSmartMinimumDistance;
    if (broadcastSmartMinimumIntervalSecs != null)
      result.broadcastSmartMinimumIntervalSecs =
          broadcastSmartMinimumIntervalSecs;
    if (gpsEnGpio != null) result.gpsEnGpio = gpsEnGpio;
    if (gpsMode != null) result.gpsMode = gpsMode;
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
    ..aI(1, _omitFieldNames ? '' : 'positionBroadcastSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'positionBroadcastSmartEnabled')
    ..aOB(3, _omitFieldNames ? '' : 'fixedPosition')
    ..aOB(4, _omitFieldNames ? '' : 'gpsEnabled')
    ..aI(5, _omitFieldNames ? '' : 'gpsUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'gpsAttemptTime',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'positionFlags',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'rxGpio', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'txGpio', fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'broadcastSmartMinimumDistance',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'broadcastSmartMinimumIntervalSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(12, _omitFieldNames ? '' : 'gpsEnGpio', fieldType: $pb.PbFieldType.OU3)
    ..aE<Config_PositionConfig_GpsMode>(13, _omitFieldNames ? '' : 'gpsMode',
        enumValues: Config_PositionConfig_GpsMode.values)
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
  $core.int get positionBroadcastSecs => $_getIZ(0);
  @$pb.TagNumber(1)
  set positionBroadcastSecs($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPositionBroadcastSecs() => $_has(0);
  @$pb.TagNumber(1)
  void clearPositionBroadcastSecs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get positionBroadcastSmartEnabled => $_getBF(1);
  @$pb.TagNumber(2)
  set positionBroadcastSmartEnabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPositionBroadcastSmartEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearPositionBroadcastSmartEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get fixedPosition => $_getBF(2);
  @$pb.TagNumber(3)
  set fixedPosition($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFixedPosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearFixedPosition() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get gpsEnabled => $_getBF(3);
  @$pb.TagNumber(4)
  set gpsEnabled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGpsEnabled() => $_has(3);
  @$pb.TagNumber(4)
  void clearGpsEnabled() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get gpsUpdateInterval => $_getIZ(4);
  @$pb.TagNumber(5)
  set gpsUpdateInterval($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGpsUpdateInterval() => $_has(4);
  @$pb.TagNumber(5)
  void clearGpsUpdateInterval() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get gpsAttemptTime => $_getIZ(5);
  @$pb.TagNumber(6)
  set gpsAttemptTime($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGpsAttemptTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearGpsAttemptTime() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get positionFlags => $_getIZ(6);
  @$pb.TagNumber(7)
  set positionFlags($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPositionFlags() => $_has(6);
  @$pb.TagNumber(7)
  void clearPositionFlags() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get rxGpio => $_getIZ(7);
  @$pb.TagNumber(8)
  set rxGpio($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRxGpio() => $_has(7);
  @$pb.TagNumber(8)
  void clearRxGpio() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get txGpio => $_getIZ(8);
  @$pb.TagNumber(9)
  set txGpio($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTxGpio() => $_has(8);
  @$pb.TagNumber(9)
  void clearTxGpio() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get broadcastSmartMinimumDistance => $_getIZ(9);
  @$pb.TagNumber(10)
  set broadcastSmartMinimumDistance($core.int value) =>
      $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBroadcastSmartMinimumDistance() => $_has(9);
  @$pb.TagNumber(10)
  void clearBroadcastSmartMinimumDistance() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get broadcastSmartMinimumIntervalSecs => $_getIZ(10);
  @$pb.TagNumber(11)
  set broadcastSmartMinimumIntervalSecs($core.int value) =>
      $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasBroadcastSmartMinimumIntervalSecs() => $_has(10);
  @$pb.TagNumber(11)
  void clearBroadcastSmartMinimumIntervalSecs() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get gpsEnGpio => $_getIZ(11);
  @$pb.TagNumber(12)
  set gpsEnGpio($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasGpsEnGpio() => $_has(11);
  @$pb.TagNumber(12)
  void clearGpsEnGpio() => $_clearField(12);

  @$pb.TagNumber(13)
  Config_PositionConfig_GpsMode get gpsMode => $_getN(12);
  @$pb.TagNumber(13)
  set gpsMode(Config_PositionConfig_GpsMode value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasGpsMode() => $_has(12);
  @$pb.TagNumber(13)
  void clearGpsMode() => $_clearField(13);
}

class Config_PowerConfig extends $pb.GeneratedMessage {
  factory Config_PowerConfig({
    $core.bool? isPowerSaving,
    $core.int? onBatteryShutdownAfterSecs,
    $core.double? adcMultiplierOverride,
    $core.int? waitBluetoothSecs,
    $core.int? sdsSecs,
    $core.int? lsSecs,
    $core.int? minWakeSecs,
    $core.int? deviceBatteryInaAddress,
    $fixnum.Int64? powermonEnables,
  }) {
    final result = create();
    if (isPowerSaving != null) result.isPowerSaving = isPowerSaving;
    if (onBatteryShutdownAfterSecs != null)
      result.onBatteryShutdownAfterSecs = onBatteryShutdownAfterSecs;
    if (adcMultiplierOverride != null)
      result.adcMultiplierOverride = adcMultiplierOverride;
    if (waitBluetoothSecs != null) result.waitBluetoothSecs = waitBluetoothSecs;
    if (sdsSecs != null) result.sdsSecs = sdsSecs;
    if (lsSecs != null) result.lsSecs = lsSecs;
    if (minWakeSecs != null) result.minWakeSecs = minWakeSecs;
    if (deviceBatteryInaAddress != null)
      result.deviceBatteryInaAddress = deviceBatteryInaAddress;
    if (powermonEnables != null) result.powermonEnables = powermonEnables;
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
    ..aI(2, _omitFieldNames ? '' : 'onBatteryShutdownAfterSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(3, _omitFieldNames ? '' : 'adcMultiplierOverride',
        fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'waitBluetoothSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'sdsSecs', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'lsSecs', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'minWakeSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'deviceBatteryInaAddress',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        32, _omitFieldNames ? '' : 'powermonEnables', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
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

  @$pb.TagNumber(2)
  $core.int get onBatteryShutdownAfterSecs => $_getIZ(1);
  @$pb.TagNumber(2)
  set onBatteryShutdownAfterSecs($core.int value) =>
      $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOnBatteryShutdownAfterSecs() => $_has(1);
  @$pb.TagNumber(2)
  void clearOnBatteryShutdownAfterSecs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get adcMultiplierOverride => $_getN(2);
  @$pb.TagNumber(3)
  set adcMultiplierOverride($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAdcMultiplierOverride() => $_has(2);
  @$pb.TagNumber(3)
  void clearAdcMultiplierOverride() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get waitBluetoothSecs => $_getIZ(3);
  @$pb.TagNumber(4)
  set waitBluetoothSecs($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWaitBluetoothSecs() => $_has(3);
  @$pb.TagNumber(4)
  void clearWaitBluetoothSecs() => $_clearField(4);

  @$pb.TagNumber(6)
  $core.int get sdsSecs => $_getIZ(4);
  @$pb.TagNumber(6)
  set sdsSecs($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(6)
  $core.bool hasSdsSecs() => $_has(4);
  @$pb.TagNumber(6)
  void clearSdsSecs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get lsSecs => $_getIZ(5);
  @$pb.TagNumber(7)
  set lsSecs($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(7)
  $core.bool hasLsSecs() => $_has(5);
  @$pb.TagNumber(7)
  void clearLsSecs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get minWakeSecs => $_getIZ(6);
  @$pb.TagNumber(8)
  set minWakeSecs($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(8)
  $core.bool hasMinWakeSecs() => $_has(6);
  @$pb.TagNumber(8)
  void clearMinWakeSecs() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get deviceBatteryInaAddress => $_getIZ(7);
  @$pb.TagNumber(9)
  set deviceBatteryInaAddress($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(9)
  $core.bool hasDeviceBatteryInaAddress() => $_has(7);
  @$pb.TagNumber(9)
  void clearDeviceBatteryInaAddress() => $_clearField(9);

  @$pb.TagNumber(32)
  $fixnum.Int64 get powermonEnables => $_getI64(8);
  @$pb.TagNumber(32)
  set powermonEnables($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(32)
  $core.bool hasPowermonEnables() => $_has(8);
  @$pb.TagNumber(32)
  void clearPowermonEnables() => $_clearField(32);
}

class Config_NetworkConfig_IpV4Config extends $pb.GeneratedMessage {
  factory Config_NetworkConfig_IpV4Config({
    $core.int? ip,
    $core.int? gateway,
    $core.int? subnet,
    $core.int? dns,
  }) {
    final result = create();
    if (ip != null) result.ip = ip;
    if (gateway != null) result.gateway = gateway;
    if (subnet != null) result.subnet = subnet;
    if (dns != null) result.dns = dns;
    return result;
  }

  Config_NetworkConfig_IpV4Config._();

  factory Config_NetworkConfig_IpV4Config.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_NetworkConfig_IpV4Config.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.NetworkConfig.IpV4Config',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'ip', fieldType: $pb.PbFieldType.OF3)
    ..aI(2, _omitFieldNames ? '' : 'gateway', fieldType: $pb.PbFieldType.OF3)
    ..aI(3, _omitFieldNames ? '' : 'subnet', fieldType: $pb.PbFieldType.OF3)
    ..aI(4, _omitFieldNames ? '' : 'dns', fieldType: $pb.PbFieldType.OF3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_NetworkConfig_IpV4Config clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_NetworkConfig_IpV4Config copyWith(
          void Function(Config_NetworkConfig_IpV4Config) updates) =>
      super.copyWith(
              (message) => updates(message as Config_NetworkConfig_IpV4Config))
          as Config_NetworkConfig_IpV4Config;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_NetworkConfig_IpV4Config create() =>
      Config_NetworkConfig_IpV4Config._();
  @$core.override
  Config_NetworkConfig_IpV4Config createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_NetworkConfig_IpV4Config getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_NetworkConfig_IpV4Config>(
          create);
  static Config_NetworkConfig_IpV4Config? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get ip => $_getIZ(0);
  @$pb.TagNumber(1)
  set ip($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIp() => $_has(0);
  @$pb.TagNumber(1)
  void clearIp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get gateway => $_getIZ(1);
  @$pb.TagNumber(2)
  set gateway($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGateway() => $_has(1);
  @$pb.TagNumber(2)
  void clearGateway() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get subnet => $_getIZ(2);
  @$pb.TagNumber(3)
  set subnet($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubnet() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubnet() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get dns => $_getIZ(3);
  @$pb.TagNumber(4)
  set dns($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDns() => $_has(3);
  @$pb.TagNumber(4)
  void clearDns() => $_clearField(4);
}

class Config_NetworkConfig extends $pb.GeneratedMessage {
  factory Config_NetworkConfig({
    $core.bool? wifiEnabled,
    $core.String? wifiSsid,
    $core.String? wifiPsk,
    $core.String? ntpServer,
    $core.bool? ethEnabled,
    Config_NetworkConfig_AddressMode? addressMode,
    Config_NetworkConfig_IpV4Config? ipv4Config,
    $core.String? rsyslogServer,
    $core.int? enabledProtocols,
    $core.bool? ipv6Enabled,
  }) {
    final result = create();
    if (wifiEnabled != null) result.wifiEnabled = wifiEnabled;
    if (wifiSsid != null) result.wifiSsid = wifiSsid;
    if (wifiPsk != null) result.wifiPsk = wifiPsk;
    if (ntpServer != null) result.ntpServer = ntpServer;
    if (ethEnabled != null) result.ethEnabled = ethEnabled;
    if (addressMode != null) result.addressMode = addressMode;
    if (ipv4Config != null) result.ipv4Config = ipv4Config;
    if (rsyslogServer != null) result.rsyslogServer = rsyslogServer;
    if (enabledProtocols != null) result.enabledProtocols = enabledProtocols;
    if (ipv6Enabled != null) result.ipv6Enabled = ipv6Enabled;
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
    ..aOS(3, _omitFieldNames ? '' : 'wifiSsid')
    ..aOS(4, _omitFieldNames ? '' : 'wifiPsk')
    ..aOS(5, _omitFieldNames ? '' : 'ntpServer')
    ..aOB(6, _omitFieldNames ? '' : 'ethEnabled')
    ..aE<Config_NetworkConfig_AddressMode>(
        7, _omitFieldNames ? '' : 'addressMode',
        enumValues: Config_NetworkConfig_AddressMode.values)
    ..aOM<Config_NetworkConfig_IpV4Config>(
        8, _omitFieldNames ? '' : 'ipv4Config',
        subBuilder: Config_NetworkConfig_IpV4Config.create)
    ..aOS(9, _omitFieldNames ? '' : 'rsyslogServer')
    ..aI(10, _omitFieldNames ? '' : 'enabledProtocols',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(11, _omitFieldNames ? '' : 'ipv6Enabled')
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

  @$pb.TagNumber(3)
  $core.String get wifiSsid => $_getSZ(1);
  @$pb.TagNumber(3)
  set wifiSsid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasWifiSsid() => $_has(1);
  @$pb.TagNumber(3)
  void clearWifiSsid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get wifiPsk => $_getSZ(2);
  @$pb.TagNumber(4)
  set wifiPsk($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasWifiPsk() => $_has(2);
  @$pb.TagNumber(4)
  void clearWifiPsk() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get ntpServer => $_getSZ(3);
  @$pb.TagNumber(5)
  set ntpServer($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasNtpServer() => $_has(3);
  @$pb.TagNumber(5)
  void clearNtpServer() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get ethEnabled => $_getBF(4);
  @$pb.TagNumber(6)
  set ethEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(6)
  $core.bool hasEthEnabled() => $_has(4);
  @$pb.TagNumber(6)
  void clearEthEnabled() => $_clearField(6);

  @$pb.TagNumber(7)
  Config_NetworkConfig_AddressMode get addressMode => $_getN(5);
  @$pb.TagNumber(7)
  set addressMode(Config_NetworkConfig_AddressMode value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasAddressMode() => $_has(5);
  @$pb.TagNumber(7)
  void clearAddressMode() => $_clearField(7);

  @$pb.TagNumber(8)
  Config_NetworkConfig_IpV4Config get ipv4Config => $_getN(6);
  @$pb.TagNumber(8)
  set ipv4Config(Config_NetworkConfig_IpV4Config value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasIpv4Config() => $_has(6);
  @$pb.TagNumber(8)
  void clearIpv4Config() => $_clearField(8);
  @$pb.TagNumber(8)
  Config_NetworkConfig_IpV4Config ensureIpv4Config() => $_ensure(6);

  @$pb.TagNumber(9)
  $core.String get rsyslogServer => $_getSZ(7);
  @$pb.TagNumber(9)
  set rsyslogServer($core.String value) => $_setString(7, value);
  @$pb.TagNumber(9)
  $core.bool hasRsyslogServer() => $_has(7);
  @$pb.TagNumber(9)
  void clearRsyslogServer() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get enabledProtocols => $_getIZ(8);
  @$pb.TagNumber(10)
  set enabledProtocols($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(10)
  $core.bool hasEnabledProtocols() => $_has(8);
  @$pb.TagNumber(10)
  void clearEnabledProtocols() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get ipv6Enabled => $_getBF(9);
  @$pb.TagNumber(11)
  set ipv6Enabled($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(11)
  $core.bool hasIpv6Enabled() => $_has(9);
  @$pb.TagNumber(11)
  void clearIpv6Enabled() => $_clearField(11);
}

class Config_DisplayConfig extends $pb.GeneratedMessage {
  factory Config_DisplayConfig({
    $core.int? screenOnSecs,
    $core.int? gpsFormat,
    $core.int? autoScreenCarouselSecs,
    $core.bool? compassNorthTop,
    $core.bool? flipScreen,
    Config_DisplayConfig_DisplayUnits? units,
    Config_DisplayConfig_OledType? oled,
    Config_DisplayConfig_DisplayMode? displaymode,
    $core.bool? headingBold,
    $core.bool? wakeOnTapOrMotion,
    Config_DisplayConfig_CompassOrientation? compassOrientation,
    $core.bool? use12hClock,
    $core.bool? useLongNodeName,
  }) {
    final result = create();
    if (screenOnSecs != null) result.screenOnSecs = screenOnSecs;
    if (gpsFormat != null) result.gpsFormat = gpsFormat;
    if (autoScreenCarouselSecs != null)
      result.autoScreenCarouselSecs = autoScreenCarouselSecs;
    if (compassNorthTop != null) result.compassNorthTop = compassNorthTop;
    if (flipScreen != null) result.flipScreen = flipScreen;
    if (units != null) result.units = units;
    if (oled != null) result.oled = oled;
    if (displaymode != null) result.displaymode = displaymode;
    if (headingBold != null) result.headingBold = headingBold;
    if (wakeOnTapOrMotion != null) result.wakeOnTapOrMotion = wakeOnTapOrMotion;
    if (compassOrientation != null)
      result.compassOrientation = compassOrientation;
    if (use12hClock != null) result.use12hClock = use12hClock;
    if (useLongNodeName != null) result.useLongNodeName = useLongNodeName;
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
    ..aI(2, _omitFieldNames ? '' : 'gpsFormat', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'autoScreenCarouselSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'compassNorthTop')
    ..aOB(5, _omitFieldNames ? '' : 'flipScreen')
    ..aE<Config_DisplayConfig_DisplayUnits>(6, _omitFieldNames ? '' : 'units',
        enumValues: Config_DisplayConfig_DisplayUnits.values)
    ..aE<Config_DisplayConfig_OledType>(7, _omitFieldNames ? '' : 'oled',
        enumValues: Config_DisplayConfig_OledType.values)
    ..aE<Config_DisplayConfig_DisplayMode>(
        8, _omitFieldNames ? '' : 'displaymode',
        enumValues: Config_DisplayConfig_DisplayMode.values)
    ..aOB(9, _omitFieldNames ? '' : 'headingBold')
    ..aOB(10, _omitFieldNames ? '' : 'wakeOnTapOrMotion')
    ..aE<Config_DisplayConfig_CompassOrientation>(
        11, _omitFieldNames ? '' : 'compassOrientation',
        enumValues: Config_DisplayConfig_CompassOrientation.values)
    ..aOB(12, _omitFieldNames ? '' : 'use12hClock', protoName: 'use_12h_clock')
    ..aOB(13, _omitFieldNames ? '' : 'useLongNodeName')
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

  @$pb.TagNumber(2)
  $core.int get gpsFormat => $_getIZ(1);
  @$pb.TagNumber(2)
  set gpsFormat($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGpsFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearGpsFormat() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get autoScreenCarouselSecs => $_getIZ(2);
  @$pb.TagNumber(3)
  set autoScreenCarouselSecs($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAutoScreenCarouselSecs() => $_has(2);
  @$pb.TagNumber(3)
  void clearAutoScreenCarouselSecs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get compassNorthTop => $_getBF(3);
  @$pb.TagNumber(4)
  set compassNorthTop($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCompassNorthTop() => $_has(3);
  @$pb.TagNumber(4)
  void clearCompassNorthTop() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get flipScreen => $_getBF(4);
  @$pb.TagNumber(5)
  set flipScreen($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFlipScreen() => $_has(4);
  @$pb.TagNumber(5)
  void clearFlipScreen() => $_clearField(5);

  @$pb.TagNumber(6)
  Config_DisplayConfig_DisplayUnits get units => $_getN(5);
  @$pb.TagNumber(6)
  set units(Config_DisplayConfig_DisplayUnits value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasUnits() => $_has(5);
  @$pb.TagNumber(6)
  void clearUnits() => $_clearField(6);

  @$pb.TagNumber(7)
  Config_DisplayConfig_OledType get oled => $_getN(6);
  @$pb.TagNumber(7)
  set oled(Config_DisplayConfig_OledType value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOled() => $_has(6);
  @$pb.TagNumber(7)
  void clearOled() => $_clearField(7);

  @$pb.TagNumber(8)
  Config_DisplayConfig_DisplayMode get displaymode => $_getN(7);
  @$pb.TagNumber(8)
  set displaymode(Config_DisplayConfig_DisplayMode value) =>
      $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDisplaymode() => $_has(7);
  @$pb.TagNumber(8)
  void clearDisplaymode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get headingBold => $_getBF(8);
  @$pb.TagNumber(9)
  set headingBold($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHeadingBold() => $_has(8);
  @$pb.TagNumber(9)
  void clearHeadingBold() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get wakeOnTapOrMotion => $_getBF(9);
  @$pb.TagNumber(10)
  set wakeOnTapOrMotion($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasWakeOnTapOrMotion() => $_has(9);
  @$pb.TagNumber(10)
  void clearWakeOnTapOrMotion() => $_clearField(10);

  @$pb.TagNumber(11)
  Config_DisplayConfig_CompassOrientation get compassOrientation => $_getN(10);
  @$pb.TagNumber(11)
  set compassOrientation(Config_DisplayConfig_CompassOrientation value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCompassOrientation() => $_has(10);
  @$pb.TagNumber(11)
  void clearCompassOrientation() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get use12hClock => $_getBF(11);
  @$pb.TagNumber(12)
  set use12hClock($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUse12hClock() => $_has(11);
  @$pb.TagNumber(12)
  void clearUse12hClock() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get useLongNodeName => $_getBF(12);
  @$pb.TagNumber(13)
  set useLongNodeName($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasUseLongNodeName() => $_has(12);
  @$pb.TagNumber(13)
  void clearUseLongNodeName() => $_clearField(13);
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
    $core.int? channelNum,
    $core.bool? overrideDutyCycle,
    $core.bool? sx126xRxBoostedGain,
    $core.double? overrideFrequency,
    $core.bool? paFanDisabled,
    $core.Iterable<$core.int>? ignoreIncoming,
    $core.bool? ignoreMqtt,
    $core.bool? configOkToMqtt,
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
    if (channelNum != null) result.channelNum = channelNum;
    if (overrideDutyCycle != null) result.overrideDutyCycle = overrideDutyCycle;
    if (sx126xRxBoostedGain != null)
      result.sx126xRxBoostedGain = sx126xRxBoostedGain;
    if (overrideFrequency != null) result.overrideFrequency = overrideFrequency;
    if (paFanDisabled != null) result.paFanDisabled = paFanDisabled;
    if (ignoreIncoming != null) result.ignoreIncoming.addAll(ignoreIncoming);
    if (ignoreMqtt != null) result.ignoreMqtt = ignoreMqtt;
    if (configOkToMqtt != null) result.configOkToMqtt = configOkToMqtt;
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
    ..aI(11, _omitFieldNames ? '' : 'channelNum',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(12, _omitFieldNames ? '' : 'overrideDutyCycle')
    ..aOB(13, _omitFieldNames ? '' : 'sx126xRxBoostedGain')
    ..aD(14, _omitFieldNames ? '' : 'overrideFrequency',
        fieldType: $pb.PbFieldType.OF)
    ..aOB(15, _omitFieldNames ? '' : 'paFanDisabled')
    ..p<$core.int>(
        103, _omitFieldNames ? '' : 'ignoreIncoming', $pb.PbFieldType.KU3)
    ..aOB(104, _omitFieldNames ? '' : 'ignoreMqtt')
    ..aOB(105, _omitFieldNames ? '' : 'configOkToMqtt')
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

  @$pb.TagNumber(11)
  $core.int get channelNum => $_getIZ(10);
  @$pb.TagNumber(11)
  set channelNum($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasChannelNum() => $_has(10);
  @$pb.TagNumber(11)
  void clearChannelNum() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get overrideDutyCycle => $_getBF(11);
  @$pb.TagNumber(12)
  set overrideDutyCycle($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOverrideDutyCycle() => $_has(11);
  @$pb.TagNumber(12)
  void clearOverrideDutyCycle() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get sx126xRxBoostedGain => $_getBF(12);
  @$pb.TagNumber(13)
  set sx126xRxBoostedGain($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasSx126xRxBoostedGain() => $_has(12);
  @$pb.TagNumber(13)
  void clearSx126xRxBoostedGain() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.double get overrideFrequency => $_getN(13);
  @$pb.TagNumber(14)
  set overrideFrequency($core.double value) => $_setFloat(13, value);
  @$pb.TagNumber(14)
  $core.bool hasOverrideFrequency() => $_has(13);
  @$pb.TagNumber(14)
  void clearOverrideFrequency() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get paFanDisabled => $_getBF(14);
  @$pb.TagNumber(15)
  set paFanDisabled($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasPaFanDisabled() => $_has(14);
  @$pb.TagNumber(15)
  void clearPaFanDisabled() => $_clearField(15);

  @$pb.TagNumber(103)
  $pb.PbList<$core.int> get ignoreIncoming => $_getList(15);

  @$pb.TagNumber(104)
  $core.bool get ignoreMqtt => $_getBF(16);
  @$pb.TagNumber(104)
  set ignoreMqtt($core.bool value) => $_setBool(16, value);
  @$pb.TagNumber(104)
  $core.bool hasIgnoreMqtt() => $_has(16);
  @$pb.TagNumber(104)
  void clearIgnoreMqtt() => $_clearField(104);

  @$pb.TagNumber(105)
  $core.bool get configOkToMqtt => $_getBF(17);
  @$pb.TagNumber(105)
  set configOkToMqtt($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(105)
  $core.bool hasConfigOkToMqtt() => $_has(17);
  @$pb.TagNumber(105)
  void clearConfigOkToMqtt() => $_clearField(105);
}

class Config_BluetoothConfig extends $pb.GeneratedMessage {
  factory Config_BluetoothConfig({
    $core.bool? enabled,
    Config_BluetoothConfig_PairingMode? mode,
    $core.int? fixedPin,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (mode != null) result.mode = mode;
    if (fixedPin != null) result.fixedPin = fixedPin;
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
    ..aE<Config_BluetoothConfig_PairingMode>(2, _omitFieldNames ? '' : 'mode',
        enumValues: Config_BluetoothConfig_PairingMode.values)
    ..aI(3, _omitFieldNames ? '' : 'fixedPin', fieldType: $pb.PbFieldType.OU3)
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

  @$pb.TagNumber(2)
  Config_BluetoothConfig_PairingMode get mode => $_getN(1);
  @$pb.TagNumber(2)
  set mode(Config_BluetoothConfig_PairingMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get fixedPin => $_getIZ(2);
  @$pb.TagNumber(3)
  set fixedPin($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFixedPin() => $_has(2);
  @$pb.TagNumber(3)
  void clearFixedPin() => $_clearField(3);
}

class Config_SecurityConfig extends $pb.GeneratedMessage {
  factory Config_SecurityConfig({
    $core.List<$core.int>? publicKey,
    $core.List<$core.int>? privateKey,
    $core.Iterable<$core.List<$core.int>>? adminKey,
    $core.bool? isManaged,
    $core.bool? serialEnabled,
    $core.bool? debugLogApiEnabled,
    $core.bool? adminChannelEnabled,
  }) {
    final result = create();
    if (publicKey != null) result.publicKey = publicKey;
    if (privateKey != null) result.privateKey = privateKey;
    if (adminKey != null) result.adminKey.addAll(adminKey);
    if (isManaged != null) result.isManaged = isManaged;
    if (serialEnabled != null) result.serialEnabled = serialEnabled;
    if (debugLogApiEnabled != null)
      result.debugLogApiEnabled = debugLogApiEnabled;
    if (adminChannelEnabled != null)
      result.adminChannelEnabled = adminChannelEnabled;
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
    ..p<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'adminKey', $pb.PbFieldType.PY)
    ..aOB(4, _omitFieldNames ? '' : 'isManaged')
    ..aOB(5, _omitFieldNames ? '' : 'serialEnabled')
    ..aOB(6, _omitFieldNames ? '' : 'debugLogApiEnabled')
    ..aOB(8, _omitFieldNames ? '' : 'adminChannelEnabled')
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

  @$pb.TagNumber(3)
  $pb.PbList<$core.List<$core.int>> get adminKey => $_getList(2);

  @$pb.TagNumber(4)
  $core.bool get isManaged => $_getBF(3);
  @$pb.TagNumber(4)
  set isManaged($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsManaged() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsManaged() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get serialEnabled => $_getBF(4);
  @$pb.TagNumber(5)
  set serialEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSerialEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearSerialEnabled() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get debugLogApiEnabled => $_getBF(5);
  @$pb.TagNumber(6)
  set debugLogApiEnabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDebugLogApiEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearDebugLogApiEnabled() => $_clearField(6);

  @$pb.TagNumber(8)
  $core.bool get adminChannelEnabled => $_getBF(6);
  @$pb.TagNumber(8)
  set adminChannelEnabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(8)
  $core.bool hasAdminChannelEnabled() => $_has(6);
  @$pb.TagNumber(8)
  void clearAdminChannelEnabled() => $_clearField(8);
}

class Config_SessionkeyConfig extends $pb.GeneratedMessage {
  factory Config_SessionkeyConfig() => create();

  Config_SessionkeyConfig._();

  factory Config_SessionkeyConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Config_SessionkeyConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config.SessionkeyConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_SessionkeyConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Config_SessionkeyConfig copyWith(
          void Function(Config_SessionkeyConfig) updates) =>
      super.copyWith((message) => updates(message as Config_SessionkeyConfig))
          as Config_SessionkeyConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Config_SessionkeyConfig create() => Config_SessionkeyConfig._();
  @$core.override
  Config_SessionkeyConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Config_SessionkeyConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Config_SessionkeyConfig>(create);
  static Config_SessionkeyConfig? _defaultInstance;
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
  sessionkey,
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
    Config_SessionkeyConfig? sessionkey,
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
    if (sessionkey != null) result.sessionkey = sessionkey;
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
    9: Config_PayloadVariant.sessionkey,
    0: Config_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Config',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9])
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
    ..aOM<Config_SessionkeyConfig>(9, _omitFieldNames ? '' : 'sessionkey',
        subBuilder: Config_SessionkeyConfig.create)
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
  @$pb.TagNumber(9)
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
  @$pb.TagNumber(9)
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

  @$pb.TagNumber(9)
  Config_SessionkeyConfig get sessionkey => $_getN(8);
  @$pb.TagNumber(9)
  set sessionkey(Config_SessionkeyConfig value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionkey() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionkey() => $_clearField(9);
  @$pb.TagNumber(9)
  Config_SessionkeyConfig ensureSessionkey() => $_ensure(8);
}

class ModuleConfig_MQTTConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_MQTTConfig({
    $core.bool? enabled,
    $core.String? address,
    $core.String? username,
    $core.String? password,
    $core.bool? encryptionEnabled,
    $core.bool? jsonEnabled,
    $core.bool? tlsEnabled,
    $core.String? root,
    $core.bool? proxyToClientEnabled,
    $core.bool? mapReportingEnabled,
    ModuleConfig_MapReportSettings? mapReportSettings,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (address != null) result.address = address;
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    if (encryptionEnabled != null) result.encryptionEnabled = encryptionEnabled;
    if (jsonEnabled != null) result.jsonEnabled = jsonEnabled;
    if (tlsEnabled != null) result.tlsEnabled = tlsEnabled;
    if (root != null) result.root = root;
    if (proxyToClientEnabled != null)
      result.proxyToClientEnabled = proxyToClientEnabled;
    if (mapReportingEnabled != null)
      result.mapReportingEnabled = mapReportingEnabled;
    if (mapReportSettings != null) result.mapReportSettings = mapReportSettings;
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
    ..aOS(2, _omitFieldNames ? '' : 'address')
    ..aOS(3, _omitFieldNames ? '' : 'username')
    ..aOS(4, _omitFieldNames ? '' : 'password')
    ..aOB(5, _omitFieldNames ? '' : 'encryptionEnabled')
    ..aOB(6, _omitFieldNames ? '' : 'jsonEnabled')
    ..aOB(7, _omitFieldNames ? '' : 'tlsEnabled')
    ..aOS(8, _omitFieldNames ? '' : 'root')
    ..aOB(9, _omitFieldNames ? '' : 'proxyToClientEnabled')
    ..aOB(10, _omitFieldNames ? '' : 'mapReportingEnabled')
    ..aOM<ModuleConfig_MapReportSettings>(
        11, _omitFieldNames ? '' : 'mapReportSettings',
        subBuilder: ModuleConfig_MapReportSettings.create)
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

  @$pb.TagNumber(2)
  $core.String get address => $_getSZ(1);
  @$pb.TagNumber(2)
  set address($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get username => $_getSZ(2);
  @$pb.TagNumber(3)
  set username($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsername() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get password => $_getSZ(3);
  @$pb.TagNumber(4)
  set password($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPassword() => $_has(3);
  @$pb.TagNumber(4)
  void clearPassword() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get encryptionEnabled => $_getBF(4);
  @$pb.TagNumber(5)
  set encryptionEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEncryptionEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearEncryptionEnabled() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get jsonEnabled => $_getBF(5);
  @$pb.TagNumber(6)
  set jsonEnabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasJsonEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearJsonEnabled() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get tlsEnabled => $_getBF(6);
  @$pb.TagNumber(7)
  set tlsEnabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTlsEnabled() => $_has(6);
  @$pb.TagNumber(7)
  void clearTlsEnabled() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get root => $_getSZ(7);
  @$pb.TagNumber(8)
  set root($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRoot() => $_has(7);
  @$pb.TagNumber(8)
  void clearRoot() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get proxyToClientEnabled => $_getBF(8);
  @$pb.TagNumber(9)
  set proxyToClientEnabled($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasProxyToClientEnabled() => $_has(8);
  @$pb.TagNumber(9)
  void clearProxyToClientEnabled() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get mapReportingEnabled => $_getBF(9);
  @$pb.TagNumber(10)
  set mapReportingEnabled($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMapReportingEnabled() => $_has(9);
  @$pb.TagNumber(10)
  void clearMapReportingEnabled() => $_clearField(10);

  @$pb.TagNumber(11)
  ModuleConfig_MapReportSettings get mapReportSettings => $_getN(10);
  @$pb.TagNumber(11)
  set mapReportSettings(ModuleConfig_MapReportSettings value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasMapReportSettings() => $_has(10);
  @$pb.TagNumber(11)
  void clearMapReportSettings() => $_clearField(11);
  @$pb.TagNumber(11)
  ModuleConfig_MapReportSettings ensureMapReportSettings() => $_ensure(10);
}

class ModuleConfig_MapReportSettings extends $pb.GeneratedMessage {
  factory ModuleConfig_MapReportSettings({
    $core.int? publishIntervalSecs,
    $core.int? positionPrecision,
    $core.bool? shouldReportLocation,
  }) {
    final result = create();
    if (publishIntervalSecs != null)
      result.publishIntervalSecs = publishIntervalSecs;
    if (positionPrecision != null) result.positionPrecision = positionPrecision;
    if (shouldReportLocation != null)
      result.shouldReportLocation = shouldReportLocation;
    return result;
  }

  ModuleConfig_MapReportSettings._();

  factory ModuleConfig_MapReportSettings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_MapReportSettings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.MapReportSettings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'publishIntervalSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'positionPrecision',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'shouldReportLocation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_MapReportSettings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_MapReportSettings copyWith(
          void Function(ModuleConfig_MapReportSettings) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_MapReportSettings))
          as ModuleConfig_MapReportSettings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_MapReportSettings create() =>
      ModuleConfig_MapReportSettings._();
  @$core.override
  ModuleConfig_MapReportSettings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_MapReportSettings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_MapReportSettings>(create);
  static ModuleConfig_MapReportSettings? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get publishIntervalSecs => $_getIZ(0);
  @$pb.TagNumber(1)
  set publishIntervalSecs($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPublishIntervalSecs() => $_has(0);
  @$pb.TagNumber(1)
  void clearPublishIntervalSecs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get positionPrecision => $_getIZ(1);
  @$pb.TagNumber(2)
  set positionPrecision($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPositionPrecision() => $_has(1);
  @$pb.TagNumber(2)
  void clearPositionPrecision() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get shouldReportLocation => $_getBF(2);
  @$pb.TagNumber(3)
  set shouldReportLocation($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShouldReportLocation() => $_has(2);
  @$pb.TagNumber(3)
  void clearShouldReportLocation() => $_clearField(3);
}

class ModuleConfig_SerialConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_SerialConfig({
    $core.bool? enabled,
    $core.bool? echo,
    $core.int? rxd,
    $core.int? txd,
    ModuleConfig_SerialConfig_Serial_Baud? baud,
    $core.int? timeout,
    ModuleConfig_SerialConfig_Serial_Mode? mode,
    $core.bool? overrideConsoleSerialPort,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (echo != null) result.echo = echo;
    if (rxd != null) result.rxd = rxd;
    if (txd != null) result.txd = txd;
    if (baud != null) result.baud = baud;
    if (timeout != null) result.timeout = timeout;
    if (mode != null) result.mode = mode;
    if (overrideConsoleSerialPort != null)
      result.overrideConsoleSerialPort = overrideConsoleSerialPort;
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
    ..aOB(2, _omitFieldNames ? '' : 'echo')
    ..aI(3, _omitFieldNames ? '' : 'rxd', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'txd', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModuleConfig_SerialConfig_Serial_Baud>(
        5, _omitFieldNames ? '' : 'baud',
        enumValues: ModuleConfig_SerialConfig_Serial_Baud.values)
    ..aI(6, _omitFieldNames ? '' : 'timeout', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModuleConfig_SerialConfig_Serial_Mode>(
        7, _omitFieldNames ? '' : 'mode',
        enumValues: ModuleConfig_SerialConfig_Serial_Mode.values)
    ..aOB(8, _omitFieldNames ? '' : 'overrideConsoleSerialPort')
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

  @$pb.TagNumber(2)
  $core.bool get echo => $_getBF(1);
  @$pb.TagNumber(2)
  set echo($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEcho() => $_has(1);
  @$pb.TagNumber(2)
  void clearEcho() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rxd => $_getIZ(2);
  @$pb.TagNumber(3)
  set rxd($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRxd() => $_has(2);
  @$pb.TagNumber(3)
  void clearRxd() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get txd => $_getIZ(3);
  @$pb.TagNumber(4)
  set txd($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTxd() => $_has(3);
  @$pb.TagNumber(4)
  void clearTxd() => $_clearField(4);

  @$pb.TagNumber(5)
  ModuleConfig_SerialConfig_Serial_Baud get baud => $_getN(4);
  @$pb.TagNumber(5)
  set baud(ModuleConfig_SerialConfig_Serial_Baud value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBaud() => $_has(4);
  @$pb.TagNumber(5)
  void clearBaud() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get timeout => $_getIZ(5);
  @$pb.TagNumber(6)
  set timeout($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTimeout() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimeout() => $_clearField(6);

  @$pb.TagNumber(7)
  ModuleConfig_SerialConfig_Serial_Mode get mode => $_getN(6);
  @$pb.TagNumber(7)
  set mode(ModuleConfig_SerialConfig_Serial_Mode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearMode() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get overrideConsoleSerialPort => $_getBF(7);
  @$pb.TagNumber(8)
  set overrideConsoleSerialPort($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOverrideConsoleSerialPort() => $_has(7);
  @$pb.TagNumber(8)
  void clearOverrideConsoleSerialPort() => $_clearField(8);
}

class ModuleConfig_ExternalNotificationConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_ExternalNotificationConfig({
    $core.bool? enabled,
    $core.int? outputMs,
    $core.int? output,
    $core.bool? active,
    $core.bool? alertMessage,
    $core.bool? alertBell,
    $core.bool? usePwm,
    $core.int? outputVibra,
    $core.int? outputBuzzer,
    $core.bool? alertMessageVibra,
    $core.bool? alertMessageBuzzer,
    $core.bool? alertBellVibra,
    $core.bool? alertBellBuzzer,
    $core.int? nagTimeout,
    $core.bool? useI2sAsBuzzer,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (outputMs != null) result.outputMs = outputMs;
    if (output != null) result.output = output;
    if (active != null) result.active = active;
    if (alertMessage != null) result.alertMessage = alertMessage;
    if (alertBell != null) result.alertBell = alertBell;
    if (usePwm != null) result.usePwm = usePwm;
    if (outputVibra != null) result.outputVibra = outputVibra;
    if (outputBuzzer != null) result.outputBuzzer = outputBuzzer;
    if (alertMessageVibra != null) result.alertMessageVibra = alertMessageVibra;
    if (alertMessageBuzzer != null)
      result.alertMessageBuzzer = alertMessageBuzzer;
    if (alertBellVibra != null) result.alertBellVibra = alertBellVibra;
    if (alertBellBuzzer != null) result.alertBellBuzzer = alertBellBuzzer;
    if (nagTimeout != null) result.nagTimeout = nagTimeout;
    if (useI2sAsBuzzer != null) result.useI2sAsBuzzer = useI2sAsBuzzer;
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
    ..aI(2, _omitFieldNames ? '' : 'outputMs', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'output', fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'active')
    ..aOB(5, _omitFieldNames ? '' : 'alertMessage')
    ..aOB(6, _omitFieldNames ? '' : 'alertBell')
    ..aOB(7, _omitFieldNames ? '' : 'usePwm')
    ..aI(8, _omitFieldNames ? '' : 'outputVibra',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'outputBuzzer',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'alertMessageVibra')
    ..aOB(11, _omitFieldNames ? '' : 'alertMessageBuzzer')
    ..aOB(12, _omitFieldNames ? '' : 'alertBellVibra')
    ..aOB(13, _omitFieldNames ? '' : 'alertBellBuzzer')
    ..aI(14, _omitFieldNames ? '' : 'nagTimeout',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(15, _omitFieldNames ? '' : 'useI2sAsBuzzer')
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

  @$pb.TagNumber(2)
  $core.int get outputMs => $_getIZ(1);
  @$pb.TagNumber(2)
  set outputMs($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOutputMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutputMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get output => $_getIZ(2);
  @$pb.TagNumber(3)
  set output($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutput() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get active => $_getBF(3);
  @$pb.TagNumber(4)
  set active($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActive() => $_has(3);
  @$pb.TagNumber(4)
  void clearActive() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get alertMessage => $_getBF(4);
  @$pb.TagNumber(5)
  set alertMessage($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAlertMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearAlertMessage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get alertBell => $_getBF(5);
  @$pb.TagNumber(6)
  set alertBell($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAlertBell() => $_has(5);
  @$pb.TagNumber(6)
  void clearAlertBell() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get usePwm => $_getBF(6);
  @$pb.TagNumber(7)
  set usePwm($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUsePwm() => $_has(6);
  @$pb.TagNumber(7)
  void clearUsePwm() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get outputVibra => $_getIZ(7);
  @$pb.TagNumber(8)
  set outputVibra($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOutputVibra() => $_has(7);
  @$pb.TagNumber(8)
  void clearOutputVibra() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get outputBuzzer => $_getIZ(8);
  @$pb.TagNumber(9)
  set outputBuzzer($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOutputBuzzer() => $_has(8);
  @$pb.TagNumber(9)
  void clearOutputBuzzer() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get alertMessageVibra => $_getBF(9);
  @$pb.TagNumber(10)
  set alertMessageVibra($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAlertMessageVibra() => $_has(9);
  @$pb.TagNumber(10)
  void clearAlertMessageVibra() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get alertMessageBuzzer => $_getBF(10);
  @$pb.TagNumber(11)
  set alertMessageBuzzer($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAlertMessageBuzzer() => $_has(10);
  @$pb.TagNumber(11)
  void clearAlertMessageBuzzer() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get alertBellVibra => $_getBF(11);
  @$pb.TagNumber(12)
  set alertBellVibra($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAlertBellVibra() => $_has(11);
  @$pb.TagNumber(12)
  void clearAlertBellVibra() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get alertBellBuzzer => $_getBF(12);
  @$pb.TagNumber(13)
  set alertBellBuzzer($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAlertBellBuzzer() => $_has(12);
  @$pb.TagNumber(13)
  void clearAlertBellBuzzer() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get nagTimeout => $_getIZ(13);
  @$pb.TagNumber(14)
  set nagTimeout($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNagTimeout() => $_has(13);
  @$pb.TagNumber(14)
  void clearNagTimeout() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get useI2sAsBuzzer => $_getBF(14);
  @$pb.TagNumber(15)
  set useI2sAsBuzzer($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasUseI2sAsBuzzer() => $_has(14);
  @$pb.TagNumber(15)
  void clearUseI2sAsBuzzer() => $_clearField(15);
}

class ModuleConfig_StoreForwardConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_StoreForwardConfig({
    $core.bool? enabled,
    $core.bool? heartbeat,
    $core.int? records,
    $core.int? historyReturnMax,
    $core.int? historyReturnWindow,
    $core.bool? isServer,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (records != null) result.records = records;
    if (historyReturnMax != null) result.historyReturnMax = historyReturnMax;
    if (historyReturnWindow != null)
      result.historyReturnWindow = historyReturnWindow;
    if (isServer != null) result.isServer = isServer;
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
    ..aOB(2, _omitFieldNames ? '' : 'heartbeat')
    ..aI(3, _omitFieldNames ? '' : 'records', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'historyReturnMax',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'historyReturnWindow',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(6, _omitFieldNames ? '' : 'isServer')
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

  @$pb.TagNumber(2)
  $core.bool get heartbeat => $_getBF(1);
  @$pb.TagNumber(2)
  set heartbeat($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get records => $_getIZ(2);
  @$pb.TagNumber(3)
  set records($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRecords() => $_has(2);
  @$pb.TagNumber(3)
  void clearRecords() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get historyReturnMax => $_getIZ(3);
  @$pb.TagNumber(4)
  set historyReturnMax($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHistoryReturnMax() => $_has(3);
  @$pb.TagNumber(4)
  void clearHistoryReturnMax() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get historyReturnWindow => $_getIZ(4);
  @$pb.TagNumber(5)
  set historyReturnWindow($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHistoryReturnWindow() => $_has(4);
  @$pb.TagNumber(5)
  void clearHistoryReturnWindow() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isServer => $_getBF(5);
  @$pb.TagNumber(6)
  set isServer($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsServer() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsServer() => $_clearField(6);
}

class ModuleConfig_RangeTestConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_RangeTestConfig({
    $core.bool? enabled,
    $core.int? sender,
    $core.bool? save,
    $core.bool? clearOnReboot,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (sender != null) result.sender = sender;
    if (save != null) result.save = save;
    if (clearOnReboot != null) result.clearOnReboot = clearOnReboot;
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
    ..aI(2, _omitFieldNames ? '' : 'sender', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'save')
    ..aOB(4, _omitFieldNames ? '' : 'clearOnReboot')
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

  @$pb.TagNumber(2)
  $core.int get sender => $_getIZ(1);
  @$pb.TagNumber(2)
  set sender($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSender() => $_has(1);
  @$pb.TagNumber(2)
  void clearSender() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get save => $_getBF(2);
  @$pb.TagNumber(3)
  set save($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSave() => $_has(2);
  @$pb.TagNumber(3)
  void clearSave() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get clearOnReboot => $_getBF(3);
  @$pb.TagNumber(4)
  set clearOnReboot($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasClearOnReboot() => $_has(3);
  @$pb.TagNumber(4)
  void clearClearOnReboot() => $_clearField(4);
}

class ModuleConfig_TelemetryConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_TelemetryConfig({
    $core.int? deviceUpdateInterval,
    $core.int? environmentUpdateInterval,
    $core.bool? environmentMeasurementEnabled,
    $core.bool? environmentScreenEnabled,
    $core.bool? environmentDisplayFahrenheit,
    $core.bool? airQualityEnabled,
    $core.int? airQualityInterval,
    $core.bool? powerMeasurementEnabled,
    $core.int? powerUpdateInterval,
    $core.bool? powerScreenEnabled,
    $core.bool? healthMeasurementEnabled,
    $core.int? healthUpdateInterval,
    $core.bool? healthScreenEnabled,
    $core.bool? deviceTelemetryEnabled,
  }) {
    final result = create();
    if (deviceUpdateInterval != null)
      result.deviceUpdateInterval = deviceUpdateInterval;
    if (environmentUpdateInterval != null)
      result.environmentUpdateInterval = environmentUpdateInterval;
    if (environmentMeasurementEnabled != null)
      result.environmentMeasurementEnabled = environmentMeasurementEnabled;
    if (environmentScreenEnabled != null)
      result.environmentScreenEnabled = environmentScreenEnabled;
    if (environmentDisplayFahrenheit != null)
      result.environmentDisplayFahrenheit = environmentDisplayFahrenheit;
    if (airQualityEnabled != null) result.airQualityEnabled = airQualityEnabled;
    if (airQualityInterval != null)
      result.airQualityInterval = airQualityInterval;
    if (powerMeasurementEnabled != null)
      result.powerMeasurementEnabled = powerMeasurementEnabled;
    if (powerUpdateInterval != null)
      result.powerUpdateInterval = powerUpdateInterval;
    if (powerScreenEnabled != null)
      result.powerScreenEnabled = powerScreenEnabled;
    if (healthMeasurementEnabled != null)
      result.healthMeasurementEnabled = healthMeasurementEnabled;
    if (healthUpdateInterval != null)
      result.healthUpdateInterval = healthUpdateInterval;
    if (healthScreenEnabled != null)
      result.healthScreenEnabled = healthScreenEnabled;
    if (deviceTelemetryEnabled != null)
      result.deviceTelemetryEnabled = deviceTelemetryEnabled;
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
    ..aI(2, _omitFieldNames ? '' : 'environmentUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'environmentMeasurementEnabled')
    ..aOB(4, _omitFieldNames ? '' : 'environmentScreenEnabled')
    ..aOB(5, _omitFieldNames ? '' : 'environmentDisplayFahrenheit')
    ..aOB(6, _omitFieldNames ? '' : 'airQualityEnabled')
    ..aI(7, _omitFieldNames ? '' : 'airQualityInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(8, _omitFieldNames ? '' : 'powerMeasurementEnabled')
    ..aI(9, _omitFieldNames ? '' : 'powerUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'powerScreenEnabled')
    ..aOB(11, _omitFieldNames ? '' : 'healthMeasurementEnabled')
    ..aI(12, _omitFieldNames ? '' : 'healthUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(13, _omitFieldNames ? '' : 'healthScreenEnabled')
    ..aOB(14, _omitFieldNames ? '' : 'deviceTelemetryEnabled')
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

  @$pb.TagNumber(2)
  $core.int get environmentUpdateInterval => $_getIZ(1);
  @$pb.TagNumber(2)
  set environmentUpdateInterval($core.int value) =>
      $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnvironmentUpdateInterval() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnvironmentUpdateInterval() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get environmentMeasurementEnabled => $_getBF(2);
  @$pb.TagNumber(3)
  set environmentMeasurementEnabled($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEnvironmentMeasurementEnabled() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnvironmentMeasurementEnabled() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get environmentScreenEnabled => $_getBF(3);
  @$pb.TagNumber(4)
  set environmentScreenEnabled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnvironmentScreenEnabled() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnvironmentScreenEnabled() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get environmentDisplayFahrenheit => $_getBF(4);
  @$pb.TagNumber(5)
  set environmentDisplayFahrenheit($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnvironmentDisplayFahrenheit() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnvironmentDisplayFahrenheit() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get airQualityEnabled => $_getBF(5);
  @$pb.TagNumber(6)
  set airQualityEnabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAirQualityEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearAirQualityEnabled() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get airQualityInterval => $_getIZ(6);
  @$pb.TagNumber(7)
  set airQualityInterval($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAirQualityInterval() => $_has(6);
  @$pb.TagNumber(7)
  void clearAirQualityInterval() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get powerMeasurementEnabled => $_getBF(7);
  @$pb.TagNumber(8)
  set powerMeasurementEnabled($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPowerMeasurementEnabled() => $_has(7);
  @$pb.TagNumber(8)
  void clearPowerMeasurementEnabled() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get powerUpdateInterval => $_getIZ(8);
  @$pb.TagNumber(9)
  set powerUpdateInterval($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPowerUpdateInterval() => $_has(8);
  @$pb.TagNumber(9)
  void clearPowerUpdateInterval() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get powerScreenEnabled => $_getBF(9);
  @$pb.TagNumber(10)
  set powerScreenEnabled($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPowerScreenEnabled() => $_has(9);
  @$pb.TagNumber(10)
  void clearPowerScreenEnabled() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get healthMeasurementEnabled => $_getBF(10);
  @$pb.TagNumber(11)
  set healthMeasurementEnabled($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHealthMeasurementEnabled() => $_has(10);
  @$pb.TagNumber(11)
  void clearHealthMeasurementEnabled() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get healthUpdateInterval => $_getIZ(11);
  @$pb.TagNumber(12)
  set healthUpdateInterval($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasHealthUpdateInterval() => $_has(11);
  @$pb.TagNumber(12)
  void clearHealthUpdateInterval() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get healthScreenEnabled => $_getBF(12);
  @$pb.TagNumber(13)
  set healthScreenEnabled($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHealthScreenEnabled() => $_has(12);
  @$pb.TagNumber(13)
  void clearHealthScreenEnabled() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get deviceTelemetryEnabled => $_getBF(13);
  @$pb.TagNumber(14)
  set deviceTelemetryEnabled($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasDeviceTelemetryEnabled() => $_has(13);
  @$pb.TagNumber(14)
  void clearDeviceTelemetryEnabled() => $_clearField(14);
}

class ModuleConfig_CannedMessageConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_CannedMessageConfig({
    $core.bool? rotary1Enabled,
    $core.int? inputbrokerPinA,
    $core.int? inputbrokerPinB,
    $core.int? inputbrokerPinPress,
    ModuleConfig_CannedMessageConfig_InputEventChar? inputbrokerEventCw,
    ModuleConfig_CannedMessageConfig_InputEventChar? inputbrokerEventCcw,
    ModuleConfig_CannedMessageConfig_InputEventChar? inputbrokerEventPress,
    $core.bool? updown1Enabled,
    $core.bool? enabled,
    $core.String? allowInputSource,
    $core.bool? sendBell,
  }) {
    final result = create();
    if (rotary1Enabled != null) result.rotary1Enabled = rotary1Enabled;
    if (inputbrokerPinA != null) result.inputbrokerPinA = inputbrokerPinA;
    if (inputbrokerPinB != null) result.inputbrokerPinB = inputbrokerPinB;
    if (inputbrokerPinPress != null)
      result.inputbrokerPinPress = inputbrokerPinPress;
    if (inputbrokerEventCw != null)
      result.inputbrokerEventCw = inputbrokerEventCw;
    if (inputbrokerEventCcw != null)
      result.inputbrokerEventCcw = inputbrokerEventCcw;
    if (inputbrokerEventPress != null)
      result.inputbrokerEventPress = inputbrokerEventPress;
    if (updown1Enabled != null) result.updown1Enabled = updown1Enabled;
    if (enabled != null) result.enabled = enabled;
    if (allowInputSource != null) result.allowInputSource = allowInputSource;
    if (sendBell != null) result.sendBell = sendBell;
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
    ..aOB(1, _omitFieldNames ? '' : 'rotary1Enabled')
    ..aI(2, _omitFieldNames ? '' : 'inputbrokerPinA',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'inputbrokerPinB',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'inputbrokerPinPress',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<ModuleConfig_CannedMessageConfig_InputEventChar>(
        5, _omitFieldNames ? '' : 'inputbrokerEventCw',
        enumValues: ModuleConfig_CannedMessageConfig_InputEventChar.values)
    ..aE<ModuleConfig_CannedMessageConfig_InputEventChar>(
        6, _omitFieldNames ? '' : 'inputbrokerEventCcw',
        enumValues: ModuleConfig_CannedMessageConfig_InputEventChar.values)
    ..aE<ModuleConfig_CannedMessageConfig_InputEventChar>(
        7, _omitFieldNames ? '' : 'inputbrokerEventPress',
        enumValues: ModuleConfig_CannedMessageConfig_InputEventChar.values)
    ..aOB(8, _omitFieldNames ? '' : 'updown1Enabled')
    ..aOB(9, _omitFieldNames ? '' : 'enabled')
    ..aOS(10, _omitFieldNames ? '' : 'allowInputSource')
    ..aOB(11, _omitFieldNames ? '' : 'sendBell')
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
  $core.bool get rotary1Enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set rotary1Enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRotary1Enabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearRotary1Enabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get inputbrokerPinA => $_getIZ(1);
  @$pb.TagNumber(2)
  set inputbrokerPinA($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInputbrokerPinA() => $_has(1);
  @$pb.TagNumber(2)
  void clearInputbrokerPinA() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get inputbrokerPinB => $_getIZ(2);
  @$pb.TagNumber(3)
  set inputbrokerPinB($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInputbrokerPinB() => $_has(2);
  @$pb.TagNumber(3)
  void clearInputbrokerPinB() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get inputbrokerPinPress => $_getIZ(3);
  @$pb.TagNumber(4)
  set inputbrokerPinPress($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInputbrokerPinPress() => $_has(3);
  @$pb.TagNumber(4)
  void clearInputbrokerPinPress() => $_clearField(4);

  @$pb.TagNumber(5)
  ModuleConfig_CannedMessageConfig_InputEventChar get inputbrokerEventCw =>
      $_getN(4);
  @$pb.TagNumber(5)
  set inputbrokerEventCw(
          ModuleConfig_CannedMessageConfig_InputEventChar value) =>
      $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasInputbrokerEventCw() => $_has(4);
  @$pb.TagNumber(5)
  void clearInputbrokerEventCw() => $_clearField(5);

  @$pb.TagNumber(6)
  ModuleConfig_CannedMessageConfig_InputEventChar get inputbrokerEventCcw =>
      $_getN(5);
  @$pb.TagNumber(6)
  set inputbrokerEventCcw(
          ModuleConfig_CannedMessageConfig_InputEventChar value) =>
      $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasInputbrokerEventCcw() => $_has(5);
  @$pb.TagNumber(6)
  void clearInputbrokerEventCcw() => $_clearField(6);

  @$pb.TagNumber(7)
  ModuleConfig_CannedMessageConfig_InputEventChar get inputbrokerEventPress =>
      $_getN(6);
  @$pb.TagNumber(7)
  set inputbrokerEventPress(
          ModuleConfig_CannedMessageConfig_InputEventChar value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasInputbrokerEventPress() => $_has(6);
  @$pb.TagNumber(7)
  void clearInputbrokerEventPress() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get updown1Enabled => $_getBF(7);
  @$pb.TagNumber(8)
  set updown1Enabled($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdown1Enabled() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdown1Enabled() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get enabled => $_getBF(8);
  @$pb.TagNumber(9)
  set enabled($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEnabled() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnabled() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get allowInputSource => $_getSZ(9);
  @$pb.TagNumber(10)
  set allowInputSource($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAllowInputSource() => $_has(9);
  @$pb.TagNumber(10)
  void clearAllowInputSource() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get sendBell => $_getBF(10);
  @$pb.TagNumber(11)
  set sendBell($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSendBell() => $_has(10);
  @$pb.TagNumber(11)
  void clearSendBell() => $_clearField(11);
}

class ModuleConfig_AudioConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_AudioConfig({
    $core.bool? codec2Enabled,
    $core.int? pttPin,
    ModuleConfig_AudioConfig_Audio_Baud? bitrate,
    $core.int? i2sWs,
    $core.int? i2sSd,
    $core.int? i2sDin,
    $core.int? i2sSck,
  }) {
    final result = create();
    if (codec2Enabled != null) result.codec2Enabled = codec2Enabled;
    if (pttPin != null) result.pttPin = pttPin;
    if (bitrate != null) result.bitrate = bitrate;
    if (i2sWs != null) result.i2sWs = i2sWs;
    if (i2sSd != null) result.i2sSd = i2sSd;
    if (i2sDin != null) result.i2sDin = i2sDin;
    if (i2sSck != null) result.i2sSck = i2sSck;
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
    ..aI(2, _omitFieldNames ? '' : 'pttPin', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModuleConfig_AudioConfig_Audio_Baud>(
        3, _omitFieldNames ? '' : 'bitrate',
        enumValues: ModuleConfig_AudioConfig_Audio_Baud.values)
    ..aI(4, _omitFieldNames ? '' : 'i2sWs', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'i2sSd', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'i2sDin', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'i2sSck', fieldType: $pb.PbFieldType.OU3)
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

  @$pb.TagNumber(2)
  $core.int get pttPin => $_getIZ(1);
  @$pb.TagNumber(2)
  set pttPin($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPttPin() => $_has(1);
  @$pb.TagNumber(2)
  void clearPttPin() => $_clearField(2);

  @$pb.TagNumber(3)
  ModuleConfig_AudioConfig_Audio_Baud get bitrate => $_getN(2);
  @$pb.TagNumber(3)
  set bitrate(ModuleConfig_AudioConfig_Audio_Baud value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBitrate() => $_has(2);
  @$pb.TagNumber(3)
  void clearBitrate() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get i2sWs => $_getIZ(3);
  @$pb.TagNumber(4)
  set i2sWs($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasI2sWs() => $_has(3);
  @$pb.TagNumber(4)
  void clearI2sWs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get i2sSd => $_getIZ(4);
  @$pb.TagNumber(5)
  set i2sSd($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasI2sSd() => $_has(4);
  @$pb.TagNumber(5)
  void clearI2sSd() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get i2sDin => $_getIZ(5);
  @$pb.TagNumber(6)
  set i2sDin($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasI2sDin() => $_has(5);
  @$pb.TagNumber(6)
  void clearI2sDin() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get i2sSck => $_getIZ(6);
  @$pb.TagNumber(7)
  set i2sSck($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasI2sSck() => $_has(6);
  @$pb.TagNumber(7)
  void clearI2sSck() => $_clearField(7);
}

class ModuleConfig_RemoteHardwareConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_RemoteHardwareConfig({
    $core.bool? enabled,
    $core.bool? allowUndefinedPinAccess,
    $core.Iterable<RemoteHardwarePin>? availablePins,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (allowUndefinedPinAccess != null)
      result.allowUndefinedPinAccess = allowUndefinedPinAccess;
    if (availablePins != null) result.availablePins.addAll(availablePins);
    return result;
  }

  ModuleConfig_RemoteHardwareConfig._();

  factory ModuleConfig_RemoteHardwareConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_RemoteHardwareConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.RemoteHardwareConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aOB(2, _omitFieldNames ? '' : 'allowUndefinedPinAccess')
    ..pPM<RemoteHardwarePin>(3, _omitFieldNames ? '' : 'availablePins',
        subBuilder: RemoteHardwarePin.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_RemoteHardwareConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_RemoteHardwareConfig copyWith(
          void Function(ModuleConfig_RemoteHardwareConfig) updates) =>
      super.copyWith((message) =>
              updates(message as ModuleConfig_RemoteHardwareConfig))
          as ModuleConfig_RemoteHardwareConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_RemoteHardwareConfig create() =>
      ModuleConfig_RemoteHardwareConfig._();
  @$core.override
  ModuleConfig_RemoteHardwareConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_RemoteHardwareConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_RemoteHardwareConfig>(
          create);
  static ModuleConfig_RemoteHardwareConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get allowUndefinedPinAccess => $_getBF(1);
  @$pb.TagNumber(2)
  set allowUndefinedPinAccess($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAllowUndefinedPinAccess() => $_has(1);
  @$pb.TagNumber(2)
  void clearAllowUndefinedPinAccess() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<RemoteHardwarePin> get availablePins => $_getList(2);
}

class ModuleConfig_NeighborInfoConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_NeighborInfoConfig({
    $core.bool? enabled,
    $core.int? updateInterval,
    $core.bool? transmitOverLora,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (updateInterval != null) result.updateInterval = updateInterval;
    if (transmitOverLora != null) result.transmitOverLora = transmitOverLora;
    return result;
  }

  ModuleConfig_NeighborInfoConfig._();

  factory ModuleConfig_NeighborInfoConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_NeighborInfoConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.NeighborInfoConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aI(2, _omitFieldNames ? '' : 'updateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'transmitOverLora')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_NeighborInfoConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_NeighborInfoConfig copyWith(
          void Function(ModuleConfig_NeighborInfoConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_NeighborInfoConfig))
          as ModuleConfig_NeighborInfoConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_NeighborInfoConfig create() =>
      ModuleConfig_NeighborInfoConfig._();
  @$core.override
  ModuleConfig_NeighborInfoConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_NeighborInfoConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_NeighborInfoConfig>(
          create);
  static ModuleConfig_NeighborInfoConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get updateInterval => $_getIZ(1);
  @$pb.TagNumber(2)
  set updateInterval($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUpdateInterval() => $_has(1);
  @$pb.TagNumber(2)
  void clearUpdateInterval() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get transmitOverLora => $_getBF(2);
  @$pb.TagNumber(3)
  set transmitOverLora($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransmitOverLora() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransmitOverLora() => $_clearField(3);
}

class ModuleConfig_AmbientLightingConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_AmbientLightingConfig({
    $core.bool? ledState,
    $core.int? current,
    $core.int? red,
    $core.int? green,
    $core.int? blue,
  }) {
    final result = create();
    if (ledState != null) result.ledState = ledState;
    if (current != null) result.current = current;
    if (red != null) result.red = red;
    if (green != null) result.green = green;
    if (blue != null) result.blue = blue;
    return result;
  }

  ModuleConfig_AmbientLightingConfig._();

  factory ModuleConfig_AmbientLightingConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_AmbientLightingConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.AmbientLightingConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ledState')
    ..aI(2, _omitFieldNames ? '' : 'current', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'red', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'green', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'blue', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_AmbientLightingConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_AmbientLightingConfig copyWith(
          void Function(ModuleConfig_AmbientLightingConfig) updates) =>
      super.copyWith((message) =>
              updates(message as ModuleConfig_AmbientLightingConfig))
          as ModuleConfig_AmbientLightingConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_AmbientLightingConfig create() =>
      ModuleConfig_AmbientLightingConfig._();
  @$core.override
  ModuleConfig_AmbientLightingConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_AmbientLightingConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_AmbientLightingConfig>(
          create);
  static ModuleConfig_AmbientLightingConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ledState => $_getBF(0);
  @$pb.TagNumber(1)
  set ledState($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLedState() => $_has(0);
  @$pb.TagNumber(1)
  void clearLedState() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get current => $_getIZ(1);
  @$pb.TagNumber(2)
  set current($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrent() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get red => $_getIZ(2);
  @$pb.TagNumber(3)
  set red($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRed() => $_has(2);
  @$pb.TagNumber(3)
  void clearRed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get green => $_getIZ(3);
  @$pb.TagNumber(4)
  set green($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGreen() => $_has(3);
  @$pb.TagNumber(4)
  void clearGreen() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get blue => $_getIZ(4);
  @$pb.TagNumber(5)
  set blue($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBlue() => $_has(4);
  @$pb.TagNumber(5)
  void clearBlue() => $_clearField(5);
}

class ModuleConfig_DetectionSensorConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_DetectionSensorConfig({
    $core.bool? enabled,
    $core.int? minimumBroadcastSecs,
    $core.int? stateBroadcastSecs,
    $core.bool? sendBell,
    $core.String? name,
    $core.int? monitorPin,
    ModuleConfig_DetectionSensorConfig_TriggerType? detectionTriggerType,
    $core.bool? usePullup,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (minimumBroadcastSecs != null)
      result.minimumBroadcastSecs = minimumBroadcastSecs;
    if (stateBroadcastSecs != null)
      result.stateBroadcastSecs = stateBroadcastSecs;
    if (sendBell != null) result.sendBell = sendBell;
    if (name != null) result.name = name;
    if (monitorPin != null) result.monitorPin = monitorPin;
    if (detectionTriggerType != null)
      result.detectionTriggerType = detectionTriggerType;
    if (usePullup != null) result.usePullup = usePullup;
    return result;
  }

  ModuleConfig_DetectionSensorConfig._();

  factory ModuleConfig_DetectionSensorConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_DetectionSensorConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.DetectionSensorConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aI(2, _omitFieldNames ? '' : 'minimumBroadcastSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'stateBroadcastSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'sendBell')
    ..aOS(5, _omitFieldNames ? '' : 'name')
    ..aI(6, _omitFieldNames ? '' : 'monitorPin', fieldType: $pb.PbFieldType.OU3)
    ..aE<ModuleConfig_DetectionSensorConfig_TriggerType>(
        7, _omitFieldNames ? '' : 'detectionTriggerType',
        enumValues: ModuleConfig_DetectionSensorConfig_TriggerType.values)
    ..aOB(8, _omitFieldNames ? '' : 'usePullup')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_DetectionSensorConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_DetectionSensorConfig copyWith(
          void Function(ModuleConfig_DetectionSensorConfig) updates) =>
      super.copyWith((message) =>
              updates(message as ModuleConfig_DetectionSensorConfig))
          as ModuleConfig_DetectionSensorConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_DetectionSensorConfig create() =>
      ModuleConfig_DetectionSensorConfig._();
  @$core.override
  ModuleConfig_DetectionSensorConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_DetectionSensorConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_DetectionSensorConfig>(
          create);
  static ModuleConfig_DetectionSensorConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get minimumBroadcastSecs => $_getIZ(1);
  @$pb.TagNumber(2)
  set minimumBroadcastSecs($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinimumBroadcastSecs() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinimumBroadcastSecs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stateBroadcastSecs => $_getIZ(2);
  @$pb.TagNumber(3)
  set stateBroadcastSecs($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStateBroadcastSecs() => $_has(2);
  @$pb.TagNumber(3)
  void clearStateBroadcastSecs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get sendBell => $_getBF(3);
  @$pb.TagNumber(4)
  set sendBell($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSendBell() => $_has(3);
  @$pb.TagNumber(4)
  void clearSendBell() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get name => $_getSZ(4);
  @$pb.TagNumber(5)
  set name($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasName() => $_has(4);
  @$pb.TagNumber(5)
  void clearName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get monitorPin => $_getIZ(5);
  @$pb.TagNumber(6)
  set monitorPin($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMonitorPin() => $_has(5);
  @$pb.TagNumber(6)
  void clearMonitorPin() => $_clearField(6);

  @$pb.TagNumber(7)
  ModuleConfig_DetectionSensorConfig_TriggerType get detectionTriggerType =>
      $_getN(6);
  @$pb.TagNumber(7)
  set detectionTriggerType(
          ModuleConfig_DetectionSensorConfig_TriggerType value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDetectionTriggerType() => $_has(6);
  @$pb.TagNumber(7)
  void clearDetectionTriggerType() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get usePullup => $_getBF(7);
  @$pb.TagNumber(8)
  set usePullup($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUsePullup() => $_has(7);
  @$pb.TagNumber(8)
  void clearUsePullup() => $_clearField(8);
}

class ModuleConfig_PaxcounterConfig extends $pb.GeneratedMessage {
  factory ModuleConfig_PaxcounterConfig({
    $core.bool? enabled,
    $core.int? paxcounterUpdateInterval,
    $core.int? wifiThreshold,
    $core.int? bleThreshold,
  }) {
    final result = create();
    if (enabled != null) result.enabled = enabled;
    if (paxcounterUpdateInterval != null)
      result.paxcounterUpdateInterval = paxcounterUpdateInterval;
    if (wifiThreshold != null) result.wifiThreshold = wifiThreshold;
    if (bleThreshold != null) result.bleThreshold = bleThreshold;
    return result;
  }

  ModuleConfig_PaxcounterConfig._();

  factory ModuleConfig_PaxcounterConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModuleConfig_PaxcounterConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig.PaxcounterConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..aI(2, _omitFieldNames ? '' : 'paxcounterUpdateInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'wifiThreshold')
    ..aI(4, _omitFieldNames ? '' : 'bleThreshold')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_PaxcounterConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModuleConfig_PaxcounterConfig copyWith(
          void Function(ModuleConfig_PaxcounterConfig) updates) =>
      super.copyWith(
              (message) => updates(message as ModuleConfig_PaxcounterConfig))
          as ModuleConfig_PaxcounterConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModuleConfig_PaxcounterConfig create() =>
      ModuleConfig_PaxcounterConfig._();
  @$core.override
  ModuleConfig_PaxcounterConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModuleConfig_PaxcounterConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModuleConfig_PaxcounterConfig>(create);
  static ModuleConfig_PaxcounterConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get paxcounterUpdateInterval => $_getIZ(1);
  @$pb.TagNumber(2)
  set paxcounterUpdateInterval($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPaxcounterUpdateInterval() => $_has(1);
  @$pb.TagNumber(2)
  void clearPaxcounterUpdateInterval() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get wifiThreshold => $_getIZ(2);
  @$pb.TagNumber(3)
  set wifiThreshold($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWifiThreshold() => $_has(2);
  @$pb.TagNumber(3)
  void clearWifiThreshold() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get bleThreshold => $_getIZ(3);
  @$pb.TagNumber(4)
  set bleThreshold($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBleThreshold() => $_has(3);
  @$pb.TagNumber(4)
  void clearBleThreshold() => $_clearField(4);
}

enum ModuleConfig_PayloadVariant {
  mqtt,
  serial,
  externalNotification,
  storeForward,
  rangeTest,
  telemetry,
  cannedMessage,
  audio,
  remoteHardware,
  neighborInfo,
  ambientLighting,
  detectionSensor,
  paxcounter,
  notSet
}

/// Module config message wrapper
class ModuleConfig extends $pb.GeneratedMessage {
  factory ModuleConfig({
    ModuleConfig_MQTTConfig? mqtt,
    ModuleConfig_SerialConfig? serial,
    ModuleConfig_ExternalNotificationConfig? externalNotification,
    ModuleConfig_StoreForwardConfig? storeForward,
    ModuleConfig_RangeTestConfig? rangeTest,
    ModuleConfig_TelemetryConfig? telemetry,
    ModuleConfig_CannedMessageConfig? cannedMessage,
    ModuleConfig_AudioConfig? audio,
    ModuleConfig_RemoteHardwareConfig? remoteHardware,
    ModuleConfig_NeighborInfoConfig? neighborInfo,
    ModuleConfig_AmbientLightingConfig? ambientLighting,
    ModuleConfig_DetectionSensorConfig? detectionSensor,
    ModuleConfig_PaxcounterConfig? paxcounter,
  }) {
    final result = create();
    if (mqtt != null) result.mqtt = mqtt;
    if (serial != null) result.serial = serial;
    if (externalNotification != null)
      result.externalNotification = externalNotification;
    if (storeForward != null) result.storeForward = storeForward;
    if (rangeTest != null) result.rangeTest = rangeTest;
    if (telemetry != null) result.telemetry = telemetry;
    if (cannedMessage != null) result.cannedMessage = cannedMessage;
    if (audio != null) result.audio = audio;
    if (remoteHardware != null) result.remoteHardware = remoteHardware;
    if (neighborInfo != null) result.neighborInfo = neighborInfo;
    if (ambientLighting != null) result.ambientLighting = ambientLighting;
    if (detectionSensor != null) result.detectionSensor = detectionSensor;
    if (paxcounter != null) result.paxcounter = paxcounter;
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
    3: ModuleConfig_PayloadVariant.externalNotification,
    4: ModuleConfig_PayloadVariant.storeForward,
    5: ModuleConfig_PayloadVariant.rangeTest,
    6: ModuleConfig_PayloadVariant.telemetry,
    7: ModuleConfig_PayloadVariant.cannedMessage,
    8: ModuleConfig_PayloadVariant.audio,
    9: ModuleConfig_PayloadVariant.remoteHardware,
    10: ModuleConfig_PayloadVariant.neighborInfo,
    11: ModuleConfig_PayloadVariant.ambientLighting,
    12: ModuleConfig_PayloadVariant.detectionSensor,
    13: ModuleConfig_PayloadVariant.paxcounter,
    0: ModuleConfig_PayloadVariant.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModuleConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    ..aOM<ModuleConfig_MQTTConfig>(1, _omitFieldNames ? '' : 'mqtt',
        subBuilder: ModuleConfig_MQTTConfig.create)
    ..aOM<ModuleConfig_SerialConfig>(2, _omitFieldNames ? '' : 'serial',
        subBuilder: ModuleConfig_SerialConfig.create)
    ..aOM<ModuleConfig_ExternalNotificationConfig>(
        3, _omitFieldNames ? '' : 'externalNotification',
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
    ..aOM<ModuleConfig_RemoteHardwareConfig>(
        9, _omitFieldNames ? '' : 'remoteHardware',
        subBuilder: ModuleConfig_RemoteHardwareConfig.create)
    ..aOM<ModuleConfig_NeighborInfoConfig>(
        10, _omitFieldNames ? '' : 'neighborInfo',
        subBuilder: ModuleConfig_NeighborInfoConfig.create)
    ..aOM<ModuleConfig_AmbientLightingConfig>(
        11, _omitFieldNames ? '' : 'ambientLighting',
        subBuilder: ModuleConfig_AmbientLightingConfig.create)
    ..aOM<ModuleConfig_DetectionSensorConfig>(
        12, _omitFieldNames ? '' : 'detectionSensor',
        subBuilder: ModuleConfig_DetectionSensorConfig.create)
    ..aOM<ModuleConfig_PaxcounterConfig>(
        13, _omitFieldNames ? '' : 'paxcounter',
        subBuilder: ModuleConfig_PaxcounterConfig.create)
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
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
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
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
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
  ModuleConfig_ExternalNotificationConfig get externalNotification => $_getN(2);
  @$pb.TagNumber(3)
  set externalNotification(ModuleConfig_ExternalNotificationConfig value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExternalNotification() => $_has(2);
  @$pb.TagNumber(3)
  void clearExternalNotification() => $_clearField(3);
  @$pb.TagNumber(3)
  ModuleConfig_ExternalNotificationConfig ensureExternalNotification() =>
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

  @$pb.TagNumber(9)
  ModuleConfig_RemoteHardwareConfig get remoteHardware => $_getN(8);
  @$pb.TagNumber(9)
  set remoteHardware(ModuleConfig_RemoteHardwareConfig value) =>
      $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasRemoteHardware() => $_has(8);
  @$pb.TagNumber(9)
  void clearRemoteHardware() => $_clearField(9);
  @$pb.TagNumber(9)
  ModuleConfig_RemoteHardwareConfig ensureRemoteHardware() => $_ensure(8);

  @$pb.TagNumber(10)
  ModuleConfig_NeighborInfoConfig get neighborInfo => $_getN(9);
  @$pb.TagNumber(10)
  set neighborInfo(ModuleConfig_NeighborInfoConfig value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasNeighborInfo() => $_has(9);
  @$pb.TagNumber(10)
  void clearNeighborInfo() => $_clearField(10);
  @$pb.TagNumber(10)
  ModuleConfig_NeighborInfoConfig ensureNeighborInfo() => $_ensure(9);

  @$pb.TagNumber(11)
  ModuleConfig_AmbientLightingConfig get ambientLighting => $_getN(10);
  @$pb.TagNumber(11)
  set ambientLighting(ModuleConfig_AmbientLightingConfig value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasAmbientLighting() => $_has(10);
  @$pb.TagNumber(11)
  void clearAmbientLighting() => $_clearField(11);
  @$pb.TagNumber(11)
  ModuleConfig_AmbientLightingConfig ensureAmbientLighting() => $_ensure(10);

  @$pb.TagNumber(12)
  ModuleConfig_DetectionSensorConfig get detectionSensor => $_getN(11);
  @$pb.TagNumber(12)
  set detectionSensor(ModuleConfig_DetectionSensorConfig value) =>
      $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasDetectionSensor() => $_has(11);
  @$pb.TagNumber(12)
  void clearDetectionSensor() => $_clearField(12);
  @$pb.TagNumber(12)
  ModuleConfig_DetectionSensorConfig ensureDetectionSensor() => $_ensure(11);

  @$pb.TagNumber(13)
  ModuleConfig_PaxcounterConfig get paxcounter => $_getN(12);
  @$pb.TagNumber(13)
  set paxcounter(ModuleConfig_PaxcounterConfig value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasPaxcounter() => $_has(12);
  @$pb.TagNumber(13)
  void clearPaxcounter() => $_clearField(13);
  @$pb.TagNumber(13)
  ModuleConfig_PaxcounterConfig ensurePaxcounter() => $_ensure(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
