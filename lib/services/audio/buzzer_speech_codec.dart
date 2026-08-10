// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Conditions speech for playback through a Meshtastic node's buzzer.
///
/// Firmware that can speak accepts 8-bit PCM over a BLE characteristic and
/// plays it through the transducer. Synthesis happens here rather than on the
/// node because it was measured and rejected there: SAM was run on the device
/// at five drive levels and six voice configurations and none of it was
/// intelligible, while recorded speech through the identical path is clear.
/// The channel is fine; synthesis into a 1500-2900 Hz window is not.
///
/// Audio has to be conditioned for that transducer, and untreated speech is
/// not intelligible through it. Speech intelligibility normally lives at
/// 300 Hz to 3.4 kHz, but the element produces nothing useful below about
/// 1.4 kHz, so more than half of that band is wasted excursion. Band-limiting
/// onto the measured resonance and driving hard into a limiter beat every
/// wider or gentler setting tested by ear on real hardware.
///
/// Pure functions with no plugin or platform dependencies, so the chain is
/// unit-testable against the reference implementation that produced the
/// hardware-verified audio.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// PWM timing for a sample rate the node's hardware can produce exactly.
///
/// The wire format carries timing rather than a sample rate so the firmware
/// never has to solve for one: a rate it cannot make exactly is rejected
/// rather than approximated.
class BuzzerPwmTiming {
  const BuzzerPwmTiming({
    required this.rate,
    required this.countertop,
    required this.refresh,
    required this.carrierHz,
  });

  final int rate;
  final int countertop;
  final int refresh;
  final int carrierHz;
}

/// Mono samples in -1..1 plus the rate they were recorded at, decoded from a
/// platform synthesiser's output file.
class DecodedWav {
  const DecodedWav(this.samples, this.sampleRate);
  final List<double> samples;
  final int sampleRate;
}

/// Minimal RIFF/WAVE reader for what platform speech synthesisers produce:
/// integer PCM at 8 or 16 bit, or IEEE float at 32 bit, mono or stereo.
/// The float case is what iOS emits: AVSpeechSynthesizer's write callback
/// hands over float32 buffers and AVAudioFile stores them as-is. Chunks are
/// walked rather than assumed at fixed offsets, because platforms insert
/// extra ones (`LIST`, `fact`, ...) between `fmt ` and `data`. Stereo is
/// downmixed by averaging.
///
/// Returns null for anything else, including other containers a platform
/// might emit (CAF, AIFF); callers treat null as "no audio" rather than an
/// error.
DecodedWav? decodeWav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  if (bd.getUint32(0, Endian.big) != 0x52494646) return null; // "RIFF"
  if (bd.getUint32(8, Endian.big) != 0x57415645) return null; // "WAVE"

  var offset = 12;
  var format = 1; // 1 = integer PCM, 3 = IEEE float
  var channels = 1;
  var sampleRate = 22050;
  var bits = 16;
  Uint8List? data;

  while (offset + 8 <= bytes.length) {
    final id = bd.getUint32(offset, Endian.big);
    final size = bd.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (body + size > bytes.length) {
      // Truncated final chunk: take what is actually there.
      if (id == 0x64617461) {
        data = Uint8List.sublistView(bytes, body, bytes.length);
      }
      break;
    }
    if (id == 0x666D7420) {
      // "fmt "
      format = bd.getUint16(body, Endian.little);
      channels = bd.getUint16(body + 2, Endian.little);
      sampleRate = bd.getUint32(body + 4, Endian.little);
      bits = bd.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 40) {
        // WAVE_FORMAT_EXTENSIBLE: the real format code is the first two
        // bytes of the sub-format GUID.
        format = bd.getUint16(body + 24, Endian.little);
      }
    } else if (id == 0x64617461) {
      // "data". A writer that is still open declares size zero until it
      // finalises the header: CoreAudio flushes every sample to disk before
      // the synthesiser reports completion but only rewrites the sizes when
      // the file object is later released. The samples are there, so a zero
      // size means everything to end of file, not an empty chunk.
      data = Uint8List.sublistView(
        bytes,
        body,
        size == 0 ? bytes.length : body + size,
      );
    }
    offset = body + size + (size.isOdd ? 1 : 0); // chunks are word aligned
  }

  if (data == null || data.isEmpty || channels < 1) return null;

  final samples = <double>[];
  if (format == 1 && bits == 16) {
    final view = ByteData.view(
      data.buffer,
      data.offsetInBytes,
      data.length - (data.length % 2),
    );
    for (var i = 0; i + 1 < view.lengthInBytes; i += 2) {
      samples.add(view.getInt16(i, Endian.little) / 32768.0);
    }
  } else if (format == 1 && bits == 8) {
    for (final b in data) {
      samples.add((b - 128) / 128.0);
    }
  } else if (format == 3 && bits == 32) {
    final view = ByteData.view(
      data.buffer,
      data.offsetInBytes,
      data.length - (data.length % 4),
    );
    for (var i = 0; i + 3 < view.lengthInBytes; i += 4) {
      final v = view.getFloat32(i, Endian.little);
      samples.add(v.isFinite ? v.clamp(-1.0, 1.0) : 0.0);
    }
  } else {
    return null;
  }

  if (channels > 1) {
    final mono = <double>[];
    for (var i = 0; i + channels <= samples.length; i += channels) {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += samples[i + c];
      }
      mono.add(sum / channels);
    }
    return DecodedWav(mono, sampleRate);
  }
  return DecodedWav(samples, sampleRate);
}

