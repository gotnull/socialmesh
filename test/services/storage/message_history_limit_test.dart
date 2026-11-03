// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;

String _uniqueDbPath() {
  return p.join(
    Directory.systemTemp.path,
    'msg_history_limit_${_pid}_${_seq++}.db',
  );
}

List<Message> _channelMessages(int count, {int offset = 0}) {
  return [
    for (var i = offset; i < offset + count; i++)
      Message(
        id: 'm-$i',
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Message $i',
        timestamp: DateTime(2025, 1, 1).add(Duration(minutes: i)),
        channel: 0,
        received: true,
      ),
  ];
}

Future<MessageDatabase> _openWithSavedLimit(int? saved) async {
  SharedPreferences.setMockInitialValues({
    if (saved != null) 'message_history_limit': saved,
  });
  final storage = MessageDatabase(testDbPath: _uniqueDbPath());
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  group('SettingsService.readMessageHistoryLimit', () {
    Future<int> resolve(int? saved) async {
      SharedPreferences.setMockInitialValues({
        if (saved != null) 'message_history_limit': saved,
      });
      return SettingsService.readMessageHistoryLimit(
        await SharedPreferences.getInstance(),
      );
    }

    test('defaults to the database limit when nothing is saved', () async {
      expect(await resolve(null), MessageDatabase.maxMessagesPerConversation);
    });

    test('raises values saved before the limit was applied', () async {
      for (final saved in [50, 100, 200]) {
        expect(
          await resolve(saved),
          MessageDatabase.maxMessagesPerConversation,
        );
      }
    });

    test('keeps a saved limit at or above the default', () async {
      expect(await resolve(1000), 1000);
      expect(await resolve(5000), 5000);
    });

    test('the smallest option is the database default', () {
      expect(
        SettingsService.messageHistoryLimitOptions.first,
        MessageDatabase.maxMessagesPerConversation,
      );
    });
  });

  group('MessageDatabase conversation limit', () {
    test(
      'a raised limit keeps more than the default per conversation',
      () async {
        final storage = await _openWithSavedLimit(1000);

        await storage.saveMessages(_channelMessages(600));

        expect(await storage.loadConversation('channel:0'), hasLength(600));
      },
    );

    test(
      'a legacy saved value still trims at the default, never below',
      () async {
        final storage = await _openWithSavedLimit(100);
        final limit = MessageDatabase.maxMessagesPerConversation;

        await storage.saveMessages(_channelMessages(limit + 1));

        final kept = await storage.loadConversation('channel:0');
        expect(kept, hasLength(limit));
        expect(kept.any((m) => m.id == 'm-0'), isFalse);
      },
    );

    test(
      'a limit changed while the database is open applies on the next save',
      () async {
        final storage = await _openWithSavedLimit(1000);
        await storage.saveMessages(_channelMessages(600));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'message_history_limit',
          MessageDatabase.maxMessagesPerConversation,
        );
        await storage.saveMessage(_channelMessages(1, offset: 600).single);

        final kept = await storage.loadConversation('channel:0');
        expect(kept, hasLength(MessageDatabase.maxMessagesPerConversation));
        expect(kept.any((m) => m.id == 'm-600'), isTrue);
        expect(kept.any((m) => m.id == 'm-100'), isFalse);
      },
    );
  });
}
