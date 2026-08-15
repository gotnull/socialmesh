// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/mesh_models.dart';
import '../../core/logging.dart';
import '../../core/radio_scope.dart';
import 'conversation_read_position.dart';
import 'encrypted_database.dart';
import '../../utils/text_sanitizer.dart';

/// SQLite-backed message storage service.
///
/// Replaces the SharedPreferences JSON blob approach which suffered from:
/// - A global 100-message cap across ALL conversations
/// - O(n) read-modify-write on every save (write amplification)
/// - Missing field serialization (status, packetId, routingError, errorMessage)
/// - No per-conversation storage or indexing
///
/// This implementation stores messages in a SQLite database with proper
/// indexing and per-conversation retention limits.
class MessageDatabase {
  static const _dbName = 'messages.db';
  static const _tableName = 'messages';
  static const _readPositionsTableName = 'conversation_read_positions';
  static const _dbVersion = 12;

  /// Maximum messages retained per conversation (DM or channel).
  static const int maxMessagesPerConversation = 500;

  Database? _db;
  final String? _testDbPath;

  /// Whether a migration from SharedPreferences has already been attempted
  /// this session.
  bool _migrationAttempted = false;

  MessageDatabase({this._testDbPath});

  /// Initialize the database, creating tables if needed and migrating
  /// any legacy SharedPreferences data on first run.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      dbPath = await RadioScope.instance.databasePath(_dbName);
    }

    _db = await openEncryptedDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
        // Only enforce WAL for on-disk databases. In-memory databases
        // (used in tests via _testDbPath) do not support WAL mode.
        if (_testDbPath == null) {
          assert(
            walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
            'WAL mode not active',
          ); // lint-allow: hardcoded-string
        }
      },
      onCreate: (db, version) async {
        AppLogging.storage('Creating messages database v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading messages database v$oldVersion -> v$newVersion',
        );
        // Re-runs are no-ops: after a downgrade the on-disk schema is
        // newer than user_version, so ALTER blocks must skip columns
        // that already exist.
        Set<String>? cachedColumns;
        Future<void> addColumnIfMissing(String column, String sql) async {
          final existing = cachedColumns ??= (await db.rawQuery(
            'PRAGMA table_info($_tableName)', // lint-allow: hardcoded-string
          )).map((r) => r['name'] as String).toSet();
          if (existing.contains(column)) {
            AppLogging.storage('Migration: $column already exists, skipping');
            return;
          }
          await db.execute(sql);
          existing.add(column);
        }

        if (oldVersion < 2) {
          await addColumnIfMissing(
            'reply_id',
            'ALTER TABLE $_tableName ADD COLUMN reply_id INTEGER', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'is_emoji',
            'ALTER TABLE $_tableName ADD COLUMN is_emoji INTEGER NOT NULL DEFAULT 0', // lint-allow: hardcoded-string
          );
          AppLogging.storage('Added reply_id and is_emoji columns (v2)');
        }
        if (oldVersion < 3) {
          // Retroactively fix tapback messages that were stored as regular
          // messages before the is_emoji flag was properly set.  Any message
          // whose text is at most 8 UTF-16 code units (a single emoji
          // grapheme cluster) AND has a reply_id is almost certainly a
          // tapback reaction, not a real text message.
          final fixed = await db.rawUpdate(
            'UPDATE $_tableName SET is_emoji = 1 ' // lint-allow: hardcoded-string
            'WHERE reply_id IS NOT NULL AND LENGTH(text) <= 8 ' // lint-allow: hardcoded-string
            'AND is_emoji = 0', // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'v3 migration: retroactively flagged $fixed legacy tapback messages',
          );
        }
        if (oldVersion < 4) {
          await addColumnIfMissing(
            'hop_count',
            'ALTER TABLE $_tableName ADD COLUMN hop_count INTEGER', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'rx_snr',
            'ALTER TABLE $_tableName ADD COLUMN rx_snr REAL', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'rx_rssi',
            'ALTER TABLE $_tableName ADD COLUMN rx_rssi INTEGER', // lint-allow: hardcoded-string
          );
          AppLogging.storage('Added hop_count, rx_snr, rx_rssi columns (v4)');
        }
        if (oldVersion < 5) {
          // Some devices received these columns via onCreate when the CREATE
          // TABLE schema was ahead of the version number.  Check PRAGMA
          // table_info before each ALTER to avoid duplicate column errors
          // (which sqflite prints to the native log even when caught in Dart).
          await addColumnIfMissing(
            'sent_at',
            'ALTER TABLE $_tableName ADD COLUMN sent_at INTEGER', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'last_attempt_at',
            'ALTER TABLE $_tableName ADD COLUMN last_attempt_at INTEGER', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'retry_count',
            'ALTER TABLE $_tableName ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0', // lint-allow: hardcoded-string
          );
          await addColumnIfMissing(
            'auto_retry_enabled',
            'ALTER TABLE $_tableName ADD COLUMN auto_retry_enabled INTEGER NOT NULL DEFAULT 0', // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'Added sent_at, last_attempt_at, retry_count, auto_retry_enabled columns (v5)',
          );
        }
        if (oldVersion < 6) {
          // Fix Primary Channel messages that were misclassified as DMs.
          //
          // A prior bug used `channel > 0` to detect channel messages, which
          // excluded Primary Channel (index 0). Broadcast messages on
          // channel 0 were incorrectly stored with DM-style conversation
          // keys like `dm:<from>:4294967295` instead of `channel:0`.
          //
          // Detection rule: to_node == 0xFFFFFFFF (broadcast) AND
          // conversation_key starts with 'dm:' → misclassified.
          // Repair: rewrite to `channel:<channel>` using the stored channel
          // column (defaulting to 0 if null).
          final fixed = await db.rawUpdate(
            'UPDATE $_tableName ' // lint-allow: hardcoded-string
            "SET conversation_key = 'channel:' || COALESCE(channel, 0) " // lint-allow: hardcoded-string
            "WHERE to_node = 4294967295 AND conversation_key LIKE 'dm:%'", // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'v6 migration: reclassified $fixed Primary Channel messages '
            'from DM-style to channel conversation keys',
          );
        }
        if (oldVersion < 7) {
          // Complete the channel column fix that v6 started.
          //
          // v6 repaired conversation_key for misclassified broadcast
          // messages but left the channel column as NULL.  The UI filters
          // channel messages with `m.channel == channelIndex` — in Dart,
          // `null != 0`, so these rows are invisible in the Primary
          // Channel conversation even though their conversation_key is
          // correct.  Normalise NULL → 0 for all broadcast rows so the
          // in-memory Message.channel matches the UI filter.
          final fixed = await db.rawUpdate(
            'UPDATE $_tableName ' // lint-allow: hardcoded-string
            'SET channel = COALESCE(channel, 0) ' // lint-allow: hardcoded-string
            'WHERE to_node = 4294967295 AND channel IS NULL', // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'v7 migration: normalised channel column for $fixed broadcast '
            'messages with NULL channel',
          );
        }
        if (oldVersion < 8) {
          // Deduplicate messages on reconnect: both foreground and background
          // ingest paths now produce deterministic IDs from packet identity
          // (pkt-<fromHex>-<packetIdHex>), so the PRIMARY KEY naturally
          // deduplicates via INSERT OR REPLACE.  This migration:
          //
          // 1. Removes legacy duplicate rows that accumulated before the fix
          //    (keeps the row with the smallest rowid per packet identity).
          // 2. Creates a unique index as a safety net for any edge case
          //    where a non-deterministic id reaches the DB.
          final removed = await db.rawDelete(
            'DELETE FROM $_tableName WHERE packet_id IS NOT NULL ' // lint-allow: hardcoded-string
            'AND rowid NOT IN (' // lint-allow: hardcoded-string
            '  SELECT MIN(rowid) FROM $_tableName ' // lint-allow: hardcoded-string
            '  WHERE packet_id IS NOT NULL ' // lint-allow: hardcoded-string
            '  GROUP BY packet_id, from_node' // lint-allow: hardcoded-string
            ')', // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'v8 migration: removed $removed duplicate messages',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS ' // lint-allow: hardcoded-string
            'idx_messages_packet_identity ' // lint-allow: hardcoded-string
            'ON $_tableName (packet_id, from_node) ' // lint-allow: hardcoded-string
            'WHERE packet_id IS NOT NULL', // lint-allow: hardcoded-string
          );
          AppLogging.storage(
            'v8 migration: created unique index on (packet_id, from_node)',
          );
        }
        if (oldVersion < 9) {
          await _createConversationReadPositionsTable(db);
          AppLogging.storage(
            'v9 migration: created conversation read positions table',
          );
        }
        if (oldVersion < 10) {
          // Nullable column — legacy rows load as realAck=null (unknown),
          // which the UI renders identically to the previous "delivered"
          // state to avoid rewriting historical certainty.
          await addColumnIfMissing(
            'real_ack',
            'ALTER TABLE $_tableName ADD COLUMN real_ack INTEGER', // lint-allow: hardcoded-string
          );
          AppLogging.storage('v10 migration: ensured real_ack column');
        }
        if (oldVersion < 11) {
          // Nullable column — legacy rows load as relayNode=null (unknown),
          // which the UI simply omits (the relay row is gated on non-null).
          await addColumnIfMissing(
            'relay_node',
            'ALTER TABLE $_tableName ADD COLUMN relay_node INTEGER', // lint-allow: hardcoded-string
          );
          AppLogging.storage('v11 migration: ensured relay_node column');
        }
        if (oldVersion < 12) {
          // Nullable tri-state column mirroring Message.viaMqtt: 1 = MQTT,
          // 0 = RF, NULL = unknown. Legacy rows load as null so historical
          // messages surface as "unknown" transport rather than being
          // mislabelled RF.
          await addColumnIfMissing(
            'via_mqtt',
            'ALTER TABLE $_tableName ADD COLUMN via_mqtt INTEGER', // lint-allow: hardcoded-string
          );
          AppLogging.storage('v12 migration: ensured via_mqtt column');
        }
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        // Retain the on-disk schema: every shipped schema is a strict
        // superset of older versions, and message history is
        // unrecoverable user data. sqflite stamps user_version down
        // after this callback, so the ALTER blocks in onUpgrade are
        // guarded for the eventual re-upgrade.
        AppLogging.storage(
          'Messages database downgrade requested '
          'v$oldVersion -> v$newVersion (schema retained)',
        );
      },
    );

    // Migrate from SharedPreferences on first run
    if (!_migrationAttempted) {
      _migrationAttempted = true;
      await _migrateFromSharedPreferences();
    }
  }

  Database get _database {
    if (_db == null) {
      throw Exception('MessageDatabase not initialized — call init() first');
    }
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        from_node INTEGER NOT NULL,
        to_node INTEGER NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        channel INTEGER,
        sent INTEGER NOT NULL DEFAULT 0,
        received INTEGER NOT NULL DEFAULT 0,
        acked INTEGER NOT NULL DEFAULT 0,
        real_ack INTEGER,
        status TEXT NOT NULL DEFAULT 'sent',
        error_message TEXT,
        routing_error TEXT,
        packet_id INTEGER,
        source TEXT NOT NULL DEFAULT 'unknown',
        read INTEGER NOT NULL DEFAULT 0,
        sender_long_name TEXT,
        sender_short_name TEXT,
        sender_avatar_color INTEGER,
        conversation_key TEXT NOT NULL,
        reply_id INTEGER,
        is_emoji INTEGER NOT NULL DEFAULT 0,
        hop_count INTEGER,
        rx_snr REAL,
        rx_rssi INTEGER,
        relay_node INTEGER,
        via_mqtt INTEGER,
        sent_at INTEGER,
        last_attempt_at INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0,
        auto_retry_enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index for per-conversation queries (the primary access pattern)
    await db.execute('''
      CREATE INDEX idx_messages_conversation
      ON $_tableName (conversation_key, timestamp DESC)
    ''');

    // Index for node-scoped queries (reconciliation)
    await db.execute('''
      CREATE INDEX idx_messages_node
      ON $_tableName (from_node, to_node, timestamp DESC)
    ''');

    // Index for packet ID lookups (delivery updates)
    await db.execute('''
      CREATE INDEX idx_messages_packet_id
      ON $_tableName (packet_id)
    ''');

    // Unique index on packet identity to prevent duplicate messages from
    // concurrent foreground/background ingest paths on reconnect.
    await db.execute('''
      CREATE UNIQUE INDEX idx_messages_packet_identity
      ON $_tableName (packet_id, from_node)
      WHERE packet_id IS NOT NULL
    ''');

    await _createConversationReadPositionsTable(db);

    AppLogging.storage('Created messages table with indexes');
  }

  Future<void> _createConversationReadPositionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_readPositionsTableName (
        conversation_key TEXT PRIMARY KEY,
        anchor_message_id TEXT NOT NULL,
        anchor_timestamp INTEGER NOT NULL,
        anchor_alignment REAL,
        was_near_latest INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Conversation key
  // ---------------------------------------------------------------------------

  /// Compute a stable conversation key for a message.
  ///
  /// Channel messages: `channel:<index>`
  /// DM messages: `dm:<lower_node>:<higher_node>` (order-independent)
  static String conversationKey(Message message) {
    // Broadcast messages (to == 0xFFFFFFFF) are channel messages.
    // Use the channel index as the key — including Primary Channel (index 0)
    // which was previously excluded by the `channel > 0` check, causing
    // Primary Channel messages to be stored under DM conversation keys.
    if (message.isBroadcast) {
      return 'channel:${message.channel ?? 0}'; // lint-allow: hardcoded-string
    }
    // For DMs, use sorted node nums so both directions map to the same key
    final a = message.from;
    final b = message.to;
    final lower = a < b ? a : b;
    final higher = a < b ? b : a;
    return 'dm:$lower:$higher'; // lint-allow: hardcoded-string
  }

  /// Compute a conversation key from raw parameters (for queries).
  static String conversationKeyFromParams({
    int? channel,
    int? nodeA,
    int? nodeB,
  }) {
    if (channel != null && channel >= 0) {
      return 'channel:$channel'; // lint-allow: hardcoded-string
    }
    if (nodeA != null && nodeB != null) {
      final lower = nodeA < nodeB ? nodeA : nodeB;
      final higher = nodeA < nodeB ? nodeB : nodeA;
      return 'dm:$lower:$higher'; // lint-allow: hardcoded-string
    }
    throw ArgumentError('Must provide either channel or both nodeA and nodeB');
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Insert or update a message. Trims the conversation if it exceeds
  /// [maxMessagesPerConversation].
  Future<void> saveMessage(Message message) async {
    final convKey = conversationKey(message);
    final row = _messageToRow(message, convKey);

    await _database.insert(
      _tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trim oldest messages beyond per-conversation limit
    await _trimConversation(convKey);
  }

  /// Batch insert multiple messages (used during migration).
  Future<void> saveMessages(List<Message> messages) async {
    if (messages.isEmpty) return;

    final batch = _database.batch();
    for (final message in messages) {
      final convKey = conversationKey(message);
      batch.insert(
        _tableName,
        _messageToRow(message, convKey),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    // Trim all affected conversations
    final convKeys = messages.map(conversationKey).toSet();
    for (final key in convKeys) {
      await _trimConversation(key);
    }
  }

  /// Load all messages, ordered by timestamp ascending.
  Future<List<Message>> loadMessages() async {
    final rows = await _database.query(_tableName, orderBy: 'timestamp ASC');
    return rows.map(_messageFromRow).toList();
  }

  /// Load messages for a specific conversation.
  Future<List<Message>> loadConversation(String convKey, {int? limit}) async {
    final rows = await _database.query(
      _tableName,
      where: 'conversation_key = ?',
      whereArgs: [convKey],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return rows.map(_messageFromRow).toList();
  }

  /// Count stored messages for a specific conversation.
  Future<int> countConversationMessages(String convKey) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_tableName WHERE conversation_key = ?', // lint-allow: hardcoded-string
      [convKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Load the newest [limit] messages for a conversation in ascending order.
  Future<List<Message>> loadConversationNewestWindow(
    String convKey, {
    required int limit,
  }) async {
    if (limit <= 0) return const [];

    final rows = await _database.rawQuery(
      '''
      SELECT * FROM (
        SELECT * FROM $_tableName
        WHERE conversation_key = ?
        ORDER BY timestamp DESC, id DESC
        LIMIT ?
      )
      ORDER BY timestamp ASC, id ASC
      ''',
      [convKey, limit],
    );
    return rows.map(_messageFromRow).toList();
  }

  /// Load an older page of messages before the current oldest loaded message.
  Future<List<Message>> loadConversationOlderPage(
    String convKey, {
    required DateTime beforeTimestamp,
    required String beforeMessageId,
    required int limit,
  }) async {
    if (limit <= 0) return const [];

    final rows = await _database.rawQuery(
      '''
      SELECT * FROM (
        SELECT * FROM $_tableName
        WHERE conversation_key = ?
          AND (
            timestamp < ?
            OR (timestamp = ? AND id < ?)
          )
        ORDER BY timestamp DESC, id DESC
        LIMIT ?
      )
      ORDER BY timestamp ASC, id ASC
      ''',
      [
        convKey,
        beforeTimestamp.millisecondsSinceEpoch,
        beforeTimestamp.millisecondsSinceEpoch,
        beforeMessageId,
        limit,
      ],
    );
    return rows.map(_messageFromRow).toList();
  }

  /// Reload the currently loaded window from its oldest message boundary.
  Future<List<Message>> loadConversationFromBoundary(
    String convKey, {
    required DateTime fromTimestamp,
    required String fromMessageId,
  }) async {
    final rows = await _database.query(
      _tableName,
      where:
          'conversation_key = ? AND (timestamp > ? OR (timestamp = ? AND id >= ?))',
      whereArgs: [
        convKey,
        fromTimestamp.millisecondsSinceEpoch,
        fromTimestamp.millisecondsSinceEpoch,
        fromMessageId,
      ],
      orderBy: 'timestamp ASC, id ASC',
    );
    return rows.map(_messageFromRow).toList();
  }

  Future<void> saveConversationReadPosition(
    ConversationReadPosition position,
  ) async {
    await _database.insert(_readPositionsTableName, {
      'conversation_key': position.conversationKey,
      'anchor_message_id': position.anchorMessageId,
      'anchor_timestamp': position.anchorTimestamp.millisecondsSinceEpoch,
      'anchor_alignment': position.anchorAlignment,
      'was_near_latest': position.wasNearLatest ? 1 : 0,
      'updated_at': position.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ConversationReadPosition?> loadConversationReadPosition(
    String convKey,
  ) async {
    final rows = await _database.query(
      _readPositionsTableName,
      where: 'conversation_key = ?',
      whereArgs: [convKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return ConversationReadPosition(
      conversationKey: row['conversation_key'] as String,
      anchorMessageId: row['anchor_message_id'] as String,
      anchorTimestamp: DateTime.fromMillisecondsSinceEpoch(
        row['anchor_timestamp'] as int,
      ),
      anchorAlignment: (row['anchor_alignment'] as num?)?.toDouble(),
      wasNearLatest: (row['was_near_latest'] as int) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  /// Count messages for a given node since a timestamp.
  Future<int> countMessagesForNode(int nodeNum, {int? sinceMillis}) async {
    final where = StringBuffer('(from_node = ? OR to_node = ?)');
    final args = <Object>[nodeNum, nodeNum];
    if (sinceMillis != null) {
      where.write(' AND timestamp >= ?');
      args.add(sinceMillis);
    }
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE $where', // lint-allow: hardcoded-string
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Load messages for a given node, optionally since a timestamp.
  Future<List<Message>> loadMessagesForNode(
    int nodeNum, {
    int? sinceMillis,
  }) async {
    final where = StringBuffer('(from_node = ? OR to_node = ?)');
    final args = <Object>[nodeNum, nodeNum];
    if (sinceMillis != null) {
      where.write(' AND timestamp >= ?');
      args.add(sinceMillis);
    }
    final rows = await _database.query(
      _tableName,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'timestamp ASC',
    );
    return rows.map(_messageFromRow).toList();
  }

  /// Find a message by its packet ID (for delivery updates).
  Future<Message?> findByPacketId(int packetId) async {
    final rows = await _database.query(
      _tableName,
      where: 'packet_id = ?',
      whereArgs: [packetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _messageFromRow(rows.first);
  }

  /// Delete a specific message by ID.
  Future<void> deleteMessage(String messageId) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [messageId]);
    AppLogging.storage('Deleted message: $messageId');
  }

  /// Clear all messages.
  Future<void> clearMessages() async {
    await _database.delete(_tableName);
    AppLogging.storage('Cleared all messages');
  }

  /// Delete every stored message for a specific channel index.
  ///
  /// Returns the number of rows removed. DM rows (where `channel` is
  /// null) are unaffected — they live in their own conversation key.
  Future<int> deleteMessagesForChannel(int channelIndex) async {
    final removed = await _database.delete(
      _tableName,
      where: 'channel = ?',
      whereArgs: [channelIndex],
    );
    AppLogging.storage('Cleared $removed messages from channel $channelIndex');
    return removed;
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Trimming
  // ---------------------------------------------------------------------------

  /// Remove oldest messages in a conversation if count exceeds the limit.
  Future<void> _trimConversation(String convKey) async {
    final countResult = await _database.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE conversation_key = ?', // lint-allow: hardcoded-string
      [convKey],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count > maxMessagesPerConversation) {
      final excess = count - maxMessagesPerConversation;
      await _database.rawDelete(
        '''
        DELETE FROM $_tableName WHERE id IN (
          SELECT id FROM $_tableName
          WHERE conversation_key = ?
          ORDER BY timestamp ASC
          LIMIT ?
        )
        ''',
        [convKey, excess],
      );
      AppLogging.storage(
        'Trimmed $excess oldest messages from conversation $convKey',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, Object?> _messageToRow(Message message, String convKey) {
    return {
      'id': message.id,
      'from_node': message.from,
      'to_node': message.to,
      'text': message.text,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'channel': message.channel,
      'sent': message.sent ? 1 : 0,
      'received': message.received ? 1 : 0,
      'acked': message.acked ? 1 : 0,
      'real_ack': message.realAck == null ? null : (message.realAck! ? 1 : 0),
      'status': message.status.name,
      'error_message': message.errorMessage,
      'routing_error': message.routingError?.name,
      'packet_id': message.packetId,
      'source': message.source.name,
      'read': message.read ? 1 : 0,
      'sender_long_name': message.senderLongName,
      'sender_short_name': message.senderShortName,
      'sender_avatar_color': message.senderAvatarColor,
      'conversation_key': convKey,
      'reply_id': message.replyId,
      'is_emoji': message.isEmoji ? 1 : 0,
      'hop_count': message.hopCount,
      'rx_snr': message.rxSnr,
      'rx_rssi': message.rxRssi,
      'relay_node': message.relayNode,
      'via_mqtt': message.viaMqtt == null ? null : (message.viaMqtt! ? 1 : 0),
      'sent_at': message.sentAt?.millisecondsSinceEpoch,
      'last_attempt_at': message.lastAttemptAt?.millisecondsSinceEpoch,
      'retry_count': message.retryCount,
      'auto_retry_enabled': message.autoRetryEnabled ? 1 : 0,
    };
  }

  Message _messageFromRow(Map<String, Object?> row) {
    return Message(
      id: row['id'] as String,
      from: row['from_node'] as int,
      to: row['to_node'] as int,
      text: sanitizeExternalText(row['text'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      // Normalise channel for broadcast messages: if the DB column is NULL
      // but to_node indicates a broadcast (0xFFFFFFFF), default to Primary
      // Channel (0).  This ensures `Message.channel == 0` so the UI filter
      // `m.channel == channelIndex` matches correctly.  DMs keep null
      // channel unchanged (their classification uses to/from, not channel).
      channel:
          (row['channel'] as int?) ??
          ((row['to_node'] as int) == 0xFFFFFFFF ? 0 : null),
      sent: (row['sent'] as int) == 1,
      received: (row['received'] as int) == 1,
      acked: (row['acked'] as int) == 1,
      realAck: row['real_ack'] == null ? null : (row['real_ack'] as int) == 1,
      status: _parseMessageStatus(row['status'] as String?),
      errorMessage: row['error_message'] as String?,
      routingError: _parseRoutingError(row['routing_error'] as String?),
      packetId: row['packet_id'] as int?,
      source: _parseMessageSource(row['source'] as String?),
      read: (row['read'] as int) == 1,
      senderLongName: row['sender_long_name'] != null
          ? sanitizeExternalText(row['sender_long_name'] as String)
          : null,
      senderShortName: row['sender_short_name'] != null
          ? sanitizeExternalText(row['sender_short_name'] as String)
          : null,
      senderAvatarColor: row['sender_avatar_color'] as int?,
      replyId: row['reply_id'] as int?,
      isEmoji: (row['is_emoji'] as int?) == 1,
      hopCount: row['hop_count'] as int?,
      rxSnr: (row['rx_snr'] as num?)?.toDouble(),
      rxRssi: row['rx_rssi'] as int?,
      relayNode: row['relay_node'] as int?,
      viaMqtt: row['via_mqtt'] == null ? null : (row['via_mqtt'] as int) == 1,
      sentAt: row['sent_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['sent_at'] as int)
          : null,
      lastAttemptAt: row['last_attempt_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_attempt_at'] as int)
          : null,
      retryCount: (row['retry_count'] as int?) ?? 0,
      autoRetryEnabled: (row['auto_retry_enabled'] as int?) == 1,
    );
  }

  MessageStatus _parseMessageStatus(String? name) {
    if (name == null) return MessageStatus.sent;
    return MessageStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MessageStatus.sent,
    );
  }

  RoutingError? _parseRoutingError(String? name) {
    if (name == null) return null;
    return RoutingError.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RoutingError.none,
    );
  }

  MessageSource _parseMessageSource(String? name) {
    if (name == null) return MessageSource.unknown;
    return MessageSource.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MessageSource.unknown,
    );
  }

  // ---------------------------------------------------------------------------
  // Migration from SharedPreferences
  // ---------------------------------------------------------------------------

  /// One-time migration: read legacy JSON blob from SharedPreferences,
  /// insert into SQLite, then remove the SharedPreferences key.
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('messages');
      if (jsonString == null || jsonString.isEmpty) return;

      // Check if we already have messages in the database (migration already
      // ran in a previous session but the prefs key was not cleaned up).
      final existingCount = Sqflite.firstIntValue(
        await _database.rawQuery('SELECT COUNT(*) FROM $_tableName'),
      );
      if (existingCount != null && existingCount > 0) {
        // Database already has messages — just clean up the prefs key.
        await prefs.remove('messages');
        AppLogging.storage(
          'SharedPreferences migration skipped: database already has '
          '$existingCount messages. Removed legacy key.',
        );
        return;
      }

      final jsonList = jsonDecode(jsonString) as List;
      final messages = <Message>[];

      for (final j in jsonList) {
        try {
          final json = j as Map<String, dynamic>;
          messages.add(
            Message(
              id: json['id'] as String,
              from: json['from'] as int,
              to: json['to'] as int,
              text: sanitizeExternalText(json['text'] as String),
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                json['timestamp'] as int,
              ),
              channel: json['channel'] as int?,
              sent: json['sent'] as bool? ?? false,
              received: json['received'] as bool? ?? false,
              acked: json['acked'] as bool? ?? false,
              source: _parseMessageSource(json['source'] as String?),
              read: json['read'] as bool? ?? false,
              senderLongName: json['senderLongName'] != null
                  ? sanitizeExternalText(json['senderLongName'] as String)
                  : null,
              senderShortName: json['senderShortName'] != null
                  ? sanitizeExternalText(json['senderShortName'] as String)
                  : null,
              senderAvatarColor: json['senderAvatarColor'] as int?,
              // These fields were not persisted in the old format —
              // they'll get their defaults (MessageStatus.sent, null, null)
            ),
          );
        } catch (e) {
          AppLogging.storage('Skipping malformed legacy message: $e');
        }
      }

      if (messages.isNotEmpty) {
        await saveMessages(messages);
        AppLogging.storage(
          'Migrated ${messages.length} messages from SharedPreferences '
          'to SQLite',
        );
      }

      // Remove the legacy key
      await prefs.remove('messages');
      AppLogging.storage('Removed legacy SharedPreferences messages key');
    } catch (e) {
      AppLogging.storage('SharedPreferences migration failed: $e');
      // Non-fatal — old messages may be lost but new ones will persist
    }
  }
}
