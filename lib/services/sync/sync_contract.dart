// SPDX-License-Identifier: GPL-3.0-or-later

// Sync Contract Registry — declares all syncable entity types.
//
// Every user-created or user-curated data domain that participates
// in Cloud Sync MUST be registered here. An automated test verifies
// that all registered types have the required infrastructure:
// serialization, local DAO, cloud path, and merge logic.
//
// Adding a new syncable type:
// 1. Add an entry to [SyncType]
// 2. Fill in [SyncTypeConfig] for it
// 3. Ensure local persistence writes outbox entries
// 4. Ensure the sync service handles push/pull for this type
// 5. Run `flutter test test/features/nodedex/nodedex_sync_coverage_test.dart`

/// All entity types that participate in Cloud Sync.
///
/// Each type must have a corresponding [SyncTypeConfig] in [syncTypeConfigs].
enum SyncType {
  /// NodeDex entry (core metrics, encounters, regions, co-seen edges, sigil).
  nodedexEntry,

  /// NodeDex social tag (classification) — synced as part of the entry
  /// but with its own per-field timestamp for last-write-wins.
  nodedexSocialTag,

  /// NodeDex user note — synced as part of the entry but with its own
  /// per-field timestamp for last-write-wins.
  nodedexUserNote,

  /// User profile data (display name, bio, callsign, etc.).
  userProfile,

  /// User preferences (theme, haptics, animations, canned responses, etc.).
  userPreferences,

  /// Automation rules — per-document sync via outbox pattern.
  ///
  /// Each automation is its own Firestore document in
  /// `users/{uid}/automations_sync/{docId}`.
  automations,

  /// Custom widget schemas — per-document sync via outbox pattern.
  ///
  /// Each user-created widget is its own Firestore document in
  /// `users/{uid}/widgets_sync/{docId}`.
  widgetSchemas,
}

/// Configuration for a single syncable entity type.
///
/// Documents the sync infrastructure for each [SyncType] and provides
/// enough metadata for automated coverage tests.
class SyncTypeConfig {
  /// Human-readable name for logging and diagnostics.
  final String displayName;

  /// The entity type string used in the outbox and Firestore documents.
  ///
  /// For types embedded in a parent (like socialTag inside entry),
  /// this is the parent entity type.
  final String entityTypeKey;

  /// Firestore collection path relative to `users/{uid}/`.
  ///
  /// For profile-based sync, this is the top-level collection path.
  final String cloudCollectionPath;

  /// Whether this type uses the NodeDex outbox pattern.
  final bool usesOutbox;

  /// Whether this type is embedded in a parent entity's JSON payload.
  ///
  /// If true, the type does not have its own outbox entries — it travels
  /// with the parent entity.
  final bool isEmbeddedInParent;

  /// The parent [SyncType] if this type is embedded.
  final SyncType? parentType;

  /// Whether tombstone (soft-delete) is supported.
  final bool supportsTombstone;

  /// Whether per-field timestamps are used for conflict resolution.
  final bool hasPerFieldTimestamp;

  /// Whether this type is gated by the Cloud Sync entitlement.
  final bool requiresEntitlement;

  /// Description of the conflict resolution policy.
  final String conflictPolicy;

  const SyncTypeConfig({
    required this.displayName,
    required this.entityTypeKey,
    required this.cloudCollectionPath,
    required this.usesOutbox,
    this.isEmbeddedInParent = false,
    this.parentType,
    this.supportsTombstone = false,
    this.hasPerFieldTimestamp = false,
    this.requiresEntitlement = true,
    required this.conflictPolicy,
  });
}

