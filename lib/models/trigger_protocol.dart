// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Source protocol of an automation / IFTTT event. Carried alongside
// event data so trigger filters (`TriggerProtocolFilter`) can decide
// whether to fire, and so IFTTT webhook payloads can include a
// `protocol` field for downstream branching.
enum TriggerProtocol { meshtastic, meshcore }
