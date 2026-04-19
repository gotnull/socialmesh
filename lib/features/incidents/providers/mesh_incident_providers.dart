// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for mesh incident reporting.
///
/// Provider dependency chain:
///   UI (mesh_incident_list_screen) -> meshIncidentCasesProvider
///     -> meshIncidentServiceProvider -> meshIncidentDatabaseProvider
///   UI (mesh_incident_composer_screen) -> meshIncidentActionsProvider
///     -> meshIncidentServiceProvider -> mrrpEngine -> protocolService
///   Inbound: protocolService -> mrrpEngine -> incidentServiceHandler
///     -> meshIncidentServiceProvider -> meshIncidentDatabaseProvider
///
/// All providers follow Riverpod 3.x patterns.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/protocol/sip/spp_types.dart';
import '../models/incident.dart';
import '../models/mesh_incident_report.dart';
import '../services/mesh_incident_database.dart';
import '../services/mesh_incident_service.dart';

// ---------------------------------------------------------------------------
// Database provider
// ---------------------------------------------------------------------------

/// Provides the [MeshIncidentDatabaseImpl] singleton.
///
/// Callers must call `open()` before querying.
final meshIncidentDatabaseProvider = Provider<MeshIncidentDatabaseImpl>((ref) {
  final db = MeshIncidentDatabaseImpl();
  ref.onDispose(() => db.close());
  return db;
});

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the [MeshIncidentService] singleton.
final meshIncidentServiceProvider = Provider<MeshIncidentService>((ref) {
  final db = ref.watch(meshIncidentDatabaseProvider);
  final service = MeshIncidentService(db: db);
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// Case list provider
// ---------------------------------------------------------------------------

/// Loads all active mesh incident cases.
///
/// Returns case projections derived from the report timeline. Each case
/// includes the effective status, latest report, and contributor nodes.
final meshIncidentCasesProvider = FutureProvider<List<MeshIncidentCaseState>>((
  ref,
) async {
  final db = ref.watch(meshIncidentDatabaseProvider);
  await db.open();

  final service = ref.watch(meshIncidentServiceProvider);
  await service.init();

  return service.getActiveCases();
});

/// Loads all mesh incident cases including resolved/closed.
final meshIncidentAllCasesProvider =
    FutureProvider<List<MeshIncidentCaseState>>((ref) async {
      final db = ref.watch(meshIncidentDatabaseProvider);
      await db.open();

      final reports = await db.getRecentReports(limit: 200);
      if (reports.isEmpty) return [];

      // Group by caseId and build case states
      final caseMap = <int, List<MeshIncidentReport>>{};
      for (final report in reports) {
        caseMap.putIfAbsent(report.caseId, () => []).add(report);
      }

      return caseMap.values
          .where((reports) => reports.isNotEmpty)
          .map(MeshIncidentCaseState.fromReports)
          .toList()
        ..sort(
          (a, b) =>
              b.latestReport.timestamp.compareTo(a.latestReport.timestamp),
        );
    });

// ---------------------------------------------------------------------------
// Case detail provider
// ---------------------------------------------------------------------------

/// Loads the full report timeline for a specific case.
final meshIncidentCaseDetailProvider =
    FutureProvider.family<List<MeshIncidentReport>, int>((ref, caseId) async {
      final db = ref.watch(meshIncidentDatabaseProvider);
      await db.open();
      return db.getReportsForCase(caseId);
    });

/// Derives the effective case state from the report timeline.
final meshIncidentCaseStateProvider =
    FutureProvider.family<MeshIncidentCaseState?, int>((ref, caseId) async {
      final reports = await ref.watch(
        meshIncidentCaseDetailProvider(caseId).future,
      );
      if (reports.isEmpty) return null;
      return MeshIncidentCaseState.fromReports(reports);
    });

// ---------------------------------------------------------------------------
// Stream provider for live updates
// ---------------------------------------------------------------------------

/// Stream of newly received mesh incident reports.
///
/// Use this for notifications and live UI updates.
final meshIncidentReportStreamProvider = StreamProvider<MeshIncidentReport>((
  ref,
) {
  final service = ref.watch(meshIncidentServiceProvider);
  return service.onReportReceived;
});

// ---------------------------------------------------------------------------
// Actions controller
// ---------------------------------------------------------------------------

/// Handles outbound mesh incident report actions.
///
/// Manages creating, updating, correcting, and closing mesh incident reports.
class MeshIncidentActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Creates and sends a new mesh incident report.
  Future<MeshIncidentReport?> createReport({
    required IncidentClassification classification,
    required IncidentPriority priority,
    required IncidentConfidence confidence,
    required IncidentReporterRole reporterRole,
    required String body,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(meshIncidentServiceProvider);
      final report = await service.sendReport(
        classification: classification,
        priority: priority,
        confidence: confidence,
        reporterRole: reporterRole,
        body: body,
        latitude: latitude,
        longitude: longitude,
      );

      _invalidateLists();
      state = const AsyncData(null);
      return report;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Sends an update to an existing case.
  Future<MeshIncidentReport?> sendUpdate({
    required int caseId,
    required IncidentClassification classification,
    required IncidentPriority priority,
    required IncidentConfidence confidence,
    required IncidentReporterRole reporterRole,
    required String body,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(meshIncidentServiceProvider);
      final report = await service.sendReport(
        existingCaseId: caseId,
        updateType: IncidentUpdateType.update,
        classification: classification,
        priority: priority,
        confidence: confidence,
        reporterRole: reporterRole,
        body: body,
        latitude: latitude,
        longitude: longitude,
      );

      _invalidateLists();
      state = const AsyncData(null);
      return report;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Sends a correction to a previous report in a case.
  Future<MeshIncidentReport?> sendCorrection({
    required int caseId,
    required int refSeq,
    required IncidentClassification classification,
    required IncidentPriority priority,
    required IncidentConfidence confidence,
    required IncidentReporterRole reporterRole,
    required String body,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(meshIncidentServiceProvider);
      final report = await service.sendReport(
        existingCaseId: caseId,
        updateType: IncidentUpdateType.correction,
        refSeq: refSeq,
        classification: classification,
        priority: priority,
        confidence: confidence,
        reporterRole: reporterRole,
        body: body,
        latitude: latitude,
        longitude: longitude,
      );

      _invalidateLists();
      state = const AsyncData(null);
      return report;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Closes a case.
  Future<MeshIncidentReport?> closeCase({
    required int caseId,
    required IncidentReporterRole reporterRole,
    required String body,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(meshIncidentServiceProvider);
      final report = await service.sendReport(
        existingCaseId: caseId,
        updateType: IncidentUpdateType.closure,
        classification: IncidentClassification.operational,
        priority: IncidentPriority.routine,
        confidence: IncidentConfidence.confirmed,
        reporterRole: reporterRole,
        body: body,
      );

      _invalidateLists();
      state = const AsyncData(null);
      return report;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  void _invalidateLists() {
    ref.invalidate(meshIncidentCasesProvider);
    ref.invalidate(meshIncidentAllCasesProvider);
  }
}

final meshIncidentActionsProvider =
    NotifierProvider<MeshIncidentActionsNotifier, AsyncValue<void>>(
      MeshIncidentActionsNotifier.new,
    );
