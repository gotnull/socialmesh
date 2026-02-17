import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_storage_${_testPid}_${_testDbSeq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('MessageDatabase saves and loads parsed push message', () async {
    final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
    await storage.init();

    final payload = {
      'fromNode': '123',
      'toNode': '456',
      'text': 'Hello from push',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final message = parsePushMessagePayload(payload);
    expect(message, isNotNull);

    await storage.saveMessage(message!);

    final loaded = await storage.loadMessages();
    expect(loaded.any((m) => m.id == message.id), isTrue);
  });
}
