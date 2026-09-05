// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';

// A completed region apply suppresses the region picker across the reboot
// and reconnect the apply itself causes. That suppression must expire: a
// radio re-flashed or factory reset hours later comes back on the same
// device id with region UNSET, and an "applied" state left over from the
// morning hid the picker for it (seen on a Heltec V4 after a full erase).

RegionConfigState _applied({required int attemptedAtMs}) => RegionConfigState(
  regionChoice: config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
  applyStatus: RegionApplyStatus.applied,
  lastAttemptAtMs: attemptedAtMs,
  connectionSessionId: 1,
  targetDeviceId: 'ble-0864',
);

void main() {
  final now = DateTime(2026, 9, 5, 20, 0);
  DateTime clock() => now;

  group('regionAppliedWithinCarryOver', () {
    test('an apply that just completed is still carried over', () {
      final state = _applied(
        attemptedAtMs: now.millisecondsSinceEpoch - 20 * 1000,
      );
      expect(regionAppliedWithinCarryOver(state, now: clock), isTrue);
    });

    test('an apply at the edge of the window is still carried over', () {
      final state = _applied(
        attemptedAtMs:
            now.millisecondsSinceEpoch - kRegionAppliedCarryOver.inMilliseconds,
      );
      expect(regionAppliedWithinCarryOver(state, now: clock), isTrue);
    });

    test('an apply older than the window no longer suppresses setup', () {
      final state = _applied(
        attemptedAtMs:
            now.millisecondsSinceEpoch -
            kRegionAppliedCarryOver.inMilliseconds -
            1000,
      );
      expect(regionAppliedWithinCarryOver(state, now: clock), isFalse);
    });

    test('an apply with no timestamp is not carried over', () {
      const state = RegionConfigState(
        regionChoice: config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        applyStatus: RegionApplyStatus.applied,
        connectionSessionId: 1,
        targetDeviceId: 'ble-0864',
      );
      expect(regionAppliedWithinCarryOver(state, now: clock), isFalse);
    });

    test('only the applied status counts', () {
      final state = RegionConfigState(
        regionChoice: config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        applyStatus: RegionApplyStatus.applying,
        lastAttemptAtMs: now.millisecondsSinceEpoch,
        connectionSessionId: 1,
        targetDeviceId: 'ble-0864',
      );
      expect(regionAppliedWithinCarryOver(state, now: clock), isFalse);
    });
  });

  group('both guards use the time-bounded check', () {
    // The picker guard and the notifier's session-change branch must agree,
    // otherwise one of them keeps the stale suppression alive.
    late String source;
    setUpAll(() async {
      source = await File('lib/providers/app_providers.dart').readAsString();
    });

    test('needsRegionSetupProvider and RegionConfigNotifier both call it', () {
      final calls = RegexpMatches(
        RegExp(r'regionAppliedWithinCarryOver\((state|regionState)\)'),
        source,
      ).count;
      expect(calls, 2);
    });
  });
}

class RegexpMatches {
  RegexpMatches(this.pattern, this.source);
  final RegExp pattern;
  final String source;
  int get count => pattern.allMatches(source).length;
}
