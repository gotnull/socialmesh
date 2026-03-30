// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/voice_constants.dart';

void main() {
  group('VoiceConstants', () {
    test(
      'maxPayloadBytes equals headerSize plus maxFrames * bytesPerFrame',
      () {
        expect(
          VoiceConstants.maxPayloadBytes,
          VoiceConstants.headerSize +
              VoiceConstants.maxFrames * VoiceConstants.bytesPerFrame,
        );
      },
    );

    test(
      'maxRecordingDuration equals maxFrames * samplesPerFrame / sampleRate',
      () {
        final expectedMilliseconds =
            (VoiceConstants.maxFrames *
                VoiceConstants.samplesPerFrame *
                1000) ~/
            VoiceConstants.sampleRate;
        expect(
          VoiceConstants.maxRecordingDuration.inMilliseconds,
          expectedMilliseconds,
        );
      },
    );

    test('wire format constants match spec values', () {
      expect(VoiceConstants.magicByte, 0xC2);
      expect(VoiceConstants.wireMode1200, 0x04);
      expect(VoiceConstants.cApiMode1200, 5);
      expect(VoiceConstants.bytesPerFrame, 6);
      expect(VoiceConstants.samplesPerFrame, 320);
      expect(VoiceConstants.sampleRate, 8000);
      expect(VoiceConstants.channels, 1);
      expect(VoiceConstants.bitsPerSample, 16);
    });

    test('payload capacity is within SIP 1024-byte-per-60s budget', () {
      expect(VoiceConstants.maxPayloadBytes, lessThanOrEqualTo(8192));
    });

    test('headerSize is 4 bytes', () {
      expect(VoiceConstants.headerSize, 4);
    });

    test('mime type and file extension are correct', () {
      expect(VoiceConstants.mimeType, 'audio/x-codec2');
      expect(VoiceConstants.fileExtension, '.c2');
    });

    test('filename prefix is correct', () {
      expect(VoiceConstants.filenamePrefix, 'voice_');
    });

    test('maxTransferSize is 8192', () {
      expect(VoiceConstants.maxTransferSize, 8192);
    });
  });

  group('VoiceQuality', () {
    test('extended mode matches 1200 bps spec', () {
      const q = VoiceQuality.extended;
      expect(q.wireModeByte, 0x04);
      expect(q.cApiMode, 5);
      expect(q.bytesPerFrame, 6);
      expect(q.samplesPerFrame, 320);
      expect(q.bitRate, 1200);
    });

    test('standard mode matches 2400 bps spec', () {
      const q = VoiceQuality.standard;
      expect(q.wireModeByte, 0x05);
      expect(q.cApiMode, 1);
      expect(q.bytesPerFrame, 6);
      expect(q.samplesPerFrame, 160);
      expect(q.bitRate, 2400);
    });

    test('high mode matches 3200 bps spec', () {
      const q = VoiceQuality.high;
      expect(q.wireModeByte, 0x06);
      expect(q.cApiMode, 0);
      expect(q.bytesPerFrame, 8);
      expect(q.samplesPerFrame, 160);
      expect(q.bitRate, 3200);
    });

    test('all modes fit within maxTransferSize', () {
      for (final q in VoiceQuality.values) {
        expect(
          q.maxPayloadBytes,
          lessThanOrEqualTo(VoiceConstants.maxTransferSize),
          reason: '${q.name} maxPayloadBytes exceeds transfer limit',
        );
      }
    });

    test('maxFrames computation is correct for all modes', () {
      for (final q in VoiceQuality.values) {
        final expected =
            (VoiceConstants.maxTransferSize - VoiceConstants.headerSize) ~/
            q.bytesPerFrame;
        expect(q.maxFrames, expected, reason: '${q.name} maxFrames');
      }
    });

    test('maxRecordingDuration is positive for all modes', () {
      for (final q in VoiceQuality.values) {
        expect(
          q.maxRecordingDuration.inSeconds,
          greaterThan(0),
          reason: '${q.name} duration',
        );
      }
    });

    test('higher bitrate means shorter max duration', () {
      expect(
        VoiceQuality.extended.maxRecordingDuration.inSeconds,
        greaterThan(VoiceQuality.standard.maxRecordingDuration.inSeconds),
      );
      expect(
        VoiceQuality.standard.maxRecordingDuration.inSeconds,
        greaterThan(VoiceQuality.high.maxRecordingDuration.inSeconds),
      );
    });

    test('fromWireModeByte resolves all known modes', () {
      expect(VoiceQuality.fromWireModeByte(0x04), VoiceQuality.extended);
      expect(VoiceQuality.fromWireModeByte(0x05), VoiceQuality.standard);
      expect(VoiceQuality.fromWireModeByte(0x06), VoiceQuality.high);
    });

    test('fromWireModeByte returns null for unknown bytes', () {
      expect(VoiceQuality.fromWireModeByte(0x00), isNull);
      expect(VoiceQuality.fromWireModeByte(0xFF), isNull);
    });

    test('prefsValue roundtrip works for all modes', () {
      for (final q in VoiceQuality.values) {
        expect(VoiceQuality.fromPrefsValue(q.prefsValue), q);
      }
    });

    test('fromPrefsValue defaults to defaultQuality for null or unknown', () {
      expect(VoiceQuality.fromPrefsValue(null), VoiceConstants.defaultQuality);
      expect(
        VoiceQuality.fromPrefsValue('unknown'),
        VoiceConstants.defaultQuality,
      );
    });

    test('wire mode bytes are unique', () {
      final wireBytes = VoiceQuality.values.map((q) => q.wireModeByte).toList();
      expect(wireBytes.toSet().length, wireBytes.length);
    });
  });
}
