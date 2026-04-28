// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetTimelineProjector — pure function that turns a persisted record
// list + the current PetState + PetConfig into an immutable
// [PetTimelineView] for the screen to render.
//
// Responsibilities:
//
//   1. Classify each record by importance (major / important / minor)
//      using [importanceForKind]. Callers (the recorder) stamp this
//      at write time; the projector falls back to the same function
//      on read so stale rows written before an importance-policy
//      tweak still render correctly.
//   2. Build one [PetTimelineSection] per stage the pet has actually
//      entered. Stage boundaries come from `hatched`/`stageAdvanced`
//      events in the record list — no separate stage-time table
//      needed because the engine stamps `stage_at_event` for every
//      row.
//   3. Compress same-kind minor events inside a short window into a
//      [PetTimelineGroupedEntry] ("Charged 3×"). Major + important
//      events are never grouped and never swallowed.
//   4. Emit an [PetTimelineUpcoming] estimate from
//      `stageStartedAt + durationFor(stage)` unless the pet is
//      dormant.
//   5. Synthesize the [PetTimelineOrigin] from PetState fields that
//      don't depend on the record list.
//
// Purity: no Flutter, no Riverpod, no DateTime.now() — takes `now`
// explicitly. Every side-effect-free step is independently testable.

import '../models/care_event.dart';
import '../models/pet_base_allele.dart';
import '../models/pet_config.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../models/pet_timeline_view.dart';

/// Grouping window for repeated minor care taps. Events of the SAME
/// kind whose gap to the previous one in the run is within this
/// window are collapsed into a single [PetTimelineGroupedEntry].
const Duration kPetTimelineGroupingWindow = Duration(minutes: 10);

/// Importance policy — single source of truth. The recorder stamps
/// this at write time; the projector falls back to it on read. Any
/// change here should be accompanied by a re-stamp pass OR the
/// understanding that old rows will render with the old importance
/// until they're evicted.
PetTimelineImportance importanceForKind(CareEventKind kind) {
  switch (kind) {
    // --- Major: life-cycle events, always hero-card, never grouped,
    //     never evicted.
    case CareEventKind.hatched:
    case CareEventKind.stageAdvanced:
    case CareEventKind.branchResolved:
    case CareEventKind.dormantEntered:
    case CareEventKind.reSigilled:
      return PetTimelineImportance.major;

    // --- Important: consequential state transitions the user should
    //     be able to see at a glance.
    case CareEventKind.sicknessOnset:
    case CareEventKind.sicknessRecovered:
    case CareEventKind.purged:
    case CareEventKind.callMissed:
    case CareEventKind.mistakeRecorded:
      return PetTimelineImportance.important;

    // --- Minor: routine care + ambient. Groupable, first to be
    //     evicted when the cap is hit.
    case CareEventKind.charged:
    case CareEventKind.surged:
    case CareEventKind.resonated:
    case CareEventKind.stabilised:
    case CareEventKind.synced:
    case CareEventKind.dimmed:
    case CareEventKind.inspected:
    case CareEventKind.hygieneArtefactAppeared:
    case CareEventKind.callStarted:
    case CareEventKind.callAnswered:
    case CareEventKind.sleepEntered:
    case CareEventKind.sleepExited:
      return PetTimelineImportance.minor;
  }
}

/// Kinds whose minor-tier entries are ALLOWED to be grouped. Some
/// minor events (e.g. `sleepEntered`) are singular per sleep cycle
/// and wouldn't make sense collapsed — but in practice the grouping
/// window is short enough that they'd never match. Allowing grouping
/// on all minor kinds keeps the logic simple.
bool _canGroup(CareEventKind kind) =>
    importanceForKind(kind) == PetTimelineImportance.minor;

/// Build the full [PetTimelineView] from persisted records + current
/// state + config. Records must be in chronological order (oldest
/// first); callers guarantee this via `ORDER BY at_ms ASC`.
///
/// [now] is injected so tests are deterministic.
PetTimelineView projectPetTimeline({
  required PetState state,
  required PetConfig config,
  required List<PetTimelineRecord> records,
  required List<PetBaseAllele> alleleSequence,
  required DateTime now,
}) {
  final origin = _buildOrigin(state, alleleSequence);
  final sections = _buildSections(state, records);
  final upcoming = _buildUpcoming(state, config, now);
  final totalEvents = records.length;
  return PetTimelineView(
    origin: origin,
    sections: sections,
    upcoming: upcoming,
    totalEvents: totalEvents,
  );
}

