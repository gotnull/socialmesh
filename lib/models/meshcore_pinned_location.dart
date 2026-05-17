// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q10: user-dropped map pin (POI annotation). Local-only — no
// wire frame is emitted, no copy is shared with the mesh.

import 'dart:convert';

class MeshCorePinnedLocation {
  /// Stable id, used for deletion. ISO-8601 of the creation
  /// timestamp; collisions are virtually impossible (sub-millisecond
  /// double-tap on a phone wouldn't both succeed because long-press
  /// is gated by a sheet prompt).
  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final DateTime createdAt;

  const MeshCorePinnedLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': latitude,
    'lon': longitude,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  static MeshCorePinnedLocation? tryFromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lon = json['lon'];
    final label = json['label'];
    final id = json['id'];
    final createdAtRaw = json['createdAt'];
    if (lat is! num) return null;
    if (lon is! num) return null;
    if (label is! String) return null;
    if (id is! String) return null;
    if (createdAtRaw is! String) return null;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;
    return MeshCorePinnedLocation(
      id: id,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      label: label,
      createdAt: createdAt,
    );
  }

  /// Encode the pin to a single JSON string the
  /// `MeshCorePinnedLocationStore` can persist inside a
  /// `SharedPreferences` `StringList`.
  String encode() => jsonEncode(toJson());

  static MeshCorePinnedLocation? decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return tryFromJson(json);
    } catch (_) {
      return null;
    }
  }
}
