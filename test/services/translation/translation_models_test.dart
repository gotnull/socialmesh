// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/translation/translation_models.dart';

void main() {
  group('TranslationRequest', () {
    test('constructs with required fields', () {
      const req = TranslationRequest(text: 'hello', targetLanguage: 'es');
      expect(req.text, 'hello');
      expect(req.targetLanguage, 'es');
      expect(req.sourceLanguage, isNull);
    });

    test('constructs with optional sourceLanguage', () {
      const req = TranslationRequest(
        text: 'hello',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );
      expect(req.sourceLanguage, 'en');
    });
  });

  group('TranslationResult', () {
    final now = DateTime(2025, 6, 15, 12, 0, 0);

    test('constructs with required fields', () {
      final result = TranslationResult(
        translatedText: 'hola',
        targetLanguage: 'es',
        timestamp: now,
      );
      expect(result.translatedText, 'hola');
      expect(result.targetLanguage, 'es');
      expect(result.detectedSourceLanguage, isNull);
      expect(result.timestamp, now);
    });

    test('toJson produces correct map', () {
      final result = TranslationResult(
        translatedText: 'hola',
        detectedSourceLanguage: 'en',
        targetLanguage: 'es',
        timestamp: now,
      );
      final json = result.toJson();
      expect(json['translatedText'], 'hola');
      expect(json['detectedSourceLanguage'], 'en');
      expect(json['targetLanguage'], 'es');
      expect(json['timestamp'], now.toIso8601String());
    });

    test('fromJson round-trips correctly', () {
      final original = TranslationResult(
        translatedText: 'hola',
        detectedSourceLanguage: 'en',
        targetLanguage: 'es',
        timestamp: now,
      );
      final restored = TranslationResult.fromJson(original.toJson());
      expect(restored.translatedText, original.translatedText);
      expect(restored.detectedSourceLanguage, original.detectedSourceLanguage);
      expect(restored.targetLanguage, original.targetLanguage);
      expect(restored.timestamp, original.timestamp);
    });

    test('fromJson handles null detectedSourceLanguage', () {
      final json = {
        'translatedText': 'hola',
        'detectedSourceLanguage': null,
        'targetLanguage': 'es',
        'timestamp': now.toIso8601String(),
      };
      final result = TranslationResult.fromJson(json);
      expect(result.detectedSourceLanguage, isNull);
    });
  });

  group('TranslationError', () {
    test('implements Exception', () {
      const error = TranslationError(
        type: TranslationErrorType.offline,
        message: 'No connection',
      );
      expect(error, isA<Exception>());
    });

    test('toString includes type and message', () {
      const error = TranslationError(
        type: TranslationErrorType.apiError,
        message: 'Server error',
      );
      expect(error.toString(), contains('apiError'));
      expect(error.toString(), contains('Server error'));
    });
  });

  group('TranslationErrorType', () {
    test('has all expected values', () {
      expect(TranslationErrorType.values, hasLength(12));
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.offline),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.apiError),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.rateLimited),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.emptyInput),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.configurationError),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.authenticationRequired),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.unsupportedLanguage),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.quotaExhausted),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.privacyBlocked),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.providerDisabled),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.byoKeyMissing),
      );
      expect(
        TranslationErrorType.values,
        contains(TranslationErrorType.contentIneligible),
      );
    });
  });

  group('TranslationProviderMode', () {
    test('has expected values', () {
      expect(TranslationProviderMode.values, hasLength(3));
      expect(
        TranslationProviderMode.values,
        containsAll([
          TranslationProviderMode.managed,
          TranslationProviderMode.byo,
          TranslationProviderMode.disabled,
        ]),
      );
    });
  });

  group('TranslationPrivacyMode', () {
    test('has expected values', () {
      expect(TranslationPrivacyMode.values, hasLength(3));
      expect(
        TranslationPrivacyMode.values,
        containsAll([
          TranslationPrivacyMode.standard,
          TranslationPrivacyMode.private_,
          TranslationPrivacyMode.strict,
        ]),
      );
    });
  });

  group('TranslationQuotaState', () {
    test('defaultAllowance has expected values', () {
      final quota = TranslationQuotaState.defaultAllowance;
      expect(quota.usedChars, 0);
      expect(quota.charLimit, 500000);
      expect(quota.isExhausted, false);
      expect(quota.remaining, 500000);
    });

    test('isExhausted returns true when usedChars >= charLimit', () {
      final quota = TranslationQuotaState(
        usedChars: 500000,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
      expect(quota.isExhausted, true);
    });

    test('isExhausted returns true when usedChars exceeds charLimit', () {
      final quota = TranslationQuotaState(
        usedChars: 500001,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
      expect(quota.isExhausted, true);
    });

    test('remaining returns correct value', () {
      final quota = TranslationQuotaState(
        usedChars: 100000,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
      expect(quota.remaining, 400000);
    });

    test('remaining clamps to zero when over limit', () {
      final quota = TranslationQuotaState(
        usedChars: 600000,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
      expect(quota.remaining, 0);
    });

    test('resetsAt is 30 days from periodStart', () {
      final start = DateTime(2025, 7, 1);
      final quota = TranslationQuotaState(
        usedChars: 0,
        charLimit: 500000,
        periodStart: start,
      );
      expect(quota.resetsAt, DateTime(2025, 7, 31));
    });

    test('isPeriodExpired returns true for old period', () {
      final quota = TranslationQuotaState(
        usedChars: 0,
        charLimit: 500000,
        periodStart: DateTime.now().subtract(const Duration(days: 31)),
      );
      expect(quota.isPeriodExpired, true);
    });

    test('isPeriodExpired returns false for current period', () {
      final quota = TranslationQuotaState(
        usedChars: 0,
        charLimit: 500000,
        periodStart: DateTime.now(),
      );
      expect(quota.isPeriodExpired, false);
    });

    test('copyWith updates fields', () {
      final quota = TranslationQuotaState.defaultAllowance;
      final updated = quota.copyWith(usedChars: 50000);
      expect(updated.usedChars, 50000);
      expect(updated.charLimit, 500000);
    });

    test('toJson / fromJson round-trip', () {
      final start = DateTime(2025, 7, 1, 12, 0, 0);
      final quota = TranslationQuotaState(
        usedChars: 42000,
        charLimit: 500000,
        periodStart: start,
      );
      final json = quota.toJson();
      final restored = TranslationQuotaState.fromJson(json);
      expect(restored.usedChars, 42000);
      expect(restored.charLimit, 500000);
      expect(restored.periodStart, start);
    });

    test('fromJson handles missing fields with defaults', () {
      final restored = TranslationQuotaState.fromJson({});
      expect(restored.usedChars, 0);
      expect(restored.charLimit, 500000);
      expect(restored.periodStart, isNotNull);
    });

    test('fromJson migrates old count-based format', () {
      final restored = TranslationQuotaState.fromJson({
        'remaining': 450,
        'limit': 500,
      });
      expect(restored.usedChars, 0);
      expect(restored.charLimit, 500000);
      expect(restored.periodStart, isNotNull);
    });
  });

  group('TranslationPolicyDecision', () {
    test('has expected values', () {
      expect(TranslationPolicyDecision.values, hasLength(7));
    });
  });

  group('Unicode rune counting', () {
    test('ASCII text has same rune count as length', () {
      const text = 'Hello, world';
      expect(text.runes.length, text.length);
    });

    test('emoji counts as expected runes', () {
      const emoji = '😀';
      expect(emoji.runes.length, 1);
      expect(emoji.length, 2); // UTF-16 surrogate pair
    });

    test('mixed ASCII and emoji', () {
      const text = 'Hello 😀 World 🌍';
      // H,e,l,l,o, ,😀, ,W,o,r,l,d, ,🌍 = 15 runes
      expect(text.runes.length, 15);
    });

    test('CJK characters count as one rune each', () {
      const text = '你好世界';
      expect(text.runes.length, 4);
    });

    test('flag emoji (multi-code-point) counts correctly', () {
      const flag = '🇺🇸';
      // Flag is 2 regional indicator symbols = 2 runes
      expect(flag.runes.length, 2);
    });
  });
}
