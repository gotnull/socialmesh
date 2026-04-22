// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/peer_pet_live_state.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
import 'package:socialmesh/features/pet/providers/pet_providers.dart';
import 'package:socialmesh/features/pet/services/peer_pet_live_state_mapper.dart';
import 'package:socialmesh/features/pet/services/pet_repository.dart';
import 'package:socialmesh/providers/app_providers.dart';

/// Test harness that wraps a ProviderContainer with closure-captured
/// input values. Calling [setObs] / [setLastSeen] updates the captured
/// value and invalidates the corresponding overridden provider so the
/// controller's `ref.listen` subscriptions fire through to
/// `_reevaluate`.
class _Harness {
  _Harness({required this.nodeNum, required this.clock, Duration? cooldown}) {
    container = ProviderContainer(
      overrides: [
        // Sync-derived observation view — test-friendly replacement
        // for the FutureProvider-backed remotePetProvider.
        peerPetObservationProvider(nodeNum).overrideWith((ref) => _obs),
        peerLastSeenProvider(nodeNum).overrideWith((ref) => _lastSeen),
        peerPetClockProvider.overrideWith((ref) => clock),
        peerPetLiveStateMapperProvider.overrideWith(
          (ref) => PeerPetLiveStateMapper(
            downgradeCooldown: cooldown ?? const Duration(seconds: 15),
          ),
        ),
      ],
    );
  }

  final int nodeNum;
  final DateTime Function() clock;
  late final ProviderContainer container;

  RemotePetObservation? _obs;
  DateTime? _lastSeen;

  void setObs(RemotePetObservation? v) {
    _obs = v;
    container.invalidate(peerPetObservationProvider(nodeNum));
  }

  void setLastSeen(DateTime? v) {
    _lastSeen = v;
    container.invalidate(peerLastSeenProvider(nodeNum));
  }

  PeerPetLiveBand currentBand() =>
      container.read(peerPetLiveStateProvider(nodeNum)).band;

  void dispose() => container.dispose();
}

PetPublicState _pub({
  PetStage stage = PetStage.adult,
  PetBranch branch = PetBranch.steady,
  PetMood mood = PetMood.content,
  bool isAsleep = false,
  int ageInDays = 10,
}) => PetPublicState(
  dnaSeed: 0xdeadbeef,
  stage: stage,
  branch: branch,
  mood: mood,
  ageInDays: ageInDays,
  isAsleep: isAsleep,
  isSick: false,
  isCalling: false,
  isEvolving: false,
);

