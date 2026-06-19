// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'reticulum_capture_classifier.dart';
import 'reticulum_capture_metadata.dart';
import 'reticulum_capture_writer.dart';
import 'reticulum_safe_log.dart';

/// Combined capture file + sidecar metadata pair, sorted by recency.
class ReticulumCaptureEntry {
  const ReticulumCaptureEntry({required this.file, required this.metadata});

  final File file;
  final ReticulumCaptureMetadata metadata;

  String get filename {
    final segs = file.path.split(Platform.pathSeparator);
    return segs.isEmpty ? file.path : segs.last;
  }

  /// First 12 hex chars of the SHA-256 checksum, useful for compact
  /// display in lists.
  String get checksumShortPrefix {
    final c = metadata.checksumSha256;
    return c.length >= 12 ? c.substring(0, 12) : c;
  }
}

/// Result of importing a capture file from the share sheet / file
/// picker. Either a fresh entry (and the kind), or a rejection.
sealed class ReticulumCaptureImportResult {
  const ReticulumCaptureImportResult();
}

class ReticulumCaptureImportSuccess extends ReticulumCaptureImportResult {
  const ReticulumCaptureImportSuccess(this.entry);
  final ReticulumCaptureEntry entry;
}

class ReticulumCaptureImportDuplicate extends ReticulumCaptureImportResult {
  const ReticulumCaptureImportDuplicate(this.existing);
  final ReticulumCaptureEntry existing;
}

class ReticulumCaptureImportRejected extends ReticulumCaptureImportResult {
  const ReticulumCaptureImportRejected(this.reason);

  /// Machine-friendly reason key (UI maps these to localized strings).
  final ReticulumCaptureImportRejectionReason reason;
}

enum ReticulumCaptureImportRejectionReason {
  invalidMagic,
  unsupportedVersion,
  ioError,
}

/// Library service over the on-disk capture directory.
///
/// Owns three responsibilities:
///   * walking `reticulum_captures/` and `reticulum_captures/imported/`
///   * classifying captures that lack a sidecar and persisting one
///   * dedupe-by-checksum during imports
class ReticulumCaptureLibrary {
  ReticulumCaptureLibrary({
    this._captureRootOverride,
    ReticulumCaptureClassifier? classifier,
    DateTime Function()? clock,
  }) : _classifier = classifier ?? const ReticulumCaptureClassifier(),
       _clock = clock ?? DateTime.now;

  final Directory? _captureRootOverride;
  final ReticulumCaptureClassifier _classifier;
  final DateTime Function() _clock;

  static const String importedSubdir = 'imported';

  Future<Directory> _captureRoot() async {
    if (_captureRootOverride != null) return _captureRootOverride;
    final docs = await getApplicationDocumentsDirectory();
    return Directory(
      '${docs.path}/${ReticulumCaptureWriter.captureFolderName}',
    );
  }

  Future<Directory> _importedDir() async {
    final root = await _captureRoot();
    return Directory('${root.path}/$importedSubdir');
  }

  /// List every capture file under the root + imported subdirectory,
  /// sorted by `firstSeenMs` descending (newest first). Captures
  /// without a sidecar are classified and one is written on-the-fly.
  Future<List<ReticulumCaptureEntry>> list() async {
    final entries = <ReticulumCaptureEntry>[];
    final root = await _captureRoot();
    if (await root.exists()) {
      await _collectFromDir(root, entries, recurse: true);
    }
    // Sort newest first; missing timestamps go last.
    entries.sort((a, b) {
      final at = a.metadata.firstSeenMs ?? -1;
      final bt = b.metadata.firstSeenMs ?? -1;
      return bt.compareTo(at);
    });
    return entries;
  }

  Future<void> _collectFromDir(
    Directory dir,
    List<ReticulumCaptureEntry> out, {
    required bool recurse,
  }) async {
    await for (final ent in dir.list(followLinks: false)) {
      if (ent is File && ent.path.endsWith('.bin')) {
        final entry = await _loadOrClassify(ent);
        if (entry != null) out.add(entry);
      } else if (ent is Directory && recurse) {
        await _collectFromDir(ent, out, recurse: false);
      }
    }
  }

