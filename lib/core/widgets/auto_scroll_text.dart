import 'package:flutter/material.dart';

/// Auto-scrolling text widget with edge fade effect for long text.
/// Only scrolls if the text overflows the available width.
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delayBefore;
  final Duration pauseBetween;
  final int? maxLines;
  final double fadeWidth;
  final bool fadedBorder;
  final double velocity;

  const AutoScrollText(
    this.text, {
    super.key,
    this.style,
    this.delayBefore = const Duration(seconds: 1),
    this.pauseBetween = const Duration(seconds: 2),
    this.maxLines = 1,
    this.fadeWidth = 12.0,
    this.fadedBorder = true,
    this.velocity = 35.0,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _needsScroll = false;
  double _textWidth = 0;
  double _availableWidth = 0;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrollAnimation() async {
    if (!mounted || _isScrolling || !_needsScroll) return;
    _isScrolling = true;

    // Wait before starting
    await Future.delayed(widget.delayBefore);
    if (!mounted) return;

    while (mounted && _needsScroll) {
      // Calculate scroll duration based on velocity
      final scrollDistance = _textWidth - _availableWidth + widget.fadeWidth;
      if (scrollDistance <= 0) break;

      final duration = Duration(
        milliseconds: (scrollDistance / widget.velocity * 1000).round(),
      );

      // Scroll forward
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          scrollDistance,
          duration: duration,
          curve: Curves.linear,
        );
      }
      if (!mounted) return;

      // Pause at end
      await Future.delayed(widget.pauseBetween);
      if (!mounted) return;

      // Scroll back at same speed
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: duration,
          curve: Curves.linear,
        );
      }
      if (!mounted) return;

      // Pause before repeating
      await Future.delayed(widget.pauseBetween);
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If constraints are unbounded, fall back to static text
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth <= 0 ||
            constraints.maxWidth.isInfinite) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Measure the text
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        _textWidth = textPainter.width;
        _availableWidth = constraints.maxWidth;
        _needsScroll = _textWidth > _availableWidth;

        // If text fits, just show static text
        if (!_needsScroll) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Schedule scroll animation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isScrolling) {
            _startScrollAnimation();
          }
        });

        // Build scrollable text with fade edges
        Widget scrollView = SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            softWrap: false,
          ),
        );

        // Add subtle fade effect if enabled
        if (widget.fadedBorder && widget.fadeWidth > 0) {
          final fadeRatio = (widget.fadeWidth / constraints.maxWidth).clamp(
            0.0,
            0.15,
          );
          scrollView = ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, fadeRatio, 1 - fadeRatio, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: scrollView,
          );
        }

        return scrollView;
      },
    );
  }
}
