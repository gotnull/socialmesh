import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MessagesProvider persists pushed message and is queryable', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Ensure message storage is initialized by reading the provider
    await container.read(messageStorageProvider.future);

    final payload = {
      'fromNode': '10',
      'toNode': '20',
      'text': 'Test push message',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final message = parsePushMessagePayload(payload)!;

    // Simulate push handling by directly adding it (Push handler will do this in runtime)
    container.read(messagesProvider.notifier).addMessage(message);

    final messages = container.read(messagesProvider);
    expect(messages.any((m) => m.id == message.id), isTrue);

    // Check that getMessagesForNode works
    final nodeMessages = container
        .read(messagesProvider.notifier)
        .getMessagesForNode(10);
    expect(nodeMessages.any((m) => m.id == message.id), isTrue);
  });
}
