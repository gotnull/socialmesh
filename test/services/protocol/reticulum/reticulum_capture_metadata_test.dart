// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_classifier.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_metadata.dart';

ReticulumCaptureMetadata _sampleMetadata() {
  return ReticulumCaptureMetadata.fromClassification(
    classification: const ReticulumCaptureClassification(
      kind: ReticulumCaptureKind.realCandidate,
      recordCount: 5,
      firstSeenMs: 1000,
      lastSeenMs: 1004,
      distinctSources: [0x11, 0x22],
      containsHarnessMagic: false,
    ),
    createdAt: DateTime.utc(2026, 4, 25, 16, 0, 0),
    classifiedAt: DateTime.utc(2026, 4, 25, 16, 5, 0),
    source: ReticulumCaptureSource.shared,
    checksumSha256: 'abc123def456',
    region: 'ANZ',
    channelIndex: 1,
    notes: 'Field test capture',
  );
}

void main() {
  group('ReticulumCaptureMetadata — JSON round-trip', () {
    test('toJson then fromJson preserves all fields', () {
      final original = _sampleMetadata();
      final restored = ReticulumCaptureMetadata.fromJson(original.toJson());

      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.captureKind, original.captureKind);
      expect(restored.createdAtIso, original.createdAtIso);
      expect(restored.classifiedAtIso, original.classifiedAtIso);
      expect(restored.source, original.source);
      expect(restored.deviceModel, original.deviceModel);
      expect(restored.firmwareVersion, original.firmwareVersion);
      expect(restored.region, original.region);
      expect(restored.channelIndex, original.channelIndex);
      expect(restored.notes, original.notes);
      expect(restored.recordCount, original.recordCount);
      expect(restored.firstSeenMs, original.firstSeenMs);
      expect(restored.lastSeenMs, original.lastSeenMs);
      expect(restored.distinctSources, original.distinctSources);
      expect(restored.containsHarnessMagic, original.containsHarnessMagic);
      expect(restored.checksumSha256, original.checksumSha256);
    });

    test('toJsonString produces parseable JSON object', () {
      final original = _sampleMetadata();
      final asString = original.toJsonString();
      final decoded = json.decode(asString);
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['captureKind'], 'realCandidate');
      expect(decoded['source'], 'shared');
      expect(decoded['notes'], 'Field test capture');
    });

    test('fromJsonString rejects non-object root', () {
      expect(
        () => ReticulumCaptureMetadata.fromJsonString('[]'),
        throwsFormatException,
      );
    });

    test('fromJson handles missing fields with sensible defaults', () {
      final restored = ReticulumCaptureMetadata.fromJson(<String, dynamic>{
        'captureKind': 'harness',
      });
      expect(restored.captureKind, ReticulumCaptureKind.harness);
      expect(restored.source, ReticulumCaptureSource.local);
      expect(restored.notes, '');
      expect(restored.recordCount, 0);
      expect(restored.distinctSources, isEmpty);
      expect(restored.containsHarnessMagic, isFalse);
    });
  });

  group('ReticulumCaptureMetadata — payload-byte safety contract', () {
    test('toJson never carries a payload field, however named', () {
      final original = _sampleMetadata();
      final j = original.toJson();
      // The metadata model is the source of truth for what may be
      // serialized; this test fails if a future contributor adds a
      // payload-bearing field with any of these obvious names.
      const forbidden = [
        'payload',
        'payloads',
        'payloadBytes',
        'samples',
        'rawBytes',
        'bodies',
      ];
      for (final key in forbidden) {
        expect(
          j.containsKey(key),
          isFalse,
          reason: 'payload-bearing key "$key" must never appear in metadata',
        );
      }
    });

    test('toJsonString does not embed any base64 / hex blob field', () {
      final original = _sampleMetadata();
      final asString = original.toJsonString();
      // Crude but effective: a payload-bearing field would show up as
      // a long, contiguous run of base64/hex chars in the value
      // position. None of our fields do.
      expect(
        RegExp(r'"[a-zA-Z]+"\s*:\s*"[A-Za-z0-9+/=]{64,}"').hasMatch(asString),
        isFalse,
        reason: 'no field should serialize a 64+ char base64/hex blob',
      );
    });
  });

  group('ReticulumCaptureMetadata.copyWith', () {
    test('updates only the fields supplied', () {
      final original = _sampleMetadata();
      final updated = original.copyWith(notes: 'updated notes');
      expect(updated.notes, 'updated notes');
      // Everything else preserved.
      expect(updated.region, original.region);
      expect(updated.captureKind, original.captureKind);
      expect(updated.checksumSha256, original.checksumSha256);
    });

    test('explicit-null flags clear nullable fields', () {
      final original = _sampleMetadata();
      final updated = original.copyWith(
        regionExplicitNull: true,
        channelIndexExplicitNull: true,
      );
      expect(updated.region, isNull);
      expect(updated.channelIndex, isNull);
    });
  });
}
