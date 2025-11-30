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

class LogRecord_Level extends $pb.ProtobufEnum {
  static const LogRecord_Level UNSET =
      LogRecord_Level._(0, _omitEnumNames ? '' : 'UNSET');
  static const LogRecord_Level CRITICAL =
      LogRecord_Level._(50, _omitEnumNames ? '' : 'CRITICAL');
  static const LogRecord_Level ERROR =
      LogRecord_Level._(40, _omitEnumNames ? '' : 'ERROR');
  static const LogRecord_Level WARNING =
      LogRecord_Level._(30, _omitEnumNames ? '' : 'WARNING');
  static const LogRecord_Level INFO =
      LogRecord_Level._(20, _omitEnumNames ? '' : 'INFO');
  static const LogRecord_Level DEBUG =
      LogRecord_Level._(10, _omitEnumNames ? '' : 'DEBUG');
  static const LogRecord_Level TRACE =
      LogRecord_Level._(5, _omitEnumNames ? '' : 'TRACE');

  static const $core.List<LogRecord_Level> values = <LogRecord_Level>[
    UNSET,
    CRITICAL,
    ERROR,
    WARNING,
    INFO,
    DEBUG,
    TRACE,
  ];

  static final $core.Map<$core.int, LogRecord_Level> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static LogRecord_Level? valueOf($core.int value) => _byValue[value];

  const LogRecord_Level._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
