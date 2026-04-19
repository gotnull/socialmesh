// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/providers/translation_providers.dart';
import 'package:socialmesh/services/translation/translation_models.dart';

void main() {
  group('MessageTranslationState', () {
    test('default state has no loading, result, or error', () {
      const state = MessageTranslationState();
      expect(state.isLoading, false);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('copyWith updates fields', () {
      const state = MessageTranslationState();

      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, true);
      expect(loading.result, isNull);

      final result = TranslationResult(
        translatedText: 'hola',
        targetLanguage: 'es',
        timestamp: DateTime(2025, 6, 15),
      );
      final withResult = state.copyWith(result: result);
      expect(withResult.result, isNotNull);
      expect(withResult.result!.translatedText, 'hola');
    });

    test('copyWith clearError removes error', () {
      final state = MessageTranslationState(
        error: const TranslationError(
          type: TranslationErrorType.offline,
          message: 'No connection',
        ),
      );

      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearResult removes result', () {
      final state = MessageTranslationState(
        result: TranslationResult(
          translatedText: 'hola',
          targetLanguage: 'es',
          timestamp: DateTime(2025, 6, 15),
        ),
      );

      final cleared = state.copyWith(clearResult: true);
      expect(cleared.result, isNull);
    });
  });
}
