// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Classifier pins for RC-CROSS-TRANSPORT: the single source of truth for
// preserve vs clear vs rehydrate semantics used by every connect
// entrypoint via [prepareForDeviceTransition]. Each row in the
// transition matrix has at least one test here.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  group('classifyDeviceTransition — every matrix row', () {
    test('firstEver: no previous device persisted', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:01',
        newDeviceName: 'Meshtastic_abcd',
        newDeviceType: TransportType.ble,
        previousDeviceId: null,
        previousDeviceType: null,
        lastMyNodeNum: null,
        lastDeviceName: null,
      );
      expect(t.kind, DeviceTransitionKind.firstEver);
      expect(t.clearNodes, isFalse);
      expect(t.isLogicalRebind, isFalse);
      expect(t.transportFamilyChanged, isFalse);
      expect(t.forceFreshHydration, isFalse);
    });

    test('sameDevice: raw id unchanged', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:01',
        newDeviceName: 'Meshtastic_abcd',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.sameDevice);
      expect(t.clearNodes, isFalse);
      expect(t.isLogicalRebind, isFalse);
      expect(t.transportFamilyChanged, isFalse);
    });

    test('transportRebind: BLE UUID rotated, same radio, same family', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:02',
        newDeviceName: 'Meshtastic_abcd',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.transportRebind);
      expect(t.clearNodes, isFalse);
      expect(t.isLogicalRebind, isTrue);
      expect(t.transportFamilyChanged, isFalse);
      expect(t.forceFreshHydration, isFalse);
    });

    test('sameRadioCrossTransport: BLE → TCP with matching nodeNum suffix', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'tcp:meshtastic_abcd.local:4403',
        newDeviceName: 'Meshtastic abcd',
        newDeviceType: TransportType.network,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.sameRadioCrossTransport);
      expect(t.clearNodes, isFalse);
      expect(t.isLogicalRebind, isTrue);
      expect(t.transportFamilyChanged, isTrue);
      expect(
        t.forceFreshHydration,
        isTrue,
        reason:
            'same radio across transports preserves persisted NodeDB but '
            'must force a fresh rehydrate of the new session',
      );
    });

    test('sameRadioCrossTransport: TCP → BLE with matching nodeNum suffix', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:01',
        newDeviceName: 'Meshtastic_abcd',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'tcp:meshtastic_abcd.local:4403',
        previousDeviceType: 'network',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.sameRadioCrossTransport);
      expect(t.forceFreshHydration, isTrue);
    });

    test('deviceSwitch: BLE A → BLE B (different radio, same family)', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:99',
        newDeviceName: 'Meshtastic_9999',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.deviceSwitch);
      expect(t.clearNodes, isTrue);
      expect(t.isLogicalRebind, isFalse);
      expect(t.transportFamilyChanged, isFalse);
    });

    test('deviceSwitch: TCP A → BLE B (different radio, cross-transport)', () {
      // Classic bug scenario: previous TCP session, user taps a different
      // physical BLE radio. Must be a destructive clear — otherwise the
      // persisted (global) node cache from radio A leaks into radio B's
      // session.
      final t = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:99',
        newDeviceName: 'Meshtastic_9999',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'tcp:meshtastic_abcd.local:4403',
        previousDeviceType: 'network',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.deviceSwitch);
      expect(t.clearNodes, isTrue);
      expect(t.transportFamilyChanged, isTrue);
    });

    test('deviceSwitch: BLE A → TCP B (different radio, cross-transport)', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'tcp:10.0.0.42:4403',
        newDeviceName: '10.0.0.42',
        newDeviceType: TransportType.network,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.deviceSwitch);
      expect(t.clearNodes, isTrue);
      expect(t.transportFamilyChanged, isTrue);
    });

    test('deviceSwitch: TCP A → TCP B (different endpoint, same family)', () {
      final t = classifyDeviceTransition(
        newDeviceId: 'tcp:10.0.0.99:4403',
        newDeviceName: '10.0.0.99',
        newDeviceType: TransportType.network,
        previousDeviceId: 'tcp:10.0.0.42:4403',
        previousDeviceType: 'network',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(t.kind, DeviceTransitionKind.deviceSwitch);
      expect(t.clearNodes, isTrue);
      expect(t.transportFamilyChanged, isFalse);
    });

    test(
      'sameRadioCrossTransport is NOT destructive even if lastDeviceType is null',
      () {
        // Legacy installs predate lastDeviceType — we still shouldn't
        // wipe when logical identity matches. `transportFamilyChanged`
        // is false when previousTransportType is unknown, so we fall
        // through to `transportRebind` (still non-destructive).
        final t = classifyDeviceTransition(
          newDeviceId: 'tcp:meshtastic_abcd.local:4403',
          newDeviceName: 'Meshtastic abcd',
          newDeviceType: TransportType.network,
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          previousDeviceType: null,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        );
        expect(t.clearNodes, isFalse);
        expect(t.isLogicalRebind, isTrue);
      },
    );

    test('repeated swap TCP A → BLE B → TCP A stays correctly classified', () {
      // Leg 1: TCP A → BLE B (deviceSwitch, destructive).
      final leg1 = classifyDeviceTransition(
        newDeviceId: 'AA:BB:CC:DD:EE:99',
        newDeviceName: 'Meshtastic_9999',
        newDeviceType: TransportType.ble,
        previousDeviceId: 'tcp:meshtastic_abcd.local:4403',
        previousDeviceType: 'network',
        lastMyNodeNum: 0x1234abcd,
        lastDeviceName: 'Meshtastic_abcd',
      );
      expect(leg1.kind, DeviceTransitionKind.deviceSwitch);

      // Leg 2: BLE B → TCP A after BLE B became new "last". lastMyNodeNum
      // now belongs to node B (0x9999). TCP A's endpoint (`_abcd.local`)
      // does NOT match — so this is a true device switch, not a rebind.
      final leg2 = classifyDeviceTransition(
        newDeviceId: 'tcp:meshtastic_abcd.local:4403',
        newDeviceName: 'Meshtastic abcd',
        newDeviceType: TransportType.network,
        previousDeviceId: 'AA:BB:CC:DD:EE:99',
        previousDeviceType: 'ble',
        lastMyNodeNum: 0x9999,
        lastDeviceName: 'Meshtastic_9999',
      );
      expect(leg2.kind, DeviceTransitionKind.deviceSwitch);
      expect(leg2.clearNodes, isTrue);
    });
  });

  group('isLogicalSameRadio — cross-transport identity', () {
    test('TCP host contains prior BLE nodeNum suffix → same radio', () {
      expect(
        isLogicalSameRadio(
          newDeviceName: 'Meshtastic abcd',
          newDeviceId: 'tcp:meshtastic_abcd.local:4403',
          newDeviceType: TransportType.network,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isTrue,
      );
    });

    test('bare IP endpoint with no nodeNum hint → not same radio', () {
      expect(
        isLogicalSameRadio(
          newDeviceName: '10.0.0.42',
          newDeviceId: 'tcp:10.0.0.42:4403',
          newDeviceType: TransportType.network,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('TCP host coincidentally containing the 4 hex digits inside another '
        'word is not treated as a match (boundary check)', () {
      // 'aabcd' contains 'abcd' but only as a substring inside the
      // longer token. We must NOT treat it as the same radio.
      expect(
        isLogicalSameRadio(
          newDeviceName: 'Meshtastic aabcd.local',
          newDeviceId: 'tcp:meshtastic-aabcdmeshnode.local:4403',
          newDeviceType: TransportType.network,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isFalse,
      );
    });

    test('BLE rotated UUID + suffix match → same radio (BLE-only path)', () {
      expect(
        isLogicalSameRadio(
          newDeviceName: 'Meshtastic_abcd',
          newDeviceId: 'AA:BB:CC:DD:EE:02',
          newDeviceType: TransportType.ble,
          lastMyNodeNum: 0x1234abcd,
          lastDeviceName: 'Meshtastic_abcd',
        ),
        isTrue,
      );
    });
  });

  group('transportTypeFromString — round-trip', () {
    test('known values decode', () {
      expect(transportTypeFromString('ble'), TransportType.ble);
      expect(transportTypeFromString('usb'), TransportType.usb);
      expect(transportTypeFromString('network'), TransportType.network);
    });

    test('null and unknown values → null (transport family unknown)', () {
      expect(transportTypeFromString(null), isNull);
      expect(transportTypeFromString(''), isNull);
      expect(transportTypeFromString('lora'), isNull);
    });
  });
}
