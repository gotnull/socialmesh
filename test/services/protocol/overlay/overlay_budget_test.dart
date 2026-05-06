// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Byte-budget invariants for the SocialMesh Overlay v0.2 stack.
///
/// These assertions guard the numeric relationships documented in
/// `docs/sip/OVERLAY_V0_2.md` §3 and §25. If a constant changes, this
/// test file is the first place to break — that is intentional.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';

void main() {
  group('Overlay v0.2 byte budget invariants', () {
    test('loraMtu matches the Meshtastic Data.payload ceiling', () {
      expect(OverlayLinkConstants.loraMtu, 237);
    });

    test('MRRP v0.2 header = 28 = base(20) + linkExtension(8)', () {
      expect(OverlayLinkConstants.baseMrrpHeader, 20);
      expect(OverlayLinkConstants.linkExtensionBytes, 8);
      expect(OverlayLinkConstants.headerLen, 28);
    });

    test('SIP wrapper and signed-trailer add up correctly', () {
      expect(OverlayLinkConstants.sipWrapperBytes, 22);
      expect(OverlayLinkConstants.sipSignedWrapperBytes, 88);
    });

    test('unsigned MRRP payload ceiling is 187 B', () {
      expect(OverlayLinkConstants.payloadCeilUnsigned, 187);
      expect(
        OverlayLinkConstants.payloadCeilUnsigned,
        OverlayLinkConstants.loraMtu -
            OverlayLinkConstants.sipWrapperBytes -
            OverlayLinkConstants.headerLen,
      );
    });

    test('signed MRRP payload ceiling is 121 B', () {
      expect(OverlayLinkConstants.payloadCeilSigned, 121);
      expect(
        OverlayLinkConstants.payloadCeilSigned,
        OverlayLinkConstants.loraMtu -
            OverlayLinkConstants.sipSignedWrapperBytes -
            OverlayLinkConstants.headerLen,
      );
    });

    test('SPP v0.2 header is 10 B', () {
      expect(OverlayResourceConstants.headerLen, 10);
    });

    test('unsigned chunk ceiling is 177 B (MRRP 187 - SPP 10)', () {
      expect(OverlayResourceConstants.chunkPayloadCeilUnsigned, 177);
    });

    test('signed chunk ceiling is 111 B (MRRP 121 - SPP 10)', () {
      expect(OverlayResourceConstants.chunkPayloadCeilSigned, 111);
    });

    test('default chunk (128 B) fits under both unsigned budgets', () {
      expect(
        OverlayResourceConstants.chunkSizeDefault,
        lessThanOrEqualTo(OverlayResourceConstants.chunkPayloadCeilUnsigned),
      );
    });

    test('secure chunk (96 B) fits under the signed ceiling', () {
      expect(
        OverlayResourceConstants.chunkSizeSecure,
        lessThanOrEqualTo(OverlayResourceConstants.chunkPayloadCeilSigned),
      );
    });

    test('resource cap fits a u16 chunk count at 128 B chunks', () {
      final chunks =
          (OverlayResourceConstants.maxResourceBytes +
              OverlayResourceConstants.chunkSizeDefault -
              1) ~/
          OverlayResourceConstants.chunkSizeDefault;
      expect(chunks, lessThanOrEqualTo(OverlayResourceConstants.maxChunkIndex));
    });

    test('capability block max fits in a single MRRP payload', () {
      // MRRP v0.1 payload ceiling is 195 (per MRRP spec). Capability
      // blocks ride inside ID_CLAIM alongside other TLVs, so this
      // invariant keeps the block well under that ceiling.
      expect(OverlayCapabilityConstants.maxBlockBytes, lessThan(195));
    });

    test('stale threshold is two ping periods', () {
      expect(
        OverlayLinkConstants.staleThresholdSec,
        2 * OverlayLinkConstants.pingCadenceSecMax,
      );
    });
  });
}
