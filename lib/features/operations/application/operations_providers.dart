// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Operations Riverpod 3.x wiring.
//
// Provider graph:
//   operationsEnabledProvider          (Provider<bool>)
//   operationsCatalogProvider          (Provider<List<OperationDefinition>>)
//   operationsDatabaseProvider         (Provider<OperationsDatabase>)
//   operationsRepositoryProvider       (FutureProvider<OperationsRepository>)
//   operationsTracerouteEventProvider  (StreamProvider<TraceRouteLog>)
//   operationsProvider                 (AsyncNotifierProvider<OperationsNotifier, OperationsState>)
//     -> operationsActiveListProvider     (Provider<List<OperationViewModel>>)
//     -> operationsCompletedListProvider  (Provider<List<OperationViewModel>>)
//     -> operationByIdProvider.family     (Provider.family<OperationViewModel?, String>)
//
// Wiring rules: providers delegate to the repository + engine. No SQL,
// no transport calls, no business logic. Operations never sends RF
// traffic.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../models/telemetry_log.dart';
import '../../../providers/app_providers.dart';
import '../../nodedex/models/nodedex_entry.dart';
import '../../nodedex/providers/nodedex_providers.dart';
import '../data/operations_database.dart';
import '../data/operations_repository.dart';
import '../domain/operation_catalog.dart';
import '../domain/operations_progress_engine.dart';
import '../models/operation_event.dart';
import '../models/operation_models.dart';

// ============================================================================
// State + ViewModel
// ============================================================================

/// Top-level operations state held by [OperationsNotifier].
class OperationsState {
  /// Whether the feature is enabled at runtime. False = empty catalog,
  /// no listeners, UI shows the disabled state.
  final bool enabled;

  /// All operations from the catalog. The UI filters this down.
  final List<OperationDefinition> catalog;

  /// Persisted progress keyed by operationId. Operations never touched
  /// have no entry; the UI treats absence as `notStarted`.
  final Map<String, OperationProgress> progress;

  const OperationsState({
    required this.enabled,
    required this.catalog,
    required this.progress,
  });

  factory OperationsState.disabled() {
    return const OperationsState(enabled: false, catalog: [], progress: {});
  }

  OperationsState copyWith({
    bool? enabled,
    List<OperationDefinition>? catalog,
    Map<String, OperationProgress>? progress,
  }) {
    return OperationsState(
      enabled: enabled ?? this.enabled,
      catalog: catalog ?? this.catalog,
      progress: progress ?? this.progress,
    );
  }

  OperationProgress progressOrEmpty(
    OperationDefinition def, {
    required DateTime now,
  }) {
    final existing = progress[def.id];
    if (existing == null) return OperationProgress.empty(def, now: now);
    if (existing.version != def.version) {
      // Persisted progress predates the current definition shape — start
      // fresh. The engine will refuse to advance a mismatched version, so
      // returning a fresh empty record here lets recovery happen on the
      // next event without losing future progress.
      return OperationProgress.empty(def, now: now);
    }
    return existing;
  }
}

/// UI-friendly bundle of definition + progress + lifecycle state.
class OperationViewModel {
  final OperationDefinition definition;
  final OperationProgress progress;
  final OperationCompletionState state;
  final double overallFraction;

  const OperationViewModel({
    required this.definition,
    required this.progress,
    required this.state,
    required this.overallFraction,
  });
}

// ============================================================================
// Foundational providers
// ============================================================================

/// Whether the Operations surface is enabled. Mirrors `AppFeatureFlags`
/// but lives here so tests can override the gate independently.
final operationsEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isOperationsEnabled;
});

/// Static catalog provider. Tests can override to inject a fixed catalog.
final operationsCatalogProvider = Provider<List<OperationDefinition>>((ref) {
  return buildOperationCatalog();
});

/// Owns the OperationsDatabase lifecycle.
final operationsDatabaseProvider = Provider<OperationsDatabase>((ref) {
  final db = OperationsDatabase();
  ref.onDispose(() {
    unawaited(db.close());
  });
  return db;
});

/// Repository wraps the database. FutureProvider so dependents can
/// `ref.watch(...future)` and await initial open.
final operationsRepositoryProvider = FutureProvider<OperationsRepository>((
  ref,
) async {
  final db = ref.watch(operationsDatabaseProvider);
  final repo = OperationsRepository(db);
  // Touch the database to force open + schema creation up front.
  await db.database;
  return repo;
});

