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

/// Formatter that protects variables from partial deletion.
/// If a deletion would break into a variable, delete the whole variable instead.
class _VariableProtectionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    // Only intercept deletions
    if (newText.length >= oldText.length) return newValue;

    // Find what was deleted
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;

    // Check if deletion would break a variable
    for (final match in _variableRegex.allMatches(oldText)) {
      final varStart = match.start;
      final varEnd = match.end;

      // Case 1: Backspace at cursor - cursor was right after deletion point
      if (oldSel.isCollapsed && newSel.isCollapsed) {
        final deletePos = newSel.baseOffset;

        // Check if we're deleting into a variable from the right (backspace)
        if (deletePos >= varStart && deletePos < varEnd) {
          // Delete the whole variable
          final result =
              oldText.substring(0, varStart) + oldText.substring(varEnd);
          return TextEditingValue(
            text: result,
            selection: TextSelection.collapsed(offset: varStart),
          );
        }
      }

      // Case 2: Selection delete - check if selection partially overlaps variable
      if (!oldSel.isCollapsed) {
        final selStart = oldSel.start;
        final selEnd = oldSel.end;

        // If selection partially overlaps a variable, expand to include whole variable
        if ((selStart > varStart && selStart < varEnd) ||
            (selEnd > varStart && selEnd < varEnd)) {
          // Expand selection to include full variable and recurse
          final expandedStart = selStart <= varStart ? selStart : varStart;
          final expandedEnd = selEnd >= varEnd ? selEnd : varEnd;
          final result =
              oldText.substring(0, expandedStart) +
              oldText.substring(expandedEnd);
          return TextEditingValue(
            text: result,
            selection: TextSelection.collapsed(offset: expandedStart),
          );
        }
      }
    }

    return newValue;
  }
}

/// Validates text for invalid variable patterns.
List<String> validateVariables(String text) {
  final invalidVars = <String>[];
  final validMatches = _variableRegex.allMatches(text).toList();

  int pos = 0;
  while (pos < text.length - 1) {
    final idx = text.indexOf('{{', pos);
    if (idx == -1) break;

    final isValid = validMatches.any((m) => m.start == idx);
    if (!isValid) {
      final endBrace = text.indexOf('}}', idx);
      if (endBrace != -1) {
        invalidVars.add(text.substring(idx, endBrace + 2));
      } else {
        final end = text.indexOf(' ', idx);
        invalidVars.add(text.substring(idx, end == -1 ? text.length : end));
      }
    }
    pos = idx + 1;
  }

  return invalidVars;
}

/// Custom controller that styles variables with colored text (no WidgetSpans)
class _VariableTextController extends TextEditingController {
  _VariableTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) return TextSpan(text: '', style: style);

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in _variableRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, match.start), style: style),
        );
      }

      // Style the variable with green color and background
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style?.copyWith(
            color: AppTheme.successGreen,
            fontWeight: FontWeight.w600,
            backgroundColor: AppTheme.successGreen.withValues(alpha: 0.15),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return spans.isEmpty
        ? TextSpan(text: text, style: style)
        : TextSpan(children: spans, style: style);
  }
}

/// A text field with variable chips that insert at cursor position.
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
  late _VariableTextController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = _VariableTextController(text: widget.value);
    _controller.addListener(_onSelectionChange);

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(VariableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.text = widget.value;
      // Try to restore selection
      if (selection.isValid && selection.end <= widget.value.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onSelectionChange);
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
    widget.onFocusChange?.call();
  }

  void _onSelectionChange() {
    // If cursor is inside a variable, move it to the end of that variable
    final text = _controller.text;
    final selection = _controller.selection;

    if (!selection.isValid || !selection.isCollapsed) return;

    final cursorPos = selection.baseOffset;

    for (final match in _variableRegex.allMatches(text)) {
      if (cursorPos > match.start && cursorPos < match.end) {
        // Cursor is inside a variable - move to end
        _controller.selection = TextSelection.collapsed(offset: match.end);
        return;
      }
    }
  }

  /// Insert a variable at current cursor position
  void insertVariable(String variable) {
    if (!validVariables.contains(variable)) return;
    HapticFeedback.lightImpact();

    final text = _controller.text;
    final selection = _controller.selection;

    int insertAt = text.length;
    if (selection.isValid && selection.isCollapsed) {
      insertAt = selection.baseOffset;
    } else if (selection.isValid) {
      insertAt = selection.end;
    }

    final newText =
        text.substring(0, insertAt) + variable + text.substring(insertAt);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: insertAt + variable.length,
    );

    widget.onChanged(newText);
    _focusNode.requestFocus();
  }

  bool get hasFocus => _hasFocus;

  @override
  Widget build(BuildContext context) {
    final invalidVars = validateVariables(widget.value);
    final hasError = invalidVars.isNotEmpty;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      inputFormatters: [_VariableProtectionFormatter()],
      minLines: 2,
      maxLines: 5,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
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
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        errorText: hasError ? 'Invalid: ${invalidVars.join(", ")}' : null,
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
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.successGreen : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
