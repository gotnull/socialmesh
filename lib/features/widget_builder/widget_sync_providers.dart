// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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
import '../dashboard/widgets/schema_widget_content.dart'
    show widgetRefreshTriggerProvider;
import 'models/widget_schema.dart';
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
        ? 'ERROR: ${storeAsync.error}' // lint-allow: hardcoded-string
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
/// and has SharedPreferences initialized.
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

// =============================================================================
// Widget Builder Screen List Provider
// =============================================================================

/// AsyncNotifier that owns the widget builder screen's list state.
///
/// Previously the screen carried local `_myWidgets`, `_isLoading`, and
/// `_lastRefreshTrigger` fields, with a fire-and-forget `_loadWidgets()`
/// running from `initState` AND from a post-frame trigger watcher. Sync
/// arrivals re-entered `_loadWidgets()` and reset `_isLoading = true`,
/// flashing the spinner / empty state over a populated list. This notifier
/// replaces that pattern: the screen watches the notifier, and sync pull
/// arrivals update state in-place without flipping to loading.
class WidgetBuilderListNotifier extends AsyncNotifier<List<WidgetSchema>> {
  int _emitCount = 0;

  void _emit(AsyncValue<List<WidgetSchema>> next, String reason) {
    _emitCount++;
    final desc = next.when(
      data: (data) => 'data(widgets=${data.length})',
      loading: () => 'loading',
      error: (e, _) => 'error($e)',
    );
    AppLogging.widgets('#$_emitCount emit -> $desc via $reason');
    state = next;
  }

  @override
  Future<List<WidgetSchema>> build() async {
    AppLogging.widgets(
      'build() entered (notifier id=${identityHashCode(this)})',
    );
    // Sync pull callback refreshes in-place — no flip to loading, so the UI
    // does not blink to Quick Start templates while the new data arrives.
    ref.listen<WidgetSyncService?>(widgetSyncServiceProvider, (prev, next) {
      AppLogging.widgets(
        'syncService listen fired '
        '(prev=${prev != null}, next=${next != null})',
      );
      next?.onPullApplied = (appliedCount) {
        if (!ref.mounted) return;
        AppLogging.widgets('onPullApplied(applied=$appliedCount) -> refresh()');
        refresh();
      };
    }, fireImmediately: true);

    // Manual triggers from share imports / etc.
    ref.listen<int>(widgetRefreshTriggerProvider, (prev, next) {
      if (prev == null || next == prev) return;
      AppLogging.widgets(
        'widgetRefreshTriggerProvider bumped '
        '($prev -> $next) -> refresh()',
      );
      refresh();
    });

    final result = await _load();
    AppLogging.widgets(
      'build() initial _load() complete (widgets=${result.length})',
    );
    return result;
  }

  Future<List<WidgetSchema>> _load() async {
    AppLogging.widgets('_load() awaiting widgetStorageServiceProvider');
    final storageService = await ref.read(widgetStorageServiceProvider.future);
    final widgets = await storageService.getWidgets();
    AppLogging.widgets('_load() storage returned widgets=${widgets.length}');
    return widgets;
  }

  /// Reload from storage, keeping previous data visible while the new data
  /// loads (no AsyncValue.loading flip).
  Future<void> refresh() async {
    AppLogging.widgets('refresh() start');
    try {
      final next = await _load();
      if (!ref.mounted) return;
      _emit(AsyncValue.data(next), 'refresh()');
    } catch (e, st) {
      if (!ref.mounted) return;
      _emit(AsyncValue.error(e, st), 'refresh() error');
    }
  }

  /// Optimistically drop a widget from the in-memory state so the UI
  /// updates before the storage delete completes. The next refresh()
  /// (or sync pull) reconciles authoritatively.
  void removeWidgetLocally(String schemaId) {
    final current = state.asData?.value;
    if (current == null) return;
    final newWidgets = current.where((w) => w.id != schemaId).toList();
    _emit(AsyncValue.data(newWidgets), 'removeWidgetLocally($schemaId)');
  }
}

final widgetBuilderListProvider =
    AsyncNotifierProvider<WidgetBuilderListNotifier, List<WidgetSchema>>(
      WidgetBuilderListNotifier.new,
    );
