// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  group('SipFeatureBits overlay bits', () {
    test('bit layout does not collide with v0.1 bits', () {
      const v01Mask = SipFeatureBits.allV01;
      expect(SipFeatureBits.overlayLinkV02 & v01Mask, equals(0));
      expect(SipFeatureBits.overlayResourceV02 & v01Mask, equals(0));
      expect(SipFeatureBits.overlaySecureV03 & v01Mask, equals(0));
    });

    test('overlay bits are all distinct', () {
      final bits = [
        SipFeatureBits.overlayLinkV02,
        SipFeatureBits.overlayResourceV02,
        SipFeatureBits.overlaySecureV03,
      ];
      expect(bits.toSet().length, equals(bits.length));
    });

    test('allV01 stays at 0x000B for wire compatibility', () {
      expect(SipFeatureBits.allV01, equals(0x000B));
    });
  });

  group('SipPeerCapability overlay accessors', () {
    SipPeerCapability make(int features) {
      return SipPeerCapability(
        nodeId: 0xDEADBEEF,
        features: features,
        deviceClass: 1,
        maxProtoMinor: 0,
        mtuHint: 200,
        rxWindowS: 10,
        capsHash: 0,
        lastSeenMs: 0,
      );
    }

    test('v0.1-only peer reports no overlay support', () {
      final peer = make(SipFeatureBits.allV01);
      expect(peer.supportsSip1, isTrue);
      expect(peer.supportsOverlayLinkV02, isFalse);
      expect(peer.supportsOverlayResourceV02, isFalse);
    });

    test('peer with link bit reports link support only', () {
      final peer = make(SipFeatureBits.allV01 | SipFeatureBits.overlayLinkV02);
      expect(peer.supportsOverlayLinkV02, isTrue);
      expect(peer.supportsOverlayResourceV02, isFalse);
    });

    test('peer with link + resource bits reports both', () {
      final peer = make(
        SipFeatureBits.allV01 |
            SipFeatureBits.overlayLinkV02 |
            SipFeatureBits.overlayResourceV02,
      );
      expect(peer.supportsOverlayLinkV02, isTrue);
      expect(peer.supportsOverlayResourceV02, isTrue);
    });
  });
}
