// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the SIP Signal v1 UI/composer wiring inside the existing
/// SIP DM screen. Grep-based — no Flutter widget tree pumped — so
/// the assertions stay valid as the screen evolves and we don't have
/// to mock the entire DM stack.
///
/// Hard rules pinned here:
///   - The rich-composer tab enum carries `signal` alongside `sketch`
///     and `play` (text is the always-on inline composer, intentionally
///     not in this enum).
///   - The Signal tab is gated by `enabled && peerSupportsSignal &&
///     !peerBlocked` — same shape as the Play tab.
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
    test('rich-composer tab enum includes signal', () {
      expect(
        RegExp(
          r'enum\s+_RichComposerTab\s*\{\s*sketch\s*,\s*play\s*,\s*signal\s*\}',
        ).hasMatch(screenSrc),
        isTrue,
        reason:
            'Signal must be a tab inside the rich-composer sheet '
            'alongside Sketch and Play. Text is intentionally absent — '
            'it is the always-on inline composer.',
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

    test('Signal panel renders inside the rich-composer sheet, not inline', () {
      // After the inline-mode-switcher → bottom-sheet refactor, the
      // signal panel is one of the IndexedStack children INSIDE
      // `_RichComposerSheet`. Pin both the host and the construction.
      expect(
        screenSrc.contains('class _RichComposerSheet'),
        isTrue,
        reason:
            'Sketch / Play / Signal live inside _RichComposerSheet now; '
            'the inline _ComposerModeSwitcher was removed because the '
            'inline height transitions caused the user-reported jolt.',
      );
      expect(
        screenSrc.contains('SipSignalComposerPanel(sessionTag:'),
        isTrue,
        reason: 'Signal panel is one of the IndexedStack children.',
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
            'the trigger / sheet tab strip reacts to peer-capability '
            'updates.',
      );
    });

    test('peerSupportsSignal reads supportsDmSignalV1 from discovery', () {
      expect(
        screenSrc.contains('peer?.supportsDmSignalV1 ?? false'),
        isTrue,
        reason: 'peer-feature gate must consult the discovery cache',
      );
    });

    test('the rich-composer trigger only appears when at least one rich '
        'tab is reachable', () {
      // The trigger button on the inline ChatComposer is gated by
      // `showComposerTrigger = showSketchTab || showPlayTab ||
      // showSignalTab` — peers without any rich cap see no attach
      // button at all.
      expect(
        RegExp(
          r'showComposerTrigger\s*=\s*'
          r'showSketchTab\s*\|\|\s*showPlayTab\s*\|\|\s*showSignalTab',
        ).hasMatch(screenSrc),
        isTrue,
      );
    });

    test('signal label still uses the existing ARB key', () {
      expect(screenSrc.contains('l10n.sipDmComposerModeSignal'), isTrue);
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
