// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// A single feature item within a What's New payload.
///
/// Each item describes one new feature or notable change introduced
/// in a particular version. Items can optionally reference an Ico help
/// topic, a deep-link route, and a badge key for drawer indicators.
class WhatsNewItem {
  /// Unique identifier for this item (e.g. "nodedex_intro").
  final String id;

  /// Display title shown in the popup (e.g. "NodeDex").
  final String title;

  /// Short description of what the feature does.
  final String description;

  /// Icon shown alongside the item in the popup.
  final IconData icon;

  /// Optional icon color override. Falls back to accent color when null.
  final Color? iconColor;

  /// Optional route path for deep-linking (e.g. navigating to the feature).
  /// When non-null, a CTA button is rendered in the popup.
  final String? deepLinkRoute;

  /// Optional Ico help topic ID to open the relevant help tour.
  /// When non-null, a "Learn more" action is rendered.
  final String? helpTopicId;

  /// Optional key used to match this item to a drawer menu entry.
  /// When the payload is unseen, any drawer item whose badge key matches
  /// will show a "NEW" chip.
  final String? badgeKey;

  /// Label for the primary CTA button. Defaults to "Open" when a
  /// [deepLinkRoute] is provided.
  final String? ctaLabel;

  const WhatsNewItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
    this.deepLinkRoute,
    this.helpTopicId,
    this.badgeKey,
    this.ctaLabel,
  });
}

/// A versioned collection of [WhatsNewItem]s shown together when the
/// user updates to (or installs) the given version.
class WhatsNewPayload {
  /// The semantic version this payload is associated with (e.g. "1.2.0").
  final String version;

  /// Headline shown at the top of the popup.
  final String headline;

  /// Optional subtitle rendered below the headline.
  final String? subtitle;

  /// The feature items to display.
  final List<WhatsNewItem> items;

  const WhatsNewPayload({
    required this.version,
    required this.headline,
    this.subtitle,
    required this.items,
  });

  /// Returns the set of badge keys referenced by items in this payload.
  Set<String> get badgeKeys =>
      items.where((i) => i.badgeKey != null).map((i) => i.badgeKey!).toSet();
}

/// Static registry of all What's New payloads, ordered by version.
///
/// To add a new entry for a future release:
/// 1. Create a new [WhatsNewPayload] with the target version string.
/// 2. Add one or more [WhatsNewItem]s describing the new features.
/// 3. Append the payload to [_payloads] in ascending version order.
/// 4. If a drawer item should show a NEW chip, set [WhatsNewItem.badgeKey]
///    to the same value used in the drawer menu's `whatsNewBadgeKey` field.
///
/// See docs/WHATS_NEW.md for the full guide.
class WhatsNewRegistry {
  WhatsNewRegistry._();

  // ===========================================================================
  // PAYLOADS — add new versions at the bottom
  // ===========================================================================

  static const List<WhatsNewPayload> _payloads = [
    // v0.9.0 — Reachability introduction
    WhatsNewPayload(
      version: '0.9.0',
      headline: "What's New in Socialmesh",
      subtitle: 'Version 0.9.0',
      items: [
        WhatsNewItem(
          id: 'reachability_intro',
          title: 'Reachability',
          description:
              'Estimate how likely you are to reach each node on your mesh — '
              'without sending a single test packet.\n\n'
              'Reachability passively observes traffic flowing through the '
              'network and assigns High, Medium, or Low confidence to every '
              'node. Find it in the drawer menu under Mesh.',
          icon: Icons.wifi_find,
          iconColor: Color(0xFF26A69A), // Colors.teal.shade400
          deepLinkRoute: '/reachability',
          helpTopicId: 'reachability_overview',
          ctaLabel: 'Open Reachability',
        ),
      ],
    ),

    // v1.0.0 — World Map introduction
    WhatsNewPayload(
      version: '1.0.0',
      headline: "What's New in Socialmesh",
      subtitle: 'Version 1.0.0',
      items: [
        WhatsNewItem(
          id: 'world_map_intro',
          title: 'World Map',
          description:
              'See the entire global Meshtastic network on a single map. '
              'Every dot is a node sharing its location — zoom, pan, and '
              'tap to explore node details, hardware info, and last-seen '
              'times.\n\n'
              'No connection required. The World Map pulls live data from '
              'the Socialmesh backend so you can explore the mesh anywhere.',
          icon: Icons.public,
          iconColor: Color(0xFF42A5F5), // Colors.blue.shade400
          deepLinkRoute: '/world-map',
          helpTopicId: 'world_mesh_overview',
          ctaLabel: 'Open World Map',
        ),
      ],
    ),

    // v1.1.0 — Signals / Presence Feed introduction
    WhatsNewPayload(
      version: '1.1.0',
      headline: "What's New in Socialmesh",
      subtitle: 'Version 1.1.0',
      items: [
        WhatsNewItem(
          id: 'signals_intro',
          title: 'Signals',
          description:
              'Broadcast ephemeral moments to your mesh. Signals are '
              'presence markers — share text, a photo, or your location '
              'with a TTL from 15 minutes up to 24 hours.\n\n'
              'Nearby signals appear first with proximity badges showing '
              'hop count. When they fade, they are gone. True off-grid, '
              'ephemeral presence.',
          icon: Icons.sensors,
          iconColor: Color(0xFFBA68C8), // Colors.purple.shade300
          deepLinkRoute: '/signals',
          helpTopicId: 'signals_overview',
          ctaLabel: 'Open Signals',
        ),
      ],
    ),

    // v1.2.0 — NodeDex introduction
    WhatsNewPayload(
      version: '1.2.0',
      headline: "What's New in Socialmesh",
      subtitle: 'Version 1.2.0',
      items: [
        WhatsNewItem(
          id: 'nodedex_intro',
          title: 'NodeDex',
          description:
              'A living field journal of the mesh world. Every node you '
              'discover is automatically recorded with a unique procedural '
              'Sigil and a personality Trait derived from real behavior.\n\n'
              'Find it in the drawer menu under Social. Filter by trait, '
              'search by name or hex ID, and tap any entry to explore its '
              'full profile — signal history, discovery timeline, and more.',
          icon: Icons.auto_stories_outlined,
          iconColor: Color(0xFFFFCA28), // Colors.amber.shade400
          deepLinkRoute: '/nodedex',
          helpTopicId: 'nodedex_overview',
          badgeKey: 'nodedex',
          ctaLabel: 'Open NodeDex',
        ),
      ],
    ),
  ];

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Returns all registered payloads in ascending version order.
  static List<WhatsNewPayload> get allPayloads => List.unmodifiable(_payloads);