void main() {
  group('PeerPetLiveStateController', () {
    test('initial build with fresh lastSeen emits active immediately', () {
      fakeAsync((async) {
        final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final h = _Harness(nodeNum: 1, clock: () => now);
        addTearDown(h.dispose);

        h.setLastSeen(now.subtract(const Duration(seconds: 20)));
        async.flushMicrotasks();

        expect(h.currentBand(), PeerPetLiveBand.active);
      });
    });

    test('downgrade to calm waits the full cooldown before emitting', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final h = _Harness(
          nodeNum: 2,
          clock: () => now,
          cooldown: const Duration(seconds: 15),
        );
        addTearDown(h.dispose);

        h.setLastSeen(now.subtract(const Duration(seconds: 10)));
        async.flushMicrotasks();
        expect(h.currentBand(), PeerPetLiveBand.active);

        // Peer quiets down (raw band now calm).
        now = now.add(const Duration(minutes: 2));
        h.setLastSeen(now.subtract(const Duration(seconds: 125)));
        async.flushMicrotasks();
        expect(
          h.currentBand(),
          PeerPetLiveBand.active,
          reason: 'must hold during cooldown',
        );

        // 10s elapsed — still held.
        now = now.add(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 10));
        expect(h.currentBand(), PeerPetLiveBand.active);

        // Past cooldown.
        now = now.add(const Duration(seconds: 6));
        async.elapse(const Duration(seconds: 6));
        expect(h.currentBand(), PeerPetLiveBand.calm);
      });
    });

    test(
      'rapid identical updates do not multi-emit (equality short-circuit)',
      () {
        fakeAsync((async) {
          var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
          final h = _Harness(nodeNum: 3, clock: () => now);
          addTearDown(h.dispose);

          h.setLastSeen(now.subtract(const Duration(seconds: 5)));
          async.flushMicrotasks();

          final emitted = <PeerPetLiveState>[];
          h.container.listen<PeerPetLiveState>(
            peerPetLiveStateProvider(3),
            (_, next) => emitted.add(next),
          );
          // Materialize.
          h.container.read(peerPetLiveStateProvider(3));

          // Five identical-band updates — raw stays "active" across all.
          for (var i = 1; i <= 5; i++) {
            now = now.add(const Duration(seconds: 1));
            h.setLastSeen(now.subtract(const Duration(seconds: 6)));
            async.flushMicrotasks();
          }

          expect(emitted, isEmpty, reason: 'same-band updates must not emit');
        });
      },
    );

    test('peer-flagged sleepy bypasses the cooldown on entry', () {
      fakeAsync((async) {
        final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final h = _Harness(nodeNum: 4, clock: () => now);
        addTearDown(h.dispose);

        h.setLastSeen(now.subtract(const Duration(seconds: 20)));
        async.flushMicrotasks();
        expect(h.currentBand(), PeerPetLiveBand.active);

        h.setObs(
          RemotePetObservation(
            nodeNum: 4,
            state: _pub(isAsleep: true),
            observedAt: now,
          ),
        );
        async.flushMicrotasks();

        expect(
          h.currentBand(),
          PeerPetLiveBand.sleepy,
          reason: 'wire-authoritative low-energy entry is immediate',
        );
      });
    });

    test('dispose cancels any pending cooldown timer', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final h = _Harness(nodeNum: 5, clock: () => now);

        h.setLastSeen(now.subtract(const Duration(seconds: 5)));
        async.flushMicrotasks();
        expect(h.currentBand(), PeerPetLiveBand.active);

        // Trigger a downgrade → schedules a 15s cooldown timer.
        now = now.add(const Duration(minutes: 3));
        h.setLastSeen(now.subtract(const Duration(seconds: 90)));
        async.flushMicrotasks();

        h.dispose();

        // If the timer leaked, fakeAsync flags pending timers at
        // scope exit. Advance past cooldown to prove no callback fires.
        async.elapse(const Duration(minutes: 5));
      });
    });

    test(
      'fresh lastSeen + NO remote observation → band tracks presence only',
      () {
        fakeAsync((async) {
          var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
          final h = _Harness(nodeNum: 6, clock: () => now);
          addTearDown(h.dispose);

          // No observation ever — purely presence-driven.
          h.setLastSeen(now.subtract(const Duration(seconds: 10)));
          async.flushMicrotasks();
          expect(
            h.currentBand(),
            PeerPetLiveBand.active,
            reason: 'raw band follows presence with no observation at all',
          );

          // Stale to 3 minutes → raw band becomes calm → cooldown applies.
          now = now.add(const Duration(minutes: 3));
          h.setLastSeen(now.subtract(const Duration(minutes: 3)));
          async.flushMicrotasks();
          expect(h.currentBand(), PeerPetLiveBand.active);

          now = now.add(const Duration(seconds: 16));
          async.elapse(const Duration(seconds: 16));
          expect(h.currentBand(), PeerPetLiveBand.calm);
        });
      },
    );

    test(
      'fresh lastSeen + STALE observation → presence wins (wire flags stale)',
      () {
        fakeAsync((async) {
          final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
          final h = _Harness(nodeNum: 7, clock: () => now);
          addTearDown(h.dispose);

          h.setLastSeen(now.subtract(const Duration(seconds: 15)));
          h.setObs(
            RemotePetObservation(
              nodeNum: 7,
              state: _pub(isAsleep: true), // flag WAS sleep, but...
              observedAt: now.subtract(const Duration(hours: 2)), // ...stale
            ),
          );
          async.flushMicrotasks();

          expect(
            h.currentBand(),
            PeerPetLiveBand.active,
            reason: 'stale wire sleep flag must not pin the band',
          );
        });
      },
    );
  });
}
