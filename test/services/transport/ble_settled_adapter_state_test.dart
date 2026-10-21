// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

void main() {
  group('BleTransport.settledAdapterState', () {
    test('waits past the launch-time unknown state for on', () async {
      final states = StreamController<BluetoothAdapterState>();
      addTearDown(states.close);

      final result = BleTransport.settledAdapterState(states.stream);
      states.add(BluetoothAdapterState.unknown);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      states.add(BluetoothAdapterState.on);

      expect(await result, BluetoothAdapterState.on);
    });

    test('reports off when the adapter is off', () async {
      final result = BleTransport.settledAdapterState(
        Stream.fromIterable(const [
          BluetoothAdapterState.unknown,
          BluetoothAdapterState.off,
        ]),
      );

      expect(await result, BluetoothAdapterState.off);
    });

    test('skips transitional states', () async {
      final result = BleTransport.settledAdapterState(
        Stream.fromIterable(const [
          BluetoothAdapterState.turningOn,
          BluetoothAdapterState.on,
        ]),
      );

      expect(await result, BluetoothAdapterState.on);
    });

    test('returns unknown when no settled state arrives in time', () async {
      final states = StreamController<BluetoothAdapterState>();
      addTearDown(states.close);

      final result = BleTransport.settledAdapterState(
        states.stream,
        timeout: const Duration(milliseconds: 100),
      );
      states.add(BluetoothAdapterState.unknown);

      expect(await result, BluetoothAdapterState.unknown);
    });
  });
}
