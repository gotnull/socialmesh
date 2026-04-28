// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/care_accumulators.dart';
import 'package:socialmesh/features/pet/models/care_event.dart';
import 'package:socialmesh/features/pet/models/pet_base_allele.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/models/pet_timeline_view.dart';
import 'package:socialmesh/features/pet/services/pet_timeline_projector.dart';

final _hatched = DateTime.utc(2026, 4, 1, 12, 0);
final _now = DateTime.utc(2026, 4, 5, 12, 0);
const _config = PetConfig();
final _alleles = deriveAlleleSequence(0xDEADBEEF);

PetState _stateAt({
  required PetStage stage,
  required PetBranch branch,
  DateTime? stageStartedAt,
}) {
  return PetState(
    ownerNodeNum: 42,
    dnaSeed: 0xDEADBEEF,
    stage: stage,
    branch: branch,
    hatchedAt: _hatched,
    stageStartedAt: stageStartedAt ?? _hatched,
    lastTickAt: _hatched,
    energy: 10,
    mood: 10,
    stability: 10,
    instability: 0,
    isSick: false,
    isAsleep: false,
    hygieneArtefacts: const [],
    activeCall: null,
    stageAccumulators: const CareAccumulators.empty(),
    recentEvents: const [],
  );
}

PetTimelineRecord _rec({
  required DateTime at,
  required CareEventKind kind,
  PetStage stage = PetStage.juvenile,
  PetBranch branch = PetBranch.steady,
  String? detail,
}) {
  return PetTimelineRecord(
    ownerNodeNum: 42,
    at: at,
    kind: kind,
    detail: detail,
    stageAtEvent: stage,
    branchAtEvent: branch,
    importance: importanceForKind(kind),
  );
}

PetTimelineView _project({
  required PetState state,
  required List<PetTimelineRecord> records,
  DateTime? now,
}) {
  return projectPetTimeline(
    state: state,
    config: _config,
    records: records,
    alleleSequence: _alleles,
    now: now ?? _now,
  );
}

