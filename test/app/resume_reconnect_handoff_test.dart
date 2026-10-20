// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app-resume handler lives in the app shell's widget state, so these
// guards read the source. Meshtastic reconnect on resume must go through
// `startBackgroundConnection`, which on iOS connects to the saved peripheral
// by identifier before scanning. A scan-only resume path cannot reach a
// radio that iOS still holds after the app was terminated (a held radio
// does not advertise), and because it sets the auto-reconnect state to
// scanning it also blocks `startBackgroundConnection` from running.

void main() {
  final mainSource = File('lib/main.dart').readAsStringSync();

  String resumeReconnectBody() {
    final start = mainSource.indexOf('Future<void> _performReconnectOnResume(');
    expect(start, isNonNegative, reason: '_performReconnectOnResume missing');
    final end = mainSource.indexOf('\n  }\n', start);
    return mainSource.substring(start, end);
  }

  test('main.dart runs no BLE scan of its own', () {
    final scanCalls = mainSource
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => line.contains('.scan('));
    expect(
      scanCalls,
      isEmpty,
      reason:
          'reconnect scans belong to startBackgroundConnection, which tries '
          'the iOS direct connect first',
    );
  });

  test('Meshtastic resume hands off to startBackgroundConnection', () {
    final body = resumeReconnectBody();
    expect(body, contains('.startBackgroundConnection()'));
    final idle = body.indexOf('AutoReconnectState.idle');
    final handOff = body.indexOf('.startBackgroundConnection()');
    expect(
      idle,
      allOf(isNonNegative, lessThan(handOff)),
      reason:
          'startBackgroundConnection is blocked while the state is scanning, '
          'so the resume path must reset it to idle first',
    );
  });
}
