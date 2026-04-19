// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canonical NodeBoard card container. Matches the NodeDex detail
// screen card pattern so NodeBoard cards slot into the same visual
// hierarchy: uppercase section header with a leading icon, subtle
// bordered surface, consistent spacing.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class NodeBoardCardContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const NodeBoardCardContainer({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.textTertiary),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          child,
        ],
      ),
    );
  }
}

/// Small stat chip — icon + label/count. Matches NodeDex / Aether chip
/// style. Use for thread counts, reply counts, time-ago, etc.
class NodeBoardStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tint;

  const NodeBoardStatChip({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? context.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered fade + slide entrance used by NodeDex cards. Wraps any
/// card to give the same calm, premium entry animation. Pass a
/// monotonically increasing `index` for the stagger cascade.
class NodeBoardEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final bool reduceMotion;

  const NodeBoardEntrance({
    super.key,
    required this.index,
    required this.child,
    this.reduceMotion = false,
  });

  @override
  State<NodeBoardEntrance> createState() => _NodeBoardEntranceState();
}

class _NodeBoardEntranceState extends State<NodeBoardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.reduceMotion) {
      _controller.value = 1.0;
    } else {
      final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 600));
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
