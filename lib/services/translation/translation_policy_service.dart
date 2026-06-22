// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../core/logging.dart';
import '../../utils/emoji_text.dart';
import 'translation_models.dart';

/// Centralized policy engine for translation decisions.
///
/// Evaluates whether a given translation request should proceed based on
/// entitlement, provider mode, privacy mode, quota, and content eligibility.
class TranslationPolicyService {
  /// Maximum character length for a single translation request.
  static const int maxCharacterLength = 5000;

  /// Minimum text length worth translating.
  static const int minMeaningfulLength = 2;

  /// Evaluate whether translation is permitted for the given inputs.
  TranslationPolicyDecision evaluate({
    required bool hasEntitlement,
    required TranslationProviderMode providerMode,
    required TranslationPrivacyMode privacyMode,
    required TranslationQuotaState quotaState,
    required String text,
    required bool hasByoKey,
  }) {
    // 1. Entitlement check
    if (!hasEntitlement) {
      AppLogging.app('TranslationPolicy: denied — no entitlement');
      return TranslationPolicyDecision.noEntitlement;
    }

    // 2. Provider mode check
    if (providerMode == TranslationProviderMode.disabled) {
      AppLogging.app('TranslationPolicy: denied — provider disabled');
      return TranslationPolicyDecision.providerDisabled;
    }

    // 3. Content eligibility
    if (!isContentEligible(text)) {
      AppLogging.app('TranslationPolicy: denied — content ineligible');
      return TranslationPolicyDecision.contentIneligible;
    }

    // 4. Privacy mode: strict blocks managed provider
    if (privacyMode == TranslationPrivacyMode.strict &&
        providerMode == TranslationProviderMode.managed) {
      AppLogging.app(
        'TranslationPolicy: denied — strict privacy blocks managed provider',
      );
      return TranslationPolicyDecision.privacyBlocked;
    }

    // 5. BYO mode requires a valid key
    if (providerMode == TranslationProviderMode.byo && !hasByoKey) {
      AppLogging.app('TranslationPolicy: denied — BYO key missing');
      return TranslationPolicyDecision.byoKeyMissing;
    }

    // 6. Managed quota pre-flight check (rune-based for Unicode)
    if (providerMode == TranslationProviderMode.managed) {
      final newChars = text.runes.length;
      if (quotaState.usedChars + newChars > quotaState.charLimit) {
        AppLogging.app(
          'TranslationPolicy: denied — managed quota would exceed limit '
          '(${quotaState.usedChars} + $newChars > ${quotaState.charLimit})',
        );
        return TranslationPolicyDecision.quotaExhausted;
      }
    }

    return TranslationPolicyDecision.allowed;
  }

  /// Whether the translation result should be persisted to cache.
  bool shouldPersistToCache({
    required TranslationPrivacyMode privacyMode,
    required bool isDm,
  }) {
    switch (privacyMode) {
      case TranslationPrivacyMode.standard:
        return true;
      case TranslationPrivacyMode.private_:
        // Cache allowed for channels, not for DMs in private mode
        return !isDm;
      case TranslationPrivacyMode.strict:
        // No persistence in strict mode
        return false;
    }
  }

  /// Whether cached results may be read for this request.
  bool shouldReadCache({required TranslationPrivacyMode privacyMode}) {
    // Always allow reading cache — if it was stored, it was permitted at that time
    return privacyMode != TranslationPrivacyMode.strict;
  }

  /// Check if content is eligible for translation.
  static bool isContentEligible(String text) {
    final trimmed = text.trim();

    // Empty or whitespace-only
    if (trimmed.isEmpty) return false;

    // Too short to be meaningful
    if (trimmed.length < minMeaningfulLength) return false;

    // Too long
    if (trimmed.length > maxCharacterLength) return false;

    // URL-only content
    if (_isUrlOnly(trimmed)) return false;

    // Emoji-only content
    if (isEmojiOnly(trimmed)) return false;

    return true;
  }

  static bool _isUrlOnly(String text) {
    final urlPattern = RegExp(
      r'^(https?://\S+)(\s+(https?://\S+))*$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text.trim());
  }
}
