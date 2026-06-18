// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/services/incident_mode_reducer.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  // Fixed base clock; events are spaced by whole minutes so ordering is
  // deterministic and easy to reason about.
  final base = DateTime.utc(2026, 6, 17, 10);
  DateTime at(int minutes) => base.add(Duration(minutes: minutes));

  const incidentId = 0x1001;
  const requester = 100;
  const responderA = 200;
  const responderB = 300;

  IncidentEvent create({int minute = 0, DateTime? expiresAt}) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: IncidentEventType.create,
    senderNodeId: requester,
    seq: 0,
    timestamp: at(minute),
    expiresAt: expiresAt,
  );

  IncidentEvent helpEvent({
    required IncidentEventType type,
    required int sender,
    required int seq,
    required int minute,
    IncidentQuickUpdate? quickUpdate,
    IncidentAckCategory? ackCategory,
    IncidentLocation? location,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: sender,
    seq: seq,
    timestamp: at(minute),
    quickUpdate: quickUpdate,
    ackCategory: ackCategory,
    location: location,
  );

  IncidentEvent hazard({
    required int seq,
    required int minute,
    required IncidentMeshStatus status,
    required IncidentUpdateType updateType,
    int sender = 500,
    int? refSeq,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.hazardReport,
    type: IncidentEventType.hazardReport,
    senderNodeId: sender,
    seq: seq,
    timestamp: at(minute),
    refSeq: refSeq,
    hazardStatus: status,
    hazardUpdateType: updateType,
  );

  group('IncidentReducer empty/invalid input', () {
    test('throws on empty log', () {
      expect(() => IncidentReducer.project(const []), throwsArgumentError);
    });

    test('throws when events span multiple incidents', () {
      final a = create();
      final b = create().copyWith(incidentId: 0x2002);
      expect(() => IncidentReducer.project([a, b]), throwsArgumentError);
    });
  });

  group('IncidentReducer help-request lifecycle', () {
    test('create only -> broadcasting', () {
      final p = IncidentReducer.project([create()]);
      expect(p.workflowKind, IncidentWorkflowKind.helpRequest);
      expect(p.helpState, IncidentLifecycleState.broadcasting);
      expect(p.hazardStatus, isNull);
      expect(p.isTerminal, isFalse);
      expect(p.originNodeId, requester);
      expect(p.responderCount, 0);
      expect(p.locationSharing, isTrue);
    });

    test('create + ack(received) -> activeNoResponder', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.ack,
          sender: responderA,
          seq: 0,
          minute: 1,
          ackCategory: IncidentAckCategory.received,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.activeNoResponder);
      expect(p.responderCount, 0);
    });

    test('create + responderAccept -> activeWithResponder', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.activeWithResponder);
      expect(p.responderCount, 1);
      expect(p.responders.single.nodeId, responderA);
      expect(p.responders.single.deliveryState, IncidentDeliveryState.accepted);
    });

    test('responder onMyWay -> responderEnRoute', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.responderEnRoute);
      expect(p.responders.single.lastStatus, IncidentQuickUpdate.onMyWay);
    });

    test('responder arrived -> responderArrived', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 2,
          minute: 4,
          quickUpdate: IncidentQuickUpdate.arrived,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.responderArrived);
    });

    test('responderLeave drops back to activeNoResponder when none remain', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderLeave,
          sender: responderA,
          seq: 1,
          minute: 3,
        ),
      ]);
      // An accept was observed (acknowledged), so we fall to activeNoResponder
      // rather than broadcasting.
      expect(p.helpState, IncidentLifecycleState.activeNoResponder);
      expect(p.responderCount, 0);
    });

    test('latest requester status is projected', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.requesterStatus,
          sender: requester,
          seq: 1,
          minute: 1,
          quickUpdate: IncidentQuickUpdate.imInjured,
        ),
        helpEvent(
          type: IncidentEventType.requesterStatus,
          sender: requester,
          seq: 2,
          minute: 2,
          quickUpdate: IncidentQuickUpdate.cantMove,
        ),
      ]);
      expect(p.lastRequesterStatus, IncidentQuickUpdate.cantMove);
    });

    test('requester false_alarm quick code does NOT terminate the incident', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.requesterStatus,
          sender: requester,
          seq: 1,
          minute: 1,
          quickUpdate: IncidentQuickUpdate.falseAlarm,
        ),
      ]);
      // Only an explicit cancel event terminates -- false_alarm is informational.
      expect(p.isTerminal, isFalse);
      expect(p.helpState, IncidentLifecycleState.broadcasting);
    });

    test('latest requester location is projected', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.location,
          sender: requester,
          seq: 1,
          minute: 1,
          location: IncidentLocation(
            incidentId: incidentId,
            nodeId: requester,
            latitude: 1,
            longitude: 2,
            fixedAt: at(1),
          ),
        ),
        helpEvent(
          type: IncidentEventType.location,
          sender: requester,
          seq: 2,
          minute: 2,
          location: IncidentLocation(
            incidentId: incidentId,
            nodeId: requester,
            latitude: 3,
            longitude: 4,
            fixedAt: at(2),
          ),
        ),
      ]);
      expect(p.lastRequesterLocation?.latitude, 3);
      expect(p.lastRequesterLocation?.longitude, 4);
    });
  });

  group('IncidentReducer multi-responder', () {
    test('progress is the max across active responders', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderB,
          seq: 0,
          minute: 3,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderB,
          seq: 1,
          minute: 4,
          quickUpdate: IncidentQuickUpdate.arrived,
        ),
      ]);
      // A is just accepted, B has arrived -> overall arrived.
      expect(p.helpState, IncidentLifecycleState.responderArrived);
      expect(p.responderCount, 2);
    });

    test('participants sorted by node id; requester present', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderB,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 3,
        ),
      ]);
      expect(p.participants.map((e) => e.nodeId), [
        requester,
        responderA,
        responderB,
      ]);
      expect(p.participants.first.role, IncidentRole.requester);
    });
  });

  group('IncidentReducer terminal states', () {
    test('resolve -> resolvedSafe (terminal)', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.resolve,
          sender: requester,
          seq: 1,
          minute: 5,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.resolvedSafe);
      expect(p.isTerminal, isTrue);
      expect(p.locationSharing, isFalse);
    });

    test('cancel -> cancelled (terminal)', () {
      final p = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.cancel,
          sender: requester,
          seq: 1,
          minute: 3,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.cancelled);
      expect(p.isTerminal, isTrue);
      expect(p.locationSharing, isFalse);
    });

    test('resolvedSafe and cancelled are distinct outcomes', () {
      final resolved = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.resolve,
          sender: requester,
          seq: 1,
          minute: 3,
        ),
      ]);
      final cancelled = IncidentReducer.project([
        create(),
        helpEvent(
          type: IncidentEventType.cancel,
          sender: requester,
          seq: 1,
          minute: 3,
        ),
      ]);
      expect(resolved.helpState, IncidentLifecycleState.resolvedSafe);
      expect(cancelled.helpState, IncidentLifecycleState.cancelled);
      expect(resolved.helpState, isNot(cancelled.helpState));
    });

    test('expire -> expired (terminal)', () {
      final p = IncidentReducer.project([
        create(expiresAt: at(30)),
        helpEvent(
          type: IncidentEventType.expire,
          sender: requester,
          seq: 1,
          minute: 31,
        ),
      ]);
      expect(p.helpState, IncidentLifecycleState.expired);
      expect(p.isTerminal, isTrue);
    });

    test(
      'resolve wins over later expire on precedence when same timestamp',
      () {
        final resolve = helpEvent(
          type: IncidentEventType.resolve,
          sender: requester,
          seq: 1,
          minute: 5,
        );
        final expire = helpEvent(
          type: IncidentEventType.expire,
          sender: requester,
          seq: 2,
          minute: 5,
        );
        final p = IncidentReducer.project([create(), expire, resolve]);
        expect(p.helpState, IncidentLifecycleState.resolvedSafe);
      },
    );
  });

  group('IncidentReducer dedupe and ordering', () {
    test('duplicate event is ignored', () {
      final accept = helpEvent(
        type: IncidentEventType.responderAccept,
        sender: responderA,
        seq: 0,
        minute: 2,
      );
      final p = IncidentReducer.project([create(), accept, accept]);
      expect(p.responderCount, 1);
      // Timeline holds create + one accept, not the duplicate.
      expect(p.timeline.length, 2);
    });

    test('out-of-order events converge to the same projection', () {
      final ordered = <IncidentEvent>[
        create(minute: 0),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 2,
          minute: 4,
          quickUpdate: IncidentQuickUpdate.arrived,
        ),
      ];
      final shuffled = [ordered[3], ordered[1], ordered[0], ordered[2]];

      final a = IncidentReducer.project(ordered);
      final b = IncidentReducer.project(shuffled);

      expect(a.helpState, b.helpState);
      expect(a.helpState, IncidentLifecycleState.responderArrived);
      expect(
        a.timeline.map((e) => e.dedupeKey).toList(),
        b.timeline.map((e) => e.dedupeKey).toList(),
      );
    });

    test('timeline ordering is stable and chronological', () {
      final events = <IncidentEvent>[
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 2,
          minute: 4,
          quickUpdate: IncidentQuickUpdate.arrived,
        ),
        create(minute: 0),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
      ];
      final p = IncidentReducer.project(events);
      final times = p.timeline.map((e) => e.timestamp).toList();
      final sorted = [...times]..sort();
      expect(times, sorted);
      expect(p.timeline.first.type, IncidentEventType.create);
    });
  });

  group('IncidentReducer hazard isolation', () {
    test('hazard report projects status and never enters help lifecycle', () {
      final p = IncidentReducer.project([
        hazard(
          seq: 0,
          minute: 0,
          status: IncidentMeshStatus.reported,
          updateType: IncidentUpdateType.initial,
        ),
        hazard(
          seq: 1,
          minute: 1,
          status: IncidentMeshStatus.active,
          updateType: IncidentUpdateType.update,
        ),
      ]);
      expect(p.workflowKind, IncidentWorkflowKind.hazardReport);
      expect(p.helpState, isNull);
      expect(p.hazardStatus, IncidentMeshStatus.active);
      expect(p.responderCount, 0);
      expect(p.participants, isEmpty);
      expect(p.locationSharing, isFalse);
      expect(p.isTerminal, isFalse);
    });

    test('hazard closure is terminal via status, not help lifecycle', () {
      final p = IncidentReducer.project([
        hazard(
          seq: 0,
          minute: 0,
          status: IncidentMeshStatus.reported,
          updateType: IncidentUpdateType.initial,
        ),
        hazard(
          seq: 1,
          minute: 1,
          status: IncidentMeshStatus.resolved,
          updateType: IncidentUpdateType.closure,
        ),
      ]);
      expect(p.helpState, isNull);
      expect(p.hazardStatus, IncidentMeshStatus.resolved);
      expect(p.isTerminal, isTrue);
    });

    test('hazard correction supersedes referenced seq', () {
      final p = IncidentReducer.project([
        hazard(
          seq: 0,
          minute: 0,
          status: IncidentMeshStatus.reported,
          updateType: IncidentUpdateType.initial,
        ),
        hazard(
          seq: 1,
          minute: 1,
          status: IncidentMeshStatus.active,
          updateType: IncidentUpdateType.correction,
          refSeq: 0,
        ),
      ]);
      // seq 0 superseded; effective status comes from the correction (seq 1).
      expect(p.hazardStatus, IncidentMeshStatus.active);
      final seq0 = p.timeline.firstWhere((e) => e.seq == 0);
      expect(seq0.isSuperseded, isTrue);
    });
  });
}
