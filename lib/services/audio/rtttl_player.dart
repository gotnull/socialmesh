import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// RTTTL (Ring Tone Text Transfer Language) Parser and Player
///
/// RTTTL Format: name:d=duration,o=octave,b=bpm:notes
/// Example: "Nokia:d=4,o=5,b=180:8e6,8d6,f#,g#,8c#6,8b,d,e,8b,8a,c#,e,2a"
class RtttlPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Parse and play an RTTTL string
  Future<void> play(String rtttl) async {
    if (_isPlaying) {
      await stop();
    }

    try {
      final parsed = _parseRtttl(rtttl);
      if (parsed == null || parsed.notes.isEmpty) {
        throw Exception('Invalid RTTTL string');
      }

      _isPlaying = true;

      // Generate and play WAV audio
      final wavData = _generateWav(parsed);
      await _player.setAudioSource(RtttlAudioSource(wavData));
      await _player.play();

      // Wait for completion
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
    } catch (e) {
      _isPlaying = false;
      rethrow;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    _isPlaying = false;
    await _player.stop();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  /// Parse RTTTL string into structured data
  _RtttlData? _parseRtttl(String rtttl) {
    try {
      // Remove any leading/trailing whitespace
      rtttl = rtttl.trim();

      // Split into parts: name:defaults:notes
      final parts = rtttl.split(':');
      if (parts.length < 3) {
        // Try to handle format without name
        if (parts.length == 2) {
          parts.insert(0, 'tune');
        } else {
          return null;
        }
      }

      final defaults = parts[1].toLowerCase();
      final notesStr = parts.sublist(2).join(':');

      // Parse defaults
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

      // Parse notes
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

  /// Parse a single note
  _Note? _parseNote(String noteStr, int defaultDuration, int defaultOctave) {
    if (noteStr.isEmpty) return null;

    // RTTTL note format: [duration]note[#][.][octave]
    // Examples: 8e6, c#, 2p, 4a.5, 8f#.6, 32p
    // The dot (for dotted notes) can appear before or after the octave

    // Use regex to parse - matches the working JavaScript implementation
    // Pattern: optional duration, required note (a-g or p), optional sharp,
    // optional dot, optional octave
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

    // Calculate frequency
    final frequency = _noteToFrequency(noteLetter, isSharp, octave);

    return _Note(frequency: frequency, duration: duration, isDotted: isDotted);
  }

  /// Convert note letter to frequency in Hz
  /// Uses middle C (C4 = 261.63 Hz) as reference, matching standard RTTTL
  double _noteToFrequency(String note, bool isSharp, int octave) {
    // Pause/rest
    if (note == 'p') return 0;

    // Chromatic scale note indices (C = 0)
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

    // Middle C (C4) = 261.63 Hz
    const middleC = 261.63;

    // Calculate frequency: middleC * 2^((octave - 4) + noteIndex/12)
    // This matches the JavaScript reference implementation
    final semitoneOffset = noteIndex + (isSharp ? 1 : 0);
    return middleC * pow(2, (octave - 4) + semitoneOffset / 12.0);
  }

  /// Generate WAV audio data from parsed RTTTL
  Uint8List _generateWav(_RtttlData data) {
    const sampleRate = 44100;
    final samples = <int>[];

    // Calculate whole note duration in samples
    final wholeNoteDuration = (60.0 / data.bpm) * 4.0;

    for (final note in data.notes) {
      // Calculate note duration in seconds
      var noteDuration = wholeNoteDuration / note.duration;
      if (note.isDotted) {
        noteDuration *= 1.5;
      }

      final numSamples = (noteDuration * sampleRate).round();

      if (note.frequency == 0) {
        // Rest/pause - silence
        samples.addAll(List.filled(numSamples, 0));
      } else {
        // Generate sine wave with envelope
        for (int i = 0; i < numSamples; i++) {
          final t = i / sampleRate;

          // Simple ADSR envelope
          double envelope = 1.0;
          final attackTime = 0.01;
          final releaseTime = 0.05;

          if (t < attackTime) {
            envelope = t / attackTime;
          } else if (t > noteDuration - releaseTime) {
            envelope = (noteDuration - t) / releaseTime;
          }
          envelope = envelope.clamp(0.0, 1.0);

          // Generate sample (sine wave)
          final sample = sin(2 * pi * note.frequency * t) * envelope * 0.5;
          samples.add((sample * 32767).round().clamp(-32768, 32767));
        }
      }

      // Add small gap between notes (10ms)
      samples.addAll(List.filled((0.01 * sampleRate).round(), 0));
    }

    return _createWav(samples, sampleRate);
  }

  /// Create WAV file bytes from samples
  Uint8List _createWav(List<int> samples, int sampleRate) {
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
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
    buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // AudioFormat (PCM)
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

    // Write samples
    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
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
  final double frequency; // Hz, 0 for rest
  final int duration; // Musical duration (1, 2, 4, 8, 16, 32)
  final bool isDotted;

  _Note({
    required this.frequency,
    required this.duration,
    this.isDotted = false,
  });
}

/// Custom AudioSource for playing raw WAV data
class RtttlAudioSource extends StreamAudioSource {
  final Uint8List _wavData;

  RtttlAudioSource(this._wavData);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _wavData.length;

    return StreamAudioResponse(
      sourceLength: _wavData.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_wavData.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
