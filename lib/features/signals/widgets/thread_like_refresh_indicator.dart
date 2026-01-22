import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final Path _githubBasePath = _buildGithubPath();
final Rect _githubBaseBounds = _githubBasePath.getBounds();

/// Custom pull-to-refresh indicator with a thread-like animated path.
class ThreadLikeRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;

  const ThreadLikeRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
  });

  @override
  ThreadLikeRefreshIndicatorState createState() =>
      ThreadLikeRefreshIndicatorState();
}

class ThreadLikeRefreshIndicatorState extends State<ThreadLikeRefreshIndicator>
    with TickerProviderStateMixin {
  static const double _triggerDistance = 110;
  static const double _maxIndicatorHeight = 80;

  late final AnimationController _loopController;
  double _pullDistance = 0;
  bool _refreshing = false;
  DateTime? _lastHapticTime;
  DateTime? _lastOverscrollTime;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  void _startRefresh() {
    if (_refreshing) return;
    setState(() {
      _pullDistance = _triggerDistance;
      _refreshing = true;
    });
    // Ensure the looping animation runs while refreshing
    _updateLooping();

    widget.onRefresh().whenComplete(() {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullDistance = 0;
        });
        _updateLooping();
      }
    });
  }

  void _resetPull() {
    if (_refreshing) return;
    if (_pullDistance > 0) {
      setState(() => _pullDistance = 0);
      _updateLooping();
    }
  }

  void _updateLooping() {
    // Only run the repeating loop while a refresh is active. While the user
    // is pulling we calculate a pull-driven phase and *do not* enable the
    // continuous repeating animation — this keeps the motion deterministic
    // and prevents the "repeating over and over" behavior.
    final shouldLoop = _refreshing;
    if (shouldLoop) {
      if (!_loopController.isAnimating) {
        _loopController.value = 0.0;
        _loopController.repeat();
      }
    } else {
      if (_loopController.isAnimating) {
        _loopController.stop();
      }
      _loopController.value = 0.0;
    }
  }

  // Visible for tests: whether the internal loop animation is active.
  @visibleForTesting
  bool debugIsLoopingForTest() => _loopController.isAnimating;

  // Visible for tests: allow tests to simulate pulling and triggering refresh
  // without relying on platform-specific scroll behavior.
  // NOTE: Only use in tests.
  @visibleForTesting
  void debugSetPullDistanceForTest(double distance) {
    setState(() {
      _pullDistance = distance.clamp(0, _triggerDistance * 1.5);
    });
    _updateLooping();
  }

  @visibleForTesting
  void debugTriggerRefreshForTest() {
    _startRefresh();
  }

  void _maybeVibrate(double velocity, DateTime now) {
    if (_refreshing) return;
    final last = _lastHapticTime;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 120)) {
      return;
    }

    _lastHapticTime = now;
    if (velocity >= 1.0) {
      HapticFeedback.heavyImpact();
    } else if (velocity > 0.7) {
      HapticFeedback.mediumImpact();
    } else if (velocity > 0.35) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_refreshing && notification is ScrollUpdateNotification) {
      return false;
    }

    // Handle overscroll (platform may deliver OverscrollNotification)
    if (notification is OverscrollNotification &&
        notification.overscroll > 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      final now = DateTime.now();
      final dt = now
          .difference(_lastOverscrollTime ?? now)
          .inMilliseconds
          .clamp(1, double.maxFinite)
          .toDouble();
      final velocity = notification.overscroll / dt;
      _lastOverscrollTime = now;
      _maybeVibrate(velocity, now);
      setState(() {
        _pullDistance = (_pullDistance + notification.overscroll).clamp(
          0,
          _triggerDistance * 1.5,
        );
      });
      _updateLooping();

      // Some platforms deliver ScrollUpdateNotification with negative scrollDelta
      // when pulling down at the top instead of OverscrollNotification. Handle
      // that too so the indicator becomes visible on drag.
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        notification.scrollDelta != null &&
        notification.scrollDelta! < 0) {
      final overscroll = -notification.scrollDelta!; // convert to positive
      final now = DateTime.now();
      final dt = now
          .difference(_lastOverscrollTime ?? now)
          .inMilliseconds
          .clamp(1, double.maxFinite)
          .toDouble();
      final velocity = overscroll / dt;
      _lastOverscrollTime = now;
      _maybeVibrate(velocity, now);
      setState(() {
        _pullDistance = (_pullDistance + overscroll).clamp(
          0,
          _triggerDistance * 1.5,
        );
      });
      _updateLooping();
    } else if (notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >
                notification.metrics.minScrollExtent)) {
      if (_pullDistance >= _triggerDistance) {
        _startRefresh();
      } else {
        _resetPull();
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final indicatorHeight =
        (_refreshing
                ? _maxIndicatorHeight
                : _pullDistance.clamp(0, _maxIndicatorHeight))
            .toDouble();
    final progress = (_pullDistance / _triggerDistance).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, child) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: indicatorHeight,
                child: Opacity(
                  key: const Key('thread_like_indicator_opacity'),
                  opacity: indicatorHeight > 0 ? 1 : 0,
                  child: CustomPaint(
                    painter: _ThreadLikeRefreshPainter(
                      animationValue: _loopController.value,
                      progress: progress,
                      indicatorColor:
                          widget.indicatorColor ??
                          Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              );
            },
          ),
          Transform.translate(
            offset: Offset(0, indicatorHeight),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ThreadLikeRefreshPainter extends CustomPainter {
  final double animationValue;
  final double progress;
  final Color indicatorColor;

  _ThreadLikeRefreshPainter({
    required this.animationValue,
    required this.progress,
    required this.indicatorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final double scaleX = size.width / _githubBaseBounds.width;
    final double scaleY = size.height / _githubBaseBounds.height;
    final double scale = min(scaleX, scaleY) * 0.85;
    // First scale the base path to match the available indicator size.
    final matrix = Matrix4.identity()..scale(scale, scale);
    final Path scaledPath = _githubBasePath.transform(matrix.storage);
    // Align the scaled path so its top aligns with the top of the paint
    // area and it is centered horizontally. This guarantees the path's
    // top-middle (the original start point at y=0) is at canvas y=0 and
    // x=center, making the animation start predictable.
    final bounds = scaledPath.getBounds();
    final double dx = (size.width / 2) - bounds.center.dx;
    final double dy = -bounds.top + (paint.strokeWidth / 2) + 4.0; // padding
    final Path alignedPath = scaledPath.shift(Offset(dx, dy));

    final Color startColor = indicatorColor.withOpacity(0.6 + progress * 0.3);
    final Color peakColor = indicatorColor.withOpacity(0.95);
    final Color endColor = indicatorColor.withOpacity(
      0.35 + (1 - progress) * 0.3,
    );
    final Rect clipRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );
    paint.shader = LinearGradient(
      colors: [startColor, peakColor, endColor],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(clipRect);

    // Vary dash/gap sizes and animation speed with pull progress to mimic
    // the original "thread" animation: dashes grow as you pull, gaps shrink
    // slightly, and the speed increases.
    final double minDash = size.width * 0.06; // compact dashes
    final double maxDash = size.width * 0.38; // stretched dashes when pulled
    final double dashLength = minDash + (maxDash - minDash) * progress;
    final double gapLength = dashLength * (0.45 - (progress * 0.25));
    final double speedFactor = 0.6 + (progress * 1.4);

    // Cycle length for dash+gap. We'll bias the base offset by the current
    // pull progress so that as the user pulls the visible dashes grow from
    // the top-middle and sweep in an anti-clockwise direction. Then add a
    // small looping animation on top of that for subtle motion.
    final double cycle = dashLength + gapLength;

    // Pull-influenced phase (makes the path appear to sweep as you pull).
    final double pullPhase = progress * cycle * 1.3;
    // Small looping phase driven by the repeating controller.
    final double animPhase = animationValue * cycle * speedFactor * 0.9;

    // Use a negative sign to make the motion go anti-clockwise along the
    // original path direction. The final offset is in pixels along the
    // path metric.
    final double offsetPx = -(pullPhase + animPhase);

    // Slightly increase stroke when pulled for better visibility
    paint.strokeWidth = 2.0 + (3.0 * progress);

    final dashedPath = _createDashedPath(
      alignedPath,
      dashLength,
      gapLength,
      offsetPx,
    );

    canvas.drawPath(dashedPath, paint);

    // Draw a small moving head dot along the whole path so it follows the
    // continuous dash motion across segment boundaries. Compute the total
    // path length and place the head using the global offset normalized
    // into that length.
    final metrics = alignedPath.computeMetrics().toList(growable: false);
    if (metrics.isNotEmpty) {
      final double totalLen = metrics.fold<double>(0.0, (s, m) => s + m.length);
      if (totalLen > 0) {
        double t = offsetPx % totalLen;
        if (t < 0) t += totalLen;
        double accum = 0.0;
        for (final metric in metrics) {
          if (t <= accum + metric.length) {
            final localOffset = t - accum;
            final tangent = metric.getTangentForOffset(
              localOffset.clamp(0.0, metric.length),
            );
            if (tangent != null) {
              final headPaint = Paint()..color = peakColor.withOpacity(0.95);
              final headRadius = 2.5 + (2.5 * progress);
              canvas.drawCircle(tangent.position, headRadius, headPaint);
            }
            break;
          }
          accum += metric.length;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadLikeRefreshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.indicatorColor != indicatorColor;
  }
}

Path _buildGithubPath() {
  final path = Path()
    ..moveTo(61.2, 0)
    ..cubicTo(26.525, 0, 0, 26.325, 0, 61)
    ..cubicTo(0, 88.725, 17.45, 112.45, 42.375, 120.8)
    ..cubicTo(45.575, 121.375, 46.7, 119.4, 46.7, 117.775)
    ..cubicTo(46.7, 116.225, 46.625, 107.675, 46.625, 102.425)
    ..cubicTo(46.625, 102.425, 29.125, 106.175, 25.45, 94.975)
    ..cubicTo(25.45, 94.975, 22.6, 87.7, 18.5, 85.825)
    ..cubicTo(18.5, 85.825, 12.775, 81.9, 18.9, 81.975)
    ..cubicTo(18.9, 81.975, 25.125, 82.475, 28.55, 88.425)
    ..cubicTo(34.025, 98.075, 43.2, 95.3, 46.775, 93.65)
    ..cubicTo(47.35, 89.65, 48.975, 86.875, 50.775, 85.225)
    ..cubicTo(36.8, 83.675, 22.7, 81.65, 22.7, 57.6)
    ..cubicTo(22.7, 50.725, 24.6, 47.275, 28.6, 42.875)
    ..cubicTo(27.95, 41.25, 25.825, 34.55, 29.25, 25.9)
    ..cubicTo(34.475, 24.275, 46.5, 32.65, 46.5, 32.65)
    ..cubicTo(51.5, 31.25, 56.875, 30.525, 62.2, 30.525)
    ..cubicTo(67.525, 30.525, 72.9, 31.25, 77.9, 32.65)
    ..cubicTo(77.9, 32.65, 89.925, 24.25, 95.15, 25.9)
    ..cubicTo(98.575, 34.575, 96.45, 41.25, 95.8, 42.875)
    ..cubicTo(99.8, 47.3, 102.25, 50.75, 102.25, 57.6)
    ..cubicTo(102.25, 81.725, 87.525, 83.65, 73.55, 85.225)
    ..cubicTo(75.85, 87.2, 77.8, 90.95, 77.8, 96.825)
    ..cubicTo(77.8, 105.25, 77.725, 115.675, 77.725, 117.725)
    ..cubicTo(77.725, 119.35, 78.875, 121.325, 82.05, 120.75)
    ..cubicTo(107.05, 112.45, 124, 88.725, 124, 61)
    ..cubicTo(124, 26.325, 95.875, 0, 61.2, 0)
    ..close();
  return path;
}

Path _createDashedPath(
  Path source,
  double dashLength,
  double gapLength,
  double offset,
) {
  if (dashLength <= 0) {
    return source;
  }

  final cycle = dashLength + gapLength;
  if (cycle <= 0) return source;

  final dashed = Path();
  final normalizedOffset = offset % cycle;

  // Maintain a global 'pos' and 'draw' state across metrics so dashes do
  // not reset at metric boundaries, producing a continuous, smooth pattern.
  bool draw = true;
  double pos = -normalizedOffset;

  for (final metric in source.computeMetrics()) {
    while (pos < metric.length) {
      final segmentLength = draw ? dashLength : gapLength;
      final start = pos.clamp(0.0, metric.length);
      final end = (pos + segmentLength).clamp(0.0, metric.length);
      if (draw && end > start) {
        dashed.addPath(metric.extractPath(start, end), Offset.zero);
      }
      pos += segmentLength;
      draw = !draw;
    }
    // Advance pos into the next metric by subtracting the consumed length.
    pos -= metric.length;
  }

  return dashed;
}
