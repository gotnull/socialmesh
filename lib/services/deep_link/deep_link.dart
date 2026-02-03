// SPDX-License-Identifier: GPL-3.0-or-later

/// Deep link handling pipeline for Socialmesh.
///
/// This package provides a centralized, crash-safe deep link system:
///
/// 1. [DeepLinkParser] - Parses URIs into [ParsedDeepLink] objects
/// 2. [DeepLinkRouter] - Determines routes from parsed links
/// 3. [DeepLinkManager] - Manages lifecycle and executes navigation
///
/// Supported URI formats:
/// - `socialmesh://node/<base64-or-docId>`
/// - `socialmesh://channel/<base64>`
/// - `socialmesh://profile/<id>`
/// - `socialmesh://widget/<id>`
/// - `socialmesh://post/<id>`
/// - `socialmesh://location?lat=X&lng=Y`
/// - `https://socialmesh.app/share/node/<id>`
/// - `https://socialmesh.app/share/profile/<id>`
/// - `meshtastic://` (legacy, redirected)
/// - `https://meshtastic.org/e/#<base64>` (legacy channel)
library;

export 'deep_link_parser.dart';
export 'deep_link_router.dart';
export 'deep_link_types.dart';
