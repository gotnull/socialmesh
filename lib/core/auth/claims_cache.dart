// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging.dart';

/// Cached organisation claims extracted from Firebase JWT.
///
/// Consumer users (no org membership) have null [orgId] and [role].
/// [cachedAt] and [tokenExpiry] are milliseconds since epoch.
@immutable
class CachedClaims {
  final String? orgId;
  final String? role;
  final int cachedAt;
  final int tokenExpiry;

  const CachedClaims({
    required this.orgId,
    required this.role,
    required this.cachedAt,
    required this.tokenExpiry,
  });

  /// Whether this represents a consumer user with no org claims.
  bool get isConsumer => orgId == null && role == null;

  /// Whether the cached token expiry has been exceeded by more than 24 hours.
  bool get isStale {
    final now = DateTime.now().millisecondsSinceEpoch;
    const stalenessThresholdMs = 24 * 60 * 60 * 1000; // 24 hours
    return now > tokenExpiry + stalenessThresholdMs;
  }

  /// Staleness duration in hours (how far past expiry + 24h we are).
  /// Returns 0 if not stale.
  int get stalenessHours {
    final now = DateTime.now().millisecondsSinceEpoch;
    const stalenessThresholdMs = 24 * 60 * 60 * 1000;
    final exceededBy = now - (tokenExpiry + stalenessThresholdMs);
    if (exceededBy <= 0) return 0;
    return (exceededBy / (60 * 60 * 1000)).ceil();
  }

  Map<String, dynamic> toJson() => {
    'orgId': orgId,
    'role': role,
    'cachedAt': cachedAt,
    'tokenExpiry': tokenExpiry,
  };

  factory CachedClaims.fromJson(Map<String, dynamic> json) {
    return CachedClaims(
      orgId: json['orgId'] as String?,
      role: json['role'] as String?,
      cachedAt: json['cachedAt'] as int,
      tokenExpiry: json['tokenExpiry'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedClaims &&
          runtimeType == other.runtimeType &&
          orgId == other.orgId &&
          role == other.role &&
          cachedAt == other.cachedAt &&
          tokenExpiry == other.tokenExpiry;

  @override
  int get hashCode => Object.hash(orgId, role, cachedAt, tokenExpiry);

  @override
  String toString() =>
      'CachedClaims(orgId=$orgId, role=$role, cachedAt=$cachedAt, tokenExpiry=$tokenExpiry)';
}

/// Manages reading and writing of org claims to [FlutterSecureStorage].
///
/// Cache JSON structure:
/// ```json
/// {
///   "role": "operator",
///   "orgId": "org-uuid-123",
///   "cachedAt": 1700000000000,
///   "tokenExpiry": 1700003600000
/// }
/// ```
///
/// Corruption (invalid JSON, missing required fields) is handled gracefully
/// by returning null and clearing the corrupt entry.
class ClaimsCache {
  static const _storageKey = 'org_claims_cache';

  final FlutterSecureStorage _storage;

  ClaimsCache({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  /// Write [claims] to secure storage.
  Future<void> write(CachedClaims claims) async {
    final json = jsonEncode(claims.toJson());
    await _storage.write(key: _storageKey, value: json);
    AppLogging.claims(
      'Claims: cached to SecureStorage (cachedAt=${claims.cachedAt})',
    );
  }

  /// Read cached claims from secure storage.
  ///
  /// Returns null if no cache exists or if the cached data is corrupt.
  /// Corrupt entries are cleared automatically.
  Future<CachedClaims?> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Validate required integer fields exist
      if (json['cachedAt'] is! int || json['tokenExpiry'] is! int) {
        AppLogging.claims(
          'Claims: corrupt cache detected (missing required int fields), clearing',
        );
        await clear();
        return null;
      }
      return CachedClaims.fromJson(json);
    } catch (e) {
      AppLogging.claims('Claims: corrupt cache detected ($e), clearing');
      await clear();
      return null;
    }
  }

  /// Clear the cached claims.
  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }

  /// Visible-for-testing: the storage key used.
  static String get storageKey => _storageKey;
}
