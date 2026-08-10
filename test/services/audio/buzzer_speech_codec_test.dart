// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/audio/buzzer_speech_codec.dart';

/// The reference vectors below come from the Python implementation in the
/// automatic-mouth repo (`tools/wav2c.py`), which is what produced the audio
/// that was confirmed intelligible on real hardware. Pinning against it is the
/// point: the conditioning is not a matter of taste, and a chain that drifts
/// from it produces audio this transducer cannot carry.
///
/// The input is synthetic rather than speech so the vector is reproducible
/// without a text-to-speech engine.
List<double> _referenceInput() {
  const sr = 22050;
  final n = (sr * 0.30).toInt();
  final x = <double>[];
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    var s =
        0.45 *
            math.sin(2 * math.pi * 300 * t) // below the passband
            +
        0.35 *
            math.sin(2 * math.pi * 2000 * t) // inside it
            +
        0.20 * math.sin(2 * math.pi * 5000 * t); // above it
    if (t > 0.12 && t < 0.16) {
      s +=
          0.5 *
          math.sin(2 * math.pi * 1800 * t); // transient for the compressor
    }
    x.add(s);
  }
  return x;
}

void main() {
  group('BuzzerSpeechCodec.timingFor', () {
    test('solves the PWM divide exactly for the rates we use', () {
      final t8 = BuzzerSpeechCodec.timingFor(8000)!;
      expect(t8.countertop, 250);
      expect(t8.refresh, 7);
      expect(t8.carrierHz, 64000);

      final t16 = BuzzerSpeechCodec.timingFor(16000)!;
      expect(t16.countertop, 250);
      expect(t16.refresh, 3);
      expect(t16.carrierHz, 64000);
    });

    test(
      'keeps the carrier above hearing so the transducer filters it out',
      () {
        for (final rate in [8000, 10000, 16000]) {
          expect(
            BuzzerSpeechCodec.timingFor(rate)!.carrierHz,
            greaterThan(20000),
          );
        }
      },
    );

    test(
      'reports rates the hardware cannot make exactly, rather than rounding',
      () {
        // 22050 does not divide 16 MHz, so there is no exact countertop/refresh.
        expect(BuzzerSpeechCodec.timingFor(22050), isNull);
      },
    );
  });

  group('BuzzerSpeechCodec.condition', () {
    late final timing = BuzzerSpeechCodec.timingFor(8000)!;
    late final pcm = BuzzerSpeechCodec.condition(
      _referenceInput(),
      22050,
      timing,
    );

    test('matches the hardware-verified reference implementation', () {
      expect(pcm.length, 2400);
      expect(pcm.take(16).toList(), [
        128,
        131,
        122,
        119,
        140,
        143,
        110,
        106,
        153,
        156,
        97,
        94,
        165,
        168,
        85,
        82,
      ]);
      expect(pcm.skip(pcm.length - 16).toList(), [
        174,
        171,
        88,
        91,
        162,
        159,
        100,
        103,
        150,
        146,
        113,
        116,
        137,
        134,
        125,
        128,
      ]);
      expect(pcm.fold<int>(0, (a, b) => a + b) % 1000000, 307600);
    });

    test('starts and ends at silence, so playback does not click', () {
      expect(pcm.first, 128);
      expect(pcm.last, 128);
    });

    test(
      'drives hard, because loudness is what carries intelligibility here',
      () {
        // Crest factor well under a raw signal's ~20 dB. The offline chain lands
        // the built-in vocabulary near 5 dB and anything gentler lost every A/B.
        var peak = 0.0;
        var sumSq = 0.0;
        for (final s in pcm) {
          final v = (s - 128) / 127.0;
          if (v.abs() > peak) peak = v.abs();
          sumSq += v * v;
        }
        final rms = math.sqrt(sumSq / pcm.length);
        final crestDb = 20 * (math.log(peak / rms) / math.ln10);
        expect(crestDb, lessThan(12));
      },
    );

    test('empty input produces no audio rather than throwing', () {
      expect(BuzzerSpeechCodec.condition([], 22050, timing), isEmpty);
    });
  });

  group('BuzzerSpeechCodec.frame', () {
    test('writes the header the firmware parses', () {
      final timing = BuzzerSpeechCodec.timingFor(8000)!;
      final pcm = BuzzerSpeechCodec.condition(_referenceInput(), 22050, timing);
      final framed = BuzzerSpeechCodec.frame(pcm, timing);

      expect(framed.length, BuzzerSpeechCodec.headerLength + pcm.length);
      expect(
        framed[0],
        0xA5,
      ); // magic, so a stray write cannot open an utterance
      expect(framed[1], 0x5A);
      expect(framed[2] | (framed[3] << 8), timing.countertop);
      expect(framed[4], timing.refresh);
      expect(framed[5], 0); // reserved
      final declared =
          framed[6] | (framed[7] << 8) | (framed[8] << 16) | (framed[9] << 24);
      expect(declared, pcm.length);
      expect(
        framed.skip(BuzzerSpeechCodec.headerLength).take(8).toList(),
        pcm.take(8).toList(),
      );
    });

    test('a three second utterance fits the firmware buffer at 8 kHz', () {
      expect(3 * 8000, lessThan(BuzzerSpeechCodec.maxUtteranceBytes));
      // ...but not at 16 kHz, which is why 8 kHz is the default over BLE.
      expect(3 * 16000, greaterThan(BuzzerSpeechCodec.maxUtteranceBytes));
    });
  });

  group('decodeWav', () {
    test('parses a canonical 16-bit mono file', () {
      final wav = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 16),
        _chunk('data', _int16Bytes([0, 16384, -16384, 32767])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.sampleRate, 22050);
      expect(decoded.samples, hasLength(4));
      expect(decoded.samples[0], 0);
      expect(decoded.samples[1], closeTo(0.5, 1e-4));
      expect(decoded.samples[2], closeTo(-0.5, 1e-4));
      expect(decoded.samples[3], closeTo(1.0, 1e-3));
    });

    test('walks past a LIST/INFO chunk sitting before data', () {
      // Both desktop and mobile synthesisers insert metadata chunks between
      // fmt and data; a parser that assumes fixed offsets dies here.
      final wav = _riff([
        _fmtChunk(channels: 1, rate: 16000, bits: 16),
        _chunk('LIST', [
          ...'INFO'.codeUnits,
          ...'ISFT'.codeUnits,
          4,
          0,
          0,
          0,
          ...'test'.codeUnits,
        ]),
        _chunk('data', _int16Bytes([1000, -1000])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.sampleRate, 16000);
      expect(decoded.samples, hasLength(2));
    });

    test('honours the pad byte after an odd-sized chunk', () {
      // RIFF chunks are word aligned: an odd body is followed by one pad byte
      // that is not part of the declared size. Missing it shifts every later
      // chunk id by one and the data chunk is never found.
      final wav = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 16),
        _chunk('note', [0x41, 0x42, 0x43]), // 3 bytes -> 1 pad byte
        _chunk('data', _int16Bytes([12345])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.samples, hasLength(1));
      expect(decoded.samples[0], closeTo(12345 / 32768.0, 1e-6));
    });

    test('downmixes stereo by averaging the channels', () {
      final wav = _riff([
        _fmtChunk(channels: 2, rate: 44100, bits: 16),
        _chunk('data', _int16Bytes([16384, -16384, 8192, 8192])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.samples, hasLength(2));
      expect(decoded.samples[0], closeTo(0, 1e-4)); // L and R cancel
      expect(decoded.samples[1], closeTo(0.25, 1e-4));
    });

    test('decodes 8-bit unsigned samples', () {
      final wav = _riff([
        _fmtChunk(channels: 1, rate: 8000, bits: 8),
        _chunk('data', [128, 192, 64, 255]),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.samples[0], 0);
      expect(decoded.samples[1], closeTo(0.5, 1e-6));
      expect(decoded.samples[2], closeTo(-0.5, 1e-6));
      expect(decoded.samples[3], closeTo(0.992, 1e-3));
    });

    test('reads to end of file when the data chunk declares zero size', () {
      // A still-open CoreAudio writer flushes every sample but leaves the
      // header sizes zero until the file object is released, which on iOS
      // happens after the synthesiser reports completion. Real capture from
      // the simulator: 75488 bytes on disk, data size field still zero.
      final zeroSized = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add([0, 0, 0, 0]) // stale RIFF size, also not yet finalised
        ..add('WAVE'.codeUnits)
        ..add(_fmtChunk(channels: 1, rate: 22050, bits: 16))
        ..add('data'.codeUnits)
        ..add([0, 0, 0, 0]) // declared zero
        ..add(_int16Bytes([100, 200, 300]));
      final decoded = decodeWav(zeroSized.toBytes())!;
      expect(decoded.samples, hasLength(3));
    });

    test('takes what is actually present from a truncated data chunk', () {
      // A synthesiser that streams into the file can leave the declared data
      // size larger than what was flushed. Losing the tail beats losing all
      // of it.
      final complete = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 16),
        _chunk('data', _int16Bytes([100, 200, 300, 400])),
      ]);
      final truncated = Uint8List.sublistView(complete, 0, complete.length - 4);
      final decoded = decodeWav(truncated)!;
      expect(decoded.samples, hasLength(2));
    });

    test('rejects containers that are not RIFF/WAVE', () {
      // CAF is what AVAudioFile writes unless told otherwise, so this is the
      // exact wrong-container case the probe exists to catch.
      final caf = Uint8List.fromList([
        ...'caff'.codeUnits,
        0,
        1,
        0,
        0,
        ...List.filled(64, 0),
      ]);
      expect(decodeWav(caf), isNull);

      final aiff = Uint8List.fromList([
        ...'FORM'.codeUnits,
        0,
        0,
        0,
        100,
        ...'AIFF'.codeUnits,
        ...List.filled(64, 0),
      ]);
      expect(decodeWav(aiff), isNull);

      expect(decodeWav(Uint8List(0)), isNull);
      expect(decodeWav(Uint8List(11)), isNull);
    });

    test('decodes 32-bit float, which is what iOS actually writes', () {
      // AVSpeechSynthesizer hands float32 buffers to AVAudioFile, so a .wav
      // synthesised on iOS is IEEE float (format 3), not integer PCM.
      final wav = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 32, format: 3),
        _chunk('data', _float32Bytes([0.0, 0.5, -0.5, 2.0])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.sampleRate, 22050);
      expect(decoded.samples, hasLength(4));
      expect(decoded.samples[0], 0);
      expect(decoded.samples[1], closeTo(0.5, 1e-6));
      expect(decoded.samples[2], closeTo(-0.5, 1e-6));
      expect(decoded.samples[3], 1.0); // out-of-range float clamps
    });

    test('resolves WAVE_FORMAT_EXTENSIBLE to its sub-format', () {
      final wav = _riff([
        _extensibleFmtChunk(channels: 1, rate: 22050, bits: 32, subFormat: 3),
        _chunk('data', _float32Bytes([0.25])),
      ]);
      final decoded = decodeWav(wav)!;
      expect(decoded.samples, hasLength(1));
      expect(decoded.samples[0], closeTo(0.25, 1e-6));
    });

    test('rejects formats it cannot decode rather than mangling them', () {
      final int24 = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 24),
        _chunk('data', List.filled(9, 0)),
      ]);
      expect(decodeWav(int24), isNull);

      // Float bit depth with an integer format code is a malformed file, not
      // something to guess at.
      final mismatched = _riff([
        _fmtChunk(channels: 1, rate: 22050, bits: 32, format: 1),
        _chunk('data', List.filled(8, 0)),
      ]);
      expect(decodeWav(mismatched), isNull);
    });

    test('returns null when there is no data chunk at all', () {
      final wav = _riff([_fmtChunk(channels: 1, rate: 22050, bits: 16)]);
      expect(decodeWav(wav), isNull);
    });
  });
}

