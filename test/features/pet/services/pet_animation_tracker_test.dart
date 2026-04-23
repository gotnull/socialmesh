// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Verifies the durable watermark semantics of PetAnimationTracker:
// one-shot hatch / evolution effects must not replay on widget rebuild,
// app resume, or unrelated provider invalidation.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/pet/models/care_event.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_animation_tracker.dart';

const _ownerNodeNum = 0xBEEF1234;
final _hatch = DateTime(2026, 5, 1, 12);

PetState _stateWithTransitions(List<CareEvent> events) {
  // Start from a minimal egg state and append the supplied events.
  final base = PetState.egg(ownerNodeNum: _ownerNodeNum, hatchedAt: _hatch);
  return base.copyWith(recentEvents: [...base.recentEvents, ...events]);
}

CareEvent _advanced(DateTime at) =>
    CareEvent(at: at, kind: CareEventKind.stageAdvanced);

Future<PetAnimationTracker> _newTracker() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return PetAnimationTracker(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetAnimationTracker — watermark mechanics', () {
    test('ackedAt returns epoch-0 on a fresh install', () async {
      final t = await _newTracker();
      expect(t.ackedAt(_ownerNodeNum), DateTime.fromMillisecondsSinceEpoch(0));
    });

    test(
      'latestUnacknowledged returns most recent stageAdvanced event',
      () async {
        final t = await _newTracker();
        final state = _stateWithTransitions([
          _advanced(_hatch.add(const Duration(minutes: 10))),
          _advanced(_hatch.add(const Duration(days: 2, minutes: 10))),
          _advanced(_hatch.add(const Duration(days: 6, minutes: 10))),
        ]);
        final latest = t.latestUnacknowledged(state);
        expect(latest, isNotNull);
        expect(latest!.at, _hatch.add(const Duration(days: 6, minutes: 10)));
      },
    );

    test('acknowledge hides events at or before the watermark', () async {
      final t = await _newTracker();
      final ackAt = _hatch.add(const Duration(days: 2, minutes: 10));
      await t.acknowledge(_ownerNodeNum, ackAt);

      final state = _stateWithTransitions([
        _advanced(_hatch.add(const Duration(minutes: 10))),
        _advanced(ackAt),
        _advanced(_hatch.add(const Duration(days: 6, minutes: 10))),
      ]);
      final latest = t.latestUnacknowledged(state);
      expect(latest, isNotNull);
      expect(latest!.at, _hatch.add(const Duration(days: 6, minutes: 10)));
    });

    test(
      'events with timestamp EXACTLY equal to watermark are acknowledged',
      () async {
        final t = await _newTracker();
        final boundary = _hatch.add(const Duration(minutes: 10));
        await t.acknowledge(_ownerNodeNum, boundary);
        final state = _stateWithTransitions([_advanced(boundary)]);
        expect(t.latestUnacknowledged(state), isNull);
      },
    );

    test('repeated invocation without a newer event returns null '
        '(no replay on rebuild)', () async {
      final t = await _newTracker();
      final at = _hatch.add(const Duration(minutes: 10));
      final state = _stateWithTransitions([_advanced(at)]);

      // First call: event is unacknowledged.
      expect(t.latestUnacknowledged(state)!.at, at);

      // UI "acknowledges" it.
      await t.acknowledge(_ownerNodeNum, at);

      // Subsequent calls in the same session, or after reload, must
      // NOT resurface it.
      expect(t.latestUnacknowledged(state), isNull);
      expect(t.latestUnacknowledged(state), isNull);
    });

    test(
      'watermark survives tracker reconstruction (simulating resume)',
      () async {
        final t1 = await _newTracker();
        final at = _hatch.add(const Duration(minutes: 10));
        await t1.acknowledge(_ownerNodeNum, at);

        // Rebuild tracker against the same SharedPreferences store.
        final prefs = await SharedPreferences.getInstance();
        final t2 = PetAnimationTracker(prefs);
        expect(t2.ackedAt(_ownerNodeNum), at);

        final state = _stateWithTransitions([_advanced(at)]);
        expect(t2.latestUnacknowledged(state), isNull);
      },
    );

    test('acknowledgeAll sets watermark to the latest transition', () async {
      final t = await _newTracker();
      final events = [
        _advanced(_hatch.add(const Duration(minutes: 10))),
        _advanced(_hatch.add(const Duration(days: 6, minutes: 10))),
        _advanced(_hatch.add(const Duration(days: 2, minutes: 10))),
      ];
      final state = _stateWithTransitions(events);
      await t.acknowledgeAll(state);

      expect(
        t.ackedAt(_ownerNodeNum),
        _hatch.add(const Duration(days: 6, minutes: 10)),
      );
      expect(t.latestUnacknowledged(state), isNull);
    });

    test('per-owner watermarks are independent', () async {
      final t = await _newTracker();
      const otherOwner = 0xCAFE5678;
      final at = _hatch.add(const Duration(minutes: 10));

      await t.acknowledge(_ownerNodeNum, at);
      // Other owner's watermark is still epoch-0.
      expect(t.ackedAt(otherOwner), DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('non-stageAdvanced events (e.g. mistakeRecorded) are ignored by the '
        'watermark', () async {
      final t = await _newTracker();
      final state = _stateWithTransitions([
        CareEvent(
          at: _hatch.add(const Duration(minutes: 5)),
          kind: CareEventKind.mistakeRecorded,
        ),
        CareEvent(
          at: _hatch.add(const Duration(minutes: 6)),
          kind: CareEventKind.charged,
        ),
      ]);
      expect(t.latestUnacknowledged(state), isNull);
    });
  });

  group('classifyTransitionByResultingStage', () {
    test('egg → juvenile classified as hatch', () {
      expect(
        classifyTransitionByResultingStage(PetStage.juvenile),
        PetTransitionKind.hatch,
      );
    });

    test('adolescent → adult classified as branch resolution', () {
      expect(
        classifyTransitionByResultingStage(PetStage.adult),
        PetTransitionKind.branchResolution,
      );
    });

    test('elder → dormant classified as dormancy', () {
      expect(
        classifyTransitionByResultingStage(PetStage.dormant),
        PetTransitionKind.dormancy,
      );
    });

    test('egg stage is not a valid transition target', () {
      expect(
        classifyTransitionByResultingStage(PetStage.egg),
        PetTransitionKind.unknown,
      );
    });
  });
}
