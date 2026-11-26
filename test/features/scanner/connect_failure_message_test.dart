// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// A failed connect is shown to the user in words they can act on. The raw
// exception text never reaches the banner or a snackbar.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/scanner/scanner_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_device.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('a plugin connect timeout reads as a timeout', () {
    expect(
      connectFailureMessage(
        l10n,
        Exception(
          'FlutterBluePlusException | connect | fbp-code: 1 | '
          'Timed out after 15s',
        ),
      ),
      l10n.scannerConnectionTimedOut,
    );
  });

  test('a timeout reported by the protocol reads as a timeout', () {
    expect(
      connectFailureMessage(
        l10n,
        'Identification failed',
        protocolError: MeshProtocolError.timeout,
      ),
      l10n.scannerConnectionTimedOut,
    );
  });

  test('a device that drops during setup reads as an unexpected '
      'disconnect', () {
    expect(
      connectFailureMessage(
        l10n,
        Exception('Device disconnected during setup'),
      ),
      l10n.scannerDeviceDisconnectedUnexpectedly,
    );
  });

  test('an unsupported device gets the unsupported device message', () {
    expect(
      connectFailureMessage(
        l10n,
        'Unknown device type.',
        protocolError: MeshProtocolError.unsupportedDevice,
      ),
      l10n.scannerUnsupportedDeviceMessage,
    );
  });

  test('anything else gets the generic message, not the exception', () {
    final message = connectFailureMessage(
      l10n,
      StateError('PlatformException(write_characteristic_error, null)'),
    );
    expect(message, l10n.scannerConnectionFailed);
    expect(message, isNot(contains('PlatformException')));
  });
}
