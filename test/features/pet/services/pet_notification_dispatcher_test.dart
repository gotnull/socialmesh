// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for the pet notification dispatcher — exercises the
// full contract:
//
//   * fire-once-per-event guarantees for stage transitions, sickness
//     onset, and attention calls;
//   * durable dedupe across provider rebuilds AND cold restarts
//     (SharedPreferences);
//   * still-relevant-now gating so catch-up bursts of callStarted /
//     sicknessOnset events from long absences don't emit stale alerts;
//   * latest-only stage notification when a catch-up crosses multiple
//     boundaries in one advance.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/pet/models/attention_call.dart';
import 'package:socialmesh/features/pet/models/care_event.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_notification_dispatcher.dart';

const _ownerNodeNum = 0xABCDEF01;
final _hatch = DateTime(2026, 6, 1, 12);

class _RecordingSink implements PetNotificationSink {
  int stageCount = 0;
  int sicknessCount = 0;
  int callCount = 0;
  final List<PetStage> stageCalls = [];
  final List<CallReason> callReasons = [];

  @override
  Future<void> sendStageTransition({
    required PetStage toStage,
    required PetBranch branch,
    required int ownerNodeNum,
  }) async {
    stageCount++;
    stageCalls.add(toStage);
  }

  @override
  Future<void> sendSicknessOnset({required int ownerNodeNum}) async {
    sicknessCount++;
  }

  @override
  Future<void> sendAttentionCall({
    required CallReason reason,
    required int ownerNodeNum,
  }) async {
    callCount++;
    callReasons.add(reason);
  }
}

/// Variant that delays every send — models the real flutter_local_notifications
/// platform channel latency so concurrent dispatch races are observable.
class _SlowRecordingSink extends _RecordingSink {
  final Duration delay;
  _SlowRecordingSink({required this.delay});

  @override
  Future<void> sendStageTransition({
    required PetStage toStage,
    required PetBranch branch,
    required int ownerNodeNum,
  }) async {
    await Future<void>.delayed(delay);
    await super.sendStageTransition(
      toStage: toStage,
      branch: branch,
      ownerNodeNum: ownerNodeNum,
    );
  }

  @override
  Future<void> sendSicknessOnset({required int ownerNodeNum}) async {
    await Future<void>.delayed(delay);
    await super.sendSicknessOnset(ownerNodeNum: ownerNodeNum);
  }

  @override
  Future<void> sendAttentionCall({
    required CallReason reason,
    required int ownerNodeNum,
  }) async {
    await Future<void>.delayed(delay);
    await super.sendAttentionCall(reason: reason, ownerNodeNum: ownerNodeNum);
  }
}

