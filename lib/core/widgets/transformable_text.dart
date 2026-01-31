// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A text overlay that can be dragged, scaled, and rotated with gestures.
///
/// This widget provides text editing capabilities:
/// - Drag to move
/// - Two-finger pinch to scale
/// - Two-finger rotate to rotate
/// - Tap to edit text
/// - Long press to delete
class TransformableText extends StatefulWidget {
  const TransformableText({
    super.key,
    required this.text,
    required this.onTextChanged,
    required this.onDelete,
    this.initialPosition = const Offset(0.5, 0.4),
    this.initialScale = 1.0,
    this.initialRotation = 0.0,
    this.textStyle,
    this.hasBackground = true,
    this.backgroundColor = Colors.black54,
    this.textColor = Colors.white,
    this.isEditable = true,
    this.showEditBorder = false,
    this.minScale = 0.5,
    this.maxScale = 3.0,
  });

  /// The text to display
  final String text;

  /// Called when text is edited
  final ValueChanged<String> onTextChanged;

  /// Called when delete is triggered
  final VoidCallback onDelete;

  /// Initial normalized position (0-1 range for x and y)
  final Offset initialPosition;

  /// Initial scale factor
  final double initialScale;

  /// Initial rotation in radians
  final double initialRotation;

  /// Custom text style
  final TextStyle? textStyle;

  /// Whether to show background behind text
  final bool hasBackground;

  /// Background color
  final Color backgroundColor;

  /// Text color
  final Color textColor;

  /// Whether text can be edited
  final bool isEditable;

  /// Whether to show edit border
  final bool showEditBorder;

  /// Minimum scale factor
  final double minScale;

  /// Maximum scale factor
  final double maxScale;

  @override
  State<TransformableText> createState() => TransformableTextState();
}

class TransformableTextState extends State<TransformableText> {
  late Offset _position;
  late double _scale;
  late double _rotation;

  // For gesture tracking
  Offset? _startFocalPoint;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _basePosition = Offset.zero;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _scale = widget.initialScale;
    _rotation = widget.initialRotation;
  }

  /// Get current transform state for saving
  TransformState get transformState =>
      TransformState(position: _position, scale: _scale, rotation: _rotation);

  /// Set transform state
  void setTransformState(TransformState state) {
    setState(() {
      _position = state.position;
      _scale = state.scale;
      _rotation = state.rotation;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startFocalPoint = details.focalPoint;
    _baseScale = _scale;
    _baseRotation = _rotation;
    _basePosition = _position;
    HapticFeedback.selectionClick();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size containerSize) {
    setState(() {
      // Update scale (with limits)
      _scale = (_baseScale * details.scale).clamp(
        widget.minScale,
        widget.maxScale,
      );

      // Update rotation
      _rotation = _baseRotation + details.rotation;

      // Update position based on drag
      if (_startFocalPoint != null) {
        final delta = details.focalPoint - _startFocalPoint!;
        _position = Offset(
          (_basePosition.dx + delta.dx / containerSize.width).clamp(0.1, 0.9),
          (_basePosition.dy + delta.dy / containerSize.height).clamp(0.1, 0.9),
        );
      }
    });
  }

  void _onTap() {
    if (widget.isEditable) {
      setState(() => _isEditing = true);
      _showTextEditor();
    }
  }

  void _onLongPress() {
    HapticFeedback.heavyImpact();
    _showDeleteConfirmation();
  }

  void _showTextEditor() {
    final controller = TextEditingController(text: widget.text);

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TextEditorSheet(
        controller: controller,
        textColor: widget.textColor,
        hasBackground: widget.hasBackground,
        onDone: (text) {
          Navigator.pop(context, text);
        },
      ),
    ).then((newText) {
      setState(() => _isEditing = false);
      if (newText != null && newText.isNotEmpty) {
        widget.onTextChanged(newText);
      } else if (newText != null && newText.isEmpty) {
        widget.onDelete();
      }
    });
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          'Delete text?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This will remove the text overlay.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

        // Calculate pixel position from normalized position
        final pixelX = _position.dx * containerSize.width;
        final pixelY = _position.dy * containerSize.height;

        return Stack(
          children: [
            Positioned(
              left: pixelX,
              top: pixelY,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: (d) => _onScaleUpdate(d, containerSize),
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Transform.scale(
                      scale: _scale,
                      child: _buildTextContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextContent() {
    final effectiveStyle = (widget.textStyle ?? const TextStyle()).copyWith(
      color: widget.textColor,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.hasBackground
            ? widget.backgroundColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: widget.showEditBorder || _isEditing
            ? Border.all(color: Colors.white38, width: 1.5)
            : null,
      ),
      child: Text(
        widget.text,
        style: widget.hasBackground
            ? effectiveStyle
            : effectiveStyle.copyWith(
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 4,
                    offset: const Offset(1, 1),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// State representing the transform of a text overlay
class TransformState {
  final Offset position;
  final double scale;
  final double rotation;

  const TransformState({
    this.position = const Offset(0.5, 0.4),
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  TransformState copyWith({Offset? position, double? scale, double? rotation}) {
    return TransformState(
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
    'positionX': position.dx,
    'positionY': position.dy,
    'scale': scale,
    'rotation': rotation,
  };

  factory TransformState.fromJson(Map<String, dynamic> json) {
    return TransformState(
      position: Offset(
        (json['positionX'] as num?)?.toDouble() ?? 0.5,
        (json['positionY'] as num?)?.toDouble() ?? 0.4,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Bottom sheet for editing text with color and style options
class _TextEditorSheet extends StatefulWidget {
  const _TextEditorSheet({
    required this.controller,
    required this.textColor,
    required this.hasBackground,
    required this.onDone,
  });

  final TextEditingController controller;
  final Color textColor;
  final bool hasBackground;
  final void Function(String) onDone;

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late Color _selectedColor;
  late bool _hasBackground;
  double _fontSize = 24;
  final FocusNode _focusNode = FocusNode();

  static const _colorOptions = [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30), // Red
    Color(0xFFFF9500), // Orange
    Color(0xFFFFCC00), // Yellow
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFF5856D6), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFF8E8E93), // Gray
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.textColor;
    _hasBackground = widget.hasBackground;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => widget.onDone(widget.controller.text),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => widget.onDone(widget.controller.text),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Text input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  style: TextStyle(
                    color: _selectedColor,
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type something...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 24),

              // Color picker
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Background toggle
                    GestureDetector(
                      onTap: () =>
                          setState(() => _hasBackground = !_hasBackground),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
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
                          size: 20,
                        ),
                      ),
                    ),
                    // Color options
                    ..._colorOptions.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? context.accentColor
                                  : Colors.white.withValues(alpha: 0.3),
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Size slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'A',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 16,
                        max: 48,
                        onChanged: (v) => setState(() => _fontSize = v),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                      ),
                    ),
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
