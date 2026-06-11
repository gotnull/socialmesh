// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared find-then-upload core for QR-shareable content (automations,
// widgets). Each feature keeps its own export-data sanitization and URL
// assembly; the fingerprint dedup and Firestore upload-or-reuse flow is
// identical across content types and lives here once.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Uploads exportable content to a Firestore collection, reusing an
/// existing document when an identical export already exists for the
/// same user (fingerprint match over name-scoped candidates).
class SharedContentUploader {
  /// Target Firestore collection (e.g. `shared_automations`).
  final String collection;

  /// Keys excluded from the duplicate fingerprint. Server-stamped and
  /// ownership fields must never participate, or a re-share of the
  /// same content would always look new.
  final Set<String> fingerprintIgnoredKeys;

  /// Feature-namespaced logger (e.g. `AppLogging.automations`).
  final void Function(String message) log;

  const SharedContentUploader({
    required this.collection,
    required this.log,
    this.fingerprintIgnoredKeys = const {'createdBy', 'createdAt'},
  });

  /// Order-independent fingerprint over the export payload.
  String fingerprintOf(Map<String, dynamic> exportData) {
    final data = Map<String, dynamic>.from(exportData);
    for (final key in fingerprintIgnoredKeys) {
      data.remove(key);
    }
    final sortedKeys = data.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key:${data[key]}|');
    }
    return buffer.toString().hashCode.toRadixString(16);
  }

  /// Returns the id of an existing identical document owned by
  /// [userId], or null when none matches.
  Future<String?> findExisting(
    String userId,
    Map<String, dynamic> exportData,
  ) async {
    final fingerprint = fingerprintOf(exportData);
    final name = exportData['name'] as String?;

    final query = FirebaseFirestore.instance
        .collection(collection)
        .where('createdBy', isEqualTo: userId)
        .where('name', isEqualTo: name)
        .limit(10);

    try {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        if (fingerprintOf(doc.data()) == fingerprint) {
          log('[Share] Found existing "$name" in $collection: ${doc.id}');
          return doc.id;
        }
      }
    } catch (e) {
      log('[Share] Error checking $collection for duplicates: $e');
    }
    return null;
  }

  /// Uploads [exportData] for [userId], or reuses an identical existing
  /// document. Returns the document id either way.
  Future<String> uploadOrReuse({
    required String userId,
    required Map<String, dynamic> exportData,
    required String contentName,
  }) async {
    final existingId = await findExisting(userId, exportData);
    if (existingId != null) {
      log('[Share] Reusing existing "$contentName" with ID $existingId');
      return existingId;
    }

    final docRef = await FirebaseFirestore.instance.collection(collection).add({
      ...exportData,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    log('[Share] Uploaded "$contentName" to $collection with ID ${docRef.id}');
    return docRef.id;
  }
}