class BuzzerSpeechCodec {
  BuzzerSpeechCodec._();

  /// The nRF52840 PWM peripheral's base clock.
  static const int _baseHz = 16000000;

  /// Source samples are 8-bit, so duty resolution past 256 steps is wasted.
  static const int _minCountertop = 249;

  /// Magic that opens an utterance, so a stray write cannot start one.
  static const int _magic0 = 0xA5;
  static const int _magic1 = 0x5A;

  /// Header length in bytes, ahead of the PCM payload.
  static const int headerLength = 10;

  /// The firmware's utterance buffer: five seconds at 8 kHz.
  static const int maxUtteranceBytes = 40960;

  /// Measured passband of the transducer, not the speech band.
  static const double defaultLowHz = 1500;
  static const double defaultHighHz = 2900;
  static const double defaultPreEmphasis = 0.70;
  static const double defaultMakeupDb = 22;

  /// 8 kHz is the sensible default over a radio link. The passband tops out at
  /// 2.9 kHz so Nyquist is nowhere near the constraint, and it halves both the
  /// transfer and the firmware's buffer.
  static const int defaultRate = 8000;

  /// Solves `16 MHz / (countertop * (refresh + 1)) == rate` exactly.
  ///
  /// Maximises the carrier, because the higher it sits the more thoroughly the
  /// transducer's own mass filters it out and the further residual switching
  /// stays from the audio band. Returns null when no exact solution exists;
  /// 8000, 10000 and 16000 all divide cleanly.
  static BuzzerPwmTiming? timingFor(int rate) {
    BuzzerPwmTiming? best;
    for (var refresh = 0; refresh < 256; refresh++) {
      final div = rate * (refresh + 1);
      if (div == 0 || _baseHz % div != 0) continue;
      final top = _baseHz ~/ div;
      if (top < _minCountertop || top > 32767) continue;
      final carrier = _baseHz ~/ top;
      if (best == null || carrier > best.carrierHz) {
        best = BuzzerPwmTiming(
          rate: rate,
          countertop: top,
          refresh: refresh,
          carrierHz: carrier,
        );
      }
    }
    return best;
  }

