// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/translation/translation_cache.dart';
import 'package:socialmesh/services/translation/translation_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TranslationCache cache;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    cache = TranslationCache(testDbPath: inMemoryDatabasePath);
    await cache.initialize();
  });

  tearDown(() async {
    await cache.close();
  });

  group('TranslationCache', () {
    final result = TranslationResult(
      translatedText: 'hola',
      detectedSourceLanguage: 'en',
      targetLanguage: 'es',
      timestamp: DateTime(2025, 6, 15, 12, 0, 0),
    );

    test('returns null on cache miss', () async {
      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      expect(cached, isNull);
    });

    test('stores and retrieves a translation', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNotNull);
      expect(cached!.translatedText, 'hola');
      expect(cached.detectedSourceLanguage, 'en');
      expect(cached.targetLanguage, 'es');
    });

    test('returns null when text has changed (hash mismatch)', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      // Lookup with different original text
      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello world',
        targetLanguage: 'es',
      );

      expect(cached, isNull);
    });

    test('returns null for different target language', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'fr',
      );

      expect(cached, isNull);
    });

    test('replaces existing entry on conflict', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      final updatedResult = TranslationResult(
        translatedText: 'hola actualizada',
        detectedSourceLanguage: 'en',
        targetLanguage: 'es',
        timestamp: DateTime(2025, 6, 16, 12, 0, 0),
      );

      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: updatedResult,
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNotNull);
      expect(cached!.translatedText, 'hola actualizada');
    });

    test('stores multiple messages independently', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      final result2 = TranslationResult(
        translatedText: 'bonjour',
        detectedSourceLanguage: 'en',
        targetLanguage: 'fr',
        timestamp: DateTime(2025, 6, 15, 12, 0, 0),
      );

      await cache.put(
        messageId: 'msg-2',
        originalText: 'good morning',
        result: result2,
      );

      final cached1 = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      final cached2 = await cache.get(
        messageId: 'msg-2',
        originalText: 'good morning',
        targetLanguage: 'fr',
      );

      expect(cached1, isNotNull);
      expect(cached1!.translatedText, 'hola');
      expect(cached2, isNotNull);
      expect(cached2!.translatedText, 'bonjour');
    });

    test('handles null detectedSourceLanguage', () async {
      final noDetected = TranslationResult(
        translatedText: 'hola',
        targetLanguage: 'es',
        timestamp: DateTime(2025, 6, 15, 12, 0, 0),
      );

      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: noDetected,
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNotNull);
      expect(cached!.detectedSourceLanguage, isNull);
    });

    test('initialize is idempotent', () async {
      // Already initialized in setUp — calling again should be no-op
      await cache.initialize();

      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNotNull);
    });

    test('get returns null when database is not initialized', () async {
      final uninitializedCache = TranslationCache(
        testDbPath: inMemoryDatabasePath,
      );

      final cached = await uninitializedCache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNull);
    });

    test('put is no-op when database is not initialized', () async {
      final uninitializedCache = TranslationCache(
        testDbPath: inMemoryDatabasePath,
      );

      // Should not throw
      await uninitializedCache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );
    });

    test('clearAll removes all cached entries', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
      );
      await cache.put(
        messageId: 'msg-2',
        originalText: 'world',
        result: TranslationResult(
          translatedText: 'mundo',
          targetLanguage: 'es',
          timestamp: DateTime(2025, 6, 15, 12, 0, 0),
        ),
      );

      await cache.clearAll();

      final cached1 = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );
      final cached2 = await cache.get(
        messageId: 'msg-2',
        originalText: 'world',
        targetLanguage: 'es',
      );

      expect(cached1, isNull);
      expect(cached2, isNull);
    });

    test('put accepts provider parameter', () async {
      await cache.put(
        messageId: 'msg-1',
        originalText: 'hello',
        result: result,
        provider: 'byo',
      );

      final cached = await cache.get(
        messageId: 'msg-1',
        originalText: 'hello',
        targetLanguage: 'es',
      );

      expect(cached, isNotNull);
      expect(cached!.translatedText, 'hola');
    });

    test('textHash produces consistent hashes', () {
      final hash1 = TranslationCache.textHash('hello');
      final hash2 = TranslationCache.textHash('hello');
      final hash3 = TranslationCache.textHash('world');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
    });
  });
}
