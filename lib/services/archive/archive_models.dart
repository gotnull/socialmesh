// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

/// Status classification for an individual archive entry.
enum ArchiveEntryStatus {
  /// Entry can be previewed/played/imported/saved.
  supported,

  /// Entry type is not handled by the app.
  unsupported,

  /// Uncompressed entry exceeds the per-entry size limit.
  tooLarge,

  /// Entry path is unsafe (traversal, absolute, symlink).
  blocked,

  /// Entry is a nested archive (not extracted in v1).
  nestedArchive,
}

/// Supported action types for archive entries.
enum ArchiveEntryAction {
  /// Preview image content.
  preview,

  /// Play audio content.
  play,

  /// Save entry to device storage.
  save,
}

/// Describes a single entry inside an inspected archive.
class ArchiveEntry {
  /// Sanitised filename (basename only, no path components).
  final String filename;

  /// Original path as stored in the archive (for display only).
  final String originalPath;

  /// Uncompressed size in bytes.
  final int uncompressedSize;

  /// Compressed size in bytes (as stored in the archive).
  final int compressedSize;

  /// MIME type inferred from filename extension.
  final String mimeType;

  /// Safety/support classification.
  final ArchiveEntryStatus status;

  /// Available actions for this entry (empty if unsupported/blocked).
  final List<ArchiveEntryAction> actions;

  /// Extracted bytes (populated only after explicit extraction).
  final Uint8List? extractedBytes;

  const ArchiveEntry({
    required this.filename,
    required this.originalPath,
    required this.uncompressedSize,
    required this.compressedSize,
    required this.mimeType,
    required this.status,
    required this.actions,
    this.extractedBytes,
  });

  ArchiveEntry copyWith({Uint8List? extractedBytes}) {
    return ArchiveEntry(
      filename: filename,
      originalPath: originalPath,
      uncompressedSize: uncompressedSize,
      compressedSize: compressedSize,
      mimeType: mimeType,
      status: status,
      actions: actions,
      extractedBytes: extractedBytes ?? this.extractedBytes,
    );
  }
}

/// Result of inspecting a ZIP archive.
class ArchiveManifest {
  /// Archive filename.
  final String archiveFilename;

  /// Total archive size in bytes (compressed).
  final int archiveSize;

  /// All entries discovered in the archive.
  final List<ArchiveEntry> entries;

  /// Whether the archive is encrypted/password-protected (rejected in v1).
  final bool isEncrypted;

  /// Human-readable rejection reason if the archive cannot be inspected.
  final ArchiveRejectReason? rejectReason;

  const ArchiveManifest({
    required this.archiveFilename,
    required this.archiveSize,
    required this.entries,
    this.isEncrypted = false,
    this.rejectReason,
  });

  /// Whether inspection succeeded and entries are available.
  bool get isValid => rejectReason == null && !isEncrypted;

  /// Total number of entries.
  int get entryCount => entries.length;

  /// Entries that can be acted upon.
  List<ArchiveEntry> get supportedEntries =>
      entries.where((e) => e.status == ArchiveEntryStatus.supported).toList();

  /// Entries that are blocked or unsupported.
  List<ArchiveEntry> get unsupportedEntries => entries
      .where(
        (e) =>
            e.status == ArchiveEntryStatus.unsupported ||
            e.status == ArchiveEntryStatus.blocked ||
            e.status == ArchiveEntryStatus.tooLarge ||
            e.status == ArchiveEntryStatus.nestedArchive,
      )
      .toList();

  /// Count of entries by status for the summary banner.
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final entry in entries) {
      final category = _categoryForMime(entry.mimeType, entry.status);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  static String _categoryForMime(String mime, ArchiveEntryStatus status) {
    if (status != ArchiveEntryStatus.supported) return 'unsupported';
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/') || mime == 'audio/x-codec2') return 'voice';
    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('gpx') ||
        mime.contains('kml') ||
        mime.contains('csv')) {
      return 'text';
    }
    return 'other';
  }
}

/// Reasons an archive may be rejected during inspection.
enum ArchiveRejectReason {
  /// Archive is encrypted or password-protected.
  encrypted,

  /// Archive data is corrupt or unreadable.
  corrupt,

  /// Total entry count exceeds the safety limit.
  tooManyEntries,

  /// Total uncompressed size exceeds the safety limit.
  totalSizeTooLarge,
}
