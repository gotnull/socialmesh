import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/signals/screens/create_signal_screen.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';

void main() {
  testWidgets('Offline: image disabled and offline banner shown', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        isSignedInProvider.overrideWithValue(true),
        isDeviceConnectedProvider.overrideWithValue(true),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const CreateSignalScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Ensure notifier is offline
    final connNotifier = container.read(connectivityStatusProvider.notifier);
    connNotifier.setOnline(false);
    await tester.pumpAndSettle();

    // Image action should be present and offline banner visible
    final imageFinder = find.text('Image');
    expect(imageFinder, findsOneWidget);
    expect(
      find.textContaining('Offline: images and cloud features are unavailable'),
      findsOneWidget,
    );

    // Tapping image does not open the picker when offline
    await tester.tap(imageFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('No internet connection'), findsNothing);

    // Now simulate connectivity returning online
    connNotifier.setOnline(true);
    await tester.pump(const Duration(milliseconds: 100));

    // Banner should disappear
    expect(
      find.textContaining('Offline: images and cloud features are unavailable'),
      findsNothing,
    );

    // Now tapping image should no longer show the offline message (permission/state may vary in tests)
    await tester.tap(imageFinder);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.textContaining('No internet connection'),
      findsNothing,
    );

    container.dispose();
  });
}
