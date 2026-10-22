// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

void main() {
  group('BleTransport.preferAdvertisedName', () {
    test('the advertised name wins over a stale platform name', () {
      // A radio re-flashed from MeshCore to Meshtastic: iOS still holds
      // the old name, the advertisement carries the new one.
      expect(
        BleTransport.preferAdvertisedName(
          advertisedName: 'Meshtastic_29a9',
          platformName: 'MeshCore-C3339C3A29A9',
        ),
        'Meshtastic_29a9',
      );
    });

    test('falls back to the platform name when nothing is advertised', () {
      expect(
        BleTransport.preferAdvertisedName(
          advertisedName: '',
          platformName: '29ea_2d94',
        ),
        '29ea_2d94',
      );
    });

    test('is empty when neither name is known', () {
      expect(
        BleTransport.preferAdvertisedName(advertisedName: '', platformName: ''),
        isEmpty,
      );
    });
  });
}
