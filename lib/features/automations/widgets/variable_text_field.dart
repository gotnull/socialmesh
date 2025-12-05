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

/// Regex to match incomplete/malformed variable patterns
final _incompleteVariableRegex = RegExp(
  r'\{\{[^}]*\}(?!\})|\{\{[^}]*$|\{\{[^}]*\}[^}]',
);

/// Validates text for invalid variable patterns.
/// Returns list of invalid variables found, or empty list if all valid.
List<String> validateVariables(String text) {
  final invalidVars = <String>[];

  // Check for complete but invalid variables
  for (final match in _anyVariableRegex.allMatches(text)) {
    final varText = match.group(0)!;
    if (!validVariables.contains(varText)) {
      invalidVars.add(varText);
    }
  }

  // Check for incomplete patterns like {{node.name} or {{battery
  for (final match in _incompleteVariableRegex.allMatches(text)) {
    final varText = match.group(0)!;
    if (!invalidVars.contains(varText)) {
      invalidVars.add(varText);
    }
  }

  return invalidVars;
}

/// Custom TextEditingController that styles variables with background color
class _VariableTextEditingController extends TextEditingController {
  _VariableTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // Find all valid variables
    final validMatches = _variableRegex.allMatches(text).toList();

    // Find all invalid/incomplete patterns
    final invalidPatterns = <({int start, int end, String text})>[];

    // Complete but invalid {{...}}
    for (final match in _anyVariableRegex.allMatches(text)) {
      if (!validVariables.contains(match.group(0))) {
        invalidPatterns.add((
          start: match.start,
          end: match.end,
          text: match.group(0)!,
        ));
      }
    }

    // Incomplete patterns
    for (final match in _incompleteVariableRegex.allMatches(text)) {
      final alreadyFound = invalidPatterns.any(
        (p) =>
            (match.start >= p.start && match.start < p.end) ||
            (match.end > p.start && match.end <= p.end),
      );
      if (!alreadyFound) {
        invalidPatterns.add((
          start: match.start,
          end: match.end,
          text: match.group(0)!,
        ));
      }
    }

    // Build list of all styled ranges
    final styledRanges = <({int start, int end, bool isValid})>[];

    for (final match in validMatches) {
      styledRanges.add((start: match.start, end: match.end, isValid: true));
    }

    for (final pattern in invalidPatterns) {
      // Don't add if overlaps with valid
      final overlapsValid = styledRanges.any(
        (r) =>
            r.isValid &&
            ((pattern.start >= r.start && pattern.start < r.end) ||
                (pattern.end > r.start && pattern.end <= r.end)),
      );
      if (!overlapsValid) {
        styledRanges.add((
          start: pattern.start,
          end: pattern.end,
          isValid: false,
        ));
      }
    }

    // Sort by start position
    styledRanges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final range in styledRanges) {
      // Add text before the match
      if (range.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, range.start), style: style),
        );
      }

      // Style the variable
      final varText = text.substring(range.start, range.end);
      if (range.isValid) {
        spans.add(
          TextSpan(
            text: varText,
            style: style?.copyWith(
              color: AppTheme.successGreen,
              backgroundColor: AppTheme.successGreen.withValues(alpha: 0.2),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: varText,
            style: style?.copyWith(
              color: AppTheme.errorRed,
              backgroundColor: AppTheme.errorRed.withValues(alpha: 0.2),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      lastEnd = range.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    if (spans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    return TextSpan(children: spans, style: style);
  }
}

/// A text field that renders variables as styled chips inline.
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
  late _VariableTextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = _VariableTextEditingController(text: widget.value);
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

  /// Delete a variable from the text
  void deleteVariable(int start, int end) {
    HapticFeedback.lightImpact();

    final text = _controller.text;
    final newText = text.substring(0, start) + text.substring(end);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: start);

    widget.onChanged(newText);
  }

  /// Get all variable matches with their positions
  List<({String variable, int start, int end})> get variableMatches {
    final matches = <({String variable, int start, int end})>[];
    for (final match in _variableRegex.allMatches(_controller.text)) {
      matches.add((
        variable: match.group(0)!,
        start: match.start,
        end: match.end,
      ));
    }
    return matches;
  }

  bool get hasFocus => _hasFocus;

  @override
  Widget build(BuildContext context) {
    final invalidVars = validateVariables(widget.value);
    final hasError = invalidVars.isNotEmpty;
    final matches = variableMatches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
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
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matches.asMap().entries.map((entry) {
              final match = entry.value;
              final displayName =
                  _variableDisplayNames[match.variable] ?? match.variable;
              return _VariableChip(
                label: displayName,
                onDelete: () => deleteVariable(match.start, match.end),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// A deletable variable chip
class _VariableChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _VariableChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: AppTheme.successGreen),
            ),
          ),
        ],
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
