// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-B: `showMeshCoreRepeaterCliHelpSheet` widget pins.
//
// Pinned invariants:
//   - Sheet opens via `AppBottomSheet.showScrollable` (NOT
//     `showDialog`/`AlertDialog`).
//   - Three section headers render: General, Settings, Neighbours.
//   - Tapping a help row pops the sheet and returns the command
//     template to the caller.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_repeater_cli_help_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

class _HelpLauncher extends StatelessWidget {
  final void Function(String?) onPicked;
  const _HelpLauncher({required this.onPicked});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const ValueKey('launch'),
            onPressed: () async {
              final picked = await showMeshCoreRepeaterCliHelpSheet(context);
              onPicked(picked);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Widget _wrap({required void Function(String?) onPicked}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: _HelpLauncher(onPicked: onPicked),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('sheet renders the canonical 7 section headers (D49-D4)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(onPicked: (_) {}));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('launch')));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreRepeaterCliHelpTitle), findsOneWidget);

    // The sheet's DraggableScrollableSheet only renders visible
    // section headers; scroll the list to bring each one into view
    // before asserting it. Use a Scrollable finder rather than
    // ListView so it works whether the sheet wraps in a ListView,
    // CustomScrollView, or other scrollable variant.
    final scrollable = find.byType(Scrollable);
    for (final header in <String>[
      _l10n.meshcoreRepeaterCliHelpGeneralHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpSettingsHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpBridgeHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpLoggingHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpNeighborsHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpRegionHeader.toUpperCase(),
      _l10n.meshcoreRepeaterCliHelpGpsHeader.toUpperCase(),
    ]) {
      await tester.scrollUntilVisible(
        find.text(header),
        300,
        scrollable: scrollable.first,
      );
      expect(
        find.text(header),
        findsOneWidget,
        reason: 'section header "$header" must render',
      );
    }
  });

  testWidgets('tapping a help row pops sheet with command template', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? picked;
    await tester.pumpWidget(_wrap(onPicked: (v) => picked = v));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('launch')));
    await _settle(tester);

    // Tap the first General-section command: "advert".
    await tester.tap(find.text('advert'));
    await _settle(tester);

    expect(picked, 'advert');
  });

  testWidgets('does NOT use AlertDialog / showDialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(onPicked: (_) {}));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('launch')));
    await _settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SimpleDialog), findsNothing);
  });
}
