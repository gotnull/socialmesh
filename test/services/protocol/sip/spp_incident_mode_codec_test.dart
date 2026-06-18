// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_mode_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  // Epoch 0 keeps the 4 timestamp bytes all-zero, so full payloads can be
  // pinned as literal byte vectors deterministically.
  final epoch0 = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  const incidentId = 0x01020304; // little-endian bytes: 04 03 02 01
  const seq = 7;

  // Fixed prefix the codec emits ahead of every msg_type body.
  List<int> prefix({
    required int workflow,
    required int msg,
    int id = incidentId,
    int seqByte = seq,
    int refSeq = 0xFF,
    List<int> ts = const [0, 0, 0, 0],
  }) => [
    0x13, // spp_type incidentMode
    0x01, // version
    workflow,
    msg,
    id & 0xFF, (id >> 8) & 0xFF, (id >> 16) & 0xFF, (id >> 24) & 0xFF,
    seqByte,
    refSeq,
    0x00, // flags reserved
    ...ts,
  ];

  IncidentEvent help({
    required IncidentEventType type,
    int seqVal = seq,
    int? refSeq,
    DateTime? ts,
    IncidentQuickUpdate? quickUpdate,
    IncidentAckCategory? ackCategory,
    IncidentLocation? location,
    IncidentMessage? message,
    DateTime? expiresAt,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: 0, // ignored by encode
    seq: seqVal,
    timestamp: ts ?? epoch0,
    refSeq: refSeq,
    quickUpdate: quickUpdate,
    ackCategory: ackCategory,
    location: location,
    message: message,
    expiresAt: expiresAt,
  );

  group('SppIncidentModeCodec byte-pinned vectors (help_request)', () {
    test('IncidentCreate (no expiry)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.create),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x10),
          0, 0, 0, 0, // expiry = none
        ]),
      );
    });

    test('IncidentAck (received)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(
          type: IncidentEventType.ack,
          ackCategory: IncidentAckCategory.received,
          refSeq: 0,
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x11, refSeq: 0x00),
          0x01, // ack category received
        ]),
      );
    });

    test('IncidentSeen (empty body)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.seen),
      );
      expect(bytes, orderedEquals(prefix(workflow: 0x01, msg: 0x12)));
    });

    test('ResponderAccept (empty body)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.responderAccept),
      );
      expect(bytes, orderedEquals(prefix(workflow: 0x01, msg: 0x13)));
    });

    test('ResponderLeave (empty body)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.responderLeave),
      );
      expect(bytes, orderedEquals(prefix(workflow: 0x01, msg: 0x14)));
    });

    test('RequesterStatus (imInjured)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(
          type: IncidentEventType.requesterStatus,
          quickUpdate: IncidentQuickUpdate.imInjured,
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x15),
          0x02, // imInjured
        ]),
      );
    });

    test('ResponderStatus (onMyWay)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(
          type: IncidentEventType.responderStatus,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x16),
          0x10, // onMyWay
        ]),
      );
    });

    test('IncidentLocation (lat=1.0, lon=-1.0, acc=25m, fix epoch0)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(
          type: IncidentEventType.location,
          location: IncidentLocation(
            incidentId: incidentId,
            nodeId: 0,
            latitude: 1.0,
            longitude: -1.0,
            accuracyMeters: 25,
            fixedAt: epoch0,
          ),
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x17),
          0x80, 0x96, 0x98, 0x00, // latE7 = 10000000
          0x80, 0x69, 0x67, 0xFF, // lonE7 = -10000000
          0x19, 0x00, // accuracy = 25
          0x00, 0x00, 0x00, 0x00, // fixedAt epoch0
        ]),
      );
    });

    test('IncidentMessage ("hi")', () {
      final bytes = SppIncidentModeCodec.encode(
        help(
          type: IncidentEventType.message,
          message: IncidentMessage(
            incidentId: incidentId,
            senderNodeId: 0,
            seq: seq,
            text: 'hi',
            timestamp: epoch0,
          ),
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x01, msg: 0x18),
          0x02, // text length
          0x68, 0x69, // "hi"
        ]),
      );
    });

    test('IncidentResolve (empty body)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.resolve),
      );
      expect(bytes, orderedEquals(prefix(workflow: 0x01, msg: 0x19)));
    });

    test('IncidentCancel (empty body)', () {
      final bytes = SppIncidentModeCodec.encode(
        help(type: IncidentEventType.cancel),
      );
      expect(bytes, orderedEquals(prefix(workflow: 0x01, msg: 0x1A)));
    });

    test('IncidentExpire is local-only and never encodes', () {
      expect(
        SppIncidentModeCodec.encode(help(type: IncidentEventType.expire)),
        isNull,
      );
    });
  });

  group('SppIncidentModeCodec round-trip (help_request)', () {
    final realTs = DateTime.utc(2026, 6, 17, 10, 30, 45);

    test('create round-trips with expiry', () {
      final expiry = DateTime.utc(2026, 6, 17, 11);
      final ev = help(
        type: IncidentEventType.create,
        ts: realTs,
        expiresAt: expiry,
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        55,
      );
      expect(decoded, isNotNull);
      expect(decoded!.type, IncidentEventType.create);
      expect(decoded.workflowKind, IncidentWorkflowKind.helpRequest);
      expect(decoded.incidentId, incidentId);
      expect(decoded.seq, seq);
      expect(decoded.senderNodeId, 55); // bound from transport, not payload
      expect(decoded.timestamp, realTs);
      expect(decoded.expiresAt, expiry);
    });

    test('create round-trips with no expiry', () {
      final ev = help(type: IncidentEventType.create, ts: realTs);
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        1,
      );
      expect(decoded!.expiresAt, isNull);
    });

    test('every empty-body help type round-trips', () {
      const emptyTypes = [
        IncidentEventType.seen,
        IncidentEventType.responderAccept,
        IncidentEventType.responderLeave,
        IncidentEventType.resolve,
        IncidentEventType.cancel,
      ];
      for (final t in emptyTypes) {
        final decoded = SppIncidentModeCodec.decode(
          SppIncidentModeCodec.encode(help(type: t, ts: realTs))!,
          9,
        );
        expect(decoded, isNotNull, reason: t.name);
        expect(decoded!.type, t, reason: t.name);
        expect(decoded.senderNodeId, 9, reason: t.name);
      }
    });

    test('location round-trips including accuracy and fix time', () {
      final fix = DateTime.utc(2026, 6, 17, 9, 59);
      final ev = help(
        type: IncidentEventType.location,
        ts: realTs,
        location: IncidentLocation(
          incidentId: incidentId,
          nodeId: 0,
          latitude: -33.8688,
          longitude: 151.2093,
          accuracyMeters: 12,
          fixedAt: fix,
        ),
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        77,
      );
      expect(decoded!.location, isNotNull);
      final loc = decoded.location!;
      expect(loc.nodeId, 77); // bound from transport
      expect(loc.latitude, closeTo(-33.8688, 1e-6));
      expect(loc.longitude, closeTo(151.2093, 1e-6));
      expect(loc.accuracyMeters, 12);
      expect(loc.fixedAt, fix);
    });

    test('location with unknown accuracy round-trips as null', () {
      final ev = help(
        type: IncidentEventType.location,
        location: IncidentLocation(
          incidentId: incidentId,
          nodeId: 0,
          latitude: 10,
          longitude: 20,
          fixedAt: realTs,
        ),
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        3,
      );
      expect(decoded!.location!.accuracyMeters, isNull);
    });

    test('refSeq round-trips and 0xFF sentinel decodes to null', () {
      final withRef = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(
          help(
            type: IncidentEventType.ack,
            ackCategory: IncidentAckCategory.surfaced,
            refSeq: 3,
          ),
        )!,
        1,
      );
      expect(withRef!.refSeq, 3);

      final noRef = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(
          help(
            type: IncidentEventType.ack,
            ackCategory: IncidentAckCategory.surfaced,
          ),
        )!,
        1,
      );
      expect(noRef!.refSeq, isNull);
    });
  });

  group('SppIncidentModeCodec quick-update mapping', () {
    test('every quick code round-trips on the correct status type', () {
      for (final q in IncidentQuickUpdate.values) {
        final type = q.isRequesterCode
            ? IncidentEventType.requesterStatus
            : IncidentEventType.responderStatus;
        final decoded = SppIncidentModeCodec.decode(
          SppIncidentModeCodec.encode(help(type: type, quickUpdate: q))!,
          1,
        );
        expect(decoded, isNotNull, reason: q.name);
        expect(decoded!.quickUpdate, q, reason: q.name);
      }
    });

    test('requester status rejects a responder code at encode', () {
      expect(
        SppIncidentModeCodec.encode(
          help(
            type: IncidentEventType.requesterStatus,
            quickUpdate: IncidentQuickUpdate.onMyWay,
          ),
        ),
        isNull,
      );
    });

    test('responder status rejects a requester code at encode', () {
      expect(
        SppIncidentModeCodec.encode(
          help(
            type: IncidentEventType.responderStatus,
            quickUpdate: IncidentQuickUpdate.imOk,
          ),
        ),
        isNull,
      );
    });

    test('status with missing quick code fails to encode', () {
      expect(
        SppIncidentModeCodec.encode(
          help(type: IncidentEventType.requesterStatus),
        ),
        isNull,
      );
    });
  });

  group('SppIncidentModeCodec ACK category mapping', () {
    test('every ack category round-trips', () {
      for (final cat in IncidentAckCategory.values) {
        final decoded = SppIncidentModeCodec.decode(
          SppIncidentModeCodec.encode(
            help(type: IncidentEventType.ack, ackCategory: cat),
          )!,
          1,
        );
        expect(decoded!.ackCategory, cat, reason: cat.name);
      }
    });

    test('ack with missing category fails to encode', () {
      expect(
        SppIncidentModeCodec.encode(help(type: IncidentEventType.ack)),
        isNull,
      );
    });
  });

  group('SppIncidentModeCodec message sanitization', () {
    test('control characters are stripped at decode (codec boundary)', () {
      final ev = help(
        type: IncidentEventType.message,
        message: IncidentMessage(
          incidentId: incidentId,
          senderNodeId: 0,
          seq: seq,
          text: 'ab', // bell (C0 control) in the middle
          timestamp: epoch0,
        ),
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        1,
      );
      expect(decoded!.message!.text, 'ab');
    });

    test('message seq mirrors the event seq', () {
      final ev = help(
        type: IncidentEventType.message,
        seqVal: 12,
        message: IncidentMessage(
          incidentId: incidentId,
          senderNodeId: 0,
          seq: 999, // ignored on the wire; reset to event seq on decode
          text: 'hello',
          timestamp: epoch0,
        ),
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        1,
      );
      expect(decoded!.message!.seq, 12);
      expect(decoded.message!.text, 'hello');
    });
  });

  group('SppIncidentModeCodec malformed / safe rejection', () {
    test('too-short payload returns null', () {
      expect(SppIncidentModeCodec.decode(Uint8List(3), 0), isNull);
      expect(SppIncidentModeCodec.decode(Uint8List(0), 0), isNull);
    });

    test('wrong spp_type returns null', () {
      final raw = Uint8List.fromList(prefix(workflow: 0x01, msg: 0x12))
        ..[0] = 0x10; // legacy hazard type, not incidentMode
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('wrong version returns null', () {
      final raw = Uint8List.fromList(prefix(workflow: 0x01, msg: 0x12))
        ..[1] = 99;
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('unknown workflow_kind returns null', () {
      final raw = Uint8List.fromList(prefix(workflow: 0x99, msg: 0x12));
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('unknown msg_type returns null', () {
      final raw = Uint8List.fromList(prefix(workflow: 0x01, msg: 0x99));
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('workflow/msg_type mismatch returns null', () {
      // hazardReport msg (0x01) under help workflow (0x01) is invalid.
      final raw = Uint8List.fromList([
        ...prefix(workflow: 0x01, msg: 0x01),
        0,
        0,
      ]);
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('truncated location body returns null', () {
      final raw = Uint8List.fromList([
        ...prefix(workflow: 0x01, msg: 0x17),
        0x00, 0x00, // only 2 of 14 body bytes
      ]);
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('message length overrunning the payload returns null', () {
      final raw = Uint8List.fromList([
        ...prefix(workflow: 0x01, msg: 0x18),
        0x05, // claims 5 text bytes
        0x68, // only 1 provided
      ]);
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('invalid ack category byte returns null', () {
      final raw = Uint8List.fromList([
        ...prefix(workflow: 0x01, msg: 0x11),
        0x7F, // not a defined ack category
      ]);
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });

    test('invalid quick code byte returns null', () {
      final raw = Uint8List.fromList([
        ...prefix(workflow: 0x01, msg: 0x15),
        0x7F, // not a defined quick code
      ]);
      expect(SppIncidentModeCodec.decode(raw, 0), isNull);
    });
  });

  group('SppIncidentModeCodec hazard_report (unified envelope)', () {
    IncidentEvent hazard({
      required IncidentMeshStatus status,
      required IncidentUpdateType update,
      int seqVal = seq,
      int? refSeq,
      DateTime? ts,
    }) => IncidentEvent(
      incidentId: incidentId,
      workflowKind: IncidentWorkflowKind.hazardReport,
      type: IncidentEventType.hazardReport,
      senderNodeId: 0,
      seq: seqVal,
      timestamp: ts ?? epoch0,
      refSeq: refSeq,
      hazardStatus: status,
      hazardUpdateType: update,
    );

    test('byte-pinned hazard report (active / initial)', () {
      final bytes = SppIncidentModeCodec.encode(
        hazard(
          status: IncidentMeshStatus.active,
          update: IncidentUpdateType.initial,
        ),
      );
      expect(
        bytes,
        orderedEquals([
          ...prefix(workflow: 0x00, msg: 0x01),
          0x01, // status active
          0x00, // update initial
        ]),
      );
    });

    test('hazard report round-trips with correction ref_seq', () {
      final ev = hazard(
        status: IncidentMeshStatus.contained,
        update: IncidentUpdateType.correction,
        refSeq: 2,
        ts: DateTime.utc(2026, 6, 17, 8),
      );
      final decoded = SppIncidentModeCodec.decode(
        SppIncidentModeCodec.encode(ev)!,
        500,
      );
      expect(decoded!.workflowKind, IncidentWorkflowKind.hazardReport);
      expect(decoded.type, IncidentEventType.hazardReport);
      expect(decoded.hazardStatus, IncidentMeshStatus.contained);
      expect(decoded.hazardUpdateType, IncidentUpdateType.correction);
      expect(decoded.refSeq, 2);
      expect(decoded.senderNodeId, 500);
    });

    test('all hazard status + update combinations round-trip', () {
      for (final s in IncidentMeshStatus.values) {
        for (final u in IncidentUpdateType.values) {
          final decoded = SppIncidentModeCodec.decode(
            SppIncidentModeCodec.encode(hazard(status: s, update: u))!,
            1,
          );
          expect(decoded!.hazardStatus, s, reason: '${s.name}/${u.name}');
          expect(decoded.hazardUpdateType, u, reason: '${s.name}/${u.name}');
        }
      }
    });
  });

  group('hazard-report wire preservation (legacy vs unified)', () {
    // The legacy field-hazard codec (SppIncidentCodec, type 0x10) is left
    // untouched: its wire format and behaviour are PRESERVED. The unified
    // codec introduces a SEPARATE, reduced hazard representation under the
    // new workflow_kind envelope (type 0x13). No migration of the legacy
    // wire occurs in this change; switching the runtime to the unified
    // envelope is deferred to the MRRP wiring change (PR-4).

    test('legacy and unified hazard use distinct, non-colliding SPP types', () {
      expect(SppPayloadType.incidentReport.code, 0x10);
      expect(SppPayloadType.incidentMode.code, 0x13);
      expect(
        SppPayloadType.incidentReport.code,
        isNot(SppPayloadType.incidentMode.code),
      );
    });

    test('legacy hazard codec still round-trips unchanged (type 0x10)', () {
      final report = MeshIncidentReport(
        caseId: 0xDEAD,
        seqNum: 3,
        updateType: IncidentUpdateType.update,
        confidence: IncidentConfidence.probable,
        classification: IncidentClassification.medical,
        priority: IncidentPriority.immediate,
        status: IncidentMeshStatus.active,
        reporterRole: IncidentReporterRole.operator,
        timestamp: DateTime.utc(2025, 6, 15, 12),
        body: 'Patient found at camp',
      );
      final encoded = SppIncidentCodec.encode(report)!;
      expect(encoded[0], 0x10); // still the legacy type id
      final decoded = SppIncidentCodec.decode(encoded, 55);
      expect(decoded!.caseId, report.caseId);
      expect(decoded.classification, report.classification);
      expect(decoded.priority, report.priority);
      expect(decoded.body, report.body);
    });

    test('unified codec rejects a legacy-encoded hazard payload', () {
      // A legacy 0x10 payload must not be misread by the unified 0x13 codec.
      final report = MeshIncidentReport(
        caseId: 1,
        seqNum: 0,
        updateType: IncidentUpdateType.initial,
        confidence: IncidentConfidence.unconfirmed,
        classification: IncidentClassification.operational,
        priority: IncidentPriority.routine,
        status: IncidentMeshStatus.reported,
        reporterRole: IncidentReporterRole.observer,
        timestamp: DateTime.utc(2025, 6, 15),
        body: 'hi',
      );
      final legacy = SppIncidentCodec.encode(report)!;
      expect(SppIncidentModeCodec.decode(legacy, 0), isNull);
    });
  });
}
