// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import 'translation_models.dart';

/// Local cache for translated messages.
///
/// Keyed by (messageId, textHash, targetLanguage) to avoid repeated API calls.
/// Supports a normalized dedupe index by (textHash, sourceLang, targetLang)
/// so identical source text translating to the same target reuses results.
class TranslationCache {
  Database? _db;
  final String? _testDbPath;

  /// Creates a cache. Pass [_testDbPath] to override the default path
  /// (e.g. [inMemoryDatabasePath] in tests).
  TranslationCache({this._testDbPath});

  /// Open or create the cache database.
  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath =
        _testDbPath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'translation_cache.db',
        );

    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE translations (
            message_id TEXT NOT NULL,
            text_hash TEXT NOT NULL,
            target_language TEXT NOT NULL,
            translated_text TEXT NOT NULL,
            detected_source_language TEXT,
            timestamp TEXT NOT NULL,
            provider TEXT DEFAULT 'managed',
            PRIMARY KEY (message_id, target_language)
          )
        ''');
        // Normalized dedupe index for text-hash-based lookups
        await db.execute('''
          CREATE INDEX idx_translations_dedupe
          ON translations (text_hash, target_language)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE translations ADD COLUMN provider TEXT DEFAULT 'managed'",
          );
          // Add dedupe index
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_translations_dedupe
            ON translations (text_hash, target_language)
          ''');
        }
        if (oldVersion < 3) {
          // Clear stale BYO/OpenAI cached translations that lack source
          // language detection. These may contain same-language results
          // (e.g. "Hi" → "Hello" when target is English) from before the
          // adapter was updated to return detectedSourceLanguage.
          await db.execute(
            'DELETE FROM translations WHERE detected_source_language IS NULL',
          );
        }
      },
    );
    AppLogging.app('TranslationCache: initialized');
  }

  /// Generate a short hash of the original text for cache verification.
  static String textHash(String text) {
    // Simple FNV-1a hash — fast, good distribution, no crypto dependency
    var hash = 2166136261;
    for (var i = 0; i < text.length; i++) {
      hash ^= text.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Look up a cached translation.
  ///
  /// Returns `null` on cache miss or if the text hash doesn't match
  /// (indicating the message content has changed).
  Future<TranslationResult?> get({
    required String messageId,
    required String originalText,
    required String targetLanguage,
  }) async {
    final db = _db;
    if (db == null) return null;

    // First try exact message ID match
    final rows = await db.query(
      'translations',
      where: 'message_id = ? AND target_language = ?',
      whereArgs: [messageId, targetLanguage],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final row = rows.first;
      // Verify text hash matches (content hasn't changed)
      final storedHash = row['text_hash'] as String;
      if (storedHash == textHash(originalText)) {
        return TranslationResult(
          translatedText: row['translated_text'] as String,
          detectedSourceLanguage: row['detected_source_language'] as String?,
          targetLanguage: row['target_language'] as String,
          timestamp: DateTime.parse(row['timestamp'] as String),
        );
      }
    }

    // Fall back to dedupe lookup: same text + same target = same result
    final hash = textHash(originalText);
    final dedupeRows = await db.query(
      'translations',
      where: 'text_hash = ? AND target_language = ?',
      whereArgs: [hash, targetLanguage],
      limit: 1,
    );

    if (dedupeRows.isEmpty) return null;

    final dedupeRow = dedupeRows.first;
    return TranslationResult(
      translatedText: dedupeRow['translated_text'] as String,
      detectedSourceLanguage: dedupeRow['detected_source_language'] as String?,
      targetLanguage: dedupeRow['target_language'] as String,
      timestamp: DateTime.parse(dedupeRow['timestamp'] as String),
    );
  }

  /// Store a translation result in the cache.
  Future<void> put({
    required String messageId,
    required String originalText,
    required TranslationResult result,
    String provider = 'managed',
  }) async {
    final db = _db;
    if (db == null) return;

    await db.insert('translations', {
      'message_id': messageId,
      'text_hash': textHash(originalText),
      'target_language': result.targetLanguage,
      'translated_text': result.translatedText,
      'detected_source_language': result.detectedSourceLanguage,
      'timestamp': result.timestamp.toIso8601String(),
      'provider': provider,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Clear all cached translations.
  Future<int> clearAll() async {
    final db = _db;
    if (db == null) return 0;
    return db.delete('translations');
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
