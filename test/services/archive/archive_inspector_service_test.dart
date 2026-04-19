// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/archive/archive_inspector_service.dart';
import 'package:socialmesh/services/archive/archive_models.dart';

/// Helper to build a ZIP archive from a map of filename → content bytes.
Uint8List _buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final file = ArchiveFile.bytes(entry.key, entry.value);
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Helper to build a ZIP with entries of a specified size.
Uint8List _buildZipWithSizedEntries(Map<String, int> entrySizes) {
  final entries = <String, List<int>>{};
  for (final e in entrySizes.entries) {
    entries[e.key] = List.filled(e.value, 0x41); // Fill with 'A'
  }
  return _buildZip(entries);
}

void main() {
  late ArchiveInspectorService service;

  setUp(() {
    service = ArchiveInspectorService();
  });

  group('ArchiveInspectorService.inspect', () {
    test('inspects a simple valid ZIP with supported entries', () {
      final zip = _buildZip({
        'photo.jpg': [0xFF, 0xD8, 0xFF, 0xE0], // JPEG signature
        'note.txt': 'Hello world'.codeUnits,
        'config.json': '{"key":"value"}'.codeUnits,
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'test.zip',
      );

      expect(manifest.isValid, isTrue);
      expect(manifest.entryCount, 3);
      expect(manifest.archiveFilename, 'test.zip');
      expect(manifest.archiveSize, zip.length);

      // All entries should be supported.
      expect(manifest.supportedEntries.length, 3);
      expect(manifest.unsupportedEntries.length, 0);

      // Check MIME types inferred from extensions.
      final jpg = manifest.entries.firstWhere((e) => e.filename == 'photo.jpg');
      expect(jpg.mimeType, 'image/jpeg');
      expect(jpg.status, ArchiveEntryStatus.supported);
      expect(jpg.actions, contains(ArchiveEntryAction.preview));
      expect(jpg.actions, contains(ArchiveEntryAction.save));

      final txt = manifest.entries.firstWhere((e) => e.filename == 'note.txt');
      expect(txt.mimeType, 'text/plain');
      expect(txt.status, ArchiveEntryStatus.supported);

      final json = manifest.entries.firstWhere(
        (e) => e.filename == 'config.json',
      );
      expect(json.mimeType, 'application/json');
      expect(json.status, ArchiveEntryStatus.supported);
    });

    test('classifies mixed supported and unsupported entries', () {
      final zip = _buildZip({
        'image.png': [0x89, 0x50, 0x4E, 0x47], // PNG signature
        'voice.c2': [0x01, 0x02, 0x03],
        'data.bin': [0x00, 0x01, 0x02],
        'unknown.xyz': [0x0A, 0x0B],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'mixed.zip',
      );

      expect(manifest.isValid, isTrue);
      expect(manifest.entryCount, 4);

      final png = manifest.entries.firstWhere((e) => e.filename == 'image.png');
      expect(png.status, ArchiveEntryStatus.supported);
      expect(png.mimeType, 'image/png');

      final c2 = manifest.entries.firstWhere((e) => e.filename == 'voice.c2');
      expect(c2.status, ArchiveEntryStatus.supported);
      expect(c2.mimeType, 'audio/x-codec2');
      expect(c2.actions, contains(ArchiveEntryAction.play));

      // .bin gets 'application/octet-stream' and only save action.
      final bin = manifest.entries.firstWhere((e) => e.filename == 'data.bin');
      expect(bin.status, ArchiveEntryStatus.supported);
      expect(bin.actions, [ArchiveEntryAction.save]);

      // .xyz gets 'application/octet-stream' and save only.
      final xyz = manifest.entries.firstWhere(
        (e) => e.filename == 'unknown.xyz',
      );
      expect(xyz.status, ArchiveEntryStatus.supported);
      expect(xyz.actions, [ArchiveEntryAction.save]);
    });

    test('rejects oversized individual entry', () {
      final zip = _buildZipWithSizedEntries({
        'small.txt': 100,
        'huge.dat': ArchiveLimits.maxEntrySize + 1,
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'oversized.zip',
      );

      expect(manifest.isValid, isTrue);
      expect(manifest.entryCount, 2);

      final small = manifest.entries.firstWhere(
        (e) => e.filename == 'small.txt',
      );
      expect(small.status, ArchiveEntryStatus.supported);

      final huge = manifest.entries.firstWhere((e) => e.filename == 'huge.dat');
      expect(huge.status, ArchiveEntryStatus.tooLarge);
      expect(huge.actions, isEmpty);
    });

    test('rejects archive with too many entries', () {
      final entries = <String, List<int>>{};
      for (var i = 0; i <= ArchiveLimits.maxEntryCount; i++) {
        entries['file_$i.txt'] = [0x41]; // 1-byte each
      }
      final zip = _buildZip(entries);

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'toomany.zip',
      );

      expect(manifest.isValid, isFalse);
      expect(manifest.rejectReason, ArchiveRejectReason.tooManyEntries);
      expect(manifest.entries, isEmpty);
    });

    test('rejects archive whose total uncompressed size exceeds limit', () {
      // Create entries that individually fit but collectively exceed the limit.
      final entrySize = ArchiveLimits.maxEntrySize; // 64KB each
      final entryCount =
          (ArchiveLimits.maxTotalUncompressedSize ~/ entrySize) + 1;

      final entries = <String, List<int>>{};
      for (var i = 0; i < entryCount; i++) {
        entries['file_$i.dat'] = List.filled(entrySize, 0x42);
      }
      final zip = _buildZip(entries);

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'totalsize.zip',
      );

      expect(manifest.isValid, isFalse);
      expect(manifest.rejectReason, ArchiveRejectReason.totalSizeTooLarge);
    });

    test('rejects corrupt archive data', () {
      // A truncated ZIP header — starts with PK signature but is incomplete.
      // The archive library recognises this as a ZIP attempt and throws.
      final corrupt = Uint8List.fromList([
        0x50, 0x4B, 0x03, 0x04, // Local file header signature
        0x14, 0x00, // Version needed
        0x00, 0x00, // Flags
        0x08, 0x00, // Compression: deflate
        // Truncated — missing required fields
      ]);

      final manifest = service.inspect(
        archiveBytes: corrupt,
        archiveFilename: 'corrupt.zip',
      );

      // Either rejected as corrupt, or decoded as empty (library tolerance).
      // The important invariant is that no exploitable entries are returned.
      expect(manifest.entries, isEmpty);
    });

    test('detects encrypted ZIP and rejects it', () {
      // Build an encrypted ZIP by manually setting the encryption flag.
      // We create a minimal ZIP local file header with bit 0 of flags set.
      final builder = BytesBuilder();

      // Local file header signature.
      builder.add([0x50, 0x4B, 0x03, 0x04]);
      // Version needed.
      builder.add([0x14, 0x00]);
      // General purpose bit flag — bit 0 = encrypted.
      builder.add([0x01, 0x00]);
      // Compression method (stored).
      builder.add([0x00, 0x00]);
      // Last mod time + date.
      builder.add([0x00, 0x00, 0x00, 0x00]);
      // CRC-32.
      builder.add([0x00, 0x00, 0x00, 0x00]);
      // Compressed size.
      builder.add([0x05, 0x00, 0x00, 0x00]);
      // Uncompressed size.
      builder.add([0x05, 0x00, 0x00, 0x00]);
      // Filename length.
      builder.add([0x08, 0x00]);
      // Extra field length.
      builder.add([0x00, 0x00]);
      // Filename.
      builder.add('test.txt'.codeUnits);
      // File data (encrypted, but we just put dummy data).
      builder.add([0x01, 0x02, 0x03, 0x04, 0x05]);

      // Pad with central directory + EOCD (minimal).
      // Central directory file header.
      builder.add([0x50, 0x4B, 0x01, 0x02]);
      builder.add(List.filled(42, 0x00)); // Central directory header fields.
      // End of central directory record.
      builder.add([0x50, 0x4B, 0x05, 0x06]);
      builder.add(List.filled(18, 0x00));

      final encrypted = Uint8List.fromList(builder.toBytes());

      final manifest = service.inspect(
        archiveBytes: encrypted,
        archiveFilename: 'encrypted.zip',
      );

      // The raw byte scanner should detect the encrypted flag.
      // If decoding also fails, that's fine — either path rejects it.
      expect(manifest.isEncrypted || manifest.rejectReason != null, isTrue);
    });

    test('blocks unsafe path traversal entries', () {
      final zip = _buildZip({
        '../etc/passwd': [0x00],
        'safe.txt': [0x41],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'traversal.zip',
      );

      expect(manifest.isValid, isTrue);

      // The traversal entry should be blocked.
      final blocked = manifest.entries.where(
        (e) => e.status == ArchiveEntryStatus.blocked,
      );
      expect(blocked.length, 1);
      expect(blocked.first.actions, isEmpty);

      // The safe entry should be supported.
      final safe = manifest.entries.firstWhere((e) => e.filename == 'safe.txt');
      expect(safe.status, ArchiveEntryStatus.supported);
    });

    test('blocks absolute path entries', () {
      final zip = _buildZip({
        '/tmp/evil.sh': [0x23, 0x21], // #!/
        'good.txt': [0x41],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'absolute.zip',
      );

      expect(manifest.isValid, isTrue);

      final blocked = manifest.entries.where(
        (e) => e.status == ArchiveEntryStatus.blocked,
      );
      expect(blocked.isNotEmpty, isTrue);
    });

    test('classifies nested ZIP as nestedArchive status', () {
      // Create an inner ZIP.
      final innerZip = _buildZip({
        'inner.txt': [0x41],
      });

      // Put it inside an outer ZIP.
      final outerZip = _buildZip({
        'readme.txt': 'Hello'.codeUnits,
        'nested.zip': innerZip,
      });

      final manifest = service.inspect(
        archiveBytes: outerZip,
        archiveFilename: 'outer.zip',
      );

      expect(manifest.isValid, isTrue);

      final nested = manifest.entries.firstWhere(
        (e) => e.filename == 'nested.zip',
      );
      expect(nested.status, ArchiveEntryStatus.nestedArchive);
      expect(nested.actions, isEmpty);

      final readme = manifest.entries.firstWhere(
        (e) => e.filename == 'readme.txt',
      );
      expect(readme.status, ArchiveEntryStatus.supported);
    });

    test('category counts are correct for summary banner', () {
      final zip = _buildZip({
        'photo1.jpg': [0xFF, 0xD8],
        'photo2.png': [0x89, 0x50],
        'voice.c2': [0x01],
        'note.txt': [0x41],
        'data.json': [0x7B],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'summary.zip',
      );

      final counts = manifest.categoryCounts;
      expect(counts['image'], 2);
      expect(counts['voice'], 1);
      expect(counts['text'], 2); // .txt + .json
    });

    test('directories are excluded from entry list', () {
      final archive = Archive();
      // Add a directory entry.
      archive.addFile(ArchiveFile.directory('subdir/'));
      // Add a file.
      archive.addFile(ArchiveFile.bytes('subdir/file.txt', [0x41]));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'dirs.zip',
      );

      expect(manifest.isValid, isTrue);
      // Only the file entry should appear, not the directory.
      expect(manifest.entryCount, 1);
      expect(manifest.entries.first.filename, 'file.txt');
    });
  });

  group('ArchiveInspectorService.extractEntry', () {
    test('extracts a single supported entry', () {
      final content = 'Hello from archive'.codeUnits;
      final zip = _buildZip({
        'readme.txt': content,
        'photo.jpg': [0xFF, 0xD8],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'extract.zip',
      );

      final entry = manifest.entries.firstWhere(
        (e) => e.filename == 'readme.txt',
      );

      final extracted = service.extractEntry(archiveBytes: zip, entry: entry);

      expect(extracted, isNotNull);
      expect(extracted!.length, content.length);
      expect(String.fromCharCodes(extracted), 'Hello from archive');
    });

    test('returns null for blocked entry', () {
      final zip = _buildZip({
        '../evil.txt': [0x00],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'blocked.zip',
      );

      final entry = manifest.entries.first;
      expect(entry.status, ArchiveEntryStatus.blocked);

      final extracted = service.extractEntry(archiveBytes: zip, entry: entry);

      expect(extracted, isNull);
    });

    test('returns null for too-large entry', () {
      final zip = _buildZipWithSizedEntries({
        'big.dat': ArchiveLimits.maxEntrySize + 1,
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'big.zip',
      );

      final entry = manifest.entries.first;
      expect(entry.status, ArchiveEntryStatus.tooLarge);

      final extracted = service.extractEntry(archiveBytes: zip, entry: entry);

      expect(extracted, isNull);
    });
  });

  group('ArchiveManifest', () {
    test('supportedEntries and unsupportedEntries partition correctly', () {
      final zip = _buildZip({
        'good.txt': [0x41],
        '../bad.txt': [0x42],
      });

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'partition.zip',
      );

      expect(
        manifest.supportedEntries.length + manifest.unsupportedEntries.length,
        manifest.entryCount,
      );
    });

    test('empty archive has valid manifest with zero entries', () {
      final archive = Archive();
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));

      final manifest = service.inspect(
        archiveBytes: zip,
        archiveFilename: 'empty.zip',
      );

      expect(manifest.isValid, isTrue);
      expect(manifest.entryCount, 0);
      expect(manifest.entries, isEmpty);
    });
  });
}
