// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'reticulum_capture_replay.dart';
import 'reticulum_safe_log.dart';

/// Provenance classification for a SMRC capture file.
enum ReticulumCaptureKind {
  /// SMRC v1 file whose records all begin with the harness magic
  /// `SHRN`. Safe to exclude from any future Phase 2 wire-format
  /// derivation corpus.
  harness,

  /// SMRC v1 file that contains at least one record whose payload
  /// does NOT begin with `SHRN`. Treat as a real-mesh capture
  /// candidate — eligible for Phase 2 inputs once provenance has
  /// been verified.
  realCandidate,

  /// File magic is `SMRC` but the version byte is not `0x01`.
  /// Reader cannot safely decode records.
  unsupportedVersion,

  /// File does not start with `SMRC\x01`, or record decoding raised
  /// an unexpected error, or the file decoded to zero records.
  invalid,
}

/// Result of classifying a single capture file. Carries enough
/// metadata for [ReticulumCaptureLibrary] to write a sidecar without
/// re-reading the file.
class ReticulumCaptureClassification {
  const ReticulumCaptureClassification({
    required this.kind,
    required this.recordCount,
    required this.firstSeenMs,
    required this.lastSeenMs,
    required this.distinctSources,
    required this.containsHarnessMagic,
  });

  final ReticulumCaptureKind kind;
  final int recordCount;
  final int? firstSeenMs;
  final int? lastSeenMs;
  final List<int> distinctSources;
  final bool containsHarnessMagic;

  static const _empty = ReticulumCaptureClassification(
    kind: ReticulumCaptureKind.invalid,
    recordCount: 0,
    firstSeenMs: null,
    lastSeenMs: null,
    distinctSources: <int>[],
    containsHarnessMagic: false,
  );

  static ReticulumCaptureClassification get invalid =>
      _empty.copyWith(kind: ReticulumCaptureKind.invalid);

  static ReticulumCaptureClassification get unsupportedVersion =>
      _empty.copyWith(kind: ReticulumCaptureKind.unsupportedVersion);

  ReticulumCaptureClassification copyWith({
    ReticulumCaptureKind? kind,
    int? recordCount,
    int? firstSeenMs,
    int? lastSeenMs,
    List<int>? distinctSources,
    bool? containsHarnessMagic,
  }) {
    return ReticulumCaptureClassification(
      kind: kind ?? this.kind,
      recordCount: recordCount ?? this.recordCount,
      firstSeenMs: firstSeenMs ?? this.firstSeenMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      distinctSources: distinctSources ?? this.distinctSources,
      containsHarnessMagic: containsHarnessMagic ?? this.containsHarnessMagic,
    );
  }
}

/// Classifies a SMRC capture file into one of the [ReticulumCaptureKind]
/// buckets. Pure logic; touches the filesystem only to read the file.
class ReticulumCaptureClassifier {
  const ReticulumCaptureClassifier();

  /// Synchronous-shaped classifier that operates on bytes. Useful for
  /// tests; avoids re-reading the file from disk.
  ReticulumCaptureClassification classifyBytes(Uint8List bytes) {
    List<dynamic> records;
    try {
      records = ReticulumCaptureReplay.decodeAll(bytes);
    } on UnsupportedCaptureVersion catch (e) {
      // The shared decoder throws this for both "magic doesn't match"
      // (e.version == null) AND "magic matches but version byte is
      // unknown" (e.version != null). Disambiguate so the library can
      // present the right rejection reason to the user.
      if (e.version == null) {
        ReticulumSafeLog.event('classify_invalid reason=bad_magic');
        return ReticulumCaptureClassification.invalid;
      }
      ReticulumSafeLog.event(
        'classify_unsupported_version version=${e.version}',
      );
      return ReticulumCaptureClassification.unsupportedVersion;
    } catch (e) {
      ReticulumSafeLog.event('classify_invalid error=$e');
      return ReticulumCaptureClassification.invalid;
    }

    if (records.isEmpty) {
      ReticulumSafeLog.event('classify_invalid reason=empty_records');
      return ReticulumCaptureClassification.invalid;
    }

    var allHarness = true;
    var anyHarness = false;
    final distinctSources = <int>{};
    int? firstSeenMs;
    int? lastSeenMs;

    for (final r in records) {
      distinctSources.add(r.fromNode as int);
      final ts = r.timestampMs as int;
      firstSeenMs = (firstSeenMs == null || ts < firstSeenMs)
          ? ts
          : firstSeenMs;
      lastSeenMs = (lastSeenMs == null || ts > lastSeenMs) ? ts : lastSeenMs;

      final isHarness = _payloadHasHarnessMagic(r.payload as Uint8List);
      if (isHarness) {
        anyHarness = true;
      } else {
        allHarness = false;
      }
    }

    final kind = allHarness
        ? ReticulumCaptureKind.harness
        : ReticulumCaptureKind.realCandidate;

    final sources = distinctSources.toList()..sort();
    final result = ReticulumCaptureClassification(
      kind: kind,
      recordCount: records.length,
      firstSeenMs: firstSeenMs,
      lastSeenMs: lastSeenMs,
      distinctSources: List.unmodifiable(sources),
      containsHarnessMagic: anyHarness,
    );
    ReticulumSafeLog.event(
      'classify_ok kind=${kind.name} records=${records.length} '
      'sources=${sources.length} harness_magic=$anyHarness',
    );
    return result;
  }

  /// Read [file] and return its classification. Never throws; returns
  /// [ReticulumCaptureKind.invalid] for any I/O error.
  Future<ReticulumCaptureClassification> classify(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return classifyBytes(bytes);
    } catch (e) {
      ReticulumSafeLog.event('classify_io_error error=$e');
      return ReticulumCaptureClassification.invalid;
    }
  }

  static bool _payloadHasHarnessMagic(Uint8List payload) {
    if (payload.length < 4) return false;
    // ASCII "SHRN" = 0x53 0x48 0x52 0x4E.
    return payload[0] == 0x53 &&
        payload[1] == 0x48 &&
        payload[2] == 0x52 &&
        payload[3] == 0x4E;
  }
}
