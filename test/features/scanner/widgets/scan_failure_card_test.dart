// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/scanner/widgets/scan_failure_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Future<AppLocalizations> _pumpCard(
  WidgetTester tester, {
  required BleScanFailureKind kind,
  Locale locale = const Locale('en'),
  double width = 360,
  double textScale = 1.0,
  VoidCallback? onDismiss,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Material(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ScanFailureCard(
                  kind: kind,
                  onDismiss: onDismiss ?? () {},
                  onOpenSettings: onOpenSettings ?? () {},
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return l10n;
}

void main() {
  group('ScanFailureCard copy and action per kind', () {
    testWidgets(
      'locationServicesOff explains Location and opens its settings',
      (tester) async {
        var opened = 0;
        final l10n = await _pumpCard(
          tester,
          kind: BleScanFailureKind.locationServicesOff,
          onOpenSettings: () => opened++,
        );
        expect(find.text(l10n.scannerLocationServicesOffTitle), findsOneWidget);
        expect(find.text(l10n.scannerLocationServicesOffBody), findsOneWidget);
        await tester.tap(find.text(l10n.scannerOpenLocationSettings));
        expect(opened, 1);
      },
    );

    testWidgets('permissionDenied explains the grant and opens app settings', (
      tester,
    ) async {
      var opened = 0;
      final l10n = await _pumpCard(
        tester,
        kind: BleScanFailureKind.permissionDenied,
        onOpenSettings: () => opened++,
      );
      expect(find.text(l10n.scannerScanPermissionTitle), findsOneWidget);
      expect(find.text(l10n.scannerScanPermissionBody), findsOneWidget);
      await tester.tap(find.text(l10n.scannerOpenAppSettings));
      expect(opened, 1);
    });

    testWidgets('stackFailure keeps its copy and Bluetooth settings action', (
      tester,
    ) async {
      var opened = 0;
      final l10n = await _pumpCard(
        tester,
        kind: BleScanFailureKind.stackFailure,
        onOpenSettings: () => opened++,
      );
      expect(find.text(l10n.scannerScanStackErrorTitle), findsOneWidget);
      expect(find.text(l10n.scannerScanStackErrorBody), findsOneWidget);
      await tester.tap(
        find.text(l10n.scannerPairingRefreshOpenBluetoothSettings),
      );
      expect(opened, 1);
    });

    testWidgets('throttled keeps its copy and shows no action', (tester) async {
      final l10n = await _pumpCard(tester, kind: BleScanFailureKind.throttled);
      expect(find.text(l10n.scannerScanThrottledTitle), findsOneWidget);
      expect(find.text(l10n.scannerScanThrottledBody), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('the close icon dismisses', (tester) async {
      var dismissed = 0;
      await _pumpCard(
        tester,
        kind: BleScanFailureKind.locationServicesOff,
        onDismiss: () => dismissed++,
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(dismissed, 1);
    });
  });

  // Overflow raises a FlutterError in the test binding, so a clean pump
  // at the narrowest supported width and enlarged text proves the card
  // wraps rather than clips, in every shipped locale.
  group('ScanFailureCard layout', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final kind in BleScanFailureKind.values) {
        testWidgets(
          'no overflow: ${locale.languageCode} ${kind.name} at 320dp, 1.5x text',
          (tester) async {
            await _pumpCard(
              tester,
              kind: kind,
              locale: locale,
              width: 320,
              textScale: 1.5,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
