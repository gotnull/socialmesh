// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet enums — stage, branch, mood, action, event, call reason.
//
// Wire format invariants: the numeric index of every enum below is part of
// the PetPublicState codec. Never reorder existing values. Add new values at
// the END of each enum and bump the codec schema tag.

enum PetStage { egg, juvenile, adolescent, adult, elder, dormant }

enum PetBranch { unborn, luminous, steady, volatile, dimmed }

enum PetMood { content, hungry, sad, sick, sleeping, calling }

enum CareAction {
  charge,
  surge,
  resonate,
  stabilise,
  sync,
  purge,
  dim,
  inspect,
  reSigil,
}

enum CareEventKind {
  hatched,
  charged,
  surged,
  resonated,
  stabilised,
  synced,
  purged,
  dimmed,
  inspected,
  hygieneArtefactAppeared,
  sicknessOnset,
  sicknessRecovered,
  sleepEntered,
  sleepExited,
  callStarted,
  callAnswered,
  callMissed,
  mistakeRecorded,
  stageAdvanced,
  branchResolved,
  dormantEntered,
  reSigilled,
}

enum CallReason { hungry, lonely, sick, hygiene, bedtime, boredom }