/// Successful traceroute completions wrapped as a stream provider so the
/// notifier can `ref.listen` rather than subscribe imperatively. Filters
/// to `response == true` (completed). Failures and pending placeholders
/// are dropped.
final operationsTracerouteEventProvider = StreamProvider<TraceRouteLog>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  return protocol.traceRouteLogStream.where((run) => run.response == true);
});

// ============================================================================
// Notifier
// ============================================================================

class OperationsNotifier extends AsyncNotifier<OperationsState> {
  @override
  Future<OperationsState> build() async {
    if (!ref.watch(operationsEnabledProvider)) {
      AppLogging.operations('OPERATIONS_DISABLED feature flag off');
      return OperationsState.disabled();
    }

    final repo = await ref.watch(operationsRepositoryProvider.future);
    final catalog = ref.watch(operationsCatalogProvider);
    final persisted = await repo.loadAll();

    AppLogging.operations(
      'OPERATIONS_INIT catalog_size=${catalog.length} '
      'persisted_count=${persisted.length}',
    );

    // NodeDex ingestion. `fireImmediately: true` so the very first build
    // counts any nodes the user has already encountered before the
    // notifier was constructed (idempotent — engine dedupe blocks repeat
    // counting on subsequent rebuilds).
    ref.listen<Map<int, NodeDexEntry>>(nodeDexProvider, (prev, next) {
      _ingestNodeDex(next);
    }, fireImmediately: true);

    // Traceroute ingestion. We deliberately do NOT seed from the
    // repository on init — Operations should only credit traceroutes the
    // user runs while the feature is active, not retroactively count
    // history that predated enrollment.
    ref.listen(operationsTracerouteEventProvider, (prev, next) {
      next.whenData(_ingestTraceroute);
    });

    return OperationsState(
      enabled: true,
      catalog: catalog,
      progress: persisted,
    );
  }

  // --------------------------------------------------------------------------
  // Public mutation API (UI / tests)
  // --------------------------------------------------------------------------

  /// Mark a completed operation as having had its reward acknowledged.
  /// v1 has no server-side claim flow; this just stamps `claimedAt`.
  Future<void> markRewardClaimed(String operationId) async {
    final current = state.value;
    if (current == null || !current.enabled) return;
    final existing = current.progress[operationId];
    if (existing == null || existing.completedAt == null) return;
    if (existing.claimedAt != null) return;

    final now = clock.now();
    final updated = existing.copyWith(claimedAt: now, updatedAt: now);
    await _persist(updated);

    final nextProgress = Map<String, OperationProgress>.from(current.progress)
      ..[operationId] = updated;
    state = AsyncData(current.copyWith(progress: nextProgress));
  }

