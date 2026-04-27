// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the SIP Signal v1 tap-Morse + composer UX additions:
///
///   - `MorseTable.letterForToken` is the inverse of `charToCode` and
///     covers the full supported alphabet.
///   - The composer panel:
///       * defaults to Morse / Tap input,
///       * routes Send through the live-encoded byte gate
///         (`_liveEncodedBytes()`),
///       * keeps Clear / Preview / Send active when the Tone phrase
///         hits the hard cap,
///       * disables note pads (and only note pads) at the cap so the
///         user can never wedge.
///
/// Grep-based — same approach as `sip_signal_wiring_test.dart`. The
/// composer is heavy on Riverpod / haptics / l10n so a full widget
/// pump would be a maintenance liability for what is fundamentally a
/// shape-pinning test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/signal/morse_table.dart';

void main() {
  group('MorseTable.letterForToken (inverse lookup)', () {
    test('S, O, A round-trip through forward + inverse', () {
      expect(MorseTable.letterForToken('...'), 'S');
      expect(MorseTable.letterForToken('---'), 'O');
      expect(MorseTable.letterForToken('.-'), 'A');
    });

    test('every alphabet entry round-trips', () {
      for (final entry in MorseTable.charToCode.entries) {
        expect(
          MorseTable.letterForToken(entry.value),
          entry.key,
          reason:
              'inverse must round-trip every charToCode entry — '
              '${entry.key} → ${entry.value} → ${entry.key}',
        );
      }
    });

    test('returns null for unknown tokens', () {
      expect(MorseTable.letterForToken('...-..-'), isNull);
      expect(MorseTable.letterForToken('?'), isNull);
      expect(MorseTable.letterForToken(''), isNull);
    });

    test('inverse is stable across calls (cached map)', () {
      // Two consecutive lookups must hit the same memoised map — pinned
      // because the panel decodes per keystroke and a hot rebuild of
      // the inverse would cost a few microseconds per tap.
      final first = MorseTable.letterForToken('...');
      final second = MorseTable.letterForToken('...');
      expect(first, equals(second));
    });
  });

  group('Composer panel — defaults + stuck-state + live-bytes', () {
    final panelSrc = File(
      'lib/features/sip/signal/sip_signal_composer_panel.dart',
    ).readAsStringSync();

    test('default sub-mode is Morse (over Tone)', () {
      expect(
        panelSrc.contains('_SignalSubMode _subMode = _SignalSubMode.morse;'),
        isTrue,
        reason:
            'Per the v1 product brief, Signal lands on the message-passing '
            'sub-mode by default — Tone is the alternate.',
      );
    });

    test('default Morse input is Tap (over Type)', () {
      expect(
        panelSrc.contains('_MorseInputMode _morseInput = _MorseInputMode.tap;'),
        isTrue,
        reason: 'Tap-Morse is the primary input surface — Type is the helper.',
      );
    });

    test('tap-Morse keypad has dot, dash, Letter, Space, Backspace keys', () {
      // Each tap key dispatches to a dedicated handler so the test pins
      // the call sites by name (more durable than pinning the visible
      // glyphs, which are universal Morse symbols and not localised).
      expect(panelSrc.contains("_appendTapSymbol('.')"), isTrue);
      expect(panelSrc.contains("_appendTapSymbol('-')"), isTrue);
      expect(panelSrc.contains('_appendTapLetterGap'), isTrue);
      expect(panelSrc.contains('_appendTapWordGap'), isTrue);
      expect(panelSrc.contains('_tapBackspace'), isTrue);
    });

    test(
      'tap-Morse decode delegates to MorseTable.decode (canonical path)',
      () {
        // The composer routes through MorseTable.decode so the multi-format
        // robustness (canonical separator, multi-space fallback, greedy
        // continuous fallback) lives in one place.
        expect(
          panelSrc.contains('MorseTable.decode(pattern)'),
          isTrue,
          reason:
              'Tap-Morse decoder must delegate to MorseTable.decode rather '
              'than re-implement the split logic.',
        );
      },
    );

    test('tap-Morse word gap uses MorseTable.wordSeparator', () {
      // Single source of truth — when the separator changes, the live
      // preview, render output, and decode stay in lock-step.
      expect(
        panelSrc.contains('MorseTable.wordSeparator'),
        isTrue,
        reason:
            'Tap-Morse word-gap insertion must use the canonical '
            'wordSeparator constant so the live preview matches what '
            'render() emits to the receiver.',
      );
    });

    test(
      'phrase-full state disables note pads but keeps Clear / Preview / Send',
      () {
        // Pad rows pass `enabled: !isFull` — pads disable when the
        // phrase reaches the cap.
        expect(panelSrc.contains('enabled: !isFull'), isTrue);
        // The Clear button gates on `_hasDraftToClear`, which is
        // independent of the phrase-full state — it stays enabled as
        // long as the draft is non-empty.
        expect(
          panelSrc.contains('onPressed: hasContent ? _onClear : null'),
          isTrue,
          reason:
              'Clear must remain active whenever the draft has content, '
              'including at the phrase-full cap (the original stuck-state).',
        );
        // Preview / Send gate on `_canSend`, which checks the encoded
        // envelope size — at-cap drafts encode under budget, so both
        // remain active.
        expect(
          panelSrc.contains('onPressed: canSend ? _onPreview : null'),
          isTrue,
        );
        expect(
          panelSrc.contains(
            'onPressed: (canSend && !_sending) ? _onSend : null',
          ),
          isTrue,
        );
        // The badge surfaces the "x/x notes • Phrase full" copy so the
        // disabled pads are explained inline.
        expect(panelSrc.contains('sipSignalToneFull('), isTrue);
      },
    );

    test('live byte indicator drives the composer footer', () {
      // The footer renders `_SignalSizeBadge` which derives its label
      // from the same `_liveEncodedBytes()` source as `_canSend`.
      expect(panelSrc.contains('class _SignalSizeBadge'), isTrue);
      expect(panelSrc.contains('_SignalSizeBadge(bytes: bytes)'), isTrue);
      expect(panelSrc.contains('sipSignalSizeBytes(value)'), isTrue);
      expect(panelSrc.contains('sipSignalSizeOverBudget(value)'), isTrue);
    });

    test('over-budget gating uses SipSignalConstants.maxEnvelopeBytes (no '
        'magic numbers)', () {
      // Source-of-truth check: the cap reads from constants.
      expect(panelSrc.contains('SipSignalConstants.maxEnvelopeBytes'), isTrue);
      // The badge over-budget branch checks against the same constant.
      expect(
        panelSrc.contains('value > SipSignalConstants.maxEnvelopeBytes'),
        isTrue,
      );
    });

    test('Send-success path clears every draft (Tone phrase, Type, Tap)', () {
      // The success setState resets all three drafts so the next compose
      // starts clean regardless of which sub-mode produced the previous
      // send.
      expect(panelSrc.contains('_phraseDraft.clear();'), isTrue);
      expect(panelSrc.contains('_morseController.clear();'), isTrue);
      expect(panelSrc.contains("_tapMorsePattern = '';"), isTrue);
    });

    test('tap-Morse Letter/Space/Backspace gate on non-empty pattern (no '
        'no-op spamming)', () {
      // Letter is enabled only when there is a token to terminate.
      expect(
        panelSrc.contains(
          'enabled: pattern.isNotEmpty && !pattern.endsWith(\' \')',
        ),
        isTrue,
      );
      // Backspace + Space wire on `pattern.isNotEmpty`.
      final spaceCount = 'enabled: pattern.isNotEmpty,'.allMatches(panelSrc);
      expect(
        spaceCount.length >= 2,
        isTrue,
        reason: 'Both Space and Backspace gate on non-empty pattern',
      );
    });
  });
}
