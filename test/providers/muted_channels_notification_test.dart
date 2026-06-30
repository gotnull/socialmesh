// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/muted_channels_provider.dart';
import 'package:socialmesh/services/notifications/channel_mute_prefs.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences.setMockInitialValues({});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // MutedChannelsNotifier — provider layer
  // ---------------------------------------------------------------------------

  group('MutedChannelsNotifier', () {
    test('initial state is empty set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final muted = container.read(mutedChannelsProvider);
      expect(muted, isEmpty);
    });

    test('toggleMute adds channel index to set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      final result = await notifier.toggleMute(0);

      expect(result, isTrue);
      expect(container.read(mutedChannelsProvider), contains(0));
    });

    test('toggleMute removes channel index when already muted', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(2);
      expect(container.read(mutedChannelsProvider), contains(2));

      final result = await notifier.toggleMute(2);
      expect(result, isFalse);
      expect(container.read(mutedChannelsProvider), isNot(contains(2)));
    });

    test('isMuted returns correct state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      expect(notifier.isMuted(0), isFalse);

      await notifier.toggleMute(0);
      expect(notifier.isMuted(0), isTrue);

      await notifier.toggleMute(0);
      expect(notifier.isMuted(0), isFalse);
    });

    test('multiple channels can be independently muted', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(0);
      await notifier.toggleMute(2);
      await notifier.toggleMute(5);

      final muted = container.read(mutedChannelsProvider);
      expect(muted, containsAll([0, 2, 5]));
      expect(muted, isNot(contains(1)));
      expect(muted, isNot(contains(3)));
    });

    test('mute state persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(0);
      await notifier.toggleMute(3);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('muted_channel_indices');
      expect(stored, isNotNull);
      final storedInts = stored!
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      expect(storedInts, containsAll([0, 3]));
    });

    test('mute state loads from SharedPreferences on build', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['0', '4', '7'],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The notifier uses lazy async load; read + pump to let it settle.
      container.read(mutedChannelsProvider);
      await Future<void>.delayed(Duration.zero);

      final muted = container.read(mutedChannelsProvider);
      expect(muted, containsAll([0, 4, 7]));
    });

    test('isChannelMutedProvider family returns correct value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(2);

      expect(container.read(isChannelMutedProvider(2)), isTrue);
      expect(container.read(isChannelMutedProvider(0)), isFalse);
      expect(container.read(isChannelMutedProvider(1)), isFalse);
    });

    test('unmuting persists removal to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['0', '3'],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mutedChannelsProvider);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(0); // unmute channel 0

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('muted_channel_indices');
      final storedInts = stored!
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      expect(storedInts, contains(3));
      expect(storedInts, isNot(contains(0)));
    });
  });

  // ---------------------------------------------------------------------------
  // Notification gate logic — the isChannelMessage heuristic bug
  // ---------------------------------------------------------------------------

  group('Channel 0 mute gate (root cause)', () {
    // The bug: `isChannelMessage = channel != null && channel > 0`
    // excludes channel 0 from the mute check.  These tests prove
    // that a simple `channel != null` check covers all channels.

    test('channel 0 is excluded by the old channel > 0 heuristic', () {
      // Reproduces the broken classification
      bool oldIsChannelMessage(int? channel) => channel != null && channel > 0;

      expect(oldIsChannelMessage(0), isFalse, reason: 'channel 0 was excluded');
      expect(oldIsChannelMessage(1), isTrue);
      expect(oldIsChannelMessage(null), isFalse);
    });

    test('channel != null check covers all channels including 0', () {
      // The fix: mute check uses `channel != null` (no > 0 filter)
      bool shouldCheckMute(int? channel) => channel != null;

      expect(shouldCheckMute(0), isTrue, reason: 'channel 0 must be checked');
      expect(shouldCheckMute(1), isTrue);
      expect(shouldCheckMute(5), isTrue);
      expect(shouldCheckMute(null), isFalse);
    });

    test('muted channel 0 blocks notification (simulated gate)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(0);

      // Simulate the fixed notification gate
      const messageChannel = 0;
      final mutedChannels = container.read(mutedChannelsProvider);

      final shouldSuppress = mutedChannels.contains(messageChannel);
      expect(shouldSuppress, isTrue);
    });

    test('unmuted channel 0 allows notification (simulated gate)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const messageChannel = 0;
      final mutedChannels = container.read(mutedChannelsProvider);

      final shouldSuppress = mutedChannels.contains(messageChannel);
      expect(shouldSuppress, isFalse);
    });

    test('muted channel 3 blocks notification on channel 3', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(mutedChannelsProvider.notifier).toggleMute(3);

      const messageChannel = 3;
      final mutedChannels = container.read(mutedChannelsProvider);

      expect(mutedChannels.contains(messageChannel), isTrue);
    });

    test('muted channel 3 does NOT block notification on channel 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(mutedChannelsProvider.notifier).toggleMute(3);

      const messageChannel = 0;
      final mutedChannels = container.read(mutedChannelsProvider);

      expect(mutedChannels.contains(messageChannel), isFalse);
    });

    test('mixed mute states: channels behave independently', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);
      await notifier.toggleMute(0); // mute primary
      await notifier.toggleMute(2); // mute channel 2
      // channels 1, 3, 4 remain unmuted

      final muted = container.read(mutedChannelsProvider);

      expect(muted.contains(0), isTrue, reason: 'channel 0 muted');
      expect(muted.contains(1), isFalse, reason: 'channel 1 unmuted');
      expect(muted.contains(2), isTrue, reason: 'channel 2 muted');
      expect(muted.contains(3), isFalse, reason: 'channel 3 unmuted');
      expect(muted.contains(4), isFalse, reason: 'channel 4 unmuted');
    });

    test('toggle mute updates behavior immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mutedChannelsProvider.notifier);

      // Initially unmuted — notification allowed
      expect(container.read(mutedChannelsProvider).contains(0), isFalse);

      // Mute — notification blocked immediately
      await notifier.toggleMute(0);
      expect(container.read(mutedChannelsProvider).contains(0), isTrue);

      // Unmute — notification allowed immediately
      await notifier.toggleMute(0);
      expect(container.read(mutedChannelsProvider).contains(0), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Background handler mute gate (SharedPreferences path)
  // ---------------------------------------------------------------------------

  group('Background handler mute gate (SharedPreferences)', () {
    /// Simulates the mute-check logic from BackgroundMessageProcessor and
    /// PushNotificationService, which read SharedPreferences directly
    /// (no Riverpod) because they may run outside the main isolate.
    bool backgroundMuteCheck(SharedPreferences prefs, int? messageChannel) {
      if (messageChannel == null) return false;
      final mutedRaw = prefs.getStringList('muted_channel_indices');
      if (mutedRaw == null) return false;
      final mutedSet = mutedRaw
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      return mutedSet.contains(messageChannel);
    }

    test('muted channel 0 blocks notification in background path', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['0'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(backgroundMuteCheck(prefs, 0), isTrue);
    });

    test('unmuted channel 0 allows notification in background path', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['2', '5'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(backgroundMuteCheck(prefs, 0), isFalse);
    });

    test('no muted channels allows all notifications', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(backgroundMuteCheck(prefs, 0), isFalse);
      expect(backgroundMuteCheck(prefs, 1), isFalse);
      expect(backgroundMuteCheck(prefs, 5), isFalse);
    });

    test('null channel skips mute check (non-mesh notification)', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['0', '1', '2'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(backgroundMuteCheck(prefs, null), isFalse);
    });

    test('multiple muted channels checked independently', () async {
      SharedPreferences.setMockInitialValues({
        'muted_channel_indices': ['0', '3', '7'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(backgroundMuteCheck(prefs, 0), isTrue);
      expect(backgroundMuteCheck(prefs, 1), isFalse);
      expect(backgroundMuteCheck(prefs, 3), isTrue);
      expect(backgroundMuteCheck(prefs, 5), isFalse);
      expect(backgroundMuteCheck(prefs, 7), isTrue);
    });

    test(
      'SharedPreferences update from foreground is visible to background',
      () async {
        SharedPreferences.setMockInitialValues({});

        // Foreground mutes channel 0 (via MutedChannelsNotifier)
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(mutedChannelsProvider.notifier).toggleMute(0);

        // Background reads SharedPreferences directly
        final prefs = await SharedPreferences.getInstance();
        expect(backgroundMuteCheck(prefs, 0), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PendingMessageNotification.isChannelMessage (batch classification)
  // ---------------------------------------------------------------------------

  group('PendingMessageNotification.isChannelMessage', () {
    test('channelIndex > 0 is channel message', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
        channelIndex: 1,
        channelName: 'LongFast',
      );
      expect(msg.isChannelMessage, isTrue);
    });

    test(
      'channelIndex == 0 IS classified as channel message (Primary Channel)',
      () {
        // Primary Channel (index 0) is a channel message — the old `> 0`
        // heuristic was a bug. Fixed: isChannelMessage = channelIndex != null.
        final msg = PendingMessageNotification(
          senderName: 'Test',
          message: 'hello',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        );
        expect(msg.isChannelMessage, isTrue);
      },
    );

    test('null channelIndex is not channel message', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
      );
      expect(msg.isChannelMessage, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-end mute gate simulation
  // ---------------------------------------------------------------------------

  group('End-to-end mute gate simulation', () {
    /// Simulates the fixed notification gate from _notifyNewMessage.
    /// Returns true if the notification should be SHOWN (not suppressed).
    bool shouldNotify({
      required Set<int> mutedChannels,
      required int? messageChannel,
      required bool notificationsEnabled,
    }) {
      // Master toggle
      if (!notificationsEnabled) return false;

      // Per-channel mute — the fix: runs for ALL channels including 0
      if (messageChannel != null && mutedChannels.contains(messageChannel)) {
        return false;
      }

      return true;
    }

    test('muted channel 0, master on → blocked', () {
      expect(
        shouldNotify(
          mutedChannels: {0},
          messageChannel: 0,
          notificationsEnabled: true,
        ),
        isFalse,
      );
    });

    test('unmuted channel 0, master on → allowed', () {
      expect(
        shouldNotify(
          mutedChannels: {},
          messageChannel: 0,
          notificationsEnabled: true,
        ),
        isTrue,
      );
    });

    test('muted channel 2, message on channel 2 → blocked', () {
      expect(
        shouldNotify(
          mutedChannels: {2},
          messageChannel: 2,
          notificationsEnabled: true,
        ),
        isFalse,
      );
    });

    test('muted channel 2, message on channel 0 → allowed', () {
      expect(
        shouldNotify(
          mutedChannels: {2},
          messageChannel: 0,
          notificationsEnabled: true,
        ),
        isTrue,
      );
    });

    test('master toggle off → blocked regardless of mute', () {
      expect(
        shouldNotify(
          mutedChannels: {},
          messageChannel: 0,
          notificationsEnabled: false,
        ),
        isFalse,
      );
    });

    test('null channel (non-mesh) → allowed even with muted channels', () {
      expect(
        shouldNotify(
          mutedChannels: {0, 1, 2, 3, 4, 5, 6, 7},
          messageChannel: null,
          notificationsEnabled: true,
        ),
        isTrue,
      );
    });

    test('all channels muted → all channel messages blocked', () {
      for (var ch = 0; ch < 8; ch++) {
        expect(
          shouldNotify(
            mutedChannels: {0, 1, 2, 3, 4, 5, 6, 7},
            messageChannel: ch,
            notificationsEnabled: true,
          ),
          isFalse,
          reason: 'channel $ch should be blocked',
        );
      }
    });

    test('no channels muted → all channel messages allowed', () {
      for (var ch = 0; ch < 8; ch++) {
        expect(
          shouldNotify(
            mutedChannels: {},
            messageChannel: ch,
            notificationsEnabled: true,
          ),
          isTrue,
          reason: 'channel $ch should be allowed',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Persistence across app restart
  // ---------------------------------------------------------------------------

  group('Persistence across app restart', () {
    test('mute survives container disposal and recreation', () async {
      // First "app session" — mute channel 0
      SharedPreferences.setMockInitialValues({});
      final container1 = ProviderContainer();
      await container1.read(mutedChannelsProvider.notifier).toggleMute(0);
      await container1.read(mutedChannelsProvider.notifier).toggleMute(3);
      container1.dispose();

      // Second "app session" — should restore muted channels from prefs
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      // Trigger lazy load
      container2.read(mutedChannelsProvider);
      await Future<void>.delayed(Duration.zero);

      final muted = container2.read(mutedChannelsProvider);
      expect(muted, containsAll([0, 3]));
    });
  });

  // ---------------------------------------------------------------------------
  // Shared authoritative helper: isChannelMutedInPrefs (channel_mute_prefs.dart)
  // ---------------------------------------------------------------------------

  group('isChannelMutedInPrefs (shared helper)', () {
    test('missing key returns false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(isChannelMutedInPrefs(prefs, 0), isFalse);
    });

    test('channel present in persisted set returns true', () async {
      SharedPreferences.setMockInitialValues({
        mutedChannelsPrefKey: ['0', '3', '7'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(isChannelMutedInPrefs(prefs, 3), isTrue);
      expect(isChannelMutedInPrefs(prefs, 7), isTrue);
    });

    test('channel absent from persisted set returns false', () async {
      SharedPreferences.setMockInitialValues({
        mutedChannelsPrefKey: ['2', '5'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(isChannelMutedInPrefs(prefs, 0), isFalse);
      expect(isChannelMutedInPrefs(prefs, 1), isFalse);
    });

    test('malformed entries are ignored', () async {
      SharedPreferences.setMockInitialValues({
        mutedChannelsPrefKey: ['', 'x', '4'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(isChannelMutedInPrefs(prefs, 4), isTrue);
      expect(isChannelMutedInPrefs(prefs, 0), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Regression: foreground gate must suppress during provider hydration window
  // ---------------------------------------------------------------------------

  group('Foreground gate is authoritative before provider hydration', () {
    // The bug (report LvXeEp86d66orJse1bpi): the foreground in-app gate read
    // mutedChannelsProvider, whose Notifier.build() returns an EMPTY set and
    // hydrates from SharedPreferences asynchronously. A channel message
    // arriving in that window (e.g. the BLE reconnect replay flood) saw an
    // empty mute set and notified a muted channel anyway. The fix reads the
    // persisted value via isChannelMutedInPrefs(settings.prefs, ...), which is
    // correct even before the provider hydrates.

    test(
      'provider is still empty in the hydration window but prefs is muted',
      () async {
        SharedPreferences.setMockInitialValues({
          mutedChannelsPrefKey: ['3'],
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // First synchronous read kicks off the async _loadFromPrefs and returns
        // the optimistic empty set — this is the race window.
        final providerState = container.read(mutedChannelsProvider);
        expect(
          providerState,
          isEmpty,
          reason:
              'provider has not hydrated yet — reading it would under-report',
        );

        // The fixed gate reads prefs directly and correctly suppresses.
        final prefs = await SharedPreferences.getInstance();
        expect(
          isChannelMutedInPrefs(prefs, 3),
          isTrue,
          reason:
              'authoritative read suppresses the muted channel in the hydration '
              'window',
        );
      },
    );

    // Mirrors the gate: message.channel ?? (isBroadcast ? 0 : null).
    int? muteIndexFor(int? messageChannel, {required bool isBroadcast}) =>
        messageChannel ?? (isBroadcast ? 0 : null);

    test(
      'broadcast with null channel is treated as primary (channel 0)',
      () async {
        SharedPreferences.setMockInitialValues({
          mutedChannelsPrefKey: ['0'],
        });
        final prefs = await SharedPreferences.getInstance();

        final muteChannelIndex = muteIndexFor(null, isBroadcast: true);

        expect(muteChannelIndex, 0);
        expect(isChannelMutedInPrefs(prefs, muteChannelIndex!), isTrue);
      },
    );

    test('DM with null channel is not coerced to a channel index', () {
      final muteChannelIndex = muteIndexFor(null, isBroadcast: false);

      expect(
        muteChannelIndex,
        isNull,
        reason: 'a DM with no channel must not be mute-checked against ch 0',
      );
    });
  });
}