  Future<ReticulumCaptureEntry?> _loadOrClassify(File capture) async {
    final sidecar = sidecarFor(capture);
    if (await sidecar.exists()) {
      try {
        final metadata = ReticulumCaptureMetadata.fromJsonString(
          await sidecar.readAsString(),
        );
        return ReticulumCaptureEntry(file: capture, metadata: metadata);
      } catch (e) {
        ReticulumSafeLog.event('library_sidecar_decode_error error=$e');
      }
    }
    // No sidecar — classify and persist one.
    final classification = await _classifier.classify(capture);
    final checksum = await _computeChecksum(capture);
    final stat = await capture.stat();
    final metadata = ReticulumCaptureMetadata.fromClassification(
      classification: classification,
      createdAt: stat.modified,
      classifiedAt: _clock(),
      source: _inferSource(capture),
      checksumSha256: checksum,
    );
    try {
      await sidecar.writeAsString(metadata.toJsonString());
    } catch (e) {
      ReticulumSafeLog.event('library_sidecar_write_error error=$e');
    }
    return ReticulumCaptureEntry(file: capture, metadata: metadata);
  }

  /// Look up a capture by SHA-256 checksum. Returns null if none.
  Future<ReticulumCaptureEntry?> findByChecksum(String checksum) async {
    final all = await list();
    for (final e in all) {
      if (e.metadata.checksumSha256 == checksum) return e;
    }
    return null;
  }

  /// Import an external capture file into the library.
  ///
  /// Behavior:
  ///   * Reads [sourceFile] bytes once.
  ///   * Computes SHA-256 — rejects as duplicate if already present.
  ///   * Validates SMRC magic + version via the classifier — rejects
  ///     as invalid / unsupported on failure.
  ///   * Copies bytes into `reticulum_captures/imported/<filename>`,
  ///     uniquifying with a numeric suffix on collision.
  ///   * Writes a sidecar with the supplied [source].
  Future<ReticulumCaptureImportResult> importFromFile(
    File sourceFile, {
    ReticulumCaptureSource source = ReticulumCaptureSource.shared,
    String? notesOverride,
  }) async {
    try {
      if (!await sourceFile.exists()) {
        return const ReticulumCaptureImportRejected(
          ReticulumCaptureImportRejectionReason.ioError,
        );
      }
      final bytes = await sourceFile.readAsBytes();
      final classification = _classifier.classifyBytes(bytes);
      switch (classification.kind) {
        case ReticulumCaptureKind.invalid:
          return const ReticulumCaptureImportRejected(
            ReticulumCaptureImportRejectionReason.invalidMagic,
          );
        case ReticulumCaptureKind.unsupportedVersion:
          return const ReticulumCaptureImportRejected(
            ReticulumCaptureImportRejectionReason.unsupportedVersion,
          );
        case ReticulumCaptureKind.harness:
        case ReticulumCaptureKind.realCandidate:
          break;
      }
      final checksum = sha256.convert(bytes).toString();
      final existing = await findByChecksum(checksum);
      if (existing != null) {
        return ReticulumCaptureImportDuplicate(existing);
      }
      final importedDir = await _importedDir();
      if (!await importedDir.exists()) {
        await importedDir.create(recursive: true);
      }
      final basename = _basename(sourceFile);
      final dest = await _uniquifyDestination(importedDir, basename);
      await dest.writeAsBytes(bytes, flush: true);

      final metadata = ReticulumCaptureMetadata.fromClassification(
        classification: classification,
        createdAt: (await sourceFile.stat()).modified,
        classifiedAt: _clock(),
        source: source,
        checksumSha256: checksum,
        notes: notesOverride ?? '',
      );
      await sidecarFor(dest).writeAsString(metadata.toJsonString());

      ReticulumSafeLog.event(
        'library_import_ok kind=${classification.kind.name} '
        'records=${classification.recordCount} '
        'checksum=${_short(checksum)}',
      );
      return ReticulumCaptureImportSuccess(
        ReticulumCaptureEntry(file: dest, metadata: metadata),
      );
    } catch (e) {
      ReticulumSafeLog.event('library_import_error error=$e');
      return const ReticulumCaptureImportRejected(
        ReticulumCaptureImportRejectionReason.ioError,
      );
    }
  }

