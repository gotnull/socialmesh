// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// _internal/ is the only directory in the watch-companion package where
// Meshtastic / MeshCore implementation symbols may be imported. Public
// watch_companion files (everything above this directory) MUST NOT import
// ProtocolService, MeshCoreSession, messagesProvider,
// meshCoreConversationsProvider, channelSettingsProvider, or any other
// protocol-specific symbol. The watch_companion_protocol_isolation_test
// fails the build the moment that boundary is crossed.
//
// This file is intentionally minimal. It exists so:
//   1. git tracks the _internal/ directory (git tracks files, not dirs);
//   2. the protocol-isolation test has a real directory to assert against;
//   3. Slice 3 has an anchor location for the upcoming adapter files
//      (watch_inbox_facade.dart, watch_channels_facade.dart,
//      watch_readiness_facade.dart, watch_send_facade.dart,
//      watch_snapshot_composer.dart, watch_channel_bridge.dart).

/// Sentinel constant proving the _internal/ directory is indexed by the
/// Dart analyzer. Asserted by the isolation test; do not remove without
/// updating that test.
const String kWatchCompanionInternalBoundaryMarker =
    'watch_companion_internal_boundary_v1';
