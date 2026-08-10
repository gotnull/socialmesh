// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canonical `RouteSettings.name` values for conversation screens.
//
// Every push of a chat screen carries one of these names - from a list
// tile, a map callout, a quick-action sheet or a notification tap. The
// name identifies the conversation, not just the screen class, so the
// notification router can tell whether the thread it is about to open is
// already the top route and skip a duplicate push. Without it, tapping
// one notification after another for the same channel stacks a new
// identical screen every time and the user has to back out of each one.
//
// The names are opaque stack tags, never passed to `pushNamed`: they are
// deliberately not `/`-prefixed so they can never be mistaken for an
// `onGenerateRoute` path or match a `RouteRegistry` entry.

const String _conversationRoutePrefix = 'chat';

/// Stack tag for a Meshtastic channel thread.
String meshtasticChannelRouteName(int channelIndex) =>
    '$_conversationRoutePrefix:meshtastic:channel:$channelIndex';

/// Stack tag for a Meshtastic direct-message thread.
String meshtasticDmRouteName(int nodeNum) =>
    '$_conversationRoutePrefix:meshtastic:dm:$nodeNum';

/// Stack tag for a MeshCore channel thread.
String meshCoreChannelRouteName(int channelIndex) =>
    '$_conversationRoutePrefix:meshcore:channel:$channelIndex';

/// Stack tag for a MeshCore contact thread. The public key is lowercased
/// so a tag built from a notification payload matches one built from the
/// contact store regardless of how either side cased the hex.
String meshCoreContactRouteName(String publicKeyHex) =>
    '$_conversationRoutePrefix:meshcore:dm:${publicKeyHex.toLowerCase()}';
