// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/translation/google_translation_adapter.dart';
import 'package:socialmesh/services/translation/translation_cache.dart';
import 'package:socialmesh/services/translation/translation_models.dart';
import 'package:socialmesh/services/translation/translation_service.dart';

/// Fake adapter that returns a fixed result without Firebase.
class _FakeTranslationAdapter implements TranslationAdapter {
  int callCount = 0;
  TranslationRequest? lastRequest;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    // Preserve empty-text validation from real adapter
    if (request.text.trim().isEmpty) {
      throw const TranslationError(
        type: TranslationErrorType.emptyInput,
        message: 'Text is empty',
      );
    }
    callCount++;
    lastRequest = request;
    return TranslationResult(
      translatedText: 'hola',
      detectedSourceLanguage: 'en',
      targetLanguage: request.targetLanguage,
      timestamp: DateTime(2025, 6, 15, 12, 0, 0),
    );
  }

  @override
  void dispose() {}
}

/// Adapter that always exceeds the 10-second timeout.
class _SlowTranslationAdapter implements TranslationAdapter {
  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    await Future.delayed(const Duration(seconds: 30));
    return TranslationResult(
      translatedText: 'slow',
      targetLanguage: request.targetLanguage,
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TranslationService service;
  late TranslationCache cache;
  late _FakeTranslationAdapter adapter;
  bool isOnline = true;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    isOnline = true;

    cache = TranslationCache(testDbPath: inMemoryDatabasePath);
    await cache.initialize();

    adapter = _FakeTranslationAdapter();

    service = TranslationService(
      adapter: adapter,
      cache: cache,
      isOnline: () => isOnline,
    );
  });

  tearDown(() async {
    await cache.close();
  });

  group('TranslationService.translateMessage', () {
    test('translates and caches result on cache miss', () async {
      final result = await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
      );

      expect(result.translatedText, 'hola');
      expect(result.detectedSourceLanguage, 'en');
      expect(adapter.callCount, 1);

      // Verify it was cached
      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      expect(cached, isNotNull);
      expect(cached!.translatedText, 'hola');
    });

    test('returns cached result without adapter call', () async {
      // First call populates cache
      await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
      );
      expect(adapter.callCount, 1);

      // Second call should hit cache
      final result = await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
      );

      expect(result.translatedText, 'hola');
      expect(adapter.callCount, 1); // No additional call
    });

    test('throws offline error when no cache and offline', () async {
      isOnline = false;

      expect(
        () => service.translateMessage(
          messageId: 'msg-1',
          text: 'hello',
          targetLanguage: 'es',
        ),
        throwsA(
          isA<TranslationError>().having(
            (e) => e.type,
            'type',
            TranslationErrorType.offline,
          ),
        ),
      );
    });

    test('returns cached result even when offline', () async {
      // Populate cache while online
      await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
      );

      // Go offline
      isOnline = false;

      // Should still return cached result
      final result = await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
      );

      expect(result.translatedText, 'hola');
      expect(adapter.callCount, 1); // Only the initial call
    });

    test('passes sourceLanguage to adapter', () async {
      await service.translateMessage(
        messageId: 'msg-1',
        text: 'hello',
        targetLanguage: 'es',
        sourceLanguage: 'en',
      );

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.sourceLanguage, 'en');
    });
  });

  group('TranslationService timeout', () {
    test('throws on adapter timeout', () async {
      final slowAdapter = _SlowTranslationAdapter();
      final slowService = TranslationService(
        adapter: slowAdapter,
        cache: cache,
        isOnline: () => true,
      );

      expect(
        () => slowService.translateMessage(
          messageId: 'slow-1',
          text: 'hello',
          targetLanguage: 'es',
        ),
        throwsA(
          isA<TranslationError>().having(
            (e) => e.type,
            'type',
            TranslationErrorType.apiError,
          ),
        ),
      );
    });
  });

  group('TranslationService privacy enforcement', () {
    test('does not cache DM translations in private mode', () async {
      final result = await service.translateMessage(
        messageId: 'dm-1',
        text: 'hello',
        targetLanguage: 'es',
        privacyMode: TranslationPrivacyMode.private_,
        isDm: true,
      );

      expect(result.translatedText, 'hola');
      expect(adapter.callCount, 1);

      // Verify NOT cached
      final cached = await cache.get(
        messageId: 'dm-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      expect(cached, isNull);
    });

    test('caches channel translations in private mode', () async {
      await service.translateMessage(
        messageId: 'ch-1',
        text: 'hello',
        targetLanguage: 'es',
        privacyMode: TranslationPrivacyMode.private_,
        isDm: false,
      );

      expect(adapter.callCount, 1);

      final cached = await cache.get(
        messageId: 'ch-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      expect(cached, isNotNull);
    });

    test('does not cache or read cache in strict mode', () async {
      await service.translateMessage(
        messageId: 'strict-1',
        text: 'hello',
        targetLanguage: 'es',
        privacyMode: TranslationPrivacyMode.strict,
        isDm: false,
      );

      expect(adapter.callCount, 1);

      // Verify NOT cached
      final cached = await cache.get(
        messageId: 'strict-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      expect(cached, isNull);

      // Second call should NOT read cache (even if it existed)
      await service.translateMessage(
        messageId: 'strict-1',
        text: 'hello',
        targetLanguage: 'es',
        privacyMode: TranslationPrivacyMode.strict,
        isDm: false,
      );
      expect(adapter.callCount, 2); // Must call adapter again
    });
  });
}
