// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/channel_mute_prefs.dart';

void main() {
  // muteIndexForMessage decides which channel index (if any) gates a message's
  // notification via the per-channel mute set. Broadcasts only: a DM carries a
  // channel index but must never be silenced by a channel mute.
  group('muteIndexForMessage', () {
    test('broadcast on an explicit channel returns that channel', () {
      expect(muteIndexForMessage(isBroadcast: true, channel: 2), 2);
    });

    test('broadcast on channel 0 returns 0', () {
      expect(muteIndexForMessage(isBroadcast: true, channel: 0), 0);
    });

    test('broadcast with an unresolved channel falls back to primary (0)', () {
      expect(muteIndexForMessage(isBroadcast: true, channel: null), 0);
    });

    test('DM on channel 0 is never gated by channel mute', () {
      // Regression: a DM arrives on the Primary Channel (0). Muting channel 0
      // for broadcasts must not silence the DM.
      expect(muteIndexForMessage(isBroadcast: false, channel: 0), isNull);
    });

    test('DM on a non-zero channel is never gated by channel mute', () {
      expect(muteIndexForMessage(isBroadcast: false, channel: 3), isNull);
    });

    test('DM with an unresolved channel is never gated by channel mute', () {
      expect(muteIndexForMessage(isBroadcast: false, channel: null), isNull);
    });
  });
}
