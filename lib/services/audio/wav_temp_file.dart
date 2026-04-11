// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

/// Writes in-memory WAV bytes to a temporary file so that [just_audio]'s
/// stable [AudioPlayer.setFilePath] API can be used instead of the
/// experimental [StreamAudioSource] / [StreamAudioResponse] APIs.
///
/// Lifecycle:
///  1. Call [WavTempFile.write] to persist bytes and obtain a file path.
///  2. Pass [filePath] to `AudioPlayer.setFilePath`.
///  3. Call [cleanup] when the audio source is no longer needed (e.g. on
///     stop, dispose, or before loading a new source).
///
/// Each instance manages exactly one temp file. Creating a new instance
/// for a new playback session is the intended usage pattern.
///
/// Uses [Directory.systemTemp] (pure Dart) which maps to the app-sandboxed
/// temporary directory on both iOS and Android. No `path_provider` dependency
/// required.
class WavTempFile {
  WavTempFile._(this._file);

  final File _file;

  /// Absolute path suitable for [AudioPlayer.setFilePath].
  String get filePath => _file.path;

  /// Writes [wavBytes] to a uniquely-named temporary file and returns a
  /// handle for the caller to manage cleanup.
  ///
  /// The [tag] parameter is included in the filename for debuggability
  /// (e.g. `'rtttl'`, `'voice'`). It must be filesystem-safe.
  static Future<WavTempFile> write(
    Uint8List wavBytes, {
    String tag = 'audio',
  }) async {
    final dir = Directory.systemTemp;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${dir.path}/sm_${tag}_$timestamp.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    return WavTempFile._(file);
  }

  /// Deletes the backing temp file. Safe to call multiple times or after
  /// the file has already been removed by the OS.
  Future<void> cleanup() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } on FileSystemException catch (_) {
      // Best-effort: the OS temp directory is periodically purged anyway.
    }
  }
}