  /// Persist updated provenance fields. Caller may not change derived
  /// fields (kind, recordCount, etc.) — those come from the SMRC
  /// header and are tied to the bytes on disk.
  Future<ReticulumCaptureEntry> updateProvenance(
    ReticulumCaptureEntry entry, {
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
  }) async {
    final updated = entry.metadata.copyWith(
      source: source,
      deviceModel: deviceModel,
      deviceModelExplicitNull: deviceModelExplicitNull,
      firmwareVersion: firmwareVersion,
      firmwareVersionExplicitNull: firmwareVersionExplicitNull,
      region: region,
      regionExplicitNull: regionExplicitNull,
      channelIndex: channelIndex,
      channelIndexExplicitNull: channelIndexExplicitNull,
      notes: notes,
    );
    await sidecarFor(entry.file).writeAsString(updated.toJsonString());
    return ReticulumCaptureEntry(file: entry.file, metadata: updated);
  }

  /// Delete capture + sidecar together. Best-effort; missing sidecars
  /// are silently ignored.
  Future<void> delete(ReticulumCaptureEntry entry) async {
    try {
      if (await entry.file.exists()) {
        await entry.file.delete();
      }
    } catch (e) {
      ReticulumSafeLog.event('library_delete_capture_error error=$e');
    }
    try {
      final sidecar = sidecarFor(entry.file);
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    } catch (e) {
      ReticulumSafeLog.event('library_delete_sidecar_error error=$e');
    }
    ReticulumSafeLog.event(
      'library_delete_ok checksum=${_short(entry.metadata.checksumSha256)}',
    );
  }

  /// Sidecar path for a given capture file. Pure path arithmetic.
  static File sidecarFor(File capture) {
    return File('${capture.path}${ReticulumCaptureMetadata.fileSuffix}');
  }

  static Future<String> _computeChecksum(File file) async {
    // Stream the file through SHA-256 so we don't load >8 MB into
    // memory just to checksum it.
    final digestSink = AccumulatorSink<Digest>();
    final converter = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      converter.add(chunk);
    }
    converter.close();
    return digestSink.events.single.toString();
  }

  ReticulumCaptureSource _inferSource(File capture) {
    final isImported = capture.path.contains(
      '${Platform.pathSeparator}$importedSubdir'
      '${Platform.pathSeparator}',
    );
    return isImported
        ? ReticulumCaptureSource.shared
        : ReticulumCaptureSource.local;
  }

  Future<File> _uniquifyDestination(Directory dir, String filename) async {
    var dest = File('${dir.path}/$filename');
    if (!await dest.exists()) return dest;
    final dotBin = filename.lastIndexOf('.bin');
    final stem = dotBin > 0 ? filename.substring(0, dotBin) : filename;
    var n = 1;
    while (true) {
      dest = File('${dir.path}/$stem.$n.bin');
      if (!await dest.exists()) return dest;
      n++;
    }
  }

  String _basename(File f) {
    final segs = f.path.split(Platform.pathSeparator);
    final last = segs.isEmpty ? f.path : segs.last;
    return last.endsWith('.bin') ? last : '$last.bin';
  }

  String _short(String checksum) =>
      checksum.length >= 12 ? checksum.substring(0, 12) : checksum;
}

/// Tiny single-event sink used to capture the digest at the end of
/// the streaming SHA-256 conversion.
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = <T>[];
  bool _closed = false;

  @override
  void add(T data) {
    if (_closed) throw StateError('AccumulatorSink already closed');
    events.add(data);
  }

  @override
  void close() {
    _closed = true;
  }
}
