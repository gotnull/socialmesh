// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetTimelineRecorder — the write-through bridge between
// OwnPetController's in-memory PetState and the persisted
// pet_timeline_events table.
//
// Invoked from OwnPetController at two moments:
//   1. First-time import on fresh load: when the pet state has been
//      loaded from disk but the timeline DB is still empty for this
//      owner, the recorder flushes the WHOLE `recentEvents` ring
//      buffer into the timeline so the user has something to look at
//      (otherwise a long-lived pet upgrading to this feature starts
//      with an empty screen).
//   2. On every state emission thereafter, the recorder ingests the
//      full ring again — the repository's dedupe index (see
//      `pet_database.dart` v2 migration) makes duplicate writes a
//      no-op, so we don't need a separate "new events since last
//      save" diff.
//
// The recorder is a thin functional facade — no state of its own.
// The repository does the dedupe + cap enforcement.

import '../../../core/logging.dart';
import '../models/pet_state.dart';
import 'pet_timeline_projector.dart';
import 'pet_timeline_repository.dart';

class PetTimelineRecorder {
  final PetTimelineRepository _repo;

  const PetTimelineRecorder(this._repo);

  /// Record every event currently sitting in [state.recentEvents]
  /// into the timeline table. Deduped by (owner, at_ms, kind,
  /// detail) — calling this every emission is safe and cheap.
  ///
  /// Stage + branch for every event come from the pet's CURRENT
  /// state at write time. That's the correct call for transient
  /// minor events (they occurred while the pet was in its current
  /// stage) AND for stage-transition events (the `hatched` /
  /// `stageAdvanced` event marks the entry into the new stage, so
  /// the stage IS the post-transition stage). The
  /// [buildRecordFromEvent] helper encodes this contract.
  Future<void> ingestFromState(PetState state) async {
    final events = state.recentEvents;
    if (events.isEmpty) return;
    await _repo.init();
    final records = events
        .map((e) => buildRecordFromEvent(event: e, state: state))
        .toList(growable: false);
    await _repo.insertAll(ownerNodeNum: state.ownerNodeNum, records: records);
  }

  /// Drop the timeline for [ownerNodeNum]. Called when the user
  /// re-sigils — a new egg means a new story, the old one is
  /// retired. The new egg's own `hatched` event will re-seed the
  /// timeline on the next `ingestFromState`.
  Future<void> clearForOwner(int ownerNodeNum) async {
    await _repo.init();
    await _repo.clearForOwner(ownerNodeNum);
    AppLogging.pet(
      'PetTimelineRecorder: cleared timeline for owner=$ownerNodeNum',
    );
  }
}
