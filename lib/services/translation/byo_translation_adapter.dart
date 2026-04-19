// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logging.dart';
import 'google_translation_adapter.dart';
import 'translation_models.dart';

/// Configuration for OpenAI translation.
///
/// Defaults to `gpt-4o-mini` — the cheapest suitable model for
/// short, high-volume translation requests on mesh networks.
class OpenAiTranslationConfig {
  final String model;
  final String apiBaseUrl;

  const OpenAiTranslationConfig({
    this.model = 'gpt-4o-mini', // lint-allow: hardcoded-string
    this.apiBaseUrl = 'https://api.openai.com', // lint-allow: hardcoded-string
  });
}

/// Translation adapter using a user-supplied OpenAI API key.
///
/// Calls the OpenAI Chat Completions API directly without going through
/// Socialmesh Cloud Functions. The API key never leaves the device except
/// in the direct HTTPS call to OpenAI. The key is never logged or included
/// in analytics or crash reporting.
class OpenAiTranslationAdapter implements TranslationAdapter {
  final String apiKey;
  final http.Client _client;
  final OpenAiTranslationConfig config;

  OpenAiTranslationAdapter({
    required this.apiKey,
    this.config = const OpenAiTranslationConfig(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers(String key) => {
    'Content-Type': 'application/json', // lint-allow: hardcoded-string
    'Authorization': 'Bearer $key', // lint-allow: hardcoded-string
  };

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    if (request.text.trim().isEmpty) {
      throw const TranslationError(
        type: TranslationErrorType.emptyInput,
        message: 'Text is empty', // lint-allow: hardcoded-string
      );
    }

    try {
      final uri = Uri.parse(
        '${config.apiBaseUrl}/v1/chat/completions', // lint-allow: hardcoded-string
      );

      AppLogging.app(
        'OpenAI: POST $uri | model=${config.model} '
        'target=${request.targetLanguage} '
        'keyPrefix=${apiKey.length > 6 ? apiKey.substring(0, 6) : "short"}... '
        'keyLen=${apiKey.length}',
      );

      final systemPrompt = request.sourceLanguage != null
          ? 'Translate the following text from ${request.sourceLanguage} '
                'to ${request.targetLanguage}. '
                'If the text is already in ${request.targetLanguage}, return it exactly as-is. '
                'Respond with a JSON object: {"translation": "<translated text>", "detectedLanguage": "<ISO 639-1 code of the source language>"}.' // lint-allow: hardcoded-string
          : 'Translate the following text to ${request.targetLanguage}. '
                'If the text is already in ${request.targetLanguage}, return it exactly as-is. '
                'Respond with a JSON object: {"translation": "<translated text>", "detectedLanguage": "<ISO 639-1 code of the source language>"}.'; // lint-allow: hardcoded-string

      final body = {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': request.text},
        ],
        'temperature': 0.3,
        'max_tokens': 1024,
        'response_format': {'type': 'json_object'},
      };

      final response = await _client
          .post(uri, headers: _headers(apiKey), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      AppLogging.app(
        'OpenAI: response status=${response.statusCode} '
        'bodyLen=${response.body.length}',
      );

      if (response.statusCode == 401) {
        AppLogging.app(
          'OpenAI: 401 Unauthorized — response body: ${response.body}',
        );
        // Distinguish between invalid key and missing permissions
        final isMissingScope = response.body.contains(
          'missing_scope',
        ); // lint-allow: hardcoded-string
        throw TranslationError(
          type: TranslationErrorType.byoKeyMissing,
          message: isMissingScope
              ? 'API key missing required permissions — check scopes on platform.openai.com' // lint-allow: hardcoded-string
              : 'Invalid OpenAI API key', // lint-allow: hardcoded-string
        );
      }

      if (response.statusCode == 403) {
        AppLogging.app(
          'OpenAI: 403 Forbidden — response body: ${response.body}',
        );
        final isModelNotFound = response.body.contains(
          'model_not_found',
        ); // lint-allow: hardcoded-string
        throw TranslationError(
          type: TranslationErrorType.apiError,
          message: isModelNotFound
              ? 'Model ${config.model} not available for your project' // lint-allow: hardcoded-string
              : 'Access denied by OpenAI', // lint-allow: hardcoded-string
        );
      }

      if (response.statusCode == 429) {
        AppLogging.app('OpenAI: 429 Rate Limited — ${response.body}');
        throw const TranslationError(
          type: TranslationErrorType.rateLimited,
          message: 'Rate limit exceeded', // lint-allow: hardcoded-string
        );
      }

      if (response.statusCode != 200) {
        AppLogging.app(
          'OpenAI: unexpected ${response.statusCode} — ${response.body}',
        );
        throw TranslationError(
          type: TranslationErrorType.apiError,
          message:
              'API returned ${response.statusCode}', // lint-allow: hardcoded-string
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        AppLogging.app(
          'OpenAI: 200 but empty choices — full response: ${response.body}',
        );
        throw const TranslationError(
          type: TranslationErrorType.apiError,
          message: 'Empty response from OpenAI', // lint-allow: hardcoded-string
        );
      }

      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final content = (message['content'] as String).trim();

      // Parse JSON response for translation and detected language
      String translatedText;
      String? detectedLanguage;
      try {
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        translatedText =
            (parsed['translation'] as String?)?.trim() ??
            content; // lint-allow: hardcoded-string
        detectedLanguage =
            parsed['detectedLanguage']
                as String?; // lint-allow: hardcoded-string
      } catch (_) {
        // Fallback: if JSON parsing fails, treat entire content as translation
        translatedText = content;
      }

      AppLogging.app(
        'OpenAI: success — '
        '"${request.text}" → "$translatedText" '
        '(${request.targetLanguage}, detected=$detectedLanguage)',
      );

      return TranslationResult(
        translatedText: translatedText,
        detectedSourceLanguage: detectedLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );
    } on TranslationError {
      rethrow;
    } catch (e, stack) {
      AppLogging.app('OpenAI: unexpected exception: $e\n$stack');
      throw TranslationError(
        type: TranslationErrorType.apiError,
        message: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
