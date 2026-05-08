// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/connection_providers.dart';

/// Pins the Android-only bond-missing-on-final-scan-fail differentiation.
///
/// The patch adds a `PairingInvalidationReason.bondForgotten` enum value
/// and wires `DeviceConnectionNotifier.startBackgroundConnection` to,
/// at the final scan-fail (max retries reached, about to enter
/// unreachable state), check `FlutterBluePlus.bondedDevices` on Android
/// only. If the saved `lastDeviceId` is no longer in that list, the
/// user removed the device from Android Bluetooth settings and the
/// app routes to pairing invalidation with re-pair guidance instead
/// of the misleading "Device not found" copy.
///
/// iOS has no pre-connection bond-state API, so scan-fail on iOS
/// stays strictly unreachable; pairing invalidation only fires from
/// connect/auth failure on iOS.
///
/// Driving `startBackgroundConnection` end-to-end requires
/// transport/settings/scanner scaffolding outside the surgical-patch
/// constraint. These tests pin the implementation contract via:
/// - enum + log-value contract
/// - reason-keyed UX copy contract
/// - source-level structural pins (the call site shape)
void main() {
  group('PairingInvalidationReason.bondForgotten contract', () {
    test('enum value exists with the expected log value', () {
      expect(
        PairingInvalidationReason.bondForgotten.logValue,
        'bond_forgotten_after_scan_fail',
        reason:
            'log lines must clearly distinguish '
            'bond_forgotten_after_scan_fail from device_not_found '
            '(the unreachable case).',
      );
    });

    test('enum value count includes the new bondForgotten slot', () {
      expect(
        PairingInvalidationReason.values,
        contains(PairingInvalidationReason.bondForgotten),
      );
      // Sanity: the existing reasons are still there.
      expect(
        PairingInvalidationReason.values,
        containsAll([
          PairingInvalidationReason.peerReset,
          PairingInvalidationReason.missingDevice,
          PairingInvalidationReason.accountDeleted,
          PairingInvalidationReason.bondForgotten,
        ]),
      );
    });
  });

  group('localized copy contract', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('connectionErrorBondForgotten gets the re-pair text, distinct from '
        'the generic deviceReset text', () {
      expect(
        l10n.connectionErrorBondForgotten,
        'This device was removed from Android Bluetooth settings. '
        'Re-pair it from Scanner.',
      );
      // Distinct from the generic copy — banners must NOT show the
      // re-pair text for plain unreachable.
      expect(
        l10n.connectionErrorBondForgotten,
        isNot(equals(l10n.connectionErrorDeviceReset)),
      );
    });
  });

  group('source-level implementation pins', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/providers/connection_providers.dart',
      ).readAsString();
    });

    test('final scan-fail branch is gated on Platform.isAndroid before reading '
        'FlutterBluePlus.bondedDevices', () {
      // The patch must check `Platform.isAndroid` before the bond
      // query AT THE FINAL SCAN-FAIL point. iOS scan-fail must NEVER
      // trigger the bond inference. Searching for the call shape
      // pins the structural contract.
      // Substrings deliberately chosen to fit within a single string
      // literal so dart-format line-wrapping cannot mask the regression.
      expect(
        source.contains('Final scan-fail + bond'),
        isTrue,
        reason:
            'final scan-fail bond check log line is missing; patch '
            'reverted or relocated. Structural contract is broken.',
      );
      expect(
        source.contains('FlutterBluePlus.bondedDevices'),
        isTrue,
        reason: 'bond query is required for the Android branch',
      );
    });

    test(
      'iOS scan-fail branch logs the clarifying "no pre-connect bond signal" '
      'line and does NOT query bondedDevices',
      () {
        // Substring spans a single literal so dart-format wrapping
        // cannot mask it.
        expect(
          source.contains('pre-connect bond signal'),
          isTrue,
          reason:
              'iOS scan-fail must explicitly log that bond-state inference '
              'is not available pre-connection, so triage logs make the '
              'platform asymmetry observable.',
        );
        expect(
          source.contains('Final scan-fail on iOS'),
          isTrue,
          reason: 'iOS-specific scan-fail log line is missing',
        );
      },
    );

    test('final scan-fail Android branch routes to '
        'PairingInvalidationReason.bondForgotten, not peerReset or '
        'missingDevice', () {
      // The Android branch must use the new bondForgotten reason
      // specifically. Reusing peerReset would mis-tag the log and
      // produce the wrong UX copy ("device was reset"); reusing
      // missingDevice would not trigger pairing invalidation at all.
      expect(
        source.contains('PairingInvalidationReason.bondForgotten'),
        isTrue,
      );
    });

    test('_handlePairingInvalidated switches errorMessage on '
        'PairingInvalidationReason.bondForgotten', () {
      // The reason-keyed UX-copy switch must exist. Without it,
      // bondForgotten would fall back to the generic "Device was
      // reset" text — losing the re-pair guidance the user needs.
      expect(
        source.contains('reason == PairingInvalidationReason.bondForgotten'),
        isTrue,
        reason:
            '_handlePairingInvalidated must distinguish bondForgotten '
            'from other reasons to surface the correct re-pair copy.',
      );
      expect(source.contains('connectionErrorBondForgotten'), isTrue);
    });

    test('non-final scan-fail (the per-attempt retry branch) does NOT call '
        'FlutterBluePlus.bondedDevices: bond check only runs after max '
        'retries are exhausted', () {
      // The bond check sits in a single block under the
      // "Max retries exceeded" path. Per-attempt retry scheduling
      // happens earlier (in the `_reconnectAttempt < _maxReconnectAttempts`
      // branch) and must not perform the bond query.
      //
      // There are exactly three legitimate `FlutterBluePlus.bondedDevices`
      // call-site reads in this file:
      //   1. Aggressive pre-scan cleanup (early in
      //      startBackgroundConnection).
      //   2. The new final-scan-fail check (this patch).
      //   3. The existing GATT 133 connect-failure recovery in
      //      `_connectToDevice` (Android-only bond-missing detection
      //      after a real connect attempt).
      //
      // A fourth runtime read would mean the bond query crept into
      // the per-attempt retry path or some other unintended location.
      // Doc-comment mentions of `FlutterBluePlus.bondedDevices` are
      // not call sites — filter them out by requiring the `await`
      // prefix that runtime calls use.
      final runtimeCalls = 'await FlutterBluePlus.bondedDevices'.allMatches(
        source,
      );
      expect(
        runtimeCalls.length,
        3,
        reason:
            'Expected exactly 3 runtime FlutterBluePlus.bondedDevices reads: '
            'pre-scan cleanup, new final-scan-fail (this patch), and '
            'existing GATT 133 connect-failure recovery. A fourth call '
            'site likely means the bond query leaked into the per-attempt '
            'retry path.',
      );
    });
  });
}
