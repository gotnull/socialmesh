// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import '../services/transport/network_transport.dart';

/// Default TCP port for MeshCore companion-radio firmware over Wi-Fi.
const int kMeshCoreDefaultTcpPort = 5000;

/// Mesh protocol carried over a saved TCP endpoint.
///
/// Each saved endpoint is bound to one protocol. Meshtastic is the
/// production default; MeshCore is exposed only as a dev/debug option
/// (gated in the UI) and goes through [ConnectionCoordinator]'s
/// dedicated `connectMeshCoreTcp` path — never through the Meshtastic
/// network transport.
enum NetworkEndpointProtocol {
  meshtastic,
  meshcore;

  /// Stable wire name for serialization. Do not rename; would break
  /// already-saved endpoints in shared_preferences.
  String get id => switch (this) {
    NetworkEndpointProtocol.meshtastic => 'meshtastic',
    NetworkEndpointProtocol.meshcore => 'meshcore',
  };

  static NetworkEndpointProtocol fromId(String? id) {
    switch (id) {
      case 'meshcore':
        return NetworkEndpointProtocol.meshcore;
      case 'meshtastic':
      default:
        return NetworkEndpointProtocol.meshtastic;
    }
  }
}

/// A saved network endpoint for TCP connections.
///
/// Modelled after the standard Meshtastic companion app pattern of
/// persisting manual connections as "host:port" identifiers.
class NetworkEndpoint {
  final String id;
  final String host;
  final int port;
  final DateTime lastUsed;
  final String? name;
  final NetworkEndpointProtocol protocol;

  NetworkEndpoint({
    required this.id,
    required this.host,
    required this.port,
    required this.lastUsed,
    this.name,
    this.protocol = NetworkEndpointProtocol.meshtastic,
  });

  String get displayAddress => '$host:$port';

  NetworkEndpoint copyWith({
    String? id,
    String? host,
    int? port,
    DateTime? lastUsed,
    String? name,
    NetworkEndpointProtocol? protocol,
  }) {
    return NetworkEndpoint(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      lastUsed: lastUsed ?? this.lastUsed,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'lastUsed': lastUsed.toIso8601String(),
    'name': name,
    'protocol': protocol.id,
  };

  /// Canonical host form: trimmed and lowercased.
  ///
  /// Hostnames are case-insensitive (RFC 4343), so normalizing at storage
  /// time keeps 'Node.Local' and 'node.local' from producing two distinct
  /// saved endpoints with distinct ids.
  static String normalizeHost(String host) => host.trim().toLowerCase();

  /// Whether [port] is a valid TCP port for an endpoint.
  static bool isValidPort(int port) => port >= 1 && port <= 65535;

  factory NetworkEndpoint.fromJson(Map<String, dynamic> json) {
    // Lenient on disk content: legacy entries saved before storage-time
    // normalization are cleaned on load, never rejected. The stored id is
    // kept verbatim so legacy entries retain their identity.
    final rawPort = json['port'] as int? ?? kMeshtasticDefaultPort;
    return NetworkEndpoint(
      id: json['id'] as String,
      host: normalizeHost(json['host'] as String),
      port: isValidPort(rawPort) ? rawPort : kMeshtasticDefaultPort,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      name: json['name'] as String?,
      protocol: NetworkEndpointProtocol.fromId(json['protocol'] as String?),
    );
  }

  /// Create a new endpoint with an auto-generated ID.
  ///
  /// The host is normalized before the ID is derived, so two casings of
  /// the same hostname collapse to one endpoint.
  factory NetworkEndpoint.create({
    required String host,
    int port = kMeshtasticDefaultPort,
    String? name,
    NetworkEndpointProtocol protocol = NetworkEndpointProtocol.meshtastic,
  }) {
    if (!isValidPort(port)) {
      throw ArgumentError.value(port, 'port', 'must be in 1..65535');
    }
    final normalizedHost = normalizeHost(host);
    // Deterministic ID per (protocol, host, port) so the same host:port
    // can coexist for two different protocols without collision.
    final idSource = '${protocol.id}:$normalizedHost:$port';
    final id = idSource.hashCode.toRadixString(16);
    return NetworkEndpoint(
      id: id,
      host: normalizedHost,
      port: port,
      lastUsed: DateTime.now(),
      name: name,
      protocol: protocol,
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
