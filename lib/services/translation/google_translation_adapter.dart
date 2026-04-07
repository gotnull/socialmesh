// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/logging.dart';
import '../../core/safety/error_handler.dart';
import 'translation_models.dart';

/// Abstract interface for translation adapters.
///
/// Allows swapping the concrete implementation (Cloud Function, REST, etc.)
/// and simplifies testing by avoiding Firebase dependencies.
abstract class TranslationAdapter {
  /// Translate [request.text] into [request.targetLanguage].
  ///
  /// Throws [TranslationError] on failure.
  Future<TranslationResult> translate(TranslationRequest request);

  /// Release any resources held by this adapter.
  void dispose();
}

/// Adapter for managed OpenAI translation via the `translateText` Cloud Function.
///
/// Delegates to the existing Firebase Cloud Function which handles the
/// OpenAI API call server-side with Application Default Credentials — no
/// client-side API key required.
class ManagedTranslationAdapter implements TranslationAdapter {
  final FirebaseFunctions _functions;

  /// Creates an adapter. Pass [functions] to inject a custom instance
  /// (e.g. for emulator usage in tests).
  ManagedTranslationAdapter({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    if (request.text.trim().isEmpty) {
      throw const TranslationError(
        type: TranslationErrorType.emptyInput,
        message: 'Text is empty', // lint-allow: hardcoded-string
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'translateText',
      ); // lint-allow: hardcoded-string
      final result = await callable.call<dynamic>({
        'text': request.text,
        'target': request.targetLanguage,
        if (request.sourceLanguage != null) 'source': request.sourceLanguage,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final translatedText = data['translatedText'] as String;
      final detected = data['detectedLanguage'] as String?;

      return TranslationResult(
        translatedText: translatedText,
        detectedSourceLanguage: detected,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );
    } on FirebaseFunctionsException catch (e, stack) {
      AppLogging.app(
        'Translation Cloud Function error: ${e.code} ${e.message}',
      );

      if (e.code == 'resource-exhausted') {
        // lint-allow: hardcoded-string
        throw const TranslationError(
          type: TranslationErrorType.rateLimited,
          message:
              'Translation rate limit exceeded', // lint-allow: hardcoded-string
        );
      }
      if (e.code == 'unauthenticated') {
        // lint-allow: hardcoded-string
        AppErrorHandler.reportError(
          e,
          stack,
          context: 'Translation auth error', // lint-allow: hardcoded-string
        );
        throw const TranslationError(
          type: TranslationErrorType.authenticationRequired,
          message:
              'Authentication required for translation', // lint-allow: hardcoded-string
        );
      }
      if (e.code == 'invalid-argument' &&
          (e.message?.contains('Unsupported language') ?? false)) {
        // lint-allow: hardcoded-string
        throw TranslationError(
          type: TranslationErrorType.unsupportedLanguage,
          message: e.message ?? e.code, // lint-allow: hardcoded-string
        );
      }

      // Report unexpected API errors to Crashlytics
      AppErrorHandler.reportError(
        e,
        stack,
        context:
            'Translation API error: ${e.code}', // lint-allow: hardcoded-string
      );
      throw TranslationError(
        type: TranslationErrorType.apiError,
        message: e.message ?? e.code, // lint-allow: hardcoded-string
      );
    } catch (e, stack) {
      AppLogging.app('Translation request failed: $e');
      AppErrorHandler.reportError(
        e,
        stack,
        context: 'Translation unexpected error', // lint-allow: hardcoded-string
      );
      throw TranslationError(
        type: TranslationErrorType.apiError,
        message: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    // No resources to release — FirebaseFunctions is managed by Firebase.
  }
}
