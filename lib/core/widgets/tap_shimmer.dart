// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../logging.dart';

/// FU 2026-05-18: shimmer overlay that loops for the duration of a
/// background operation. Driven by an [active] bool - while active,
/// the highlight band sweeps across the child on repeat; when active
/// flips false, the current sweep finishes then the overlay stops.
///
/// Built for the MeshCore Settings auto-add toggles where the
/// firmware round-trip takes hundreds of ms to seconds. A real spinner
/// would feel heavy on a toggle row; a subtle shimmer gives the user
/// visible "still working" feedback without dominating.
///
/// Typical usage:
///
/// ```dart
/// final state = ref.watch(meshCoreAutoAddConfigProvider);
/// TapShimmer(
///   active: state.isLoading,
///   child: SettingsTile(...),
/// )
/// ```
///
/// Respects the system reduce-motion preference: when animations are
/// disabled, the widget is a transparent pass-through.
class TapShimmer extends StatefulWidget {
  final Widget child;
  final bool active;
  final Duration sweepDuration;
  final Color highlightColor;

  /// Rounded-rectangle clip applied to the shimmer OVERLAY (not the
  /// child). Defaults to the canonical SettingsTile radius (12pt) so
  /// the sweep stays inside the rounded card. Set to
  /// `BorderRadius.zero` for full-rect overlays.
  final BorderRadius borderRadius;

  /// Inset applied to the shimmer overlay so it matches the visible
  /// card area when wrapping a widget that has its own margin (like
  /// the canonical SettingsTile, which has
  /// `EdgeInsets.symmetric(horizontal: 16, vertical: 2)` margin around
  /// its card). Default matches SettingsTile out of the box.
  final EdgeInsets overlayPadding;

  const TapShimmer({
    super.key,
    required this.child,
    required this.active,
    this.sweepDuration = const Duration(milliseconds: 1000),
    this.highlightColor = const Color(0x44FFFFFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.overlayPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 2,
    ),
  });

  @override
  State<TapShimmer> createState() => _TapShimmerState();
}

class _TapShimmerState extends State<TapShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.sweepDuration,
    );
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(TapShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sweepDuration != widget.sweepDuration) {
      _controller.duration = widget.sweepDuration;
    }
    if (widget.active && !oldWidget.active) {
      _start();
    } else if (!widget.active && oldWidget.active) {
      _stop();
    }
  }

  void _start() {
    AppLogging.meshcore(
      'event=tap_shimmer.started duration_ms=${widget.sweepDuration.inMilliseconds}',
    );
    // Ping-pong: sweep left -> right -> left -> right while active.
    _controller.repeat(reverse: true);
  }

  void _stop() {
    _controller.stop();
    _controller.value = 0;
    AppLogging.meshcore('event=tap_shimmer.stopped');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) return widget.child;
    // Stack overlay (not ShaderMask) so the shimmer paints ON TOP of
    // the child rather than trying to mask through Material/InkWell
    // composited layers - ShaderMask is fragile there.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          // Padding insets the overlay to match the visible card area
          // (SettingsTile has 16/2 margin around its rounded card by
          // default). ClipRRect then contains the sweep to the rounded
          // shape so the shimmer behaves like an InkWell ripple.
          child: Padding(
            padding: widget.overlayPadding,
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    if (t == 0 || t == 1) return const SizedBox.shrink();
                    final peak = -0.3 + 1.6 * t;
                    // SizedBox.expand gives DecoratedBox concrete bounds.
                    return SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              widget.highlightColor,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [
                              0.0,
                              (peak - 0.2).clamp(0.0, 1.0),
                              peak.clamp(0.0, 1.0),
                              (peak + 0.2).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
