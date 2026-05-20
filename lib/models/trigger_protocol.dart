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

// Tri-state for the Automation trigger / action and Dashboard widget
// compatibility matrix. Source of truth: docs/engineering/
// MESHCORE_PROTOCOL_COMPATIBILITY.md. Extension methods on the three
// enums (`TriggerType.supportOn`, `ActionType.supportOn`,
// `DashboardWidgetType.supportOn`) read against this enum so the
// editor / picker UI can hide unsupported items + flag partial ones
// with a "Limited on <protocol>" chip.
enum ProtocolSupport {
  // Wire path exists and the trigger/action/widget reliably fires +
  // dispatches end-to-end on this protocol.
  supported,
  // Works when the underlying data happens to exist (e.g. position
  // triggers fire only for contacts that broadcast GPS). Picker
  // should surface a "Limited on <protocol>" tag.
  partial,
  // The protocol doesn't expose the data source / wire surface this
  // item requires. Picker should hide the row when filtered to this
  // protocol.
  unsupported,
}
