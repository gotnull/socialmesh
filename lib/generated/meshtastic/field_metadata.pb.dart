// This is a generated file - do not edit.
//
// Generated from meshtastic/field_metadata.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

///
///  Structured, app/UI-relevant metadata describing a protobuf field or enum value.
///
///  Carried in a single FieldOptions extension (`field_metadata` below), so adding
///  an attribute is a SCHEMA-ONLY change: add a new field to this message (use the
///  next field number) and every generated registry - KMP/Wire, C, Python,
///  TypeScript, Rust, Swift - picks it up automatically. No generator code change
///  is needed, and no additional FieldOptions extension number is consumed.
///
///  The one build step an attribute addition does cost is regenerating
///  protoc-gen-fieldmeta-swift's own binding for this file
///  (tools/protoc-gen-fieldmeta-swift/README.md documents the one-liner). That
///  plugin decodes the option through a generated Swift type rather than through
///  dynamic reflection as the Go plugin does, so a stale binding cannot see the
///  new attribute. It fails loudly rather than dropping it silently.
///
///  Constraint: attributes must be SCALAR (bool / 32-bit int / float / string).
///  A message, enum, bytes, repeated, or map attribute is rejected at generation
///  time (the generators would otherwise emit meaningless, non-deterministic
///  values), and so is a 64-bit integer kind, which TypeScript's number cannot
///  hold exactly. Float attributes must be finite: an open bound is left unset,
///  not set to inf. A list is therefore a single delimited string - see
///  `keywords`. See tools/protoc-gen-fieldmeta.
///
///  BOUNDS (`min_value`, `max_value`) are PRESENTATION metadata, deliberately, and
///  they overlap an existing standard. protovalidate - `(buf.validate.field)`,
///  buf's successor to protoc-gen-validate - is the industry-standard way to
///  express a numeric constraint in a schema, and where a constraint must be
///  ENFORCED that is the thing to reach for, not these two attributes.
///
///  They exist here anyway because protovalidate evaluates CEL against a
///  descriptor at runtime, and the consumers that most need a bound cannot do
///  that: nanopb on the firmware has no descriptors and no CEL, and neither do
///  the generated Wire, prost or swift-protobuf types the clients use. A build-
///  time attribute is the only form that reaches every target.
///
///  The cost is that a bound stated here and a bound enforced elsewhere can
///  drift, and nothing detects it. So: state a bound here only when the firmware
///  genuinely enforces it, treat the firmware as the source of truth, and if
///  `(buf.validate.field)` is ever adopted for a field, make these mirror it
///  rather than compete with it.
///
///  STRING attributes are treated as user-facing display text and are emitted for
///  localization where the target supports it - the Swift target emits
///  String(localized:defaultValue:comment:) keyed by the field's full name, so the
///  English here is the SOURCE string and translations live in the consuming app's
///  catalog. Do not put machine-readable values (regexes, identifiers, format
///  codes) in a string attribute; they would be handed to translators.
///
///  The exception is a short, named set of MACHINE-READABLE string attributes -
///  currently `since_firmware` and `deprecated_since` - which the generators emit
///  as plain literals. A firmware version is compared rather than read, and a
///  translated one would compare wrongly at runtime. The set is deliberately
///  closed and lives in the generators (`machineReadableAttributes`); adding to it
///  is a generator change and should stay rare, because every entry is a string a
///  translator will never see and therefore a place display text can hide.
///
///  To tag a field, set the option on it, e.g.
///    uint32 rx_gpio = 8 [(meshtastic.field_metadata) = { diy_only: true }];
///
///  One attribute, `deprecated`, is special: it MIRRORS the field's standard
///  `[deprecated = true]` option rather than being set inside this annotation.
///  The generators populate it from that standard option so apps can read
///  deprecation at runtime (protobuf runtimes strip options, so it is otherwise
///  invisible). This is the only attribute that costs a generator change.
///
///  Downstream apps use this to drive UI decisions (e.g. hiding DIY-only settings
///  on pre-assembled boards) directly from the protobuf schema.
class FieldMetadata extends $pb.GeneratedMessage {
  factory FieldMetadata({
    $core.bool? diyOnly,
    $core.bool? adminOnly,
    $core.double? minValue,
    $core.double? maxValue,
    $core.String? unit,
    $core.bool? deprecated,
    $core.String? label,
    $core.String? description,
    $core.String? keywords,
    $core.String? sinceFirmware,
    $core.String? deprecatedSince,
  }) {
    final result = create();
    if (diyOnly != null) result.diyOnly = diyOnly;
    if (adminOnly != null) result.adminOnly = adminOnly;
    if (minValue != null) result.minValue = minValue;
    if (maxValue != null) result.maxValue = maxValue;
    if (unit != null) result.unit = unit;
    if (deprecated != null) result.deprecated = deprecated;
    if (label != null) result.label = label;
    if (description != null) result.description = description;
    if (keywords != null) result.keywords = keywords;
    if (sinceFirmware != null) result.sinceFirmware = sinceFirmware;
    if (deprecatedSince != null) result.deprecatedSince = deprecatedSince;
    return result;
  }

