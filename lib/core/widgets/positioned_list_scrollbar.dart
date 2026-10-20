// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../theme.dart';

/// Where a [ScrollablePositionedList] viewport sits, in item units.
@immutable
class PositionedListScrollMetrics {
  const PositionedListScrollMetrics({
    required this.offsetItems,
    required this.visibleItems,
  });

  /// Items scrolled past the top edge, including the hidden part of the
  /// top-most visible item.
  final double offsetItems;

  /// Items on screen, counting partly visible items by their visible part.
  final double visibleItems;

  /// Derives the metrics from the list's reported [positions], or returns
  /// null when nothing is laid out yet.
  static PositionedListScrollMetrics? from(Iterable<ItemPosition> positions) {
    double visible = 0;
    ItemPosition? top;
    for (final p in positions) {
      final extent = p.itemTrailingEdge - p.itemLeadingEdge;
      if (extent <= 0) continue;
      final shown =
          math.min(p.itemTrailingEdge, 1.0) - math.max(p.itemLeadingEdge, 0.0);
      if (shown <= 0) continue;
      visible += shown / extent;
      if (top == null || p.index < top.index) top = p;
    }
    if (top == null) return null;
    final topExtent = top.itemTrailingEdge - top.itemLeadingEdge;
    final hiddenPart = top.itemLeadingEdge < 0
        ? -top.itemLeadingEdge / topExtent
        : 0.0;
    return PositionedListScrollMetrics(
      offsetItems: top.index + hiddenPart,
      visibleItems: visible,
    );
  }
}

/// Draggable scroll bar for a [ScrollablePositionedList].
///
/// The list reports item positions rather than exposing a
/// [ScrollController], so [RawScrollbar] cannot drive it. The thumb is sized
/// and placed from the visible items, and dragging it jumps to the matching
/// item. It shows while the list scrolls and fades after
/// [AppTheme.scrollbarTimeToFade], with the same metrics as GlassScaffold's
/// bar.
class PositionedListScrollbar extends StatefulWidget {
  const PositionedListScrollbar({
    super.key,
    required this.itemCount,
    required this.itemPositionsListener,
    required this.itemScrollController,
    required this.onDragToEnd,
    required this.child,
  });

  /// The item count of the wrapped list.
  final int itemCount;

  /// The listener attached to the wrapped list.
  final ItemPositionsListener itemPositionsListener;

  /// The controller attached to the wrapped list.
  final ItemScrollController itemScrollController;

  /// Called when the thumb reaches the bottom of the track. An index jump
  /// puts an item at the top of the viewport, so the list owner aligns the
  /// last item itself.
  final VoidCallback onDragToEnd;

  /// The [ScrollablePositionedList].
  final Widget child;

  @override
  State<PositionedListScrollbar> createState() =>
      _PositionedListScrollbarState();
}

class _PositionedListScrollbarState extends State<PositionedListScrollbar> {
  static const double _endThreshold = 0.995;

