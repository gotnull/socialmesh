// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// StaggeredListTile — fade + subtle rise entrance animation used in
// premium list views (NodeDex co-seen list, MeshCanvas channel
// canvases, etc.).
//
// Visual contract:
//   - 320 ms total entrance: fade-in (eased) + 0.08 vertical slide.
//   - 40 ms stagger per index, capped at 400 ms total delay.
//   - Post-frame scheduling so Future.delayed never fires on a
//     disposed widget.
//   - AutomaticKeepAliveClientMixin so a tile that already animated
//     does NOT replay when it scrolls back into view.
//
// Use this wherever a sliver list of cards/tiles needs a polished
// entrance. Never hand-roll the timing — pull it from here.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class StaggeredListTile extends StatefulWidget {
  /// Position of this tile in the list. Drives the stagger delay.
  final int index;

  /// The tile content to animate in.
  final Widget child;

  /// Per-index delay in milliseconds. Defaults to 40 ms.
  final int staggerMsPerIndex;

  /// Hard cap on total stagger delay. Defaults to 400 ms.
  final int staggerCapMs;

  const StaggeredListTile({
    super.key,
    required this.index,
    required this.child,
    this.staggerMsPerIndex = 40,
    this.staggerCapMs = 400,
  });

  @override
  State<StaggeredListTile> createState() => _StaggeredListTileState();
}

class _StaggeredListTileState extends State<StaggeredListTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => _hasAnimated;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = math.min(
      widget.index * widget.staggerMsPerIndex,
      widget.staggerCapMs,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (delay == 0) {
        _controller.forward();
        _hasAnimated = true;
        updateKeepAlive();
      } else {
        Future.delayed(Duration(milliseconds: delay), () {
          if (!mounted) return;
          _controller.forward();
          _hasAnimated = true;
          updateKeepAlive();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasAnimated && _controller.isCompleted) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
