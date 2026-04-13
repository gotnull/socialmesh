// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// AnimatedAvatarStack — reusable premium avatar cluster component.
//
// Renders overlapping circular avatars in a compact stack with subtle
// cycling animation where the front-most avatar rotates back and the
// next avatar becomes visually prominent. Designed for card headers.
//
// This is a pure presentation widget. It accepts prepared view model
// data and does not perform any business logic or data selection.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Presentation model for a single item in an [AnimatedAvatarStack].
///
/// This is a pure view model — it contains only the data the widget
/// needs to render. Business logic and data selection happen in the
/// provider layer, not here.
@immutable
class AvatarStackItem {
  /// Stable identifier for this item, used for identity preservation
  /// across provider updates. Must be unique within the stack.
  final String id;

  /// The widget to render inside the circular avatar.
  ///
  /// This can be a [SigilAvatar], [NodeAvatar], [CircleAvatar],
  /// [Image], or any other compact widget. The stack does not
  /// prescribe what goes inside — it only manages layout and animation.
  final Widget child;

  /// Tooltip text shown on long-press. Also used as the semantic label
  /// for accessibility when [semanticLabel] is null.
  final String? tooltip;

  /// Semantic label for screen readers. Falls back to [tooltip] if null.
  final String? semanticLabel;

  /// Optional callback when this specific avatar is tapped.
  final VoidCallback? onTap;

  const AvatarStackItem({
    required this.id,
    required this.child,
    this.tooltip,
    this.semanticLabel,
    this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarStackItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Layout and animation constants for [AnimatedAvatarStack].
///
/// Avoids magic numbers scattered across the widget. All values are
/// tuned for the premium "quiet activity" aesthetic.
abstract final class AvatarStackDefaults {
  /// Default maximum number of visible avatars.
  static const int maxVisible = 4;

  /// Default avatar diameter in logical pixels.
  static const double avatarSize = 32;

  /// Default overlap as a fraction of [avatarSize] (0.0–1.0).
  ///
  /// 0.35 means each subsequent avatar overlaps 35% of the previous.
  static const double overlapFraction = 0.35;

  /// Default cycle interval between front-avatar rotations.
  static const Duration cycleInterval = Duration(seconds: 5);

  /// Default animation duration for the transition.
  static const Duration animationDuration = Duration(milliseconds: 700);

  /// Scale factor for the front-most avatar.
  static const double frontScale = 1.0;

  /// Scale factor for rear avatars (subtle depth during transition).
  static const double rearScale = 0.95;

  /// Opacity for the front-most avatar.
  static const double frontOpacity = 1.0;

  /// Opacity for rear avatars (fades during transition).
  static const double rearOpacity = 0.55;

  /// Border width around each avatar for visual separation.
  static const double borderWidth = 1.5;
}

/// A compact cluster of overlapping circular avatars with subtle
/// cycling animation.
///
/// The front-most avatar periodically rotates back into the stack
/// and the next avatar becomes visually prominent. This communicates
/// "live activity" in a premium, restrained way.
///
/// ## Features
///
/// - **Reusable**: Works with any [AvatarStackItem] content (sigils,
///   photos, initials). Not tied to NodeDex or any specific feature.
/// - **Lifecycle-aware**: Pauses animation when offscreen, backgrounded,
///   or when reduced-motion accessibility is active.
/// - **Stable ordering**: Only rotates visual prominence, never
///   reorders the semantic list from the provider.
/// - **Small static fallback**: Renders statically when < 2 items.
///
/// ## Usage
///
/// ```dart
/// AnimatedAvatarStack(
///   items: viewModelItems,
///   maxVisible: 4,
///   avatarSize: 32,
///   animationEnabled: !reduceMotion,
/// )
/// ```
class AnimatedAvatarStack extends StatefulWidget {
  /// The items to display, in provider-determined semantic order.
  ///
  /// The widget preserves this order and only cycles the visual
  /// front position. Items beyond [maxVisible] are not rendered.
  final List<AvatarStackItem> items;

  /// Maximum number of avatars to display. Items beyond this are
  /// hidden. Defaults to [AvatarStackDefaults.maxVisible].
  final int maxVisible;

  /// Diameter of each circular avatar in logical pixels.
  /// Defaults to [AvatarStackDefaults.avatarSize].
  final double avatarSize;

  /// How much each subsequent avatar overlaps the previous, as a
  /// fraction of [avatarSize] (0.0–1.0).
  /// Defaults to [AvatarStackDefaults.overlapFraction].
  final double overlapFraction;

  /// Whether cycling animation is enabled. Set to `false` when
  /// reduced-motion accessibility is active.
  final bool animationEnabled;

  /// Interval between front-avatar rotations.
  /// Defaults to [AvatarStackDefaults.cycleInterval].
  final Duration cycleInterval;

  /// Optional semantic label for the entire stack, used by screen
  /// readers to describe the cluster.
  final String? semanticLabel;

  /// When true and [items.length] > [maxVisible], show a "+N" circle
  /// after the last visible avatar indicating how many items are hidden.
  final bool showOverflowCount;

  /// Optional callback when the overflow "+N" circle is tapped.
  final VoidCallback? onOverflowTap;

  /// Semantic label for the overflow "+N" circle, used by screen readers.
  /// If null, defaults to '+N more' (not localized). Callers should
  /// provide a localized string via `context.l10n.avatarStackOverflowLabel`.
  final String? overflowSemanticLabel;

  const AnimatedAvatarStack({
    super.key,
    required this.items,
    this.maxVisible = AvatarStackDefaults.maxVisible,
    this.avatarSize = AvatarStackDefaults.avatarSize,
    this.overlapFraction = AvatarStackDefaults.overlapFraction,
    this.animationEnabled = true,
    this.cycleInterval = AvatarStackDefaults.cycleInterval,
    this.semanticLabel,
    this.showOverflowCount = false,
    this.onOverflowTap,
    this.overflowSemanticLabel,
  }) : assert(
         overlapFraction >= 0 && overlapFraction < 1,
         'overlapFraction must be in [0, 1)',
       );

  @override
  State<AnimatedAvatarStack> createState() => AnimatedAvatarStackState();
}

/// State for [AnimatedAvatarStack].
///
/// Visible for testing — allows tests to verify cycling state.
class AnimatedAvatarStackState extends State<AnimatedAvatarStack>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Current rotation offset — the index that is visually "front".
  int _frontIndex = 0;

  /// Previous front index — used to interpolate between states.
  int _prevFrontIndex = 0;

  /// Timer for periodic cycling.
  Timer? _cycleTimer;

  /// Whether the app is in a background lifecycle state.
  bool _isBackgrounded = false;

  /// Explicit animation controller for coordinated motion.
  late final AnimationController _controller;

  /// Position curve: spring overshoot for premium feel.
  late final Animation<double> _positionAnim;

  /// Opacity curve: smooth ease-in-out, no overshoot.
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationEnabled
          ? AvatarStackDefaults.animationDuration
          : Duration.zero,
    );
    _positionAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );
    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.value = 1.0; // Start fully settled.
    WidgetsBinding.instance.addObserver(this);
    _startCycleTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AnimatedAvatarStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clamp front index if the list shrank.
    final visibleCount = _visibleCount;
    if (_frontIndex >= visibleCount) {
      _frontIndex = 0;
    }
    // Restart or stop timer if animation/items changed.
    if (oldWidget.animationEnabled != widget.animationEnabled ||
        oldWidget.cycleInterval != widget.cycleInterval ||
        oldWidget.items.length != widget.items.length) {
      _stopCycleTimer();
      _startCycleTimerIfNeeded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isBackgrounded = true;
        _stopCycleTimer();
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        _isBackgrounded = false;
        _startCycleTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _stopCycleTimer();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Number of items actually visible (capped by [maxVisible]).
  int get _visibleCount => widget.items.length.clamp(0, widget.maxVisible);

  /// Whether cycling should be active right now.
  bool get _shouldCycle =>
      widget.animationEnabled &&
      !_isBackgrounded &&
      _visibleCount >= 2 &&
      SchedulerBinding.instance.lifecycleState != AppLifecycleState.paused;

  void _startCycleTimerIfNeeded() {
    if (!_shouldCycle) return;
    _cycleTimer ??= Timer.periodic(widget.cycleInterval, (_) => _cycle());
  }

  void _stopCycleTimer() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
  }

