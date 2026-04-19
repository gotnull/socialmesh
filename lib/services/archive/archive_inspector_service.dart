// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/logging.dart';
import 'archive_models.dart';

/// Safety limits for archive inspection and extraction.
class ArchiveLimits {
  ArchiveLimits._();

  /// Maximum number of entries allowed in an archive.
  static const int maxEntryCount = 100;

  /// Maximum uncompressed size of a single entry (64 KB).
  static const int maxEntrySize = 65536;

  /// Maximum total uncompressed size across all entries (256 KB).
  static const int maxTotalUncompressedSize = 262144;

  /// Maximum filename length in bytes (UTF-8).
  static const int maxFilenameLength = 255;

  /// Archive extensions that are treated as nested archives.
  static const Set<String> nestedArchiveExtensions = {
    '.zip',
    '.tar',
    '.gz',
    '.bz2',
    '.xz',
    '.7z',
    '.rar',
  };
}

/// Inspects and extracts ZIP archives with security validation.
///
/// Responsibilities:
/// - Parse archive bytes and build an [ArchiveManifest]
/// - Classify each entry (supported, unsupported, blocked, too large)
/// - Extract individual entries on demand with path safety checks
///
/// This service is stateless and does not hold references to BuildContext
/// or WidgetRef.
class ArchiveInspectorService {
  /// Inspects the given [archiveBytes] and returns a manifest describing
  /// all entries, their types, safety status, and available actions.
  ///
  /// The archive is decoded in memory — no files are written to disk
  /// during inspection.
  ArchiveManifest inspect({
    required Uint8List archiveBytes,
    required String archiveFilename,
  }) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(archiveBytes);
    } catch (e) {
      AppLogging.fileTransfer(
        'ARCHIVE_INSPECT: Failed to decode $archiveFilename: $e',
      );
      return ArchiveManifest(
        archiveFilename: archiveFilename,
        archiveSize: archiveBytes.length,
        entries: const [],
        rejectReason: ArchiveRejectReason.corrupt,
      );
    }

    // Check for encrypted entries via raw ZIP local file header flags.
    // Bit 0 of the general purpose flag indicates encryption.
    if (_hasEncryptedEntries(archiveBytes)) {
      AppLogging.fileTransfer(
        'ARCHIVE_INSPECT: Encrypted archive rejected: $archiveFilename',
      );
      return ArchiveManifest(
        archiveFilename: archiveFilename,
        archiveSize: archiveBytes.length,
        entries: const [],
        isEncrypted: true,
        rejectReason: ArchiveRejectReason.encrypted,
      );
    }

    // Filter to files only (skip directories).
    final files = archive.files.where((f) => !f.isDirectory).toList();

    // Entry count limit.
    if (files.length > ArchiveLimits.maxEntryCount) {
      AppLogging.fileTransfer(
        'ARCHIVE_INSPECT: Too many entries (${files.length}) '
        'in $archiveFilename',
      );
      return ArchiveManifest(
        archiveFilename: archiveFilename,
        archiveSize: archiveBytes.length,
        entries: const [],
        rejectReason: ArchiveRejectReason.tooManyEntries,
      );
    }

    // Total uncompressed size limit.
    var totalUncompressed = 0;
    for (final file in files) {
      totalUncompressed += file.size;
    }
    if (totalUncompressed > ArchiveLimits.maxTotalUncompressedSize) {
      AppLogging.fileTransfer(
        'ARCHIVE_INSPECT: Total uncompressed size '
        '($totalUncompressed) exceeds limit in $archiveFilename',
      );
      return ArchiveManifest(
        archiveFilename: archiveFilename,
        archiveSize: archiveBytes.length,
        entries: const [],
        rejectReason: ArchiveRejectReason.totalSizeTooLarge,
      );
    }

    // Build entry descriptors.
    final entries = <ArchiveEntry>[];
    for (final file in files) {
      entries.add(_classifyEntry(file));
    }

    AppLogging.fileTransfer(
      'ARCHIVE_INSPECT: $archiveFilename — ${entries.length} entries, '
      '${entries.where((e) => e.status == ArchiveEntryStatus.supported).length} supported',
    );

    return ArchiveManifest(
      archiveFilename: archiveFilename,
      archiveSize: archiveBytes.length,
      entries: entries,
    );
  }

  /// Extracts the bytes of a single entry from [archiveBytes].
  ///
  /// Returns the entry's uncompressed content, or `null` if the entry
  /// cannot be found or is blocked/too large.
  Uint8List? extractEntry({
    required Uint8List archiveBytes,
    required ArchiveEntry entry,
  }) {
    if (entry.status == ArchiveEntryStatus.blocked ||
        entry.status == ArchiveEntryStatus.tooLarge) {
      return null;
    }

    try {
      final archive = ZipDecoder().decodeBytes(archiveBytes);
      for (final file in archive.files) {
        if (file.name == entry.originalPath && !file.isDirectory) {
          return Uint8List.fromList(file.content);
        }
      }
    } catch (e) {
      AppLogging.fileTransfer(
        'ARCHIVE_EXTRACT: Failed to extract ${entry.filename}: $e',
      );
    }
    return null;
  }

  /// Classifies a single archive file entry.
  ArchiveEntry _classifyEntry(ArchiveFile file) {
    final originalPath = file.name;
    final basename = p.basename(originalPath);
    final uncompressedSize = file.size;
    // The archive package does not expose compressed size on ArchiveFile;
    // use uncompressed size as display fallback.
    final compressedSize = uncompressedSize;

    // Security: check for unsafe paths.
    if (_isUnsafePath(originalPath)) {
      return ArchiveEntry(
        filename: basename,
        originalPath: originalPath,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        mimeType: _guessMimeType(basename),
        status: ArchiveEntryStatus.blocked,
        actions: const [],
      );
    }

    // Security: reject symlinks.
    if (file.isSymbolicLink) {
      return ArchiveEntry(
        filename: basename,
        originalPath: originalPath,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        mimeType: _guessMimeType(basename),
        status: ArchiveEntryStatus.blocked,
        actions: const [],
      );
    }

    // Filename length check.
    if (basename.length > ArchiveLimits.maxFilenameLength) {
      return ArchiveEntry(
        filename: basename.substring(0, ArchiveLimits.maxFilenameLength),
        originalPath: originalPath,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        mimeType: _guessMimeType(basename),
        status: ArchiveEntryStatus.blocked,
        actions: const [],
      );
    }

    // Per-entry size limit.
    if (uncompressedSize > ArchiveLimits.maxEntrySize) {
      return ArchiveEntry(
        filename: basename,
        originalPath: originalPath,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        mimeType: _guessMimeType(basename),
        status: ArchiveEntryStatus.tooLarge,
        actions: const [],
      );
    }

    // Nested archive detection.
    final ext = p.extension(basename).toLowerCase();
    if (ArchiveLimits.nestedArchiveExtensions.contains(ext)) {
      return ArchiveEntry(
        filename: basename,
        originalPath: originalPath,
        uncompressedSize: uncompressedSize,
        compressedSize: compressedSize,
        mimeType: _guessMimeType(basename),
        status: ArchiveEntryStatus.nestedArchive,
        actions: const [],
      );
    }

    // Classify by MIME type and determine actions.
    final mime = _guessMimeType(basename);
    final actions = _actionsForMime(mime, ext);
    final status = actions.isNotEmpty
        ? ArchiveEntryStatus.supported
        : ArchiveEntryStatus.unsupported;

    return ArchiveEntry(
      filename: basename,
      originalPath: originalPath,
      uncompressedSize: uncompressedSize,
      compressedSize: compressedSize,
      mimeType: mime,
      status: status,
      actions: actions,
    );
  }

  /// Returns `true` if the path contains traversal or absolute components.
  bool _isUnsafePath(String path) {
    // Absolute paths.
    if (path.startsWith('/') || path.startsWith('\\')) return true;
    if (path.length >= 2 && path[1] == ':') return true; // Windows drive

    // Path traversal.
    final normalised = p.normalize(path);
    if (normalised.startsWith('..') || normalised.contains('/../')) {
      return true;
    }

    // Split and check each component.
    final parts = path.split(RegExp(r'[/\\]'));
    for (final part in parts) {
      if (part == '..') return true;
    }

    return false;
  }

  /// Determines available actions based on MIME type.
  List<ArchiveEntryAction> _actionsForMime(String mime, String ext) {
    final actions = <ArchiveEntryAction>[];

    if (mime.startsWith('image/')) {
      actions.add(ArchiveEntryAction.preview);
      actions.add(ArchiveEntryAction.save);
    } else if (mime == 'audio/x-codec2' || ext == '.c2') {
      actions.add(ArchiveEntryAction.play);
      actions.add(ArchiveEntryAction.save);
    } else if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('gpx') ||
        mime.contains('kml') ||
        mime.contains('csv')) {
      actions.add(ArchiveEntryAction.preview);
      actions.add(ArchiveEntryAction.save);
    } else if (mime.startsWith('audio/')) {
      actions.add(ArchiveEntryAction.save);
    } else if (mime == 'application/pdf') {
      actions.add(ArchiveEntryAction.save);
    } else if (mime == 'application/octet-stream') {
      actions.add(ArchiveEntryAction.save);
    }

    return actions;
  }

  /// Infers MIME type from filename extension.
  ///
  /// Mirrors the classification logic in the file transfer provider.
  String _guessMimeType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.txt' => 'text/plain',
      '.json' => 'application/json',
      '.csv' => 'text/csv',
      '.gpx' => 'application/gpx+xml',
      '.kml' => 'application/vnd.google-earth.kml+xml',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      '.pdf' => 'application/pdf',
      '.zip' => 'application/zip',
      '.gz' => 'application/gzip',
      '.tar' => 'application/x-tar',
      '.c2' => 'audio/x-codec2',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.ogg' => 'audio/ogg',
      '.xml' => 'application/xml',
      _ => 'application/octet-stream',
    };
  }

  /// Detects encrypted entries by scanning ZIP local file headers.
  ///
  /// The general purpose bit flag (offset 6 in each local file header)
  /// has bit 0 set when the entry is encrypted. We scan up to 64
  /// local file headers since we cap entries at [ArchiveLimits.maxEntryCount].
  bool _hasEncryptedEntries(Uint8List data) {
    // ZIP local file header signature: PK\x03\x04
    const signature = [0x50, 0x4B, 0x03, 0x04];
    var offset = 0;
    var checked = 0;

    while (offset + 30 <= data.length &&
        checked < ArchiveLimits.maxEntryCount) {
      // Find next local file header.
      if (data[offset] != signature[0] ||
          data[offset + 1] != signature[1] ||
          data[offset + 2] != signature[2] ||
          data[offset + 3] != signature[3]) {
        offset++;
        continue;
      }

      // General purpose bit flag is at offset 6 from the header start.
      final flags = data[offset + 6] | (data[offset + 7] << 8);
      if (flags & 0x01 != 0) return true;

      // Skip past this entry: 30 + filename length + extra field length
      // + compressed size.
      final filenameLen = data[offset + 26] | (data[offset + 27] << 8);
      final extraLen = data[offset + 28] | (data[offset + 29] << 8);
      final compSize =
          data[offset + 18] |
          (data[offset + 19] << 8) |
          (data[offset + 20] << 16) |
          (data[offset + 21] << 24);
      offset += 30 + filenameLen + extraLen + compSize;
      checked++;
    }

    return false;
  }
}
