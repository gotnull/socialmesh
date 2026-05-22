// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('MrrpServiceId well-known constants', () {
    test('all existing service IDs are unchanged (regression pin)', () {
      expect(MrrpServiceId.meetupV1, 0x00000001);
      expect(MrrpServiceId.profileV1, 0x00000002);
      expect(MrrpServiceId.boardV1, 0x00000003);
      expect(MrrpServiceId.incidentV1, 0x00000004);
      expect(MrrpServiceId.petV1, 0x00000005);
      expect(MrrpServiceId.echoTest, 0xFFFF0001);
    });

    test('canvas.v1 is assigned 0x00000007', () {
      expect(MrrpServiceId.canvasV1, 0x00000007);
    });

    test('canvas.v1 does not collide with any other allocated id', () {
      final ids = <int>{
        MrrpServiceId.meetupV1,
        MrrpServiceId.profileV1,
        MrrpServiceId.boardV1,
        MrrpServiceId.incidentV1,
        MrrpServiceId.petV1,
        MrrpServiceId.canvasV1,
        MrrpServiceId.echoTest,
      };
      expect(ids.length, 7, reason: 'duplicate service id detected');
    });

    test('nameOf returns canonical strings for known ids', () {
      expect(MrrpServiceId.nameOf(MrrpServiceId.meetupV1), 'meetup.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.profileV1), 'profile.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.boardV1), 'board.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.incidentV1), 'incident.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.petV1), 'pet.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.canvasV1), 'canvas.v1');
      expect(MrrpServiceId.nameOf(MrrpServiceId.echoTest), 'echo.test');
    });

    test('nameOf returns hex placeholder for unknown ids', () {
      expect(MrrpServiceId.nameOf(0x00000099), '0x00000099');
    });
  });

  group('MrrpConstants regression pins', () {
    // canvas.v1 ships its own decoder-side per-sender cap inside
    // MrrpServiceCanvas (slice S5). The global MRRP cap MUST remain
    // unchanged so other services retain their conservative default.
    test('mrrpMaxInboundRequestsPerSenderPer60s stays at 4', () {
      expect(MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s, 4);
    });
  });
}
