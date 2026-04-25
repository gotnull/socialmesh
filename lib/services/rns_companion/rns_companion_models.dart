// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Wire-contract models for the rns_companion HTTP API.
//
// The Python service in `tools/rns_companion/` emits camelCase JSON;
// these Dart models match that contract exactly. See
// `tools/rns_companion/README.md` for the authoritative API spec.

import 'dart:convert';

class RnsCompanionHealth {
  const RnsCompanionHealth({
    required this.ok,
    required this.service,
    required this.version,
    required this.mode,
  });

  final bool ok;
  final String service;
  final String version;

  /// Identifier of the active data source on the companion side
  /// (`"stub"` or `"live"`). Defaults to `"unknown"` when the
  /// companion is older than v0.2 and doesn't emit the field.
  final String mode;

  factory RnsCompanionHealth.fromJson(Map<String, dynamic> json) {
    return RnsCompanionHealth(
      ok: json['ok'] as bool,
      service: json['service'] as String,
      version: json['version'] as String,
      mode: (json['mode'] as String?) ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ok': ok,
    'service': service,
    'version': version,
    'mode': mode,
  };
}

class RnsCompanionServiceSummary {
  const RnsCompanionServiceSummary({
    required this.destination,
    required this.name,
    required this.type,
    required this.lastSeen,
  });

  final String destination;
  final String name;
  final String type;
  final int lastSeen;

  factory RnsCompanionServiceSummary.fromJson(Map<String, dynamic> json) {
    return RnsCompanionServiceSummary(
      destination: json['destination'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      lastSeen: (json['lastSeen'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'destination': destination,
    'name': name,
    'type': type,
    'lastSeen': lastSeen,
  };
}

class RnsCompanionPageSummary {
  const RnsCompanionPageSummary({
    required this.pageId,
    required this.title,
    required this.updatedAt,
  });

  final String pageId;
  final String title;
  final int updatedAt;

  factory RnsCompanionPageSummary.fromJson(Map<String, dynamic> json) {
    return RnsCompanionPageSummary(
      pageId: json['pageId'] as String,
      title: json['title'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageId': pageId,
    'title': title,
    'updatedAt': updatedAt,
  };
}

class RnsCompanionPageBody {
  const RnsCompanionPageBody({
    required this.pageId,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String pageId;
  final String title;
  final String body;
  final int updatedAt;

  factory RnsCompanionPageBody.fromJson(Map<String, dynamic> json) {
    return RnsCompanionPageBody(
      pageId: json['pageId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageId': pageId,
    'title': title,
    'body': body,
    'updatedAt': updatedAt,
  };
}

/// Helper used by the client + tests to decode JSON safely. Wraps
/// every parse in a try/catch so callers can map failures to a
/// typed `RnsCompanionParseError`.
Object? decodeRnsCompanionJson(String body) {
  return jsonDecode(body);
}
