import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

/// Valid variable names that can be used in automations
const validVariables = [
  '{{node.name}}',
  '{{battery}}',
  '{{location}}',
  '{{message}}',
  '{{time}}',
];

/// Display names for variables (without braces)
const _variableDisplayNames = {
  '{{node.name}}': 'node.name',
  '{{battery}}': 'battery',
  '{{location}}': 'location',
  '{{message}}': 'message',
  '{{time}}': 'time',
};

/// Regex to match valid variables
final _variableRegex = RegExp(
  r'\{\{(node\.name|battery|location|message|time)\}\}',
);

/// Regex to match ANY double-brace pattern (for detecting invalid ones)
final _anyVariableRegex = RegExp(r'\{\{[^}]*\}\}');

/// Validates text for invalid variable patterns.
/// Returns list of invalid variables found, or empty list if all valid.
List<String> validateVariables(String text) {
  final allMatches = _anyVariableRegex.allMatches(text).toList();
  final invalidVars = <String>[];

  for (final match in allMatches) {
    final varText = match.group(0)!;
    if (!validVariables.contains(varText)) {
      invalidVars.add(varText);
    }
  }

  return invalidVars;
}

/// A text field that renders variables as styled chips inline.
/// Shows TextField when focused for editing, rich text with chips when not focused.
class VariableTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final String hintText;
  final int maxLines;
  final FocusNode? focusNode;
  final VoidCallback? onFocusChange;

  const VariableTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.hintText = '',
    this.maxLines = 1,
    this.focusNode,
    this.onFocusChange,
  });

  @override
  State<VariableTextField> createState() => VariableTextFieldState();
}

class VariableTextFieldState extends State<VariableTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(VariableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
    widget.onFocusChange?.call();
  }

  /// Insert a variable at the current cursor position
  void insertVariable(String variable) {
    if (!validVariables.contains(variable)) return;

    HapticFeedback.lightImpact();

    final text = _controller.text;
    final selection = _controller.selection;

    int insertAt;
    if (selection.isValid && selection.isCollapsed) {
      insertAt = selection.baseOffset;
    } else if (selection.isValid) {
      insertAt = selection.start;
    } else {
      insertAt = text.length;
    }

    final newText =
        text.substring(0, insertAt) + variable + text.substring(insertAt);
    _controller.text = newText;

    final newPosition = insertAt + variable.length;
    _controller.selection = TextSelection.collapsed(offset: newPosition);

    widget.onChanged(newText);
    _focusNode.requestFocus();
  }

  bool get hasFocus => _hasFocus;

  /// Build rich text with inline chips for variables
  List<InlineSpan> _buildRichContent(String text) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _variableRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        );
      }

      // Add the chip as a WidgetSpan
      final variable = match.group(0)!;
      final displayName = _variableDisplayNames[variable] ?? variable;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppTheme.successGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              displayName,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.successGreen,
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final invalidVars = validateVariables(widget.value);
    final hasError = invalidVars.isNotEmpty;

    // Always show rich text with chips - use ExtendedText for inline editing
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: InputDecorator(
        isFocused: _hasFocus,
        decoration: InputDecoration(
          labelText: widget.labelText,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.errorRed),
                )
              : null,
          focusedBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.errorRed, width: 2),
                )
              : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          errorText: hasError ? 'Invalid: ${invalidVars.join(", ")}' : null,
        ),
        child: Stack(
          children: [
            // Invisible text field for input handling
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            // Visible rich content with chips
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: widget.value.isEmpty
                  ? Text(
                      widget.hintText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    )
                  : Text.rich(
                      TextSpan(children: _buildRichContent(widget.value)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget showing available variables that can be tapped to insert
class VariableChipPicker extends StatelessWidget {
  final VariableTextFieldState? targetField;
  final bool isActive;

  const VariableChipPicker({
    super.key,
    this.targetField,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isActive
                ? 'Tap to insert at cursor:'
                : 'Tap a field, then tap a variable:',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: validVariables.map((v) => _buildChip(v)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String variable) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    return GestureDetector(
      onTap: isActive && targetField != null
          ? () => targetField!.insertVariable(variable)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.successGreen.withValues(alpha: 0.15)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppTheme.successGreen.withValues(alpha: 0.4)
                : AppTheme.darkBorder,
          ),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.successGreen : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
