// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Phase 8 consent-UI invariants. The two consent-bearing
/// screens (`sip_hub_screen.dart` `_IncomingRequestTile` and
/// `mesh_explorer_peer_detail_sheet.dart` `_onBlock`) MUST:
///
///   1. Persist a block via `peerSafetyManagerProvider.notifier`'s
///      `block(...)` call. This makes future inbound HELLO / DM /
///      MRRP frames from the peer hit the protocol-layer safety gate.
///
///   2. Silently clear the pending consent state by calling
///      `cancelSipHandshake` (NOT `declineSipHandshake`). Block must
///      never emit a HS_DECLINE on the wire — that would confirm to
///      the peer that we exist and saw their request. Block makes
///      the peer see "node unreachable."
///
///   3. Gate the Block action behind a destructive confirm sheet
///      (`AppBottomSheet.showConfirm(... isDestructive: true)`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIP Hub _IncomingRequestTile Block wiring', () {
    final src = File('lib/features/sip/sip_hub_screen.dart').readAsStringSync();

    test('imports peer_safety_providers + app_bottom_sheet', () {
      expect(src.contains('peer_safety_providers.dart'), isTrue);
      expect(src.contains('app_bottom_sheet.dart'), isTrue);
    });

    test('exposes a Block button label via l10n.sipHubBlock', () {
      expect(src.contains('l10n.sipHubBlock'), isTrue);
    });

    test('Block path persists block via peerSafetyManagerProvider', () {
      // The Block confirm path must call PeerSafetyManager.block.
      // Grep is intentionally loose — anchored on the provider name +
      // the method — so reformatting won't break it.
      expect(src.contains('peerSafetyManagerProvider.notifier'), isTrue);
      expect(
        RegExp(r'\.block\(\s*peerNodeId').hasMatch(src),
        isTrue,
        reason: 'Block path must call peerSafetyManager.block(peerNodeId, ...)',
      );
    });

    test('Block path cancels via cancelSipHandshake (silent), '
        'NOT declineSipHandshake (wire)', () {
      expect(
        src.contains('cancelSipHandshake(peerNodeId)'),
        isTrue,
        reason:
            'Block must silently drop the pending request via '
            'cancelSipHandshake — it must NOT emit a HS_DECLINE on '
            'the wire',
      );
    });

    test('Block path is gated by an isDestructive confirm sheet', () {
      expect(
        src.contains('AppBottomSheet.showConfirm'),
        isTrue,
        reason: 'Block must be confirmed via AppBottomSheet.showConfirm',
      );
      expect(
        src.contains('isDestructive: true'),
        isTrue,
        reason: 'Block confirm sheet must be flagged isDestructive',
      );
      expect(src.contains('l10n.sipHubBlockConfirmTitle'), isTrue);
      expect(src.contains('l10n.sipHubBlockConfirmBody'), isTrue);
    });

    test('Consent body copy is rendered above the action row', () {
      expect(
        src.contains('l10n.sipHubConsentBody'),
        isTrue,
        reason:
            'Accept/Decline/Block must be preceded by an explanation '
            'of what tapping Accept enables',
      );
    });
  });

  group('Mesh Explorer peer detail sheet Block wiring', () {
    final src = File(
      'lib/features/mesh_explorer/widgets/'
      'mesh_explorer_peer_detail_sheet.dart',
    ).readAsStringSync();

    test('imports peer_safety_providers + app_bottom_sheet', () {
      expect(src.contains('peer_safety_providers.dart'), isTrue);
      expect(src.contains('app_bottom_sheet.dart'), isTrue);
    });

    test('Block path persists block via peerSafetyManagerProvider', () {
      expect(src.contains('peerSafetyManagerProvider.notifier'), isTrue);
      expect(
        RegExp(r'\.block\(\s*peer\.nodeId').hasMatch(src),
        isTrue,
        reason:
            'Mesh Explorer Block must call '
            'peerSafetyManager.block(peer.nodeId, ...)',
      );
    });

    test('Block path uses cancelSipHandshake (silent drop), '
        'NOT declineSipHandshake', () {
      expect(
        src.contains('cancelSipHandshake(peer.nodeId)'),
        isTrue,
        reason:
            'Mesh Explorer Block must clear pending state without '
            'emitting HS_DECLINE',
      );
    });

    test('Block path is gated by an isDestructive confirm sheet', () {
      expect(src.contains('AppBottomSheet.showConfirm'), isTrue);
      expect(src.contains('isDestructive: true'), isTrue);
      expect(src.contains('l10n.meshExplorerBlockConfirmTitle'), isTrue);
      expect(src.contains('l10n.meshExplorerBlockConfirmBody'), isTrue);
    });
  });

  group('First-contact banner wiring', () {
    final src = File('lib/features/sip/sip_dm_screen.dart').readAsStringSync();

    test('imports peer_safety_providers + status_banner', () {
      expect(src.contains('peer_safety_providers.dart'), isTrue);
      expect(src.contains('status_banner.dart'), isTrue);
    });

    test('renders a _FirstContactBanner widget tied to the session peer', () {
      expect(
        src.contains('_FirstContactBanner('),
        isTrue,
        reason: 'sip_dm_screen.dart must render _FirstContactBanner',
      );
      expect(
        src.contains('_FirstContactBanner({required this.peerNodeId})'),
        isTrue,
        reason:
            'banner must be parameterised by peerNodeId so the gate '
            'and dismissal lookup are per-peer',
      );
    });

    test('banner gate reads hasFirstContact AND isDismissed', () {
      expect(src.contains('hasFirstContact(peerNodeId)'), isTrue);
      expect(src.contains('isDismissed(peerNodeId)'), isTrue);
    });

    test('banner dismiss path goes through '
        'firstContactBannerDismissalsProvider, NOT markFirstHandshake', () {
      expect(src.contains('firstContactBannerDismissalsProvider'), isTrue);
      // The banner must not piggyback on markFirstHandshake — the
      // first-contact mark is reserved for explicit Accept taps.
      // Search the banner widget body specifically.
      final bannerStart = src.indexOf('class _FirstContactBanner');
      final bannerEnd = src.indexOf('class _SessionInfoBar', bannerStart);
      expect(
        bannerStart,
        greaterThan(0),
        reason: '_FirstContactBanner class must exist',
      );
      expect(
        bannerEnd,
        greaterThan(bannerStart),
        reason: '_SessionInfoBar must follow _FirstContactBanner',
      );
      final bannerBody = src.substring(bannerStart, bannerEnd);
      expect(
        bannerBody.contains('markFirstHandshake'),
        isFalse,
        reason:
            'banner dismissal MUST NOT call markFirstHandshake — '
            'that mark is reserved for explicit Accept-tap consent',
      );
      expect(
        bannerBody.contains('declineSipHandshake'),
        isFalse,
        reason: 'banner must not mutate handshake state',
      );
      expect(
        bannerBody.contains('cancelSipHandshake'),
        isFalse,
        reason: 'banner must not mutate handshake state',
      );
    });
  });
}
