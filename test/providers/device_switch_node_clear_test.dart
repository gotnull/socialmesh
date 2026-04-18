// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  // Regression: connecting to a different physical device must trigger a
  // node-data clear, otherwise the persistent NodeStorageService loads
  // every node identity ever seen and unions it with the new device's
  // NodeDB — making every device appear to share the same node count.
  //
  // This tests the pure predicate that drives the auto-clear; the helpers
  // (clearDeviceDataBeforeConnect[Ref]) consult it to override their
  // explicit `clearNodeData` flag.
  group('isDeviceSwitch (RC-DEVICE-SWITCH regression)', () {
    test('returns true when previous and new IDs differ', () {
      expect(
        isDeviceSwitchForTest('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:02'),
        isTrue,
      );
    });

    test('returns false for same physical device (reconnect)', () {
      expect(
        isDeviceSwitchForTest('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:01'),
        isFalse,
      );
    });

    test('returns false when previous is null (first ever connect)', () {
      // Never connected before — caller's explicit clearNodeData decision
      // stands. We don't auto-clear because there is nothing to leak from.
      expect(isDeviceSwitchForTest(null, 'AA:BB:CC:DD:EE:01'), isFalse);
    });

    test('returns false when new is null (caller did not pass it)', () {
      // Conservative: if a caller hasn't been migrated to pass newDeviceId
      // we keep current behaviour (their explicit clearNodeData stands).
      expect(isDeviceSwitchForTest('AA:BB:CC:DD:EE:01', null), isFalse);
    });

    test('returns false when both are null', () {
      expect(isDeviceSwitchForTest(null, null), isFalse);
    });

    test(
      'case-sensitive — different casing IS treated as a different device',
      () {
        // BLE IDs on iOS are UUIDs and casing matters. A device id is the
        // canonical identifier the transport gives us; we must not normalise.
        expect(
          isDeviceSwitchForTest(
            '12345678-90AB-CDEF-1234-567890ABCDEF',
            '12345678-90ab-cdef-1234-567890abcdef',
          ),
          isTrue,
        );
      },
    );
  });
}