PetTimelineOrigin _buildOrigin(
  PetState state,
  List<PetBaseAllele> alleleSequence,
) {
  final dominant = alleleSequence.isEmpty
      ? PetBaseAllele.aurora
      : PetAlleleDistribution.from(alleleSequence).dominant;
  return PetTimelineOrigin(
    dnaSeed: state.dnaSeed,
    hatchedAt: state.hatchedAt,
    ownerNodeNum: state.ownerNodeNum,
    dominantAllele: dominant,
  );
}

List<PetTimelineSection> _buildSections(
  PetState state,
  List<PetTimelineRecord> records,
) {
  // Empty history → the pet has only just existed. Emit a single
  // section for the current stage so the UI still has a lane to draw
  // the origin-to-now connection in.
  if (records.isEmpty) {
    return [
      PetTimelineSection(
        stage: state.stage,
        startedAt: state.stageStartedAt,
        isCurrent: true,
        entries: const [],
      ),
    ];
  }

  // Group records by stage in the order the pet actually entered
  // each stage. The stage-at-event field on each record is
  // authoritative — the pet's CURRENT stage is only used for the
  // "isCurrent" flag + to include the trailing current stage even if
  // no events have fired yet inside it.
  final byStage = <PetStage, List<PetTimelineRecord>>{};
  final stageOrder = <PetStage>[]; // first-seen order
  for (final r in records) {
    if (!byStage.containsKey(r.stageAtEvent)) {
      stageOrder.add(r.stageAtEvent);
    }
    byStage.putIfAbsent(r.stageAtEvent, () => <PetTimelineRecord>[]).add(r);
  }
  // Ensure the pet's current stage has its own section even if nothing
  // has been recorded for it yet — the user opened the screen right
  // after the transition, for instance.
  if (!byStage.containsKey(state.stage)) {
    stageOrder.add(state.stage);
    byStage[state.stage] = const [];
  }

  // A section's `startedAt` is the earliest record in that stage OR
  // (for the current stage with no records) the pet's `stageStartedAt`.
  final sections = <PetTimelineSection>[];
  for (final stage in stageOrder) {
    final stageRecords = byStage[stage] ?? const <PetTimelineRecord>[];
    final startedAt = stageRecords.isEmpty
        ? (stage == state.stage ? state.stageStartedAt : state.hatchedAt)
        : stageRecords.first.at;
    final entries = _buildEntriesForStage(stageRecords);
    sections.add(
      PetTimelineSection(
        stage: stage,
        startedAt: startedAt,
        isCurrent: stage == state.stage,
        entries: entries,
      ),
    );
  }
  return sections;
}

/// Within a single stage, compress repeated minor same-kind events
/// within [kPetTimelineGroupingWindow] into a single grouped entry.
/// Major + important events always emit as singles and flush any
/// active group.
List<PetTimelineEntry> _buildEntriesForStage(List<PetTimelineRecord> records) {
  if (records.isEmpty) return const [];
  final out = <PetTimelineEntry>[];

  // Active grouping state.
  CareEventKind? groupKind;
  DateTime? groupFirstAt;
  DateTime? groupLastAt;
  int groupCount = 0;
  PetStage? groupStage;
  PetBranch? groupBranch;

  void flush() {
    if (groupKind == null) return;
    if (groupCount == 1) {
      // A lone minor event — emit it as a plain single entry so it
      // keeps a dedicated timestamp line instead of rendering as
      // "Charged 1×".
      out.add(
        PetTimelineSingleEntry(
          event: CareEvent(at: groupFirstAt!, kind: groupKind!),
          stageAtEvent: groupStage!,
          branchAtEvent: groupBranch!,
          importance: PetTimelineImportance.minor,
        ),
      );
    } else {
      out.add(
        PetTimelineGroupedEntry(
          kind: groupKind!,
          count: groupCount,
          firstAt: groupFirstAt!,
          lastAt: groupLastAt!,
          stageAtGroup: groupStage!,
          branchAtGroup: groupBranch!,
        ),
      );
    }
    groupKind = null;
    groupFirstAt = null;
    groupLastAt = null;
    groupCount = 0;
    groupStage = null;
    groupBranch = null;
  }

  for (final r in records) {
    final importance = r.importance;
    if (importance != PetTimelineImportance.minor || !_canGroup(r.kind)) {
      // Majors + importants flush any open group and emit alone.
      flush();
      out.add(
        PetTimelineSingleEntry(
          event: r.toCareEvent(),
          stageAtEvent: r.stageAtEvent,
          branchAtEvent: r.branchAtEvent,
          importance: importance,
        ),
      );
      continue;
    }
    // Minor → try to extend an existing group or start a new one.
    if (groupKind == r.kind &&
        groupLastAt != null &&
        r.at.difference(groupLastAt!) <= kPetTimelineGroupingWindow) {
      groupCount += 1;
      groupLastAt = r.at;
      continue;
    }
    // Different kind or window exceeded — flush + start a fresh group.
    flush();
    groupKind = r.kind;
    groupFirstAt = r.at;
    groupLastAt = r.at;
    groupCount = 1;
    groupStage = r.stageAtEvent;
    groupBranch = r.branchAtEvent;
  }
  flush();
  return out;
}

