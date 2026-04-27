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
