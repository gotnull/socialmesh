// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inline message-timeline bubble for one SIP Signal envelope.
///
/// Decodes the entry's stored bytes once, renders either the
/// phrase or Morse variant, and exposes a Replay button that hands
/// the decoded body back to [SipSignalSynthService] for local
/// regeneration. The wire never carries audio samples.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../providers/sip_play_providers.dart';
import '../../../services/protocol/sip/signal/morse_table.dart';
import '../../../services/protocol/sip/signal/sip_signal_codec.dart';
import '../../../services/protocol/sip/signal/sip_signal_constants.dart';
import '../../../services/protocol/sip/signal/sip_signal_payload.dart';

/// Estimated duration of a phrase playback. Mirrors the synth's
/// per-note rendering: each note runs for `durationTicks * tickMs`
/// plus a 40 ms inter-note gap. Pure function — kept inline here so
/// the bubble can disable Replay without coupling to the synth's
/// internals.
Duration _phrasePlaybackDuration(SipSignalPhraseBody phrase) {
  var totalMs = 0;
  for (final note in phrase.notes) {
    totalMs += note.durationTicks * SipSignalConstants.phraseTickMs;
    totalMs += 40; // inter-note gap mirroring _renderPhrase's 0.04 s pad
  }
  // Add a small tail so the button re-enables a touch AFTER the audio
  // tail decays — avoids a perceptible "click before silence" feel.
  return Duration(milliseconds: totalMs + 80);
}

/// Estimated duration of a Morse playback. Sums the unit-times from
/// [morseTimingForText] (dots, dashes, gaps) and converts via
/// `1200 / wpm` ms per unit.
Duration _morsePlaybackDuration(SipSignalMorseBody morse) {
  final unitMs = SipSignalConstants.unitMsForWpm(morse.speedWpm);
  var totalUnits = 0;
  for (final step in morseTimingForText(morse.text)) {
    totalUnits += step.units;
  }
  return Duration(milliseconds: totalUnits * unitMs + 80);
}

/// User-facing label for an instrument code. Centralised so bubble
/// + composer agree on copy.
String instrumentLabel(BuildContext context, SipSignalInstrument instrument) {
  final l10n = context.l10n;
  return switch (instrument) {
    SipSignalInstrument.sine => l10n.sipSignalInstrumentSine,
    SipSignalInstrument.bell => l10n.sipSignalInstrumentBell,
    SipSignalInstrument.pluck => l10n.sipSignalInstrumentPluck,
    SipSignalInstrument.chirp => l10n.sipSignalInstrumentChirp,
  };
}

/// Map a MIDI note (0..127) to a human-readable note name like `C4`.
/// Pure helper — no localisation needed (note names are universal in
/// Western music notation).
String midiNoteName(int midi) {
  const names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  if (midi < 0 || midi > 127) return '?';
  // MIDI 60 = C4 by the most common convention used by DAWs.
  final octave = (midi ~/ 12) - 1;
  final pitch = names[midi % 12];
  return '$pitch$octave';
}

class SipSignalBubble extends ConsumerWidget {
  /// Wire payload of the SIP DM history entry. Decoded once per build;
  /// the codec is cheap (4..32 bytes) so caching isn't worth the
  /// complexity vs the timeline-rebuild loop.
  final Uint8List entryPayload;

  /// Outbound vs inbound — affects bubble alignment + copy ("you sent" vs
  /// implicit incoming).
  final bool isOutbound;

  const SipSignalBubble({
    super.key,
    required this.entryPayload,
    required this.isOutbound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = SipSignalCodec.decode(entryPayload);
    if (!result.isOk) {
      return _MalformedBubble();
    }
    final env = result.envelope!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      child: switch (env.kind) {
        SipSignalKind.phrase => _PhraseBubbleBody(envelope: env),
        SipSignalKind.morse => _MorseBubbleBody(envelope: env),
      },
    );
  }
}

class _PhraseBubbleBody extends ConsumerStatefulWidget {
  final SipSignalEnvelope envelope;
  const _PhraseBubbleBody({required this.envelope});

  @override
  ConsumerState<_PhraseBubbleBody> createState() => _PhraseBubbleBodyState();
}

class _PhraseBubbleBodyState extends ConsumerState<_PhraseBubbleBody> {
  bool _replaying = false;
  Timer? _replayTimer;

  @override
  void dispose() {
    _replayTimer?.cancel();
    super.dispose();
  }

