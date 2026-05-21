// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pure capability derivation. Imports no protocol-specific symbols; the
// file lives under _internal/ only because it is glue code for the
// snapshot composer.

import '../models/watch_companion_capabilities.dart';
import '../models/watch_companion_connection_state.dart';

/// Derives the [WatchCompanionCapabilities] flag set from the composed
/// snapshot slices. v1 policy:
///
/// - `canQuickReply` and `canSendImOk` require the link to be `ready`.
///   Connecting / degraded / disconnected all disable the send affordance
///   so the Watch UI grays out the Send button before the phone would
///   reject the intent anyway.
/// - `canSendLocationIntent` is always false because MESH_SIGNALS_V0_1
///   explicitly bars a GPS payload (the location intent is reserved for
///   v2 once a payload type is specified).
/// - `canShowInbox` and `canShowNodes` are true whenever the slice has
///   something to render, so the Watch's empty-state placeholders only
///   appear when the underlying data really is empty.
WatchCompanionCapabilities deriveWatchCapabilities({
  required WatchCompanionConnectionState connection,
  required bool inboxHasData,
  required bool nodesHasData,
}) {
  final canSend = connection.status == WatchCompanionConnectionStatus.ready;
  return WatchCompanionCapabilities(
    canQuickReply: canSend,
    canSendImOk: canSend,
    canSendLocationIntent: false,
    canShowNodes: nodesHasData,
    canShowInbox: inboxHasData,
  );
}
