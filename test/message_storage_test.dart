import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MessageStorageService saves and loads parsed push message', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = MessageStorageService();
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
