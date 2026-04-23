// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/peer_pet_live_state.dart';
import 'package:socialmesh/features/pet/services/peer_pet_live_state_mapper.dart';

/// All tests use a fixed "now" so schedule math is deterministic.
final _now = DateTime.utc(2026, 1, 1, 12, 0, 0);

PeerPresenceSignal _signal({
  Duration? sinceLastSeen,
  Duration? sinceObserved,
  bool isAsleepOnWire = false,
  bool isDormantOnWire = false,
}) => PeerPresenceSignal(
  sinceLastSeen: sinceLastSeen,
  sinceObserved: sinceObserved,
  isAsleepOnWire: isAsleepOnWire,
  isDormantOnWire: isDormantOnWire,
);

void main() {
  group('PeerPetLiveStateMapper.resolveRaw', () {
    const mapper = PeerPetLiveStateMapper();

    test('dormant on wire wins over everything — not freshness-gated', () {
      final s = _signal(
        sinceLastSeen: const Duration(seconds: 5),
        sinceObserved: const Duration(days: 30),
        isDormantOnWire: true,
      );
      expect(mapper.resolveRaw(s), PeerPetLiveBand.dormant);
    });

    test('asleep on wire is honored while observation is fresh', () {
      final s = _signal(
        sinceLastSeen: const Duration(seconds: 5),
        sinceObserved: const Duration(minutes: 1),
        isAsleepOnWire: true,
      );
      expect(mapper.resolveRaw(s), PeerPetLiveBand.sleepy);
    });

    test('asleep on wire is IGNORED when observation is stale (>30m)', () {
      // Peer was asleep 2h ago. That flag is no longer authoritative —
      // fall through to presence freshness (10s → active).
      final s = _signal(
        sinceLastSeen: const Duration(seconds: 10),
        sinceObserved: const Duration(hours: 2),
        isAsleepOnWire: true,
      );
      expect(mapper.resolveRaw(s), PeerPetLiveBand.active);
    });

    test('freshness ladder — active (<60s)', () {
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(seconds: 30))),
        PeerPetLiveBand.active,
      );
    });

    test('freshness ladder — calm (60s ≤ x < 5m)', () {
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(seconds: 60))),
        PeerPetLiveBand.calm,
      );
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(minutes: 4))),
        PeerPetLiveBand.calm,
      );
    });

    test('freshness ladder — idle (5m ≤ x < 30m)', () {
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(minutes: 5))),
        PeerPetLiveBand.idle,
      );
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(minutes: 29))),
        PeerPetLiveBand.idle,
      );
    });

    test('freshness ladder — unknown (≥ 30m or absent)', () {
      expect(
        mapper.resolveRaw(_signal(sinceLastSeen: const Duration(minutes: 30))),
        PeerPetLiveBand.unknown,
      );
      expect(mapper.resolveRaw(_signal()), PeerPetLiveBand.unknown);
    });
  });

  group('PeerPetLiveStateMapper.smooth — rule 0: same-band', () {
    const mapper = PeerPetLiveStateMapper();

    test('same band emits nothing and clears any stale pending', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.active,
        pendingBand: PeerPetLiveBand.calm, // stale pending
        pendingSince: _now.subtract(const Duration(seconds: 5)),
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, isNull);
      expect(d.fireAt, isNull);
    });
  });

  group('PeerPetLiveStateMapper.smooth — rule 1: sleepy/dormant entry', () {
    const mapper = PeerPetLiveStateMapper();

    test('any -> sleepy is immediate', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.sleepy,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(isAsleepOnWire: true),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.sleepy);
      expect(d.pendingBand, isNull);
    });

    test('any -> dormant is immediate', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.idle,
        incoming: PeerPetLiveBand.dormant,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(isDormantOnWire: true),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.dormant);
    });
  });

  group('PeerPetLiveStateMapper.smooth — rule 2: sleepy/dormant EXIT', () {
    const mapper = PeerPetLiveStateMapper();

    test('exit sleepy without wire-clearance requires cooldown', () {
      // Signal says peer was recently observed 20s ago (so not within
      // the 10s explicit-clearance window) with flags now false.
      final d = mapper.smooth(
        current: PeerPetLiveBand.sleepy,
        incoming: PeerPetLiveBand.active,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(sinceObserved: const Duration(seconds: 20)),
        now: _now,
      );
      expect(d.emit, isNull, reason: 'must not flap out of sleepy');
      expect(d.pendingBand, PeerPetLiveBand.active);
      expect(d.fireAt, _now.add(const Duration(seconds: 15)));
    });

    test('exit sleepy WITH fresh wire clearance (≤10s) is immediate', () {
      // The peer freshly and explicitly said "awake" — trust it.
      final d = mapper.smooth(
        current: PeerPetLiveBand.sleepy,
        incoming: PeerPetLiveBand.active,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(sinceObserved: const Duration(seconds: 2)),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.active);
    });

    test('exit sleepy with NO observation requires cooldown', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.sleepy,
        incoming: PeerPetLiveBand.active,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(), // no observation at all
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.active);
    });

    test('exit dormant with wire clearance still immediate (symmetry)', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.dormant,
        incoming: PeerPetLiveBand.active,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(sinceObserved: const Duration(seconds: 5)),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.active);
    });
  });

  group('PeerPetLiveStateMapper.smooth — rules 3 & 4: upgrades', () {
    const mapper = PeerPetLiveStateMapper();

    test('any non-low-energy -> active is immediate', () {
      for (final from in [
        PeerPetLiveBand.calm,
        PeerPetLiveBand.idle,
        PeerPetLiveBand.unknown,
      ]) {
        final d = mapper.smooth(
          current: from,
          incoming: PeerPetLiveBand.active,
          pendingBand: null,
          pendingSince: null,
          signal: _signal(sinceLastSeen: const Duration(seconds: 5)),
          now: _now,
        );
        expect(d.emit, PeerPetLiveBand.active, reason: 'from ${from.name}');
      }
    });

    test('idle -> calm is immediate (rank upgrade)', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.idle,
        incoming: PeerPetLiveBand.calm,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.calm);
    });

    test('unknown -> calm is immediate (rank upgrade)', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.unknown,
        incoming: PeerPetLiveBand.calm,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.calm);
    });
  });

  group('PeerPetLiveStateMapper.smooth — rule 5: downgrade cooldown', () {
    const mapper = PeerPetLiveStateMapper(
      downgradeCooldown: Duration(seconds: 15),
    );

    test('fresh downgrade starts a pending clock, no emit', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.calm,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.calm);
      expect(d.fireAt, _now.add(const Duration(seconds: 15)));
    });

    test('same pending band holding < cooldown: hold pending, no emit', () {
      // 10s have elapsed since we first went to "pending calm".
      final pendingSince = _now.subtract(const Duration(seconds: 10));
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.calm,
        pendingBand: PeerPetLiveBand.calm,
        pendingSince: pendingSince,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.calm);
      // Re-emits the SAME fireAt so the owner doesn't schedule a
      // second timer.
      expect(d.fireAt, pendingSince.add(const Duration(seconds: 15)));
    });

    test('same pending band holding ≥ cooldown: emits + clears pending', () {
      final pendingSince = _now.subtract(const Duration(seconds: 16));
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.calm,
        pendingBand: PeerPetLiveBand.calm,
        pendingSince: pendingSince,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, PeerPetLiveBand.calm);
      expect(d.pendingBand, isNull);
      expect(d.fireAt, isNull);
    });

    test('pending band CHANGES: restart clock at now (no timer pile-up)', () {
      // Was pending -> calm; signal now pushes us to idle. New clock.
      final d = mapper.smooth(
        current: PeerPetLiveBand.active,
        incoming: PeerPetLiveBand.idle,
        pendingBand: PeerPetLiveBand.calm,
        pendingSince: _now.subtract(const Duration(seconds: 12)),
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.idle);
      expect(d.fireAt, _now.add(const Duration(seconds: 15)));
    });

    test('idle -> unknown (lateral-to-unknown) requires cooldown', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.idle,
        incoming: PeerPetLiveBand.unknown,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(),
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.unknown);
    });
  });

  group('PeerPetLiveStateMapper.smooth — unknown transitions', () {
    const mapper = PeerPetLiveStateMapper();

    test('sleepy -> unknown goes through rule 2 (exit sleepy) cooldown', () {
      final d = mapper.smooth(
        current: PeerPetLiveBand.sleepy,
        incoming: PeerPetLiveBand.unknown,
        pendingBand: null,
        pendingSince: null,
        signal: _signal(), // no fresh observation
        now: _now,
      );
      expect(d.emit, isNull);
      expect(d.pendingBand, PeerPetLiveBand.unknown);
    });
  });
}