/// The canonical registry of all sync type configurations.
///
/// Every [SyncType] must have an entry here. The automated test
/// `nodedex_sync_coverage_test.dart` verifies this.
const Map<SyncType, SyncTypeConfig> syncTypeConfigs = {
  SyncType.nodedexEntry: SyncTypeConfig(
    displayName: 'NodeDex Entry',
    entityTypeKey: 'entry',
    cloudCollectionPath: 'nodedex_sync',
    usesOutbox: true,
    supportsTombstone: true,
    conflictPolicy:
        'Metric merge: min firstSeen, max lastSeen, max counts. '
        'Collections: union merge with dedup.',
  ),
  SyncType.nodedexSocialTag: SyncTypeConfig(
    displayName: 'NodeDex Classification',
    entityTypeKey: 'entry',
    cloudCollectionPath: 'nodedex_sync',
    usesOutbox: true,
    isEmbeddedInParent: true,
    parentType: SyncType.nodedexEntry,
    hasPerFieldTimestamp: true,
    conflictPolicy:
        'Last-write-wins by socialTagUpdatedAtMs. '
        'Conflict copy if both edited within 5s window.',
  ),
  SyncType.nodedexUserNote: SyncTypeConfig(
    displayName: 'NodeDex User Note',
    entityTypeKey: 'entry',
    cloudCollectionPath: 'nodedex_sync',
    usesOutbox: true,
    isEmbeddedInParent: true,
    parentType: SyncType.nodedexEntry,
    hasPerFieldTimestamp: true,
    conflictPolicy:
        'Last-write-wins by userNoteUpdatedAtMs. '
        'Conflict copy if both edited within 5s window.',
  ),
  SyncType.userProfile: SyncTypeConfig(
    displayName: 'User Profile',
    entityTypeKey: 'profile',
    cloudCollectionPath: 'users',
    usesOutbox: false,
    supportsTombstone: false,
    requiresEntitlement: false,
    conflictPolicy:
        'Local-first with server merge via ProfileCloudSyncService.',
  ),
  SyncType.userPreferences: SyncTypeConfig(
    displayName: 'User Preferences',
    entityTypeKey: 'preferences',
    cloudCollectionPath: 'users',
    usesOutbox: false,
    isEmbeddedInParent: true,
    parentType: SyncType.userProfile,
    requiresEntitlement: false,
    conflictPolicy:
        'Null-coalescing merge: non-null values win per field. '
        'Embedded in profile document.',
  ),
  SyncType.automations: SyncTypeConfig(
    displayName: 'Automations',
    entityTypeKey: 'automation',
    cloudCollectionPath: 'automations_sync',
    usesOutbox: true,
    supportsTombstone: true,
    requiresEntitlement: true,
    conflictPolicy:
        'Per-document last-write-wins. Each automation is an independent '
        'Firestore document with its own updated_at_ms timestamp.',
  ),
  SyncType.widgetSchemas: SyncTypeConfig(
    displayName: 'Widget Schemas',
    entityTypeKey: 'widget',
    cloudCollectionPath: 'widgets_sync',
    usesOutbox: true,
    supportsTombstone: true,
    requiresEntitlement: true,
    conflictPolicy:
        'Per-document last-write-wins. Each custom widget is an independent '
        'Firestore document with its own updated_at_ms timestamp.',
  ),
};

/// Verify that all [SyncType] values have a config entry.
///
/// Call this from tests to enforce completeness.
bool verifySyncContractCompleteness() {
  for (final type in SyncType.values) {
    if (!syncTypeConfigs.containsKey(type)) {
      return false;
    }
  }
  return true;
}

/// Get the list of sync types that are missing config entries.
List<SyncType> getMissingSyncConfigs() {
  return SyncType.values
      .where((type) => !syncTypeConfigs.containsKey(type))
      .toList();
}

/// Get all sync types that require Cloud Sync entitlement.
List<SyncType> getEntitlementGatedTypes() {
  return syncTypeConfigs.entries
      .where((e) => e.value.requiresEntitlement)
      .map((e) => e.key)
      .toList();
}

/// Get all sync types that use the outbox pattern.
List<SyncType> getOutboxTypes() {
  return syncTypeConfigs.entries
      .where((e) => e.value.usesOutbox)
      .map((e) => e.key)
      .toList();
}