  void _cycle() {
    if (!mounted || !_shouldCycle) return;
    final count = _visibleCount;
    if (count < 2) return;
    _prevFrontIndex = _frontIndex;
    _frontIndex = (_frontIndex - 1 + count) % count;
    _controller.forward(from: 0);
  }

  /// Expose the current front index for testing.
  int get currentFrontIndex => _frontIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final visibleCount = _visibleCount;
    final visibleItems = items.take(visibleCount).toList();

    final avatarSize = widget.avatarSize;
    final overlapPx = avatarSize * widget.overlapFraction;
    final step = avatarSize - overlapPx;

    // Overflow indicator calculation.
    final overflowCount = items.length - widget.maxVisible;
    final showOverflow = widget.showOverflowCount && overflowCount > 0;

    // Total width: first avatar + (n-1) * step + optional overflow step.
    final totalWidth =
        avatarSize + (visibleCount - 1 + (showOverflow ? 1 : 0)) * step;
    final totalHeight = avatarSize;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.9);

    // Horizontal padding absorbs easeInOutBack overshoot so avatars
    // don't glitch at the ShaderMask fade edges. Only needed when
    // cycling is possible (2+ items) or overflow is shown.
    final overshootPad = (visibleCount >= 2 || showOverflow) ? 8.0 : 0.0;

    Widget stack = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: totalWidth + overshootPad * 2,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: _buildPositionedAvatars(
              visibleItems,
              step,
              avatarSize,
              borderColor,
              overshootPad,
              showOverflow: showOverflow,
              overflowCount: overflowCount,
            ),
          ),
        );
      },
    );

    // Left-edge fade: the beginning of the stack recedes into
    // transparency, matching how horizontal chip rows fade.
    if (visibleCount >= 2) {
      stack = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.white, Colors.white],
          stops: [0.0, 0.25, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: stack,
      );
    }

    if (widget.semanticLabel != null) {
      stack = Semantics(label: widget.semanticLabel, child: stack);
    }

    return stack;
  }

  List<Widget> _buildPositionedAvatars(
    List<AvatarStackItem> items,
    double step,
    double size,
    Color borderColor,
    double padLeft, {
    required bool showOverflow,
    required int overflowCount,
  }) {
    final count = items.length;
    if (count == 0) return const [];

    final posT = _positionAnim.value;
    final opT = _opacityAnim.value;

    final widgets = <Widget>[];

    for (var paintOrder = 0; paintOrder < count; paintOrder++) {
      // Current slot assignment (target).
      final curSlot = paintOrder;
      final curItemIndex = (_frontIndex + 1 + curSlot) % count;

      // Find what slot this item *was* in, to interpolate from.
      int prevSlotForItem = curSlot; // fallback if not found
      for (var s = 0; s < count; s++) {
        if ((_prevFrontIndex + 1 + s) % count == curItemIndex) {
          prevSlotForItem = s;
          break;
        }
      }

      final item = items[curItemIndex];

      // Interpolate position from previous slot to current slot.
      final fromLeft = padLeft + prevSlotForItem * step;
      final toLeft = padLeft + curSlot * step;
      final targetLeft = fromLeft + (toLeft - fromLeft) * posT;

      // Interpolate opacity based on current slot.
      final fromT = count > 1 ? prevSlotForItem / (count - 1) : 1.0;
      final toT = count > 1 ? curSlot / (count - 1) : 1.0;
      final interpT = fromT + (toT - fromT) * opT;
      final opacity = _lerpDouble(
        AvatarStackDefaults.rearOpacity,
        AvatarStackDefaults.frontOpacity,
        interpT,
      );
      final scale = _lerpDouble(
        AvatarStackDefaults.rearScale,
        AvatarStackDefaults.frontScale,
        interpT,
      );

      Widget avatar = _AvatarCircle(
        size: size,
        borderColor: borderColor,
        child: item.child,
      );

      // Apply interpolated opacity and scale.
      avatar = Opacity(opacity: opacity.clamp(0.0, 1.0), child: avatar);
      if (scale != 1.0) {
        avatar = Transform.scale(scale: scale, child: avatar);
      }

      // Wrap with tooltip if provided.
      if (item.tooltip != null) {
        avatar = Tooltip(message: item.tooltip!, child: avatar);
      }

      // Wrap with tap handler if provided.
      if (item.onTap != null) {
        avatar = GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            item.onTap!();
          },
          child: avatar,
        );
      }

      // Wrap with semantics.
      avatar = Semantics(
        label: item.semanticLabel ?? item.tooltip,
        button: item.onTap != null,
        child: avatar,
      );

      widgets.add(
        Positioned(
          key: ValueKey(item.id),
          left: targetLeft,
          top: (widget.avatarSize - size * scale) / 2,
          width: size,
          height: size,
          child: avatar,
        ),
      );
    }

    // Overflow "+N" circle — static, not part of cycling animation.
    if (showOverflow) {
      final overflowLeft = padLeft + count * step;

      Widget overflowCircle = _OverflowCircle(
        size: size,
        borderColor: borderColor,
        overflowCount: overflowCount,
      );

      overflowCircle = Opacity(
        opacity: AvatarStackDefaults.frontOpacity,
        child: overflowCircle,
      );

      if (widget.onOverflowTap != null) {
        overflowCircle = GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onOverflowTap!();
          },
          child: overflowCircle,
        );
      }

      overflowCircle = Semantics(
        label: widget.overflowSemanticLabel ?? '+$overflowCount more',
        child: overflowCircle,
      );

      widgets.add(
        Positioned(
          key: const ValueKey('overflow'),
          left: overflowLeft,
          top: 0,
          width: size,
          height: size,
          child: overflowCircle,
        ),
      );
    }

    return widgets;
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// A "+N" overflow indicator circle matching the style of [_AvatarCircle].
class _OverflowCircle extends StatelessWidget {
  final double size;
  final Color borderColor;
  final int overflowCount;

  const _OverflowCircle({
    required this.size,
    required this.borderColor,
    required this.overflowCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF2A2A3E)
        : const Color(0xFFE0E0EA);
    final textColor = isDark ? Colors.white70 : Colors.black54;
    final fontSize = (size * 0.32).clamp(10.0, double.infinity);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: AvatarStackDefaults.borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$overflowCount',
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

/// A single circular avatar cell with a border for visual separation
/// from overlapping neighbours.
class _AvatarCircle extends StatelessWidget {
  final double size;
  final Color borderColor;
  final Widget child;

  const _AvatarCircle({
    required this.size,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF1E1E2E)
        : const Color(0xFFF0F0F5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: AvatarStackDefaults.borderWidth,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size - AvatarStackDefaults.borderWidth * 2,
          height: size - AvatarStackDefaults.borderWidth * 2,
          child: child,
        ),
      ),
    );
  }
}