void main() {
  group('importanceForKind — policy covers every CareEventKind', () {
    test('every kind has a deterministic tier', () {
      for (final k in CareEventKind.values) {
        final tier = importanceForKind(k);
        expect(tier, isA<PetTimelineImportance>(), reason: k.name);
      }
    });

    test('major tier includes every stage-transition kind', () {
      expect(
        importanceForKind(CareEventKind.hatched),
        PetTimelineImportance.major,
      );
      expect(
        importanceForKind(CareEventKind.stageAdvanced),
        PetTimelineImportance.major,
      );
      expect(
        importanceForKind(CareEventKind.branchResolved),
        PetTimelineImportance.major,
      );
      expect(
        importanceForKind(CareEventKind.dormantEntered),
        PetTimelineImportance.major,
      );
      expect(
        importanceForKind(CareEventKind.reSigilled),
        PetTimelineImportance.major,
      );
    });

    test('important tier surfaces sickness + mistakes', () {
      expect(
        importanceForKind(CareEventKind.sicknessOnset),
        PetTimelineImportance.important,
      );
      expect(
        importanceForKind(CareEventKind.sicknessRecovered),
        PetTimelineImportance.important,
      );
      expect(
        importanceForKind(CareEventKind.purged),
        PetTimelineImportance.important,
      );
      expect(
        importanceForKind(CareEventKind.callMissed),
        PetTimelineImportance.important,
      );
      expect(
        importanceForKind(CareEventKind.mistakeRecorded),
        PetTimelineImportance.important,
      );
    });

    test('routine care taps are minor', () {
      expect(
        importanceForKind(CareEventKind.charged),
        PetTimelineImportance.minor,
      );
      expect(
        importanceForKind(CareEventKind.resonated),
        PetTimelineImportance.minor,
      );
      expect(
        importanceForKind(CareEventKind.stabilised),
        PetTimelineImportance.minor,
      );
    });
  });

  group('origin block — always present', () {
    test('empty records: origin populated from PetState', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final view = _project(state: state, records: const []);
      expect(view.origin.dnaSeed, 0xDEADBEEF);
      expect(view.origin.hatchedAt, _hatched);
      expect(view.origin.ownerNodeNum, 42);
    });

    test('dormant pet still shows origin', () {
      final state = _stateAt(stage: PetStage.dormant, branch: PetBranch.dimmed);
      final view = _project(state: state, records: const []);
      expect(view.origin.dnaSeed, 0xDEADBEEF);
    });
  });

  group('sections — stage bucketing', () {
    test('empty records → single section for current stage', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final view = _project(state: state, records: const []);
      expect(view.sections, hasLength(1));
      expect(view.sections.single.stage, PetStage.juvenile);
      expect(view.sections.single.isCurrent, isTrue);
      expect(view.sections.single.entries, isEmpty);
    });

    test('events in two stages → two sections, one per stage', () {
      final state = _stateAt(
        stage: PetStage.adolescent,
        branch: PetBranch.steady,
      );
      final records = [
        _rec(
          at: _hatched.add(const Duration(hours: 1)),
          kind: CareEventKind.charged,
          stage: PetStage.juvenile,
        ),
        _rec(
          at: _hatched.add(const Duration(days: 2)),
          kind: CareEventKind.stageAdvanced,
          stage: PetStage.adolescent,
        ),
        _rec(
          at: _hatched.add(const Duration(days: 2, hours: 1)),
          kind: CareEventKind.resonated,
          stage: PetStage.adolescent,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.map((s) => s.stage).toList(), [
        PetStage.juvenile,
        PetStage.adolescent,
      ]);
      expect(view.sections.last.isCurrent, isTrue);
      expect(view.sections.first.isCurrent, isFalse);
    });

    test('current stage without any records still gets a section', () {
      final state = _stateAt(
        stage: PetStage.adolescent,
        branch: PetBranch.steady,
        stageStartedAt: _hatched.add(const Duration(days: 2)),
      );
      final records = [
        _rec(
          at: _hatched.add(const Duration(hours: 1)),
          kind: CareEventKind.charged,
          stage: PetStage.juvenile,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.map((s) => s.stage).toList(), [
        PetStage.juvenile,
        PetStage.adolescent,
      ]);
      expect(view.sections.last.entries, isEmpty);
      expect(view.sections.last.isCurrent, isTrue);
    });
  });

  group('grouping — minor events within the window', () {
    test('three charges in 5 minutes collapse to one grouped entry', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.charged),
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.charged,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 5)),
          kind: CareEventKind.charged,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.single.entries, hasLength(1));
      final entry = view.sections.single.entries.single;
      expect(entry, isA<PetTimelineGroupedEntry>());
      final g = entry as PetTimelineGroupedEntry;
      expect(g.kind, CareEventKind.charged);
      expect(g.count, 3);
      expect(g.firstAt, t0);
      expect(g.lastAt, t0.add(const Duration(minutes: 5)));
    });

    test('gap exceeding window starts a new group', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.charged),
        // 15-minute gap exceeds the 10-minute window → new group.
        _rec(
          at: t0.add(const Duration(minutes: 15)),
          kind: CareEventKind.charged,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.single.entries, hasLength(2));
      expect(
        view.sections.single.entries.every((e) => e is PetTimelineSingleEntry),
        isTrue,
        reason: 'each lone charge stays a single entry (not "Charged 1×")',
      );
    });

    test('different kinds within the window do not collapse', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.charged),
        _rec(
          at: t0.add(const Duration(minutes: 1)),
          kind: CareEventKind.resonated,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.charged,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.single.entries, hasLength(3));
    });

    test('lone minor event emits as a single entry, not a 1× group', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final records = [
        _rec(
          at: _hatched.add(const Duration(hours: 1)),
          kind: CareEventKind.charged,
        ),
      ];
      final view = _project(state: state, records: records);
      final entry = view.sections.single.entries.single;
      expect(entry, isA<PetTimelineSingleEntry>());
    });

    test('major event interleaved in a run of minors flushes the group', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.charged),
        _rec(
          at: t0.add(const Duration(minutes: 1)),
          kind: CareEventKind.charged,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.hatched,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 3)),
          kind: CareEventKind.charged,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 4)),
          kind: CareEventKind.charged,
        ),
      ];
      final view = _project(state: state, records: records);
      final entries = view.sections.single.entries;
      expect(entries, hasLength(3));
      expect(entries[0], isA<PetTimelineGroupedEntry>());
      expect((entries[0] as PetTimelineGroupedEntry).count, 2);
      expect(entries[1], isA<PetTimelineSingleEntry>());
      expect(
        (entries[1] as PetTimelineSingleEntry).importance,
        PetTimelineImportance.major,
      );
      expect(entries[2], isA<PetTimelineGroupedEntry>());
      expect((entries[2] as PetTimelineGroupedEntry).count, 2);
    });

    test('important events are never grouped, even when consecutive', () {
      final state = _stateAt(stage: PetStage.adult, branch: PetBranch.steady);
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.sicknessOnset, stage: PetStage.adult),
        _rec(
          at: t0.add(const Duration(minutes: 1)),
          kind: CareEventKind.sicknessOnset,
          stage: PetStage.adult,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections.single.entries, hasLength(2));
      expect(
        view.sections.single.entries.every((e) => e is PetTimelineSingleEntry),
        isTrue,
      );
    });

    test('grouping does NOT span stage boundaries', () {
      // Two charges in the same 5-minute window BUT across a stage
      // transition must render as two separate entries (in two
      // sections), not one group.
      final state = _stateAt(
        stage: PetStage.adolescent,
        branch: PetBranch.steady,
      );
      final t0 = _hatched.add(const Duration(hours: 1));
      final records = [
        _rec(at: t0, kind: CareEventKind.charged, stage: PetStage.juvenile),
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.charged,
          stage: PetStage.adolescent,
        ),
      ];
      final view = _project(state: state, records: records);
      expect(view.sections, hasLength(2));
      for (final s in view.sections) {
        expect(s.entries, hasLength(1));
      }
    });
  });

  group('upcoming — next stage ETA', () {
    test('juvenile pet → upcoming adolescent with remaining time', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
        stageStartedAt: _now.subtract(const Duration(days: 1)),
      );
      final view = _project(state: state, records: const []);
      expect(view.upcoming, isNotNull);
      expect(view.upcoming!.nextStage, PetStage.adolescent);
      // config.juvenileDuration = 2d; 1d elapsed → ~1d remaining.
      expect(view.upcoming!.remaining.inDays, 1);
    });

    test('dormant pet has no upcoming', () {
      final state = _stateAt(stage: PetStage.dormant, branch: PetBranch.dimmed);
      final view = _project(state: state, records: const []);
      expect(view.upcoming, isNull);
    });

    test('overdue stage clamps remaining to zero (no negative)', () {
      final state = _stateAt(
        stage: PetStage.egg,
        branch: PetBranch.unborn,
        stageStartedAt: _now.subtract(const Duration(hours: 2)),
      );
      final view = _project(state: state, records: const []);
      // eggDuration = 10min; 2h elapsed → would be -1h50m.
      expect(view.upcoming!.remaining, Duration.zero);
      expect(view.upcoming!.nextStage, PetStage.juvenile);
    });
  });

  group('determinism — same inputs → same outputs', () {
    test('view-model equality holds across two projections', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final records = [
        _rec(
          at: _hatched.add(const Duration(hours: 1)),
          kind: CareEventKind.charged,
        ),
        _rec(
          at: _hatched.add(const Duration(hours: 1, minutes: 2)),
          kind: CareEventKind.charged,
        ),
      ];
      final a = _project(state: state, records: records);
      final b = _project(state: state, records: records);
      expect(a, equals(b));
    });
  });

  group('evictOldestMinorsToCap — majors never lost', () {
    test('under cap: list returned unchanged', () {
      final records = [_rec(at: _hatched, kind: CareEventKind.charged)];
      final kept = evictOldestMinorsToCap(records, 10);
      expect(kept, same(records));
    });

    test('over cap: oldest minors evicted first', () {
      final t0 = _hatched;
      final records = [
        _rec(at: t0, kind: CareEventKind.charged), // minor
        _rec(
          at: t0.add(const Duration(minutes: 1)),
          kind: CareEventKind.charged,
        ), // minor
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.hatched,
        ), // MAJOR — must survive
        _rec(
          at: t0.add(const Duration(minutes: 3)),
          kind: CareEventKind.charged,
        ), // minor
      ];
      final kept = evictOldestMinorsToCap(records, 2);
      // Must retain the major + enough minors to hit cap.
      expect(kept, hasLength(2));
      expect(
        kept.any((r) => r.kind == CareEventKind.hatched),
        isTrue,
        reason: 'major events are immune to eviction',
      );
    });

    test('only majors/importants present: no eviction even above cap', () {
      final t0 = _hatched;
      final records = [
        _rec(at: t0, kind: CareEventKind.hatched),
        _rec(
          at: t0.add(const Duration(minutes: 1)),
          kind: CareEventKind.sicknessOnset,
        ),
        _rec(
          at: t0.add(const Duration(minutes: 2)),
          kind: CareEventKind.stageAdvanced,
        ),
      ];
      final kept = evictOldestMinorsToCap(records, 1);
      expect(
        kept,
        hasLength(3),
        reason: 'cap is soft in favor of major/important survivability',
      );
    });
  });

  group('buildRecordFromEvent — stamps current state context', () {
    test('stage + branch come from PetState at write time', () {
      final state = _stateAt(stage: PetStage.adult, branch: PetBranch.volatile);
      final event = CareEvent(
        at: _hatched.add(const Duration(hours: 1)),
        kind: CareEventKind.charged,
      );
      final rec = buildRecordFromEvent(event: event, state: state);
      expect(rec.stageAtEvent, PetStage.adult);
      expect(rec.branchAtEvent, PetBranch.volatile);
      expect(rec.importance, PetTimelineImportance.minor);
      expect(rec.ownerNodeNum, 42);
      expect(rec.kind, CareEventKind.charged);
    });

    test('major event gets major importance', () {
      final state = _stateAt(
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      final event = CareEvent(at: _hatched, kind: CareEventKind.hatched);
      final rec = buildRecordFromEvent(event: event, state: state);
      expect(rec.importance, PetTimelineImportance.major);
    });
  });
}
