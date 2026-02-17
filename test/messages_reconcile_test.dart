import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/message_database.dart';
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

class _TestProtocolService extends ProtocolService {
  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => const Stream.empty();
}

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_reconcile_${_testPid}_${_testDbSeq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'reconcileFromStorageForNode adds messages present in storage',
    () async {
      SharedPreferences.setMockInitialValues({});

      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
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
          protocolServiceProvider.overrideWithValue(_TestProtocolService()),
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
