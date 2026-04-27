// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Focus-mode UX added to the Play composer panel:
///
///   - When a non-terminal SIP Play instance exists in the session,
///     the panel collapses to ONLY the resume banner. The "Play a
///     game" header, subtitle, and Tic-Tac-Toe card are hidden so
///     the user cannot start a duplicate game.
///   - When no active instance exists, the panel renders the
///     full picker layout (header + subtitle + TTT card).
///
/// Also pins the optimistic + interaction-lock invariants in the
/// active-game bubble:
///   - `_BoardSection` holds a local `_pendingMove` and an
///     `_interactionLock` flag,
///   - `didUpdateWidget` clears the pending overlay when the
///     engine state advances and the board cell now equals the
///     pending mark,
///   - `_IncomingOfferRow` carries a `_responding` flag with
///     PLAY_ACCEPT_TAP / SUCCESS / FAIL logging.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screenSrc = File(
    'lib/features/sip/sip_dm_screen.dart',
  ).readAsStringSync();
  final bubbleSrc = File(
    'lib/features/sip/play/sip_play_bubble.dart',
  ).readAsStringSync();

  group('Play composer panel — Focus mode', () {
    test('Focus-mode early-return renders only the resume banner', () {
      // The panel build must short-circuit on hasActiveInstance and
      // return the GameInProgressBanner-only layout. We pin both
      // ends of the early return.
      expect(
        screenSrc.contains('if (hasActiveInstance)'),
        isTrue,
        reason: 'panel must check hasActiveInstance to enter Focus mode',
      );
      // The early-return body uses the resume banner.
      final activeIdx = screenSrc.indexOf('if (hasActiveInstance) {');
      expect(activeIdx, greaterThan(0));
      // Find the closing of that block.
      final closingIdx = screenSrc.indexOf('}', activeIdx);
      final block = screenSrc.substring(activeIdx, closingIdx + 1);
      expect(
        block.contains('_GameInProgressBanner('),
        isTrue,
        reason: 'Focus-mode body must surface the resume banner',
      );
      expect(
        block.contains('_TicTacToeCard'),
        isFalse,
        reason: 'Focus-mode must hide the TTT card to prevent duplicates',
      );
      expect(
        block.contains('sipPlayPanelTitle'),
        isFalse,
        reason: 'Focus-mode hides the "Play a game" header',
      );
    });

    test('default mode (no active instance) renders title + subtitle '
        '+ TTT card', () {
      expect(screenSrc.contains('l10n.sipPlayPanelTitle'), isTrue);
      expect(screenSrc.contains('l10n.sipPlayPanelSubtitle'), isTrue);
      expect(screenSrc.contains('_TicTacToeCard('), isTrue);
    });

    test('hasActiveInstance is derived from the engine state — '
        'isTerminal is the gate', () {
      // Pure-replay invariant: the panel does NOT maintain its own
      // "is there a game running" flag. It reads SipPlayInstanceState
      // and checks isTerminal.
      expect(
        screenSrc.contains('!state.isTerminal'),
        isTrue,
        reason:
            'active-instance detection must consult engine state, not '
            'a local UI flag',
      );
    });
  });

  group('Active board — optimistic move + interaction lock', () {
    test('_BoardSection holds local pendingMove + interactionLock', () {
      expect(
        bubbleSrc.contains('TttMove? _pendingMove'),
        isTrue,
        reason: 'optimistic overlay state must live in widget State',
      );
      expect(bubbleSrc.contains('bool _interactionLock'), isTrue);
    });

    test('didUpdateWidget clears pendingMove when engine catches up', () {
      // The clear must compare the engine board cell to the pending
      // move's mark. Anything else risks leaving the overlay sticky
      // after a successful send.
      final start = bubbleSrc.indexOf('void didUpdateWidget(');
      expect(start, greaterThan(0));
      final end = bubbleSrc.indexOf('Widget build(', start);
      expect(end, greaterThan(start));
      final body = bubbleSrc.substring(start, end);
      expect(
        body.contains('boardCell == pending.mark'),
        isTrue,
        reason:
            'pending overlay clears only when the engine state shows '
            'the cell with the expected mark',
      );
      expect(body.contains('_pendingMove = null'), isTrue);
      expect(body.contains('_interactionLock = false'), isTrue);
    });

    test('failed send clears pendingMove (no sticky overlay)', () {
      // The _sendMove failure branch must call _clearPending, since
      // didUpdateWidget can\'t fire (engine never advanced).
      final start = bubbleSrc.indexOf('Future<void> _sendMove(');
      expect(start, greaterThan(0));
      final end = bubbleSrc.indexOf('void _clearPending(', start);
      expect(end, greaterThan(start));
      final body = bubbleSrc.substring(start, end);
      expect(
        body.contains('_clearPending();'),
        isTrue,
        reason:
            'failed send must clear the optimistic overlay so the '
            'cell does not stick visually',
      );
    });

    test('cell-tap path logs PLAY_MOVE_TAP with pending=true marker', () {
      expect(
        bubbleSrc.contains('PLAY_MOVE_TAP'),
        isTrue,
        reason: 'every cell tap must produce a structured log line',
      );
      expect(bubbleSrc.contains('pending=true'), isTrue);
      expect(
        bubbleSrc.contains('PLAY_MOVE_RESOLVED'),
        isTrue,
        reason:
            'resolution log line lets us measure UI → engine catch-up '
            'latency in the field',
      );
    });

    test('TttBoardWidget call passes the pendingMove from state', () {
      // The board widget exposes a pendingMove prop so the overlay
      // is centralised in the renderer. Pin the pass-through.
      expect(
        bubbleSrc.contains('pendingMove: _pendingMove'),
        isTrue,
        reason:
            '_BoardSectionState must forward _pendingMove to '
            'TttBoardWidget for the overlay to render',
      );
    });

    test('engine determinism preserved: _pendingMove is NEVER written '
        'to the entry log', () {
      // Defensive: the only writes to the entry log come from
      // sipDmRouterProvider.sendPlay — never from a pending-overlay
      // mutation. Pin by absence: nothing in the bubble file should
      // append to history directly.
      expect(
        bubbleSrc.contains('messages.add'),
        isFalse,
        reason:
            'only SipDmManager builds entries — bubble code must '
            'never append to the entry log directly',
      );
    });
  });

  group('Inbound offer — responding state + logging', () {
    test('_IncomingOfferRow holds local _responding flag', () {
      expect(bubbleSrc.contains('bool _responding ='), isTrue);
      expect(bubbleSrc.contains('bool _respondingAccept'), isTrue);
    });

    test('Accept / Decline buttons disable while responding', () {
      // The disabled check is a short circuit in onPressed — we pin
      // the predicate `disabled = peerBlocked || _responding`.
      expect(
        bubbleSrc.contains(
          'final disabled = widget.peerBlocked || _responding',
        ),
        isTrue,
      );
      expect(bubbleSrc.contains('onPressed: disabled ? null'), isTrue);
    });

    test('responding state surfaces a CircularProgressIndicator on the '
        'tapped button', () {
      expect(bubbleSrc.contains('CircularProgressIndicator'), isTrue);
    });

    test(
      'logging covers PLAY_ACCEPT and PLAY_DECLINE TAP / SUCCESS / FAIL',
      () {
        expect(bubbleSrc.contains('PLAY_ACCEPT_TAP'), isTrue);
        expect(bubbleSrc.contains('PLAY_ACCEPT_SUCCESS'), isTrue);
        expect(bubbleSrc.contains('PLAY_ACCEPT_FAIL'), isTrue);
        // DECLINE variants must be distinct so `PLAY_DECLINE_TAP` followed
        // by `PLAY_ACCEPT_SUCCESS` (the original mislog) can't recur.
        expect(bubbleSrc.contains('PLAY_DECLINE_TAP'), isTrue);
        expect(bubbleSrc.contains('PLAY_DECLINE_SUCCESS'), isTrue);
        expect(bubbleSrc.contains('PLAY_DECLINE_FAIL'), isTrue);
      },
    );
  });
}
