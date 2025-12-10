// This is a generated file - do not edit.
//
// Generated from meshtastic/device_ui.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompassMode extends $pb.ProtobufEnum {
  ///
  ///  Compass with dynamic ring and heading
  static const CompassMode DYNAMIC =
      CompassMode._(0, _omitEnumNames ? '' : 'DYNAMIC');

  ///
  ///  Compass with fixed ring and heading
  static const CompassMode FIXED_RING =
      CompassMode._(1, _omitEnumNames ? '' : 'FIXED_RING');

  ///
  ///  Compass with heading and freeze option
  static const CompassMode FREEZE_HEADING =
      CompassMode._(2, _omitEnumNames ? '' : 'FREEZE_HEADING');

  static const $core.List<CompassMode> values = <CompassMode>[
    DYNAMIC,
    FIXED_RING,
    FREEZE_HEADING,
  ];

  static final $core.List<CompassMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static CompassMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CompassMode._(super.value, super.name);
}

class Theme extends $pb.ProtobufEnum {
  ///
  ///  Dark
  static const Theme DARK = Theme._(0, _omitEnumNames ? '' : 'DARK');

  ///
  ///  Light
  static const Theme LIGHT = Theme._(1, _omitEnumNames ? '' : 'LIGHT');

  ///
  ///  Red
  static const Theme RED = Theme._(2, _omitEnumNames ? '' : 'RED');

  static const $core.List<Theme> values = <Theme>[
    DARK,
    LIGHT,
    RED,
  ];

  static final $core.List<Theme?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Theme? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Theme._(super.value, super.name);
}

///
///  Localization
class Language extends $pb.ProtobufEnum {
  ///
  ///  English
  static const Language ENGLISH =
      Language._(0, _omitEnumNames ? '' : 'ENGLISH');

  ///
  ///  French
  static const Language FRENCH = Language._(1, _omitEnumNames ? '' : 'FRENCH');

  ///
  ///  German
  static const Language GERMAN = Language._(2, _omitEnumNames ? '' : 'GERMAN');

  ///
  ///  Italian
  static const Language ITALIAN =
      Language._(3, _omitEnumNames ? '' : 'ITALIAN');

  ///
  ///  Portuguese
  static const Language PORTUGUESE =
      Language._(4, _omitEnumNames ? '' : 'PORTUGUESE');

  ///
  ///  Spanish
  static const Language SPANISH =
      Language._(5, _omitEnumNames ? '' : 'SPANISH');

  ///
  ///  Swedish
  static const Language SWEDISH =
      Language._(6, _omitEnumNames ? '' : 'SWEDISH');

  ///
  ///  Finnish
  static const Language FINNISH =
      Language._(7, _omitEnumNames ? '' : 'FINNISH');

  ///
  ///  Polish
  static const Language POLISH = Language._(8, _omitEnumNames ? '' : 'POLISH');

  ///
  ///  Turkish
  static const Language TURKISH =
      Language._(9, _omitEnumNames ? '' : 'TURKISH');

  ///
  ///  Serbian
  static const Language SERBIAN =
      Language._(10, _omitEnumNames ? '' : 'SERBIAN');

  ///
  ///  Russian
  static const Language RUSSIAN =
      Language._(11, _omitEnumNames ? '' : 'RUSSIAN');

  ///
  ///  Dutch
  static const Language DUTCH = Language._(12, _omitEnumNames ? '' : 'DUTCH');

  ///
  ///  Greek
  static const Language GREEK = Language._(13, _omitEnumNames ? '' : 'GREEK');

  ///
  ///  Norwegian
  static const Language NORWEGIAN =
      Language._(14, _omitEnumNames ? '' : 'NORWEGIAN');

  ///
  ///  Slovenian
  static const Language SLOVENIAN =
      Language._(15, _omitEnumNames ? '' : 'SLOVENIAN');

  ///
  ///  Ukrainian
  static const Language UKRAINIAN =
      Language._(16, _omitEnumNames ? '' : 'UKRAINIAN');

  ///
  ///  Bulgarian
  static const Language BULGARIAN =
      Language._(17, _omitEnumNames ? '' : 'BULGARIAN');

  ///
  ///  Czech
  static const Language CZECH = Language._(18, _omitEnumNames ? '' : 'CZECH');