Future<(PetNotificationLedger, SharedPreferences)> _newLedger({
  Map<String, Object> initial = const {},
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return (PetNotificationLedger(prefs), prefs);
}

PetState _base({
  PetStage stage = PetStage.juvenile,
  PetBranch branch = PetBranch.steady,
  bool isSick = false,
  AttentionCall? call,
  List<CareEvent> events = const [],
}) {
  final base = PetState.egg(ownerNodeNum: _ownerNodeNum, hatchedAt: _hatch);
  return base.copyWith(
    stage: stage,
    branch: branch,
    stageStartedAt: _hatch,
    lastTickAt: _hatch.add(const Duration(hours: 1)),
    isSick: isSick,
    activeCall: call,
    recentEvents: [...base.recentEvents, ...events],
  );
}

CareEvent _stageAdvanced(DateTime at) =>
    CareEvent(at: at, kind: CareEventKind.stageAdvanced);
CareEvent _sick(DateTime at) =>
    CareEvent(at: at, kind: CareEventKind.sicknessOnset);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage transitions', () {
    test('fires exactly once for a fresh transition', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(minutes: 15));
      final s = _base(
        stage: PetStage.juvenile,
        events: [_stageAdvanced(_hatch.add(const Duration(minutes: 10)))],
      );

      final outcome = await d.onStateTransition(
        previous: null,
        current: s,
        now: now,
      );
      expect(outcome, contains(PetNotificationDecision.stageTransition));
      expect(sink.stageCount, 1);
      expect(sink.stageCalls.single, PetStage.juvenile);
    });

    test('does not refire on provider rebuild', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(minutes: 15));
      final s = _base(
        stage: PetStage.juvenile,
        events: [_stageAdvanced(_hatch.add(const Duration(minutes: 10)))],
      );

      await d.onStateTransition(previous: null, current: s, now: now);
      final second = await d.onStateTransition(
        previous: s,
        current: s,
        now: now,
      );
      expect(sink.stageCount, 1);
      expect(second, contains(PetNotificationDecision.suppressedDedupe));
    });

    test(
      'multi-boundary catch-up only notifies for the latest transition',
      () async {
        final (ledger, _) = await _newLedger();
        final sink = _RecordingSink();
        final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
        final now = _hatch.add(const Duration(days: 7));
        // Simulate recent events from a long catch-up crossing 3 stages.
        final s = _base(
          stage: PetStage.adolescent,
          events: [
            _stageAdvanced(_hatch.add(const Duration(minutes: 10))),
            _stageAdvanced(_hatch.add(const Duration(minutes: 10, days: 2))),
          ],
        ).copyWith(lastTickAt: now);

        // To keep the test realistic, the latest transition happened 2
        // minutes ago (fresh). Otherwise the stale gate kicks in.
        final freshEvent = now.subtract(const Duration(minutes: 2));
        final withFresh = s.copyWith(
          recentEvents: [...s.recentEvents, _stageAdvanced(freshEvent)],
        );

        await d.onStateTransition(previous: null, current: withFresh, now: now);
        expect(
          sink.stageCount,
          1,
          reason: 'only the latest transition should notify',
        );
        expect(
          ledger.stageNotifiedAt(_ownerNodeNum),
          freshEvent,
          reason: 'watermark should be at latest transition',
        );
      },
    );

    test(
      'stale transition is suppressed (watermark advances silently)',
      () async {
        final (ledger, _) = await _newLedger();
        final sink = _RecordingSink();
        final d = PetNotificationDispatcher(
          ledger: ledger,
          sink: sink,
          stageStalenessWindow: const Duration(hours: 6),
        );
        // Simulate: user opens app a day after their pet hatched.
        final now = _hatch.add(const Duration(days: 1));
        final s = _base(
          stage: PetStage.juvenile,
          events: [_stageAdvanced(_hatch.add(const Duration(minutes: 10)))],
        );

        final outcome = await d.onStateTransition(
          previous: null,
          current: s,
          now: now,
        );
        expect(sink.stageCount, 0);
        expect(outcome, contains(PetNotificationDecision.suppressedStale));
        // Watermark should still advance so subsequent rebuilds don't
        // re-evaluate the stale transition.
        expect(
          ledger.stageNotifiedAt(_ownerNodeNum),
          _hatch.add(const Duration(minutes: 10)),
        );
      },
    );

    test(
      'dormant transition is NOT stale-suppressed even if older than window',
      () async {
        final (ledger, _) = await _newLedger();
        final sink = _RecordingSink();
        final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
        final now = _hatch.add(const Duration(days: 30));
        final s = _base(
          stage: PetStage.dormant,
          events: [_stageAdvanced(_hatch.add(const Duration(days: 25)))],
        );

        await d.onStateTransition(previous: null, current: s, now: now);
        expect(sink.stageCount, 1);
      },
    );
  });

  group('Sickness', () {
    test('fires once on onset while currently sick', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(minutes: 30));
      final s = _base(
        isSick: true,
        events: [_sick(now.subtract(const Duration(minutes: 2)))],
      );

      await d.onStateTransition(previous: null, current: s, now: now);
      expect(sink.sicknessCount, 1);
    });

    test('does not refire while still sick', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(minutes: 30));
      final s = _base(
        isSick: true,
        events: [_sick(now.subtract(const Duration(minutes: 2)))],
      );

      await d.onStateTransition(previous: null, current: s, now: now);
      await d.onStateTransition(previous: s, current: s, now: now);
      await d.onStateTransition(previous: s, current: s, now: now);
      expect(sink.sicknessCount, 1);
    });

    test('stale sicknessOnset during catch-up is gated by isSick flag '
        '(pet already recovered — no notify)', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(hours: 6));
      final s = _base(
        isSick: false, // already recovered
        events: [_sick(_hatch.add(const Duration(hours: 2)))],
      );

      await d.onStateTransition(previous: null, current: s, now: now);
      expect(sink.sicknessCount, 0);
    });

    test('next onset after recovery fires again', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now1 = _hatch.add(const Duration(minutes: 30));
      var s = _base(
        isSick: true,
        events: [_sick(now1.subtract(const Duration(minutes: 2)))],
      );
      await d.onStateTransition(previous: null, current: s, now: now1);
      expect(sink.sicknessCount, 1);

      // Purge — pet recovers. Ledger should clear.
      final recovered = s.copyWith(isSick: false);
      await d.onStateTransition(
        previous: s,
        current: recovered,
        now: now1.add(const Duration(minutes: 1)),
      );
      expect(ledger.sicknessNotifiedAt(_ownerNodeNum), isNull);

      // New sickness later.
      final later = now1.add(const Duration(hours: 3));
      s = recovered.copyWith(
        isSick: true,
        recentEvents: [
          ...recovered.recentEvents,
          _sick(later.subtract(const Duration(minutes: 1))),
        ],
      );
      await d.onStateTransition(previous: recovered, current: s, now: later);
      expect(sink.sicknessCount, 2);
    });
  });

  group('Attention call', () {
    test('fires once per call, replaced by the next', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(hours: 2));
      final call1 = AttentionCall(
        startedAt: now.subtract(const Duration(minutes: 5)),
        deadline: now.add(const Duration(hours: 2)),
        reason: CallReason.hungry,
      );
      var s = _base(call: call1);
      await d.onStateTransition(previous: null, current: s, now: now);
      await d.onStateTransition(previous: s, current: s, now: now);
      expect(sink.callCount, 1);

      // Answer the call (activeCall becomes null) — ledger should clear.
      final answered = s.copyWith(activeCall: null);
      await d.onStateTransition(
        previous: s,
        current: answered,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(ledger.callNotifiedAt(_ownerNodeNum), isNull);

      // New call later fires again.
      final later = now.add(const Duration(hours: 3));
      final call2 = AttentionCall(
        startedAt: later,
        deadline: later.add(const Duration(hours: 2)),
        reason: CallReason.lonely,
      );
      s = answered.copyWith(activeCall: call2);
      await d.onStateTransition(
        previous: answered,
        current: s,
        now: later.add(const Duration(minutes: 2)),
      );
      expect(sink.callCount, 2);
      expect(sink.callReasons.last, CallReason.lonely);
    });

    test('expired call is NOT notified (stale)', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(hours: 6));
      // A call that fired 5h ago, deadline was 3h ago.
      final expiredCall = AttentionCall(
        startedAt: now.subtract(const Duration(hours: 5)),
        deadline: now.subtract(const Duration(hours: 3)),
        reason: CallReason.hungry,
      );
      final s = _base(call: expiredCall);

      final outcome = await d.onStateTransition(
        previous: null,
        current: s,
        now: now,
      );
      expect(sink.callCount, 0);
      expect(outcome, contains(PetNotificationDecision.suppressedStale));
    });
  });

  group('Durable dedupe across restart', () {
    test(
      'cold start with existing ledger does NOT re-emit milestone alerts',
      () async {
        // Simulate: user already got the hatch notification in a prior
        // session. Restart the app — a fresh dispatcher with a fresh
        // ledger instance over the SAME SharedPreferences store must
        // NOT re-notify.
        final transitionAt = _hatch.add(const Duration(minutes: 10));

        // Session 1: fire and record.
        final (ledger1, prefs) = await _newLedger();
        final sink1 = _RecordingSink();
        final d1 = PetNotificationDispatcher(ledger: ledger1, sink: sink1);
        final s = _base(
          stage: PetStage.juvenile,
          events: [_stageAdvanced(transitionAt)],
        );
        await d1.onStateTransition(
          previous: null,
          current: s,
          now: transitionAt.add(const Duration(minutes: 2)),
        );
        expect(sink1.stageCount, 1);

        // Session 2: new dispatcher, new ledger, same SharedPreferences.
        final ledger2 = PetNotificationLedger(prefs);
        final sink2 = _RecordingSink();
        final d2 = PetNotificationDispatcher(ledger: ledger2, sink: sink2);
        await d2.onStateTransition(
          previous: null,
          current: s,
          now: transitionAt.add(const Duration(minutes: 5)),
        );
        expect(
          sink2.stageCount,
          0,
          reason: 'persisted watermark should block re-emit after restart',
        );
      },
    );
  });

  group('Concurrent dispatch race safety', () {
    test('two concurrent onStateTransition calls fire the sink exactly once '
        'for a single hatch event', () async {
      // Mirrors production usage: the bridge provider calls
      // onStateTransition without awaiting, and the animation ticker
      // emits state every ~10s. Two in-flight invocations must not
      // both pass the ledger check.
      final (ledger, _) = await _newLedger();
      final sink = _SlowRecordingSink(delay: const Duration(milliseconds: 40));
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(minutes: 15));
      final s = _base(
        stage: PetStage.juvenile,
        events: [_stageAdvanced(_hatch.add(const Duration(minutes: 10)))],
      );

      await Future.wait([
        d.onStateTransition(previous: null, current: s, now: now),
        d.onStateTransition(previous: null, current: s, now: now),
        d.onStateTransition(previous: null, current: s, now: now),
      ]);

      expect(
        sink.stageCount,
        1,
        reason: 'concurrent dispatches must dedupe before sink.send',
      );
    });
  });

  group('No notification for non-care events', () {
    test('state change with only a charged event does nothing', () async {
      final (ledger, _) = await _newLedger();
      final sink = _RecordingSink();
      final d = PetNotificationDispatcher(ledger: ledger, sink: sink);
      final now = _hatch.add(const Duration(hours: 2));
      final s = _base(
        events: [CareEvent(at: now, kind: CareEventKind.charged)],
      );
      final outcome = await d.onStateTransition(
        previous: null,
        current: s,
        now: now,
      );
      expect(sink.stageCount, 0);
      expect(sink.sicknessCount, 0);
      expect(sink.callCount, 0);
      expect(outcome, everyElement(PetNotificationDecision.none));
    });
  });
}
