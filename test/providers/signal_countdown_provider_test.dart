import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/signal_providers.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/signal_service.dart';
import 'package:socialmesh/models/social.dart';

class FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

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
  Future<void> send(List<int> data) async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  bool get isConnected => state == DeviceConnectionState.connected;

  @override
  Future<void> dispose() async {}
}

class FakeSignalService extends SignalService {
  FakeSignalService() : super();

  @override
  Future<void> init() async {}

  @override
  Future<List<Post>> getActiveSignals() async {
    return [];
  }

  @override
  Future<int> cleanupExpiredSignals() async {
    return 0;
  }

  @override
  Future<int> retryCloudLookups() async {
    return 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Signal countdown ticker updates lastRefresh each second', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          signalServiceProvider.overrideWithValue(FakeSignalService()),
          protocolServiceProvider.overrideWithValue(
            ProtocolService(FakeTransport()),
          ),
          isSignedInProvider.overrideWithValue(false),
          isOnlineProvider.overrideWithValue(false),
        ],
      );

      // Trigger provider build and timers before advancing time.
      container.read(signalFeedProvider);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      final first = container.read(signalFeedProvider).lastRefresh;
      expect(first, isNotNull);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      final second = container.read(signalFeedProvider).lastRefresh;
      expect(second, isNotNull);
      expect(second!.isAfter(first!), isTrue);

      container.dispose();
    });
  });
}
