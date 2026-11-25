// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/scanner/scanner_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  group('scannerReportsSavedDeviceMissing', () {
    test('a saved Bluetooth radio absent from a scan that found others', () {
      expect(
        scannerReportsSavedDeviceMissing(
          savedType: TransportType.ble,
          savedDeviceListed: false,
          anyDeviceListed: true,
        ),
        isTrue,
      );
    });

    test('a listed Bluetooth radio, or an empty scan, is not reported', () {
      expect(
        scannerReportsSavedDeviceMissing(
          savedType: TransportType.ble,
          savedDeviceListed: true,
          anyDeviceListed: true,
        ),
        isFalse,
      );
      expect(
        scannerReportsSavedDeviceMissing(
          savedType: TransportType.ble,
          savedDeviceListed: false,
          anyDeviceListed: false,
        ),
        isFalse,
      );
    });

    test('a saved network or USB radio is never reported by a BLE scan', () {
      for (final type in [TransportType.network, TransportType.usb, null]) {
        expect(
          scannerReportsSavedDeviceMissing(
            savedType: type,
            savedDeviceListed: false,
            anyDeviceListed: true,
          ),
          isFalse,
          reason: '$type',
        );
      }
    });
  });

  group('scannerLookingSubtitle', () {
    test('names MeshCore only when MeshCore radios are scanned for', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final t = lookupAppLocalizations(locale);
        expect(
          scannerLookingSubtitle(t, meshCoreEnabled: true),
          allOf(contains('Meshtastic'), contains('MeshCore')),
          reason: '$locale',
        );
        expect(
          scannerLookingSubtitle(t, meshCoreEnabled: false),
          allOf(contains('Meshtastic'), isNot(contains('MeshCore'))),
          reason: '$locale',
        );
      }
    });
  });

  group('scannerDeviceNotFoundSubtitle', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('only a Bluetooth radio gets the Bluetooth advice', () {
      expect(
        scannerDeviceNotFoundSubtitle(l10n, TransportType.ble),
        l10n.scannerDeviceNotFoundSubtitle,
      );
      expect(
        scannerDeviceNotFoundSubtitle(l10n, null),
        l10n.scannerDeviceNotFoundSubtitle,
      );
      final network = scannerDeviceNotFoundSubtitle(
        l10n,
        TransportType.network,
      );
      final usb = scannerDeviceNotFoundSubtitle(l10n, TransportType.usb);
      expect(network, l10n.scannerDeviceNotFoundSubtitleNetwork);
      expect(usb, l10n.scannerDeviceNotFoundSubtitleUsb);
      expect(network, isNot(contains('Bluetooth')));
      expect(usb, isNot(contains('Bluetooth')));
    });

    test('every locale has its own network and USB advice', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final t = lookupAppLocalizations(locale);
        expect(
          t.scannerDeviceNotFoundSubtitleNetwork,
          isNot(t.scannerDeviceNotFoundSubtitle),
          reason: '$locale',
        );
        expect(
          t.scannerDeviceNotFoundSubtitleUsb,
          isNot(contains('Bluetooth')),
        );
      }
    });
  });
}
