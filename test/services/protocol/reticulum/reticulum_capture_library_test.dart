// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_classifier.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_library.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_metadata.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_capture_writer.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';

const _shrnMagic = [0x53, 0x48, 0x52, 0x4E];

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

Uint8List _harnessPayload() =>
    Uint8List.fromList([..._shrnMagic, ...List.filled(16, 0xAA)]);

Uint8List _opaquePayload() =>
    Uint8List.fromList(List.generate(20, (i) => i & 0xFF));

Future<File> _writeCaptureFile(
  Directory dir,
  String name,
  List<ReticulumFragmentEvent> events,
) async {
  final file = File('${dir.path}/$name');
  final builder = BytesBuilder()..add(ReticulumCaptureWriter.magicHeader());
  for (final e in events) {
    builder.add(ReticulumCaptureWriter.encodeRecord(e));
  }
  await file.writeAsBytes(builder.toBytes(), flush: true);
  return file;
}

void main() {
  late Directory tempDir;
  late ReticulumCaptureLibrary library;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rns_library_test_');
    library = ReticulumCaptureLibrary(captureRootOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('list + auto-classify on missing sidecar', () {
    test('classifies a freshly captured harness file', () async {
      await _writeCaptureFile(tempDir, 'harness.bin', [
        _event(fromNode: 0xAA, seq: 0, payload: _harnessPayload()),
        _event(fromNode: 0xAA, seq: 1, payload: _harnessPayload()),
      ]);
      final list = await library.list();
      expect(list, hasLength(1));
      final entry = list.single;
      expect(entry.metadata.captureKind, ReticulumCaptureKind.harness);
      expect(entry.metadata.recordCount, 2);
      expect(entry.metadata.containsHarnessMagic, isTrue);
      expect(entry.metadata.source, ReticulumCaptureSource.local);
      expect(entry.metadata.checksumSha256.length, 64);
    });

    test('classifies a real-candidate file with non-SHRN payloads', () async {
      await _writeCaptureFile(tempDir, 'real.bin', [
        _event(fromNode: 0x11, seq: 0, payload: _opaquePayload()),
        _event(fromNode: 0x22, seq: 1, payload: _opaquePayload()),
      ]);
      final list = await library.list();
      expect(
        list.single.metadata.captureKind,
        ReticulumCaptureKind.realCandidate,
      );
      expect(list.single.metadata.containsHarnessMagic, isFalse);
    });

    test(
      'imported subdirectory is included with shared source label',
      () async {
        final imported = Directory('${tempDir.path}/imported');
        await imported.create();
        await _writeCaptureFile(imported, 'incoming.bin', [
          _event(fromNode: 0x55, seq: 0, payload: _opaquePayload()),
        ]);
        final list = await library.list();
        expect(list, hasLength(1));
        expect(list.single.metadata.source, ReticulumCaptureSource.shared);
      },
    );

    test(
      'writes a sidecar on first sight that is reused on second list',
      () async {
        final capture = await _writeCaptureFile(tempDir, 'persist.bin', [
          _event(fromNode: 0x01, seq: 0, payload: _harnessPayload()),
        ]);
        // First list — sidecar gets created.
        await library.list();
        final sidecar = ReticulumCaptureLibrary.sidecarFor(capture);
        expect(await sidecar.exists(), isTrue);
        final fileBefore = await sidecar.readAsString();
        // Touch the sidecar's classifiedAt to confirm second list does
        // not rewrite it. (We do this by re-listing and reading again.)
        await library.list();
        final fileAfter = await sidecar.readAsString();
        expect(fileAfter, fileBefore);
      },
    );

    test('list is sorted newest-first by firstSeenMs', () async {
      await _writeCaptureFile(tempDir, 'older.bin', [
        ReticulumFragmentEvent(
          timestampMs: 1_000_000_000_000,
          fromNode: 1,
          toNode: 1,
          packetId: 1,
          channel: 0,
          rssi: null,
          snr: null,
          payload: _opaquePayload(),
        ),
      ]);
      await _writeCaptureFile(tempDir, 'newer.bin', [
        ReticulumFragmentEvent(
          timestampMs: 2_000_000_000_000,
          fromNode: 1,
          toNode: 1,
          packetId: 2,
          channel: 0,
          rssi: null,
          snr: null,
          payload: _opaquePayload(),
        ),
      ]);
      final list = await library.list();
      expect(list, hasLength(2));
      expect(list[0].filename, 'newer.bin');
      expect(list[1].filename, 'older.bin');
    });
  });

  group('importFromFile — happy path + duplicate dedupe', () {
    late Directory sourceDir;

    setUp(() async {
      sourceDir = await Directory.systemTemp.createTemp(
        'rns_library_test_src_',
      );
    });

    tearDown(() async {
      if (await sourceDir.exists()) await sourceDir.delete(recursive: true);
    });

    test('importing a real-candidate copies it into imported/', () async {
      final source = await _writeCaptureFile(sourceDir, 'incoming.bin', [
        _event(fromNode: 0x77, seq: 0, payload: _opaquePayload()),
      ]);
      final result = await library.importFromFile(source);
      expect(result, isA<ReticulumCaptureImportSuccess>());
      final entry = (result as ReticulumCaptureImportSuccess).entry;
      expect(entry.metadata.captureKind, ReticulumCaptureKind.realCandidate);
      expect(entry.file.path, contains('imported'));
      expect(await entry.file.exists(), isTrue);
    });

    test('importing the same bytes twice is rejected as duplicate', () async {
      final source = await _writeCaptureFile(sourceDir, 'twice.bin', [
        _event(fromNode: 0x77, seq: 0, payload: _opaquePayload()),
      ]);
      final first = await library.importFromFile(source);
      expect(first, isA<ReticulumCaptureImportSuccess>());
      final firstChecksum = (first as ReticulumCaptureImportSuccess)
          .entry
          .metadata
          .checksumSha256;

      final second = await library.importFromFile(source);
      expect(second, isA<ReticulumCaptureImportDuplicate>());
      expect(
        (second as ReticulumCaptureImportDuplicate)
            .existing
            .metadata
            .checksumSha256,
        firstChecksum,
      );
    });

    test('importing a non-SMRC file is rejected as invalidMagic', () async {
      final junk = File('${sourceDir.path}/junk.bin');
      await junk.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      final result = await library.importFromFile(junk);
      expect(result, isA<ReticulumCaptureImportRejected>());
      expect(
        (result as ReticulumCaptureImportRejected).reason,
        ReticulumCaptureImportRejectionReason.invalidMagic,
      );
    });

    test(
      'importing a wrong-version file is rejected as unsupportedVersion',
      () async {
        final wrong = File('${sourceDir.path}/wrongver.bin');
        await wrong.writeAsBytes(
          Uint8List.fromList([
            ...ReticulumCaptureWriter.magicAscii.codeUnits,
            0x99,
          ]),
        );
        final result = await library.importFromFile(wrong);
        expect(
          (result as ReticulumCaptureImportRejected).reason,
          ReticulumCaptureImportRejectionReason.unsupportedVersion,
        );
      },
    );

    test(
      'imported file uniquifies destination on filename collision',
      () async {
        // Two distinct source dirs hold files with the same basename
        // but different bytes — checksums differ so neither is a
        // duplicate of the other. Both must land in imported/ at
        // distinct paths.
        final dirA = await Directory.systemTemp.createTemp(
          'rns_lib_collide_a_',
        );
        final dirB = await Directory.systemTemp.createTemp(
          'rns_lib_collide_b_',
        );
        addTearDown(() async => dirA.delete(recursive: true));
        addTearDown(() async => dirB.delete(recursive: true));

        final a = await _writeCaptureFile(dirA, 'collide.bin', [
          _event(fromNode: 0x10, seq: 0, payload: _opaquePayload()),
        ]);
        final b = await _writeCaptureFile(dirB, 'collide.bin', [
          _event(fromNode: 0x20, seq: 0, payload: _opaquePayload()),
        ]);
        final r1 = await library.importFromFile(a);
        final r2 = await library.importFromFile(b);
        expect(r1, isA<ReticulumCaptureImportSuccess>());
        expect(r2, isA<ReticulumCaptureImportSuccess>());
        final p1 = (r1 as ReticulumCaptureImportSuccess).entry.file.path;
        final p2 = (r2 as ReticulumCaptureImportSuccess).entry.file.path;
        expect(p1, isNot(equals(p2)));
        expect(p1, contains('imported'));
        expect(p2, contains('imported'));
      },
    );
  });

  group('updateProvenance', () {
    test('updates editable fields without changing derived ones', () async {
      await _writeCaptureFile(tempDir, 'prov.bin', [
        _event(fromNode: 0x01, seq: 0, payload: _opaquePayload()),
      ]);
      final entry = (await library.list()).single;
      final updated = await library.updateProvenance(
        entry,
        notes: 'home test',
        region: 'ANZ',
        channelIndex: 1,
        deviceModel: 'Heltec V3',
      );
      expect(updated.metadata.notes, 'home test');
      expect(updated.metadata.region, 'ANZ');
      expect(updated.metadata.channelIndex, 1);
      expect(updated.metadata.deviceModel, 'Heltec V3');
      // Derived fields preserved.
      expect(updated.metadata.recordCount, entry.metadata.recordCount);
      expect(updated.metadata.checksumSha256, entry.metadata.checksumSha256);
      expect(updated.metadata.captureKind, entry.metadata.captureKind);
    });

    test('explicit-null clears a nullable field on disk', () async {
      await _writeCaptureFile(tempDir, 'clear.bin', [
        _event(fromNode: 0x01, seq: 0, payload: _opaquePayload()),
      ]);
      var entry = (await library.list()).single;
      entry = await library.updateProvenance(entry, region: 'ANZ');
      expect(entry.metadata.region, 'ANZ');
      entry = await library.updateProvenance(entry, regionExplicitNull: true);
      expect(entry.metadata.region, isNull);
      // And the on-disk sidecar reflects null after re-listing.
      final reloaded = (await library.list()).single;
      expect(reloaded.metadata.region, isNull);
    });
  });

  group('delete', () {
    test('removes both capture and sidecar', () async {
      final capture = await _writeCaptureFile(tempDir, 'gone.bin', [
        _event(fromNode: 0x01, seq: 0, payload: _opaquePayload()),
      ]);
      final entry = (await library.list()).single;
      final sidecar = ReticulumCaptureLibrary.sidecarFor(capture);
      expect(await sidecar.exists(), isTrue);

      await library.delete(entry);

      expect(await capture.exists(), isFalse);
      expect(await sidecar.exists(), isFalse);
    });

    test('is a no-op when the file does not exist', () async {
      // Build an entry pointing at a path we never created.
      final fake = File('${tempDir.path}/never-existed.bin');
      final entry = ReticulumCaptureEntry(
        file: fake,
        metadata: ReticulumCaptureMetadata.fromClassification(
          classification: const ReticulumCaptureClassification(
            kind: ReticulumCaptureKind.invalid,
            recordCount: 0,
            firstSeenMs: null,
            lastSeenMs: null,
            distinctSources: [],
            containsHarnessMagic: false,
          ),
          createdAt: DateTime.utc(2026, 1, 1),
          classifiedAt: DateTime.utc(2026, 1, 1),
          source: ReticulumCaptureSource.manual,
          checksumSha256: 'x',
        ),
      );
      // Should not throw.
      await library.delete(entry);
    });
  });

  group('payload-byte safety', () {
    test('sidecar JSON contains no payload bytes from the capture', () async {
      // Embed a deliberately recognizable payload pattern; if any of it
      // appears in the sidecar JSON, this test will fail.
      final secret = Uint8List.fromList([
        0xCA,
        0xFE,
        0xBA,
        0xBE,
        0xDE,
        0xAD,
        0xBE,
        0xEF,
        0x12,
        0x34,
        0x56,
        0x78,
      ]);
      final capture = await _writeCaptureFile(tempDir, 'secret.bin', [
        _event(fromNode: 0x01, seq: 0, payload: secret),
      ]);
      await library.list();

      final sidecar = ReticulumCaptureLibrary.sidecarFor(capture);
      final body = await sidecar.readAsString();
      // Hex-encode the payload and check no contiguous run of those
      // bytes appears in the JSON.
      const hexChars = '0123456789abcdef';
      final hex = StringBuffer();
      for (final b in secret) {
        hex.write(hexChars[(b >> 4) & 0xF]);
        hex.write(hexChars[b & 0xF]);
      }
      expect(
        body.toLowerCase().contains(hex.toString()),
        isFalse,
        reason: 'sidecar JSON must not embed payload bytes',
      );
    });
  });
}
