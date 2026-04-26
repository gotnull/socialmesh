// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Phase 9 DM overflow menu invariants. The four T+S
/// actions in `sip_dm_screen.dart` MUST stay separated:
///
///   - Mute  = notifications only. Reversible toggle. No confirm.
///             Calls peerSafetyManager.mute / .unmute.
///   - Block = persist block via PeerSafetyManager.block. Calls NO
///             history-clearing surface and NO wire frame.
///   - Reset = drop secure session via
///             OverlaySecureSessionManager.resetSession. Looks up
///             canonical link via overlayLinkStore.
///   - Remove = clear local conversation via
///              SipDmManager.removeSessionLocally. NO DM_CLOSE on
///              the wire — must NOT call closeSession.
///
/// Block, Reset, Remove all gate on
/// AppBottomSheet.showConfirm(... isDestructive: true). Mute is a
/// direct toggle.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/features/sip/sip_dm_screen.dart').readAsStringSync();

  group('SIP DM overflow menu — required imports', () {
    test('imports peer_safety_providers, overlay_providers, '
        'app_bottom_sheet', () {
      expect(src.contains('peer_safety_providers.dart'), isTrue);
      expect(src.contains('overlay_providers.dart'), isTrue);
      expect(src.contains('app_bottom_sheet.dart'), isTrue);
    });
  });

  group('Mute action', () {
    test('reads / mutates via PeerSafetyManager mute + unmute', () {
      expect(
        RegExp(r'\.mute\(\s*session\.peerNodeId').hasMatch(src),
        isTrue,
        reason: 'Mute must call peerSafetyManager.mute(peerNodeId)',
      );
      expect(
        RegExp(r'\.unmute\(\s*session\.peerNodeId').hasMatch(src),
        isTrue,
        reason: 'Mute toggle must support unmute path',
      );
      expect(src.contains('isMuted(session.peerNodeId)'), isTrue);
    });

    test('mute toggle does NOT route through showConfirm '
        '(reversible, non-destructive)', () {
      // The _onToggleMute method body must contain no
      // showConfirm call. Locate the method and check.
      final start = src.indexOf('Future<void> _onToggleMute(');
      expect(start, greaterThan(0), reason: '_onToggleMute must exist');
      // Find the matching method end by scanning to the next method
      // signature in this section.
      final next = src.indexOf('Future<void> _onBlockPeer(', start);
      expect(next, greaterThan(start));
      final body = src.substring(start, next);
      expect(
        body.contains('showConfirm'),
        isFalse,
        reason:
            'Mute is a reversible toggle and must NOT prompt a '
            'destructive confirm sheet',
      );
    });
  });

  group('Block action', () {
    test('persists via PeerSafetyManager.block, NOT closeSession', () {
      final start = src.indexOf('Future<void> _onBlockPeer(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<void> _onResetSecureSession(', start);
      expect(next, greaterThan(start));
      final body = src.substring(start, next);

      expect(
        RegExp(r'\.block\(\s*session\.peerNodeId').hasMatch(body),
        isTrue,
        reason: 'Block must call peerSafetyManager.block(peerNodeId, ...)',
      );
      expect(
        body.contains('closeSession'),
        isFalse,
        reason:
            'Block must NOT call closeSession — that emits DM_CLOSE '
            'on the wire',
      );
      expect(
        body.contains('removeSessionLocally'),
        isFalse,
        reason:
            'Block preserves local history per Phase 9 spec — must '
            'NOT call removeSessionLocally',
      );
      expect(
        body.contains('resetSession'),
        isFalse,
        reason: 'Block must NOT touch the secure session',
      );
    });

    test('Block is gated by an isDestructive confirm sheet', () {
      expect(src.contains('l10n.sipDmBlockConfirmTitle'), isTrue);
      expect(src.contains('l10n.sipDmBlockConfirmBody'), isTrue);
    });
  });

  group('Reset secure session action', () {
    test('drops keys via OverlaySecureSessionManager.resetSession only', () {
      final start = src.indexOf('Future<void> _onResetSecureSession(');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<void> _onRemoveConversation(', start);
      expect(next, greaterThan(start));
      final body = src.substring(start, next);

      expect(
        body.contains('overlaySecureSessionManagerProvider'),
        isTrue,
        reason: 'Reset must read overlaySecureSessionManagerProvider',
      );
      expect(
        RegExp(r'resetSession\(\s*canonical\.linkId').hasMatch(body),
        isTrue,
        reason: 'Reset must call resetSession(linkId) on canonical link',
      );
      expect(
        body.contains('getNonTerminalForPeerNode(session.peerNodeId)'),
        isTrue,
        reason: 'Reset must look up canonical link via overlayLinkStore',
      );
      expect(
        body.contains('removeSessionLocally'),
        isFalse,
        reason: 'Reset must NOT clear local history',
      );
      expect(
        body.contains('closeSession'),
        isFalse,
        reason: 'Reset must NOT emit DM_CLOSE',
      );
      expect(
        RegExp(r'\.block\(').hasMatch(body),
        isFalse,
        reason: 'Reset must NOT block the peer',
      );
    });

    test('Reset is gated by an isDestructive confirm sheet', () {
      expect(src.contains('l10n.sipDmResetConfirmTitle'), isTrue);
      expect(src.contains('l10n.sipDmResetConfirmBody'), isTrue);
    });
  });

  group('Remove conversation action', () {
    test('clears local history via removeSessionLocally, NOT closeSession', () {
      final start = src.indexOf('Future<void> _onRemoveConversation(');
      expect(start, greaterThan(0));
      // Scan to the next method or class boundary.
      final next = src.indexOf('\n  Widget ', start) > 0
          ? src.indexOf('\n  Widget ', start)
          : src.length;
      final body = src.substring(start, next);

      expect(
        RegExp(r'removeSessionLocally\(\s*widget\.sessionTag').hasMatch(body),
        isTrue,
        reason:
            'Remove must call SipDmManager.removeSessionLocally — no '
            'wire frame emitted',
      );
      expect(
        body.contains('closeSession'),
        isFalse,
        reason:
            'Remove must NOT call closeSession — that would emit '
            'DM_CLOSE and notify the peer',
      );
      expect(
        RegExp(r'\.block\(').hasMatch(body),
        isFalse,
        reason: 'Remove must NOT auto-block the peer',
      );
      expect(
        body.contains('resetSession'),
        isFalse,
        reason: 'Remove must NOT reset the secure session',
      );
    });

    test('Remove is gated by an isDestructive confirm sheet', () {
      expect(src.contains('l10n.sipDmRemoveConfirmTitle'), isTrue);
      expect(src.contains('l10n.sipDmRemoveConfirmBody'), isTrue);
    });
  });

  group('Overflow menu structure', () {
    test('exposes all five actions: mute, block, reset_secure, '
        'remove, close', () {
      final menuStart = src.indexOf('Widget _buildOverflowMenu(');
      expect(menuStart, greaterThan(0));
      // Scan to the closing of the build method by looking for the
      // next top-level method signature.
      final menuEnd = src.indexOf('Future<void> _onToggleMute(', menuStart);
      expect(menuEnd, greaterThan(menuStart));
      final menu = src.substring(menuStart, menuEnd);

      expect(menu.contains("value: 'mute'"), isTrue);
      expect(menu.contains("value: 'block'"), isTrue);
      expect(menu.contains("value: 'reset_secure'"), isTrue);
      expect(menu.contains("value: 'remove'"), isTrue);
      expect(menu.contains("value: 'close'"), isTrue);
    });
  });
}
