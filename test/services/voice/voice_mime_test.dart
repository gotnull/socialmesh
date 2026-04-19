// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/voice/voice_mime.dart';

void main() {
  group('VoiceMime.isVoiceMessage', () {
    test('returns true for audio/x-codec2', () {
      expect(VoiceMime.isVoiceMessage('audio/x-codec2'), isTrue);
    });

    test('returns false for null', () {
      expect(VoiceMime.isVoiceMessage(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(VoiceMime.isVoiceMessage(''), isFalse);
    });

    test('returns false for audio/mpeg', () {
      expect(VoiceMime.isVoiceMessage('audio/mpeg'), isFalse);
    });

    test('returns false for image/jpeg', () {
      expect(VoiceMime.isVoiceMessage('image/jpeg'), isFalse);
    });

    test('returns false for partial match', () {
      expect(VoiceMime.isVoiceMessage('audio/x-codec'), isFalse);
    });
  });

  group('VoiceMime.generateFilename', () {
    test('starts with voice_ prefix', () {
      final filename = VoiceMime.generateFilename();
      expect(filename, startsWith('voice_'));
    });

    test('ends with .c2 extension', () {
      final filename = VoiceMime.generateFilename();
      expect(filename, endsWith('.c2'));
    });

    test('contains numeric timestamp between prefix and extension', () {
      final filename = VoiceMime.generateFilename();
      // Format: voice_<timestamp>.c2
      final inner = filename.substring(
        'voice_'.length,
        filename.length - '.c2'.length,
      );
      expect(int.tryParse(inner), isNotNull);
    });

    test('two successive calls produce different filenames', () async {
      final a = VoiceMime.generateFilename();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = VoiceMime.generateFilename();
      expect(a, isNot(equals(b)));
    });
  });
}
