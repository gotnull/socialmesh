// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inline composer panel for SIP Signal v1.
///
/// Two sub-modes:
///   - **Tone**: 8-pad grid + instrument chips → up to 8-note phrase.
///   - **Morse**: text input → live Morse pattern preview.
///
/// Both share Preview / Send / Clear controls. Preview synthesizes
/// the draft locally without touching the wire; Send routes through
/// `sipDmRouterProvider.sendSignal` so all T+S + rate-limit gates
/// fire identically to text / sketch / play.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/sip_dm_secure_router.dart';
import '../../../providers/sip_play_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/signal/morse_table.dart';
import '../../../services/protocol/sip/signal/sip_signal_codec.dart';
import '../../../services/protocol/sip/signal/sip_signal_constants.dart';
import '../../../services/protocol/sip/signal/sip_signal_payload.dart';
import '../../../services/protocol/sip/sip_dm.dart';
import '../../../utils/snackbar.dart';
import 'sip_signal_bubble.dart';

/// Sub-mode discriminator for the Signal composer.
enum _SignalSubMode { tone, morse }

/// Within Morse, two ways to compose.
enum _MorseInputMode {
  /// Default: dot/dash/letter/space buttons with live decode.
  tap,

  /// Helper: regular text field, encoder fills in the Morse pattern.
  type,
}

class SipSignalComposerPanel extends ConsumerStatefulWidget {
  final int sessionTag;

  /// Fires when the user toggles between the Tone and Morse sub-modes
  /// inside the panel. The DM screen uses this to scroll the chat to
  /// the most recent bubble of the corresponding signal kind so the
  /// composer surface and the timeline stay aligned (mirrors how the
  /// top-level Signal chip jumps to the latest signal of any kind).
  final void Function(SipSignalKind kind)? onSubModeChanged;

  const SipSignalComposerPanel({
    super.key,
    required this.sessionTag,
    this.onSubModeChanged,
  });

  @override
  ConsumerState<SipSignalComposerPanel> createState() =>
      _SipSignalComposerPanelState();
}

