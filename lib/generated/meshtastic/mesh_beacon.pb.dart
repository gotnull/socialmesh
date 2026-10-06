// This is a generated file - do not edit.
//
// Generated from meshtastic/mesh_beacon.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'channel.pb.dart' as $0;
import 'config.pbenum.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

///
///  Payload for MESH_BEACON_APP packets.
///  Periodically broadcast by nodes in beacon mode.
///  Listeners deliver the text message to the local inbox and cache any offered
///  channel/preset for the client app to act on - the firmware never auto-applies them.
class MeshBeacon extends $pb.GeneratedMessage {
  factory MeshBeacon({
    $core.String? message,
    $0.ChannelSettings? offerChannel,
    $1.Config_LoRaConfig_RegionCode? offerRegion,
    $1.Config_LoRaConfig_ModemPreset? offerPreset,
    $core.int? offerFrequencySlot,
  }) {
    final result = create();
    if (message != null) result.message = message;
    if (offerChannel != null) result.offerChannel = offerChannel;
    if (offerRegion != null) result.offerRegion = offerRegion;
    if (offerPreset != null) result.offerPreset = offerPreset;
    if (offerFrequencySlot != null)
      result.offerFrequencySlot = offerFrequencySlot;
    return result;
  }

  MeshBeacon._();

  factory MeshBeacon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MeshBeacon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MeshBeacon',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..aOM<$0.ChannelSettings>(2, _omitFieldNames ? '' : 'offerChannel',
        subBuilder: $0.ChannelSettings.create)
    ..aE<$1.Config_LoRaConfig_RegionCode>(
        3, _omitFieldNames ? '' : 'offerRegion',
        enumValues: $1.Config_LoRaConfig_RegionCode.values)
    ..aE<$1.Config_LoRaConfig_ModemPreset>(
        4, _omitFieldNames ? '' : 'offerPreset',
        enumValues: $1.Config_LoRaConfig_ModemPreset.values)
    ..aI(5, _omitFieldNames ? '' : 'offerFrequencySlot',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshBeacon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MeshBeacon copyWith(void Function(MeshBeacon) updates) =>
      super.copyWith((message) => updates(message as MeshBeacon)) as MeshBeacon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MeshBeacon create() => MeshBeacon._();
  @$core.override
  MeshBeacon createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MeshBeacon getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MeshBeacon>(create);
  static MeshBeacon? _defaultInstance;

  ///
  ///  Human-readable beacon message. Max 100 bytes enforced by firmware on send.
  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);

  ///
  ///  Optional channel (name + PSK) being advertised to listening clients.
  ///  A client app may offer to switch the user to this channel; firmware never applies it automatically.
  @$pb.TagNumber(2)
  $0.ChannelSettings get offerChannel => $_getN(1);
  @$pb.TagNumber(2)
  set offerChannel($0.ChannelSettings value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOfferChannel() => $_has(1);
  @$pb.TagNumber(2)
  void clearOfferChannel() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ChannelSettings ensureOfferChannel() => $_ensure(1);

  ///
  ///  Optional region being advertised alongside offer_preset.
  @$pb.TagNumber(3)
  $1.Config_LoRaConfig_RegionCode get offerRegion => $_getN(2);
  @$pb.TagNumber(3)
  set offerRegion($1.Config_LoRaConfig_RegionCode value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOfferRegion() => $_has(2);
  @$pb.TagNumber(3)
  void clearOfferRegion() => $_clearField(3);

  ///
  ///  Optional modem preset being advertised.
  ///  Combined with offer_region, tells a client "there is a mesh on this preset/region".
  @$pb.TagNumber(4)
  $1.Config_LoRaConfig_ModemPreset get offerPreset => $_getN(3);
  @$pb.TagNumber(4)
  set offerPreset($1.Config_LoRaConfig_ModemPreset value) =>
      $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasOfferPreset() => $_has(3);
  @$pb.TagNumber(4)
  void clearOfferPreset() => $_clearField(4);

  ///
  ///  Frequency slot this mesh uses, 1-based, matching Config.LoRaConfig.channel_num.
  ///  OMITTED when a receiver can derive the slot itself from offer_region, offer_channel's
  ///  name and offer_preset - an unset offer_preset means the region's default preset. That
  ///  covers both a region with a mandated slot and a mesh on the default name hash.
  ///  PRESENT means this mesh deliberately deviates from what derivation would produce; a
  ///  client should still validate the result against its own region before offering to join.
  ///  Do not send 0 - it is the same as omitting the field.
  @$pb.TagNumber(5)
  $core.int get offerFrequencySlot => $_getIZ(4);
  @$pb.TagNumber(5)
  set offerFrequencySlot($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOfferFrequencySlot() => $_has(4);
  @$pb.TagNumber(5)
  void clearOfferFrequencySlot() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
