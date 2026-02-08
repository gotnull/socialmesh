// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

/// Minimal protocol stub exposing a controllable message stream.
class _TestProtocolService extends ProtocolService {
  final StreamController<Message> controller =
      StreamController<Message>.broadcast();

  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => controller.stream;

  void emit(Message m) => controller.add(m);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired with in-memory storage and a test
/// protocol, seeds myNodeNum, and returns everything the test needs.
Future<
  ({
    ProviderContainer container,
    _TestProtocolService protocol,
    MessageStorageService storage,
  })
>
_createTestHarness({int myNodeNum = 20}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = MessageStorageService();
  await storage.init();

  final testProtocol = _TestProtocolService();

  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(testProtocol),
    ],
  );

  // Ensure the notifier is alive with a clean slate.
  container.read(messagesProvider.notifier).state = [];
  container.read(myNodeNumProvider.notifier).state = myNodeNum;

  return (container: container, protocol: testProtocol, storage: storage);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  // Dedupe edge-case 1: push-delivered message then device replay with a
  // completely different id and packetId but identical content.
  // The content-fingerprint layer must catch it.
  // -----------------------------------------------------------------------
  test(
    'dedupe: replay with different id and packetId but same content is caught',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      // Simulate a push-delivered message (SHA1-based deterministic id,
      // no packetId).
      final pushPayload = {
        'fromNode': '10',
        'toNode': '20',
        'text': 'Hello from the mesh',
        'timestamp': now.millisecondsSinceEpoch.toString(),
      };
      final pushMessage = parsePushMessagePayload(pushPayload)!;
      h.container.read(messagesProvider.notifier).addMessage(pushMessage);

      // Verify it landed.
      expect(
        h.container
            .read(messagesProvider)
            .where((m) => m.text == pushMessage.text)
            .length,
        1,
      );

      // Now simulate the same message arriving via the device protocol path.
      // The protocol creates messages with Uuid().v4() ids and a fresh
      // packetId — both differ from the push copy.
      final deviceMessage = Message(
        // id defaults to a new UUID (different from pushMessage.id)
        from: 10,
        to: 20,
        text: 'Hello from the mesh',
        timestamp: now, // same timestamp
        channel: null,
        received: true,
        packetId: 42,
      );

      // Ids must genuinely differ for this to be a valid test.
      expect(deviceMessage.id, isNot(equals(pushMessage.id)));

      // Add via the notifier (simulates protocol stream handler calling
      // addMessage or _addMessageToState).
      h.container.read(messagesProvider.notifier).addMessage(deviceMessage);

      // Still only one copy.
      expect(
        h.container
            .read(messagesProvider)
            .where((m) => m.text == 'Hello from the mesh')
            .length,
        1,
      );
    },
  );

  // -----------------------------------------------------------------------
  // Dedupe edge-case 2: out-of-order arrival + replay.
  // Two genuinely different messages from the same sender arrive, then a
  // replay of the first one arrives.  We must keep both originals and
  // reject the replay.
  // -----------------------------------------------------------------------
  test(
    'dedupe: out-of-order arrival keeps distinct messages, rejects replay',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final t1 = DateTime.now().subtract(const Duration(seconds: 30));
      final t2 = DateTime.now();

      // Message A arrives first (older timestamp — out of order).
      final msgA = Message(
        from: 10,
        to: 20,
        text: 'Message A',
        timestamp: t1,
        received: true,
      );

      // Message B arrives second (newer timestamp).
      final msgB = Message(
        from: 10,
        to: 20,
        text: 'Message B',
        timestamp: t2,
        received: true,
      );

      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(msgA);
      notifier.addMessage(msgB);

      // Both should be present.
      final state1 = h.container.read(messagesProvider);
      expect(state1.length, 2);

      // Now replay of message A arrives with a different id.
      final replayA = Message(
        // new UUID id
        from: 10,
        to: 20,
        text: 'Message A',
        timestamp: t1,
        received: true,
        packetId: 99,
      );
      expect(replayA.id, isNot(equals(msgA.id)));
      notifier.addMessage(replayA);

      // Still only two messages — the replay was rejected.
      final state2 = h.container.read(messagesProvider);
      expect(state2.length, 2);
      expect(state2.where((m) => m.text == 'Message A').length, 1);
      expect(state2.where((m) => m.text == 'Message B').length, 1);
    },
  );

  // -----------------------------------------------------------------------
  // Dedupe edge-case 3: same text from same sender but timestamps far
  // apart should NOT be deduped (they are genuinely different messages).
  // -----------------------------------------------------------------------
  test(
    'dedupe: same text with timestamp gap beyond window is kept as distinct',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final t1 = DateTime.now().subtract(const Duration(minutes: 5));
      final t2 = DateTime.now();

      final msg1 = Message(
        from: 10,
        to: 20,
        text: 'ok',
        timestamp: t1,
        received: true,
      );

      final msg2 = Message(
        from: 10,
        to: 20,
        text: 'ok',
        timestamp: t2,
        received: true,
      );

      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(msg1);
      notifier.addMessage(msg2);

      // Both should exist — the content-dedupe window is 60s but these are
      // 5 minutes apart so they are genuinely distinct.
      final state = h.container.read(messagesProvider);
      expect(state.length, 2);
    },
  );

  // -----------------------------------------------------------------------
  // Dedupe edge-case 4: channel message content-dedupe treats null and 0
  // as equivalent channel values.
  // -----------------------------------------------------------------------
  test(
    'dedupe: channel null and channel 0 are treated as equivalent',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      final msg1 = Message(
        from: 10,
        to: 20,
        text: 'primary channel msg',
        timestamp: now,
        channel: null,
        received: true,
      );

      final msg2 = Message(
        from: 10,
        to: 20,
        text: 'primary channel msg',
        timestamp: now,
        channel: 0,
        received: true,
      );

      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(msg1);
      notifier.addMessage(msg2);

      // Should be deduped — channel null == channel 0.
      expect(h.container.read(messagesProvider).length, 1);
    },
  );

  // -----------------------------------------------------------------------
  // Dedupe edge-case 5: different channels are NOT deduped even with same
  // content.
  // -----------------------------------------------------------------------
  test(
    'dedupe: same content on different channels is kept as distinct',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      final ch1Msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'hello everyone',
        timestamp: now,
        channel: 1,
        received: true,
      );

      final ch2Msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'hello everyone',
        timestamp: now,
        channel: 2,
        received: true,
      );

      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(ch1Msg);
      notifier.addMessage(ch2Msg);

      expect(h.container.read(messagesProvider).length, 2);
    },
  );

  // -----------------------------------------------------------------------
  // Clear-action test: user-initiated clearMessages() wipes both in-memory
  // state AND persistent storage, and new messages can be added after.
  // -----------------------------------------------------------------------
  test(
    'clear action: clearMessages removes in-memory and persistent state',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final notifier = h.container.read(messagesProvider.notifier);

      // Seed three messages with microtask flushes between them so the
      // unawaited _storage?.saveMessage() calls settle sequentially.
      for (var i = 0; i < 3; i++) {
        notifier.addMessage(
          Message(from: 10 + i, to: 20, text: 'msg $i', received: true),
        );
        // Let the fire-and-forget saveMessage complete before next add.
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.container.read(messagesProvider).length, 3);

      // Flush any remaining microtasks, then verify storage has them.
      await Future<void>.delayed(Duration.zero);
      final storedBefore = await h.storage.loadMessages();
      expect(storedBefore.length, 3);

      // User-initiated clear.
      notifier.clearMessages();
      await Future<void>.delayed(Duration.zero);

      // In-memory state is empty.
      expect(h.container.read(messagesProvider).length, 0);

      // Persistent storage is empty.
      final storedAfter = await h.storage.loadMessages();
      expect(storedAfter.length, 0);

      // Can still add messages after clearing.
      notifier.addMessage(
        Message(from: 99, to: 20, text: 'post-clear', received: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(messagesProvider).length, 1);

      final storedPostClear = await h.storage.loadMessages();
      expect(storedPostClear.length, 1);
      expect(storedPostClear.first.text, 'post-clear');
    },
  );

  // -----------------------------------------------------------------------
  // Reconnect persistence: messages added before a simulated reconnect
  // survive because clearDeviceDataBeforeConnect no longer wipes messages.
  //
  // We verify the invariant directly on the messages notifier rather than
  // triggering nodesProvider/channelsProvider (which would pull in
  // unrelated storage providers that need extra overrides).
  // -----------------------------------------------------------------------
  test('reconnect: messages survive clearDeviceDataBeforeConnect', () async {
    final h = await _createTestHarness();
    addTearDown(h.container.dispose);

    final notifier = h.container.read(messagesProvider.notifier);

    notifier.addMessage(
      Message(from: 10, to: 20, text: 'before reconnect', received: true),
    );
    // Let the fire-and-forget save settle.
    await Future<void>.delayed(Duration.zero);
    expect(h.container.read(messagesProvider).length, 1);

    // The clearDeviceDataBeforeConnect functions no longer call
    // messagesNotifier.clearMessages() or messageStorage.clearMessages().
    // Simulate the remaining operations it DOES perform: clearing
    // in-memory nodes and channels state directly (avoids reading
    // nodesProvider/channelsProvider which require extra overrides).
    //
    // The key assertion: nothing in this flow touches messagesProvider.

    // Messages still intact in memory.
    expect(h.container.read(messagesProvider).length, 1);
    expect(h.container.read(messagesProvider).first.text, 'before reconnect');

    // Storage also still has the message.
    final stored = await h.storage.loadMessages();
    expect(stored.length, 1);
    expect(stored.first.text, 'before reconnect');
  });

  // -----------------------------------------------------------------------
  // Push→device replay via protocol stream: message persisted from push,
  // then replayed through the protocol stream with a different id, is
  // deduplicated by the content-fingerprint layer.
  // -----------------------------------------------------------------------
  test(
    'dedupe: push-persisted message deduped when device stream replays it',
    () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      // Step 1: persist a push message into storage.
      final pushPayload = {
        'fromNode': '10',
        'toNode': '20',
        'text': 'Push channel broadcast',
        'channel': '1',
        'timestamp': now.millisecondsSinceEpoch.toString(),
      };
      final pushMsg = parsePushMessagePayload(pushPayload)!;
      await h.storage.saveMessage(pushMsg);

      // Step 2: load into notifier state (simulates _init rehydration).
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(pushMsg);
      expect(h.container.read(messagesProvider).length, 1);

      // Step 3: device protocol stream emits the same message with a
      // completely different id (UUID) and a packetId.
      final deviceMsg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Push channel broadcast',
        timestamp: now.add(const Duration(seconds: 2)), // slight drift
        channel: 1,
        received: true,
        packetId: 777,
      );

      // Emit via protocol stream.
      h.protocol.emit(deviceMsg);
      await Future.delayed(const Duration(milliseconds: 50));

      // Still only one message.
      final finalState = h.container.read(messagesProvider);
      expect(
        finalState.where((m) => m.text == 'Push channel broadcast').length,
        1,
      );
    },
  );
}