  /// Returns the payload for the given [version], or null if none exists.
  static WhatsNewPayload? getPayload(String version) {
    for (final payload in _payloads) {
      if (payload.version == version) return payload;
    }
    return null;
  }

  /// Returns the latest payload whose version is less than or equal to
  /// [currentVersion] and strictly greater than [lastSeenVersion].
  ///
  /// This is the payload that should be shown to the user on launch.
  /// Returns null when there is nothing new to show.
  static WhatsNewPayload? getPendingPayload({
    required String currentVersion,
    required String? lastSeenVersion,
  }) {
    // Walk payloads in reverse (newest first) to find the most recent
    // payload that the user hasn't seen yet.
    for (var i = _payloads.length - 1; i >= 0; i--) {
      final payload = _payloads[i];
      final payloadVersion = _parseVersion(payload.version);
      final currentParsed = _parseVersion(currentVersion);

      if (payloadVersion == null || currentParsed == null) continue;

      // Payload must be <= current app version
      if (_compareVersionTuples(payloadVersion, currentParsed) > 0) continue;

      // Payload must be > last seen version (or last seen is null)
      if (lastSeenVersion != null) {
        final lastSeenParsed = _parseVersion(lastSeenVersion);
        if (lastSeenParsed != null &&
            _compareVersionTuples(payloadVersion, lastSeenParsed) <= 0) {
          continue;
        }
      }

      return payload;
    }
    return null;
  }

  /// Returns the set of all badge keys from payloads that are newer than
  /// [lastSeenVersion] and at most [currentVersion].
  ///
  /// Used by the drawer to determine which items should show a NEW chip.
  static Set<String> getUnseenBadgeKeys({
    required String currentVersion,
    required String? lastSeenVersion,
  }) {
    final keys = <String>{};
    for (final payload in _payloads) {
      final payloadVersion = _parseVersion(payload.version);
      final currentParsed = _parseVersion(currentVersion);

      if (payloadVersion == null || currentParsed == null) continue;
      if (_compareVersionTuples(payloadVersion, currentParsed) > 0) continue;

      if (lastSeenVersion != null) {
        final lastSeenParsed = _parseVersion(lastSeenVersion);
        if (lastSeenParsed != null &&
            _compareVersionTuples(payloadVersion, lastSeenParsed) <= 0) {
          continue;
        }
      }

      keys.addAll(payload.badgeKeys);
    }
    return keys;
  }

  // ===========================================================================
  // INTERNAL HELPERS
  // ===========================================================================

  /// Parses "major.minor.patch" into a 3-element list, stripping build
  /// metadata and pre-release suffixes.
  static List<int>? _parseVersion(String version) {
    final cleaned = version.split('+').first.split('-').first.trim();
    final parts = cleaned.split('.');
    if (parts.length < 2 || parts.length > 3) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = parts.length >= 3 ? int.tryParse(parts[2]) : 0;

    if (major == null || minor == null || patch == null) return null;
    return [major, minor, patch];
  }

  /// Standard three-way comparison for version tuples.
  static int _compareVersionTuples(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
