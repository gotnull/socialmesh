// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// The active translation provider mode.
enum TranslationProviderMode {
  /// SocialMesh-managed Cloud Function backend (default).
  managed,

  /// User supplies their own API key for direct provider calls.
  byo,

  /// Translation disabled entirely.
  disabled,
}

/// Privacy mode controlling translation data handling.
enum TranslationPrivacyMode {
  /// Managed provider allowed, local cache allowed.
  standard,

  /// Managed provider allowed, local cache only, tighter DM rules.
  private_,

  /// Managed provider disabled — BYO only, no shared persistence.
  strict,
}

/// State of the managed translation character quota with 30-day rolling window.
class TranslationQuotaState {
  /// Characters used in the current 30-day period.
  final int usedChars;

  /// Maximum characters allowed per 30-day period.
  final int charLimit;

  /// When the current 30-day period started.
  final DateTime periodStart;

  const TranslationQuotaState({
    required this.usedChars,
    required this.charLimit,
    required this.periodStart,
  });

  /// Remaining characters in the current period.
  int get remaining => (charLimit - usedChars).clamp(0, charLimit);

  bool get isExhausted => usedChars >= charLimit;

  /// When the current period expires (30 days from start).
  DateTime get resetsAt => periodStart.add(const Duration(days: 30));

  /// Whether the current period has expired and should be reset.
  bool get isPeriodExpired => DateTime.now().isAfter(resetsAt);

  /// Default generous character allowance for initial rollout.
  /// 500K characters ≈ ~500 typical message translations.
  static TranslationQuotaState get defaultAllowance => TranslationQuotaState(
    usedChars: 0,
    charLimit: 500000,
    periodStart: DateTime.now(),
  );

  TranslationQuotaState copyWith({
    int? usedChars,
    int? charLimit,
    DateTime? periodStart,
  }) {
    return TranslationQuotaState(
      usedChars: usedChars ?? this.usedChars,
      charLimit: charLimit ?? this.charLimit,
      periodStart: periodStart ?? this.periodStart,
    );
  }

  Map<String, dynamic> toJson() => {
    'usedChars': usedChars,
    'charLimit': charLimit,
    'periodStart': periodStart.toIso8601String(),
  };

  factory TranslationQuotaState.fromJson(Map<String, dynamic> json) {
    // Migration from old count-based format
    if (json.containsKey('remaining')) {
      return TranslationQuotaState(
        usedChars: 0,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
    }
    return TranslationQuotaState(
      usedChars: json['usedChars'] as int? ?? 0,
      charLimit: json['charLimit'] as int? ?? 500000,
      periodStart: json['periodStart'] != null
          ? DateTime.parse(json['periodStart'] as String)
          : DateTime.now(),
    );
  }
}

/// Outcome of a translation policy evaluation.
enum TranslationPolicyDecision {
  /// Translation is allowed.
  allowed,

  /// User lacks translation entitlement.
  noEntitlement,

  /// Managed quota exhausted — suggest BYO.
  quotaExhausted,

  /// Privacy mode blocks managed provider.
  privacyBlocked,

  /// Provider mode is disabled.
  providerDisabled,

  /// Content is not eligible for translation.
  contentIneligible,

  /// BYO key is missing or invalid.
  byoKeyMissing,
}

/// Request to translate text.
class TranslationRequest {
  final String text;
  final String targetLanguage;
  final String? sourceLanguage;

  const TranslationRequest({
    required this.text,
    required this.targetLanguage,
    this.sourceLanguage,
  });
}

/// Result of a translation operation.
class TranslationResult {
  final String translatedText;
  final String? detectedSourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  const TranslationResult({
    required this.translatedText,
    this.detectedSourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'translatedText': translatedText,
    'detectedSourceLanguage': detectedSourceLanguage,
    'targetLanguage': targetLanguage,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      translatedText: json['translatedText'] as String,
      detectedSourceLanguage: json['detectedSourceLanguage'] as String?,
      targetLanguage: json['targetLanguage'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Error types for translation operations.
enum TranslationErrorType {
  offline,
  apiError,
  rateLimited,
  emptyInput,
  configurationError,
  authenticationRequired,
  unsupportedLanguage,
  quotaExhausted,
  privacyBlocked,
  providerDisabled,
  byoKeyMissing,
  contentIneligible,
}

/// Domain error for translation failures.
class TranslationError implements Exception {
  final TranslationErrorType type;
  final String message;

  const TranslationError({required this.type, required this.message});

  @override
  String toString() => 'TranslationError($type): $message';
}
