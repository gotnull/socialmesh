// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../features/automations/automation_providers.dart';
import '../features/nodedex/providers/nodedex_providers.dart';
import '../features/tak/providers/tak_providers.dart';
import '../features/widget_builder/widget_sync_providers.dart';
import '../providers/app_providers.dart';
import '../providers/signal_providers.dart';
import '../providers/telemetry_providers.dart';

/// Close every open SQLite database connection held by Riverpod providers.
///
/// Accepts a [WidgetRef] from the calling widget. Use this before deleting
/// database files from disk. Deleting a `.db` file while SQLite still holds
/// an open file descriptor causes "vnode unlinked while in use" integrity
/// errors on iOS and "disk I/O error" failures on subsequent writes.
///
/// Each close is wrapped in its own try/catch so a failure on one database
/// does not prevent the others from being closed.
Future<void> closeAllDatabases(WidgetRef ref) async {
  AppLogging.auth('closeAllDatabases: closing all open SQLite connections');

  // messages.db
  try {
    final messageDb = await ref.read(messageStorageProvider.future);
    await messageDb.close();
    AppLogging.auth('closeAllDatabases: messages.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: messages.db close error: $e');
  }

  // signals.db
  try {
    final signalService = ref.read(signalServiceProvider);
    await signalService.close();
    AppLogging.auth('closeAllDatabases: signals.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: signals.db close error: $e');
  }

  // telemetry.db
  try {
    final telemetryDb = await ref.read(telemetryStorageProvider.future);
    await telemetryDb.close();
    AppLogging.auth('closeAllDatabases: telemetry.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: telemetry.db close error: $e');
  }

  // routes.db
  try {
    final routeStorage = await ref.read(routeStorageProvider.future);
    await routeStorage.close();
    AppLogging.auth('closeAllDatabases: routes.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: routes.db close error: $e');
  }

  // nodedex.db
  try {
    final nodeDexDb = ref.read(nodeDexDatabaseProvider);
    await nodeDexDb.close();
    AppLogging.auth('closeAllDatabases: nodedex.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: nodedex.db close error: $e');
  }

  // traceroute_history.db
  try {
    final tracerouteRepo = await ref.read(tracerouteRepositoryProvider.future);
    await tracerouteRepo.close();
    AppLogging.auth('closeAllDatabases: traceroute_history.db closed');
  } catch (e) {
    AppLogging.debug(
      'closeAllDatabases: traceroute_history.db close error: $e',
    );
  }

  // automations.db
  try {
    final automationDb = ref.read(automationDatabaseProvider);
    await automationDb.close();
    AppLogging.auth('closeAllDatabases: automations.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: automations.db close error: $e');
  }

  // widgets.db
  try {
    final widgetDb = ref.read(widgetDatabaseProvider);
    await widgetDb.close();
    AppLogging.auth('closeAllDatabases: widgets.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: widgets.db close error: $e');
  }

  // tak_events.db
  try {
    final takDb = ref.read(takDatabaseProvider);
    await takDb.close();
    AppLogging.auth('closeAllDatabases: tak_events.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: tak_events.db close error: $e');
  }

  // cache/mesh_seen_packets.db
  try {
    final dedupeStore = ref.read(meshPacketDedupeStoreProvider);
    await dedupeStore.dispose();
    AppLogging.auth('closeAllDatabases: mesh_seen_packets.db closed');
  } catch (e) {
    AppLogging.debug('closeAllDatabases: mesh_seen_packets.db close error: $e');
  }

  AppLogging.auth('closeAllDatabases: all database connections closed');

  // NOTE: Provider invalidation is deliberately NOT done here.
  // Invalidating triggers dependent providers (e.g. TelemetryLoggerNotifier)
  // to rebuild immediately — which re-opens the same database files that
  // LocalDataWipeService is about to delete. That causes "vnode unlinked
  // while in use" integrity errors and a "disk I/O error" (6922) storm.
  //
  // Call invalidateAllDatabaseProviders() AFTER files are deleted.
}

/// Invalidate every database provider so Riverpod creates fresh instances
/// on next access.
///
/// Call this AFTER database files have been deleted from disk. Calling it
/// before deletion triggers dependent provider rebuilds that re-open the
/// same files — which then get unlinked while in use.
void invalidateAllDatabaseProviders(WidgetRef ref) {
  ref.invalidate(messageStorageProvider);
  ref.invalidate(signalServiceProvider);
  ref.invalidate(telemetryStorageProvider);
  ref.invalidate(routeStorageProvider);
  ref.invalidate(nodeDexDatabaseProvider);
  ref.invalidate(tracerouteRepositoryProvider);
  ref.invalidate(automationDatabaseProvider);
  ref.invalidate(widgetDatabaseProvider);
  ref.invalidate(takDatabaseProvider);
  ref.invalidate(meshPacketDedupeStoreProvider);
  AppLogging.auth(
    'invalidateAllDatabaseProviders: all database providers invalidated',
  );
}
