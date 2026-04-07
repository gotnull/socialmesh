// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/translation/translation_models.dart';
import 'package:socialmesh/services/translation/translation_policy_service.dart';

void main() {
  late TranslationPolicyService service;

  setUp(() {
    service = TranslationPolicyService();
  });

  group('TranslationPolicyService.evaluate', () {
    TranslationPolicyDecision eval({
      bool hasEntitlement = true,
      TranslationProviderMode providerMode = TranslationProviderMode.managed,
      TranslationPrivacyMode privacyMode = TranslationPrivacyMode.standard,
      TranslationQuotaState? quotaState,
      String text = 'Hello, world',
      bool hasByoKey = false,
    }) {
      return service.evaluate(
        hasEntitlement: hasEntitlement,
        providerMode: providerMode,
        privacyMode: privacyMode,
        quotaState: quotaState ?? TranslationQuotaState.defaultAllowance,
        text: text,
        hasByoKey: hasByoKey,
      );
    }

    test('allows managed translation with entitlement and quota', () {
      expect(eval(), TranslationPolicyDecision.allowed);
    });

    test('denies without entitlement', () {
      expect(
        eval(hasEntitlement: false),
        TranslationPolicyDecision.noEntitlement,
      );
    });

    test('denies when provider is disabled', () {
      expect(
        eval(providerMode: TranslationProviderMode.disabled),
        TranslationPolicyDecision.providerDisabled,
      );
    });

    test('denies content-ineligible text (too short)', () {
      expect(eval(text: 'a'), TranslationPolicyDecision.contentIneligible);
    });

    test('denies content-ineligible text (empty)', () {
      expect(eval(text: '   '), TranslationPolicyDecision.contentIneligible);
    });

    test('denies content-ineligible text (URL-only)', () {
      expect(
        eval(text: 'https://example.com'),
        TranslationPolicyDecision.contentIneligible,
      );
    });

    test('denies strict privacy + managed provider', () {
      expect(
        eval(privacyMode: TranslationPrivacyMode.strict),
        TranslationPolicyDecision.privacyBlocked,
      );
    });

    test('allows strict privacy + BYO provider with key', () {
      expect(
        eval(
          privacyMode: TranslationPrivacyMode.strict,
          providerMode: TranslationProviderMode.byo,
          hasByoKey: true,
        ),
        TranslationPolicyDecision.allowed,
      );
    });

    test('denies BYO mode without key', () {
      expect(
        eval(providerMode: TranslationProviderMode.byo, hasByoKey: false),
        TranslationPolicyDecision.byoKeyMissing,
      );
    });

    test('allows BYO mode with key', () {
      expect(
        eval(providerMode: TranslationProviderMode.byo, hasByoKey: true),
        TranslationPolicyDecision.allowed,
      );
    });

    test('denies managed mode when quota exhausted', () {
      expect(
        eval(
          quotaState: TranslationQuotaState(
            usedChars: 500000,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.quotaExhausted,
      );
    });

    test('allows managed mode when quota has remaining', () {
      expect(
        eval(
          quotaState: TranslationQuotaState(
            usedChars: 1000,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.allowed,
      );
    });

    test('BYO mode ignores managed quota', () {
      expect(
        eval(
          providerMode: TranslationProviderMode.byo,
          hasByoKey: true,
          quotaState: TranslationQuotaState(
            usedChars: 500000,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.allowed,
      );
    });

    test('private privacy mode allows managed provider', () {
      expect(
        eval(privacyMode: TranslationPrivacyMode.private_),
        TranslationPolicyDecision.allowed,
      );
    });

    test('denies when text would push usage over limit (pre-flight)', () {
      // 499_990 used, text has 20 runes → 500_010 > 500_000
      expect(
        eval(
          text: 'a' * 20,
          quotaState: TranslationQuotaState(
            usedChars: 499990,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.quotaExhausted,
      );
    });

    test('allows when text fits exactly within remaining quota', () {
      // 499_990 used, text has 10 runes → 500_000 = 500_000 (fits exactly)
      expect(
        eval(
          text: 'a' * 10,
          quotaState: TranslationQuotaState(
            usedChars: 499990,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.allowed,
      );
    });

    test('counts emoji runes correctly for quota check', () {
      // Each emoji is 1 rune but 2 UTF-16 code units (surrogate pair).
      // 'Hi 😀😀😀😀😀' = 3 ASCII + 5 emoji = 8 runes (but .length == 13).
      // Mix text + emoji so it passes content eligibility.
      const mixed = 'Hi 😀😀😀😀😀'; // 8 runes
      expect(mixed.runes.length, 8);
      expect(
        eval(
          text: mixed,
          quotaState: TranslationQuotaState(
            usedChars: 499993,
            charLimit: 500000,
            periodStart: DateTime.now(),
          ),
        ),
        TranslationPolicyDecision.quotaExhausted,
      );
      // 499_993 + 8 = 500_001 > 500_000 → exhausted
    });
  });

  group('TranslationPolicyService.shouldPersistToCache', () {
    test('standard mode always persists', () {
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.standard,
          isDm: false,
        ),
        true,
      );
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.standard,
          isDm: true,
        ),
        true,
      );
    });

    test('private mode persists channels but not DMs', () {
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.private_,
          isDm: false,
        ),
        true,
      );
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.private_,
          isDm: true,
        ),
        false,
      );
    });

    test('strict mode never persists', () {
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.strict,
          isDm: false,
        ),
        false,
      );
      expect(
        service.shouldPersistToCache(
          privacyMode: TranslationPrivacyMode.strict,
          isDm: true,
        ),
        false,
      );
    });
  });

  group('TranslationPolicyService.shouldReadCache', () {
    test('standard allows cache read', () {
      expect(
        service.shouldReadCache(privacyMode: TranslationPrivacyMode.standard),
        true,
      );
    });

    test('private allows cache read', () {
      expect(
        service.shouldReadCache(privacyMode: TranslationPrivacyMode.private_),
        true,
      );
    });

    test('strict denies cache read', () {
      expect(
        service.shouldReadCache(privacyMode: TranslationPrivacyMode.strict),
        false,
      );
    });
  });

  group('TranslationPolicyService.isContentEligible', () {
    test('accepts normal text', () {
      expect(TranslationPolicyService.isContentEligible('Hello world'), true);
    });

    test('rejects empty text', () {
      expect(TranslationPolicyService.isContentEligible(''), false);
    });

    test('rejects whitespace-only', () {
      expect(TranslationPolicyService.isContentEligible('   '), false);
    });

    test('rejects single character', () {
      expect(TranslationPolicyService.isContentEligible('a'), false);
    });

    test('accepts two characters', () {
      expect(TranslationPolicyService.isContentEligible('hi'), true);
    });

    test('rejects text exceeding max length', () {
      final longText = 'a' * 5001;
      expect(TranslationPolicyService.isContentEligible(longText), false);
    });

    test('accepts text at max length', () {
      final maxText = 'a' * 5000;
      expect(TranslationPolicyService.isContentEligible(maxText), true);
    });

    test('rejects URL-only content', () {
      expect(
        TranslationPolicyService.isContentEligible('https://example.com'),
        false,
      );
    });

    test('accepts URL mixed with text', () {
      expect(
        TranslationPolicyService.isContentEligible(
          'Visit https://example.com for details',
        ),
        true,
      );
    });

    test('rejects emoji-only content', () {
      expect(TranslationPolicyService.isContentEligible('😀👍🎉'), false);
    });

    test('accepts mixed emoji and text', () {
      expect(TranslationPolicyService.isContentEligible('Hello 😀'), true);
    });
  });
}
