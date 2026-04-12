// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh service instance model.
///
/// A user-created instance of a canonical mesh service type.
/// Instances hold configuration/data; an optional preset captures the
/// creation-time flavor without changing the core capability.
/// Instances are locally persisted and advertised via MRRP.
library;

import 'dart:convert';

import 'mesh_service_template.dart';

/// Lifecycle status of a service instance.
enum MeshServiceStatus {
  /// Instance is active and being advertised.
  active,

  /// Instance was stopped by the creator.
  stopped,

  /// Instance expired (TTL elapsed).
  expired,
}

/// A user-created service instance.
class MeshServiceInstance {
  /// Unique local identifier (UUID v4 string).
  final String instanceId;

  /// The canonical capability this instance provides.
  final MeshServiceType canonicalType;

  /// Optional creation preset.
  final MeshServicePresetId? presetId;

  /// User-provided title.
  final String title;

  /// User-provided description (optional).
  final String description;

  /// When this instance was created.
  final DateTime createdAt;

  /// When this instance expires (null = no expiry).
  final DateTime? expiresAt;

  /// Current lifecycle status.
  final MeshServiceStatus status;

  /// Type-specific configuration payload (JSON-encodable map).
  /// Examples:
  ///  - feed: {} (uses title/description only)
  ///  - poll: {"question": "...", "options": ["A", "B", "C"]}
  ///  - list: {"items": ["item1", "item2"]}
  final Map<String, dynamic> config;

  /// Whether this instance was created by the local user.
  final bool isLocal;

  const MeshServiceInstance({
    required this.instanceId,
    required this.canonicalType,
    this.presetId,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.expiresAt,
    this.status = MeshServiceStatus.active,
    this.config = const {},
    this.isLocal = true,
  });

  /// Whether this instance has expired based on the current time.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this instance is currently active (not stopped, not expired).
  bool get isActive => status == MeshServiceStatus.active && !isExpired;

  /// Effective status considering expiry.
  MeshServiceStatus get effectiveStatus {
    if (status == MeshServiceStatus.stopped) return MeshServiceStatus.stopped;
    if (isExpired) return MeshServiceStatus.expired;
    return status;
  }

  /// Remaining duration before expiry (null if no expiry or already expired).
  Duration? get remainingDuration {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  /// Create a copy with updated fields.
  MeshServiceInstance copyWith({
    MeshServiceType? canonicalType,
    MeshServicePresetId? presetId,
    String? title,
    String? description,
    DateTime? expiresAt,
    MeshServiceStatus? status,
    Map<String, dynamic>? config,
  }) {
    return MeshServiceInstance(
      instanceId: instanceId,
      canonicalType: canonicalType ?? this.canonicalType,
      presetId: presetId ?? this.presetId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      config: config ?? this.config,
      isLocal: isLocal,
    );
  }

  /// Serialize to a map for SQLite storage.
  Map<String, dynamic> toMap() {
    return {
      'instance_id': instanceId,
      'canonical_type': canonicalType.name,
      'preset_id': presetId?.name,
      'title': title,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'status': status.name,
      'config': jsonEncode(config),
      'is_local': isLocal ? 1 : 0,
    };
  }

  /// Deserialize from a SQLite row map.
  factory MeshServiceInstance.fromMap(Map<String, dynamic> map) {
    final canonicalType = _canonicalTypeFromMap(map);
    final presetId = _presetIdFromMap(map, canonicalType);

    return MeshServiceInstance(
      instanceId: map['instance_id'] as String,
      canonicalType: canonicalType,
      presetId: presetId,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
      status: MeshServiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MeshServiceStatus.active,
      ),
      config: map['config'] != null
          ? (jsonDecode(map['config'] as String) as Map<String, dynamic>)
          : const {},
      isLocal: (map['is_local'] as int?) == 1,
    );
  }

  static MeshServiceType _canonicalTypeFromMap(Map<String, dynamic> map) {
    final canonicalTypeName = map['canonical_type'] as String?;
    if (canonicalTypeName != null) {
      for (final value in MeshServiceType.values) {
        if (value.name == canonicalTypeName) return value;
      }
    }

    return MeshServiceCatalog.normalizeLegacyTemplateId(
      map['template_id'] as String?,
    ).canonicalType;
  }

  static MeshServicePresetId? _presetIdFromMap(
    Map<String, dynamic> map,
    MeshServiceType canonicalType,
  ) {
    final presetIdName = map['preset_id'] as String?;
    if (presetIdName != null) {
      for (final value in MeshServicePresetId.values) {
        if (value.name == presetIdName) {
          final preset = MeshServiceCatalog.presetById(value);
          if (preset?.canonicalType == canonicalType) {
            return value;
          }
        }
      }
    }

    if (map['canonical_type'] != null) {
      return null;
    }

    return MeshServiceCatalog.normalizeLegacyTemplateId(
      map['template_id'] as String?,
    ).presetId;
  }
}
