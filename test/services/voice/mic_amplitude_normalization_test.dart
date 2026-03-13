// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/voice_recorder.dart';

void main() {
  group('VoiceRecorder.normalizeDb()', () {
    test('noise gate: -40 dBFS maps to 0.0', () {
      expect(VoiceRecorder.normalizeDb(-40.0), closeTo(0.0, 1e-9));
    });

    test('full scale (0 dBFS) maps to 1.0', () {
      expect(VoiceRecorder.normalizeDb(0.0), closeTo(1.0, 1e-9));
    });

    test('silence floor (-60 dBFS) is gated to 0.0', () {
      expect(VoiceRecorder.normalizeDb(-60.0), closeTo(0.0, 1e-9));
    });

    // t^1.5 curve: t=0.5 at -20dBFS → 0.5 * sqrt(0.5) ≈ 0.354
    test('mid-point (-20 dBFS) maps to ~0.354 (t^1.5)', () {
      expect(VoiceRecorder.normalizeDb(-20.0), closeTo(0.3536, 0.001));
    });

    // t=0.25 at -30dBFS → 0.25 * sqrt(0.25) = 0.25 * 0.5 = 0.125
    test('quiet speech (-30 dBFS) maps to 0.125 (t^1.5)', () {
      expect(VoiceRecorder.normalizeDb(-30.0), closeTo(0.125, 1e-6));
    });

    test('clamps values below the -40 dBFS gate to 0.0', () {
      expect(VoiceRecorder.normalizeDb(-80.0), closeTo(0.0, 1e-9));
      expect(VoiceRecorder.normalizeDb(-120.0), closeTo(0.0, 1e-9));
    });

    test('clamps values above 0 dBFS to 1.0', () {
      expect(VoiceRecorder.normalizeDb(5.0), closeTo(1.0, 1e-9));
    });

    test('output is always in [0.0, 1.0]', () {
      for (final dBFS in [
        -90.0,
        -60.0,
        -45.0,
        -40.0,
        -30.0,
        -15.0,
        -5.0,
        0.0,
        3.0,
      ]) {
        final v = VoiceRecorder.normalizeDb(dBFS);
        expect(v, inInclusiveRange(0.0, 1.0), reason: 'dBFS=$dBFS → $v');
      }
    });

    test('output is monotonically non-decreasing across the dBFS range', () {
      double prev = 0.0;
      for (var dB = -60.0; dB <= 0.0; dB += 5.0) {
        final current = VoiceRecorder.normalizeDb(dB);
        expect(
          current,
          greaterThanOrEqualTo(prev),
          reason: 'Not monotone at dBFS=$dB',
        );
        prev = current;
      }
    });
  });
}
