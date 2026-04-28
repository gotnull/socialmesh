// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_classifier.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_writer.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';

const _shrnMagic = [0x53, 0x48, 0x52, 0x4E];
const _classifier = ReticulumCaptureClassifier();

Uint8List _smrcBytesFor(List<ReticulumFragmentEvent> events) {
  final builder = BytesBuilder()..add(ReticulumCaptureWriter.magicHeader());
  for (final e in events) {
    builder.add(ReticulumCaptureWriter.encodeRecord(e));
  }
  return builder.toBytes();
}

ReticulumFragmentEvent _event({
  required int fromNode,
  required int seq,
  required Uint8List payload,
}) {
  return ReticulumFragmentEvent(
    timestampMs: 1_000_000_000_000 + seq,
    fromNode: fromNode,
    toNode: 0xFFFFFFFF,
    packetId: 1000 + seq,
    channel: 1,
    rssi: -80,
    snr: 4.0,
    payload: payload,
  );
}

Uint8List _harnessPayload({int suffixLen = 28}) {
  return Uint8List.fromList([..._shrnMagic, ...List.filled(suffixLen, 0xAA)]);
}

Uint8List _opaquePayload({int len = 32}) {
  return Uint8List.fromList(List.generate(len, (i) => i & 0xFF));
}

void main() {
  group('classifyBytes — file-magic guards', () {
    test('rejects file that is not SMRC at all → invalid', () {
      final result = _classifier.classifyBytes(
        Uint8List.fromList('NOTAREAL'.codeUnits),
      );
      expect(result.kind, ReticulumCaptureKind.invalid);
      expect(result.recordCount, 0);
      expect(result.distinctSources, isEmpty);
    });

    test('rejects file with SMRC magic but unsupported version', () {
      final wrong = Uint8List.fromList([
        ...ReticulumCaptureWriter.magicAscii.codeUnits,
        0x99,
      ]);
      final result = _classifier.classifyBytes(wrong);
      expect(result.kind, ReticulumCaptureKind.unsupportedVersion);
    });

    test('rejects file too short to even hold magic', () {
      expect(
        _classifier.classifyBytes(Uint8List.fromList([0x01, 0x02])).kind,
        ReticulumCaptureKind.invalid,
      );
    });
  });

  group('classifyBytes — payload kind detection', () {
    test('all-SHRN payloads → harness', () {
      final bytes = _smrcBytesFor([
        _event(fromNode: 0xAABB, seq: 0, payload: _harnessPayload()),
        _event(fromNode: 0xAABB, seq: 1, payload: _harnessPayload()),
        _event(fromNode: 0xCCDD, seq: 2, payload: _harnessPayload()),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.kind, ReticulumCaptureKind.harness);
      expect(result.recordCount, 3);
      expect(result.containsHarnessMagic, isTrue);
      expect(result.distinctSources, [0xAABB, 0xCCDD]);
    });

    test('any non-SHRN payload → realCandidate', () {
      final bytes = _smrcBytesFor([
        _event(fromNode: 0x01, seq: 0, payload: _harnessPayload()),
        _event(fromNode: 0x02, seq: 1, payload: _opaquePayload()),
        _event(fromNode: 0x03, seq: 2, payload: _harnessPayload()),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.kind, ReticulumCaptureKind.realCandidate);
      // Mixed file still flags that it contained harness records — useful
      // for excluding those specific records during Phase 2 derivation.
      expect(result.containsHarnessMagic, isTrue);
      expect(result.recordCount, 3);
      expect(result.distinctSources, [1, 2, 3]);
    });

    test('all opaque payloads → realCandidate, no harness magic', () {
      final bytes = _smrcBytesFor([
        _event(fromNode: 0x10, seq: 0, payload: _opaquePayload()),
        _event(fromNode: 0x20, seq: 1, payload: _opaquePayload()),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.kind, ReticulumCaptureKind.realCandidate);
      expect(result.containsHarnessMagic, isFalse);
    });

    test('SMRC magic but zero records → invalid', () {
      // Magic only, no record bytes at all.
      final bytes = ReticulumCaptureWriter.magicHeader();
      final result = _classifier.classifyBytes(bytes);
      expect(result.kind, ReticulumCaptureKind.invalid);
    });

    test('payload shorter than 4 bytes never counts as SHRN', () {
      final bytes = _smrcBytesFor([
        _event(
          fromNode: 0x01,
          seq: 0,
          payload: Uint8List.fromList([0x53, 0x48]),
        ),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.kind, ReticulumCaptureKind.realCandidate);
      expect(result.containsHarnessMagic, isFalse);
    });
  });

  group('classifyBytes — first/last seen + distinct sources', () {
    test('firstSeenMs/lastSeenMs reflect record extremes', () {
      final bytes = _smrcBytesFor([
        ReticulumFragmentEvent(
          timestampMs: 100,
          fromNode: 1,
          toNode: 1,
          packetId: 1,
          channel: 0,
          rssi: null,
          snr: null,
          payload: _opaquePayload(len: 8),
        ),
        ReticulumFragmentEvent(
          timestampMs: 50,
          fromNode: 1,
          toNode: 1,
          packetId: 2,
          channel: 0,
          rssi: null,
          snr: null,
          payload: _opaquePayload(len: 8),
        ),
        ReticulumFragmentEvent(
          timestampMs: 200,
          fromNode: 1,
          toNode: 1,
          packetId: 3,
          channel: 0,
          rssi: null,
          snr: null,
          payload: _opaquePayload(len: 8),
        ),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.firstSeenMs, 50);
      expect(result.lastSeenMs, 200);
    });

    test('distinctSources is sorted ascending and deduped', () {
      final bytes = _smrcBytesFor([
        _event(fromNode: 0x33, seq: 0, payload: _opaquePayload()),
        _event(fromNode: 0x11, seq: 1, payload: _opaquePayload()),
        _event(fromNode: 0x22, seq: 2, payload: _opaquePayload()),
        _event(fromNode: 0x11, seq: 3, payload: _opaquePayload()),
      ]);
      final result = _classifier.classifyBytes(bytes);
      expect(result.distinctSources, [0x11, 0x22, 0x33]);
    });
  });
}
