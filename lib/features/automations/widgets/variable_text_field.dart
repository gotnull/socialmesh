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

/// A simple text field with variable chip insertion support.
/// Uses a standard TextField - variables are inserted at cursor position.
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
    // Only update if value changed externally
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

    // Calculate insertion point
    int insertAt;
    if (selection.isValid && selection.isCollapsed) {
      insertAt = selection.baseOffset;
    } else if (selection.isValid) {
      insertAt = selection.start;
    } else {
      insertAt = text.length;
    }

    // Insert the variable
    final newText =
        text.substring(0, insertAt) + variable + text.substring(insertAt);
    _controller.text = newText;

    // Move cursor after inserted variable
    final newPosition = insertAt + variable.length;
    _controller.selection = TextSelection.collapsed(offset: newPosition);

    widget.onChanged(newText);

    // Keep focus on the field
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  bool get hasFocus => _hasFocus;
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
    // Active if a target field exists (even if not currently focused)
    final showActive = isActive || targetField != null;

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
            showActive ? 'Tap to insert at cursor:' : 'Available variables:',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: validVariables
                .map((v) => _buildChip(v, showActive))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String variable, bool isActive) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    return GestureDetector(
      onTap: () {
        if (targetField != null) {
          targetField!.insertVariable(variable);
        }
      },
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
