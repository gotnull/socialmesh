// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

// A user-defined grouping of nodes (e.g. "Repeaters", "My Team").
//
// Groups are a local organisation concept with no Meshtastic radio
// equivalent; they are persisted in nodedex.db alongside the other per-node
// user metadata (social tag, note, local nickname). Row mapping lives in
// NodeGroupsStore so this model stays free of any database coupling.
//
// [colorValue] is an ARGB int rendered via `Color(colorValue)` (mirroring the
// Routes feature). [iconKey] is a stable string key into [kNodeGroupIcons] --
// never a raw code point, so Flutter's icon tree-shaking stays intact in
// release builds.
@immutable
class NodeGroup {
  final String id;
  final String name;
  final int colorValue;
  final String iconKey;
  final int sortOrder;
  final int createdAtMs;
  final int updatedAtMs;

  const NodeGroup({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconKey,
    this.sortOrder = 0,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  /// The group's swatch colour.
  Color get color => Color(colorValue);

  /// The group's icon, resolved from the curated const set. Falls back to a
  /// neutral label icon when the key is unknown (e.g. written by a newer build).
  IconData get icon => kNodeGroupIcons[iconKey] ?? kNodeGroupFallbackIcon;

  NodeGroup copyWith({
    String? name,
    int? colorValue,
    String? iconKey,
    int? sortOrder,
    int? updatedAtMs,
  }) {
    return NodeGroup(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeGroup &&
          other.id == id &&
          other.name == name &&
          other.colorValue == colorValue &&
          other.iconKey == iconKey &&
          other.sortOrder == sortOrder &&
          other.createdAtMs == createdAtMs &&
          other.updatedAtMs == updatedAtMs;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    iconKey,
    sortOrder,
    createdAtMs,
    updatedAtMs,
  );
}

/// Fallback icon used when a stored [NodeGroup.iconKey] is not recognised.
const IconData kNodeGroupFallbackIcon = Icons.label_outline;

/// Default icon key for newly created groups.
const String kNodeGroupDefaultIconKey = 'label';

/// Curated set of group icons, keyed by a stable string stored in the DB.
///
/// Every value is a `const IconData`, so icon tree-shaking is preserved in
/// release builds. Add new entries to the END with a new key; never repurpose
/// an existing key (stored rows reference it).
const Map<String, IconData> kNodeGroupIcons = {
  'label': Icons.label,
  'star': Icons.star,
  'home': Icons.home,
  'work': Icons.work,
  'group': Icons.group,
  'favorite': Icons.favorite,
  'router': Icons.router,
  'sensors': Icons.sensors,
  'hub': Icons.hub,
  'place': Icons.place,
  'shield': Icons.shield,
  'bolt': Icons.bolt,
  'terrain': Icons.terrain,
  'directions_car': Icons.directions_car,
  'flag': Icons.flag,
  'bookmark': Icons.bookmark,
  'antenna': Icons.settings_input_antenna,
  'campaign': Icons.campaign,
};
