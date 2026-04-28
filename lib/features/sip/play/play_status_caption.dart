// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Game-agnostic status helpers shared across every SIP Play game's
// board section. The status captions ("Your turn", "You won", "They
// declined", etc.) and the turn pulse-dot describe lifecycle states
// in terms that don't reference X/O, discs, or any game-specific
// vocabulary — they take booleans + an accent colour and produce the
// matching localised string / widget. Tic-Tac-Toe and Connect Four
// both consume these directly.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// Resolved visual treatment for a terminal SIP Play state. Returned
/// from [playOutcomeStyle] so the renderer can wrap the caption in a
/// colour-coded chip (green for win, red for loss, neutral for draw /
/// resign / decline). Active / pending states return null — the
/// renderer falls back to the plain text caption.
class PlayOutcomeStyle {
  final Color color;
  final IconData icon;
  const PlayOutcomeStyle({required this.color, required this.icon});
}

/// Returns visual treatment for a terminal state, or null for
/// active / pending states. Single switch matches the order used by
/// [playStatusCaption] so the icon and the text always agree.
PlayOutcomeStyle? playOutcomeStyle({
  required BuildContext context,
  required bool localWon,
  required bool remoteWon,
  required bool draw,
  required bool localResigned,
  required bool remoteResigned,
  required bool localDeclined,
  required bool remoteDeclined,
}) {
  if (localWon) {
    return const PlayOutcomeStyle(
      color: AccentColors.green,
      icon: Icons.emoji_events_outlined,
    );
  }
  if (remoteWon) {
    return PlayOutcomeStyle(
      color: SemanticColors.error,
      icon: Icons.sentiment_dissatisfied_outlined,
    );
  }
  if (draw) {
    return PlayOutcomeStyle(
      color: context.accentColor,
      icon: Icons.handshake_outlined,
    );
  }
  if (localResigned) {
    return const PlayOutcomeStyle(
      color: AccentColors.yellow,
      icon: Icons.flag_outlined,
    );
  }
  if (remoteResigned) {
    return const PlayOutcomeStyle(color: AccentColors.green, icon: Icons.flag);
  }
  if (localDeclined || remoteDeclined) {
    return PlayOutcomeStyle(
      color: SemanticColors.error,
      icon: Icons.close_rounded,
    );
  }
  return null;
}

/// Status caption + optional terminal-state chip. Used in the header
/// row of every SIP Play board section. For active / pending states,
/// renders the plain "Your turn" / "Their turn" text. For terminal
/// states (won / lost / draw / resigned / declined), wraps the text
/// in a small colour-coded chip with an icon so the resolution is
/// readable at a glance — UX #4.
class PlayStatusBanner extends StatelessWidget {
  final bool isLocalTurn;
  final bool isActive;
  final bool localWon;
  final bool remoteWon;
  final bool draw;
  final bool localResigned;
  final bool remoteResigned;
  final bool localDeclined;
  final bool remoteDeclined;

  const PlayStatusBanner({
    super.key,
    required this.isLocalTurn,
    required this.isActive,
    required this.localWon,
    required this.remoteWon,
    required this.draw,
    required this.localResigned,
    required this.remoteResigned,
    required this.localDeclined,
    required this.remoteDeclined,
  });

  @override
  Widget build(BuildContext context) {
    final caption = playStatusCaption(
      context: context,
      isLocalTurn: isLocalTurn,
      localWon: localWon,
      remoteWon: remoteWon,
      draw: draw,
      localResigned: localResigned,
      remoteResigned: remoteResigned,
      localDeclined: localDeclined,
      remoteDeclined: remoteDeclined,
    );
    final style = playOutcomeStyle(
      context: context,
      localWon: localWon,
      remoteWon: remoteWon,
      draw: draw,
      localResigned: localResigned,
      remoteResigned: remoteResigned,
      localDeclined: localDeclined,
      remoteDeclined: remoteDeclined,
    );
    if (style == null) {
      // Active / pending — keep the existing plain caption look so
      // the in-game UI doesn't shift.
      return Text(
        caption,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isLocalTurn && isActive
              ? context.accentColor
              : context.textSecondary,
          fontFamily: AppTheme.fontFamily,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: style.color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            caption,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.color,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Build the user-facing status caption for an active or terminal
/// SIP Play instance. Pure helper — no localization context needed
/// at the call site beyond a [BuildContext].
String playStatusCaption({
  required BuildContext context,
  required bool isLocalTurn,
  required bool localWon,
  required bool remoteWon,
  required bool draw,
  required bool localResigned,
  required bool remoteResigned,
  required bool localDeclined,
  required bool remoteDeclined,
}) {
  final l10n = context.l10n;
  if (localWon) return l10n.sipPlayStatusYouWon;
  if (remoteWon) return l10n.sipPlayStatusTheyWon;
  if (draw) return l10n.sipPlayStatusDraw;
  if (localResigned) return l10n.sipPlayStatusYouResigned;
  if (remoteResigned) return l10n.sipPlayStatusTheyResigned;
  if (localDeclined) return l10n.sipPlayStatusYouDeclined;
  if (remoteDeclined) return l10n.sipPlayStatusTheyDeclined;
  return isLocalTurn ? l10n.sipPlayStatusYourTurn : l10n.sipPlayStatusTheirTurn;
}

/// Small dot that pulses when it's the local user's turn — a subtle
/// "your move" cue placed inline with the status caption. Pure
/// presentation; no business logic.
class PlayTurnPulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PlayTurnPulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PlayTurnPulseDot> createState() => _PlayTurnPulseDotState();
}

class _PlayTurnPulseDotState extends State<PlayTurnPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctl.value);
        return SizedBox(
          width: widget.size + 6,
          height: widget.size + 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + 4 * t,
                height: widget.size + 4 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25 * (1.0 - t)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
