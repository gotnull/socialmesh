// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Source protocol of an automation / IFTTT event. Carried alongside
// event data so trigger filters (`TriggerProtocolFilter`) can decide
// whether to fire, and so IFTTT webhook payloads can include a
// `protocol` field for downstream branching.
enum TriggerProtocol { meshtastic, meshcore }

// Per-trigger / per-config protocol scope. `any` is the legacy
// default that fires for both protocols. `meshtastic` / `meshcore`
// short-circuit the trigger when the firing event's protocol
// doesn't match. Lives under `lib/models/` (not the automations
// feature) so `lib/services/ifttt/` and other service-layer
// consumers can import it without violating the
// services-cannot-import-features rule.
enum TriggerProtocolFilter { any, meshtastic, meshcore }

// True when a trigger with `filter` should fire for an `incoming`
// event protocol. Mirrors the helper on `AutomationTrigger` so the
// IFTTT service and the automation engine share one decision.
bool triggerProtocolFilterMatches(
  TriggerProtocolFilter filter,
  TriggerProtocol incoming,
) {
  switch (filter) {
    case TriggerProtocolFilter.any:
      return true;
    case TriggerProtocolFilter.meshtastic:
      return incoming == TriggerProtocol.meshtastic;
    case TriggerProtocolFilter.meshcore:
      return incoming == TriggerProtocol.meshcore;
  }
}
