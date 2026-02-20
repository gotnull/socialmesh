import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/widgets/top_status_banner.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';

void main() {
  testWidgets('invalidated banner hides retry and routes to scanner', (
    tester,
  ) async {
    var wentToScanner = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.failed,
            autoReconnectEnabled: true,
            onRetry: () => fail('Retry should not be shown'),
            onGoToScanner: () => wentToScanner = true,
            deviceState: const DeviceConnectionState2(
              state: DevicePairingState.pairedDeviceInvalidated,
              reason: DisconnectReason.deviceNotFound,
              errorMessage: 'Device was reset or replaced. Set it up again.',
            ),
          ),
        ),
      ),
    );

    // Let the slide-in animation complete (350ms) without triggering
    // the 2-second dismiss timer that pumpAndSettle would advance past.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Retry'), findsNothing);
    expect(
      find.text(
        'Device was reset or replaced. Forget it from Bluetooth settings and set it up again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(InkWell));
    expect(wentToScanner, isTrue);
  });

  testWidgets('auth failure banner shows correct message and hides retry', (
    tester,
  ) async {
    var wentToScanner = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.failed,
            autoReconnectEnabled: true,
            onRetry: () =>
                fail('Retry should not be callable for auth failure'),
            onGoToScanner: () => wentToScanner = true,
            deviceState: const DeviceConnectionState2(
              state: DevicePairingState.disconnected,
              reason: DisconnectReason.authFailed,
              errorMessage:
                  'Protocol configuration failed: Configuration timed out - device may require pairing or PIN was cancelled',
            ),
          ),
        ),
      ),
    );

    // Let the slide-in animation complete (350ms) without triggering
    // the 2-second dismiss timer that pumpAndSettle would advance past.
    await tester.pump(const Duration(milliseconds: 400));

    // Retry button should NOT be shown for auth failures
    expect(find.text('Retry'), findsNothing);

    // Auth failure message should be shown instead of "Device not found"
    expect(
      find.text('Authentication failed — re-pair in Scanner'),
      findsOneWidget,
    );
    expect(find.text('Device not found'), findsNothing);

    // Tapping the banner should navigate to Scanner
    await tester.tap(find.byType(InkWell));
    expect(wentToScanner, isTrue);
  });

  testWidgets('device not found banner still shows retry button', (
    tester,
  ) async {
    var retryTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.failed,
            autoReconnectEnabled: true,
            onRetry: () => retryTapped = true,
            onGoToScanner: () {},
            deviceState: const DeviceConnectionState2(
              state: DevicePairingState.disconnected,
              reason: DisconnectReason.deviceNotFound,
              errorMessage: 'Device not found',
            ),
          ),
        ),
      ),
    );

    // Let the slide-in animation complete (350ms) without triggering
    // the 2-second dismiss timer that pumpAndSettle would advance past.
    await tester.pump(const Duration(milliseconds: 400));

    // Retry button SHOULD be shown for device-not-found
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Device not found'), findsOneWidget);

    // Auth failure message should NOT be shown
    expect(
      find.text('Authentication failed — re-pair in Scanner'),
      findsNothing,
    );

    await tester.tap(find.text('Retry'));
    expect(retryTapped, isTrue);
  });

  testWidgets('reconnecting banner shows Cancel action', (tester) async {
    var wentToScanner = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.scanning,
            autoReconnectEnabled: true,
            onRetry: () {},
            onGoToScanner: () => wentToScanner = true,
            deviceState: const DeviceConnectionState2(
              state: DevicePairingState.scanning,
              reason: DisconnectReason.none,
            ),
          ),
        ),
      ),
    );

    // Let the slide-in animation complete.
    await tester.pump(const Duration(milliseconds: 400));

    // Should show searching text and Cancel action.
    expect(find.text('Searching for device...'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Retry should NOT be shown during active reconnecting.
    expect(find.text('Retry'), findsNothing);

    // Tapping the banner should navigate to scanner.
    await tester.tap(find.byType(InkWell));
    expect(wentToScanner, isTrue);
  });

  testWidgets('reconnecting banner shows Cancel for connecting state too', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.connecting,
            autoReconnectEnabled: true,
            onRetry: () {},
            onGoToScanner: () {},
            deviceState: const DeviceConnectionState2(
              state: DevicePairingState.connecting,
              reason: DisconnectReason.none,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Reconnecting...'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
