import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

/// Minimal protocol stub exposing a controllable message stream for tests
class _TestProtocolService extends ProtocolService {
  final StreamController<Message> controller =
      StreamController<Message>.broadcast();

  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => controller.stream;

  void emit(Message m) => controller.add(m);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'push_persisted_message_survives_reconnect_and_dedupes_with_device_message',
    () async {
      SharedPreferences.setMockInitialValues({});

      // Prepare storage and persist a push-parsed message
      final storage = MessageStorageService();
      await storage.init();

      final payload = {
        'fromNode': '10',
        'toNode': '20',
        'text': 'Hello from push (e2e)',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final parsed = parsePushMessagePayload(payload);
      expect(parsed, isNotNull);
      await storage.saveMessage(parsed!);

      // Prepare a test protocol we can emit messages from
      final testProtocol = _TestProtocolService();

      final container = ProviderContainer(
        overrides: [
          messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
          protocolServiceProvider.overrideWithValue(testProtocol),
        ],
      );
      addTearDown(container.dispose);

      // Ensure UI state starts empty
      final notifier = container.read(messagesProvider.notifier);
      notifier.state = [];

      // Set our device myNodeNum to be the message 'to' node (20)
      // Set our MyNodeNum notifier to the device node number
      container.read(myNodeNumProvider.notifier).state = parsed.to;

      // Simulate device pairing/connect which triggers reconcile canary
      final device = DeviceInfo(
        id: 'dev123',
        name: 'Test Device',
        type: TransportType.ble,
      );
      container
          .read(deviceConnectionProvider.notifier)
          .markAsPaired(device, parsed.to);

      // Wait a tick for the microtask reconcile to run
      await Future.delayed(const Duration(milliseconds: 50));

      // After reconnect canary, the message should be in provider
      final stateAfterRehydrate = container.read(messagesProvider);
      expect(stateAfterRehydrate.where((m) => m.id == parsed.id).length, 1);

      // Now inject the same message via the protocol ingest path (device message)
      final deviceMessage = Message(
        id: parsed.id, // same id, should dedupe
        from: parsed.from,
        to: parsed.to,
        text: parsed.text,
        timestamp: parsed.timestamp,
        channel: parsed.channel,
        received: true,
      );

      testProtocol.emit(deviceMessage);

      // Allow time for stream to propagate
      await Future.delayed(const Duration(milliseconds: 50));

      final finalState = container.read(messagesProvider);

      // Still only one message (deduped)
      expect(finalState.where((m) => m.id == parsed.id).length, 1);

      // Conversation key expectation (dm:10 because myNodeNum == 20)
      final myNode = container.read(myNodeNumProvider);
      final message = finalState.firstWhere((m) => m.id == parsed.id);
      final other = message.from == myNode ? message.to : message.from;
      final convKey = 'dm:$other';
      expect(convKey, 'dm:10');
    },
  );
}
