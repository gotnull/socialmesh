// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetTimelineView — immutable view-model types consumed by
// [PetTimelineScreen]. The projector in
// `pet_timeline_projector.dart` is the only code that builds these
// structures; the UI layer treats them as read-only render data.
//
// Shape (top → bottom in the screen):
//
//   PetTimelineOrigin   — the DNA/hatch "beginning of story" node.
//   PetTimelineSection  — one per stage encountered (egg, juvenile,
//                         adolescent, adult, elder, dormant). Contains a
//                         chronological list of entries.
//   PetTimelineUpcoming — the ghost "next stage in ~Xd" hint at the
//                         tail of the feed. Null when the pet is
//                         dormant or config can't project.
//
// Entries inside a section are a sealed union — either a single event
// with full importance, or a grouped compression of repeated minor
// care actions within a tight window.

import 'package:flutter/foundation.dart';

import 'care_event.dart';
import 'pet_base_allele.dart';
import 'pet_enums.dart';

/// Importance tier drives visual weight + eviction priority.
enum PetTimelineImportance {
  /// Life-cycle events: hatched, stageAdvanced, branchResolved,
  /// dormantEntered, reSigilled. Hero cards, never grouped, never
  /// evicted.
  major,

  /// Consequential state transitions: sickness onset/recovery, purged,
  /// callMissed, mistakeRecorded. Compact cards, always visible.
  important,

  /// Routine care taps, hygiene spawns, call start/answer, sleep
  /// edges, inspections. Compressed into grouped entries when several
  /// happen close together; evicted first when the cap is hit.
  minor,
}

/// The "origin" node at the very top of the timeline. Not an event —
/// it's the fixed starting point, computed from [PetState] fields
/// that never change after hatch.
@immutable
class PetTimelineOrigin {
  final int dnaSeed;
  final DateTime hatchedAt;
  final int ownerNodeNum;
  final PetBaseAllele dominantAllele;

