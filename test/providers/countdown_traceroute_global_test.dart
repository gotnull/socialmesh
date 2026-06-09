// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/countdown_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        // CountdownNotifier.build() listens to connectionStateProvider; give it
        // an inert stream so the notifier builds without a real transport.
        connectionStateProvider.overrideWith(
          (ref) => const Stream<DeviceConnectionState>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('global traceroute cooldown', () {
    test('is zero / null when no traceroute is active', () {
      final container = makeContainer();
      final notifier = container.read(countdownProvider.notifier);

      expect(notifier.globalTracerouteRemaining, 0);
      expect(notifier.activeTracerouteTask, isNull);
      expect(container.read(activeTracerouteProvider), isNull);
    });

    test('a countdown started for one node reflects globally on any query', () {
      final container = makeContainer();
      final notifier = container.read(countdownProvider.notifier);

      // Start a cooldown targeting one specific node (e.g. 111).
      notifier.startCountdown(
        id: CountdownNotifier.tracerouteId(111),
        label: 'Traceroute to A',
        totalSeconds: CountdownNotifier.tracerouteCooldownSeconds,
        type: CountdownType.traceroute,
        targetNodeNum: 111,
      );

      // The cooldown is now globally active — the firmware rate-limits
      // traceroute device-wide, so every button must see it regardless of
      // which node it represents.
      expect(
        notifier.globalTracerouteRemaining,
        CountdownNotifier.tracerouteCooldownSeconds,
      );

      final active = container.read(activeTracerouteProvider);
      expect(active, isNotNull);
      expect(active!.targetNodeNum, 111);
      expect(active.type, CountdownType.traceroute);
    });

    test('non-traceroute countdowns do not register as a traceroute', () {
      final container = makeContainer();
      final notifier = container.read(countdownProvider.notifier);

      notifier.startDeviceRebootCountdown();

      expect(notifier.globalTracerouteRemaining, 0);
      expect(notifier.activeTracerouteTask, isNull);
      expect(container.read(activeTracerouteProvider), isNull);
    });
  });
}
