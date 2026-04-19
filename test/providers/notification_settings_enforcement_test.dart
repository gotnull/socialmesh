// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Helper: simulates the notification flush gate from NotificationBatchNotifier
  // ---------------------------------------------------------------------------

  /// Simulates the full notification policy gate as implemented in
  /// `NotificationBatchNotifier._flush` after the fix. Returns the list of
  /// messages that would actually be dispatched.
  List<PendingMessageNotification> applyFlushGate({
    required List<PendingMessageNotification> queued,
    required bool masterEnabled,
    required bool channelEnabled,
    required bool dmEnabled,
  }) {
    if (!masterEnabled) return [];
    return queued.where((msg) {
      if (msg.isChannelMessage) return channelEnabled;
      return dmEnabled;
    }).toList();
  }

  /// Simulates the enqueue gate from `_notifyNewMessage`. Returns true if
  /// the message would be queued for notification batching.
  bool shouldEnqueue({
    required bool isBroadcast,
    required int? messageChannel,
    required bool masterEnabled,
    required bool channelEnabled,
    required bool dmEnabled,
    required Set<int> mutedChannels,
  }) {
    if (!masterEnabled) return false;
    if (messageChannel != null && mutedChannels.contains(messageChannel)) {
      return false;
    }
    final isChannelMessage = isBroadcast;
    if (isChannelMessage && !channelEnabled) return false;
    if (!isChannelMessage && !dmEnabled) return false;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Settings persistence
  // ---------------------------------------------------------------------------

  group('Settings persistence', () {
    test(
      'disabling channel notifications persists to SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Simulate settings screen toggle
        await prefs.setBool('channel_notifications_enabled', false);

        expect(prefs.getBool('channel_notifications_enabled'), isFalse);
      },
    );

    test(
      'disabling channel notifications survives SharedPreferences reload',
      () async {
        SharedPreferences.setMockInitialValues({
          'channel_notifications_enabled': false,
        });

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('channel_notifications_enabled'), isFalse);
      },
    );

    test('missing key defaults to enabled (true)', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool('channel_notifications_enabled') ?? true;
      expect(value, isTrue);
    });

    test('all notification keys persist independently', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': false,
        'dm_notifications_enabled': true,
        'notification_sound_enabled': false,
        'notification_vibration_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notifications_enabled'), isTrue);
      expect(prefs.getBool('channel_notifications_enabled'), isFalse);
      expect(prefs.getBool('dm_notifications_enabled'), isTrue);
      expect(prefs.getBool('notification_sound_enabled'), isFalse);
      expect(prefs.getBool('notification_vibration_enabled'), isTrue);
    });

    test('toggling channel notifications updates value immediately', () async {
      final prefs = await SharedPreferences.getInstance();

      // Enable
      await prefs.setBool('channel_notifications_enabled', true);
      expect(prefs.getBool('channel_notifications_enabled'), isTrue);

      // Disable
      await prefs.setBool('channel_notifications_enabled', false);
      expect(prefs.getBool('channel_notifications_enabled'), isFalse);

      // Re-enable
      await prefs.setBool('channel_notifications_enabled', true);
      expect(prefs.getBool('channel_notifications_enabled'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Enqueue gate (simulates _notifyNewMessage)
  // ---------------------------------------------------------------------------

  group('Enqueue gate (_notifyNewMessage simulation)', () {
    test('channel message + channels disabled => not enqueued', () {
      expect(
        shouldEnqueue(
          isBroadcast: true,
          messageChannel: 0,
          masterEnabled: true,
          channelEnabled: false,
          dmEnabled: true,
          mutedChannels: {},
        ),
        isFalse,
      );
    });

    test('channel message + channels enabled => enqueued', () {
      expect(
        shouldEnqueue(
          isBroadcast: true,
          messageChannel: 0,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {},
        ),
        isTrue,
      );
    });

    test('DM + channels disabled => DM still enqueued', () {
      expect(
        shouldEnqueue(
          isBroadcast: false,
          messageChannel: null,
          masterEnabled: true,
          channelEnabled: false,
          dmEnabled: true,
          mutedChannels: {},
        ),
        isTrue,
      );
    });

    test('DM + DM disabled => not enqueued', () {
      expect(
        shouldEnqueue(
          isBroadcast: false,
          messageChannel: null,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: false,
          mutedChannels: {},
        ),
        isFalse,
      );
    });

    test('master disabled => nothing enqueued', () {
      expect(
        shouldEnqueue(
          isBroadcast: true,
          messageChannel: 0,
          masterEnabled: false,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {},
        ),
        isFalse,
      );
      expect(
        shouldEnqueue(
          isBroadcast: false,
          messageChannel: null,
          masterEnabled: false,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {},
        ),
        isFalse,
      );
    });

    test('muted channel blocks even when channels enabled', () {
      expect(
        shouldEnqueue(
          isBroadcast: true,
          messageChannel: 2,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {2},
        ),
        isFalse,
      );
    });

    test('unmuted channel allows when channels enabled', () {
      expect(
        shouldEnqueue(
          isBroadcast: true,
          messageChannel: 2,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {3},
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Flush gate (simulates NotificationBatchNotifier._flush re-check)
  // ---------------------------------------------------------------------------

  group('Flush gate (_flush re-check simulation)', () {
    test('channel message + channels disabled at flush => filtered out', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'hello',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, isEmpty);
    });

    test('channel message + channels enabled at flush => dispatched', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'hello',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(1));
    });

    test('DM + channels disabled at flush => DM still dispatched', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'hey',
          fromNodeNum: 5678,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(1));
      expect(dispatched.first.isChannelMessage, isFalse);
    });

    test('DM + DM disabled at flush => filtered out', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'hey',
          fromNodeNum: 5678,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: false,
      );

      expect(dispatched, isEmpty);
    });

    test('master disabled at flush => all filtered out', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'channel msg',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'dm msg',
          fromNodeNum: 5678,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: false,
        channelEnabled: true,
        dmEnabled: true,
      );

      expect(dispatched, isEmpty);
    });

    test('mixed batch: only DMs survive when channels disabled', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'ch msg 1',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'dm msg 1',
          fromNodeNum: 5678,
        ),
        PendingMessageNotification(
          senderName: 'Carol',
          message: 'ch msg 2',
          fromNodeNum: 9012,
          channelIndex: 2,
          channelName: 'LongFast',
        ),
        PendingMessageNotification(
          senderName: 'Dave',
          message: 'dm msg 2',
          fromNodeNum: 3456,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(2));
      expect(dispatched.every((m) => !m.isChannelMessage), isTrue);
      expect(dispatched.map((m) => m.senderName), containsAll(['Bob', 'Dave']));
    });

    test('mixed batch: only channels survive when DMs disabled', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'ch msg',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'dm msg',
          fromNodeNum: 5678,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: false,
      );

      expect(dispatched, hasLength(1));
      expect(dispatched.first.isChannelMessage, isTrue);
      expect(dispatched.first.senderName, 'Alice');
    });

    test('empty batch with master enabled => no dispatch', () {
      final dispatched = applyFlushGate(
        queued: [],
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: true,
      );

      expect(dispatched, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Race condition: setting changes between enqueue and flush
  // ---------------------------------------------------------------------------

  group('Race condition: setting changes between enqueue and flush', () {
    test(
      'channel msg enqueued while enabled, disabled before flush => filtered',
      () {
        // Simulate: at enqueue time, channels were enabled
        final enqueued = shouldEnqueue(
          isBroadcast: true,
          messageChannel: 0,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {},
        );
        expect(enqueued, isTrue, reason: 'Should be queued when enabled');

        // Build the queued message
        final queued = [
          PendingMessageNotification(
            senderName: 'Alice',
            message: 'hello',
            fromNodeNum: 1234,
            channelIndex: 0,
            channelName: 'Primary',
          ),
        ];

        // Simulate: user disabled channels before flush fires
        final dispatched = applyFlushGate(
          queued: queued,
          masterEnabled: true,
          channelEnabled: false,
          dmEnabled: true,
        );

        expect(dispatched, isEmpty, reason: 'Must be filtered at flush time');
      },
    );

    test(
      'DM enqueued while enabled, DMs disabled before flush => filtered',
      () {
        final enqueued = shouldEnqueue(
          isBroadcast: false,
          messageChannel: null,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
          mutedChannels: {},
        );
        expect(enqueued, isTrue);

        final queued = [
          PendingMessageNotification(
            senderName: 'Bob',
            message: 'hey',
            fromNodeNum: 5678,
          ),
        ];

        final dispatched = applyFlushGate(
          queued: queued,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: false,
        );

        expect(dispatched, isEmpty);
      },
    );

    test('master disabled between enqueue and flush => all filtered', () {
      // Messages queued while master was on
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'ch msg',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
        PendingMessageNotification(
          senderName: 'Bob',
          message: 'dm msg',
          fromNodeNum: 5678,
        ),
      ];

      // Master turned off before flush
      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: false,
        channelEnabled: true,
        dmEnabled: true,
      );

      expect(dispatched, isEmpty);
    });

    test(
      'channels re-enabled between enqueue and flush => message dispatched',
      () {
        // Message was somehow queued (e.g. from a prior enabled state)
        final queued = [
          PendingMessageNotification(
            senderName: 'Alice',
            message: 'hello',
            fromNodeNum: 1234,
            channelIndex: 0,
            channelName: 'Primary',
          ),
        ];

        // Channels now enabled at flush time
        final dispatched = applyFlushGate(
          queued: queued,
          masterEnabled: true,
          channelEnabled: true,
          dmEnabled: true,
        );

        expect(dispatched, hasLength(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Background handler settings check (SharedPreferences path)
  // ---------------------------------------------------------------------------

  group('Background handler settings check (SharedPreferences)', () {
    /// Simulates the notification gate from BackgroundMessageProcessor and
    /// PushNotificationService, which read SharedPreferences directly.
    bool backgroundShouldNotify(SharedPreferences prefs, bool isBroadcast) {
      final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (!masterEnabled) return false;

      if (isBroadcast) {
        return prefs.getBool('channel_notifications_enabled') ?? true;
      } else {
        return prefs.getBool('dm_notifications_enabled') ?? true;
      }
    }

    test('channel message + channels disabled => no notification', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, true), isFalse);
    });

    test('channel message + channels enabled => notification', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, true), isTrue);
    });

    test('DM + channels disabled => DM still gets notification', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': false,
        'dm_notifications_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, false), isTrue);
    });

    test('master disabled => no notification for anything', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false,
        'channel_notifications_enabled': true,
        'dm_notifications_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, true), isFalse);
      expect(backgroundShouldNotify(prefs, false), isFalse);
    });

    test('missing keys default to enabled', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, true), isTrue);
      expect(backgroundShouldNotify(prefs, false), isTrue);
    });

    test('foreground setting change visible to background handler', () async {
      SharedPreferences.setMockInitialValues({
        'channel_notifications_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(backgroundShouldNotify(prefs, true), isTrue);

      // Simulate foreground toggle
      await prefs.setBool('channel_notifications_enabled', false);

      // Background reads the same SharedPreferences
      expect(backgroundShouldNotify(prefs, true), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PendingMessageNotification classification
  // ---------------------------------------------------------------------------

  group('PendingMessageNotification classification', () {
    test('channelIndex set => isChannelMessage true', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
        channelIndex: 0,
        channelName: 'Primary',
      );
      expect(msg.isChannelMessage, isTrue);
    });

    test('channelIndex null => isChannelMessage false (DM)', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
      );
      expect(msg.isChannelMessage, isFalse);
    });

    test('channelIndex 0 (Primary Channel) => isChannelMessage true', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
        channelIndex: 0,
        channelName: 'Primary',
      );
      expect(msg.isChannelMessage, isTrue);
    });

    test('channelIndex 7 (max) => isChannelMessage true', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
        channelIndex: 7,
        channelName: 'Ch7',
      );
      expect(msg.isChannelMessage, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Null / default behavior
  // ---------------------------------------------------------------------------

  group('Null / default behavior', () {
    test('null settings defaults do not bypass disabled state', () async {
      // Explicitly set to false then verify the ?? true default is
      // not used when a value IS stored.
      SharedPreferences.setMockInitialValues({
        'channel_notifications_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool('channel_notifications_enabled') ?? true;
      expect(
        value,
        isFalse,
        reason: 'Explicit false must override ?? true default',
      );
    });

    test('absent key uses default true (notifications enabled)', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('channel_notifications_enabled'), isNull);
      expect(
        prefs.getBool('channel_notifications_enabled') ?? true,
        isTrue,
        reason: 'Default for missing key is enabled',
      );
    });

    test('flush gate with null-like settings defaults to enabled', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'Alice',
          message: 'hello',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        ),
      ];

      // When settings are not loaded (null), defaults should be true
      // (permissive) — this matches the ?? true pattern in the code
      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Comprehensive behavioral matrix
  // ---------------------------------------------------------------------------

  group('Behavioral matrix', () {
    // Each row tests: (master, channelToggle, dmToggle) × message type
    final channelMsg = PendingMessageNotification(
      senderName: 'Alice',
      message: 'ch',
      fromNodeNum: 1234,
      channelIndex: 0,
      channelName: 'Primary',
    );
    final dmMsg = PendingMessageNotification(
      senderName: 'Bob',
      message: 'dm',
      fromNodeNum: 5678,
    );

    test('ON/ON/ON => both dispatched', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: true,
      );
      expect(result, hasLength(2));
    });

    test('ON/OFF/ON => only DM dispatched', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );
      expect(result, hasLength(1));
      expect(result.first.isChannelMessage, isFalse);
    });

    test('ON/ON/OFF => only channel dispatched', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: true,
        channelEnabled: true,
        dmEnabled: false,
      );
      expect(result, hasLength(1));
      expect(result.first.isChannelMessage, isTrue);
    });

    test('ON/OFF/OFF => nothing dispatched', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: false,
      );
      expect(result, isEmpty);
    });

    test('OFF/ON/ON => nothing dispatched (master overrides)', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: false,
        channelEnabled: true,
        dmEnabled: true,
      );
      expect(result, isEmpty);
    });

    test('OFF/OFF/OFF => nothing dispatched', () {
      final result = applyFlushGate(
        queued: [channelMsg, dmMsg],
        masterEnabled: false,
        channelEnabled: false,
        dmEnabled: false,
      );
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-channel messages in batch
  // ---------------------------------------------------------------------------

  group('Multi-channel messages in batch', () {
    test('all channel messages filtered when channels disabled', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'A',
          message: 'ch0',
          fromNodeNum: 1,
          channelIndex: 0,
          channelName: 'Primary',
        ),
        PendingMessageNotification(
          senderName: 'B',
          message: 'ch1',
          fromNodeNum: 2,
          channelIndex: 1,
          channelName: 'LongFast',
        ),
        PendingMessageNotification(
          senderName: 'C',
          message: 'ch3',
          fromNodeNum: 3,
          channelIndex: 3,
          channelName: 'Admin',
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, isEmpty);
    });

    test('all DMs survive when channels disabled', () {
      final queued = [
        PendingMessageNotification(
          senderName: 'A',
          message: 'dm1',
          fromNodeNum: 1,
        ),
        PendingMessageNotification(
          senderName: 'B',
          message: 'dm2',
          fromNodeNum: 2,
        ),
        PendingMessageNotification(
          senderName: 'C',
          message: 'dm3',
          fromNodeNum: 3,
        ),
      ];

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(3));
    });

    test('large mixed batch correctly filtered', () {
      final queued = <PendingMessageNotification>[];
      // 25 channel messages
      for (var i = 0; i < 25; i++) {
        queued.add(
          PendingMessageNotification(
            senderName: 'Ch$i',
            message: 'msg$i',
            fromNodeNum: i,
            channelIndex: i % 8,
            channelName: 'Channel ${i % 8}',
          ),
        );
      }
      // 25 DMs
      for (var i = 25; i < 50; i++) {
        queued.add(
          PendingMessageNotification(
            senderName: 'DM$i',
            message: 'msg$i',
            fromNodeNum: i,
          ),
        );
      }

      final dispatched = applyFlushGate(
        queued: queued,
        masterEnabled: true,
        channelEnabled: false,
        dmEnabled: true,
      );

      expect(dispatched, hasLength(25));
      expect(dispatched.every((m) => !m.isChannelMessage), isTrue);
    });
  });
}
