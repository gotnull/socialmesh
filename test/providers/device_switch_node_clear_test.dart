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

  // Regression: ESP32 / nRF BLE peripherals rotate their advertised UUID
  // across reboots and sometimes across reconnects. The stale-UUID check
  // above would have classified that as a "device switch" and wiped
  // NodeDB. The logical rebind predicate distinguishes same-radio-new-UUID
  // from a genuine different-radio switch by checking Meshtastic-level
  // identity (node number suffix in the advertised name, or exact name
  // match).
  group('isLogicalTransportRebind (RC-TRANSPORT-REBIND regression)', () {
    test('same BLE UUID returns false (not a rebind, just a reconnect)', () {
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_abcd',
          newDeviceId: 'AA:BB:CC:DD:EE:01',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('null previousDeviceId returns false (first connect)', () {
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_abcd',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: null,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('different BLE UUID + matching nodeNum suffix in name → rebind', () {
      // Same physical Meshtastic radio (node 0x1234abcd → suffix "abcd")
      // advertised under a rotated BLE UUID. Must NOT wipe node cache.
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_abcd',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isTrue,
      );
    });

    test(
      'different BLE UUID + matching exact device name (no nodeNum) → rebind',
      () {
        // nodeNum unknown (first reconnect before myInfo arrived), but the
        // advertised name matches the last one exactly.
        expect(
          isLogicalTransportRebind(
            newDeviceName: 'Meshtastic_abcd',
            newDeviceId: 'AA:BB:CC:DD:EE:02',
            previousDeviceId: 'AA:BB:CC:DD:EE:01',
            lastMyNodeNum: null,
            lastDeviceName: 'Meshtastic_abcd',
          ),
          isTrue,
        );
      },
    );

    test('different BLE UUID + different nodeNum suffix → NOT a rebind', () {
      // Truly different radio (node 0x0000beef vs 0x1234abcd).
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_beef',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('different BLE UUID + different device name → NOT a rebind', () {
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_beef',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: null,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('no logical identity available → NOT a rebind (conservative)', () {
      // We only have raw UUIDs to go on, and they differ. Without any
      // logical identity we cannot prove rebind, so the caller falls back
      // to the existing conservative clear-on-mismatch behaviour.
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_abcd',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: null,
          lastDeviceName: null,
        ),
        isFalse,
      );
    });

    test('empty lastDeviceName does not spuriously match empty new name', () {
      // Empty strings must not auto-match (no signal, not evidence).
      expect(
        isLogicalTransportRebind(
          newDeviceName: '',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: null,
          lastDeviceName: '',
        ),
        isFalse,
      );
    });

    test('nodeNum suffix match is case-insensitive', () {
      // bleNameMatchesNodeNum lowercases both sides. Some firmware versions
      // advertise uppercase hex suffixes.
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_ABCD',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isTrue,
      );
    });

    test('large nodeNum (>4 hex digits) uses only the low 4 as suffix', () {
      // Meshtastic BLE naming uses the last 4 hex digits of the node
      // number. 0xdeadbeef → suffix "beef".
      expect(
        isLogicalTransportRebind(
          newDeviceName: 'Meshtastic_beef',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          lastMyNodeNum: 0xdeadbeef,
          lastDeviceName: 'Meshtastic_beef',
        ),
        isTrue,
      );
    });

    test('repeated rebind cycles remain classified as rebind', () {
      // Simulates multiple UUID rotations in sequence. Each must classify
      // as rebind so subsequent reconnects never retrigger a wipe.
      for (final (prev, next) in [
        ('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:02'),
        ('AA:BB:CC:DD:EE:02', 'AA:BB:CC:DD:EE:03'),
        ('AA:BB:CC:DD:EE:03', 'AA:BB:CC:DD:EE:04'),
      ]) {
        expect(
          isLogicalTransportRebind(
            newDeviceName: 'Meshtastic_abcd',
            newDeviceId: next,
            previousDeviceId: prev,
            lastMyNodeNum: 0x1234abcd,
            lastDeviceName: 'Meshtastic_abcd',
          ),
          isTrue,
          reason: 'rebind cycle $prev → $next must classify as rebind',
        );
      }
    });
  });
}
