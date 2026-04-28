// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Phase 10 SIP Hub Blocked section invariants:
///
///   - Active lists (Incoming requests, Conversations, Discovered
///     peers) are filtered against `blockedPeerNodeIdsProvider` so
///     blocked peers don't surface there. Filtering is render-layer
///     only and must NOT mutate any session / protocol state.
///   - The Blocked section auto-hides when the blocked list is
///     empty.
///   - Tapping Unblock opens an `AppBottomSheet.showConfirm` sheet
///     and only then calls `peerSafetyManager.unblock`. There is no
///     direct unblock surface that bypasses the confirm.
///   - The Blocked section's tile must NOT call any session-creation
///     surface (`acceptSipHandshake`, `initiateHandshake`, `block`,
///     `cancelSipHandshake`, `removeSessionLocally`, `closeSession`,
///     `resetSession`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/features/sip/sip_hub_screen.dart').readAsStringSync();

  group('SIP Hub render-layer filter', () {
    test('reads blockedPeerNodeIdsProvider in build()', () {
      expect(
        src.contains('ref.watch(blockedPeerNodeIdsProvider)'),
        isTrue,
        reason:
            'Build must watch blockedPeerNodeIdsProvider so the lists '
            'rebuild on Block / Unblock',
      );
    });

    test('filters pendingRequestNodeIds against the blocked set', () {
      expect(
        src.contains('filteredPendingRequests'),
        isTrue,
        reason: 'Pending requests list must be filter-derived',
      );
      expect(
        RegExp(
          r'pendingRequestNodeIds[\s\S]{0,200}!blockedSet\.contains',
        ).hasMatch(src),
        isTrue,
        reason:
            'Pending request filtering must check blockedSet '
            'membership',
      );
    });

    test('filters sessions against the blocked set', () {
      expect(src.contains('filteredSessions'), isTrue);
      expect(
        RegExp(
          r'sessions[\s\S]{0,200}!blockedSet\.contains\(s\.peerNodeId',
        ).hasMatch(src),
        isTrue,
        reason: 'Conversations filter must drop blocked peers',
      );
    });

    test('filters discovered peers against the blocked set', () {
      expect(
        RegExp(
          r'unconnectedPeers[\s\S]{0,400}!blockedSet\.contains\(p\.nodeId',
        ).hasMatch(src),
        isTrue,
        reason: 'Discovered peers filter must drop blocked peers',
      );
    });
  });

  group('Blocked section structure', () {
    test('section is gated on blockedPeerNodeIds.isNotEmpty '
        '(auto-hides when empty)', () {
      expect(
        RegExp(
          r'if\s*\(\s*blockedPeerNodeIds\.isNotEmpty\s*\)\s*[\s\S]{0,300}_BlockedPeersSection',
        ).hasMatch(src),
        isTrue,
        reason: 'Blocked section must render only when blocked is non-empty',
      );
    });

    test('uses ExpansionTile (collapsed by default — no '
        'initiallyExpanded: true)', () {
      // Find the section class body.
      final start = src.indexOf('class _BlockedPeersSection');
      expect(start, greaterThan(0));
      final next = src.indexOf('class _BlockedPeerTile', start);
      expect(next, greaterThan(start));
      final body = src.substring(start, next);
      expect(body.contains('ExpansionTile('), isTrue);
      expect(
        body.contains('initiallyExpanded: true'),
        isFalse,
        reason:
            'Blocked section must collapse by default — leaving it '
            'expanded draws unwanted attention',
      );
    });

    test('uses _BlockedPeerTile children driven by '
        'blockedPeerNodeIds list', () {
      expect(src.contains('_BlockedPeerTile(peerNodeId:'), isTrue);
    });
  });

  group('Unblock action', () {
    test('routes through AppBottomSheet.showConfirm before '
        'calling unblock', () {
      final start = src.indexOf('Future<void> _onUnblock(');
      expect(start, greaterThan(0));
      // Find the end by scanning to the next class / top-level
      // boundary.
      final end = src.indexOf('\n}\n', start);
      final body = src.substring(start, end > 0 ? end : src.length);

      expect(
        body.contains('AppBottomSheet.showConfirm'),
        isTrue,
        reason: 'Unblock must prompt a confirm sheet',
      );
      // Confirm guard MUST come before the unblock call. Verify by
      // string position.
      final confirmIdx = body.indexOf('showConfirm');
      final unblockIdx = body.indexOf('manager.unblock(peerNodeId)');
      expect(confirmIdx, greaterThan(0));
      expect(unblockIdx, greaterThan(confirmIdx));
    });

    test('does NOT mutate any other safety / protocol surface', () {
      final start = src.indexOf('class _BlockedPeerTile');
      expect(start, greaterThan(0));
      final body = src.substring(start);
      // The tile body should reference unblock only; not block,
      // mute, accept/decline, cancelSipHandshake, sendSipPacket,
      // session-creation, etc.
      const banned = [
        'acceptSipHandshake',
        'declineSipHandshake',
        'cancelSipHandshake',
        'closeSession',
        'removeSessionLocally',
        'resetSession',
        'initiateHandshake',
        'sendSipPacket',
        'markFirstHandshake',
      ];
      for (final s in banned) {
        expect(
          body.contains(s),
          isFalse,
          reason:
              '_BlockedPeerTile must not call $s — Phase 10 spec '
              'requires render-layer purity',
        );
      }
      // Block-from-blocked-section also makes no sense — this is a
      // list of already-blocked peers. Verify no `.block(` call.
      expect(
        RegExp(r'\.block\(\s*peerNodeId').hasMatch(body),
        isFalse,
        reason: '_BlockedPeerTile must not re-block an already-blocked peer',
      );
    });
  });
}
