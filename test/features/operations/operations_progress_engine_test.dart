// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/operations/domain/operations_progress_engine.dart';
import 'package:socialmesh/features/operations/models/operation_event.dart';
import 'package:socialmesh/features/operations/models/operation_models.dart';

void main() {
  final now = DateTime.utc(2026, 5, 9, 12);
  final earlier = now.subtract(const Duration(minutes: 5));

  OperationDefinition uniqueDef({int target = 1, bool enabled = true}) {
    return OperationDefinition(
      id: 'op_unique',
      titleKey: 't',
      descriptionKey: 'd',
      category: OperationCategory.discovery,
      objectives: [
        OperationObjective(
          id: 'unique',
          titleKey: 't',
          kind: OperationObjectiveKind.uniqueNodeEncounter,
          target: target,
        ),
      ],
      rewards: const [],
      enabled: enabled,
    );
  }

  OperationDefinition tracerouteDef({bool multiHop = false, int target = 1}) {
    return OperationDefinition(
      id: multiHop ? 'op_multi' : 'op_trace',
      titleKey: 't',
      descriptionKey: 'd',
      category: OperationCategory.connectivity,
      objectives: [
        OperationObjective(
          id: 'r',
          titleKey: 't',
          kind: multiHop
              ? OperationObjectiveKind.multiHopObserved
              : OperationObjectiveKind.tracerouteSuccess,
          target: target,
          params: multiHop ? const {'minHopCount': 2} : const {},
        ),
      ],
      rewards: const [],
    );
  }

  group('OperationsProgressEngine — uniqueNodeEncounter', () {
    test('first unique node advances FIRST_CONTACT to completion', () {
      final def = uniqueDef();
      final progress = OperationProgress.empty(def, now: now);
      final event = OperationNodeEncountered(
        nodeNum: 0xAABBCCDD,
        occurredAt: earlier,
      );

      final result = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: event,
        now: now,
      );

      expect(result.didAdvance, isTrue);
      expect(result.didCompleteNow, isTrue);
      expect(result.deltas, {'unique': 1});
      expect(result.progress.objectiveProgress['unique'], 1);
      expect(result.progress.completedAt, now);
      expect(
        result.progress.dedupedKeys,
        contains('node_encounter:2864434397'),
      );
    });

    test('repeated same-node encounter does not double count', () {
      final def = uniqueDef(target: 5);
      var progress = OperationProgress.empty(def, now: now);

      final first = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: earlier),
        now: now,
      );
      progress = first.progress;
      expect(first.didAdvance, isTrue);

      final repeat = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: earlier),
        now: now,
      );
      expect(repeat.didAdvance, isFalse);
      expect(repeat.skipReason, OperationsEngineSkipReason.dedupeKeyKnown);
      expect(repeat.progress.objectiveProgress['unique'], 1);
    });

    test('SIGNAL_HUNTER completes at exactly 10 unique nodes', () {
      final def = uniqueDef(target: 10);
      var progress = OperationProgress.empty(def, now: now);

      for (var i = 1; i <= 9; i++) {
        final r = OperationsProgressEngine.apply(
          definition: def,
          current: progress,
          event: OperationNodeEncountered(nodeNum: i, occurredAt: earlier),
          now: now,
        );
        progress = r.progress;
        expect(r.didCompleteNow, isFalse);
      }
      expect(progress.objectiveProgress['unique'], 9);
      expect(progress.completedAt, isNull);

      final tenth = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 10, occurredAt: earlier),
        now: now,
      );
      expect(tenth.didAdvance, isTrue);
      expect(tenth.didCompleteNow, isTrue);
      expect(tenth.progress.objectiveProgress['unique'], 10);
      expect(tenth.progress.completedAt, now);
    });

    test('further events after completion are skipped', () {
      final def = uniqueDef();
      var progress = OperationProgress.empty(def, now: now);
      progress = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: earlier),
        now: now,
      ).progress;
      expect(progress.completedAt, isNotNull);

      final extra = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 2, occurredAt: earlier),
        now: now,
      );
      expect(extra.didAdvance, isFalse);
      expect(extra.skipReason, OperationsEngineSkipReason.alreadyComplete);
    });

    test('replay with the same state never inflates progress', () {
      final def = uniqueDef(target: 3);
      var progress = OperationProgress.empty(def, now: now);

      final firstPass = [1, 2, 3];
      for (final n in firstPass) {
        progress = OperationsProgressEngine.apply(
          definition: def,
          current: progress,
          event: OperationNodeEncountered(nodeNum: n, occurredAt: earlier),
          now: now,
        ).progress;
      }
      expect(progress.objectiveProgress['unique'], 3);
      expect(progress.completedAt, isNotNull);

      // Re-apply the same events. None should advance because the dedupe
      // keys are all already counted; the operation is also complete.
      for (final n in firstPass) {
        final r = OperationsProgressEngine.apply(
          definition: def,
          current: progress,
          event: OperationNodeEncountered(nodeNum: n, occurredAt: earlier),
          now: now,
        );
        expect(r.didAdvance, isFalse);
      }
      expect(progress.objectiveProgress['unique'], 3);
    });

    test('disabled definition skips with disabled reason', () {
      final def = uniqueDef(enabled: false);
      final progress = OperationProgress.empty(def, now: now);
      final r = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: earlier),
        now: now,
      );
      expect(r.didAdvance, isFalse);
      expect(r.skipReason, OperationsEngineSkipReason.disabled);
    });

    test('version mismatch refuses progress', () {
      final def = uniqueDef();
      final stale = OperationProgress(
        operationId: def.id,
        objectiveProgress: const {'unique': 0},
        dedupedKeys: const {},
        updatedAt: now,
        version: 99,
      );
      final r = OperationsProgressEngine.apply(
        definition: def,
        current: stale,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: earlier),
        now: now,
      );
      expect(r.didAdvance, isFalse);
      expect(r.skipReason, OperationsEngineSkipReason.versionMismatch);
    });

    test('event outside operation window is dropped', () {
      final def = OperationDefinition(
        id: 'window',
        titleKey: 't',
        descriptionKey: 'd',
        category: OperationCategory.discovery,
        objectives: [
          OperationObjective(
            id: 'x',
            titleKey: 't',
            kind: OperationObjectiveKind.uniqueNodeEncounter,
            target: 1,
          ),
        ],
        rewards: const [],
        startAt: now.add(const Duration(days: 1)),
      );
      final progress = OperationProgress.empty(def, now: now);
      final r = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationNodeEncountered(nodeNum: 1, occurredAt: now),
        now: now,
      );
      expect(r.didAdvance, isFalse);
      expect(r.skipReason, OperationsEngineSkipReason.outOfWindow);
    });

    test('mismatched event kind is ignored', () {
      final def = uniqueDef();
      final progress = OperationProgress.empty(def, now: now);
      final r = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'abc',
          targetNodeId: 1,
          hopCount: 2,
          occurredAt: earlier,
        ),
        now: now,
      );
      expect(r.didAdvance, isFalse);
      expect(r.skipReason, OperationsEngineSkipReason.noMatchingObjective);
    });
  });

  group('OperationsProgressEngine — traceroute', () {
    test('successful traceroute completes PATHFINDER', () {
      final def = tracerouteDef();
      final progress = OperationProgress.empty(def, now: now);
      final r = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'run_1',
          targetNodeId: 0xAA,
          hopCount: 1,
          occurredAt: earlier,
        ),
        now: now,
      );
      expect(r.didAdvance, isTrue);
      expect(r.didCompleteNow, isTrue);
      expect(r.progress.objectiveProgress['r'], 1);
    });

    test('multi-hop objective rejects single-hop runs', () {
      final def = tracerouteDef(multiHop: true);
      final progress = OperationProgress.empty(def, now: now);
      final shortRun = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'short',
          targetNodeId: 1,
          hopCount: 1,
          occurredAt: earlier,
        ),
        now: now,
      );
      expect(shortRun.didAdvance, isFalse);
      expect(
        shortRun.skipReason,
        OperationsEngineSkipReason.noMatchingObjective,
      );

      final longRun = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'long',
          targetNodeId: 1,
          hopCount: 3,
          occurredAt: earlier,
        ),
        now: now,
      );
      expect(longRun.didAdvance, isTrue);
    });

    test('repeated runId does not double count', () {
      final def = tracerouteDef(target: 2);
      var progress = OperationProgress.empty(def, now: now);
      final once = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'same',
          targetNodeId: 1,
          hopCount: 1,
          occurredAt: earlier,
        ),
        now: now,
      );
      progress = once.progress;

      final twice = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: OperationTracerouteCompleted(
          runId: 'same',
          targetNodeId: 1,
          hopCount: 1,
          occurredAt: earlier,
        ),
        now: now,
      );
      expect(twice.didAdvance, isFalse);
      expect(twice.skipReason, OperationsEngineSkipReason.dedupeKeyKnown);
      expect(progress.objectiveProgress['r'], 1);
    });
  });
}
