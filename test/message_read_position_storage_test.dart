// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/services/storage/conversation_read_position.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_read_pos_${_testPid}_${_testDbSeq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('saves and loads a conversation read position', () async {
    final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
    await storage.init();

    final savedAt = DateTime(2026, 4, 12, 9, 30);
    final position = ConversationReadPosition(
      conversationKey: 'dm:10:20',
      anchorMessageId: 'message-020',
      anchorTimestamp: DateTime(2026, 4, 12, 9, 15),
      anchorAlignment: 0.74,
      wasNearLatest: false,
      updatedAt: savedAt,
    );

    await storage.saveConversationReadPosition(position);
    final loaded = await storage.loadConversationReadPosition('dm:10:20');

    expect(loaded, isNotNull);
    expect(loaded!.conversationKey, 'dm:10:20');
    expect(loaded.anchorMessageId, 'message-020');
    expect(loaded.anchorTimestamp, DateTime(2026, 4, 12, 9, 15));
    expect(loaded.anchorAlignment, 0.74);
    expect(loaded.wasNearLatest, isFalse);
    expect(loaded.updatedAt, savedAt);
  });

  test('updating an existing conversation replaces the prior anchor', () async {
    final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
    await storage.init();

    await storage.saveConversationReadPosition(
      ConversationReadPosition(
        conversationKey: 'dm:10:20',
        anchorMessageId: 'message-020',
        anchorTimestamp: DateTime(2026, 4, 12, 9, 15),
        anchorAlignment: 0.7,
        wasNearLatest: false,
        updatedAt: DateTime(2026, 4, 12, 9, 30),
      ),
    );

    await storage.saveConversationReadPosition(
      ConversationReadPosition(
        conversationKey: 'dm:10:20',
        anchorMessageId: 'message-028',
        anchorTimestamp: DateTime(2026, 4, 12, 9, 28),
        anchorAlignment: 0.9,
        wasNearLatest: true,
        updatedAt: DateTime(2026, 4, 12, 9, 45),
      ),
    );

    final loaded = await storage.loadConversationReadPosition('dm:10:20');
    expect(loaded, isNotNull);
    expect(loaded!.anchorMessageId, 'message-028');
    expect(loaded.anchorAlignment, 0.9);
    expect(loaded.wasNearLatest, isTrue);
    expect(loaded.updatedAt, DateTime(2026, 4, 12, 9, 45));
  });

  test('conversation read positions stay isolated per conversation', () async {
    final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
    await storage.init();

    await storage.saveConversationReadPosition(
      ConversationReadPosition(
        conversationKey: 'dm:10:20',
        anchorMessageId: 'dm-anchor',
        anchorTimestamp: DateTime(2026, 4, 12, 8, 0),
        wasNearLatest: false,
        updatedAt: DateTime(2026, 4, 12, 8, 1),
      ),
    );
    await storage.saveConversationReadPosition(
      ConversationReadPosition(
        conversationKey: 'channel:0',
        anchorMessageId: 'channel-anchor',
        anchorTimestamp: DateTime(2026, 4, 12, 8, 30),
        wasNearLatest: true,
        updatedAt: DateTime(2026, 4, 12, 8, 31),
      ),
    );

    final dmPosition = await storage.loadConversationReadPosition('dm:10:20');
    final channelPosition = await storage.loadConversationReadPosition(
      'channel:0',
    );

    expect(dmPosition, isNotNull);
    expect(channelPosition, isNotNull);
    expect(dmPosition!.anchorMessageId, 'dm-anchor');
    expect(channelPosition!.anchorMessageId, 'channel-anchor');
    expect(dmPosition.wasNearLatest, isFalse);
    expect(channelPosition.wasNearLatest, isTrue);
  });
}
