// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore feature module.
//
// This module provides MeshCore-specific functionality:
// - Contacts management (discovery, QR sharing)
// - Channels (group communication)
// - Tools (diagnostics, analysis)
//
// MeshCore uses a different communication model than Meshtastic:
// - Contacts replace Nodes (discovered via adverts)
// - Direct encrypted messaging with public keys
// - Channel-based group communication

export 'screens/screens.dart';
