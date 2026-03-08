// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh service instance model.
///
/// A user-created instance of a built-in template. Instances hold
/// configuration/data; the template type defines the behavior.
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

  /// Which template this instance was created from.
  final MeshServiceTemplateId templateId;

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

  /// Template-specific configuration payload (JSON-encodable map).
  /// Examples:
  ///  - board: {} (uses title/description only)
  ///  - poll: {"question": "...", "options": ["A", "B", "C"]}
  ///  - checklist: {"items": ["item1", "item2"]}
  ///  - resourceList: {"items": ["resource1", "resource2"]}
  ///  - signal: {"signalType": 1}
  final Map<String, dynamic> config;

  /// Whether this instance was created by the local user.
  final bool isLocal;

  const MeshServiceInstance({
    required this.instanceId,
    required this.templateId,
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
    String? title,
    String? description,
    DateTime? expiresAt,
    MeshServiceStatus? status,
    Map<String, dynamic>? config,
  }) {
    return MeshServiceInstance(
      instanceId: instanceId,
      templateId: templateId,
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
      'template_id': templateId.name,
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
    return MeshServiceInstance(
      instanceId: map['instance_id'] as String,
      templateId: MeshServiceTemplateId.values.firstWhere(
        (e) => e.name == map['template_id'],
        orElse: () => MeshServiceTemplateId.board,
      ),
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
}
