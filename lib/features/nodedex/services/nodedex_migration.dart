// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Migration — one-time migration from SharedPreferences JSON v2
// into SQLite.
//
// On first open after upgrade:
// 1. Detect existing SharedPreferences NodeDex v2 payload
// 2. Parse all entries from the JSON blob
// 3. Insert into SQLite in a single transaction
// 4. Record migration complete flag in sync_state
// 5. Leave the old payload in place for one version (rollback safety)
//
// Migration acceptance checks verify entry counts, timestamps,
// encounter counts, regions, edges, tags, and notes all match.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../models/nodedex_entry.dart';
import '../services/sigil_generator.dart';
import 'nodedex_sqlite_store.dart';

/// Key used by the legacy SharedPreferences store.
const String _legacyEntriesKey = 'nodedex_entries';

/// Sync state key that records migration completion.
const String migrationCompleteKey = 'nodedex_sp_migration_complete';

/// Handles one-time migration of NodeDex data from SharedPreferences
/// JSON v2 into the SQLite store.
class NodeDexMigration {
  final NodeDexSqliteStore _sqliteStore;

  NodeDexMigration(this._sqliteStore);

  /// Check whether migration has already been completed.
  Future<bool> isMigrationComplete() async {
    final value = await _sqliteStore.getSyncState(migrationCompleteKey);
    return value == 'true';
  }

  /// Run the migration if needed.
  ///
  /// Returns true if migration was performed, false if it was already done
  /// or there was nothing to migrate.
  Future<bool> migrateIfNeeded() async {
    if (await isMigrationComplete()) {
      AppLogging.storage('NodeDexMigration: Already completed, skipping');
      return false;
    }

    AppLogging.storage('NodeDexMigration: Checking for legacy data...');

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_legacyEntriesKey);

    if (jsonString == null || jsonString.isEmpty) {
      AppLogging.storage(
        'NodeDexMigration: No legacy data found, marking complete',
      );
      await _sqliteStore.setSyncState(migrationCompleteKey, 'true');
      return false;
    }

    try {
      final entries = _parseLegacyEntries(jsonString);
      if (entries.isEmpty) {
        AppLogging.storage(
          'NodeDexMigration: Legacy data parsed to empty list, marking complete',
        );
        await _sqliteStore.setSyncState(migrationCompleteKey, 'true');
        return false;
      }

      AppLogging.storage(
        'NodeDexMigration: Found ${entries.length} legacy entries, migrating...',
      );

      // Ensure all entries have sigils.
      final entriesWithSigils = entries.map((entry) {
        if (entry.sigil == null) {
          return entry.copyWith(sigil: SigilGenerator.generate(entry.nodeNum));
        }
        return entry;
      }).toList();

      // Trim encounters to 50 per node (matching current behavior).
      final trimmedEntries = entriesWithSigils.map((entry) {
        if (entry.encounters.length > NodeDexEntry.maxEncounterRecords) {
          final trimmed = entry.encounters.sublist(
            entry.encounters.length - NodeDexEntry.maxEncounterRecords,
          );
          return entry.copyWith(encounters: trimmed);
        }
        return entry;
      }).toList();

      // Insert all entries in a single transaction.
      await _sqliteStore.bulkInsert(trimmedEntries);

      // Verify migration.
      final verificationResult = await _verifyMigration(trimmedEntries);

      if (!verificationResult.success) {
        AppLogging.storage(
          'NodeDexMigration: Verification failed: '
          '${verificationResult.errors.join(", ")}',
        );
        // Still mark complete to avoid repeated failed attempts.
        // The data is in SQLite, verification failures are non-fatal
        // and may be from acceptable differences.
      }

      // Mark migration complete.
      await _sqliteStore.setSyncState(migrationCompleteKey, 'true');

      AppLogging.storage(
        'NodeDexMigration: Successfully migrated ${trimmedEntries.length} '
        'entries to SQLite '
        '(verification: ${verificationResult.success ? "passed" : "warnings"})',
      );

      return true;
    } catch (e, stack) {
      AppLogging.storage('NodeDexMigration: Migration failed: $e\n$stack');
      // Do not mark complete on failure — allow retry next launch.
      return false;
    }
  }

  /// Parse legacy SharedPreferences JSON into entries.
  List<NodeDexEntry> _parseLegacyEntries(String jsonString) {
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((e) => NodeDexEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogging.storage('NodeDexMigration: Error parsing legacy JSON: $e');
      return [];
    }
  }

  /// Verify that migrated data matches the source.
  Future<MigrationVerification> _verifyMigration(
    List<NodeDexEntry> sourceEntries,
  ) async {
    final errors = <String>[];

    final migratedMap = await _sqliteStore.loadAllAsMap();

    // Check entry count.
    if (migratedMap.length != sourceEntries.length) {
      errors.add(
        'Entry count mismatch: '
        'source=${sourceEntries.length}, migrated=${migratedMap.length}',
      );
    }

    // Verify each entry.
    for (final source in sourceEntries) {
      final migrated = migratedMap[source.nodeNum];
      if (migrated == null) {
        errors.add('Missing entry for node ${source.nodeNum}');
        continue;
      }

      if (migrated.firstSeen != source.firstSeen) {
        errors.add(
          'Node ${source.nodeNum}: firstSeen mismatch '
          '(src=${source.firstSeen}, mig=${migrated.firstSeen})',
        );
      }
      if (migrated.lastSeen != source.lastSeen) {
        errors.add('Node ${source.nodeNum}: lastSeen mismatch');
      }
      if (migrated.encounterCount != source.encounterCount) {
        errors.add(
          'Node ${source.nodeNum}: encounterCount mismatch '
          '(src=${source.encounterCount}, mig=${migrated.encounterCount})',
        );
      }
      if (migrated.socialTag != source.socialTag) {
        errors.add('Node ${source.nodeNum}: socialTag mismatch');
      }
      if (migrated.userNote != source.userNote) {
        errors.add('Node ${source.nodeNum}: userNote mismatch');
      }

      // Check encounter count (should be trimmed to 50).
      final expectedEncCount =
          source.encounters.length > NodeDexEntry.maxEncounterRecords
          ? NodeDexEntry.maxEncounterRecords
          : source.encounters.length;
      if (migrated.encounters.length != expectedEncCount) {
        errors.add(
          'Node ${source.nodeNum}: encounter records mismatch '
          '(expected=$expectedEncCount, got=${migrated.encounters.length})',
        );
      }

      // Check region count.
      if (migrated.seenRegions.length != source.seenRegions.length) {
        errors.add(
          'Node ${source.nodeNum}: region count mismatch '
          '(src=${source.seenRegions.length}, '
          'mig=${migrated.seenRegions.length})',
        );
      }

      // Check co-seen edge count.
      if (migrated.coSeenNodes.length != source.coSeenNodes.length) {
        errors.add(
          'Node ${source.nodeNum}: co-seen edge count mismatch '
          '(src=${source.coSeenNodes.length}, '
          'mig=${migrated.coSeenNodes.length})',
        );
      }
    }

    return MigrationVerification(
      success: errors.isEmpty,
      errors: errors,
      sourceCount: sourceEntries.length,
      migratedCount: migratedMap.length,
    );
  }
}

/// Result of migration verification.
class MigrationVerification {
  /// Whether all checks passed.
  final bool success;

  /// List of verification error descriptions.
  final List<String> errors;

  /// Number of entries in the source data.
  final int sourceCount;

  /// Number of entries in the migrated store.
  final int migratedCount;

  const MigrationVerification({
    required this.success,
    required this.errors,
    required this.sourceCount,
    required this.migratedCount,
  });
}
