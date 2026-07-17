// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The iOS app-icon unread badge must ride inside the notification
// payload itself (DarwinNotificationDetails.badgeNumber). While the app
// is backgrounded the process can be re-suspended as soon as the
// notification is handed to the system, so a badge applied only via a
// follow-up 'socialmesh/badge' platform-channel call is not guaranteed
// to ever run. These tests pin the payload-level invariant for every
// message-notification path (Meshtastic DM/channel, MeshCore
// DM/channel, batched summaries) by intercepting the plugin's method
// channel and inspecting the serialized Darwin details.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const pluginChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const badgeChannel = MethodChannel('socialmesh/badge');

  final shownCalls = <MethodCall>[];

  int? badgeOf(MethodCall call) {
    final args = call.arguments as Map<Object?, Object?>;
    final details = args['platformSpecifics'] as Map<Object?, Object?>?;
    return details?['badgeNumber'] as int?;
  }

  setUpAll(() async {
    // Route the plugin through its iOS implementation so show() serializes
    // the Darwin details this test asserts on.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();

    binding.defaultBinaryMessenger.setMockMethodCallHandler(pluginChannel, (
      call,
    ) async {
      if (call.method == 'show') shownCalls.add(call);
      if (call.method == 'initialize' || call.method == 'requestPermissions') {
        return true;
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      badgeChannel,
      (call) async => null,
    );

    await NotificationService().initialize();
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pluginChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(badgeChannel, null);
  });

  setUp(() async {
    // clearBadge resets the in-memory unread counter so every test starts
    // from a badge value of zero.
    await NotificationService().clearBadge();
    shownCalls.clear();
  });

  test(
    'Meshtastic DM notification carries badgeNumber in its payload',
    () async {
      await NotificationService().showNewMessageNotification(
        senderName: 'Alice',
        senderShortName: 'ALCE',
        message: 'hello',
        fromNodeNum: 0x1234,
      );

      expect(shownCalls, hasLength(1));
      expect(badgeOf(shownCalls.single), 1);
    },
  );

  test('Meshtastic channel notification carries badgeNumber', () async {
    await NotificationService().showChannelMessageNotification(
      senderName: 'Alice',
      senderShortName: 'ALCE',
      channelName: 'Primary',
      message: 'hello channel',
      channelIndex: 0,
      fromNodeNum: 0x1234,
    );

    expect(shownCalls, hasLength(1));
    expect(badgeOf(shownCalls.single), 1);
  });

  test('MeshCore DM notification carries badgeNumber', () async {
    await NotificationService().showMeshCoreContactMessageNotification(
      senderName: 'Bob',
      pubKeyHex:
          '79426d8d00112233445566778899aabbccddeeff'
          '00112233445566778899aabb',
      message: 'meshcore dm',
    );

    expect(shownCalls, hasLength(1));
    expect(badgeOf(shownCalls.single), 1);
  });

  test('MeshCore channel notification carries badgeNumber', () async {
    await NotificationService().showMeshCoreChannelMessageNotification(
      senderName: 'Bob',
      channelName: 'Public',
      channelIndex: 0,
      senderPrefixHex: '79426d8d',
      message: 'meshcore channel',
    );

    expect(shownCalls, hasLength(1));
    expect(badgeOf(shownCalls.single), 1);
  });

  test('successive notifications increment the payload badge', () async {
    await NotificationService().showNewMessageNotification(
      senderName: 'Alice',
      senderShortName: 'ALCE',
      message: 'first',
      fromNodeNum: 0x1234,
    );
    await NotificationService().showChannelMessageNotification(
      senderName: 'Alice',
      senderShortName: 'ALCE',
      channelName: 'Primary',
      message: 'second',
      channelIndex: 0,
      fromNodeNum: 0x1234,
    );

    expect(shownCalls, hasLength(2));
    expect(badgeOf(shownCalls[0]), 1);
    expect(badgeOf(shownCalls[1]), 2);
  });

  test('batched summaries carry the accumulated badge count', () async {
    await NotificationService().showBatchedMessagesNotification(
      messages: [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'dm one',
          fromNodeNum: 1,
        ),
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'dm two',
          fromNodeNum: 2,
        ),
        PendingMessageNotification(
          senderName: 'Carol',
          message: 'ch one',
          fromNodeNum: 3,
          channelIndex: 0,
          channelName: 'Primary',
        ),
      ],
    );

    // One batched DM summary (2 unread) then one channel summary (+1).
    expect(shownCalls, hasLength(2));
    expect(badgeOf(shownCalls[0]), 2);
    expect(badgeOf(shownCalls[1]), 3);
  });
}