  ///
  ///  Danish
  static const Language DANISH = Language._(19, _omitEnumNames ? '' : 'DANISH');

  ///
  ///  Simplified Chinese (experimental)
  static const Language SIMPLIFIED_CHINESE =
      Language._(30, _omitEnumNames ? '' : 'SIMPLIFIED_CHINESE');

  ///
  ///  Traditional Chinese (experimental)
  static const Language TRADITIONAL_CHINESE =
      Language._(31, _omitEnumNames ? '' : 'TRADITIONAL_CHINESE');

  static const $core.List<Language> values = <Language>[
    ENGLISH,
    FRENCH,
    GERMAN,
    ITALIAN,
    PORTUGUESE,
    SPANISH,
    SWEDISH,
    FINNISH,
    POLISH,
    TURKISH,
    SERBIAN,
    RUSSIAN,
    DUTCH,
    GREEK,
    NORWEGIAN,
    SLOVENIAN,
    UKRAINIAN,
    BULGARIAN,
    CZECH,
    DANISH,
    SIMPLIFIED_CHINESE,
    TRADITIONAL_CHINESE,
  ];

  static final $core.Map<$core.int, Language> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Language? valueOf($core.int value) => _byValue[value];

  const Language._(super.value, super.name);
}

///
///  How the GPS coordinates are displayed on the OLED screen.
class DeviceUIConfig_GpsCoordinateFormat extends $pb.ProtobufEnum {
  ///
  ///  GPS coordinates are displayed in the normal decimal degrees format:
  ///  DD.DDDDDD DDD.DDDDDD
  static const DeviceUIConfig_GpsCoordinateFormat DEC =
      DeviceUIConfig_GpsCoordinateFormat._(0, _omitEnumNames ? '' : 'DEC');

  ///
  ///  GPS coordinates are displayed in the degrees minutes seconds format:
  ///  DD°MM'SS"C DDD°MM'SS"C, where C is the compass point representing the locations quadrant
  static const DeviceUIConfig_GpsCoordinateFormat DMS =
      DeviceUIConfig_GpsCoordinateFormat._(1, _omitEnumNames ? '' : 'DMS');

  ///
  ///  Universal Transverse Mercator format:
  ///  ZZB EEEEEE NNNNNNN, where Z is zone, B is band, E is easting, N is northing
  static const DeviceUIConfig_GpsCoordinateFormat UTM =
      DeviceUIConfig_GpsCoordinateFormat._(2, _omitEnumNames ? '' : 'UTM');

  ///
  ///  Military Grid Reference System format:
  ///  ZZB CD EEEEE NNNNN, where Z is zone, B is band, C is the east 100k square, D is the north 100k square,
  ///  E is easting, N is northing
  static const DeviceUIConfig_GpsCoordinateFormat MGRS =
      DeviceUIConfig_GpsCoordinateFormat._(3, _omitEnumNames ? '' : 'MGRS');

  ///
  ///  Open Location Code (aka Plus Codes).
  static const DeviceUIConfig_GpsCoordinateFormat OLC =
      DeviceUIConfig_GpsCoordinateFormat._(4, _omitEnumNames ? '' : 'OLC');

  ///
  ///  Ordnance Survey Grid Reference (the National Grid System of the UK).
  ///  Format: AB EEEEE NNNNN, where A is the east 100k square, B is the north 100k square,
  ///  E is the easting, N is the northing
  static const DeviceUIConfig_GpsCoordinateFormat OSGR =
      DeviceUIConfig_GpsCoordinateFormat._(5, _omitEnumNames ? '' : 'OSGR');

  ///
  ///  Maidenhead Locator System
  ///  Described here: https://en.wikipedia.org/wiki/Maidenhead_Locator_System
  static const DeviceUIConfig_GpsCoordinateFormat MLS =
      DeviceUIConfig_GpsCoordinateFormat._(6, _omitEnumNames ? '' : 'MLS');

  static const $core.List<DeviceUIConfig_GpsCoordinateFormat> values =
      <DeviceUIConfig_GpsCoordinateFormat>[
    DEC,
    DMS,
    UTM,
    MGRS,
    OLC,
    OSGR,
    MLS,
  ];

  static final $core.List<DeviceUIConfig_GpsCoordinateFormat?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static DeviceUIConfig_GpsCoordinateFormat? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceUIConfig_GpsCoordinateFormat._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
