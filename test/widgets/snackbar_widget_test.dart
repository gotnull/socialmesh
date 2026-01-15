import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/snackbar.dart';

void main() {
  testWidgets('Snackbar shows with blur and rounded top corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => showSuccessSnackBar(context, 'Signal sent'),
                  child: const Text('Show'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Tap the button to show snackbar
    await tester.tap(find.text('Show'));
    await tester.pump();

    // SnackBar should be present
    expect(find.text('Signal sent'), findsOneWidget);

    // Verify the SnackBar has a ClipRRect/BackdropFilter ancestor (blur present)
    final snack = find.text('Signal sent');
    expect(
      find.ancestor(of: snack, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );

    // Verify top-left/top-right radius by inspecting the ClipRRect
    final clip = find.ancestor(of: snack, matching: find.byType(ClipRRect));
    expect(clip, findsOneWidget);

    // Verify SnackBar widget has a top-only rounded shape to avoid bottom corner artifacts
    final snackBarWidget = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBarWidget.shape, isA<RoundedRectangleBorder>());
    final rounded = snackBarWidget.shape as RoundedRectangleBorder;
    expect(
      rounded.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    );
  });
}
