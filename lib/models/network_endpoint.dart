// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import '../services/transport/network_transport.dart';

/// A saved network endpoint for TCP connections.
///
/// Reference: meshtastic-ios Device struct with identifier "host:port"
/// persisted via UserDefaults/ManualConnectionList.
class NetworkEndpoint {
  final String id;
  final String host;
  final int port;
  final DateTime lastUsed;
  final String? name;

  NetworkEndpoint({
    required this.id,
    required this.host,
    required this.port,
    required this.lastUsed,
    this.name,
  });

  String get displayAddress => '$host:$port';

  NetworkEndpoint copyWith({
    String? id,
    String? host,
    int? port,
    DateTime? lastUsed,
    String? name,
  }) {
    return NetworkEndpoint(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      lastUsed: lastUsed ?? this.lastUsed,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'lastUsed': lastUsed.toIso8601String(),
    'name': name,
  };

  factory NetworkEndpoint.fromJson(Map<String, dynamic> json) {
    return NetworkEndpoint(
      id: json['id'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? kMeshtasticDefaultPort,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      name: json['name'] as String?,
    );
  }

  /// Create a new endpoint with an auto-generated ID.
  factory NetworkEndpoint.create({
    required String host,
    int port = kMeshtasticDefaultPort,
    String? name,
  }) {
    // Deterministic ID based on host:port (matches meshtastic-ios pattern)
    final idSource = '$host:$port';
    final id = idSource.hashCode.toRadixString(16);
    return NetworkEndpoint(
      id: id,
      host: host,
      port: port,
      lastUsed: DateTime.now(),
      name: name,
    );
  }

  /// Serialize a list of endpoints to JSON string for SharedPreferences.
  static String encodeList(List<NetworkEndpoint> endpoints) {
    return jsonEncode(endpoints.map((e) => e.toJson()).toList());
  }

  /// Deserialize a list of endpoints from JSON string.
  static List<NetworkEndpoint> decodeList(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list
        .map((e) => NetworkEndpoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkEndpoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NetworkEndpoint($host:$port)';
}
