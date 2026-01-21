import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/top_status_banner.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/reconnect_compass_providers.dart';
import 'package:socialmesh/widgets/reconnect_compass_badge.dart';

void main() {
  const deviceState = DeviceConnectionState2(
    state: DevicePairingState.scanning,
  );

  testWidgets('shows compass badge when reconnecting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reconnectCompassStateProvider.overrideWithValue(
            const ReconnectCompassState(
              headingAvailable: true,
              currentHeadingDeg: 0,
              bestHeadingDeg: 90,
              confidence: 0.5,
              lastRssi: -60,
            ),
          ),
        ],
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.scanning,
            autoReconnectEnabled: true,
            onRetry: () {},
            deviceState: deviceState,
          ),
        ),
      ),
    );

    expect(find.byType(ReconnectCompassBadge), findsOneWidget);
  });

  testWidgets('renders fallback icon when heading unavailable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reconnectCompassStateProvider.overrideWithValue(
            const ReconnectCompassState(
              headingAvailable: false,
              currentHeadingDeg: null,
              bestHeadingDeg: null,
              confidence: 0,
            ),
          ),
        ],
        child: MaterialApp(
          home: TopStatusBanner(
            autoReconnectState: AutoReconnectState.connecting,
            autoReconnectEnabled: true,
            onRetry: () {},
            deviceState: deviceState,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
  });
}
