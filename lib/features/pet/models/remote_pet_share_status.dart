// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Per-peer companion sharing signal, derived from what the node actually
// told us the last time we asked for its summary.
//
//   unknown    — we haven't received any recent response from this peer
//                (first encounter, or the app just started and the
//                in-memory status hasn't been rehydrated yet).
//   sharing    — the peer responded with a decoded companion state; the
//                cache in pet.db is the authoritative preview.
//   notSharing — the peer responded but declined or had nothing to share
//                (error frame OR empty payload). The UI uses this to
//                explain the absence of a companion preview without
//                treating the peer as unreachable.
//
// Stored in memory only — rebuilt from fresh mesh traffic after a cold
// start. Persistence was intentionally skipped to avoid a pet.db schema
// bump for a signal that refreshes naturally within seconds of each
// NodeDex open.
enum RemotePetShareStatus { unknown, sharing, notSharing }
