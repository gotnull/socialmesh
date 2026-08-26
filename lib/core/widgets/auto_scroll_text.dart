// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:socialmesh/core/theme.dart';

/// Auto-scrolling text widget for long text.
/// Only scrolls if the text overflows the available width.
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delayBefore;
  final Duration pauseBetween;
  final int? maxLines;
  final double velocity;
  final double fadeWidth;
  final TextAlign textAlign;

  const AutoScrollText(
    this.text, {
    super.key,
    this.style,
    this.delayBefore = const Duration(seconds: 1),
    this.pauseBetween = const Duration(seconds: 2),
    this.maxLines = 1,
    this.velocity = 35.0,
    this.fadeWidth = 20.0,
    this.textAlign = TextAlign.start,
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
  double _scrollPosition = 0;

  /// The in-flight delay, held so disposal can cancel it.
  ///
  /// An uncancellable delay left a pending timer behind after the widget
  /// was disposed. The `mounted` guards stop the work, but the timer
  /// still outlives the widget - which trips `flutter_test`'s
  /// pending-timer assertion and fails any widget test covering a screen
  /// that contains a marquee.
  Timer? _delayTimer;
  Completer<void>? _delayCompleter;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) {
      setState(() {
        _scrollPosition = _scrollController.offset;
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _delayTimer = null;
    // Completed rather than abandoned: an un-completed future would
    // leave the scroll loop suspended forever holding this State.
    final pending = _delayCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    _delayCompleter = null;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// A cancellable delay. Cancelled and completed on dispose.
  Future<void> _delay(Duration duration) {
    _delayTimer?.cancel();
    final completer = Completer<void>();
    _delayCompleter = completer;
    _delayTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _startScrollAnimation() async {
    if (!mounted || _isScrolling || !_needsScroll) return;
    _isScrolling = true;

    // Wait before starting
    await _delay(widget.delayBefore);
    if (!mounted) return;

    // Wait for scroll controller to be attached
    while (mounted && !_scrollController.hasClients) {
      await _delay(const Duration(milliseconds: 50));
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
      await _delay(widget.pauseBetween);
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
      await _delay(widget.pauseBetween);
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
            textAlign: widget.textAlign,
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
            textAlign: widget.textAlign,
          );
        }

        // Schedule scroll animation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isScrolling) {
            _startScrollAnimation();
          }
        });

        // Calculate fade opacities based on scroll position
        final maxScroll = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : (_textWidth - _availableWidth);
        final fadeStop = widget.fadeWidth / _availableWidth;

        // Show leading fade when scrolled (not at start)
        final showLeadingFade = _scrollPosition > 0;
        // Show trailing fade when not fully scrolled (not at end)
        final showTrailingFade = _scrollPosition < maxScroll - 1;

        // Build gradient stops
        final List<double> stops = [0.0, fadeStop, 1.0 - fadeStop, 1.0];
        final List<Color> colors = [
          showLeadingFade ? Colors.transparent : SemanticColors.highContrast,
          SemanticColors.highContrast,
          SemanticColors.highContrast,
          showTrailingFade ? Colors.transparent : SemanticColors.highContrast,
        ];

        return ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: colors, stops: stops).createShader(bounds),
          blendMode: BlendMode.dstIn,
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
