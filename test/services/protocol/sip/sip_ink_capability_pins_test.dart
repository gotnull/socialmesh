// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression pins for the SIP Ink wire-level allocations.
///
/// These tests fail loudly if anyone (including a future "cleanup"
/// pass) re-numbers the SIP Ink message type, the `dmInkV1` feature
/// bit, or the secure-data subtype. Each value is in the
/// SIP_V0_1 §3.1 / §6 amendment and OVERLAY_V0_2 §25.5 spec — these
/// numbers are wire surface and cannot move without a protocol bump.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  group('SIP Ink wire pins', () {
    test('SipMessageType.dmInk = 0x45', () {
      expect(SipMessageType.dmInk.code, equals(0x45));
      expect(SipMessageType.fromCode(0x45), equals(SipMessageType.dmInk));
    });

    test('SipFeatureBits.dmInkV1 = bit 11 (0x0800)', () {
      expect(SipFeatureBits.dmInkV1, equals(1 << 11));
      expect(SipFeatureBits.dmInkV1, equals(0x0800));
    });

    test('dmInkV1 is NOT included in allV01 (additive amendment, '
        'older peers do not see it as part of baseline)', () {
      expect(SipFeatureBits.allV01 & SipFeatureBits.dmInkV1, equals(0));
    });

    test('dmInkV1 does not collide with any v0.1 / overlay capability '
        'bit', () {
      const otherBits = [
        SipFeatureBits.sip0,
        SipFeatureBits.sip1,
        SipFeatureBits.sip3,
        SipFeatureBits.overlayLinkV02,
        SipFeatureBits.overlayResourceV02,
        SipFeatureBits.overlaySecureV03,
      ];
      for (final bit in otherBits) {
        expect(
          SipFeatureBits.dmInkV1 & bit,
          equals(0),
          reason:
              'dmInkV1 (0x${SipFeatureBits.dmInkV1.toRadixString(16)}) '
              'overlaps with 0x${bit.toRadixString(16)}',
        );
      }
    });

    test('OverlaySecureDataSubtype.dmInk = 0x05', () {
      expect(OverlaySecureDataSubtype.dmInk.code, equals(0x05));
      expect(
        OverlaySecureDataSubtype.fromCode(0x05),
        equals(OverlaySecureDataSubtype.dmInk),
      );
    });

    test('Secure-data subtype 0x05 does not collide with any prior '
        'allocation', () {
      const priorSubtypes = [
        OverlaySecureDataSubtype.generic, // 0x01
        OverlaySecureDataSubtype.dmText, // 0x02
        OverlaySecureDataSubtype.dmReaction, // 0x03
        OverlaySecureDataSubtype.rpcEnvelope, // 0x04
      ];
      for (final s in priorSubtypes) {
        expect(
          s.code,
          isNot(equals(OverlaySecureDataSubtype.dmInk.code)),
          reason: '${s.name} shares code with dmInk',
        );
      }
    });
  });
}
