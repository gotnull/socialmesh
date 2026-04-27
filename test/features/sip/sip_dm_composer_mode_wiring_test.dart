// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Pattern-A composer-mode integration that surfaced SIP
/// Play as a first-class tab inside the existing DM session UI.
///
/// Hard rules:
///   - The composer mode enum carries `text`, `sketch`, AND `play`.
///   - `_ComposerModeSwitcher` exposes Sketch + Play tabs based on
///     `showSketch` / `showPlay` props — caller-controlled visibility
///     so peer-feature gating + T+S blocking can hide individual
///     tabs without forking the widget.
///   - The Play tab is hidden (not just disabled) when the peer
///     lacks `dmPlayV1` OR is blocked OR the session is inactive.
///   - The Play panel dispatches into the existing `showSipPlayPicker`
///     sheet — no new offer surface.
///   - Switching modes must NOT clear `_textController` or
///     `_sketchDraft` (drafts are State fields that persist across
///     rebuilds; nowhere in the build does `setState` reset them).
///   - The empty-state body copy mentions text, sketches, and games.
///   - The standalone `_PlayComposerCta` (pre-integration helper)
///     must NOT exist — Play is exclusively reached via the tab.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/features/sip/sip_dm_screen.dart').readAsStringSync();

  group('Composer mode enum', () {
    test('enum carries text, sketch, AND play', () {
      expect(
        RegExp(
          r'enum\s+_SipDmComposerMode\s*\{\s*text\s*,\s*sketch\s*,\s*play',
        ).hasMatch(src),
        isTrue,
        reason:
            'composer enum must include all three modes — Pattern A '
            'integration replaces the old Text|Sketch dichotomy',
      );
    });
  });

  group('Composer mode switcher', () {
    test('switcher accepts showSketch + showPlay flags + uses Play '
        'ARB label', () {
      expect(src.contains('required this.showSketch'), isTrue);
      expect(src.contains('required this.showPlay'), isTrue);
      expect(src.contains('l10n.sipDmComposerModePlay'), isTrue);
    });

    test('switcher renders all three labels via ARB keys, not literals', () {
      expect(src.contains('l10n.sipDmComposerModeText'), isTrue);
      expect(src.contains('l10n.sipDmComposerModeSketch'), isTrue);
      expect(src.contains('l10n.sipDmComposerModePlay'), isTrue);
    });
  });

  group('Play tab gating', () {
    test('Play tab is gated by enabled + peerSupportsPlay + !peerBlocked', () {
      // The build derives showPlayTab from those three signals.
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

    test('blocked peer triggers a fallback to text mode (no orphan tab)', () {
      // When the user is on the Play tab and the peer becomes
      // blocked, the build flips the active mode to text on the
      // next rebuild rather than stranding them on a hidden tab.
      expect(
        src.contains(
          '_composerMode == _SipDmComposerMode.play && !showPlayTab',
        ),
        isTrue,
      );
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
      // The intermediate picker bottom sheet was replaced by per-game
      // cards rendered directly inside _PlayComposerPanel. Pin the
      // single offer-dispatch helper used by every card.
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
    test('switching modes does NOT clear _textController or _sketchDraft', () {
      // Search the onChanged callback inside _ComposerModeSwitcher
      // construction for any `.clear()` / `.text = ''` / `_sketchDraft =`
      // assignments. None of those should appear in the mode-switch
      // path. We isolate the switcher block to keep the assertion
      // narrow.
      final start = src.indexOf('_ComposerModeSwitcher(');
      expect(start, greaterThan(0));
      final end = src.indexOf(',\n                    ),', start);
      expect(end, greaterThan(start));
      final block = src.substring(start, end);

      expect(
        block.contains('_textController.clear'),
        isFalse,
        reason: 'mode switch must NOT clear the text draft',
      );
      expect(
        block.contains('_textController.text ='),
        isFalse,
        reason: 'mode switch must NOT overwrite the text controller',
      );
      expect(
        block.contains('_sketchDraft ='),
        isFalse,
        reason: 'mode switch must NOT reset the sketch draft',
      );
    });
  });

  group('Empty state', () {
    test('body copy mentions text, sketches, and games', () {
      // Read the ARB directly — the screen renders this through
      // l10n.sipDmEmptyDescription so we pin the source-of-truth.
      final arb = File('lib/l10n/app_en.arb').readAsStringSync();
      // Locate the value next to the key to avoid matching the
      // metadata description.
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
