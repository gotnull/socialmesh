// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  group('IncidentQuickUpdate partition', () {
    test('requester codes report isRequesterCode', () {
      const requester = [
        IncidentQuickUpdate.imOk,
        IncidentQuickUpdate.imInjured,
        IncidentQuickUpdate.cantMove,
        IncidentQuickUpdate.needWater,
        IncidentQuickUpdate.needMedical,
        IncidentQuickUpdate.falseAlarm,
        IncidentQuickUpdate.situationWorse,
      ];
      for (final code in requester) {
        expect(code.isRequesterCode, isTrue, reason: code.name);
        expect(code.isResponderCode, isFalse, reason: code.name);
      }
    });

    test('responder codes report isResponderCode', () {
      const responder = [
        IncidentQuickUpdate.onMyWay,
        IncidentQuickUpdate.arrived,
        IncidentQuickUpdate.needBackup,
        IncidentQuickUpdate.blocked,
        IncidentQuickUpdate.cantReachYou,
        IncidentQuickUpdate.leavingResponse,
      ];
      for (final code in responder) {
        expect(code.isResponderCode, isTrue, reason: code.name);
        expect(code.isRequesterCode, isFalse, reason: code.name);
      }
    });

    test('every quick code is partitioned exactly once', () {
      for (final code in IncidentQuickUpdate.values) {
        expect(code.isRequesterCode != code.isResponderCode, isTrue);
      }
    });
  });

  group('IncidentLifecycleState', () {
    test('only resolvedSafe, cancelled, expired are terminal', () {
      final terminal = IncidentLifecycleState.values
          .where((s) => s.isTerminal)
          .toSet();
      expect(terminal, {
        IncidentLifecycleState.resolvedSafe,
        IncidentLifecycleState.cancelled,
        IncidentLifecycleState.expired,
      });
    });

    test('resolvedSafe and cancelled are distinct terminal states', () {
      expect(
        IncidentLifecycleState.resolvedSafe,
        isNot(IncidentLifecycleState.cancelled),
      );
    });
  });

  group('IncidentLocation', () {
    IncidentLocation make() => IncidentLocation(
      incidentId: 7,
      nodeId: 42,
      latitude: -33.87,
      longitude: 151.21,
      accuracyMeters: 12.5,
      fixedAt: DateTime.utc(2026, 6, 17, 10),
      receivedAt: DateTime.utc(2026, 6, 17, 10, 0, 5),
    );

    test('isFinite is true for normal coordinates', () {
      expect(make().isFinite, isTrue);
    });

    test('isFinite is false for NaN', () {
      final bad = make().copyWith(latitude: double.nan);
      expect(bad.isFinite, isFalse);
    });

    test('ageFrom computes fix age', () {
      final loc = make();
      final age = loc.ageFrom(DateTime.utc(2026, 6, 17, 10, 1));
      expect(age, const Duration(minutes: 1));
    });

    test('toMap/fromMap round-trip', () {
      final original = make();
      final restored = IncidentLocation.fromMap(original.toMap());
      expect(restored.incidentId, original.incidentId);
      expect(restored.nodeId, original.nodeId);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracyMeters, original.accuracyMeters);
      expect(restored.fixedAt, original.fixedAt);
      expect(restored.receivedAt, original.receivedAt);
    });
  });

  group('IncidentMessage', () {
    test('toMap/fromMap round-trip', () {
      final original = IncidentMessage(
        incidentId: 3,
        senderNodeId: 99,
        seq: 4,
        text: 'on the ridge near the gate',
        timestamp: DateTime.utc(2026, 6, 17, 11, 30),
      );
      final restored = IncidentMessage.fromMap(original.toMap());
      expect(restored.incidentId, original.incidentId);
      expect(restored.senderNodeId, original.senderNodeId);
      expect(restored.seq, original.seq);
      expect(restored.text, original.text);
      expect(restored.timestamp, original.timestamp);
    });
  });

  group('IncidentParticipant', () {
    test('toMap/fromMap round-trip with status', () {
      final original = IncidentParticipant(
        incidentId: 5,
        nodeId: 200,
        role: IncidentRole.responder,
        lastStatus: IncidentQuickUpdate.onMyWay,
        lastSeen: DateTime.utc(2026, 6, 17, 12),
        deliveryState: IncidentDeliveryState.accepted,
      );
      final restored = IncidentParticipant.fromMap(original.toMap());
      expect(restored.incidentId, original.incidentId);
      expect(restored.nodeId, original.nodeId);
      expect(restored.role, original.role);
      expect(restored.lastStatus, original.lastStatus);
      expect(restored.lastSeen, original.lastSeen);
      expect(restored.deliveryState, original.deliveryState);
    });

    test('toMap/fromMap round-trip with null status', () {
      const original = IncidentParticipant(
        incidentId: 5,
        nodeId: 200,
        role: IncidentRole.requester,
      );
      final restored = IncidentParticipant.fromMap(original.toMap());
      expect(restored.lastStatus, isNull);
      expect(restored.lastSeen, isNull);
      expect(restored.deliveryState, IncidentDeliveryState.pending);
    });
  });

  group('IncidentEvent', () {
    test('dedupeKey format is incidentId:sender:seq', () {
      final e = IncidentEvent(
        incidentId: 10,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.create,
        senderNodeId: 3,
        seq: 2,
        timestamp: DateTime.utc(2026, 6, 17),
      );
      expect(e.dedupeKey, '10:3:2');
    });

    test('equality and hashCode key on (incidentId, sender, seq)', () {
      final a = IncidentEvent(
        incidentId: 1,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.create,
        senderNodeId: 3,
        seq: 0,
        timestamp: DateTime.utc(2026, 6, 17),
      );
      final b = IncidentEvent(
        incidentId: 1,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.requesterStatus,
        senderNodeId: 3,
        seq: 0,
        timestamp: DateTime.utc(2026, 6, 17, 1),
        quickUpdate: IncidentQuickUpdate.imOk,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('help-request event toMap/fromMap round-trip', () {
      final original = IncidentEvent(
        incidentId: 0xABCD,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.location,
        senderNodeId: 77,
        seq: 5,
        timestamp: DateTime.utc(2026, 6, 17, 9),
        receivedAt: DateTime.utc(2026, 6, 17, 9, 0, 2),
        location: IncidentLocation(
          incidentId: 0xABCD,
          nodeId: 77,
          latitude: 51.5,
          longitude: -0.12,
          accuracyMeters: 8,
          fixedAt: DateTime.utc(2026, 6, 17, 9),
        ),
      );
      final restored = IncidentEvent.fromMap(original.toMap());
      expect(restored.incidentId, original.incidentId);
      expect(restored.workflowKind, original.workflowKind);
      expect(restored.type, original.type);
      expect(restored.senderNodeId, original.senderNodeId);
      expect(restored.seq, original.seq);
      expect(restored.timestamp, original.timestamp);
      expect(restored.receivedAt, original.receivedAt);
      expect(restored.location?.latitude, 51.5);
      expect(restored.location?.longitude, -0.12);
    });

    test('hazard-report event toMap/fromMap round-trip', () {
      final original = IncidentEvent(
        incidentId: 42,
        workflowKind: IncidentWorkflowKind.hazardReport,
        type: IncidentEventType.hazardReport,
        senderNodeId: 11,
        seq: 1,
        timestamp: DateTime.utc(2026, 6, 17, 8),
        refSeq: 0,
        hazardStatus: IncidentMeshStatus.active,
        hazardUpdateType: IncidentUpdateType.correction,
      );
      final restored = IncidentEvent.fromMap(original.toMap());
      expect(restored.workflowKind, IncidentWorkflowKind.hazardReport);
      expect(restored.hazardStatus, IncidentMeshStatus.active);
      expect(restored.hazardUpdateType, IncidentUpdateType.correction);
      expect(restored.refSeq, 0);
      expect(restored.isCorrection, isTrue);
    });

    test('quick-update event toMap/fromMap round-trip', () {
      final original = IncidentEvent(
        incidentId: 1,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.responderStatus,
        senderNodeId: 200,
        seq: 3,
        timestamp: DateTime.utc(2026, 6, 17, 12),
        quickUpdate: IncidentQuickUpdate.arrived,
        ackCategory: IncidentAckCategory.accepted,
      );
      final restored = IncidentEvent.fromMap(original.toMap());
      expect(restored.quickUpdate, IncidentQuickUpdate.arrived);
      expect(restored.ackCategory, IncidentAckCategory.accepted);
    });
  });
}