// ------------------------------------------------------------ WAV builders

Uint8List _chunk(String id, List<int> body) {
  assert(id.length == 4);
  final b = BytesBuilder();
  b.add(id.codeUnits);
  b.add(
    Uint8List(4)..buffer.asByteData().setUint32(0, body.length, Endian.little),
  );
  b.add(body);
  if (body.length.isOdd) b.addByte(0); // word-align pad, outside the size
  return b.toBytes();
}

Uint8List _fmtChunk({
  required int channels,
  required int rate,
  required int bits,
  int format = 1,
}) {
  final body = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, rate, Endian.little)
    ..setUint32(8, rate * channels * (bits ~/ 8), Endian.little)
    ..setUint16(12, channels * (bits ~/ 8), Endian.little)
    ..setUint16(14, bits, Endian.little);
  return _chunk('fmt ', body.buffer.asUint8List());
}

Uint8List _extensibleFmtChunk({
  required int channels,
  required int rate,
  required int bits,
  required int subFormat,
}) {
  final body = ByteData(40)
    ..setUint16(0, 0xFFFE, Endian.little) // WAVE_FORMAT_EXTENSIBLE
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, rate, Endian.little)
    ..setUint32(8, rate * channels * (bits ~/ 8), Endian.little)
    ..setUint16(12, channels * (bits ~/ 8), Endian.little)
    ..setUint16(14, bits, Endian.little)
    ..setUint16(16, 22, Endian.little) // cbSize
    ..setUint16(18, bits, Endian.little) // valid bits per sample
    ..setUint32(20, 0x4, Endian.little) // channel mask
    ..setUint16(24, subFormat, Endian.little); // sub-format GUID leads with it
  return _chunk('fmt ', body.buffer.asUint8List());
}

Uint8List _riff(List<Uint8List> chunks) {
  final body = BytesBuilder();
  for (final c in chunks) {
    body.add(c);
  }
  final payload = body.toBytes();
  final out = BytesBuilder();
  out.add('RIFF'.codeUnits);
  out.add(
    Uint8List(4)
      ..buffer.asByteData().setUint32(0, payload.length + 4, Endian.little),
  );
  out.add('WAVE'.codeUnits);
  out.add(payload);
  return out.toBytes();
}

Uint8List _float32Bytes(List<double> values) {
  final bd = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    bd.setFloat32(i * 4, values[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

Uint8List _int16Bytes(List<int> values) {
  final bd = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    bd.setInt16(i * 2, values[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}
