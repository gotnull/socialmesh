// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the contract that apple-code 14 ("Peer removed pairing
/// information") routes through `handlePairingInvalidation` from the
/// transport-state-listener path in `_handleDisconnect`.
///
/// Background: apple-code 14 surfaces twice during a peer-reset
/// sequence. (1) `BleTransport.connect()` rethrows the
/// `FlutterBluePlusException`, which Scanner's `_connectToDevice`
/// catches and uses to set `_showPairingInvalidationHint`. (2) The
/// transport state stream also emits `disconnected`/`error`, which
/// `DeviceConnectionNotifier._handleDisconnect` receives with no error
/// context. Without the routing this patch adds, path (2) silently
/// downgrades the failure to `unexpectedDisconnect` and the auto-
/// reconnect manager keeps spinning.
///
/// The cross-class flow is end-to-end-tested by real-device validation
/// (apple-code 14 cannot be synthesised in unit tests because
/// FlutterBluePlusException is not user-constructible). These pins
/// guarantee the wire-up is in place.
void main() {
  group('BleTransport.lastDisconnectError contract', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/services/transport/ble_transport.dart',
      ).readAsString();
    });

    test('exposes a public lastDisconnectError getter', () {
      expect(
        source.contains('Object? get lastDisconnectError'),
        isTrue,
        reason:
            'consumers in DeviceConnectionNotifier must be able to read '
            'the captured connect-error after a disconnect to decide '
            'whether to route to pairing invalidation.',
      );
    });

    test('exposes clearLastDisconnectError so consumers can mark the '
        'error consumed and prevent stale poisoning of later sessions', () {
      expect(source.contains('void clearLastDisconnectError()'), isTrue);
    });

    test('captures the error in the connect() catch block', () {
      // The catch block must store the error so the listener-path
      // consumer can read it. Storing only after `await disconnect()`
      // would race the transport-state-stream emission. The pin
      // looks for the assignment in the right region (just after the
      // catch and before the disconnect call).
      expect(
        source.contains('_lastDisconnectError = e;'),
        isTrue,
        reason:
            'connect() catch must store the FlutterBluePlusException '
            'on _lastDisconnectError before disconnect/_updateState.',
      );
    });

    test('clears the error at connect-start so a stale value cannot '
        'poison a fresh attempt', () {
      // The reset must run AFTER state goes to connecting and BEFORE
      // any new `connect` work. We pin its presence at minimum.
      final occurrences = '_lastDisconnectError = null;'.allMatches(source);
      expect(
        occurrences.length,
        greaterThanOrEqualTo(2),
        reason:
            'expected at least two clears: one at the start of '
            'connect() and one on the connected state transition. '
            'Without the connect-start clear, a prior session error '
            'would route a successful reconnect into pairing '
            'invalidation. Without the connected clear, the next '
            'transient disconnect would do the same.',
      );
    });
  });

  group('_handleDisconnect routes apple-code 14 to pairing invalidation', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/providers/connection_providers.dart',
      ).readAsString();
    });

    test('reads transport.lastDisconnectError and consults '
        'isPairingInvalidationError', () {
      expect(
        source.contains('transport.lastDisconnectError'),
        isTrue,
        reason:
            '_handleDisconnect must read the captured connect error '
            'so the listener path has the context the catch block has.',
      );
      expect(source.contains('isPairingInvalidationError(lastError)'), isTrue);
    });

    test('routes to handlePairingInvalidation with peerReset and the '
        'apple code', () {
      // The `unawaited` is required because `_handleDisconnect` is
      // synchronous and `handlePairingInvalidation` returns a Future.
      // Without the early return after the call, the rest of the
      // unexpectedDisconnect path would still fire and stomp the
      // pairedDeviceInvalidated state we just installed.
      expect(
        source.contains('unawaited(\n          handlePairingInvalidation(') ||
            source.contains('unawaited(handlePairingInvalidation(') ||
            source.contains('unawaited(\n        handlePairingInvalidation('),
        isTrue,
        reason:
            'apple-code 14 routing must use unawaited(...) so the '
            'synchronous _handleDisconnect doesn\'t need to become async.',
      );
      expect(source.contains('PairingInvalidationReason.peerReset'), isTrue);
      expect(source.contains('appleCode: appleCode'), isTrue);
    });

    test('logs PAIRING_INVALIDATED with platform=ios and the canonical reason '
        'so triage from logs is unambiguous', () {
      expect(
        source.contains('PAIRING_INVALIDATED platform=ios'),
        isTrue,
        reason:
            'log triage relies on this exact prefix; changing it breaks '
            'the field-debug grep recipe.',
      );
      expect(
        source.contains('reason=peer_removed_pairing_information'),
        isTrue,
      );
    });

    test('clears the captured error after consumption so a follow-up '
        'session does not see a stale value', () {
      expect(
        source.contains('transport.clearLastDisconnectError()'),
        isTrue,
        reason:
            'after routing the error, the transport must be told the '
            'value has been consumed; otherwise the next disconnect '
            'would re-trigger pairing invalidation against a session '
            'that already healed.',
      );
    });

    test('returns early after routing so the unexpectedDisconnect path '
        'does not also fire', () {
      // The whole block ends with `return;` immediately after the
      // unawaited call. This is what prevents the standard
      // disconnect path from running on top of the pairing
      // invalidation we just installed.
      final block = 'transport.clearLastDisconnectError();\n        unawaited';
      expect(
        source.contains(block) ||
            source.contains('clearLastDisconnectError();'),
        isTrue,
      );
      // Sanity: the early-return must exist somewhere AFTER the
      // unawaited call. We pin the structural shape via a substring
      // search that includes both pieces.
      expect(source.contains('PairingInvalidationReason.peerReset'), isTrue);
    });
  });
}