  void _replay() {
    if (_replaying) return;
    final phrase = widget.envelope.phrase!;
    AppLogging.sipSignal(
      'replay phrase seq=0x${widget.envelope.sequenceId.toRadixString(16)}',
    );
    setState(() => _replaying = true);
    ref.read(sipSignalSynthServiceProvider).playPhrase(phrase);
    _replayTimer?.cancel();
    _replayTimer = Timer(_phrasePlaybackDuration(phrase), () {
      if (!mounted) return;
      setState(() => _replaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phrase = widget.envelope.phrase!;
    final notesLabel = phrase.notes
        .map((n) => midiNoteName(n.midiNote))
        .join(' • ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, size: 18, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              l10n.sipSignalBubblePhraseLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            _InstrumentChipReadout(instrument: phrase.instrument),
          ],
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          '♪ $notesLabel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Align(
          alignment: Alignment.centerRight,
          child: _ReplayButton(
            onPressed: _replaying ? null : _replay,
            replaying: _replaying,
            label: l10n.sipSignalReplay,
          ),
        ),
      ],
    );
  }
}

class _MorseBubbleBody extends ConsumerStatefulWidget {
  final SipSignalEnvelope envelope;
  const _MorseBubbleBody({required this.envelope});

  @override
  ConsumerState<_MorseBubbleBody> createState() => _MorseBubbleBodyState();
}

class _MorseBubbleBodyState extends ConsumerState<_MorseBubbleBody> {
  bool _replaying = false;
  Timer? _replayTimer;

  @override
  void dispose() {
    _replayTimer?.cancel();
    super.dispose();
  }

  void _replay() {
    if (_replaying) return;
    final morse = widget.envelope.morse!;
    AppLogging.sipSignal(
      'replay morse seq=0x${widget.envelope.sequenceId.toRadixString(16)} '
      'chars=${morse.text.length}',
    );
    setState(() => _replaying = true);
    ref.read(sipSignalSynthServiceProvider).playMorse(morse);
    _replayTimer?.cancel();
    _replayTimer = Timer(_morsePlaybackDuration(morse), () {
      if (!mounted) return;
      setState(() => _replaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final morse = widget.envelope.morse!;
    final pattern = MorseTable.render(morse.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.graphic_eq, size: 18, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              l10n.sipSignalBubbleMorseLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            // No instrument chip on Morse bubbles — the receiver
            // decodes the rhythm, not the timbre, so labelling the
            // tone (Sine / Bell / etc.) is noise and was being read
            // as a Morse-format detail. Phrase bubbles still surface
            // it because the timbre is part of the musical content.
            Text(
              '${morse.speedWpm} WPM',
              style: TextStyle(fontSize: 11, color: context.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing6),
        // Decoded text first (always show both — the bubble's whole
        // genius is that the receiver doesn't need a Morse decoder
        // ring to read the message).
        Text(
          morse.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          pattern,
          style: TextStyle(
            fontSize: 13,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 1.2,
          ),
          // No truncation — let the pattern wrap on multiple lines.
          softWrap: true,
        ),
        const SizedBox(height: AppTheme.spacing8),
        Align(
          alignment: Alignment.centerRight,
          child: _ReplayButton(
            onPressed: _replaying ? null : _replay,
            replaying: _replaying,
            label: l10n.sipSignalReplay,
          ),
        ),
      ],
    );
  }
}

/// Pill chip rendering an instrument readout, mirroring the
/// composer's `_InstrumentChip` selected-state styling. Pure
/// presentation — no tap target.
class _InstrumentChipReadout extends StatelessWidget {
  final SipSignalInstrument instrument;
  const _InstrumentChipReadout({required this.instrument});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        instrumentLabel(context, instrument),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.accentColor,
        ),
      ),
    );
  }
}

/// Replay button shared by phrase + Morse bubbles. Disables itself
/// while the gated playback timer is active so a user can't queue up
/// dozens of overlapping replays by tapping rapidly.
class _ReplayButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool replaying;
  final String label;
  const _ReplayButton({
    required this.onPressed,
    required this.replaying,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: replaying
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.accentColor.withValues(alpha: 0.7),
                ),
              ),
            )
          : const Icon(Icons.play_arrow_rounded, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
      ),
    );
  }
}

class _MalformedBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: SemanticColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: SemanticColors.error.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              l10n.sipSignalBubbleMalformed,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
