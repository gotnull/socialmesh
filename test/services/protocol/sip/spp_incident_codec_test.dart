// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/services/protocol/sip/spp_constants.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  group('SppIncidentCodec', () {
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
      String body = 'Test report body',
      int senderNodeId = 0,
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
        timestamp: timestamp ?? DateTime.utc(2025, 6, 15, 12, 0, 0),
        refSeq: refSeq,
        latitude: latitude,
        longitude: longitude,
        body: body,
        senderNodeId: senderNodeId,
      );
    }

    group('encode', () {
      test('encodes minimal report (no location)', () {
        final report = makeReport();
        final encoded = SppIncidentCodec.encode(report);

        expect(encoded, isNotNull);
        expect(
          encoded!.length,
          greaterThanOrEqualTo(
            SppConstants.headerSize + SppConstants.incidentHeaderNoLoc + 1,
          ),
        );

        // SPP header: type_id=0x10, version=1
        expect(encoded[0], SppPayloadType.incidentReport.code);
        expect(encoded[1], sppIncidentVersion);
      });

      test('encodes report with location', () {
        final report = makeReport(latitude: -37.81, longitude: 144.96);
        final encoded = SppIncidentCodec.encode(report);

        expect(encoded, isNotNull);
        expect(
          encoded!.length,
          greaterThanOrEqualTo(
            SppConstants.headerSize + SppConstants.incidentHeaderWithLoc + 1,
          ),
        );
      });

      test('encodes empty body as zero-length', () {
        final report = makeReport(body: '');
        final encoded = SppIncidentCodec.encode(report);
        expect(encoded, isNotNull);

        // Round-trip: body should be empty string
        final decoded = SppIncidentCodec.decode(encoded!, 0);
        expect(decoded, isNotNull);
        expect(decoded!.body, isEmpty);
      });

      test('respects maximum body length without location', () {
        final longBody = 'A' * SppConstants.incidentMaxBodyNoLoc;
        final report = makeReport(body: longBody);
        final encoded = SppIncidentCodec.encode(report);

        expect(encoded, isNotNull);
        // Total should not exceed MRRP max payload
        expect(
          encoded!.length,
          lessThanOrEqualTo(SppConstants.maxBody + SppConstants.headerSize),
        );
      });

      test('truncates body exceeding maximum', () {
        final tooLongBody = 'B' * (SppConstants.incidentMaxBodyNoLoc + 50);
        final report = makeReport(body: tooLongBody);
        final encoded = SppIncidentCodec.encode(report);

        expect(encoded, isNotNull);
        // Decode and check body was truncated
        final decoded = SppIncidentCodec.decode(encoded!, 42);
        expect(decoded, isNotNull);
        expect(
          decoded!.body.length,
          lessThanOrEqualTo(SppConstants.incidentMaxBodyNoLoc),
        );
      });
    });

    group('decode', () {
      test('decodes encoded report (round-trip, no location)', () {
        final original = makeReport(
          caseId: 0xDEAD,
          seqNum: 3,
          updateType: IncidentUpdateType.update,
          confidence: IncidentConfidence.probable,
          classification: IncidentClassification.medical,
          priority: IncidentPriority.immediate,
          status: IncidentMeshStatus.active,
          reporterRole: IncidentReporterRole.operator,
          body: 'Patient found at camp',
        );

        final encoded = SppIncidentCodec.encode(original);
        expect(encoded, isNotNull);

        final decoded = SppIncidentCodec.decode(encoded!, 55);
        expect(decoded, isNotNull);
        expect(decoded!.caseId, original.caseId);
        expect(decoded.seqNum, original.seqNum);
        expect(decoded.updateType, original.updateType);
        expect(decoded.confidence, original.confidence);
        expect(decoded.classification, original.classification);
        expect(decoded.priority, original.priority);
        expect(decoded.status, original.status);
        expect(decoded.reporterRole, original.reporterRole);
        expect(decoded.body, original.body);
        expect(decoded.senderNodeId, 55);
        expect(decoded.latitude, isNull);
        expect(decoded.longitude, isNull);
        expect(decoded.hasLocation, isFalse);
      });

      test('decodes encoded report (round-trip, with location)', () {
        final original = makeReport(
          caseId: 42,
          seqNum: 1,
          latitude: 51.50,
          longitude: -0.12,
          body: 'Location incident',
        );

        final encoded = SppIncidentCodec.encode(original);
        expect(encoded, isNotNull);

        final decoded = SppIncidentCodec.decode(encoded!, 100);
        expect(decoded, isNotNull);
        expect(decoded!.hasLocation, isTrue);
        // Centidegree precision: lat * 100 = 5150, / 100 = 51.50
        expect(decoded.latitude, closeTo(51.50, 0.01));
        expect(decoded.longitude, closeTo(-0.12, 0.01));
        expect(decoded.body, 'Location incident');
      });

      test('decodes correction with ref_seq', () {
        final original = makeReport(
          updateType: IncidentUpdateType.correction,
          refSeq: 2,
          body: 'Corrected info',
        );

        final encoded = SppIncidentCodec.encode(original);
        final decoded = SppIncidentCodec.decode(encoded!, 10);
        expect(decoded, isNotNull);
        expect(decoded!.updateType, IncidentUpdateType.correction);
        expect(decoded.refSeq, 2);
      });

      test('returns null for truncated input', () {
        // Too short to contain even the SPP header
        expect(SppIncidentCodec.decode(Uint8List(1), 0), isNull);

        // Has SPP header but truncated incident header
        final buf = Uint8List(5);
        buf[0] = SppPayloadType.incidentReport.code;
        buf[1] = sppIncidentVersion;
        expect(SppIncidentCodec.decode(buf, 0), isNull);
      });

      test('returns null for wrong type_id', () {
        final buf = Uint8List(20);
        buf[0] = 0xFF; // Wrong type_id
        buf[1] = 1;
        expect(SppIncidentCodec.decode(buf, 0), isNull);
      });

      test('returns null for wrong version', () {
        final buf = Uint8List(20);
        buf[0] = SppPayloadType.incidentReport.code;
        buf[1] = 99; // Wrong version
        expect(SppIncidentCodec.decode(buf, 0), isNull);
      });
    });

    group('flags bitfield', () {
      test('encodes/decodes all update types', () {
        for (final type in IncidentUpdateType.values) {
          final report = makeReport(updateType: type);
          final encoded = SppIncidentCodec.encode(report);
          final decoded = SppIncidentCodec.decode(encoded!, 0);
          expect(decoded!.updateType, type, reason: type.name);
        }
      });

      test('encodes/decodes all confidence levels', () {
        for (final conf in IncidentConfidence.values) {
          final report = makeReport(confidence: conf);
          final encoded = SppIncidentCodec.encode(report);
          final decoded = SppIncidentCodec.decode(encoded!, 0);
          expect(decoded!.confidence, conf, reason: conf.name);
        }
      });

      test('encodes/decodes location flag correctly', () {
        final noLoc = makeReport();
        final withLoc = makeReport(latitude: 10.0, longitude: 20.0);

        final encNoLoc = SppIncidentCodec.encode(noLoc);
        final encWithLoc = SppIncidentCodec.encode(withLoc);

        final decNoLoc = SppIncidentCodec.decode(encNoLoc!, 0);
        final decWithLoc = SppIncidentCodec.decode(encWithLoc!, 0);

        expect(decNoLoc!.hasLocation, isFalse);
        expect(decWithLoc!.hasLocation, isTrue);
      });
    });

    group('estimateSize', () {
      test('returns correct estimate without location', () {
        final report = makeReport(body: 'Hello');
        final estimate = SppIncidentCodec.estimateSize(report);
        final actual = SppIncidentCodec.encode(report)!.length;
        expect(estimate, actual);
      });

      test('returns correct estimate with location', () {
        final report = makeReport(
          body: 'Located',
          latitude: 1.0,
          longitude: 2.0,
        );
        final estimate = SppIncidentCodec.estimateSize(report);
        final actual = SppIncidentCodec.encode(report)!.length;
        expect(estimate, actual);
      });
    });

    group('all enum values round-trip', () {
      test('all classifications', () {
        for (final c in IncidentClassification.values) {
          final report = makeReport(classification: c);
          final decoded = SppIncidentCodec.decode(
            SppIncidentCodec.encode(report)!,
            0,
          );
          expect(decoded!.classification, c, reason: c.name);
        }
      });

      test('all priorities', () {
        for (final p in IncidentPriority.values) {
          final report = makeReport(priority: p);
          final decoded = SppIncidentCodec.decode(
            SppIncidentCodec.encode(report)!,
            0,
          );
          expect(decoded!.priority, p, reason: p.name);
        }
      });

      test('all mesh statuses', () {
        for (final s in IncidentMeshStatus.values) {
          final report = makeReport(status: s);
          final decoded = SppIncidentCodec.decode(
            SppIncidentCodec.encode(report)!,
            0,
          );
          expect(decoded!.status, s, reason: s.name);
        }
      });

      test('all reporter roles', () {
        for (final r in IncidentReporterRole.values) {
          final report = makeReport(reporterRole: r);
          final decoded = SppIncidentCodec.decode(
            SppIncidentCodec.encode(report)!,
            0,
          );
          expect(decoded!.reporterRole, r, reason: r.name);
        }
      });
    });

    group('timestamp', () {
      test('preserves timestamp to second precision', () {
        final ts = DateTime.utc(2025, 1, 15, 14, 30, 45);
        final report = makeReport(timestamp: ts);
        final decoded = SppIncidentCodec.decode(
          SppIncidentCodec.encode(report)!,
          0,
        );
        expect(decoded!.timestamp, ts);
      });

      test('truncates sub-second precision', () {
        final ts = DateTime.utc(2025, 1, 15, 14, 30, 45, 123);
        final report = makeReport(timestamp: ts);
        final decoded = SppIncidentCodec.decode(
          SppIncidentCodec.encode(report)!,
          0,
        );
        // Sub-second precision is lost (uint32 seconds)
        expect(decoded!.timestamp, DateTime.utc(2025, 1, 15, 14, 30, 45));
      });
    });
  });
}