  /// Apply a single event. Public so the event router (and tests) can
  /// inject events without going through NodeDex / traceroute streams.
  Future<void> ingest(OperationsEvent event) async {
    final current = state.value;
    if (current == null || !current.enabled) return;
    final now = clock.now();

    AppLogging.operations(
      'OPERATIONS_EVENT_INGEST kind=${event.runtimeType} '
      'dedupe=${event.dedupeKey}',
    );

    Map<String, OperationProgress>? nextProgress;

    for (final def in current.catalog) {
      if (!def.enabled) continue;
      if (!def.isActiveAt(event.occurredAt)) continue;
      final progress = current.progressOrEmpty(def, now: now);

      final result = OperationsProgressEngine.apply(
        definition: def,
        current: progress,
        event: event,
        now: now,
      );

      if (!result.didAdvance) {
        if (result.skipReason == OperationsEngineSkipReason.dedupeKeyKnown) {
          AppLogging.operations(
            'OPERATIONS_DEDUPE_SKIPPED op=${def.id} '
            'dedupe=${event.dedupeKey}',
          );
        }
        continue;
      }

      AppLogging.operations(
        'OPERATIONS_PROGRESS_UPDATED op=${def.id} '
        'deltas=${result.deltas} '
        'overall=${result.progress.overallFractionFor(def).toStringAsFixed(2)}',
      );

      for (final entry in result.deltas.entries) {
        if (result.progress.objectiveProgress[entry.key] ==
            def.objectives.firstWhere((o) => o.id == entry.key).target) {
          AppLogging.operations(
            'OPERATIONS_OBJECTIVE_COMPLETED op=${def.id} '
            'objective=${entry.key}',
          );
        }
      }

      if (result.didCompleteNow) {
        AppLogging.operations('OPERATIONS_COMPLETED op=${def.id}');
      }

      await _persist(result.progress);
      await _appendEventLog(def.id, event, result.deltas);

      nextProgress ??= Map<String, OperationProgress>.from(current.progress);
      nextProgress[def.id] = result.progress;
    }

    if (nextProgress != null) {
      state = AsyncData(current.copyWith(progress: nextProgress));
    }
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  Future<void> _ingestNodeDex(Map<int, NodeDexEntry> entries) async {
    final myNum = ref.read(myNodeNumProvider);
    for (final entry in entries.entries) {
      final nodeNum = entry.key;
      if (myNum != null && nodeNum == myNum) continue;
      // encounterCount > 0 means the upstream NodeIngestSource gate
      // already classified at least one observation as `livePacket`.
      // Sync replays from a reconnected device's NodeDB never bump this
      // counter, so we inherit reconnect-inflation safety for free.
      if (entry.value.encounterCount <= 0) continue;
      await ingest(
        OperationNodeEncountered(
          nodeNum: nodeNum,
          occurredAt: entry.value.lastSeen,
        ),
      );
    }
  }

  Future<void> _ingestTraceroute(TraceRouteLog run) async {
    if (run.response != true) return;
    await ingest(
      OperationTracerouteCompleted(
        runId: run.id,
        targetNodeId: run.targetNode,
        hopCount: run.hops.length,
        occurredAt: run.timestamp,
      ),
    );
  }

  Future<void> _persist(OperationProgress progress) async {
    try {
      final repo = await ref.read(operationsRepositoryProvider.future);
      await repo.saveProgress(progress);
    } catch (e) {
      AppLogging.operations(
        'OPERATIONS_PERSIST_FAILED save id=${progress.operationId} error=$e',
      );
    }
  }

  Future<void> _appendEventLog(
    String operationId,
    OperationsEvent event,
    Map<String, int> deltas,
  ) async {
    try {
      final repo = await ref.read(operationsRepositoryProvider.future);
      for (final entry in deltas.entries) {
        await repo.appendEvent(
          operationId: operationId,
          eventType: event.runtimeType.toString(),
          dedupeKey: event.dedupeKey,
          delta: entry.value,
          occurredAt: event.occurredAt,
          objectiveId: entry.key,
        );
      }
    } catch (_) {
      // Event log is observability-only. Errors already logged inside
      // appendEvent.
    }
  }
}

final operationsProvider =
    AsyncNotifierProvider<OperationsNotifier, OperationsState>(
      OperationsNotifier.new,
    );

// ============================================================================
// Derived UI providers
// ============================================================================

/// View-models for operations the UI should show as active.
final operationsActiveListProvider = Provider<List<OperationViewModel>>((ref) {
  final stateAsync = ref.watch(operationsProvider);
  final state = stateAsync.value;
  if (state == null || !state.enabled) return const [];
  final now = clock.now();
  final out = <OperationViewModel>[];
  for (final def in state.catalog) {
    if (!def.enabled) continue;
    if (!def.isActiveAt(now)) continue;
    final progress = state.progressOrEmpty(def, now: now);
    if (progress.completedAt != null) continue;
    out.add(_viewModel(def, progress));
  }
  return out;
});

/// View-models for operations the UI should show as completed.
final operationsCompletedListProvider = Provider<List<OperationViewModel>>((
  ref,
) {
  final stateAsync = ref.watch(operationsProvider);
  final state = stateAsync.value;
  if (state == null || !state.enabled) return const [];
  final now = clock.now();
  final out = <OperationViewModel>[];
  for (final def in state.catalog) {
    if (!def.enabled) continue;
    final progress = state.progressOrEmpty(def, now: now);
    if (progress.completedAt == null) continue;
    out.add(_viewModel(def, progress));
  }
  // Newest completion first.
  out.sort((a, b) {
    final ax = a.progress.completedAt!.millisecondsSinceEpoch;
    final bx = b.progress.completedAt!.millisecondsSinceEpoch;
    return bx.compareTo(ax);
  });
  return out;
});

final operationByIdProvider = Provider.family<OperationViewModel?, String>((
  ref,
  id,
) {
  final stateAsync = ref.watch(operationsProvider);
  final state = stateAsync.value;
  if (state == null || !state.enabled) return null;
  final now = clock.now();
  for (final def in state.catalog) {
    if (def.id != id) continue;
    if (!def.enabled) return null;
    final progress = state.progressOrEmpty(def, now: now);
    return _viewModel(def, progress);
  }
  return null;
});

OperationViewModel _viewModel(
  OperationDefinition def,
  OperationProgress progress,
) {
  return OperationViewModel(
    definition: def,
    progress: progress,
    state: progress.stateFor(def),
    overallFraction: progress.overallFractionFor(def),
  );
}
