// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D40 - radio settings Apply confirmation flow pins.
//
// Pinned invariants:
//   - Tapping Apply with a populated, valid form opens the
//     confirm-before-apply bottom sheet rendering the canonical
//     title, message, and Apply-settings primary action.
//   - Tapping Cancel inside the confirm sheet closes it without
//     emitting any wire frames (the session-required path is not
//     reached; the "not connected" snackbar that would surface for
//     a null-session apply does NOT appear).
//   - Tapping Apply settings closes the confirm sheet and proceeds
//     to the pre-existing apply flow. With a null session in the
//     test (no real transport), this is observable as the
//     "not connected" error snackbar firing AFTER the user confirms
//     - which proves the apply path advanced past the confirm gate.
//
// We test the user-visible behaviour (sheet copy + Cancel short-
// circuit + confirm advance) rather than the wire payload; D26
// already pins the setRadioParams / setRadioTxPower byte vectors.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_radio_settings_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

final _l10n = AppLocalizationsEn();

MeshCoreSelfInfo _selfInfo() => MeshCoreSelfInfo(
  advType: 1,
  txPowerDbm: 22,
  maxLoraTxPower: 22,
  pubKey: Uint8List.fromList(List.generate(32, (i) => 0x40 + (i % 16))),
  freqKhz: 869618,
  bandwidthHz: 250000,
  spreadingFactor: 11,
  codingRate: 5,
  nodeName: 'TerryDev2',
  rawPayload: Uint8List(0),
);

Widget _harness({required MeshCoreSelfInfo selfInfo}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showMeshCoreRadioSettingsSheet(
                context: ctx,
                currentSelfInfo: selfInfo,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Drain any pending modal route timers so teardown doesn't trip
/// "Timer is still pending" on the auto-dismissing snackbar that
/// the apply-after-confirm path surfaces with a null session.
Future<void> _drainPending(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pop any open modal routes (the radio settings sheet + a possible
/// confirm sheet) so teardown doesn't trip
/// "NavigatorState was disposed with an active Ticker".
Future<void> _popOpenSheets(WidgetTester tester) async {
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isNotEmpty) {
    final navState = tester.state<NavigatorState>(navFinder.last);
    while (navState.canPop()) {
      navState.pop();
    }
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('tapping Apply opens the confirm sheet with canonical D40 copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(selfInfo: _selfInfo()));
    await tester.tap(find.text('Open'));
    await _settle(tester);

    // Tap Apply in the radio settings sheet.
    await tester.tap(find.text(_l10n.meshcoreRadioSettingsApply));
    await _settle(tester);

    // Confirm sheet now renders the canonical D40 strings.
    expect(find.text(_l10n.meshcoreRadioApplyConfirmTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreRadioApplyConfirmMessage), findsOneWidget);
    expect(find.text(_l10n.meshcoreRadioApplyConfirmAction), findsOneWidget);

    await _popOpenSheets(tester);
    await _drainPending(tester);
  });

  testWidgets(
    'Cancel on the confirm sheet bails out without entering the apply '
    'path (no null-session snackbar surfaces)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_harness(selfInfo: _selfInfo()));
      await tester.tap(find.text('Open'));
      await _settle(tester);

      await tester.tap(find.text(_l10n.meshcoreRadioSettingsApply));
      await _settle(tester);

      // Cancel the confirm sheet. Two "Cancel" buttons are on screen
      // (the radio settings sheet's own dismiss + the confirm sheet's
      // cancel); the confirm sheet's button is the most recently
      // built, so use `.last`.
      await tester.tap(find.text(_l10n.meshcoreCancel).last);
      await _settle(tester);

      // The apply path is gated by the confirm: Cancel must NOT have
      // reached the null-session check, so the "not connected"
      // snackbar must NOT be on screen.
      expect(find.text(_l10n.meshcoreNotConnectedToDevice), findsNothing);
      // Confirm sheet is gone; the radio settings sheet is still
      // open (we did not dismiss it).
      expect(find.text(_l10n.meshcoreRadioApplyConfirmTitle), findsNothing);

      await _popOpenSheets(tester);
      await _drainPending(tester);
    },
  );

  testWidgets('tapping Apply settings on the confirm sheet advances past the '
      'gate to the existing apply path', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(selfInfo: _selfInfo()));
    await tester.tap(find.text('Open'));
    await _settle(tester);

    await tester.tap(find.text(_l10n.meshcoreRadioSettingsApply));
    await _settle(tester);

    // Confirm and advance.
    await tester.tap(find.text(_l10n.meshcoreRadioApplyConfirmAction));
    await _settle(tester);

    // With a null session in the test harness, the existing apply
    // path surfaces the "not connected to device" error snackbar.
    // That snackbar appearing AFTER confirm is the observable
    // signal that the gate let the apply path proceed.
    expect(find.text(_l10n.meshcoreNotConnectedToDevice), findsOneWidget);

    await _popOpenSheets(tester);
    await _drainPending(tester);
  });
}
