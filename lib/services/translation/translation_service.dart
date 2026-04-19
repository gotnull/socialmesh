// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import 'google_translation_adapter.dart';
import 'translation_cache.dart';
import 'translation_models.dart';
import 'translation_policy_service.dart';

/// Shared translation service used by message translation, bug-report
/// translation, and any future translation consumers.
///
/// Supports caching, offline fallback, policy-aware persistence,
/// and pluggable adapters (managed or BYO).
class TranslationService {
  final TranslationAdapter adapter;
  final TranslationCache cache;
  final bool Function() isOnline;
  final TranslationPolicyService policyService;

  TranslationService({
    required this.adapter,
    required this.cache,
    required this.isOnline,
    TranslationPolicyService? policyService,
  }) : policyService = policyService ?? TranslationPolicyService();

  /// Translate a message, using the cache when available.
  ///
  /// - If cached and cache-read is permitted, returns immediately.
  /// - If offline with no cache hit, throws [TranslationError.offline].
  /// - If online, calls the adapter and caches per [shouldPersist].
  Future<TranslationResult> translateMessage({
    required String messageId,
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    TranslationPrivacyMode privacyMode = TranslationPrivacyMode.standard,
    bool isDm = false,
    String providerLabel = 'managed',
  }) async {
    final canReadCache = policyService.shouldReadCache(
      privacyMode: privacyMode,
    );

    // Check cache first (if permitted)
    if (canReadCache) {
      final cached = await cache.get(
        messageId: messageId,
        originalText: text,
        targetLanguage: targetLanguage,
      );
      if (cached != null) {
        AppLogging.app('TranslationService: cache hit for message $messageId');
        return cached;
      }
    }

    // No cache hit — need network
    if (!isOnline()) {
      throw const TranslationError(
        type: TranslationErrorType.offline,
        message: 'No internet connection',
      );
    }

    final request = TranslationRequest(
      text: text,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage,
    );

    final result = await adapter
        .translate(request)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const TranslationError(
            type: TranslationErrorType.apiError,
            message: 'Translation timed out', // lint-allow: hardcoded-string
          ),
        );

    // Persist to cache based on privacy policy
    final shouldPersist = policyService.shouldPersistToCache(
      privacyMode: privacyMode,
      isDm: isDm,
    );

    if (shouldPersist) {
      await cache.put(
        messageId: messageId,
        originalText: text,
        result: result,
        provider: providerLabel,
      );
    }

    AppLogging.app(
      'TranslationService: translated message $messageId '
      '(${result.detectedSourceLanguage ?? "?"} → $targetLanguage, '
      'persisted: $shouldPersist, provider: $providerLabel)',
    );

    return result;
  }
}
