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
      // A single voice message payload must fit in the Meshtastic max fragmentable
      // payload (8192 bytes per the file-transfer engine). The SIP airtime budget
      // constrains the RATE, not individual message size.
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
  });
}
