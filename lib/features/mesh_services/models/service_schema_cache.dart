// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// In-memory cache for discovered service schemas.
///
/// Peers cache schemas received via MRRP get_schema requests.
/// Built-in canonical service schemas also register here for consistent lookup.
/// Entries expire after [ttl].
library;

import 'service_schema.dart';
import 'template_schemas.dart';
import 'mesh_service_template.dart';

/// Cache key: (nodeId, serviceType string).
typedef _SchemaCacheKey = ({int nodeId, String serviceType});

/// Cached schema entry.
class _SchemaCacheEntry {
  final ServiceSchema schema;
  final DateTime cachedAt;

  _SchemaCacheEntry({required this.schema, required this.cachedAt});
}

/// In-memory schema cache with TTL-based expiry.
class ServiceSchemaCache {
  /// Maximum cached entries.
  static const int maxEntries = 64;

  /// Cache TTL in seconds.
  static const int ttlSeconds = 3600;

  final Map<_SchemaCacheKey, _SchemaCacheEntry> _cache = {};

  /// Store a schema for a remote peer's service.
  void put(int nodeId, ServiceSchema schema) {
    _purgeExpired();

    final key = (nodeId: nodeId, serviceType: schema.serviceType);

    // Evict oldest if at capacity.
    if (!_cache.containsKey(key) && _cache.length >= maxEntries) {
      _evictOldest();
    }

    _cache[key] = _SchemaCacheEntry(schema: schema, cachedAt: DateTime.now());
  }

  /// Get a cached schema for a remote peer's service.
  ///
  /// Falls back to built-in template schemas if no remote schema cached.
  ServiceSchema? get(int nodeId, String serviceType) {
    _purgeExpired();

    final key = (nodeId: nodeId, serviceType: serviceType);
    final entry = _cache[key];
    if (entry != null) return entry.schema;

    // Fall back to built-in canonical schema.
    return _builtInSchema(serviceType);
  }

  /// Check if a schema is cached for a peer+serviceType.
  bool contains(int nodeId, String serviceType) {
    _purgeExpired();
    final key = (nodeId: nodeId, serviceType: serviceType);
    if (_cache.containsKey(key)) return true;
    return _builtInSchema(serviceType) != null;
  }

  /// Number of cached entries.
  int get length => _cache.length;

  /// Clear all cached entries.
  void clear() => _cache.clear();

  void _purgeExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) {
      return now.difference(entry.cachedAt).inSeconds > ttlSeconds;
    });
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;
    DateTime? oldest;
    _SchemaCacheKey? oldestKey;
    for (final entry in _cache.entries) {
      if (oldest == null || entry.value.cachedAt.isBefore(oldest)) {
        oldest = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }
    if (oldestKey != null) _cache.remove(oldestKey);
  }

  /// Look up a built-in canonical schema by service type string.
  static ServiceSchema? _builtInSchema(String serviceType) {
    for (final type in MeshServiceType.values) {
      final schema = MeshServiceSchemas.forType(type);
      if (schema != null && schema.serviceType == serviceType) return schema;
    }
    return null;
  }
}
