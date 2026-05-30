// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Interactive handshake visual for the onboarding flow (screen 2).
//
// Two nearby peers sit either side of a faint link. A pulse travels back and
// forth while the connection is pending. The user taps Accept: the link lights
// up, capability icons appear, and the peers are connected. This little act of
// consent is the whole point of the screen, so the user performs it rather
// than just reading about it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';

/// Two-peer link the user lights up by tapping Accept.
class PulseLink extends StatefulWidget {
  const PulseLink({
    super.key,
    required this.accent,
    this.active = true,
    this.acceptLabel = 'Accept',
    this.connectedLabel = 'Connected',
    this.onAccept,
  });

  final Color accent;
  final bool active;

  /// Localized label for the pending Accept affordance.
  final String acceptLabel;

  /// Localized label shown once the user accepts.
  final String connectedLabel;

  /// Fires when the user taps Accept (for haptics).
  final VoidCallback? onAccept;

  @override
  State<PulseLink> createState() => _PulseLinkState();
}

class _PulseLinkState extends State<PulseLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _accepted = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(PulseLink old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (widget.active && !_accepted && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  void _accept() {
    if (_accepted) return;
    setState(() => _accepted = true);
    _controller.stop();
    widget.onAccept?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _LinkPainter(
                          t: _controller.value,
                          accent: accent,
                          accepted: _accepted,
                        ),
                      );
                    },
                  ),
                ),
                _peer(context, Alignment.centerLeft, Icons.person_outline),
                _peer(context, Alignment.centerRight, Icons.person_outline),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _accepted
              ? _connectedPill(context, accent)
              : _acceptPill(context, accent),
        ),
        const SizedBox(height: AppTheme.spacing12),
        AnimatedOpacity(
          opacity: _accepted ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 320),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _capability(accent, Icons.chat_bubble_outline),
              _capability(accent, Icons.brush_outlined),
              _capability(accent, Icons.sports_esports_outlined),
              _capability(accent, Icons.lock_outline),
            ],
          ),
        ),
      ],
    );
  }

  Widget _peer(BuildContext context, Alignment align, IconData icon) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.card,
            border: Border.all(
              color: _accepted
                  ? widget.accent
                  : widget.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: _accepted
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: widget.accent, size: 26),
        ),
      ),
    );
  }

  Widget _capability(Color accent, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.14),
        ),
        child: Icon(icon, size: 16, color: accent),
      ),
    );
  }

  Widget _acceptPill(BuildContext context, Color accent) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _accept();
      },
      child: Container(
        key: const ValueKey('accept'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing20,
          vertical: AppTheme.spacing10,
        ),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.handshake_outlined, size: 18, color: Colors.white),
            const SizedBox(width: AppTheme.spacing8),
            Text(
              widget.acceptLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectedPill(BuildContext context, Color accent) {
    return Container(
      key: const ValueKey('connected'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing10,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radius24),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: accent),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            widget.connectedLabel,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkPainter extends CustomPainter {
  _LinkPainter({required this.t, required this.accent, required this.accepted});

  final double t;
  final Color accent;
  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final startX = size.width * 0.18;
    final endX = size.width * 0.82;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = accepted ? 2.0 : 1.2
      ..color = accent.withValues(alpha: accepted ? 0.7 : 0.25);
    canvas.drawLine(Offset(startX, y), Offset(endX, y), line);

    if (accepted) {
      // Solid glowing link.
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), glow);
      return;
    }

    // Pending: a pulse oscillates between the peers.
    final eased = 0.5 - 0.5 * math.cos(t * math.pi);
    final x = startX + (endX - startX) * eased;
    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.t != t || old.accent != accent || old.accepted != accepted;
}
