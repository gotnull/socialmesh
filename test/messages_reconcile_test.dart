import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reconcileFromStorageForNode adds messages present in storage',
    () async {
      SharedPreferences.setMockInitialValues({});

      final storage = MessageStorageService();
      await storage.init();

      final payload = {
        'fromNode': '10',
        'toNode': '20',
        'text': 'Hello from push reconcile test',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final message = parsePushMessagePayload(payload);
      expect(message, isNotNull);

      await storage.saveMessage(message!);

      final container = ProviderContainer(
        overrides: [
          messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(messagesProvider.notifier);

      // Simulate empty UI state
      notifier.state = [];

      await notifier.reconcileFromStorageForNode(message.from);

      final state = container.read(messagesProvider);
      expect(state.any((m) => m.id == message.id), isTrue);
    },
  );
}
