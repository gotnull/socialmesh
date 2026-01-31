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
          home: Scaffold(
            body: TopStatusBanner(
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
      ),
    );

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
}