  Timer? _fadeTimer;
  bool _visible = false;
  bool _dragging = false;
  double _grabOffset = 0;
  double _dragThumbExtent = 0;
  double _dragVisibleItems = 0;
  int? _lastJumpIndex;
  bool _endReached = false;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions.addListener(_onPositions);
  }

  @override
  void didUpdateWidget(PositionedListScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemPositionsListener != widget.itemPositionsListener) {
      oldWidget.itemPositionsListener.itemPositions.removeListener(
        _onPositions,
      );
      widget.itemPositionsListener.itemPositions.addListener(_onPositions);
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    widget.itemPositionsListener.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _onPositions() {
    if (mounted && _visible) setState(() {});
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (notification.depth != 0) return false;
    if (!_visible) setState(() => _visible = true);
    _scheduleFade();
    return false;
  }

  void _scheduleFade() {
    _fadeTimer?.cancel();
    if (_dragging) return;
    _fadeTimer = Timer(AppTheme.scrollbarTimeToFade, () {
      if (mounted && !_dragging) setState(() => _visible = false);
    });
  }

  ({double top, double extent, double track})? _thumbGeometry(
    double height,
    PositionedListScrollMetrics metrics,
  ) {
    final track = height - 2 * AppTheme.scrollbarMargin;
    final scrollable = widget.itemCount - metrics.visibleItems;
    if (track <= 0 || scrollable <= 0) return null;
    final extent = math
        .max(
          AppTheme.scrollbarMinThumbLength,
          track * metrics.visibleItems / widget.itemCount,
        )
        .clamp(0.0, track)
        .toDouble();
    final fraction = (metrics.offsetItems / scrollable).clamp(0.0, 1.0);
    return (
      top: AppTheme.scrollbarMargin + fraction * (track - extent),
      extent: extent,
      track: track,
    );
  }

  void _onDragStart(DragStartDetails details, double extent, double inset) {
    final metrics = PositionedListScrollMetrics.from(
      widget.itemPositionsListener.itemPositions.value,
    );
    if (metrics == null) return;
    HapticFeedback.selectionClick();
    _fadeTimer?.cancel();
    setState(() => _dragging = true);
    _grabOffset = (details.localPosition.dy - inset).clamp(0.0, extent);
    _dragThumbExtent = extent;
    _dragVisibleItems = metrics.visibleItems;
    _lastJumpIndex = null;
    _endReached = false;
  }

  void _onDragUpdate(DragUpdateDetails details, double track) {
    if (!_dragging) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final travel = track - _dragThumbExtent;
    if (travel <= 0) return;
    final thumbTop = local.dy - AppTheme.scrollbarMargin - _grabOffset;
    final fraction = (thumbTop / travel).clamp(0.0, 1.0);

    if (fraction >= _endThreshold) {
      if (!_endReached) {
        _endReached = true;
        _lastJumpIndex = null;
        widget.onDragToEnd();
      }
      return;
    }
    _endReached = false;
    final scrollable = math.max(0.0, widget.itemCount - _dragVisibleItems);
    final index = (fraction * scrollable).round().clamp(
      0,
      widget.itemCount - 1,
    );
    if (index == _lastJumpIndex) return;
    _lastJumpIndex = index;
    widget.itemScrollController.jumpTo(index: index);
  }

  void _onDragEnd() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _scheduleFade();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = PositionedListScrollMetrics.from(
          widget.itemPositionsListener.itemPositions.value,
        );
        final geometry = metrics == null
            ? null
            : _thumbGeometry(constraints.maxHeight, metrics);
        final shown = _visible || _dragging;

        return Stack(
          children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
            if (geometry != null)
              _buildThumb(context, geometry, shown, constraints.maxHeight),
          ],
        );
      },
    );
  }

  Widget _buildThumb(
    BuildContext context,
    ({double top, double extent, double track}) geometry,
    bool shown,
    double height,
  ) {
    // The touch target is at least kMinInteractiveDimension on both axes
    // while the painted thumb stays thin, matching RawScrollbar.
    final hitExtent = math.max(geometry.extent, kMinInteractiveDimension);
    final inset = (hitExtent - geometry.extent) / 2;
    final hitTop = (geometry.top - inset)
        .clamp(0.0, math.max(0.0, height - hitExtent))
        .toDouble();
    final thumbInset = geometry.top - hitTop;

    return Positioned(
      top: hitTop,
      right: 0,
      width: kMinInteractiveDimension,
      height: hitExtent,
      child: IgnorePointer(
        ignoring: !shown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) =>
              _onDragStart(d, geometry.extent, thumbInset),
          onVerticalDragUpdate: (d) => _onDragUpdate(d, geometry.track),
          onVerticalDragEnd: (_) => _onDragEnd(),
          onVerticalDragCancel: _onDragEnd,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: AppTheme.scrollbarFadeDuration,
            child: Padding(
              padding: EdgeInsets.only(
                top: thumbInset,
                right: AppTheme.scrollbarMargin,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: AppTheme.scrollbarThickness,
                  height: geometry.extent,
                  decoration: BoxDecoration(
                    color: context.textTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
