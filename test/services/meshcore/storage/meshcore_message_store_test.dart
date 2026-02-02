// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

// Helper to convert Uint8List to hex string
String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshCoreMessageStore', () {
    late MeshCoreMessageStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = MeshCoreMessageStore();
      await store.init();
    });

    group('contact messages', () {
      test('saves and loads contact messages', () async {
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contactKeyHex = _toHex(senderKey);
        final message = MeshCoreStoredMessage(
          id: 'msg-1',
          senderKey: senderKey,
          text: 'Hello MeshCore',
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MeshCoreMessageStatus.sent,
        );

        await store.addContactMessage(contactKeyHex, message);

        final loaded = await store.loadContactMessages(contactKeyHex);
        expect(loaded.length, equals(1));
        expect(loaded[0].id, equals('msg-1'));
        expect(loaded[0].text, equals('Hello MeshCore'));
        expect(loaded[0].isOutgoing, isTrue);
        expect(loaded[0].status, equals(MeshCoreMessageStatus.sent));
      });

      test('persists multiple messages in order', () async {
        const contactKeyHex =
            'aabbccdd00112233445566778899aabbccddeeff00112233445566778899aabb';
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final now = DateTime.now();

        for (int i = 1; i <= 5; i++) {
          final message = MeshCoreStoredMessage(
            id: 'msg-$i',
            senderKey: senderKey,
            text: 'Message $i',
            timestamp: now.add(Duration(minutes: i)),
            isOutgoing: i % 2 == 0,
          );
          await store.addContactMessage(contactKeyHex, message);
        }

        final loaded = await store.loadContactMessages(contactKeyHex);
        expect(loaded.length, equals(5));
        // Verify order preserved
        for (int i = 0; i < 5; i++) {
          expect(loaded[i].id, equals('msg-${i + 1}'));
        }
      });

      test('updates existing message status via addContactMessage', () async {
        const contactKeyHex =
            'deadbeef00112233445566778899aabbccddeeff00112233445566778899aabb';
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final message = MeshCoreStoredMessage(
          id: 'msg-update',
          senderKey: senderKey,
          text: 'Pending message',
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MeshCoreMessageStatus.pending,
        );

        await store.addContactMessage(contactKeyHex, message);

        // Update to delivered using addContactMessage (it updates if id exists)
        final updated = message.copyWith(
          status: MeshCoreMessageStatus.delivered,
          deliveredAt: DateTime.now(),
        );
        await store.addContactMessage(contactKeyHex, updated);

        final loaded = await store.loadContactMessages(contactKeyHex);
        expect(loaded.length, equals(1));
        expect(loaded[0].status, equals(MeshCoreMessageStatus.delivered));
        expect(loaded[0].deliveredAt, isNotNull);
      });

      test('isolates messages by contact', () async {
        const contactAHex =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const contactBHex =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final senderA = Uint8List.fromList(List.generate(32, (_) => 0xAA));
        final senderB = Uint8List.fromList(List.generate(32, (_) => 0xBB));

        await store.addContactMessage(
          contactAHex,
          MeshCoreStoredMessage(
            id: 'msg-a',
            senderKey: senderA,
            text: 'To contact A',
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        );

        await store.addContactMessage(
          contactBHex,
          MeshCoreStoredMessage(
            id: 'msg-b',
            senderKey: senderB,
            text: 'To contact B',
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        );

        final loadedA = await store.loadContactMessages(contactAHex);
        final loadedB = await store.loadContactMessages(contactBHex);

        expect(loadedA.length, equals(1));
        expect(loadedA[0].text, equals('To contact A'));

        expect(loadedB.length, equals(1));
        expect(loadedB[0].text, equals('To contact B'));
      });

      test('clears contact messages', () async {
        const contactKeyHex =
            'cafebabe00112233445566778899aabbccddeeff00112233445566778899aabb';
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        await store.addContactMessage(
          contactKeyHex,
          MeshCoreStoredMessage(
            id: 'msg-1',
            senderKey: senderKey,
            text: 'Message',
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        );

        await store.clearContactMessages(contactKeyHex);

        final loaded = await store.loadContactMessages(contactKeyHex);
        expect(loaded, isEmpty);
      });
    });

    group('channel messages', () {
      test('saves and loads channel messages', () async {
        const channelIndex = 3;
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final message = MeshCoreStoredMessage(
          id: 'ch-msg-1',
          senderKey: senderKey,
          text: 'Channel broadcast',
          timestamp: DateTime.now(),
          isOutgoing: false,
          isChannelMessage: true,
          channelIndex: channelIndex,
        );

        await store.addChannelMessage(channelIndex, message);

        final loaded = await store.loadChannelMessages(channelIndex);
        expect(loaded.length, equals(1));
        expect(loaded[0].id, equals('ch-msg-1'));
        expect(loaded[0].isChannelMessage, isTrue);
        expect(loaded[0].channelIndex, equals(channelIndex));
      });

      test('isolates messages by channel index', () async {
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));

        await store.addChannelMessage(
          0,
          MeshCoreStoredMessage(
            id: 'ch0-msg',
            senderKey: senderKey,
            text: 'Channel 0 message',
            timestamp: DateTime.now(),
            isOutgoing: false,
            isChannelMessage: true,
            channelIndex: 0,
          ),
        );

        await store.addChannelMessage(
          1,
          MeshCoreStoredMessage(
            id: 'ch1-msg',
            senderKey: senderKey,
            text: 'Channel 1 message',
            timestamp: DateTime.now(),
            isOutgoing: false,
            isChannelMessage: true,
            channelIndex: 1,
          ),
        );

        final channel0 = await store.loadChannelMessages(0);
        final channel1 = await store.loadChannelMessages(1);

        expect(channel0.length, equals(1));
        expect(channel0[0].text, equals('Channel 0 message'));

        expect(channel1.length, equals(1));
        expect(channel1[0].text, equals('Channel 1 message'));
      });
    });

    group('message serialization', () {
      test('serializes and deserializes all fields', () async {
        const contactKeyHex =
            'feedface00112233445566778899aabbccddeeff00112233445566778899aabb';
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final ackHash = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final pathBytes = Uint8List.fromList([0x01, 0x02, 0x03]);
        final now = DateTime.now();

        final message = MeshCoreStoredMessage(
          id: 'full-msg',
          senderKey: senderKey,
          text: 'Full message',
          timestamp: now,
          isOutgoing: true,
          status: MeshCoreMessageStatus.delivered,
          messageId: 'mid-123',
          retryCount: 2,
          expectedAckHash: ackHash,
          sentAt: now,
          deliveredAt: now.add(const Duration(seconds: 5)),
          tripTimeMs: 5000,
          pathLength: 3,
          pathBytes: pathBytes,
          isChannelMessage: false,
          channelIndex: null,
        );

        await store.addContactMessage(contactKeyHex, message);
        final loaded = (await store.loadContactMessages(contactKeyHex))[0];

        expect(loaded.id, equals('full-msg'));
        expect(loaded.senderKeyHex, equals(message.senderKeyHex));
        expect(loaded.text, equals('Full message'));
        expect(loaded.isOutgoing, isTrue);
        expect(loaded.status, equals(MeshCoreMessageStatus.delivered));
        expect(loaded.messageId, equals('mid-123'));
        expect(loaded.retryCount, equals(2));
        expect(loaded.expectedAckHash, equals(ackHash));
        expect(loaded.tripTimeMs, equals(5000));
        expect(loaded.pathLength, equals(3));
        expect(loaded.pathBytes, equals(pathBytes));
      });

      test('handles null optional fields', () async {
        const contactKeyHex =
            'badc0de000112233445566778899aabbccddeeff00112233445566778899aabb';
        final senderKey = Uint8List.fromList(List.generate(32, (i) => i));
        final message = MeshCoreStoredMessage(
          id: 'minimal-msg',
          senderKey: senderKey,
          text: 'Minimal',
          timestamp: DateTime.now(),
          isOutgoing: false,
        );

        await store.addContactMessage(contactKeyHex, message);
        final loaded = (await store.loadContactMessages(contactKeyHex))[0];

        expect(loaded.messageId, isNull);
        expect(loaded.expectedAckHash, isNull);
        expect(loaded.sentAt, isNull);
        expect(loaded.deliveredAt, isNull);
        expect(loaded.tripTimeMs, isNull);
        expect(loaded.pathLength, isNull);
        expect(loaded.pathBytes, isEmpty);
      });
    });

    group('clearAll', () {
      test('removes all messages', () async {
        const contactAHex =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const contactBHex =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final senderA = Uint8List.fromList(List.generate(32, (_) => 0xAA));
        final senderB = Uint8List.fromList(List.generate(32, (_) => 0xBB));

        await store.addContactMessage(
          contactAHex,
          MeshCoreStoredMessage(
            id: 'a',
            senderKey: senderA,
            text: 'A',
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        );
        await store.addContactMessage(
          contactBHex,
          MeshCoreStoredMessage(
            id: 'b',
            senderKey: senderB,
            text: 'B',
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        );
        await store.addChannelMessage(
          0,
          MeshCoreStoredMessage(
            id: 'ch',
            senderKey: senderA,
            text: 'Channel',
            timestamp: DateTime.now(),
            isOutgoing: true,
            isChannelMessage: true,
            channelIndex: 0,
          ),
        );

        await store.clearAll();

        expect(await store.loadContactMessages(contactAHex), isEmpty);
        expect(await store.loadContactMessages(contactBHex), isEmpty);
        expect(await store.loadChannelMessages(0), isEmpty);
      });
    });
  });

  group('MeshCoreStoredMessage', () {
    test('copyWith preserves unchanged fields', () {
      final original = MeshCoreStoredMessage(
        id: 'test',
        senderKey: Uint8List.fromList([1, 2, 3]),
        text: 'Original',
        timestamp: DateTime(2024, 1, 1),
        isOutgoing: true,
        status: MeshCoreMessageStatus.pending,
      );

      final updated = original.copyWith(
        status: MeshCoreMessageStatus.delivered,
      );

      expect(updated.id, equals('test'));
      expect(updated.text, equals('Original'));
      expect(updated.isOutgoing, isTrue);
      expect(updated.status, equals(MeshCoreMessageStatus.delivered));
    });

    test('senderKeyHex returns correct hex string', () {
      final message = MeshCoreStoredMessage(
        id: 'test',
        senderKey: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
        text: 'Test',
        timestamp: DateTime.now(),
        isOutgoing: false,
      );

      expect(message.senderKeyHex, equals('deadbeef'));
    });
  });
}
