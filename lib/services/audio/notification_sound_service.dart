import '../../core/logging.dart';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing custom notification sounds from RTTTL
///
/// iOS requires notification sounds to be in specific formats (WAV, AIFF, CAF)
/// and located in the Library/Sounds directory of the app.
/// This service converts RTTTL strings to WAV files and saves them appropriately.
class NotificationSoundService {
  static NotificationSoundService? _instance;
  static NotificationSoundService get instance =>
      _instance ??= NotificationSoundService._();

  NotificationSoundService._();

  /// Directory where notification sounds are stored
  String? _soundsDirectory;

  /// Initialize the service and ensure sounds directory exists
  Future<void> initialize() async {
    if (_soundsDirectory != null) return;

    final appDir = await getApplicationSupportDirectory();
    _soundsDirectory = '${appDir.path}/Sounds';

    final dir = Directory(_soundsDirectory!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Get the filename for a given RTTTL string (based on hash)
  String _getSoundFilename(String rtttl) {
    // Simple hash using string hashCode - sufficient for our needs
    final hash = rtttl.hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'notification_$hash.wav';
  }

  /// Get the full path to a notification sound file
  Future<String?> getSoundPath(String rtttl) async {
    await initialize();
    final filename = _getSoundFilename(rtttl);
    final path = '$_soundsDirectory/$filename';

    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }

  /// Prepare a notification sound from RTTTL
  /// Returns the filename (not full path) to use in notification sound parameter
  /// Returns null if conversion fails
  Future<String?> prepareSoundFromRtttl(String rtttl) async {
    await initialize();

    final filename = _getSoundFilename(rtttl);
    final path = '$_soundsDirectory/$filename';

    // Check if already exists
    final file = File(path);
    if (await file.exists()) {
      AppLogging.audio(
        'NotificationSoundService: Sound already cached: $filename',
      );
      return filename;
    }

    try {
      // Parse and convert RTTTL to WAV
      final wavData = _convertRtttlToWav(rtttl);
      if (wavData == null) {
        AppLogging.audio('NotificationSoundService: Failed to convert RTTTL');
        return null;
      }

      // Save to file
      await file.writeAsBytes(wavData);
      AppLogging.audio('NotificationSoundService: Saved sound to $path');

      return filename;
    } catch (e) {
      AppLogging.audio('NotificationSoundService: Error preparing sound: $e');
      return null;
    }
  }

  /// Convert RTTTL string to WAV bytes
  /// iOS notification sounds must be <= 30 seconds
  Uint8List? _convertRtttlToWav(String rtttl) {
    try {
      final parsed = _parseRtttl(rtttl);
      if (parsed == null || parsed.notes.isEmpty) {
        return null;
      }

      return _generateWav(parsed);
    } catch (e) {
      AppLogging.audio('NotificationSoundService: RTTTL conversion error: $e');
      return null;
    }
  }

  /// Parse RTTTL string into structured data
  _RtttlData? _parseRtttl(String rtttl) {
    try {
      rtttl = rtttl.trim();

      final parts = rtttl.split(':');
      if (parts.length < 3) {
        if (parts.length == 2) {
          parts.insert(0, 'tune');
        } else {
          return null;
        }
      }

      final defaults = parts[1].toLowerCase();
      final notesStr = parts.sublist(2).join(':');

      int defaultDuration = 4;
      int defaultOctave = 5;
      int bpm = 120;

      for (final part in defaults.split(',')) {
        final kv = part.trim().split('=');
        if (kv.length != 2) continue;

        final key = kv[0].trim();
        final value = int.tryParse(kv[1].trim()) ?? 0;

        switch (key) {
          case 'd':
            defaultDuration = value > 0 ? value : 4;
            break;
          case 'o':
            defaultOctave = value >= 4 && value <= 7 ? value : 5;
            break;
          case 'b':
            bpm = value > 0 ? value : 120;
            break;
        }
      }

      final notes = <_Note>[];
      for (final noteStr in notesStr.split(',')) {
        final note = _parseNote(noteStr.trim(), defaultDuration, defaultOctave);
        if (note != null) {
          notes.add(note);
        }
      }

      return _RtttlData(
        bpm: bpm,
        defaultOctave: defaultOctave,
        defaultDuration: defaultDuration,
        notes: notes,
      );
    } catch (e) {
      return null;
    }
  }

  _Note? _parseNote(String noteStr, int defaultDuration, int defaultOctave) {
    if (noteStr.isEmpty) return null;

    final pattern = RegExp(
      r'^(\d+)?([a-gp])(\#)?(\.)?([\d])?(\.)?\s*$',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(noteStr.toLowerCase());
    if (match == null) return null;

    final durationStr = match.group(1);
    final noteLetter = match.group(2);
    final isSharp = match.group(3) != null;
    final dotBefore = match.group(4) != null;
    final octaveStr = match.group(5);
    final dotAfter = match.group(6) != null;

    if (noteLetter == null) return null;

    final duration = durationStr != null
        ? int.tryParse(durationStr) ?? defaultDuration
        : defaultDuration;

    final octave = octaveStr != null
        ? int.tryParse(octaveStr) ?? defaultOctave
        : defaultOctave;

    final isDotted = dotBefore || dotAfter;
    final frequency = _noteToFrequency(noteLetter, isSharp, octave);

    return _Note(frequency: frequency, duration: duration, isDotted: isDotted);
  }

  double _noteToFrequency(String note, bool isSharp, int octave) {
    if (note == 'p') return 0;

    const noteIndices = {
      'c': 0,
      'd': 2,
      'e': 4,
      'f': 5,
      'g': 7,
      'a': 9,
      'b': 11,
    };

    final noteIndex = noteIndices[note];
    if (noteIndex == null) return 0;

    const middleC = 261.63;
    final semitoneOffset = noteIndex + (isSharp ? 1 : 0);
    return middleC * pow(2, (octave - 4) + semitoneOffset / 12.0);
  }

  Uint8List _generateWav(_RtttlData data) {
    const sampleRate = 44100;
    final samples = <int>[];

    final wholeNoteDuration = (60.0 / data.bpm) * 4.0;

    for (final note in data.notes) {
      var noteDuration = wholeNoteDuration / note.duration;
      if (note.isDotted) {
        noteDuration *= 1.5;
      }

      final numSamples = (noteDuration * sampleRate).round();

      if (note.frequency == 0) {
        samples.addAll(List.filled(numSamples, 0));
      } else {
        for (int i = 0; i < numSamples; i++) {
          final t = i / sampleRate;

          double envelope = 1.0;
          const attackTime = 0.01;
          const releaseTime = 0.05;

          if (t < attackTime) {
            envelope = t / attackTime;
          } else if (t > noteDuration - releaseTime) {
            envelope = (noteDuration - t) / releaseTime;
          }
          envelope = envelope.clamp(0.0, 1.0);

          final sample = sin(2 * pi * note.frequency * t) * envelope * 0.5;
          samples.add((sample * 32767).round().clamp(-32768, 32767));
        }
      }

      // Small gap between notes
      samples.addAll(List.filled((0.01 * sampleRate).round(), 0));
    }

    // Ensure sound is not longer than 30 seconds (iOS limit)
    const maxSamples = 30 * sampleRate;
    if (samples.length > maxSamples) {
      samples.removeRange(maxSamples, samples.length);
    }

    return _createWav(samples, sampleRate);
  }

  Uint8List _createWav(List<int> samples, int sampleRate) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // space
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  /// Clean up old notification sound files
  Future<void> cleanupOldSounds({int keepCount = 20}) async {
    await initialize();

    final dir = Directory(_soundsDirectory!);
    if (!await dir.exists()) return;

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.wav'))
        .cast<File>()
        .toList();

    if (files.length <= keepCount) return;

    // Sort by modification time, oldest first
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return aStat.modified.compareTo(bStat.modified);
    });

    // Delete oldest files
    final toDelete = files.take(files.length - keepCount);
    for (final file in toDelete) {
      try {
        await file.delete();
        AppLogging.audio(
          'NotificationSoundService: Deleted old sound: ${file.path}',
        );
      } catch (e) {
        AppLogging.audio('NotificationSoundService: Failed to delete: $e');
      }
    }
  }
}

class _RtttlData {
  final int bpm;
  final int defaultOctave;
  final int defaultDuration;
  final List<_Note> notes;

  _RtttlData({
    required this.bpm,
    required this.defaultOctave,
    required this.defaultDuration,
    required this.notes,
  });
}

class _Note {
  final double frequency;
  final int duration;
  final bool isDotted;

  _Note({
    required this.frequency,
    required this.duration,
    this.isDotted = false,
  });
}
