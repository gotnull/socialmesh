// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';

import '../models/subscription_models.dart';
import '../services/translation/byo_translation_adapter.dart';
import '../services/translation/google_translation_adapter.dart';
import '../services/translation/translation_cache.dart';
import '../services/translation/translation_key_repository.dart';
import '../services/translation/translation_models.dart';
import '../services/translation/translation_policy_service.dart';
import '../services/translation/translation_service.dart';
import 'connectivity_providers.dart';
import 'locale_provider.dart';
import 'subscription_providers.dart';

// =============================================================================
// Translation settings state
// =============================================================================

/// Translation settings — persisted via SharedPreferences.
class TranslationSettings {
  final TranslationProviderMode providerMode;
  final TranslationPrivacyMode privacyMode;

  const TranslationSettings({
    this.providerMode = TranslationProviderMode.managed,
    this.privacyMode = TranslationPrivacyMode.standard,
  });

  TranslationSettings copyWith({
    TranslationProviderMode? providerMode,
    TranslationPrivacyMode? privacyMode,
  }) {
    return TranslationSettings(
      providerMode: providerMode ?? this.providerMode,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'providerMode': providerMode.index,
    'privacyMode': privacyMode.index,
  };

  factory TranslationSettings.fromJson(Map<String, dynamic> json) {
    return TranslationSettings(
      providerMode:
          TranslationProviderMode.values[(json['providerMode'] as int?) ?? 0],
      privacyMode:
          TranslationPrivacyMode.values[(json['privacyMode'] as int?) ?? 0],
    );
  }
}

// =============================================================================
// Settings provider
// =============================================================================

class TranslationSettingsNotifier extends Notifier<TranslationSettings> {
  static const _prefsKey = 'translation_settings';

  @override
  TranslationSettings build() {
    _loadFromPrefs();
    return const TranslationSettings();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        if (ref.mounted) {
          state = TranslationSettings.fromJson(data);
        }
      }
    } catch (e) {
      AppLogging.app('TranslationSettings: failed to load — $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      AppLogging.app('TranslationSettings: failed to persist — $e');
    }
  }

  Future<void> setProviderMode(TranslationProviderMode mode) async {
    state = state.copyWith(providerMode: mode);
    await _persist();
  }

  Future<void> setPrivacyMode(TranslationPrivacyMode privacyMode) async {
    state = state.copyWith(privacyMode: privacyMode);
    await _persist();
  }
}

final translationSettingsProvider =
    NotifierProvider<TranslationSettingsNotifier, TranslationSettings>(
      TranslationSettingsNotifier.new,
    );

// =============================================================================
// Quota provider
// =============================================================================

class TranslationQuotaNotifier extends Notifier<TranslationQuotaState> {
  static const _prefsKey = 'translation_quota';

  @override
  TranslationQuotaState build() {
    _loadFromPrefs();
    return TranslationQuotaState.defaultAllowance;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        if (ref.mounted) {
          var loaded = TranslationQuotaState.fromJson(data);
          // Auto-reset if period has expired
          if (loaded.isPeriodExpired) {
            loaded = TranslationQuotaState(
              usedChars: 0,
              charLimit: loaded.charLimit,
              periodStart: DateTime.now(),
            );
          }
          state = loaded;
          await _persist();
        }
      }
    } catch (e) {
      AppLogging.app('TranslationQuota: failed to load — $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      AppLogging.app('TranslationQuota: failed to persist — $e');
    }
  }

  /// Check and reset quota if the 30-day period has expired.
  void _checkAndResetPeriod() {
    if (state.isPeriodExpired) {
      state = TranslationQuotaState(
        usedChars: 0,
        charLimit: state.charLimit,
        periodStart: DateTime.now(),
      );
    }
  }

  /// Record character usage after a successful managed translation.
  Future<void> recordUsage(int charCount) async {
    _checkAndResetPeriod();
    state = state.copyWith(usedChars: state.usedChars + charCount);
    await _persist();
  }

  /// Refresh quota from remote config or backend (future integration point).
  Future<void> refreshFromRemote(TranslationQuotaState newState) async {
    state = newState;
    await _persist();
  }
}

final translationQuotaProvider =
    NotifierProvider<TranslationQuotaNotifier, TranslationQuotaState>(
      TranslationQuotaNotifier.new,
    );

// =============================================================================
// BYO key state provider
// =============================================================================

