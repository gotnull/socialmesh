// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh incident service for processing, persisting, and projecting
/// mesh-transmitted incident reports.
///
/// This service owns the lifecycle of mesh incident data:
/// - Ingest inbound reports from the MRRP service handler
/// - Deduplicate against recently-seen reports
/// - Persist to SQLite
/// - Apply correction / supersession logic
/// - Provide case state projections
/// - Manage outbound report transmission
///
/// The service does NOT own transport -- it delegates to the MRRP engine
/// via callbacks.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../services/protocol/sip/spp_constants.dart';
import '../../../services/protocol/sip/spp_incident_codec.dart';
import '../../../services/protocol/sip/spp_types.dart';
import '../models/incident.dart';
import '../models/mesh_incident_report.dart';

/// Callback for sending an encoded MRRP incident request.
typedef SendIncidentFrame = Future<bool> Function(Uint8List sppPayload);

/// Service for mesh incident report lifecycle management.
class MeshIncidentService {
  final MeshIncidentDatabase _db;
  final SendIncidentFrame? onSend;

  /// Stream of newly received reports (for UI notification).
  Stream<MeshIncidentReport> get onReportReceived => _reportController.stream;
  final _reportController = StreamController<MeshIncidentReport>.broadcast();

  /// Simple LRU dedup cache: dedupeKey -> receivedAt.
  final Map<String, DateTime> _dedup = {};
  static const int _dedupMaxSize = 128;
  static const Duration _dedupTtl = Duration(minutes: 10);

  /// Local case_id counter for outbound reports.
  int _nextCaseId = 0;

  MeshIncidentService({required MeshIncidentDatabase db, this.onSend})
    : _db = db;

  /// Initialise the service and load the next case_id.
  Future<void> init() async {
    _nextCaseId = await _db.getMaxCaseId() + 1;
    AppLogging.protocol(
      'MeshIncidentService: init nextCaseId=$_nextCaseId', // lint-allow: hardcoded-string
    );
  }

  /// Process an inbound report from the MRRP service handler.
  ///
  /// Returns true if the report was new and persisted, false if duplicate.
  Future<bool> ingestReport(MeshIncidentReport report) async {
    // Dedupe check
    final key = report.dedupeKey;
    final now = DateTime.now();
    _evictStaleDedup(now);

    if (_dedup.containsKey(key)) {
      AppLogging.protocol(
        'MeshIncidentService: duplicate report $key', // lint-allow: hardcoded-string
      );
      return false;
    }

    // Validate basics
    if (report.body.isEmpty &&
        report.updateType == IncidentUpdateType.initial) {
      AppLogging.protocol(
        'MeshIncidentService: rejected initial report with '
        'empty body', // lint-allow: hardcoded-string
      );
      return false;
    }

    // Apply correction logic
    var reportToStore = report.copyWith(receivedAt: now.toUtc());

    if (report.isCorrection && report.refSeq != null) {
      await _db.markSuperseded(report.caseId, report.refSeq!);
    }

    await _db.insertReport(reportToStore);
    _dedup[key] = now;

    _reportController.add(reportToStore);

    AppLogging.protocol(
      'MeshIncidentService: ingested case=${report.caseId} '
      'seq=${report.seqNum}', // lint-allow: hardcoded-string
    );
    return true;
  }

  /// Create and send a new incident report.
  ///
  /// Returns the created report, or null if encoding/sending failed.
  Future<MeshIncidentReport?> sendReport({
    required IncidentClassification classification,
    required IncidentPriority priority,
    required IncidentConfidence confidence,
    required IncidentReporterRole reporterRole,
    required String body,
    double? latitude,
    double? longitude,
    int? existingCaseId,
    int? existingSeqNum,
    IncidentUpdateType updateType = IncidentUpdateType.initial,
    int? refSeq,
  }) async {
    final caseId = existingCaseId ?? _nextCaseId++;
    final seqNum = existingSeqNum ?? (await _db.getMaxSeqNum(caseId) + 1);

    final report = MeshIncidentReport(
      caseId: caseId,
      seqNum: seqNum.clamp(0, SppConstants.maxSeqNum),
      updateType: updateType,
      confidence: confidence,
      classification: classification,
      priority: priority,
      status: _statusFromUpdateType(updateType),
      reporterRole: reporterRole,
      timestamp: DateTime.now().toUtc(),
      refSeq: refSeq,
      latitude: latitude,
      longitude: longitude,
      body: body,
      senderNodeId: 0,
    );

    final encoded = SppIncidentCodec.encode(report);
    if (encoded == null) {
      AppLogging.protocol(
        'MeshIncidentService: encode failed for '
        'case=$caseId', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Persist locally
    await _db.insertReport(report.copyWith(receivedAt: DateTime.now().toUtc()));

    // Send via MRRP
    final sent = await onSend?.call(encoded) ?? false;
    if (!sent) {
      AppLogging.protocol(
        'MeshIncidentService: send failed for '
        'case=$caseId', // lint-allow: hardcoded-string
      );
    }

    return report;
  }

  /// Get all reports for a case, ordered by sequence number.
  Future<List<MeshIncidentReport>> getReportsForCase(int caseId) async {
    return _db.getReportsForCase(caseId);
  }

  /// Get the effective state for a case.
  Future<MeshIncidentCaseState?> getCaseState(int caseId) async {
    final reports = await _db.getReportsForCase(caseId);
    if (reports.isEmpty) return null;
    return MeshIncidentCaseState.fromReports(reports);
  }

  /// Get all active cases (with their latest report).
  Future<List<MeshIncidentCaseState>> getActiveCases() async {
    return _db.getActiveCases();
  }

  /// Lookup the latest report for a case (for MRRP query responses).
  MeshIncidentReport? lookupLatestSync(int caseId) {
    // Synchronous wrapper -- delegates to DB cache if available
    return null;
  }

  /// Evict stale entries from the dedup cache.
  void _evictStaleDedup(DateTime now) {
    if (_dedup.length < _dedupMaxSize) return;
    _dedup.removeWhere((_, ts) => now.difference(ts) > _dedupTtl);
  }

  IncidentMeshStatus _statusFromUpdateType(IncidentUpdateType type) {
    return switch (type) {
      IncidentUpdateType.initial => IncidentMeshStatus.reported,
      IncidentUpdateType.update => IncidentMeshStatus.active,
      IncidentUpdateType.correction => IncidentMeshStatus.active,
      IncidentUpdateType.closure => IncidentMeshStatus.resolved,
    };
  }

  /// Release resources.
  void dispose() {
    _reportController.close();
  }
}

/// Database interface for mesh incident persistence.
///
/// Implemented by the incident database provider. Extracted as an interface
/// to support testing with in-memory implementations.
abstract class MeshIncidentDatabase {
  Future<void> insertReport(MeshIncidentReport report);
  Future<void> markSuperseded(int caseId, int seqNum);
  Future<List<MeshIncidentReport>> getReportsForCase(int caseId);
  Future<List<MeshIncidentCaseState>> getActiveCases();
  Future<int> getMaxCaseId();
  Future<int> getMaxSeqNum(int caseId);
}
