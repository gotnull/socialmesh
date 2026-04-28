// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Jump-to-latest pill — shared chat affordance.
//
// Used by both the messaging screen and the SIP DM screen so the two
// chat surfaces stay 1:1 in look, animation, and tap behaviour.
//
// Designed to be dropped inside a `Stack` as a `Positioned` overlay
// (typically `bottom: AppTheme.spacing12`, `left: 0`, `right: 0`) so it
// floats over the chat list without consuming layout space. When
// [visible] is false the pill fades out via [AnimatedOpacity] and
// stops accepting taps via [IgnorePointer]; the chat list remains
// fully visible behind it because the pill itself is the only opaque
// surface in the row.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'animations.dart';

/// Floating "Jump to latest" pill displayed over a chat list when the
/// user has scrolled away from the most recent message.
///
/// Caller controls visibility via [visible] and the tap action via
/// [onTap]. The label text is supplied per-screen so each chat surface
/// can use its own ARB key (the messaging screen's
/// `messagingJumpToLatest` and the SIP DM screen's
/// `sipDmJumpToLatest` resolve to the same English string but ride
/// different translation lifecycles).
class JumpToLatestPill extends StatelessWidget {
  const JumpToLatestPill({
    super.key,
    required this.visible,
    required this.onTap,
    required this.label,
  });

  /// Whether the pill is currently shown. Animates between visible and
  /// hidden via opacity; layout space is reserved either way so the
  /// caller's `Stack` placement remains stable.
  final bool visible;

  /// Tap callback. The caller is responsible for triggering haptics
  /// and performing the actual scroll.
  final VoidCallback onTap;

  /// User-facing label, e.g. `context.l10n.messagingJumpToLatest`.
  final String label;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: Center(
          child: BouncyTap(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing14,
                vertical: AppTheme.spacing10,
              ),
              decoration: BoxDecoration(
                color: context.card.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                border: Border.all(color: context.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