  FieldMetadata._();

  factory FieldMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FieldMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FieldMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'meshtastic'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'diyOnly')
    ..aOB(2, _omitFieldNames ? '' : 'adminOnly')
    ..aD(3, _omitFieldNames ? '' : 'minValue')
    ..aD(4, _omitFieldNames ? '' : 'maxValue')
    ..aOS(5, _omitFieldNames ? '' : 'unit')
    ..aOB(6, _omitFieldNames ? '' : 'deprecated')
    ..aOS(7, _omitFieldNames ? '' : 'label')
    ..aOS(8, _omitFieldNames ? '' : 'description')
    ..aOS(9, _omitFieldNames ? '' : 'keywords')
    ..aOS(10, _omitFieldNames ? '' : 'sinceFirmware')
    ..aOS(11, _omitFieldNames ? '' : 'deprecatedSince')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldMetadata copyWith(void Function(FieldMetadata) updates) =>
      super.copyWith((message) => updates(message as FieldMetadata))
          as FieldMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FieldMetadata create() => FieldMetadata._();
  @$core.override
  FieldMetadata createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FieldMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FieldMetadata>(create);
  static FieldMetadata? _defaultInstance;

  ///
  ///  Field is only relevant to DIY hardware builds. Apps may hide it when
  ///  connected to a pre-assembled / commercial board.
  @$pb.TagNumber(1)
  $core.bool get diyOnly => $_getBF(0);
  @$pb.TagNumber(1)
  set diyOnly($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDiyOnly() => $_has(0);
  @$pb.TagNumber(1)
  void clearDiyOnly() => $_clearField(1);

  ///
  ///  Field is only relevant in advanced / administrative contexts and may be
  ///  hidden from the default UI.
  @$pb.TagNumber(2)
  $core.bool get adminOnly => $_getBF(1);
  @$pb.TagNumber(2)
  set adminOnly($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAdminOnly() => $_has(1);
  @$pb.TagNumber(2)
  void clearAdminOnly() => $_clearField(2);

  ///
  ///  Inclusive lower bound, for PRESENTATION: slider and stepper range, and the
  ///  client-side check that stops a user entering a value the firmware would
  ///  reject anyway. It is NOT the wire contract and nothing enforces it on
  ///  receipt - see the note on bounds below.
  @$pb.TagNumber(3)
  $core.double get minValue => $_getN(2);
  @$pb.TagNumber(3)
  set minValue($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMinValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinValue() => $_clearField(3);

  ///
  ///  Inclusive upper bound, for PRESENTATION. Same status as `min_value`.
  @$pb.TagNumber(4)
  $core.double get maxValue => $_getN(3);
  @$pb.TagNumber(4)
  set maxValue($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxValue() => $_clearField(4);

  ///
  ///  Human-facing unit label for the value (e.g. "m", "s", "dBm").
  @$pb.TagNumber(5)
  $core.String get unit => $_getSZ(4);
  @$pb.TagNumber(5)
  set unit($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUnit() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnit() => $_clearField(5);

  ///
  ///  Field is deprecated. MIRRORS the field's standard `[deprecated = true]`
  ///  option - the generators populate this automatically from that option so
  ///  every consumer can read it at runtime (protobuf runtimes strip options, so
  ///  the standard `deprecated` bit is otherwise invisible to apps). Setting it
  ///  by hand in a (meshtastic.field_metadata) annotation is a generation-time
  ///  ERROR; mark the field `[deprecated = true]` as usual and it flows through
  ///  here.
  @$pb.TagNumber(6)
  $core.bool get deprecated => $_getBF(5);
  @$pb.TagNumber(6)
  set deprecated($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDeprecated() => $_has(5);
  @$pb.TagNumber(6)
  void clearDeprecated() => $_clearField(6);

  ///
  ///  Short human-facing name for the field, as a UI would label the control that
  ///  edits it (e.g. "Hop Limit"). Source string for localization; see the note on
  ///  string attributes above.
  @$pb.TagNumber(7)
  $core.String get label => $_getSZ(6);
  @$pb.TagNumber(7)
  set label($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLabel() => $_has(6);
  @$pb.TagNumber(7)
  void clearLabel() => $_clearField(7);

  ///
  ///  One-sentence plain-language explanation of what the field does, suitable for
  ///  showing under the control (e.g. "How many times a message may be repeated
  ///  before it stops being forwarded."). Source string for localization.
  @$pb.TagNumber(8)
  $core.String get description => $_getSZ(7);
  @$pb.TagNumber(8)
  set description($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDescription() => $_has(7);
  @$pb.TagNumber(8)
  void clearDescription() => $_clearField(8);

  ///
  ///  Additional terms a user might search for to find this field, beyond its
  ///  label - abbreviations, older names, and related concepts (e.g. for
  ///  `hop_limit`: "hops|ttl|range"). Attributes must be scalar, so this is a
  ///  single string; entries are separated by "|" and surrounding whitespace is
  ///  ignored. "|" is used rather than "," because a keyword may itself contain a
  ///  comma. Source string for localization.
  @$pb.TagNumber(9)
  $core.String get keywords => $_getSZ(8);
  @$pb.TagNumber(9)
  set keywords($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasKeywords() => $_has(8);
  @$pb.TagNumber(9)
  void clearKeywords() => $_clearField(9);

  ///
  ///  The first firmware version that has this field, e.g. "2.7.12".
  ///
  ///  A client showing a control for a field the connected node does not have
  ///  offers a setting that will be ignored; one hiding a field the node does
  ///  have loses a setting that works. Today each client answers that from a
  ///  version constant written into its own UI, so the same boundary is stated
  ///  independently in each of them - and when firmware adds a field, every
  ///  client has to learn the number separately.
  ///
  ///  MACHINE-READABLE (see the note on string attributes above): a version is
  ///  compared, not read, and is emitted as a plain literal rather than as
  ///  localizable text.
  ///
  ///  Presentation metadata, like `min_value`: firmware still has to defend
  ///  itself, since an older client can always write a field a newer firmware
  ///  ignores, and a newer client a field an older one does not know.
  ///
  ///  Unset means "as long as anyone needs to care", which is the common case -
  ///  annotate a field only where a client genuinely has to make this decision.
  @$pb.TagNumber(10)
  $core.String get sinceFirmware => $_getSZ(9);
  @$pb.TagNumber(10)
  set sinceFirmware($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSinceFirmware() => $_has(9);
  @$pb.TagNumber(10)
  void clearSinceFirmware() => $_clearField(10);

  ///
  ///  The first firmware version that no longer honours this field, e.g. "2.7.1"
  ///  on `compass_north_top`: `compass_orientation` replaced it in 2.3.13, but
  ///  firmware went on reading the old field until 2.7.1. The replacement's
  ///  arrival and the old field's removal are different releases, which is the
  ///  whole reason this is worth writing down.
  ///
  ///  Distinct from `deprecated`, which says only THAT a field is superseded.
  ///  That is enough to stop offering it on new firmware but not enough to keep
  ///  offering it where it still works: a node below this version needs the field,
  ///  and a client that hides it on the strength of the boolean alone takes a
  ///  working setting away. Both clients do exactly that today.
  ///
  ///  So the intended rule is: show the field below this version; at or above it,
  ///  treat it as `deprecated` does - hidden unless the node holds a non-default
  ///  value, which keeps a stale setting visible rather than silently saved.
  ///
  ///  Deprecated is not removed. A field firmware has stopped reading entirely is
  ///  a different statement and wants its own annotation rather than this one.
  ///
  ///  MACHINE-READABLE, and presentation metadata, on the same terms as
  ///  `since_firmware`.
  @$pb.TagNumber(11)
  $core.String get deprecatedSince => $_getSZ(10);
  @$pb.TagNumber(11)
  set deprecatedSince($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDeprecatedSince() => $_has(10);
  @$pb.TagNumber(11)
  void clearDeprecatedSince() => $_clearField(11);
}

class Field_metadata {
  static final fieldMetadata = $pb.Extension<FieldMetadata>(
      _omitMessageNames ? '' : 'google.protobuf.FieldOptions',
      _omitFieldNames ? '' : 'fieldMetadata',
      51001,
      $pb.PbFieldType.OM,
      defaultOrMaker: FieldMetadata.getDefault,
      subBuilder: FieldMetadata.create);
  static final enumValueMetadata = $pb.Extension<FieldMetadata>(
      _omitMessageNames ? '' : 'google.protobuf.EnumValueOptions',
      _omitFieldNames ? '' : 'enumValueMetadata',
      51001,
      $pb.PbFieldType.OM,
      defaultOrMaker: FieldMetadata.getDefault,
      subBuilder: FieldMetadata.create);
  static void registerAllExtensions($pb.ExtensionRegistry registry) {
    registry.add(fieldMetadata);
    registry.add(enumValueMetadata);
  }
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
