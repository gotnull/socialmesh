// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/mesh_models.dart';
import '../../core/logging.dart';
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
  static const _dbVersion = 1;

  /// Maximum messages retained per conversation (DM or channel).
  static const int maxMessagesPerConversation = 500;

  Database? _db;
  final String? _testDbPath;

  /// Whether a migration from SharedPreferences has already been attempted
  /// this session.
  bool _migrationAttempted = false;

  MessageDatabase({String? testDbPath}) : _testDbPath = testDbPath;

  /// Initialize the database, creating tables if needed and migrating
  /// any legacy SharedPreferences data on first run.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final documentsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(documentsDir.path, _dbName);
    }

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        AppLogging.storage('Creating messages database v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading messages database v$oldVersion -> v$newVersion',
        );
        // Future migrations go here
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
        status TEXT NOT NULL DEFAULT 'sent',
        error_message TEXT,
        routing_error TEXT,
        packet_id INTEGER,
        source TEXT NOT NULL DEFAULT 'unknown',
        read INTEGER NOT NULL DEFAULT 0,
        sender_long_name TEXT,
        sender_short_name TEXT,
        sender_avatar_color INTEGER,
        conversation_key TEXT NOT NULL
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

    AppLogging.storage('Created messages table with indexes');
  }

  // ---------------------------------------------------------------------------
  // Conversation key
  // ---------------------------------------------------------------------------

  /// Compute a stable conversation key for a message.
  ///
  /// Channel messages: `channel:<index>`
  /// DM messages: `dm:<lower_node>:<higher_node>` (order-independent)
  static String conversationKey(Message message) {
    if (message.channel != null && message.channel! > 0) {
      return 'channel:${message.channel}';
    }
    // For DMs, use sorted node nums so both directions map to the same key
    final a = message.from;
    final b = message.to;
    final lower = a < b ? a : b;
    final higher = a < b ? b : a;
    return 'dm:$lower:$higher';
  }

  /// Compute a conversation key from raw parameters (for queries).
  static String conversationKeyFromParams({
    int? channel,
    int? nodeA,
    int? nodeB,
  }) {
    if (channel != null && channel > 0) {
      return 'channel:$channel';
    }
    if (nodeA != null && nodeB != null) {
      final lower = nodeA < nodeB ? nodeA : nodeB;
      final higher = nodeA < nodeB ? nodeB : nodeA;
      return 'dm:$lower:$higher';
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

  /// Count messages for a given node since a timestamp.
  Future<int> countMessagesForNode(int nodeNum, {int? sinceMillis}) async {
    final where = StringBuffer('(from_node = ? OR to_node = ?)');
    final args = <Object>[nodeNum, nodeNum];
    if (sinceMillis != null) {
      where.write(' AND timestamp >= ?');
      args.add(sinceMillis);
    }
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE $where',
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
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE conversation_key = ?',
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
    };
  }

  Message _messageFromRow(Map<String, Object?> row) {
    return Message(
      id: row['id'] as String,
      from: row['from_node'] as int,
      to: row['to_node'] as int,
      text: sanitizeUtf16(row['text'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      channel: row['channel'] as int?,
      sent: (row['sent'] as int) == 1,
      received: (row['received'] as int) == 1,
      acked: (row['acked'] as int) == 1,
      status: _parseMessageStatus(row['status'] as String?),
      errorMessage: row['error_message'] as String?,
      routingError: _parseRoutingError(row['routing_error'] as String?),
      packetId: row['packet_id'] as int?,
      source: _parseMessageSource(row['source'] as String?),
      read: (row['read'] as int) == 1,
      senderLongName: row['sender_long_name'] != null
          ? sanitizeUtf16(row['sender_long_name'] as String)
          : null,
      senderShortName: row['sender_short_name'] != null
          ? sanitizeUtf16(row['sender_short_name'] as String)
          : null,
      senderAvatarColor: row['sender_avatar_color'] as int?,
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
              text: sanitizeUtf16(json['text'] as String),
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
                  ? sanitizeUtf16(json['senderLongName'] as String)
                  : null,
              senderShortName: json['senderShortName'] != null
                  ? sanitizeUtf16(json['senderShortName'] as String)
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
