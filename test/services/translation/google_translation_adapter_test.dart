// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/translation/google_translation_adapter.dart';
import 'package:socialmesh/services/translation/translation_models.dart';

/// Minimal adapter for testing input validation without Firebase.
class _TestTranslationAdapter implements TranslationAdapter {
  int callCount = 0;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    if (request.text.trim().isEmpty) {
      throw const TranslationError(
        type: TranslationErrorType.emptyInput,
        message: 'Text is empty', // lint-allow: hardcoded-string
      );
    }
    callCount++;
    return TranslationResult(
      translatedText: 'translated',
      targetLanguage: request.targetLanguage,
      timestamp: DateTime(2025, 6, 15),
    );
  }

  @override
  void dispose() {}
}

void main() {
  group('TranslationAdapter', () {
    late _TestTranslationAdapter adapter;

    setUp(() {
      adapter = _TestTranslationAdapter();
    });

    test('throws TranslationError for empty text', () async {
      expect(
        () => adapter.translate(
          const TranslationRequest(text: '  ', targetLanguage: 'es'),
        ),
        throwsA(
          isA<TranslationError>().having(
            (e) => e.type,
            'type',
            TranslationErrorType.emptyInput,
          ),
        ),
      );
    });

    test('throws TranslationError for whitespace-only text', () async {
      expect(
        () => adapter.translate(
          const TranslationRequest(text: '\t\n  ', targetLanguage: 'es'),
        ),
        throwsA(
          isA<TranslationError>().having(
            (e) => e.type,
            'type',
            TranslationErrorType.emptyInput,
          ),
        ),
      );
    });

    test('successful translation increments call count', () async {
      final result = await adapter.translate(
        const TranslationRequest(text: 'hello', targetLanguage: 'es'),
      );

      expect(result.translatedText, 'translated');
      expect(result.targetLanguage, 'es');
      expect(adapter.callCount, 1);
    });

    // Note: Integration tests for ManagedTranslationAdapter (Cloud Function)
    // require Firebase initialization — covered by integration test suite.
  });
}