class _SipSignalComposerPanelState extends ConsumerState<SipSignalComposerPanel>
    with LifecycleSafeMixin {
  // Default sub-mode is Morse (tap-first), per the v1 product brief —
  // the ritual / message-passing surface gets the prime slot, with Tone
  // as the alternate phrase composer.
  _SignalSubMode _subMode = _SignalSubMode.morse;

  // Within Morse, default to tap input. The text field is kept as a
  // helper for power users who want to dictate via QWERTY.
  _MorseInputMode _morseInput = _MorseInputMode.tap;

  // Tone draft.
  final List<_PadNote> _phraseDraft = [];
  SipSignalInstrument _phraseInstrument = SipSignalInstrument.bell;

  // Morse draft (Type sub-mode).
  final TextEditingController _morseController = TextEditingController();
  // v1: instrument + WPM are fixed sane defaults — chip + speed
  // pickers are deferred to v2 without changing the wire.
  final SipSignalInstrument _morseInstrument = SipSignalInstrument.sine;
  final int _morseWpm = SipSignalConstants.defaultMorseWpm;

  // Tap-Morse buffer. Pattern uses the same human-readable encoding as
  // [MorseTable.render]: `.` and `-` for symbols, single space for an
  // intra-word letter gap, ` / ` for a word gap. We keep a flat string
  // (rather than a tokenised list) so backspace can rewind one symbol
  // at a time without bookkeeping; decoding is O(n) and runs per
  // keystroke, well within frame budget for the 40-token cap.
  String _tapMorsePattern = '';

  // Send guard so the user can't double-tap Send mid-flight.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    AppLogging.sipSignal(
      'composer_opened tag=0x${widget.sessionTag.toRadixString(16)}',
    );
  }

  @override
  void dispose() {
    _morseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.sipSignalPanelTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.sipSignalPanelSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSubModeSwitcher(context),
          const SizedBox(height: AppTheme.spacing12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _subMode == _SignalSubMode.tone
                ? _buildToneBody(context)
                : _buildMorseBody(context),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildSubModeSwitcher(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Row(
        children: [
          _subModeSegment(
            context,
            _SignalSubMode.tone,
            l10n.sipSignalSubModeTone,
          ),
          _subModeSegment(
            context,
            _SignalSubMode.morse,
            l10n.sipSignalSubModeMorse,
          ),
        ],
      ),
    );
  }

  Widget _subModeSegment(
    BuildContext context,
    _SignalSubMode mode,
    String label,
  ) {
    final selected = _subMode == mode;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_subMode == mode) return;
          ref.read(hapticServiceProvider).trigger(HapticType.selection);
          setState(() => _subMode = mode);
          // Bubble the kind up to the DM screen so it can scroll the
          // chat to the latest matching signal — same behaviour the
          // top-level Signal chip provides, just narrowed to the
          // sub-mode the user just chose.
          final kind = mode == _SignalSubMode.tone
              ? SipSignalKind.phrase
              : SipSignalKind.morse;
          widget.onSubModeChanged?.call(kind);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
          decoration: BoxDecoration(
            color: selected
                ? context.accentColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? context.accentColor : context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Tone sub-mode
  // ---------------------------------------------------------------

  /// 8 pad notes — two octaves of a C major run, spaced widely enough
  /// for thumb taps on an iPhone Pro.
  static const List<int> _padMidi = [
    60, // C4
    62, // D4
    64, // E4
    65, // F4
    67, // G4
    69, // A4
    71, // B4
    72, // C5
  ];

  Widget _buildToneBody(BuildContext context) {
    final l10n = context.l10n;
    final isFull = _phraseDraft.length >= SipSignalConstants.maxPhraseNotes;
    return Column(
      key: const ValueKey('signal-tone-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phrase strip — visualises current draft. Animated insertion
        // when a pad is tapped.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing10),
            decoration: BoxDecoration(
              color: context.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: _phraseDraft.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sipSignalToneEmpty,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                          fontStyle: FontStyle.italic,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing6),
                      Row(
                        children: [
                          Text(
                            l10n.sipSignalToneExampleHint,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing6),
                          // Universal-music symbol — language-neutral.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _loadCloseEncountersExample,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                border: Border.all(
                                  color: context.accentColor.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 12,
                                    color: context.accentColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacing4),
                                  Text(
                                    l10n.sipSignalToneExampleCloseEncounters,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.accentColor,
                                      fontFamily: AppTheme.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Wrap(
                    spacing: AppTheme.spacing6,
                    runSpacing: AppTheme.spacing4,
                    children: [
                      for (final note in _phraseDraft)
                        _PhraseChip(label: midiNoteName(note.midi)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        // 4×2 pad grid. Pads disable when phrase is full — Clear /
        // Preview / Send remain active so the user can never wedge.
        for (var row = 0; row < 2; row += 1) ...[
          Row(
            children: [
              for (var col = 0; col < 4; col += 1)
                Expanded(
                  child: _PadButton(
                    label: midiNoteName(_padMidi[row * 4 + col]),
                    onTap: () => _onPadTap(_padMidi[row * 4 + col]),
                    enabled: !isFull,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
        ],
        if (isFull) ...[
          const SizedBox(height: AppTheme.spacing4),
          _PhraseFullBadge(
            text: l10n.sipSignalToneFull(
              _phraseDraft.length,
              SipSignalConstants.maxPhraseNotes,
            ),
          ),
        ],
        const SizedBox(height: AppTheme.spacing4),
        // Instrument chips.
        Text(
          l10n.sipSignalToneInstrument,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
            letterSpacing: 0.6,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Wrap(
          spacing: AppTheme.spacing6,
          children: [
            for (final inst in SipSignalInstrument.values)
              _InstrumentChip(
                label: instrumentLabel(context, inst),
                selected: inst == _phraseInstrument,
                onTap: () => setState(() => _phraseInstrument = inst),
              ),
          ],
        ),
      ],
    );
  }

  void _onPadTap(int midi) {
    if (_phraseDraft.length >= SipSignalConstants.maxPhraseNotes) {
      // Full — defence-in-depth. The pad button itself goes disabled
      // when isFull is true; this guard catches a stale tap that
      // raced the rebuild. Clear / Preview / Send remain active so
      // the user can never wedge here.
      return;
    }
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    setState(() {
      _phraseDraft.add(_PadNote(midi: midi));
    });
    AppLogging.sipSignal(
      'note_appended midi=$midi count=${_phraseDraft.length}',
    );
    // Audible feedback — route through the low-latency tap pool so
    // rapid drumming on the pads doesn't queue behind the main
    // playPhrase player and so the cached WAV bypass kicks in for
    // repeat-same-note taps.
    final synth = ref.read(sipSignalSynthServiceProvider);
    synth.playToneTap(
      midi: midi,
      instrument: _phraseInstrument,
      durationTicks: 12, // ~240 ms — short, audible chirp
    );
  }

  /// MIDI notes for the iconic 5-note "Close Encounters of the Third
  /// Kind" motif. Williams scored the second Do an octave below the
  /// first (Curwen hand-signal style), and Sol resolves a perfect
  /// fifth above the octave-displaced C — that distinctive
  /// "skywards-then-deep-then-resolve" shape is what makes the motif
  /// recognisable.
  ///
  /// The composer's pad row only renders C4..C5, but `playToneTap`
  /// and `playPhrase` happily synthesise any MIDI note, so the
  /// example surfaces the lower-octave Do and Sol below the visible
  /// keyboard. The phrase chips render as `C3` and `G3` — a little
  /// hint that the pitch range goes deeper than the eight pads imply.
  static const List<int> _closeEncountersMidi = [
    62, // D4 — Re
    64, // E4 — Mi
    60, // C4 — Do
    48, // C3 — Do, an octave below per the Williams original
    55, // G3 — Sol, perfect fifth above the octave-displaced Do
  ];

  /// Replace the current draft with the Close Encounters motif and
  /// preview it immediately. Resetting (rather than appending) keeps
  /// the Send-budget predictable: the example is always exactly five
  /// notes so the byte indicator settles on the same value.
  void _loadCloseEncountersExample() {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    setState(() {
      _phraseDraft
        ..clear()
        ..addAll([for (final m in _closeEncountersMidi) _PadNote(midi: m)]);
    });
    AppLogging.sipSignal(
      'tone_example_loaded name=close_encounters '
      'notes=${_phraseDraft.length}',
    );
    final synth = ref.read(sipSignalSynthServiceProvider);
    synth.playPhrase(
      SipSignalPhraseBody(
        instrument: _phraseInstrument,
        notes: [
          for (final m in _closeEncountersMidi)
            SipSignalNote(
              midiNote: m,
              durationTicks: 24, // ~480 ms each — sing it out
              velocity: 100,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Morse sub-mode
  // ---------------------------------------------------------------

  Widget _buildMorseBody(BuildContext context) {
    return Column(
      key: const ValueKey('signal-morse-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMorseInputModeToggle(context),
        const SizedBox(height: AppTheme.spacing12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _morseInput == _MorseInputMode.tap
              ? _buildMorseTapBody(context)
              : _buildMorseTypeBody(context),
        ),
      ],
    );
  }

  Widget _buildMorseInputModeToggle(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Row(
        children: [
          _morseInputSegment(
            context,
            _MorseInputMode.tap,
            l10n.sipSignalMorseInputTap,
          ),
          _morseInputSegment(
            context,
            _MorseInputMode.type,
            l10n.sipSignalMorseInputType,
          ),
        ],
      ),
    );
  }

  Widget _morseInputSegment(
    BuildContext context,
    _MorseInputMode mode,
    String label,
  ) {
    final selected = _morseInput == mode;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_morseInput == mode) return;
          ref.read(hapticServiceProvider).trigger(HapticType.selection);
          setState(() => _morseInput = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
          decoration: BoxDecoration(
            color: selected
                ? context.accentColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? context.accentColor : context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMorseTapBody(BuildContext context) {
    final l10n = context.l10n;
    final pattern = _tapMorsePattern;
    final decoded = _decodeTapMorse(pattern);
    final hasInvalid = decoded.contains('?');
    return Column(
      key: const ValueKey('signal-morse-tap-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decoded text — what the receiver will see.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacing10),
          decoration: BoxDecoration(
            color: context.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(color: context.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sipSignalMorseTapDecodedLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                  letterSpacing: 0.6,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                decoded.isEmpty ? l10n.sipSignalMorseTapEmpty : decoded,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: decoded.isEmpty
                      ? context.textTertiary
                      : context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                  fontStyle: decoded.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                softWrap: true,
              ),
              if (pattern.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing6),
                Text(
                  l10n.sipSignalMorseTapPatternLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 0.6,
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
                  softWrap: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        // Tap keypad. Two rows: dot/dash on top, separators + backspace on bottom.
        Row(
          children: [
            Expanded(
              child: _TapKey(
                // Universal Morse glyph — not localised.
                label: '·', // lint-allow: hardcoded-string
                tooltip: l10n.sipSignalMorseTapDot,
                onTap: () => _appendTapSymbol('.'),
                emphasised: true,
              ),
            ),
            const SizedBox(width: AppTheme.spacing6),
            Expanded(
              child: _TapKey(
                // Universal Morse glyph — not localised.
                label: '—', // lint-allow: hardcoded-string
                tooltip: l10n.sipSignalMorseTapDash,
                onTap: () => _appendTapSymbol('-'),
                emphasised: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing6),
        Row(
          children: [
            Expanded(
              child: _TapKey(
                label: l10n.sipSignalMorseTapLetter,
                tooltip: l10n.sipSignalMorseTapLetter,
                onTap: _appendTapLetterGap,
                enabled: pattern.isNotEmpty && !pattern.endsWith(' '),
              ),
            ),
            const SizedBox(width: AppTheme.spacing6),
            Expanded(
              child: _TapKey(
                label: l10n.sipSignalMorseTapSpace,
                tooltip: l10n.sipSignalMorseTapSpace,
                onTap: _appendTapWordGap,
                enabled: pattern.isNotEmpty,
              ),
            ),
            const SizedBox(width: AppTheme.spacing6),
            Expanded(
              child: _TapKey(
                label: l10n.sipSignalMorseTapBackspace,
                tooltip: l10n.sipSignalMorseTapBackspace,
                icon: Icons.backspace_outlined,
                onTap: _tapBackspace,
                enabled: pattern.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          l10n.sipSignalMorseTapHint,
          style: TextStyle(
            fontSize: 11,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        if (hasInvalid) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.sipSignalMorseTapInvalidNote,
            style: TextStyle(
              fontSize: 11,
              color: SemanticColors.error.withValues(alpha: 0.85),
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMorseTypeBody(BuildContext context) {
    final l10n = context.l10n;
    final filtered = MorseTable.filtered(_morseController.text);
    final originalUpper = _morseController.text.toUpperCase();
    final hasUnsupported = filtered.length != originalUpper.length;
    final pattern = filtered.isEmpty ? '' : MorseTable.render(filtered);
    return Column(
      key: const ValueKey('signal-morse-type-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _morseController,
          maxLength: SipSignalConstants.maxMorseChars,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            // Soft filter — keep printable ASCII; the encoder does
            // the strict charset check before send.
            FilteringTextInputFormatter.deny(RegExp('[\n\r\t]')),
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: l10n.sipSignalMorsePlaceholder,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.sipSignalMorseHint,
          style: TextStyle(
            fontSize: 11,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        if (hasUnsupported) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.sipSignalMorseUnsupportedNote,
            style: TextStyle(
              fontSize: 11,
              color: SemanticColors.error.withValues(alpha: 0.85),
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
        if (pattern.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing10),
            decoration: BoxDecoration(
              color: context.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: Text(
              pattern,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------

  Widget _buildActionRow(BuildContext context) {
    final l10n = context.l10n;
    final bytes = _liveEncodedBytes();
    final canSend = _canSend();
    final hasContent = _hasDraftToClear();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Live byte indicator — sits inline on the left so the row
        // doesn't burn an extra line on a static label. Shrinks to zero
        // width when the draft is empty.
        Expanded(child: _SignalSizeBadge(bytes: bytes)),
        const SizedBox(width: AppTheme.spacing8),
        _IconActionButton(
          tooltip: l10n.sipSignalActionClear,
          icon: Icons.delete_outline,
          onPressed: hasContent ? _onClear : null,
          tone: _IconActionTone.destructive,
        ),
        const SizedBox(width: AppTheme.spacing8),
        _IconActionButton(
          tooltip: l10n.sipSignalActionPreview,
          icon: Icons.play_arrow_rounded,
          onPressed: canSend ? _onPreview : null,
        ),
        const SizedBox(width: AppTheme.spacing8),
        _IconActionButton(
          tooltip: l10n.sipSignalActionSend,
          icon: Icons.send_rounded,
          onPressed: (canSend && !_sending) ? _onSend : null,
          tone: _IconActionTone.primary,
          showProgress: _sending,
        ),
      ],
    );
  }

  bool _canSend() {
    final bytes = _liveEncodedBytes();
    if (bytes == null) return false;
    return bytes <= SipSignalConstants.maxEnvelopeBytes;
  }

  /// Source of truth for both the live-byte indicator and the
  /// can-send gate. Returns null when the draft is empty (nothing to
  /// encode), the wire-level encoded length when the draft would
  /// produce a valid envelope, OR a sentinel value larger than
  /// [SipSignalConstants.maxEnvelopeBytes] when the draft exceeds the
  /// budget. Sized buffer use is unconditional because the encoder
  /// already returns null for over-budget input — to surface "too
  /// large" copy without reaching for a separate count we resize to
  /// the cap when the encoder rejects.
  int? _liveEncodedBytes() {
    switch (_subMode) {
      case _SignalSubMode.tone:
        if (_phraseDraft.isEmpty) return null;
        final encoded = _encodeDraft();
        if (encoded != null) return encoded.length;
        // Encoder rejected (over-budget). Compute an approximate size so
        // the UI can still display "too large".
        return _approximatePhraseBytes();
      case _SignalSubMode.morse:
        final text = _currentMorseText();
        if (text.isEmpty) return null;
        final encoded = _encodeDraft();
        if (encoded != null) return encoded.length;
        return _approximateMorseBytes(text.length);
    }
  }

  /// Decoded text behind the current Morse draft, regardless of which
  /// input sub-mode produced it. Empty when the draft has nothing
  /// encodable (all `?` placeholders, all whitespace, etc.).
  String _currentMorseText() {
    switch (_morseInput) {
      case _MorseInputMode.type:
        return MorseTable.filtered(_morseController.text);
      case _MorseInputMode.tap:
        return MorseTable.filtered(_decodeTapMorse(_tapMorsePattern));
    }
  }

  /// Phrase byte estimate when the encoder rejects mid-compose. Just
  /// the wire layout: 6 fixed bytes + 3 bytes per note. Slightly over
  /// the encoder cap by design so the "over budget" copy lights up
  /// the moment the user taps the offending pad.
  int _approximatePhraseBytes() {
    return 6 + (_phraseDraft.length * 3);
  }

  /// Morse byte estimate when the encoder rejects mid-compose. Header
  /// + per-character payload (1 byte each for the supported alphabet).
  int _approximateMorseBytes(int textLen) {
    return 6 + textLen;
  }

  /// Whether the local draft has anything to clear. Drives the Clear
  /// button enabled state — must stay true even when the phrase is at
  /// the hard cap so the user can never get stuck.
  bool _hasDraftToClear() {
    switch (_subMode) {
      case _SignalSubMode.tone:
        return _phraseDraft.isNotEmpty;
      case _SignalSubMode.morse:
        switch (_morseInput) {
          case _MorseInputMode.tap:
            return _tapMorsePattern.isNotEmpty;
          case _MorseInputMode.type:
            return _morseController.text.isNotEmpty;
        }
    }
  }

  void _onClear() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() {
      switch (_subMode) {
        case _SignalSubMode.tone:
          _phraseDraft.clear();
        case _SignalSubMode.morse:
          switch (_morseInput) {
            case _MorseInputMode.tap:
              _tapMorsePattern = '';
            case _MorseInputMode.type:
              _morseController.clear();
          }
      }
    });
  }

  void _onPreview() {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final synth = ref.read(sipSignalSynthServiceProvider);
    switch (_subMode) {
      case _SignalSubMode.tone:
        if (_phraseDraft.isEmpty) return;
        synth.playPhrase(_phraseBodyForSend());
        AppLogging.sipSignal(
          'preview phrase notes=${_phraseDraft.length} '
          'instrument=${_phraseInstrument.name}',
        );
      case _SignalSubMode.morse:
        final text = _currentMorseText();
        if (text.isEmpty) return;
        synth.playMorse(_morseBodyForSend());
        AppLogging.sipSignal(
          'preview morse chars=${text.length} wpm=$_morseWpm '
          'instrument=${_morseInstrument.name} input=${_morseInput.name}',
        );
    }
  }

  Future<void> _onSend() async {
    if (_sending) return;
    final l10n = context.l10n;
    final router = ref.read(sipDmRouterProvider);
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    final bytes = _encodeDraft();
    if (bytes == null) {
      AppLogging.sipSignal('send_blocked reason=encode_failed');
      return;
    }
    setState(() => _sending = true);
    AppLogging.sipSignal(
      'send_attempt sub=${_subMode.name} bytes=${bytes.length}',
    );
    final outcome = await router.sendSignal(
      sessionTag: widget.sessionTag,
      signalPayload: bytes,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!outcome.isOk) {
      AppLogging.sipSignal('send_failed reason=${outcome.error?.name}');
      final message = switch (outcome.error) {
        SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
        SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
        SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
        _ => l10n.sipDmSessionClosed,
      };
      showErrorSnackBar(context, message);
      return;
    }
    // Success: clear the draft so the user starts fresh next time.
    setState(() {
      _phraseDraft.clear();
      _morseController.clear();
      _tapMorsePattern = '';
    });
  }

  // ---------------------------------------------------------------
  // Tap-Morse helpers
  // ---------------------------------------------------------------

  /// Append a dot or dash to the current tap-Morse pattern. Blocked
  /// when adding the symbol would exceed the wire-bound character cap
  /// (estimated by the decoded length, not the raw symbol count, so
  /// the user sees the byte indicator drive the gate).
  void _appendTapSymbol(String symbol) {
    assert(symbol == '.' || symbol == '-');
    setState(() {
      _tapMorsePattern = '$_tapMorsePattern$symbol';
    });
    AppLogging.sipSignal(
      'tap_morse_symbol symbol=$symbol pattern_len=${_tapMorsePattern.length}',
    );
  }

  /// Finalise the in-progress letter — append a single space so the
  /// next dot/dash starts a new token. No-op if the buffer already
  /// ends in a separator (avoids double letter-gaps).
  void _appendTapLetterGap() {
    if (_tapMorsePattern.isEmpty) return;
    if (_tapMorsePattern.endsWith(' ')) return;
    setState(() {
      _tapMorsePattern = '$_tapMorsePattern ';
    });
    AppLogging.sipSignal('tap_morse_letter_gap');
  }

  /// Append a word gap. Uses [MorseTable.wordSeparator] (` · `) so
  /// the live preview is byte-identical to [MorseTable.render]'s
  /// output and the canonical [MorseTable.decode] picks it up
  /// without going through the multi-space fallback.
  void _appendTapWordGap() {
    if (_tapMorsePattern.isEmpty) return;
    setState(() {
      // Strip any trailing single-space letter gap before adding the
      // word gap so we don't end up with mixed separators.
      var trimmed = _tapMorsePattern;
      while (trimmed.endsWith(' ')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      _tapMorsePattern = '$trimmed${MorseTable.wordSeparator}';
    });
    AppLogging.sipSignal('tap_morse_word_gap');
  }

  /// Backspace — peel off the most recent symbol or separator.
  /// Keeps the model symmetric with the input keys: one word
  /// separator, one letter gap, or one dot/dash per press.
  void _tapBackspace() {
    if (_tapMorsePattern.isEmpty) return;
    setState(() {
      if (_tapMorsePattern.endsWith(MorseTable.wordSeparator)) {
        _tapMorsePattern = _tapMorsePattern.substring(
          0,
          _tapMorsePattern.length - MorseTable.wordSeparator.length,
        );
      } else if (_tapMorsePattern.endsWith(' ')) {
        _tapMorsePattern = _tapMorsePattern.substring(
          0,
          _tapMorsePattern.length - 1,
        );
      } else {
        _tapMorsePattern = _tapMorsePattern.substring(
          0,
          _tapMorsePattern.length - 1,
        );
      }
    });
    AppLogging.sipSignal(
      'tap_morse_backspace pattern_len=${_tapMorsePattern.length}',
    );
  }

  /// Decode a [MorseTable.render]-shaped pattern back to text. Routes
  /// through the canonical [MorseTable.decode] so robustness
  /// (multi-space, slash-separated legacy inputs, continuous greedy)
  /// stays in one place.
  String _decodeTapMorse(String pattern) {
    return MorseTable.decode(pattern);
  }

  Uint8List? _encodeDraft() {
    final seq = _generateSequenceId();
    switch (_subMode) {
      case _SignalSubMode.tone:
        if (_phraseDraft.isEmpty) return null;
        return SipSignalCodec.encodePhrase(
          sequenceId: seq,
          instrument: _phraseInstrument,
          notes: [
            for (final n in _phraseDraft)
              SipSignalNote(
                midiNote: n.midi,
                durationTicks: 18, // ~360 ms per note — pleasant default
                velocity: 100,
              ),
          ],
        );
      case _SignalSubMode.morse:
        final text = _currentMorseText();
        if (text.isEmpty) return null;
        return SipSignalCodec.encodeMorse(
          sequenceId: seq,
          speedWpm: _morseWpm,
          toneInstrument: _morseInstrument,
          text: text,
        );
    }
  }

  SipSignalPhraseBody _phraseBodyForSend() {
    return SipSignalPhraseBody(
      instrument: _phraseInstrument,
      notes: [
        for (final n in _phraseDraft)
          SipSignalNote(midiNote: n.midi, durationTicks: 18, velocity: 100),
      ],
    );
  }

  SipSignalMorseBody _morseBodyForSend() {
    final text = _currentMorseText();
    return SipSignalMorseBody(
      speedWpm: _morseWpm,
      toneInstrument: _morseInstrument,
      text: text,
    );
  }

  /// Pseudo-random u16 — collisions are dedupe-window-bound and harmless
  /// across distinct phrases.
  int _generateSequenceId() {
    final rng = math.Random.secure();
    return rng.nextInt(0x10000);
  }
}

class _PadNote {
  final int midi;
  const _PadNote({required this.midi});
}

class _PadButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _PadButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _animate() async {
    await _press.animateTo(1.0, curve: Curves.easeOut);
    if (!mounted) return;
    await _press.animateBack(0.0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => _press.forward(),
        onTapCancel: disabled ? null : () => _press.reverse(),
        onTap: disabled
            ? null
            : () {
                _animate();
                widget.onTap();
              },
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) =>
              Transform.scale(scale: 1.0 - (_press.value * 0.05), child: child),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: disabled
                  ? context.card.withValues(alpha: 0.5)
                  : context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(
                color: context.border.withValues(alpha: disabled ? 0.25 : 0.5),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? context.textTertiary.withValues(alpha: 0.6)
                    : context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact key for the tap-Morse keypad. Shared between dot/dash
/// (emphasised, accent-tinted) and the separators / backspace
/// (subdued). Bounded width comes from the parent `Expanded`, so the
/// key never trips the unconstrained-flex assertion.
class _TapKey extends StatefulWidget {
  final String label;
  final String tooltip;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool emphasised;

  const _TapKey({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.emphasised = false,
  });

  @override
  State<_TapKey> createState() => _TapKeyState();
}

class _TapKeyState extends State<_TapKey> with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _animate() async {
    await _press.animateTo(1.0, curve: Curves.easeOut);
    if (!mounted) return;
    await _press.animateBack(0.0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final accent = context.accentColor;
    final fill = widget.emphasised
        ? accent.withValues(alpha: 0.18)
        : context.card;
    final borderColor = widget.emphasised
        ? accent.withValues(alpha: 0.55)
        : context.border.withValues(alpha: 0.5);
    final fg = widget.emphasised ? accent : context.textPrimary;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => _press.forward(),
        onTapCancel: disabled ? null : () => _press.reverse(),
        onTap: disabled
            ? null
            : () {
                _animate();
                widget.onTap();
              },
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) =>
              Transform.scale(scale: 1.0 - (_press.value * 0.05), child: child),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: disabled ? fill.withValues(alpha: 0.4) : fill,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(
                color: disabled
                    ? borderColor.withValues(alpha: 0.3)
                    : borderColor,
              ),
            ),
            child: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 18,
                    color: disabled ? fg.withValues(alpha: 0.4) : fg,
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.emphasised ? 22 : 13,
                      fontWeight: FontWeight.w600,
                      color: disabled ? fg.withValues(alpha: 0.4) : fg,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Subtle "phrase full" hint shown above the disabled note pads. Sits
/// inline so the user instantly correlates the locked pads with the
/// reason — no scroll, no toast.
class _PhraseFullBadge extends StatelessWidget {
  final String text;
  const _PhraseFullBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: AccentColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: AccentColors.orange.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AccentColors.orange,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

/// Live encoded-byte readout for the composer footer. Displays nothing
/// while the draft is empty, the encoded length while in budget, and
/// an over-budget pill once the encoder rejects.
class _SignalSizeBadge extends StatelessWidget {
  final int? bytes;
  const _SignalSizeBadge({required this.bytes});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = bytes;
    if (value == null) return const SizedBox.shrink();
    final overBudget = value > SipSignalConstants.maxEnvelopeBytes;
    final color = overBudget
        ? SemanticColors.error.withValues(alpha: 0.85)
        : context.textTertiary;
    final label = overBudget
        ? l10n.sipSignalSizeOverBudget(value)
        : l10n.sipSignalSizeBytes(value);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        fontFamily: AppTheme.fontFamily,
      ),
    );
  }
}

/// Visual variants for the icon-only action buttons in the composer
/// footer. The composer's three actions (Clear, Preview, Send) all
/// share the same 44 dp tap target; the tone enum picks the right
/// surface treatment so a screen-reader user can still distinguish
/// destructive vs primary via the tooltip alone.
enum _IconActionTone { neutral, destructive, primary }

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final _IconActionTone tone;
  final bool showProgress;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = _IconActionTone.neutral,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final accent = context.accentColor;
    final (bg, border, fg) = switch (tone) {
      _IconActionTone.neutral => (
        Colors.transparent,
        context.border.withValues(alpha: 0.5),
        context.textPrimary,
      ),
      _IconActionTone.destructive => (
        Colors.transparent,
        AccentColors.red.withValues(alpha: 0.55),
        AccentColors.red,
      ),
      _IconActionTone.primary => (accent, accent, Colors.white),
    };
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: disabled ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppTheme.radius10),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                border: Border.all(
                  color: disabled ? border.withValues(alpha: 0.4) : border,
                ),
              ),
              child: Center(
                child: showProgress
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            disabled ? fg.withValues(alpha: 0.4) : fg,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: disabled ? fg.withValues(alpha: 0.4) : fg,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhraseChip extends StatelessWidget {
  final String label;
  const _PhraseChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.accentColor,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _InstrumentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InstrumentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing10,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.accentColor.withValues(alpha: 0.18)
              : context.background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(
            color: selected
                ? context.accentColor.withValues(alpha: 0.6)
                : context.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? context.accentColor : context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
    );
  }
}
