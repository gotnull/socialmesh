// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'reticulum_capture_classifier.dart';

/// Provenance origin of a capture file.
enum ReticulumCaptureSource {
  /// Captured directly by Socialmesh's `ReticulumCaptureWriter` on
  /// this device. Default for files in the live capture directory.
  local,

  /// Imported from another Socialmesh installation via the system
  /// share sheet (AirDrop, iMessage, Files share, etc.).
  shared,

  /// Imported via AirDrop specifically.
  airdrop,

  /// Manually copied / uploaded into the imported folder by the
  /// operator. Used when none of the more specific sources apply.
  manual,
}

/// Sidecar metadata for a single SMRC capture file. Stored as
/// `<capture>.meta.json` next to the capture itself.
///
/// Crucially, this object **never** holds payload bytes — only
/// envelope metadata derived from the SMRC headers. The classifier
/// is responsible for populating the kind / counts / source-ID list;
/// human-curated fields (deviceModel, firmwareVersion, region,
/// channelIndex, notes, source) start `null`/empty and are filled
/// in via the library UI.
class ReticulumCaptureMetadata {
  const ReticulumCaptureMetadata({
    required this.schemaVersion,
    required this.captureKind,
    required this.createdAtIso,
    required this.classifiedAtIso,
    required this.source,
    required this.deviceModel,
    required this.firmwareVersion,
    required this.region,
    required this.channelIndex,
    required this.notes,
    required this.recordCount,
    required this.firstSeenMs,
    required this.lastSeenMs,
    required this.distinctSources,
    required this.containsHarnessMagic,
    required this.checksumSha256,
  });

  /// Sidecar schema version. Bump when a field changes shape.
  static const int currentSchemaVersion = 1;

  static const String fileSuffix = '.meta.json';

  final int schemaVersion;
  final ReticulumCaptureKind captureKind;
  final String createdAtIso;
  final String classifiedAtIso;
  final ReticulumCaptureSource source;
  final String? deviceModel;
  final String? firmwareVersion;
  final String? region;
  final int? channelIndex;
  final String notes;
  final int recordCount;
  final int? firstSeenMs;
  final int? lastSeenMs;
  final List<int> distinctSources;
  final bool containsHarnessMagic;
  final String checksumSha256;

  /// Build initial metadata for a freshly-classified capture file.
  /// Caller-supplied: createdAt (file mtime / now), source, checksum.
  factory ReticulumCaptureMetadata.fromClassification({
    required ReticulumCaptureClassification classification,
    required DateTime createdAt,
    required DateTime classifiedAt,
    required ReticulumCaptureSource source,
    required String checksumSha256,
    String? deviceModel,
    String? firmwareVersion,
    String? region,
    int? channelIndex,
    String notes = '',
  }) {
    return ReticulumCaptureMetadata(
      schemaVersion: currentSchemaVersion,
      captureKind: classification.kind,
      createdAtIso: createdAt.toUtc().toIso8601String(),
      classifiedAtIso: classifiedAt.toUtc().toIso8601String(),
      source: source,
      deviceModel: deviceModel,
      firmwareVersion: firmwareVersion,
      region: region,
      channelIndex: channelIndex,
      notes: notes,
      recordCount: classification.recordCount,
      firstSeenMs: classification.firstSeenMs,
      lastSeenMs: classification.lastSeenMs,
      distinctSources: List<int>.unmodifiable(classification.distinctSources),
      containsHarnessMagic: classification.containsHarnessMagic,
      checksumSha256: checksumSha256,
    );
  }

  ReticulumCaptureMetadata copyWith({
    ReticulumCaptureSource? source,
    String? deviceModel,
    bool deviceModelExplicitNull = false,
    String? firmwareVersion,
    bool firmwareVersionExplicitNull = false,
    String? region,
    bool regionExplicitNull = false,
    int? channelIndex,
    bool channelIndexExplicitNull = false,
    String? notes,
  }) {
    return ReticulumCaptureMetadata(
      schemaVersion: schemaVersion,
      captureKind: captureKind,
      createdAtIso: createdAtIso,
      classifiedAtIso: classifiedAtIso,
      source: source ?? this.source,
      deviceModel: deviceModelExplicitNull
          ? null
          : (deviceModel ?? this.deviceModel),
      firmwareVersion: firmwareVersionExplicitNull
          ? null
          : (firmwareVersion ?? this.firmwareVersion),
      region: regionExplicitNull ? null : (region ?? this.region),
      channelIndex: channelIndexExplicitNull
          ? null
          : (channelIndex ?? this.channelIndex),
      notes: notes ?? this.notes,
      recordCount: recordCount,
      firstSeenMs: firstSeenMs,
      lastSeenMs: lastSeenMs,
      distinctSources: distinctSources,
      containsHarnessMagic: containsHarnessMagic,
      checksumSha256: checksumSha256,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'captureKind': captureKind.name,
      'createdAt': createdAtIso,
      'classifiedAt': classifiedAtIso,
      'source': source.name,
      'deviceModel': deviceModel,
      'firmwareVersion': firmwareVersion,
      'region': region,
      'channelIndex': channelIndex,
      'notes': notes,
      'recordCount': recordCount,
      'firstSeenMs': firstSeenMs,
      'lastSeenMs': lastSeenMs,
      'distinctSources': distinctSources,
      'containsHarnessMagic': containsHarnessMagic,
      'checksumSha256': checksumSha256,
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ReticulumCaptureMetadata fromJson(Map<String, dynamic> json) {
    return ReticulumCaptureMetadata(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      captureKind: _kindFromString(json['captureKind'] as String?),
      createdAtIso: (json['createdAt'] as String?) ?? '',
      classifiedAtIso: (json['classifiedAt'] as String?) ?? '',
      source: _sourceFromString(json['source'] as String?),
      deviceModel: json['deviceModel'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      region: json['region'] as String?,
      channelIndex: (json['channelIndex'] as num?)?.toInt(),
      notes: (json['notes'] as String?) ?? '',
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      firstSeenMs: (json['firstSeenMs'] as num?)?.toInt(),
      lastSeenMs: (json['lastSeenMs'] as num?)?.toInt(),
      distinctSources: ((json['distinctSources'] as List?) ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList(growable: false),
      containsHarnessMagic: (json['containsHarnessMagic'] as bool?) ?? false,
      checksumSha256: (json['checksumSha256'] as String?) ?? '',
    );
  }

  static ReticulumCaptureMetadata fromJsonString(String s) {
    final parsed = json.decode(s);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Metadata sidecar is not a JSON object');
    }
    return fromJson(parsed);
  }

  static ReticulumCaptureKind _kindFromString(String? s) {
    switch (s) {
      case 'harness':
        return ReticulumCaptureKind.harness;
      case 'realCandidate':
        return ReticulumCaptureKind.realCandidate;
      case 'unsupportedVersion':
        return ReticulumCaptureKind.unsupportedVersion;
      case 'invalid':
      default:
        return ReticulumCaptureKind.invalid;
    }
  }

  static ReticulumCaptureSource _sourceFromString(String? s) {
    switch (s) {
      case 'shared':
        return ReticulumCaptureSource.shared;
      case 'airdrop':
        return ReticulumCaptureSource.airdrop;
      case 'manual':
        return ReticulumCaptureSource.manual;
      case 'local':
      default:
        return ReticulumCaptureSource.local;
    }
  }
}
