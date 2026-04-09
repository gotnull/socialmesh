// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Helper: simulates _dispatchNotification decision logic using raw
  // SharedPreferences reads (no Riverpod), as the background processor does.
  // ---------------------------------------------------------------------------

  /// Returns true if the notification should be dispatched.
  /// This mirrors the background processor logic which only reads global keys.
  bool backgroundDispatchDecision(
    SharedPreferences prefs, {
    required bool isBroadcast,
    required int? messageChannel,
  }) {
    // Master toggle
    final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!masterEnabled) return false;

    // Category toggles (global — no bg_ prefix keys)
    if (isBroadcast) {
      final channelEnabled =
          prefs.getBool('channel_notifications_enabled') ?? true;
      if (!channelEnabled) return false;
    } else {
      final dmEnabled = prefs.getBool('dm_notifications_enabled') ?? true;
      if (!dmEnabled) return false;
    }

    // Per-channel mute
    if (messageChannel != null) {
      final mutedRaw = prefs.getStringList('muted_channel_indices');
      if (mutedRaw != null) {
        final mutedSet = mutedRaw
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toSet();
        if (mutedSet.contains(messageChannel)) return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Migration: notification_settings_v2
  // ---------------------------------------------------------------------------

  group('Migration: notification_settings_v2', () {
    test('migration runs once and sets guard key', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        'dm_notifications_enabled': true,
      });

      final settings = SettingsService();
      await settings.init();

      final prefs = settings.prefs;
      expect(prefs.getBool('notification_settings_v2_migrated'), isTrue);
    });

    test(
      'bg_notify_messages=false disables dm_notifications_enabled',
      () async {
        SharedPreferences.setMockInitialValues({
          'bg_notify_messages': false,
          'dm_notifications_enabled': true,
        });

        final settings = SettingsService();
        await settings.init();

        expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
      },
    );

    test(
      'bg_notify_channels=false disables channel_notifications_enabled',
      () async {
        SharedPreferences.setMockInitialValues({
          'bg_notify_channels': false,
          'channel_notifications_enabled': true,
        });

        final settings = SettingsService();
        await settings.init();

        expect(
          settings.prefs.getBool('channel_notifications_enabled'),
          isFalse,
        );
      },
    );

    test('both bg keys false disables both global keys', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        'bg_notify_channels': false,
        'dm_notifications_enabled': true,
        'channel_notifications_enabled': true,
      });

      final settings = SettingsService();
      await settings.init();

      expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
      expect(settings.prefs.getBool('channel_notifications_enabled'), isFalse);
    });

    test('does nothing if already migrated', () async {
      SharedPreferences.setMockInitialValues({
        'notification_settings_v2_migrated': true,
        'bg_notify_messages': false,
        'dm_notifications_enabled': true,
        'bg_notify_channels': false,
        'channel_notifications_enabled': true,
      });

      final settings = SettingsService();
      await settings.init();

      // Global keys should be untouched because migration was already done
      expect(settings.prefs.getBool('dm_notifications_enabled'), isTrue);
      expect(settings.prefs.getBool('channel_notifications_enabled'), isTrue);
    });

    test('does nothing if bg keys were never set (null)', () async {
      SharedPreferences.setMockInitialValues({
        'dm_notifications_enabled': true,
        'channel_notifications_enabled': true,
      });

      final settings = SettingsService();
      await settings.init();

      // Global keys remain unchanged
      expect(settings.prefs.getBool('dm_notifications_enabled'), isTrue);
      expect(settings.prefs.getBool('channel_notifications_enabled'), isTrue);
      // Guard key still set
      expect(
        settings.prefs.getBool('notification_settings_v2_migrated'),
        isTrue,
      );
    });

    test('bg=false but global already false => no redundant write', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        'dm_notifications_enabled': false,
        'bg_notify_channels': false,
        'channel_notifications_enabled': false,
      });

      final settings = SettingsService();
      await settings.init();

      // Both remain false — migration doesn't flip them to true
      expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
      expect(settings.prefs.getBool('channel_notifications_enabled'), isFalse);
    });

    test('bg=true does not alter global keys', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': true,
        'dm_notifications_enabled': false,
        'bg_notify_channels': true,
        'channel_notifications_enabled': false,
      });

      final settings = SettingsService();
      await settings.init();

      // bg=true means user had background enabled — no reason to change global
      expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
      expect(settings.prefs.getBool('channel_notifications_enabled'), isFalse);
    });

    test(
      'partial: only bg_notify_messages=false, bg_notify_channels not set',
      () async {
        SharedPreferences.setMockInitialValues({
          'bg_notify_messages': false,
          'dm_notifications_enabled': true,
          'channel_notifications_enabled': true,
        });

        final settings = SettingsService();
        await settings.init();

        expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
        // channel key untouched because bg_notify_channels was null
        expect(settings.prefs.getBool('channel_notifications_enabled'), isTrue);
      },
    );

    test('global dm key defaults to true when absent and bg=false', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        // dm_notifications_enabled not set — defaults to true
      });

      final settings = SettingsService();
      await settings.init();

      // Migration should have written false because default was true
      expect(settings.prefs.getBool('dm_notifications_enabled'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Unified model: precedence rules
  // ---------------------------------------------------------------------------

  group('Unified model: precedence rules', () {
    test(
      'master OFF => no notifications regardless of category toggles',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': false,
          'dm_notifications_enabled': true,
          'channel_notifications_enabled': true,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isFalse,
          reason: 'master OFF blocks channel messages',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isFalse,
          reason: 'master OFF blocks DMs',
        );
      },
    );

    test(
      'master ON, DM OFF => no DM notifications, channels still work',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': false,
          'channel_notifications_enabled': true,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isFalse,
          reason: 'DM OFF blocks DMs',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isTrue,
          reason: 'channels still work when only DM is OFF',
        );
      },
    );

    test(
      'master ON, Channel OFF => no channel notifications, DMs still work',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': true,
          'channel_notifications_enabled': false,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isFalse,
          reason: 'channel OFF blocks channel messages',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isTrue,
          reason: 'DMs still work when only channel is OFF',
        );
      },
    );

    test(
      'master ON, all ON, channel muted => muted channel suppressed, others fire',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': true,
          'channel_notifications_enabled': true,
          'muted_channel_indices': ['2'],
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 2,
          ),
          isFalse,
          reason: 'muted channel 2 is suppressed',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isTrue,
          reason: 'unmuted channel 0 still fires',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 5,
          ),
          isTrue,
          reason: 'unmuted channel 5 still fires',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isTrue,
          reason: 'DMs still fire',
        );
      },
    );

    test('master ON, DM ON, bg_notify_messages in prefs but ignored', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'dm_notifications_enabled': true,
        'channel_notifications_enabled': true,
        'bg_notify_messages': false, // legacy key — must be ignored
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isTrue,
        reason: 'bg_notify_messages is dead — DMs fire based on global key',
      );
    });

    test('all toggles OFF => nothing gets through', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'dm_notifications_enabled': false,
        'channel_notifications_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isFalse,
      );
      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isFalse,
      );
    });

    test('missing keys default to enabled (fresh install)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isTrue,
      );
      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Background processor: global keys only
  // ---------------------------------------------------------------------------

  group('Background processor: global keys only', () {
    test('reads notifications_enabled for master gate', () async {
      SharedPreferences.setMockInitialValues({'notifications_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
      expect(masterEnabled, isFalse);
    });

    test('reads dm_notifications_enabled for DM gate', () async {
      SharedPreferences.setMockInitialValues({
        'dm_notifications_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final dmEnabled = prefs.getBool('dm_notifications_enabled') ?? true;
      expect(dmEnabled, isFalse);
    });

    test('reads channel_notifications_enabled for channel gate', () async {
      SharedPreferences.setMockInitialValues({
        'channel_notifications_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final channelEnabled =
          prefs.getBool('channel_notifications_enabled') ?? true;
      expect(channelEnabled, isFalse);
    });

    test('does NOT read bg_notify_messages', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        'dm_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      // Background processor only reads global key
      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isTrue,
        reason: 'bg_notify_messages is not consulted',
      );
    });

    test('does NOT read bg_notify_channels', () async {
      SharedPreferences.setMockInitialValues({
        'bg_notify_channels': false,
        'channel_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isTrue,
        reason: 'bg_notify_channels is not consulted',
      );
    });

    test('foreground setting change visible in background path', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isTrue,
      );

      // Simulate foreground toggle
      await prefs.setBool('channel_notifications_enabled', false);

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isFalse,
        reason: 'foreground change is immediately visible to background',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Channel mute overrides
  // ---------------------------------------------------------------------------

  group('Channel mute overrides', () {
    test(
      'muted channel suppressed while others still get notifications',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'channel_notifications_enabled': true,
          'muted_channel_indices': ['3'],
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 3,
          ),
          isFalse,
          reason: 'muted channel 3 is suppressed',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isTrue,
          reason: 'unmuted channel 0 is not suppressed',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 1,
          ),
          isTrue,
          reason: 'unmuted channel 1 is not suppressed',
        );
      },
    );

    test('multiple muted channels all suppressed independently', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': true,
        'muted_channel_indices': ['0', '2', '5'],
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isFalse,
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 1),
        isTrue,
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 2),
        isFalse,
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 3),
        isTrue,
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 5),
        isFalse,
      );
    });

    test('channel mute does NOT affect DMs', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'dm_notifications_enabled': true,
        'channel_notifications_enabled': true,
        'muted_channel_indices': ['0', '1', '2', '3', '4', '5', '6', '7'],
      });
      final prefs = await SharedPreferences.getInstance();

      // All channels muted
      for (var ch = 0; ch < 8; ch++) {
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: ch,
          ),
          isFalse,
          reason: 'channel $ch should be muted',
        );
      }

      // DMs still fire (messageChannel is null for DMs)
      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isTrue,
        reason: 'DMs are unaffected by channel mutes',
      );
    });

    test('empty muted list allows all channels', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': true,
        'muted_channel_indices': <String>[],
      });
      final prefs = await SharedPreferences.getInstance();

      for (var ch = 0; ch < 8; ch++) {
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: ch,
          ),
          isTrue,
          reason: 'channel $ch should be allowed when muted list is empty',
        );
      }
    });

    test('no muted_channel_indices key allows all channels', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      for (var ch = 0; ch < 8; ch++) {
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: ch,
          ),
          isTrue,
          reason: 'channel $ch should be allowed when key is absent',
        );
      }
    });

    test('channel mute + channel category OFF => double-blocked', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'channel_notifications_enabled': false,
        'muted_channel_indices': ['0'],
      });
      final prefs = await SharedPreferences.getInstance();

      // Category OFF already blocks — mute is redundant but not harmful
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isFalse,
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 1),
        isFalse,
        reason: 'channel category OFF blocks even unmuted channels',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Dead bg keys have no effect
  // ---------------------------------------------------------------------------

  group('Dead bg keys have no effect', () {
    test(
      'bg_notify_messages=false does not block DMs when global DM is ON',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': true,
          'bg_notify_messages': false,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isTrue,
          reason: 'bg_notify_messages is a dead key',
        );
      },
    );

    test(
      'bg_notify_channels=false does not block channels when global channel is ON',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'channel_notifications_enabled': true,
          'bg_notify_channels': false,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isTrue,
          reason: 'bg_notify_channels is a dead key',
        );
      },
    );

    test(
      'both bg keys false, both global keys ON => all notifications fire',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': true,
          'channel_notifications_enabled': true,
          'bg_notify_messages': false,
          'bg_notify_channels': false,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isTrue,
          reason: 'DM fires despite bg_notify_messages=false',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isTrue,
          reason: 'channel fires despite bg_notify_channels=false',
        );
      },
    );

    test(
      'bg keys true, global keys false => correctly blocked by global keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': true,
          'dm_notifications_enabled': false,
          'channel_notifications_enabled': false,
          'bg_notify_messages': true,
          'bg_notify_channels': true,
        });
        final prefs = await SharedPreferences.getInstance();

        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: false,
            messageChannel: null,
          ),
          isFalse,
          reason: 'global DM OFF blocks even though bg key is true',
        );
        expect(
          backgroundDispatchDecision(
            prefs,
            isBroadcast: true,
            messageChannel: 0,
          ),
          isFalse,
          reason: 'global channel OFF blocks even though bg key is true',
        );
      },
    );

    test('after migration, only global keys control behavior', () async {
      // Simulate pre-migration state: user had bg OFF, global ON
      SharedPreferences.setMockInitialValues({
        'bg_notify_messages': false,
        'dm_notifications_enabled': true,
        'bg_notify_channels': false,
        'channel_notifications_enabled': true,
      });

      // Run migration
      final settings = SettingsService();
      await settings.init();

      final prefs = settings.prefs;

      // Migration should have disabled global keys
      expect(prefs.getBool('dm_notifications_enabled'), isFalse);
      expect(prefs.getBool('channel_notifications_enabled'), isFalse);

      // bg keys are still in prefs but dead
      expect(prefs.getBool('bg_notify_messages'), isFalse);
      expect(prefs.getBool('bg_notify_channels'), isFalse);

      // Dispatch decision uses global keys only
      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isFalse,
        reason: 'DM blocked by migrated global key',
      );
      expect(
        backgroundDispatchDecision(prefs, isBroadcast: true, messageChannel: 0),
        isFalse,
        reason: 'channel blocked by migrated global key',
      );

      // User re-enables DMs via settings (only global key)
      await prefs.setBool('dm_notifications_enabled', true);

      expect(
        backgroundDispatchDecision(
          prefs,
          isBroadcast: false,
          messageChannel: null,
        ),
        isTrue,
        reason: 'DM fires after user re-enables global key',
      );
      // bg key still false — proves it is dead
      expect(prefs.getBool('bg_notify_messages'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // No duplicate settings write conflicting values
  // ---------------------------------------------------------------------------

  group('No duplicate settings write conflicting values', () {
    test('only one key controls DM notifications', () async {
      SharedPreferences.setMockInitialValues({
        'dm_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      // The only key that matters for DM gating
      final dmEnabled = prefs.getBool('dm_notifications_enabled') ?? true;
      expect(dmEnabled, isTrue);

      // No second key should be checked
      // bg_notify_messages is dead and should not affect the decision
      await prefs.setBool('bg_notify_messages', false);
      final dmEnabledAfter = prefs.getBool('dm_notifications_enabled') ?? true;
      expect(
        dmEnabledAfter,
        isTrue,
        reason: 'dm_notifications_enabled is independent of bg key',
      );
    });

    test('only one key controls channel notifications', () async {
      SharedPreferences.setMockInitialValues({
        'channel_notifications_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final channelEnabled =
          prefs.getBool('channel_notifications_enabled') ?? true;
      expect(channelEnabled, isTrue);

      await prefs.setBool('bg_notify_channels', false);
      final channelEnabledAfter =
          prefs.getBool('channel_notifications_enabled') ?? true;
      expect(
        channelEnabledAfter,
        isTrue,
        reason: 'channel_notifications_enabled is independent of bg key',
      );
    });

    test('SettingsService getters use the canonical keys', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false,
        'dm_notifications_enabled': false,
        'channel_notifications_enabled': false,
      });

      final settings = SettingsService();
      await settings.init();

      expect(settings.notificationsEnabled, isFalse);
      expect(settings.directMessageNotificationsEnabled, isFalse);
      expect(settings.channelMessageNotificationsEnabled, isFalse);
    });

    test('SettingsService setters write the canonical keys', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = SettingsService();
      await settings.init();

      await settings.setNotificationsEnabled(false);
      await settings.setDirectMessageNotificationsEnabled(false);
      await settings.setChannelMessageNotificationsEnabled(false);

      final prefs = settings.prefs;
      expect(prefs.getBool('notifications_enabled'), isFalse);
      expect(prefs.getBool('dm_notifications_enabled'), isFalse);
      expect(prefs.getBool('channel_notifications_enabled'), isFalse);

      // No bg_ keys should have been written
      expect(prefs.getBool('bg_notify_messages'), isNull);
      expect(prefs.getBool('bg_notify_channels'), isNull);
    });

    test(
      'toggling via SettingsService does not create conflicting bg keys',
      () async {
        SharedPreferences.setMockInitialValues({});

        final settings = SettingsService();
        await settings.init();

        // Toggle ON
        await settings.setDirectMessageNotificationsEnabled(true);
        await settings.setChannelMessageNotificationsEnabled(true);

        // Toggle OFF
        await settings.setDirectMessageNotificationsEnabled(false);
        await settings.setChannelMessageNotificationsEnabled(false);

        // Toggle ON again
        await settings.setDirectMessageNotificationsEnabled(true);
        await settings.setChannelMessageNotificationsEnabled(true);

        final prefs = settings.prefs;
        expect(prefs.getBool('dm_notifications_enabled'), isTrue);
        expect(prefs.getBool('channel_notifications_enabled'), isTrue);
        // bg keys were never created
        expect(prefs.getBool('bg_notify_messages'), isNull);
        expect(prefs.getBool('bg_notify_channels'), isNull);
      },
    );
  });
}