PetTimelineUpcoming? _buildUpcoming(
  PetState state,
  PetConfig config,
  DateTime now,
) {
  if (state.stage == PetStage.dormant) return null;
  final duration = _durationFor(state.stage, config);
  if (duration == null) return null;
  final nextStage = _nextStageOf(state.stage);
  if (nextStage == null) return null;
  final estimatedAt = state.stageStartedAt.add(duration);
  final remaining = estimatedAt.difference(now);
  // Clamp to zero so UI doesn't render "-3h" when the engine hasn't
  // yet processed the boundary. Negative remaining means the care
  // engine will advance on next tick.
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  return PetTimelineUpcoming(
    nextStage: nextStage,
    estimatedAt: estimatedAt,
    remaining: clamped,
  );
}

Duration? _durationFor(PetStage stage, PetConfig config) {
  switch (stage) {
    case PetStage.egg:
      return config.eggDuration;
    case PetStage.juvenile:
      return config.juvenileDuration;
    case PetStage.adolescent:
      return config.adolescentDuration;
    case PetStage.adult:
      return config.adultDuration;
    case PetStage.elder:
      return config.elderDuration;
    case PetStage.dormant:
      return null;
  }
}

PetStage? _nextStageOf(PetStage stage) {
  switch (stage) {
    case PetStage.egg:
      return PetStage.juvenile;
    case PetStage.juvenile:
      return PetStage.adolescent;
    case PetStage.adolescent:
      return PetStage.adult;
    case PetStage.adult:
      return PetStage.elder;
    case PetStage.elder:
      return PetStage.dormant;
    case PetStage.dormant:
      return null;
  }
}

// -----------------------------------------------------------------
// Helpers for the recorder: converting raw CareEvents from
// PetState.recentEvents into PetTimelineRecord rows with stage/branch
// context at write time.
// -----------------------------------------------------------------

/// Build a record from a single recent-events [event], stamping the
/// stage/branch CURRENT at write time. The write-through path is the
/// only place where "stage at event" diverges from the pet's live
/// stage: for stage-transition events (`hatched`, `stageAdvanced`,
/// `branchResolved`, `dormantEntered`), the event marks the NEW
/// stage, so we stamp the resulting state's stage.
PetTimelineRecord buildRecordFromEvent({
  required CareEvent event,
  required PetState state,
}) {
  return PetTimelineRecord(
    ownerNodeNum: state.ownerNodeNum,
    at: event.at,
    kind: event.kind,
    detail: event.detail,
    stageAtEvent: state.stage,
    branchAtEvent: state.branch,
    importance: importanceForKind(event.kind),
  );
}

/// Evict the oldest MINOR rows from the head of [records] until the
/// total count is at most [cap]. Majors + importants are never
/// evicted. Returns the filtered list in original order.
///
/// This runs locally in the repository on the full per-owner row set
/// after each write batch — SQLite's own LIMIT can't do the
/// importance-aware filter cleanly.
List<PetTimelineRecord> evictOldestMinorsToCap(
  List<PetTimelineRecord> records,
  int cap,
) {
  if (records.length <= cap) return records;
  final overflow = records.length - cap;
  // Walk oldest-first, drop up to `overflow` minors.
  final drop = <int>{};
  for (var i = 0; i < records.length && drop.length < overflow; i++) {
    if (records[i].importance == PetTimelineImportance.minor) {
      drop.add(i);
    }
  }
  if (drop.isEmpty) return records;
  final kept = <PetTimelineRecord>[];
  for (var i = 0; i < records.length; i++) {
    if (!drop.contains(i)) kept.add(records[i]);
  }
  return kept;
}

/// The hard cap on total persisted timeline rows per owner. Soft in
/// the sense that majors + importants are never evicted even if the
/// effective row count exceeds this — see [evictOldestMinorsToCap].
const int kPetTimelineMaxRowsPerOwner = 500;