  /// Conditions [samples] (mono, -1..1, at [sourceRate]) into unsigned 8-bit
  /// PCM at [timing.rate], ready to hand to [frame].
  static Uint8List condition(
    List<double> samples,
    int sourceRate,
    BuzzerPwmTiming timing, {
    double lowHz = defaultLowHz,
    double highHz = defaultHighHz,
    double preEmphasis = defaultPreEmphasis,
    double makeupDb = defaultMakeupDb,
  }) {
    if (samples.isEmpty) return Uint8List(0);

    var x = List<double>.from(samples);

    x = _highPass(x, sourceRate, 60); // DC and rumble
    x = _bandLimit(x, sourceRate, lowHz, highHz);
    x = _resample(x, sourceRate, timing.rate);
    x = _preEmphasis(x, preEmphasis);
    x = _compress(x, timing.rate, -22, 8, 3, 90);

    // Normalise before makeup so the limiter is actually driven. Normalising
    // straight to the target peak leaves it idle and lets the loudest
    // transient set the level for the whole utterance.
    x = _normalise(x, 1);
    x = _gainDb(x, makeupDb);
    x = _softLimit(x, 1);
    x = _normalise(x, 0.97);
    _fade(x, timing.rate, 5);

    final out = Uint8List(x.length);
    for (var i = 0; i < x.length; i++) {
      final v = (x[i] * 127).round() + 128;
      out[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
    }
    return out;
  }

  /// Builds the header the firmware expects, followed by [pcm].
  ///
  /// Write this to the speech characteristic. Payload may ride along in the
  /// same write as the header, and the rest follows as raw PCM.
  static Uint8List frame(Uint8List pcm, BuzzerPwmTiming timing) {
    final out = Uint8List(headerLength + pcm.length);
    final bd = ByteData.view(out.buffer);
    out[0] = _magic0;
    out[1] = _magic1;
    bd.setUint16(2, timing.countertop, Endian.little);
    out[4] = timing.refresh;
    out[5] = 0; // reserved
    bd.setUint32(6, pcm.length, Endian.little);
    out.setRange(headerLength, out.length, pcm);
    return out;
  }

  // ------------------------------------------------------------ filters

  static List<double> _biquad(
    List<double> x,
    double b0,
    double b1,
    double b2,
    double a1,
    double a2,
  ) {
    final y = List<double>.filled(x.length, 0);
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    for (var i = 0; i < x.length; i++) {
      final s = x[i];
      final o = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = s;
      y2 = y1;
      y1 = o;
      y[i] = o;
    }
    return y;
  }

  /// RBJ cookbook, Q = 0.7071.
  static List<double> _lowPass(List<double> x, int rate, double fc) {
    if (fc >= rate / 2) return x;
    final w = 2 * math.pi * fc / rate;
    final a = math.sin(w) / (2 * 0.7071);
    final c = math.cos(w);
    final a0 = 1 + a;
    return _biquad(
      x,
      (1 - c) / 2 / a0,
      (1 - c) / a0,
      (1 - c) / 2 / a0,
      -2 * c / a0,
      (1 - a) / a0,
    );
  }

  static List<double> _highPass(List<double> x, int rate, double fc) {
    if (fc <= 0) return x;
    final w = 2 * math.pi * fc / rate;
    final a = math.sin(w) / (2 * 0.7071);
    final c = math.cos(w);
    final a0 = 1 + a;
    return _biquad(
      x,
      (1 + c) / 2 / a0,
      -(1 + c) / a0,
      (1 + c) / 2 / a0,
      -2 * c / a0,
      (1 - a) / a0,
    );
  }

  /// Two cascaded passes, so 4th order overall.
  static List<double> _bandLimit(
    List<double> x,
    int rate,
    double lo,
    double hi,
  ) {
    var out = x;
    for (var i = 0; i < 2; i++) {
      out = _highPass(out, rate, lo);
      out = _lowPass(out, rate, hi);
    }
    return out;
  }

  /// Linear interpolation, legitimate only because the band-limit stage has
  /// already taken everything well below the destination Nyquist.
  static List<double> _resample(List<double> x, int src, int dst) {
    if (src == dst) return x;
    final ratio = src / dst;
    final out = <double>[];
    final n = x.length;
    var i = 0.0;
    while (i < n - 1) {
      final k = i.floor();
      final f = i - k;
      out.add(x[k] * (1 - f) + x[k + 1] * f);
      i += ratio;
    }
    return out;
  }

  static List<double> _preEmphasis(List<double> x, double a) {
    if (a <= 0) return x;
    final out = List<double>.filled(x.length, 0);
    var prev = 0.0;
    for (var i = 0; i < x.length; i++) {
      out[i] = x[i] - a * prev;
      prev = x[i];
    }
    return out;
  }

  /// Feed-forward peak compressor. The envelope tracks |x| with separate
  /// attack and release, and the gain applies to the sample that produced it.
  static List<double> _compress(
    List<double> x,
    int rate,
    double threshDb,
    double ratio,
    double attackMs,
    double releaseMs,
  ) {
    final thresh = math.pow(10, threshDb / 20).toDouble();
    final at = math.exp(-1 / (rate * attackMs / 1000));
    final rt = math.exp(-1 / (rate * releaseMs / 1000));
    var env = 0.0;
    final out = List<double>.filled(x.length, 0);
    for (var i = 0; i < x.length; i++) {
      final s = x[i];
      final a = s.abs();
      env = a > env ? at * env + (1 - at) * a : rt * env + (1 - rt) * a;
      final g = env > thresh
          ? math.pow(env / thresh, 1 / ratio - 1).toDouble()
          : 1.0;
      out[i] = s * g;
    }
    return out;
  }

  /// tanh saturation: unity slope for small signals, asymptotic at the
  /// ceiling, so makeup gain can be driven into it without the hard corners
  /// that clipping puts on every transient.
  static List<double> _softLimit(List<double> x, double ceiling) {
    return [
      for (final s in x)
        ceiling *
            ((math.exp(2 * s / ceiling) - 1) / (math.exp(2 * s / ceiling) + 1)),
    ];
  }

  static List<double> _gainDb(List<double> x, double db) {
    final g = math.pow(10, db / 20).toDouble();
    return [for (final s in x) s * g];
  }

  static List<double> _normalise(List<double> x, double peak) {
    var m = 0.0;
    for (final s in x) {
      final a = s.abs();
      if (a > m) m = a;
    }
    if (m < 1e-9) return x;
    final g = peak / m;
    return [for (final s in x) s * g];
  }

  static void _fade(List<double> x, int rate, double ms) {
    final n = math.min((rate * ms / 1000).floor(), x.length ~/ 2);
    for (var i = 0; i < n; i++) {
      final g = i / n;
      x[i] *= g;
      x[x.length - 1 - i] *= g;
    }
  }
}
