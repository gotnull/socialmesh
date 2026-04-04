// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/services/protocol/sip/spp_constants.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  group('MeshIncidentReport', () {
    MeshIncidentReport makeReport({
      int caseId = 1,
      int seqNum = 0,
      IncidentUpdateType updateType = IncidentUpdateType.initial,
      IncidentConfidence confidence = IncidentConfidence.unconfirmed,
      IncidentClassification classification =
          IncidentClassification.operational,
      IncidentPriority priority = IncidentPriority.routine,
      IncidentMeshStatus status = IncidentMeshStatus.reported,
      IncidentReporterRole reporterRole = IncidentReporterRole.observer,
      DateTime? timestamp,
      int refSeq = SppConstants.noRefSeq,
      double? latitude,
      double? longitude,
      String body = 'Test report',
      int senderNodeId = 42,
      bool isSuperseded = false,
    }) {
      return MeshIncidentReport(
        caseId: caseId,
        seqNum: seqNum,
        updateType: updateType,
        confidence: confidence,
        classification: classification,
        priority: priority,
        status: status,
        reporterRole: reporterRole,
        timestamp: timestamp ?? DateTime.utc(2025, 6, 15),
        refSeq: refSeq,
        latitude: latitude,
        longitude: longitude,
        body: body,
        senderNodeId: senderNodeId,
        isSuperseded: isSuperseded,
      );
    }

    test('creates with required fields', () {
      final report = makeReport();
      expect(report.caseId, 1);
      expect(report.seqNum, 0);
      expect(report.updateType, IncidentUpdateType.initial);
      expect(report.body, 'Test report');
      expect(report.senderNodeId, 42);
    });

    test('hasLocation returns true when lat/lon present', () {
      final noLoc = makeReport();
      expect(noLoc.hasLocation, isFalse);

      final withLoc = makeReport(latitude: 1.0, longitude: 2.0);
      expect(withLoc.hasLocation, isTrue);
    });

    test('dedupeKey format', () {
      final report = makeReport(caseId: 10, seqNum: 3, senderNodeId: 99);
      expect(report.dedupeKey, '10:3:99');
    });

    test('copyWith preserves unmodified fields', () {
      final original = makeReport(caseId: 5, seqNum: 2, body: 'Original');
      final copy = original.copyWith(isSuperseded: true);

      expect(copy.caseId, original.caseId);
      expect(copy.seqNum, original.seqNum);
      expect(copy.body, original.body);
      expect(copy.isSuperseded, isTrue);
      expect(original.isSuperseded, isFalse);
    });

    test('toMap/fromMap round-trip', () {
      final original = makeReport(
        caseId: 0xBEEF,
        seqNum: 7,
        updateType: IncidentUpdateType.correction,
        confidence: IncidentConfidence.confirmed,
        classification: IncidentClassification.medical,
        priority: IncidentPriority.flash,
        status: IncidentMeshStatus.active,
        reporterRole: IncidentReporterRole.supervisor,
        refSeq: 5,
        latitude: -33.87,
        longitude: 151.21,
        body: 'Round-trip body',
        senderNodeId: 100,
        isSuperseded: true,
      );

      final map = original.toMap();
      final restored = MeshIncidentReport.fromMap(map);

      expect(restored.caseId, original.caseId);
      expect(restored.seqNum, original.seqNum);
      expect(restored.updateType, original.updateType);
      expect(restored.confidence, original.confidence);
      expect(restored.classification, original.classification);
      expect(restored.priority, original.priority);
      expect(restored.status, original.status);
      expect(restored.reporterRole, original.reporterRole);
      expect(restored.refSeq, original.refSeq);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.body, original.body);
      expect(restored.senderNodeId, original.senderNodeId);
      expect(restored.isSuperseded, original.isSuperseded);
    });

    test('toMap sets receivedAt', () {
      final r = makeReport();
      final map = r.toMap();
      expect(map.containsKey('receivedAt'), isTrue);
      // receivedAt is null by default (set on ingest, not on construction)
      expect(map['receivedAt'], isNull);
    });
  });

  group('MeshIncidentCaseState', () {
    MeshIncidentReport report({
      int seqNum = 0,
      IncidentUpdateType updateType = IncidentUpdateType.initial,
      IncidentMeshStatus status = IncidentMeshStatus.reported,
      IncidentPriority priority = IncidentPriority.routine,
      IncidentConfidence confidence = IncidentConfidence.unconfirmed,
      IncidentClassification classification =
          IncidentClassification.operational,
      int senderNodeId = 1,
      bool isSuperseded = false,
      int refSeq = SppConstants.noRefSeq,
    }) {
      return MeshIncidentReport(
        caseId: 100,
        seqNum: seqNum,
        updateType: updateType,
        confidence: confidence,
        classification: classification,
        priority: priority,
        status: status,
        reporterRole: IncidentReporterRole.observer,
        timestamp: DateTime.utc(2025, 6, 15).add(Duration(minutes: seqNum)),
        refSeq: refSeq,
        body: 'Report $seqNum',
        senderNodeId: senderNodeId,
        isSuperseded: isSuperseded,
      );
    }

    test('creates from single initial report', () {
      final reports = [report()];
      final state = MeshIncidentCaseState.fromReports(reports);

      expect(state.caseId, 100);
      expect(state.reportCount, 1);
      expect(state.effectiveStatus, IncidentMeshStatus.reported);
      expect(state.effectivePriority, IncidentPriority.routine);
      expect(state.hasCorrections, isFalse);
      expect(state.contributorNodes, {1});
    });

    test('takes effective state from latest non-superseded report', () {
      final reports = [
        report(seqNum: 0, status: IncidentMeshStatus.reported),
        report(
          seqNum: 1,
          updateType: IncidentUpdateType.update,
          status: IncidentMeshStatus.active,
          priority: IncidentPriority.immediate,
          senderNodeId: 2,
        ),
      ];
      final state = MeshIncidentCaseState.fromReports(reports);

      expect(state.effectiveStatus, IncidentMeshStatus.active);
      expect(state.effectivePriority, IncidentPriority.immediate);
      expect(state.reportCount, 2);
      expect(state.contributorNodes, {1, 2});
    });

    test('skips superseded reports for effective state', () {
      final reports = [
        report(
          seqNum: 0,
          status: IncidentMeshStatus.reported,
          priority: IncidentPriority.flash,
        ),
        report(
          seqNum: 1,
          updateType: IncidentUpdateType.correction,
          status: IncidentMeshStatus.active,
          priority: IncidentPriority.routine,
          refSeq: 0,
          isSuperseded: true, // This was superseded
        ),
        report(
          seqNum: 2,
          updateType: IncidentUpdateType.update,
          status: IncidentMeshStatus.contained,
          priority: IncidentPriority.priority,
        ),
      ];
      final state = MeshIncidentCaseState.fromReports(reports);

      // Effective state should be from seq 2 (latest non-superseded)
      expect(state.effectiveStatus, IncidentMeshStatus.contained);
      expect(state.effectivePriority, IncidentPriority.priority);
      expect(state.hasCorrections, isTrue);
    });

    test('identifies multiple contributors', () {
      final reports = [
        report(seqNum: 0, senderNodeId: 10),
        report(seqNum: 1, senderNodeId: 20),
        report(seqNum: 2, senderNodeId: 10),
        report(seqNum: 3, senderNodeId: 30),
      ];
      final state = MeshIncidentCaseState.fromReports(reports);
      expect(state.contributorNodes, {10, 20, 30});
    });

    test('latestReport is the highest seq_num non-superseded', () {
      final reports = [
        report(seqNum: 0),
        report(seqNum: 1),
        report(seqNum: 2, isSuperseded: true),
        report(seqNum: 3),
      ];
      final state = MeshIncidentCaseState.fromReports(reports);
      expect(state.latestReport.seqNum, 3);
    });
  });

  group('SppPayloadType', () {
    test('incidentReport has correct typeId', () {
      expect(SppPayloadType.incidentReport.code, 0x10);
    });

    test('incidentQuery has correct typeId', () {
      expect(SppPayloadType.incidentQuery.code, 0x11);
    });

    test('incidentState has correct typeId', () {
      expect(SppPayloadType.incidentState.code, 0x12);
    });
  });

  group('IncidentUpdateType', () {
    test('has 4 values', () {
      expect(IncidentUpdateType.values.length, 4);
    });

    test('values are in correct order', () {
      expect(IncidentUpdateType.initial.index, 0);
      expect(IncidentUpdateType.update.index, 1);
      expect(IncidentUpdateType.correction.index, 2);
      expect(IncidentUpdateType.closure.index, 3);
    });
  });

  group('IncidentMeshStatus', () {
    test('has 5 values', () {
      expect(IncidentMeshStatus.values.length, 5);
    });
  });

  group('SppConstants', () {
    test('total overhead is 44 bytes', () {
      expect(SppConstants.totalOverhead, 44);
    });

    test('net usable body is 193 bytes', () {
      expect(SppConstants.maxBody, 193);
    });

    test('max body with location is less than without', () {
      expect(
        SppConstants.incidentMaxBodyWithLoc,
        lessThan(SppConstants.incidentMaxBodyNoLoc),
      );
    });

    test('header sizes are consistent', () {
      expect(
        SppConstants.incidentHeaderWithLoc,
        SppConstants.incidentHeaderNoLoc + 4,
      );
    });

    test('no-ref sentinel is 0xFF', () {
      expect(SppConstants.noRefSeq, 0xFF);
    });
  });
}
