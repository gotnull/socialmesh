// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A draggable, resizable, and rotatable text widget for story creation.
/// Based on sticker_view's gesture handling approach.
class DraggableTextWidget extends StatefulWidget {
  const DraggableTextWidget({
    super.key,
    required this.text,
    required this.constraints,
    this.textStyle,
    this.backgroundColor,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onUpdate,
  });

  final String text;
  final Size constraints;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final ValueChanged<DraggableTextState>? onUpdate;

  @override
  State<DraggableTextWidget> createState() => _DraggableTextWidgetState();
}

class DraggableTextState {
  const DraggableTextState({
    required this.position,
    required this.scale,
    required this.rotation,
  });

  final Offset position;
  final double scale;
  final double rotation;
}

class _DraggableTextWidgetState extends State<DraggableTextWidget> {
  // Transform state
  Offset _position = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;

  // Gesture tracking
  Offset _startFocalPoint = Offset.zero;
  Offset _startPosition = Offset.zero;
  double _startScale = 1.0;
  double _startRotation = 0.0;

  @override
  void initState() {
    super.initState();
    // Center the text initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _position = Offset(
            widget.constraints.width / 2,
            widget.constraints.height * 0.4,
          );
        });
        _notifyUpdate();
      }
    });
  }

  void _notifyUpdate() {
    widget.onUpdate?.call(
      DraggableTextState(
        position: _position,
        scale: _scale,
        rotation: _rotation,
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startFocalPoint = details.focalPoint;
    _startPosition = _position;
    _startScale = _scale;
    _startRotation = _rotation;
    HapticFeedback.selectionClick();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle drag (translation)
      final delta = details.focalPoint - _startFocalPoint;
      _position = Offset(
        (_startPosition.dx + delta.dx).clamp(
          widget.constraints.width * 0.1,
          widget.constraints.width * 0.9,
        ),
        (_startPosition.dy + delta.dy).clamp(
          widget.constraints.height * 0.1,
          widget.constraints.height * 0.9,
        ),
      );

      // Handle scale (pinch)
      if (details.pointerCount > 1) {
        _scale = (_startScale * details.scale).clamp(0.5, 3.0);
        _rotation = _startRotation + details.rotation;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    HapticFeedback.lightImpact();
    _notifyUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx - 140, // Half of max width
      top: _position.dy - 30, // Approximate half height
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onLongPress?.call();
        },
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByVector3(Vector3(_scale, _scale, 1.0))
            ..rotateZ(_rotation),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: widget.isSelected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Text(
              widget.text,
              style:
                  widget.textStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple text editor overlay for story creation.
class StoryTextEditor extends StatefulWidget {
  const StoryTextEditor({
    super.key,
    required this.initialText,
    required this.initialColor,
    required this.initialSize,
    required this.initialHasBackground,
    required this.onDone,
    this.onCancel,
  });

  final String initialText;
  final Color initialColor;
  final double initialSize;
  final bool initialHasBackground;
  final void Function(String text, Color color, double size, bool hasBackground)
  onDone;
  final VoidCallback? onCancel;

  @override
  State<StoryTextEditor> createState() => _StoryTextEditorState();
}

class _StoryTextEditorState extends State<StoryTextEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late Color _selectedColor;
  late double _fontSize;
  late bool _hasBackground;

  static const List<Color> _colors = [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30), // Red
    Color(0xFFFF9500), // Orange
    Color(0xFFFFCC00), // Yellow
    Color(0xFF34C759), // Green
    Color(0xFF00C7BE), // Teal
    Color(0xFF007AFF), // Blue
    Color(0xFF5856D6), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFFAF52DE), // Magenta
    Color(0xFF8E8E93), // Gray
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _selectedColor = widget.initialColor;
    _fontSize = widget.initialSize;
    _hasBackground = widget.initialHasBackground;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleDone() {
    widget.onDone(_controller.text, _selectedColor, _fontSize, _hasBackground);
  }

  void _handleCancel() {
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _handleCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                  TextButton(
                    onPressed: _handleDone,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Text input with size slider
            Expanded(
              child: Row(
                children: [
                  // Vertical size slider
                  SizedBox(
                    width: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                  activeTrackColor: _selectedColor,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white24,
                                ),
                                child: Slider(
                                  value: _fontSize,
                                  min: 18,
                                  max: 56,
                                  onChanged: (v) =>
                                      setState(() => _fontSize = v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Text field centered
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _hasBackground
                                ? Colors.black.withValues(alpha: 0.6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              maxLines: null,
                              style: TextStyle(
                                color: _selectedColor,
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type something...',
                                hintStyle: TextStyle(
                                  color: _selectedColor.withValues(alpha: 0.5),
                                  fontSize: _fontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Balance spacer
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Color picker
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _colors.length + 1, // +1 for background toggle
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Background toggle
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _hasBackground = !_hasBackground),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _hasBackground
                              ? Colors.white
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.format_color_fill,
                          color: _hasBackground ? Colors.black : Colors.white,
                          size: 18,
                        ),
                      ),
                    );
                  }

                  final color = _colors[index - 1];
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Keyboard spacer
            SizedBox(height: keyboardHeight),
          ],
        ),
      ),
    );
  }
}
