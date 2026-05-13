// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/app_bottom_sheet.dart';

void main() {
  group('AppBottomSheet.showConfirm', () {
    testWidgets('Confirm button pops with true', (tester) async {
      bool? result;
      late BuildContext rootContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                rootContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final future = AppBottomSheet.showConfirm(
        context: rootContext,
        title: 'Title',
        message: 'Message',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      result = await future;
      expect(result, true);
    });

    testWidgets('Cancel button pops with false', (tester) async {
      bool? result;
      late BuildContext rootContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                rootContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final future = AppBottomSheet.showConfirm(
        context: rootContext,
        title: 'Title',
        message: 'Message',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      result = await future;
      expect(result, false);
    });

    // Crashlytics ec04559d: when the underlying screen unmounts while the
    // sheet is open, the buttons must still pop cleanly. Pre-fix this
    // crashed with `Null check operator used on a null value` because the
    // button closures captured the dead caller context.
    testWidgets('Confirm still pops after the caller screen is unmounted', (
      tester,
    ) async {
      late BuildContext callerContext;
      var showCaller = true;
      late StateSetter rebuildRoot;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (rootContext, setState) {
              rebuildRoot = setState;
              if (!showCaller) {
                return const Scaffold(body: Center(child: Text('replaced')));
              }
              return Scaffold(
                body: Builder(
                  builder: (context) {
                    callerContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      final future = AppBottomSheet.showConfirm(
        context: callerContext,
        title: 'Title',
        message: 'Message',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      );
      await tester.pumpAndSettle();

      // Tear down the subtree that owned `callerContext`. After this rebuild
      // the original Builder is gone, so any code that closed over
      // `callerContext` would see a defunct element.
      rebuildRoot(() => showCaller = false);
      await tester.pump();

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(await future, true);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppBottomSheet.showPicker', () {
    testWidgets('picker still pops after the caller screen is unmounted', (
      tester,
    ) async {
      late BuildContext callerContext;
      var showCaller = true;
      late StateSetter rebuildRoot;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (rootContext, setState) {
              rebuildRoot = setState;
              if (!showCaller) {
                return const Scaffold(body: Center(child: Text('replaced')));
              }
              return Scaffold(
                body: Builder(
                  builder: (context) {
                    callerContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      final future = AppBottomSheet.showPicker<String>(
        context: callerContext,
        title: 'Pick',
        items: const ['alpha', 'beta'],
        itemBuilder: (item, _) =>
            Padding(padding: const EdgeInsets.all(16), child: Text(item)),
      );
      await tester.pumpAndSettle();

      rebuildRoot(() => showCaller = false);
      await tester.pump();

      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(await future, 'beta');
      expect(tester.takeException(), isNull);
    });
  });
}
