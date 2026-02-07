// SPDX-License-Identifier: GPL-3.0-or-later

// Widget Sync Providers — Riverpod providers for widget Cloud Sync infrastructure.
//
// Provider hierarchy:
//
// widgetDatabaseProvider (Provider)
//   └── widgetSqliteStoreProvider (FutureProvider)
//         ├── widgetSyncServiceProvider (Provider) — enabled by entitlement
//         └── widgetStorageServiceProvider (FutureProvider) — initialized service
//
// The store is initialized once and shared across all providers.
// Screens should use [widgetStorageServiceProvider] instead of creating
// WidgetStorageService instances directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../providers/cloud_sync_entitlement_providers.dart';
import 'services/widget_database.dart';
import 'services/widget_sqlite_store.dart';
import 'services/widget_sync_service.dart';
import 'storage/widget_storage_service.dart';

// =============================================================================
// Storage Providers
// =============================================================================

/// Provides the Widget SQLite database instance.
final widgetDatabaseProvider = Provider<WidgetDatabase>((ref) {
  AppLogging.sync('[WidgetProviders] widgetDatabaseProvider CREATING');
  final db = WidgetDatabase();
  ref.onDispose(() {
    AppLogging.sync('[WidgetProviders] widgetDatabaseProvider DISPOSING');
    db.close();
  });
  return db;
});

/// Provides an initialized WidgetSqliteStore instance.
///
/// On initialization, sets the shared store on [WidgetStorageService]
/// so that all instances (including ad-hoc ones created in screens)
/// automatically delegate CRUD operations to SQLite with outbox support.
final widgetSqliteStoreProvider = FutureProvider<WidgetSqliteStore>((
  ref,
) async {
  AppLogging.sync('[WidgetProviders] widgetSqliteStoreProvider CREATING');
  final db = ref.watch(widgetDatabaseProvider);
  final store = WidgetSqliteStore(db);
  AppLogging.sync(
    '[WidgetProviders] WidgetSqliteStore created '
    '(hashCode=${identityHashCode(store)}), calling init()...',
  );
  await store.init();

  // Set the shared store so all WidgetStorageService instances
  // (including those created directly in screens) delegate to SQLite.
  WidgetStorageService.setSharedStore(store);
  AppLogging.widgets(
    '[WidgetSyncProviders] Shared SQLite store set on WidgetStorageService',
  );
  AppLogging.sync(
    '[WidgetProviders] Shared SQLite store SET on WidgetStorageService '
    '(store hashCode=${identityHashCode(store)}, '
    'syncEnabled=${store.syncEnabled}, '
    'count=${store.count})',
  );

  return store;
});

/// Provides the Widget Cloud Sync service.
///
/// Enabled/disabled based on the user's Cloud Sync entitlement.
/// Wires up onPullApplied to trigger UI refresh when remote
/// widget schemas arrive.
final widgetSyncServiceProvider = Provider<WidgetSyncService?>((ref) {
  AppLogging.sync('[WidgetProviders] widgetSyncServiceProvider CREATING');

  final storeAsync = ref.watch(widgetSqliteStoreProvider);
  final store = storeAsync.asData?.value;

  if (store == null) {
    final stateDesc = storeAsync.isLoading
        ? 'LOADING'
        : storeAsync.hasError
        ? 'ERROR: ${storeAsync.error}'
        : 'NULL';
    AppLogging.sync(
      '[WidgetProviders] widgetSyncServiceProvider: store is NULL '
      '(state=$stateDesc) — returning null, sync DISABLED',
    );
    return null;
  }

  AppLogging.sync(
    '[WidgetProviders] widgetSyncServiceProvider: store AVAILABLE '
    '(hashCode=${identityHashCode(store)}, '
    'syncEnabled=${store.syncEnabled}, '
    'count=${store.count})',
  );

  final syncService = WidgetSyncService(store);
  AppLogging.sync(
    '[WidgetProviders] WidgetSyncService created '
    '(hashCode=${identityHashCode(syncService)})',
  );

  // Watch cloud sync entitlement to enable/disable.
  final canWrite = ref.watch(canCloudSyncWriteProvider);
  AppLogging.sync(
    '[WidgetProviders] canCloudSyncWriteProvider = $canWrite '
    '— calling setEnabled($canWrite)',
  );
  syncService.setEnabled(canWrite);

  ref.onDispose(() async {
    AppLogging.sync(
      '[WidgetProviders] widgetSyncServiceProvider DISPOSING '
      '(service hashCode=${identityHashCode(syncService)})',
    );
    await syncService.dispose();
  });

  return syncService;
});

// =============================================================================
// Widget Storage Service Provider
// =============================================================================

/// Provides an initialized [WidgetStorageService] instance.
///
/// This is the canonical way to obtain a WidgetStorageService. Screens
/// should use this provider instead of creating instances directly:
///
/// ```dart
/// final storageAsync = ref.watch(widgetStorageServiceProvider);
/// final storage = storageAsync.asData?.value;
/// ```
///
/// The service is automatically wired to the SQLite store (when ready)
/// and has SharedPreferences initialized for marketplace tracking.
///
/// Replaces the previous pattern of:
/// ```dart
/// final storage = WidgetStorageService();
/// await storage.init();
/// ```
final widgetStorageServiceProvider = FutureProvider<WidgetStorageService>((
  ref,
) async {
  AppLogging.sync('[WidgetProviders] widgetStorageServiceProvider CREATING');

  // Ensure the SQLite store is initialized first so that
  // WidgetStorageService.setSharedStore() has been called before
  // the service's init() runs the migration check.
  try {
    AppLogging.sync(
      '[WidgetProviders] Awaiting widgetSqliteStoreProvider.future...',
    );
    await ref.watch(widgetSqliteStoreProvider.future);
    AppLogging.sync(
      '[WidgetProviders] widgetSqliteStoreProvider.future resolved OK '
      '(hasStore=${WidgetStorageService.hasStore})',
    );
  } catch (e) {
    // SQLite store may not be available (e.g. during tests).
    // WidgetStorageService will fall back to SharedPreferences.
    AppLogging.sync(
      '[WidgetProviders] widgetSqliteStoreProvider.future FAILED: $e '
      '— falling back to SharedPreferences',
    );
  }

  final service = WidgetStorageService();
  AppLogging.sync(
    '[WidgetProviders] WidgetStorageService created, calling init()...',
  );
  await service.init();

  AppLogging.widgets(
    '[WidgetSyncProviders] WidgetStorageService initialized via provider '
    '(hasStore=${WidgetStorageService.hasStore})',
  );
  AppLogging.sync(
    '[WidgetProviders] WidgetStorageService initialized '
    '(hasStore=${WidgetStorageService.hasStore})',
  );

  return service;
});
