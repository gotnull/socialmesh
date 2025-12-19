import 'package:flutter/material.dart';

/// Auto-scrolling text widget for long text.
/// Only scrolls if the text overflows the available width.
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delayBefore;
  final Duration pauseBetween;
  final int? maxLines;
  final double velocity;

  const AutoScrollText(
    this.text, {
    super.key,
    this.style,
    this.delayBefore = const Duration(seconds: 1),
    this.pauseBetween = const Duration(seconds: 2),
    this.maxLines = 1,
    this.velocity = 35.0,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
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

    // Wait for scroll controller to be attached
    while (mounted && !_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;

    while (mounted && _needsScroll) {
      // Scroll distance: use the actual scrollable extent
      final scrollDistance = _scrollController.position.maxScrollExtent;
      if (scrollDistance <= 0) break;

      final duration = Duration(
        milliseconds: (scrollDistance / widget.velocity * 1000).round(),
      );

      // Scroll forward to show the end
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

      // Scroll back to start
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
        // If constraints are unbounded, fall back to static text with ellipsis
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

        // Simple clipped scrolling text - no ShaderMask, just proper clipping
        // Add a tiny bit of padding at the end to ensure last character isn't clipped
        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: widget.maxLines,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