class TranslationByoKeyNotifier extends Notifier<bool> {
  @override
  bool build() {
    _checkKey();
    return false;
  }

  Future<void> _checkKey() async {
    final repo = TranslationKeyRepository();
    final hasKey = await repo.hasKey();
    if (ref.mounted) state = hasKey;
  }

  /// Ensure the key state is fresh (awaitable, unlike build).
  Future<bool> ensureFresh() async {
    final repo = TranslationKeyRepository();
    final hasKey = await repo.hasKey();
    if (ref.mounted) state = hasKey;
    return hasKey;
  }

  /// Notify that the BYO key state may have changed.
  Future<void> refresh() async {
    await _checkKey();
  }
}

final translationByoKeyProvider =
    NotifierProvider<TranslationByoKeyNotifier, bool>(
      TranslationByoKeyNotifier.new,
    );

// =============================================================================
// Core service providers
// =============================================================================

/// Single shared [TranslationCache] instance.
final translationCacheProvider = FutureProvider<TranslationCache>((ref) async {
  final cache = TranslationCache();
  await cache.initialize();
  ref.onDispose(() => cache.close());
  return cache;
});

/// Single shared [ManagedTranslationAdapter] instance (managed mode).
final managedTranslationAdapterProvider = Provider<TranslationAdapter>((ref) {
  final adapter = ManagedTranslationAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});

/// Translation policy service instance.
final translationPolicyServiceProvider = Provider<TranslationPolicyService>((
  ref,
) {
  return TranslationPolicyService();
});

/// Whether the user has translation entitlement (Translation Pack or Complete Pack).
final translationEntitlementProvider = Provider<bool>((ref) {
  return ref.watch(hasFeatureProvider(PremiumFeature.translation));
});

/// Resolves the active [TranslationAdapter] based on provider mode and BYO key.
final activeTranslationAdapterProvider = FutureProvider<TranslationAdapter?>((
  ref,
) async {
  final settings = ref.watch(translationSettingsProvider);

  switch (settings.providerMode) {
    case TranslationProviderMode.managed:
      return ref.watch(managedTranslationAdapterProvider);
    case TranslationProviderMode.byo:
      final repo = TranslationKeyRepository();
      final key = await repo.readKey();
      if (key == null || key.isEmpty) return null;
      final adapter = OpenAiTranslationAdapter(apiKey: key);
      ref.onDispose(adapter.dispose);
      return adapter;
    case TranslationProviderMode.disabled:
      return null;
  }
});

/// Single shared [TranslationService] — the main entry point for translation.
final translationServiceProvider = FutureProvider<TranslationService?>((
  ref,
) async {
  final cache = await ref.watch(translationCacheProvider.future);
  final adapter = await ref.watch(activeTranslationAdapterProvider.future);
  final policyService = ref.watch(translationPolicyServiceProvider);

  if (adapter == null) return null;

  return TranslationService(
    adapter: adapter,
    cache: cache,
    isOnline: () => ref.read(isOnlineProvider),
    policyService: policyService,
  );
});

/// Resolve the target language for translation.
///
/// Uses the user's preferred locale if set, otherwise the device locale.
final translationTargetLanguageProvider = Provider<String>((ref) {
  final userLocale = ref.watch(localeProvider);
  if (userLocale != null) return userLocale.languageCode;
  // Fall back to device locale
  return PlatformDispatcher.instance.locale.languageCode;
});

// =============================================================================
// Per-message translation state
// =============================================================================

/// Per-message translation state, keyed by message ID.
///
/// This is an in-memory map so that translating one message does not
/// cause unrelated messages to rebuild.
class MessageTranslationState {
  final bool isLoading;
  final TranslationResult? result;
  final TranslationError? error;

  const MessageTranslationState({
    this.isLoading = false,
    this.result,
    this.error,
  });

