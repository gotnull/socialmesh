// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the SIP Signal v1 UI/composer wiring inside the existing
/// SIP DM screen. Grep-based — no Flutter widget tree pumped — so
/// the assertions stay valid as the screen evolves and we don't have
/// to mock the entire DM stack.
///
/// Hard rules pinned here:
///   - The composer-mode enum carries `signal` alongside text /
///     sketch / play.
///   - The Signal tab is gated by `enabled && peerSupportsSignal &&
///     !peerBlocked` — same shape as the Play tab.
///   - The composer-mode switcher renders the Signal segment
///     conditionally on `showSignal`.
///   - The bubble dispatcher routes `SipDmContentType.signal` entries
///     to `SipSignalBubble` and skips the reactions / reply-quote
///     affordances.
///   - The Signal panel routes through the existing
///     `sipDmRouterProvider.sendSignal` — no new transport.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screenSrc = File(
    'lib/features/sip/sip_dm_screen.dart',
  ).readAsStringSync();
  final panelSrc = File(
    'lib/features/sip/signal/sip_signal_composer_panel.dart',
  ).readAsStringSync();
  final bubbleSrc = File(
    'lib/features/sip/signal/sip_signal_bubble.dart',
  ).readAsStringSync();

  group('Composer mode integration', () {
    test('enum carries text, sketch, play, AND signal', () {
      expect(
        RegExp(
          r'enum\s+_SipDmComposerMode\s*\{\s*text\s*,\s*sketch\s*,\s*play\s*,\s*signal',
        ).hasMatch(screenSrc),
        isTrue,
        reason: 'composer enum must include all four modes',
      );
    });

    test('Signal tab is gated by enabled + peerSupportsSignal + '
        '!peerBlocked', () {
      expect(
        RegExp(
          r'showSignalTab\s*=\s*enabled\s*&&\s*peerSupportsSignal\s*&&\s*!peerBlocked',
        ).hasMatch(screenSrc),
        isTrue,
        reason:
            'Signal tab visibility must combine session-active, peer '
            'capability, and the T+S block check (same shape as Play)',
      );
    });

    test('composer body keeps every visible panel mounted via Visibility + '
        'maintainState so Signal drafts survive tab toggles', () {
      // Switching from Signal → Text → Signal used to dispose the
      // SipSignalComposerPanel's State, losing the phrase draft and
      // the tap-Morse buffer. The fix wraps each panel in
      // `Visibility(maintainState: true)`: visible: false swaps the
      // rendered subtree for SizedBox.shrink (zero layout cost) but
      // the StatefulElement stays alive so all panel-local fields
      // (and TextEditingControllers) survive.
      expect(
        screenSrc.contains('maintainState: true'),
        isTrue,
        reason:
            'Composer panels must use Visibility(maintainState: true) so '
            'mode toggles don\'t dispose their State.',
      );
      expect(
        RegExp(r'Visibility\(\s*visible: isSignal').hasMatch(screenSrc),
        isTrue,
        reason:
            'Signal panel must be wrapped in a Visibility keyed off '
            'isSignal so it stays mounted while another tab is active.',
      );
      // IndexedStack would size to the tallest child even when
      // hidden — we picked Visibility to avoid that. Pin that the
      // composer source doesn't construct one (the doc comment may
      // mention the type, so we look for the constructor call).
      expect(
        screenSrc.contains('IndexedStack('),
        isFalse,
        reason:
            'Composer must not construct IndexedStack (it sizes to the '
            'tallest child, eating chat-list vertical space). Use '
            'Visibility + maintainState instead.',
      );
    });

    test('DM screen build watches sipPeerCacheEpochProvider so cap-bit '
        'updates from CAP_BEACON / ROLLCALL_RESP rebuild the tab strip', () {
      // Field-bug fix: passive discovery inserts a `features=sip0`
      // placeholder; the real caps land moments later via CAP_BEACON
      // or ROLLCALL_RESP (`peer 0x... caps updated, features=0x3f0b`
      // in logs). Without watching the cache epoch, the Sketch /
      // Play / Signal tabs stayed hidden until an unrelated rebuild
      // tripped the screen.
      expect(
        RegExp(
          r'ref\.watch\(\s*sipPeerCacheEpochProvider\s*\)',
        ).hasMatch(screenSrc),
        isTrue,
        reason:
            'sip_dm_screen.build must watch sipPeerCacheEpochProvider so '
            'the tab strip reacts to peer-capability updates.',
      );
    });

    test('peerSupportsSignal reads supportsDmSignalV1 from discovery', () {
      expect(
        screenSrc.contains('peer?.supportsDmSignalV1 ?? false'),
        isTrue,
        reason: 'peer-feature gate must consult the discovery cache',
      );
    });

    test('blocked peer triggers a fallback to text mode (no orphan tab)', () {
      expect(
        screenSrc.contains(
          '_composerMode == _SipDmComposerMode.signal && !showSignalTab',
        ),
        isTrue,
      );
    });

    test('switcher takes a showSignal flag + renders the Signal label', () {
      expect(screenSrc.contains('required this.showSignal'), isTrue);
      expect(screenSrc.contains('l10n.sipDmComposerModeSignal'), isTrue);
      expect(screenSrc.contains('showSignal: showSignalTab'), isTrue);
    });

    test('Signal body branch routes to SipSignalComposerPanel', () {
      expect(
        screenSrc.contains(
          'SipSignalComposerPanel(sessionTag: widget.sessionTag)',
        ),
        isTrue,
        reason:
            'Signal mode must surface the dedicated composer panel — '
            'no overload of text / sketch / play surfaces',
      );
    });
  });

  group('Bubble dispatch', () {
    test('isSignal predicate gates SipSignalBubble in _MessageBubble', () {
      expect(
        screenSrc.contains(
          'entry.contentType == SipDmContentType.signal && entry.payload != null',
        ),
        isTrue,
      );
      expect(screenSrc.contains('SipSignalBubble('), isTrue);
    });

    test('Signal bubble path skips reactions / reply-quote (consistent '
        'with Ink + Play)', () {
      // Pin the early return — Signal bubble uses its own minimal
      // surface; the heavy text-bubble Column never wraps it.
      expect(
        RegExp(
          r'if\s*\(isSignal\)\s*\{[\s\S]{0,500}SipSignalBubble',
        ).hasMatch(screenSrc),
        isTrue,
      );
    });
  });

  group('Composer panel internals', () {
    test('Tone + Morse sub-modes both present', () {
      expect(panelSrc.contains('_SignalSubMode.tone'), isTrue);
      expect(panelSrc.contains('_SignalSubMode.morse'), isTrue);
    });

    test('Send routes through sipDmRouterProvider.sendSignal — no '
        'separate transport', () {
      expect(panelSrc.contains('sipDmRouterProvider'), isTrue);
      expect(panelSrc.contains('router.sendSignal('), isTrue);
      expect(
        panelSrc.contains('messages.add'),
        isFalse,
        reason:
            'composer must NOT append history entries directly — only '
            'SipDmManager.buildSignalMessage does that',
      );
    });

    test('Send gate routes through the live-encoded-bytes predicate, which '
        'rejects empty drafts AND drafts that exceed the envelope cap', () {
      // The unified `_canSend` derives from the encoder's actual output,
      // so an empty draft naturally returns null/false and a draft that
      // exceeds maxEnvelopeBytes naturally fails the comparison. This
      // replaces the previous hand-rolled per-sub-mode predicates.
      expect(
        panelSrc.contains('final bytes = _liveEncodedBytes();'),
        isTrue,
        reason: 'Send predicate must consult the live-encoded byte counter',
      );
      expect(
        panelSrc.contains('bytes <= SipSignalConstants.maxEnvelopeBytes'),
        isTrue,
        reason: 'Send must require the encoded envelope to fit in budget',
      );
      // The Morse draft path goes through the unified `_currentMorseText`
      // accessor so tap-mode and type-mode share the same gating logic.
      expect(
        panelSrc.contains('_currentMorseText()'),
        isTrue,
        reason:
            'Morse encoding must read from _currentMorseText so Tap and '
            'Type sub-modes share one source of truth',
      );
      expect(
        panelSrc.contains('MorseTable.filtered'),
        isTrue,
        reason: 'Morse send must filter unsupported characters before encode',
      );
    });

    test('phrase tap appends a note (capped at maxPhraseNotes)', () {
      expect(
        panelSrc.contains(
          '_phraseDraft.length >= SipSignalConstants.maxPhraseNotes',
        ),
        isTrue,
      );
      expect(panelSrc.contains('_phraseDraft.add'), isTrue);
    });

    test(
      'Preview uses sipSignalSynthServiceProvider — local synthesis only',
      () {
        expect(panelSrc.contains('sipSignalSynthServiceProvider'), isTrue);
        expect(panelSrc.contains('synth.playPhrase'), isTrue);
        expect(panelSrc.contains('synth.playMorse'), isTrue);
      },
    );

    test('logs cover composer_opened, note_appended, preview, send', () {
      expect(panelSrc.contains('composer_opened'), isTrue);
      expect(panelSrc.contains('note_appended'), isTrue);
      expect(panelSrc.contains('preview phrase'), isTrue);
      expect(panelSrc.contains('preview morse'), isTrue);
      expect(panelSrc.contains('send_attempt'), isTrue);
    });
  });

  group('Bubble internals', () {
    test('Phrase variant shows note names + Replay; Morse variant '
        'shows BOTH text AND pattern + Replay', () {
      expect(bubbleSrc.contains('class _PhraseBubbleBody'), isTrue);
      expect(bubbleSrc.contains('class _MorseBubbleBody'), isTrue);
      // Morse bubble must render the original text first, then the
      // pattern — that's the whole point of carrying text on the
      // wire instead of dot/dash strings.
      final start = bubbleSrc.indexOf('class _MorseBubbleBody');
      final end = bubbleSrc.indexOf('class _MalformedBubble', start);
      final body = bubbleSrc.substring(start, end);
      expect(body.contains('morse.text'), isTrue);
      expect(body.contains('MorseTable.render'), isTrue);
      expect(body.contains('sipSignalReplay'), isTrue);
    });

    test('Replay routes to sipSignalSynthServiceProvider — receiver '
        'never relies on wire-borne audio', () {
      expect(bubbleSrc.contains('sipSignalSynthServiceProvider'), isTrue);
      expect(bubbleSrc.contains('playPhrase'), isTrue);
      expect(bubbleSrc.contains('playMorse'), isTrue);
    });

    test('malformed bubble renders the safe fallback title', () {
      expect(bubbleSrc.contains('class _MalformedBubble'), isTrue);
      expect(bubbleSrc.contains('sipSignalBubbleMalformed'), isTrue);
    });
  });
}