  const PetTimelineOrigin({
    required this.dnaSeed,
    required this.hatchedAt,
    required this.ownerNodeNum,
    required this.dominantAllele,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineOrigin &&
          dnaSeed == other.dnaSeed &&
          hatchedAt == other.hatchedAt &&
          ownerNodeNum == other.ownerNodeNum &&
          dominantAllele == other.dominantAllele;

  @override
  int get hashCode =>
      Object.hash(dnaSeed, hatchedAt, ownerNodeNum, dominantAllele);
}

/// One stage-bounded section of the timeline. Chronological.
@immutable
class PetTimelineSection {
  final PetStage stage;

  /// When this stage began for THIS pet. For stages the pet never
  /// reached, the section is absent from the view entirely.
  final DateTime startedAt;

  /// True for the stage the pet is currently in — the UI highlights
  /// this section and draws the "current" marker between its last
  /// entry and the upcoming block.
  final bool isCurrent;

  final List<PetTimelineEntry> entries;

  const PetTimelineSection({
    required this.stage,
    required this.startedAt,
    required this.isCurrent,
    required this.entries,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineSection &&
          stage == other.stage &&
          startedAt == other.startedAt &&
          isCurrent == other.isCurrent &&
          listEquals(entries, other.entries);

  @override
  int get hashCode =>
      Object.hash(stage, startedAt, isCurrent, Object.hashAll(entries));
}

/// Sealed union — a section entry is either a single event or a
/// grouped compression.
sealed class PetTimelineEntry {
  final PetTimelineImportance importance;
  const PetTimelineEntry({required this.importance});

  /// Timestamp used for chronological ordering. Single → event.at,
  /// grouped → firstAt (the opening event of the group).
  DateTime get sortAt;
}

/// A single event standing on its own. Majors + importants always
/// render this way. Minors fall through to this shape too when no
/// other event nearby is compressible with them.
@immutable
final class PetTimelineSingleEntry extends PetTimelineEntry {
  final CareEvent event;

  /// Captured stage/branch at the instant the event was recorded —
  /// not the pet's CURRENT stage/branch. Used to render context chips
  /// on important-tier cards (e.g. "sickness onset · Adult / Steady").
  final PetStage stageAtEvent;
  final PetBranch branchAtEvent;

  const PetTimelineSingleEntry({
    required this.event,
    required this.stageAtEvent,
    required this.branchAtEvent,
    required super.importance,
  });

  @override
  DateTime get sortAt => event.at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineSingleEntry &&
          event.at == other.event.at &&
          event.kind == other.event.kind &&
          event.detail == other.event.detail &&
          stageAtEvent == other.stageAtEvent &&
          branchAtEvent == other.branchAtEvent &&
          importance == other.importance;

  @override
  int get hashCode => Object.hash(
    event.at,
    event.kind,
    event.detail,
    stageAtEvent,
    branchAtEvent,
    importance,
  );
}

/// A compressed run of repeated same-kind minor events inside a tight
/// window. Rendered as a single pill: "Charged 3×" with first→last
/// time range.
@immutable
final class PetTimelineGroupedEntry extends PetTimelineEntry {
  final CareEventKind kind;
  final int count;
  final DateTime firstAt;
  final DateTime lastAt;

  /// Stage the pet was in during this group (captured at firstAt).
  /// Minor groups don't cross stage boundaries — the projector
  /// flushes any active group at every stage transition.
  final PetStage stageAtGroup;
  final PetBranch branchAtGroup;

  const PetTimelineGroupedEntry({
    required this.kind,
    required this.count,
    required this.firstAt,
    required this.lastAt,
    required this.stageAtGroup,
    required this.branchAtGroup,
  }) : super(importance: PetTimelineImportance.minor);

  @override
  DateTime get sortAt => firstAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineGroupedEntry &&
          kind == other.kind &&
          count == other.count &&
          firstAt == other.firstAt &&
          lastAt == other.lastAt &&
          stageAtGroup == other.stageAtGroup &&
          branchAtGroup == other.branchAtGroup;

  @override
  int get hashCode =>
      Object.hash(kind, count, firstAt, lastAt, stageAtGroup, branchAtGroup);
}

/// The "next stage in ~Xd" ghost node at the tail. Null when the pet
/// is dormant (terminal) or config can't produce a duration.
@immutable
class PetTimelineUpcoming {
  final PetStage nextStage;
  final DateTime estimatedAt;

  /// Remaining time to the next stage from "now" at view-model build
  /// time. Stored so the UI can render "in 2 days" without re-
  /// computing — the projector runs on every state emission.
  final Duration remaining;

  const PetTimelineUpcoming({
    required this.nextStage,
    required this.estimatedAt,
    required this.remaining,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineUpcoming &&
          nextStage == other.nextStage &&
          estimatedAt == other.estimatedAt &&
          remaining == other.remaining;

  @override
  int get hashCode => Object.hash(nextStage, estimatedAt, remaining);
}

/// The top-level render model. Built once per state emission; the UI
/// treats it as opaque read-only data.
@immutable
class PetTimelineView {
  final PetTimelineOrigin origin;
  final List<PetTimelineSection> sections;
  final PetTimelineUpcoming? upcoming;

  /// Total event count (ungrouped) across all sections. Useful for
  /// the header "N events" pill without the UI having to re-walk the
  /// section list.
  final int totalEvents;

  const PetTimelineView({
    required this.origin,
    required this.sections,
    required this.upcoming,
    required this.totalEvents,
  });

  bool get isEmpty => sections.every((s) => s.entries.isEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetTimelineView &&
          origin == other.origin &&
          listEquals(sections, other.sections) &&
          upcoming == other.upcoming &&
          totalEvents == other.totalEvents;

  @override
  int get hashCode =>
      Object.hash(origin, Object.hashAll(sections), upcoming, totalEvents);
}

/// A single row as stored in / read from the `pet_timeline_events`
/// table. Not the UI view-model — the projector converts these into
/// [PetTimelineEntry]s with grouping applied.
@immutable
class PetTimelineRecord {
  final int ownerNodeNum;
  final DateTime at;
  final CareEventKind kind;
  final String? detail;
  final PetStage stageAtEvent;
  final PetBranch branchAtEvent;
  final PetTimelineImportance importance;

  const PetTimelineRecord({
    required this.ownerNodeNum,
    required this.at,
    required this.kind,
    required this.detail,
    required this.stageAtEvent,
    required this.branchAtEvent,
    required this.importance,
  });

  CareEvent toCareEvent() => CareEvent(at: at, kind: kind, detail: detail);
}
