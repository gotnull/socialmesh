// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the contract that `_awaitRegionConfirmation` waits on
/// `OperationalReadiness.ready` instead of `DevicePairingState.connected`.
///
/// Background: the prior predicate completed when the BLE link came
/// back up after the post-region reboot, but BEFORE phase-2 (queue
/// drain + full config). Healthy hardware finished phase-2 inside
/// the 60s scanner hard-timeout, but slow firmware didn't, and the
/// outer scanner timeout fired first while the inner readiness
/// machine was still hydrating. The user saw an indefinite Connecting
/// overlay and a status=failed REGION_FLOW log with reason=TimeoutException
/// even though the device was actually moving toward `ready`.
///
/// Driving the full provider graph end-to-end requires the
/// ProtocolService + transport + readiness stream stack — not in
/// scope for a surgical patch test. These pins assert the shape of
/// the implementation contract via source-level inspection.
void main() {
  late String source;
  setUpAll(() async {
    source = await File('lib/providers/app_providers.dart').readAsString();
  });

  group('region confirmation listens to readiness, not just transport state', () {
    test('subscribes to meshtasticReadinessProvider in addition to '
        'deviceConnectionProvider', () {
      // Both subscriptions must be attached. Without the readiness
      // arm, completion still fires on transport.connected and the
      // regression returns.
      expect(
        source.contains(
          'ref.listen<AsyncValue<OperationalReadiness>>(\n      meshtasticReadinessProvider,',
        ),
        isTrue,
        reason:
            '_awaitRegionConfirmation must add a listener on '
            'meshtasticReadinessProvider so that completion is gated '
            'on protocol readiness, not just BLE link state.',
      );
    });

    test(
      'completes only when readiness reaches OperationalReadiness.ready',
      () {
        // The completion path inside the readiness listener must
        // require `readiness == OperationalReadiness.ready`.
        expect(
          source.contains('if (readiness != OperationalReadiness.ready)'),
          isTrue,
        );
        // And there must be at least one completeSuccess call from the
        // readiness arm (we use named reasons "ready_after_reboot" /
        // "ready_no_reboot" to disambiguate in logs).
        expect(
          source.contains("completeSuccess('ready_after_reboot')"),
          isTrue,
        );
      },
    );

    test('the connection-arm reconnect detection sync-reads live '
        'protocol.readiness instead of trusting a cached flag', () {
      // The legacy code (a) called completeSuccess() immediately when
      // next.state == DevicePairingState.connected after a saw-disconnect,
      // and (b) the first iteration of this patch trusted a cached
      // `readinessReady` boolean which Riverpod replayed from a stale
      // gen=1 emission across the device-reboot cycle. The current
      // shape sync-reads `protocol.readiness` at the moment of the
      // connected transition. Pin the shape so neither regression
      // sneaks back.
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains('final liveReadiness = protocol.readiness;'),
        isTrue,
        reason:
            'connection arm must sync-read live protocol.readiness '
            'instead of using the cached readinessReady boolean. A '
            'stale ready emission can otherwise leak from the prior '
            'session and prematurely complete the wait.',
      );
      expect(
        collapsed.contains(
          'if (liveReadiness == OperationalReadiness.ready) { '
          "completeSuccess('connected_then_ready');",
        ),
        isTrue,
      );
    });

    test('readinessReady is dropped when readiness leaves ready, so a '
        'stale gen=N ready emission cannot persist across a reboot cycle', () {
      // The single most important regression pin in this group: the
      // gen=1 stale-ready bug fired BECAUSE the readiness arm set
      // readinessReady=true on a stale emission and never cleared
      // it. The current shape clears the flag the moment readiness
      // drops below ready and emits a `readiness_dropped` log line
      // so the transition is visible in field debug.
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains(
              "'REGION_CONFIRMATION: readiness_dropped ' "
              "'readiness=",
            ) ||
            collapsed.contains(
              "'REGION_CONFIRMATION: readiness_dropped' "
              "'readiness=",
            ) ||
            collapsed.contains(
              'REGION_CONFIRMATION: readiness_dropped readiness=',
            ),
        isTrue,
        reason:
            'the readiness-dropped diagnostic is the smoking-gun log '
            'line for stale-flag regressions. If a future patch removes '
            'it without thinking, the regression returns silently.',
      );
      expect(
        collapsed.contains('readinessReady = false;'),
        isTrue,
        reason:
            'the flag MUST be cleared on any drop below ready. Without '
            'this, a Riverpod-cached ready emission from the prior '
            'session would persist across the reboot cycle and the '
            'connection arm could prematurely complete.',
      );
    });

    test('logs the canonical REGION_CONFIRMATION wait/ready/'
        'connected_not_ready/pairing_invalidated tags so log triage '
        'is unambiguous', () {
      expect(source.contains('REGION_CONFIRMATION: waiting readiness'), isTrue);
      expect(source.contains('REGION_CONFIRMATION: ready target='), isTrue);
      expect(
        source.contains('REGION_CONFIRMATION: connected_not_ready'),
        isTrue,
      );
      expect(
        source.contains('REGION_CONFIRMATION: pairing_invalidated'),
        isTrue,
      );
    });
  });

  group('terminal-invalidation surfaces as a typed exception', () {
    test('_RegionPairingInvalidatedException is defined and used in the '
        'terminal-invalidation branch', () {
      expect(
        source.contains('class _RegionPairingInvalidatedException'),
        isTrue,
        reason:
            'a typed exception lets applyRegion\'s catch (and downstream '
            'screens) distinguish pairing-invalidation from a plain '
            'TimeoutException — the former should route to re-pair, the '
            'latter should optimistically mark applied during onboarding.',
      );
      expect(
        source.contains(
              '_RegionPairingInvalidatedException(\n            \'Region apply canceled - pairing invalidated\'',
            ) ||
            source.contains('_RegionPairingInvalidatedException('),
        isTrue,
      );
    });
  });

  group('subscriptions are released cleanly', () {
    test('both listeners are closed in finally', () {
      expect(source.contains('connectionSub.close();'), isTrue);
      expect(source.contains('readinessSub.close();'), isTrue);
    });
  });

  group('timeout window is preserved (no silent extension)', () {
    test('the 90s timeout is unchanged in this patch', () {
      // The user explicitly called this out as a non-goal. Pin the
      // 90s window so a future patch that wants to extend it has to
      // either update this test or land a separate decision.
      expect(
        source.contains('Duration(seconds: 90)'),
        isTrue,
        reason:
            'the readiness predicate change must NOT silently raise the '
            'timeout. If a future patch needs more headroom, it should '
            'land that as an explicit product decision and update this pin.',
      );
    });
  });
}
