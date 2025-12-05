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

/// A text field that displays variables as tappable chips inline.
/// Tapping a chip removes it. Variables can be inserted via the chips below.
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
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  // Parse text into segments (plain text and variables)
  List<_TextSegment> _segments = [];

  // Track which plain text segment is being edited
  int? _editingIndex;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _parseValue(widget.value);
    _focusNode.addListener(_onFocusChange);
    _editFocusNode.addListener(_onEditFocusChange);
  }

  @override
  void didUpdateWidget(VariableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reparse if value changed externally (not from our own edits)
    if (oldWidget.value != widget.value && _editingIndex == null) {
      _parseValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _editFocusNode.removeListener(_onEditFocusChange);
    _editFocusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
    widget.onFocusChange?.call();
  }

  void _onEditFocusChange() {
    if (!_editFocusNode.hasFocus && _editingIndex != null) {
      _finishEditing();
    }
    widget.onFocusChange?.call();
  }

  void _parseValue(String value) {
    _segments = [];
    final regex = RegExp(r'\{\{(node\.name|battery|location|message|time)\}\}');
    int lastEnd = 0;

    for (final match in regex.allMatches(value)) {
      // Add plain text before this match
      if (match.start > lastEnd) {
        final plainText = value.substring(lastEnd, match.start);
        if (plainText.isNotEmpty) {
          _segments.add(_TextSegment(text: plainText, isVariable: false));
        }
      }
      // Add the variable
      _segments.add(_TextSegment(text: match.group(0)!, isVariable: true));
      lastEnd = match.end;
    }

    // Add remaining plain text
    if (lastEnd < value.length) {
      final plainText = value.substring(lastEnd);
      if (plainText.isNotEmpty) {
        _segments.add(_TextSegment(text: plainText, isVariable: false));
      }
    }
  }

  String _buildValue() {
    return _segments.map((s) => s.text).join();
  }

  void _removeVariable(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _segments.removeAt(index);
    });
    widget.onChanged(_buildValue());
  }

  void insertVariable(String variable) {
    if (!validVariables.contains(variable)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _segments.add(_TextSegment(text: variable, isVariable: true));
    });
    widget.onChanged(_buildValue());
  }

  void _startEditing(int index) {
    setState(() {
      _editingIndex = index;
      _editController.text = _segments[index].text;
      _editController.selection = TextSelection.collapsed(
        offset: _editController.text.length,
      );
    });
    Future.microtask(() => _editFocusNode.requestFocus());
  }

  void _finishEditing() {
    if (_editingIndex == null) return;

    final newText = _editController.text;
    setState(() {
      if (newText.isEmpty) {
        _segments.removeAt(_editingIndex!);
      } else {
        _segments[_editingIndex!] = _TextSegment(
          text: newText,
          isVariable: false,
        );
      }
      _editingIndex = null;
    });
    widget.onChanged(_buildValue());
  }

  void _onEditChanged(String value) {
    if (_editingIndex == null) return;
    _segments[_editingIndex!] = _TextSegment(text: value, isVariable: false);
    widget.onChanged(_buildValue());
  }

  void _addNewText() {
    setState(() {
      _segments.add(_TextSegment(text: '', isVariable: false));
      _editingIndex = _segments.length - 1;
      _editController.text = '';
    });
    Future.microtask(() => _editFocusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // If no text segments exist or none being edited, start editing new text
        if (_editingIndex == null) {
          _addNewText();
        }
      },
      child: InputDecorator(
        isFocused: _hasFocus || _editFocusNode.hasFocus,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: _segments.isEmpty ? widget.hintText : null,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_segments.isEmpty && _editingIndex == null) {
      return const SizedBox(height: 20);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < _segments.length; i++)
          if (_segments[i].isVariable)
            _buildVariableChip(_segments[i].text, i)
          else if (_editingIndex == i)
            _buildInlineInput()
          else
            _buildPlainText(_segments[i].text, i),
        // Add button to append more text
        if (_editingIndex == null)
          GestureDetector(
            onTap: _addNewText,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.add, size: 16, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildVariableChip(String variable, int index) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    return GestureDetector(
      onTap: () => _removeVariable(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.successGreen.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.close,
              size: 14,
              color: AppTheme.successGreen.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlainText(String text, int index) {
    return GestureDetector(
      onTap: () => _startEditing(index),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildInlineInput() {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50),
        child: TextField(
          controller: _editController,
          focusNode: _editFocusNode,
          onChanged: _onEditChanged,
          onSubmitted: (_) => _finishEditing(),
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          maxLines: widget.maxLines,
        ),
      ),
    );
  }

  bool get hasFocus => _hasFocus || _editFocusNode.hasFocus;
}

class _TextSegment {
  final String text;
  final bool isVariable;

  _TextSegment({required this.text, required this.isVariable});
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
                ? 'Tap to insert, tap chip to remove:'
                : 'Available variables (tap a field first):',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: validVariables.map((v) {
              return _buildChip(v);
            }).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.successGreen.withValues(alpha: 0.2)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.successGreen.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: isActive ? AppTheme.successGreen : Colors.amber[300],
          ),
        ),
      ),
    );
  }
}