  MessageTranslationState copyWith({
    bool? isLoading,
    TranslationResult? result,
    TranslationError? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return MessageTranslationState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier managing per-message translation states.
class MessageTranslationsNotifier
    extends Notifier<Map<String, MessageTranslationState>> {
  @override
  Map<String, MessageTranslationState> build() => {};

  /// Translate a message through the centralized policy pipeline.
  ///
  /// Enforces entitlement, provider mode, privacy mode, quota, and content
  /// eligibility checks before calling the translation adapter.
  Future<void> translate({
    required String messageId,
    required String text,
    bool isDm = false,
  }) async {
    final existing = state[messageId];
    if (existing != null && (existing.isLoading || existing.result != null)) {
      return;
    }

    // 0. Check disk cache first — restores translations after app restart
    //    without needing entitlement/key/quota checks.
    final settings = ref.read(translationSettingsProvider);
    final policyService = ref.read(translationPolicyServiceProvider);
    if (policyService.shouldReadCache(privacyMode: settings.privacyMode)) {
      try {
        final cache = await ref.read(translationCacheProvider.future);
        final targetLang = ref.read(translationTargetLanguageProvider);
        final cached = await cache.get(
          messageId: messageId,
          originalText: text,
          targetLanguage: targetLang,
        );
        if (cached != null) {
          // Skip if detected source language matches target or text unchanged
          final cachedSameLanguage =
              (cached.detectedSourceLanguage != null &&
                  cached.detectedSourceLanguage!.toLowerCase() ==
                      targetLang.toLowerCase()) ||
              cached.translatedText.trim().toLowerCase() ==
                  text.trim().toLowerCase();
          if (cachedSameLanguage) {
            return;
          }
          if (!ref.mounted) return;
          state = {
            ...state,
            messageId: MessageTranslationState(result: cached),
          };
          return;
        }
      } catch (_) {
        // Cache miss or init error — fall through to normal flow
      }
    }

    // 1. Check entitlement — await the subscription service directly to avoid
    //    the race where purchaseStateProvider hasn't received _init() yet.
    final purchaseService = await ref.read(subscriptionServiceProvider.future);
    final hasEntitlement = purchaseService.currentState.hasFeature(
      PremiumFeature.translation,
    );

    // 2. Read remaining settings
    final quotaState = ref.read(translationQuotaProvider);
    // Await fresh key state to avoid race on cold start
    final hasByoKey = await ref
        .read(translationByoKeyProvider.notifier)
        .ensureFresh();

    // 3. Evaluate policy
    final decision = policyService.evaluate(
      hasEntitlement: hasEntitlement,
      providerMode: settings.providerMode,
      privacyMode: settings.privacyMode,
      quotaState: quotaState,
      text: text,
      hasByoKey: hasByoKey,
    );

    if (decision != TranslationPolicyDecision.allowed) {
      state = {
        ...state,
        messageId: MessageTranslationState(
          error: TranslationError(
            type: _policyDecisionToErrorType(decision),
            message: _policyDecisionMessage(decision),
          ),
        ),
      };
      return;
    }

    // Set loading
    state = {
      ...state,
      messageId: const MessageTranslationState(isLoading: true),
    };

    try {
      final service = await ref.read(translationServiceProvider.future);
      if (service == null) {
        if (!ref.mounted) return;
        state = {
          ...state,
          messageId: const MessageTranslationState(
            error: TranslationError(
              type: TranslationErrorType.providerDisabled,
              message:
                  'No translation provider available', // lint-allow: hardcoded-string
            ),
          ),
        };
        return;
      }

      final targetLang = ref.read(translationTargetLanguageProvider);
      final providerLabel = settings.providerMode == TranslationProviderMode.byo
          ? 'byo'
          : 'managed';

      final result = await service.translateMessage(
        messageId: messageId,
        text: text,
        targetLanguage: targetLang,
        privacyMode: settings.privacyMode,
        isDm: isDm,
        providerLabel: providerLabel,
      );

      // Same-language detection: skip if the source language matches the
      // target, or if the translated text is identical to the original.
      final isSameLanguage =
          (result.detectedSourceLanguage != null &&
              result.detectedSourceLanguage!.toLowerCase() ==
                  targetLang.toLowerCase()) ||
          result.translatedText.trim().toLowerCase() ==
              text.trim().toLowerCase();
      if (isSameLanguage) {
        AppLogging.app(
          'Translation skipped for $messageId: '
          'text already in target language ($targetLang)',
        );
        if (!ref.mounted) return;
        state = Map<String, MessageTranslationState>.from(state)
          ..remove(messageId);
        return;
      }

      // Record managed character usage on success (rune-based for Unicode)
      if (settings.providerMode == TranslationProviderMode.managed) {
        ref
            .read(translationQuotaProvider.notifier)
            .recordUsage(text.runes.length);
      }

      if (!ref.mounted) return;

      state = {...state, messageId: MessageTranslationState(result: result)};
    } on TranslationError catch (e) {
      AppLogging.app(
        'Translation failed for $messageId: ${e.type.name} — ${e.message}',
      );
      if (!ref.mounted) return;
      state = {...state, messageId: MessageTranslationState(error: e)};
    } catch (e) {
      AppLogging.app('Translation unexpected error for $messageId: $e');
      if (!ref.mounted) return;
      state = {
        ...state,
        messageId: MessageTranslationState(
          error: TranslationError(
            type: TranslationErrorType.apiError,
            message: e.toString(),
          ),
        ),
      };
    }
  }

  /// Retry a failed translation.
  Future<void> retry({
    required String messageId,
    required String text,
    bool isDm = false,
  }) async {
    // Clear error and retry
    final newState = Map<String, MessageTranslationState>.from(state);
    newState.remove(messageId);
    state = newState;
    await translate(messageId: messageId, text: text, isDm: isDm);
  }

  /// Clear translation state for a message (e.g. if user dismisses it).
  void clear(String messageId) {
    final newState = Map<String, MessageTranslationState>.from(state);
    newState.remove(messageId);
    state = newState;
  }

  /// Restore a cached translation for a message (e.g. on app restart or
  /// when the same text is sent again via dedupe cache lookup).
  ///
  /// Called by the messaging screen for each visible message. No-op if the
  /// message already has in-memory state (loading, result, or error).
  Future<void> restoreFromCache({
    required String messageId,
    required String text,
  }) async {
    if (state.containsKey(messageId)) return;

    final settings = ref.read(translationSettingsProvider);
    final policyService = ref.read(translationPolicyServiceProvider);
    if (!policyService.shouldReadCache(privacyMode: settings.privacyMode)) {
      return;
    }

    try {
      final cache = await ref.read(translationCacheProvider.future);
      final targetLang = ref.read(translationTargetLanguageProvider);
      final cached = await cache.get(
        messageId: messageId,
        originalText: text,
        targetLanguage: targetLang,
      );
      if (cached != null && ref.mounted) {
        // Same-language detection: skip if the cached result's source
        // language matches the target, or if the translated text is
        // identical to the original.
        final isSameLanguage =
            (cached.detectedSourceLanguage != null &&
                cached.detectedSourceLanguage!.toLowerCase() ==
                    targetLang.toLowerCase()) ||
            cached.translatedText.trim().toLowerCase() ==
                text.trim().toLowerCase();
        if (isSameLanguage) return;
        state = {...state, messageId: MessageTranslationState(result: cached)};
      }
    } catch (_) {
      // Silently ignore — cache miss or init failure
    }
  }

  static TranslationErrorType _policyDecisionToErrorType(
    TranslationPolicyDecision decision,
  ) {
    switch (decision) {
      case TranslationPolicyDecision.noEntitlement:
        return TranslationErrorType.configurationError;
      case TranslationPolicyDecision.quotaExhausted:
        return TranslationErrorType.quotaExhausted;
      case TranslationPolicyDecision.privacyBlocked:
        return TranslationErrorType.privacyBlocked;
      case TranslationPolicyDecision.providerDisabled:
        return TranslationErrorType.providerDisabled;
      case TranslationPolicyDecision.contentIneligible:
        return TranslationErrorType.contentIneligible;
      case TranslationPolicyDecision.byoKeyMissing:
        return TranslationErrorType.byoKeyMissing;
      case TranslationPolicyDecision.allowed:
        return TranslationErrorType.apiError;
    }
  }

  static String _policyDecisionMessage(TranslationPolicyDecision decision) {
    switch (decision) {
      case TranslationPolicyDecision.noEntitlement:
        return 'Translation Pack required'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.quotaExhausted:
        return 'Managed allowance exhausted'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.privacyBlocked:
        return 'Strict privacy mode blocks managed translation'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.providerDisabled:
        return 'Translation provider is disabled'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.contentIneligible:
        return 'Content not eligible for translation'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.byoKeyMissing:
        return 'BYO API key required'; // lint-allow: hardcoded-string
      case TranslationPolicyDecision.allowed:
        return ''; // lint-allow: hardcoded-string
    }
  }
}

final messageTranslationsProvider =
    NotifierProvider<
      MessageTranslationsNotifier,
      Map<String, MessageTranslationState>
    >(MessageTranslationsNotifier.new);

/// Convenience provider for a single message's translation state.
final messageTranslationProvider =
    Provider.family<MessageTranslationState?, String>((ref, messageId) {
      return ref.watch(messageTranslationsProvider)[messageId];
    });
