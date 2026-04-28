// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the rich-composer bottom-sheet integration that replaced the
/// inline mode switcher.
///
/// Hard rules:
///   - Text input is the always-on inline composer; Sketch / Play /
///     Signal live exclusively in `_RichComposerSheet`.
///   - The rich-composer trigger appears only when at least one rich
///     tab is reachable (peer caps, T+S block, session active).
///   - The sheet's tab visibility mirrors the trigger's gating —
///     hidden caps drop their tab from the row inside the sheet.
///   - The Play panel inside the sheet still routes through
///     `sendSipPlayOffer` + per-game `_GameOfferCard` widgets —
///     no fork of the offer surface.
///   - Drafts that survive sheet open/close must be lifted to screen
///     scope: `_sketchDraft` is the canonical example. `_textController`
///     is unaffected by the sheet (text is inline).
///   - The empty-state body copy mentions text, sketches, and games.
///   - The standalone `_PlayComposerCta` (pre-integration helper)
///     must NOT exist — Play is exclusively reached via the sheet.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/features/sip/sip_dm_screen.dart').readAsStringSync();

  group('Sheet host architecture', () {
    test('rich-composer tab enum carries sketch, play, signal — no text', () {
      expect(
        RegExp(
          r'enum\s+_RichComposerTab\s*\{\s*sketch\s*,\s*play\s*,\s*signal\s*\}',
        ).hasMatch(src),
        isTrue,
        reason:
            'the rich-composer sheet hosts only the three attachment '
            'modes — text is the always-on inline composer and is '
            'intentionally absent from this enum.',
      );
    });

    test('inline text input wires the leading attach trigger only when at '
        'least one rich tab is reachable', () {
      expect(
        src.contains('showComposerTrigger'),
        isTrue,
        reason:
            '_buildTextInputBlock derives a single boolean from the '
            'three peer-cap gates and uses it to show/hide the '
            'leading attach button on ChatComposer.',
      );
      expect(src.contains('_ComposerSheetTrigger('), isTrue);
      expect(src.contains('l10n.sipDmComposerSheetTooltip'), isTrue);
    });

    test('opening the sheet routes through AppBottomSheet.showScrollable', () {
      expect(src.contains('AppBottomSheet.showScrollable'), isTrue);
      expect(src.contains('l10n.sipDmComposerSheetTitle'), isTrue);
      expect(
        src.contains('_RichComposerSheet('),
        isTrue,
        reason:
            'the sheet body is a dedicated widget so its scroll '
            'controller can be wired into a SingleChildScrollView.',
      );
    });
  });

  group('Tab gating', () {
    test('Play tab visibility = enabled && peerSupportsPlay && !peerBlocked', () {
      expect(
        RegExp(
          r'showPlayTab\s*=\s*enabled\s*&&\s*peerSupportsPlay\s*&&\s*!peerBlocked',
        ).hasMatch(src),
        isTrue,
        reason:
            'Play tab visibility must combine session-active, peer '
            'capability, and the T+S block check',
      );
    });

    test('peerSupportsPlay reads supportsDmPlayV1 from discovery', () {
      expect(
        src.contains('peer?.supportsDmPlayV1 ?? false'),
        isTrue,
        reason: 'peer-feature gate must consult the discovery cache',
      );
    });

    test('the rich tab bar uses the same three ARB labels as before', () {
      expect(src.contains('l10n.sipDmComposerModeSketch'), isTrue);
      expect(src.contains('l10n.sipDmComposerModePlay'), isTrue);
      expect(src.contains('l10n.sipDmComposerModeSignal'), isTrue);
    });
  });

  group('Play panel dispatch', () {
    test(
      'the play tab content is _PlayComposerPanel, NOT the standalone CTA',
      () {
        expect(src.contains('_PlayComposerPanel('), isTrue);
        expect(
          src.contains('class _PlayComposerCta'),
          isFalse,
          reason:
              'the standalone CTA was replaced by the tab + panel — '
              'leaving it would create two competing entry points',
        );
      },
    );

    test('panel routes through sendSipPlayOffer + per-game cards', () {
      expect(src.contains('sendSipPlayOffer('), isTrue);
      expect(src.contains('_GameOfferCard('), isTrue);
      expect(src.contains('SipPlayRegistry.games'), isTrue);
    });

    test('panel renders the Play header + airtime subtitle + TTT card '
        '+ "7 B moves" badge', () {
      expect(src.contains('l10n.sipPlayPanelTitle'), isTrue);
      expect(src.contains('l10n.sipPlayPanelSubtitle'), isTrue);
      expect(src.contains('l10n.sipPlayGameTicTacToe'), isTrue);
      expect(src.contains('l10n.sipPlayPanelTttSizeBadge'), isTrue);
    });

    test('panel exposes a "Game in progress" jump affordance', () {
      expect(src.contains('l10n.sipPlayPanelGameInProgressTitle'), isTrue);
      expect(src.contains('l10n.sipPlayPanelGameInProgressJump'), isTrue);
    });
  });

  group('Draft preservation', () {
    test('sketch draft is lifted to screen scope so it survives sheet '
        'open/close cycles', () {
      // The screen owns _sketchDraft and passes it into both the
      // sheet host and the SipInkComposer inside.
      expect(
        RegExp(
          r'List<SipInkRawStroke>\s+_sketchDraft\s*=\s*\[\]',
        ).hasMatch(src),
        isTrue,
      );
      expect(src.contains('sketchDraft: _sketchDraft'), isTrue);
    });

    test('opening the sheet does NOT touch the text controller or '
        'sketch draft', () {
      // Find the _openComposerSheet body and ensure it doesn't reset
      // either draft.
      final start = src.indexOf('Future<void> _openComposerSheet(');
      expect(start, greaterThan(0));
      final end = src.indexOf('\n  }\n', start);
      expect(end, greaterThan(start));
      final block = src.substring(start, end);
      expect(
        block.contains('_messageController.clear'),
        isFalse,
        reason: 'opening the rich sheet must NOT clear text input',
      );
      expect(
        block.contains('_sketchDraft.clear'),
        isFalse,
        reason: 'opening the rich sheet must NOT discard sketch strokes',
      );
    });
  });

  group('Empty state', () {
    test('body copy mentions text, sketches, and games', () {
      final arb = File('lib/l10n/app_en.arb').readAsStringSync();
      final match = RegExp(
        r'"sipDmEmptyDescription"\s*:\s*"([^"]+)"',
      ).firstMatch(arb);
      expect(match, isNotNull);
      final body = match!.group(1)!.toLowerCase();
      expect(body.contains('text'), isTrue);
      expect(body.contains('sketch'), isTrue);
      expect(body.contains('game'), isTrue);
    });
  });
}
