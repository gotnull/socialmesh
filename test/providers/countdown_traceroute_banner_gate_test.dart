// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the global "Traceroute complete" banner gate. The banner is owned
// by CountdownNotifier (not any screen), so a completed run must be
// credited to a recent user-initiated send from ANY launch surface - the
// node details screen, the traceroute history screen, or the nodes-list
// long-press menu all funnel through startTracerouteCountdown.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/countdown_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TraceRouteLog makeRun(int targetNode, {String? id}) {
    return TraceRouteLog(
      id: id,
      nodeNum: targetNode,
      targetNode: targetNode,
      sent: true,
      response: true,
      hopsTowards: 2,
      hopsBack: 2,
      hops: const [],
      snr: 5.5,
    );
  }

  CountdownNotifier makeNotifier() {
    final container = ProviderContainer(
      overrides: [
        connectionStateProvider.overrideWith(
          (ref) => const Stream<DeviceConnectionState>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(countdownProvider.notifier);
  }

  group('shouldAnnounceTracerouteRun', () {
    test('announces a response to a recent send, exactly once', () {
      final notifier = makeNotifier();
      notifier.startTracerouteCountdown(111);

      final run = makeRun(111);
      expect(notifier.shouldAnnounceTracerouteRun(run), isTrue);
      // Duplicate reply for the same run id stays silent.
      expect(notifier.shouldAnnounceTracerouteRun(run), isFalse);
    });

    test('a second reply to the same send stays silent', () {
      final notifier = makeNotifier();
      notifier.startTracerouteCountdown(111);

      expect(notifier.shouldAnnounceTracerouteRun(makeRun(111)), isTrue);
      // A different run id but no new send: the send credit was consumed.
      expect(notifier.shouldAnnounceTracerouteRun(makeRun(111)), isFalse);
    });

    test('ignores responses for nodes the user never traced', () {
      final notifier = makeNotifier();
      notifier.startTracerouteCountdown(111);

      expect(notifier.shouldAnnounceTracerouteRun(makeRun(222)), isFalse);
    });

    test('ignores responses arriving after the completion window', () {
      final notifier = makeNotifier();
      notifier.startTracerouteCountdown(111);

      final lateArrival = DateTime.now().add(const Duration(minutes: 3));
      expect(
        notifier.shouldAnnounceTracerouteRun(makeRun(111), now: lateArrival),
        isFalse,
      );
      // The expired credit is gone for good, not just for that reply.
      expect(notifier.shouldAnnounceTracerouteRun(makeRun(111)), isFalse);
    });

    test('a fresh send re-arms the banner for the same node', () {
      final notifier = makeNotifier();
      notifier.startTracerouteCountdown(111);
      expect(notifier.shouldAnnounceTracerouteRun(makeRun(111)), isTrue);

      notifier.startTracerouteCountdown(111);
      expect(notifier.shouldAnnounceTracerouteRun(makeRun(111)), isTrue);
    });
  });
}
