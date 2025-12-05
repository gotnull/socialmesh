import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../models/automation.dart';

/// Universal variables available in all automations
const _universalVariables = [
  '{{node.name}}',
  '{{battery}}',
  '{{location}}',
  '{{message}}',
  '{{time}}',
];

/// Trigger-specific context variables
const _triggerVariables = <TriggerType, List<String>>{
  TriggerType.batteryLow: ['{{threshold}}'],
  TriggerType.batteryFull: ['{{threshold}}'],
  TriggerType.messageContains: ['{{keyword}}'],
  TriggerType.geofenceEnter: ['{{zone.radius}}'],
  TriggerType.geofenceExit: ['{{zone.radius}}'],
  TriggerType.nodeSilent: ['{{silent.duration}}'],
  TriggerType.signalWeak: ['{{signal.threshold}}'],
  TriggerType.channelActivity: ['{{channel.name}}'],
};

/// Get all valid variables for a given trigger type
List<String> getValidVariables(TriggerType? triggerType) {
  final vars = List<String>.from(_universalVariables);
  if (triggerType != null && _triggerVariables.containsKey(triggerType)) {
    vars.addAll(_triggerVariables[triggerType]!);
  }
  return vars;
}

/// Display names for variables (without braces)
const _variableDisplayNames = {
  '{{node.name}}': 'node.name',
  '{{battery}}': 'battery',
  '{{location}}': 'location',
  '{{message}}': 'message',
  '{{time}}': 'time',
  '{{threshold}}': 'threshold',
  '{{keyword}}': 'keyword',
  '{{zone.radius}}': 'zone.radius',
  '{{silent.duration}}': 'silent.duration',
  '{{signal.threshold}}': 'signal.threshold',
  '{{channel.name}}': 'channel.name',
};

/// Variable descriptions for tooltips
const _variableDescriptions = {
  '{{node.name}}': 'Name of the triggering node',
  '{{battery}}': 'Current battery percentage',
  '{{location}}': 'GPS coordinates',
  '{{message}}': 'Message content',
  '{{time}}': 'Current timestamp',
  '{{threshold}}': 'Configured trigger threshold',
  '{{keyword}}': 'Matched keyword',
  '{{zone.radius}}': 'Geofence radius in meters',
  '{{silent.duration}}': 'Silent duration setting',
  '{{signal.threshold}}': 'Signal threshold (SNR)',
  '{{channel.name}}': 'Channel name',
};

/// Regex to match all valid variables (universal + trigger-specific)
final _variableRegex = RegExp(
  r'\{\{(node\.name|battery|location|message|time|threshold|keyword|zone\.radius|silent\.duration|signal\.threshold|channel\.name)\}\}',
);

/// Legacy export for backwards compatibility
List<String> get validVariables => _universalVariables;

/// Formatter that implements two-stage variable deletion.
/// First backspace marks variable red, second backspace deletes it.
class _VariableProtectionFormatter extends TextInputFormatter {
  final VariableTextFieldState state;

  _VariableProtectionFormatter(this.state);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    // Only intercept deletions
    if (newText.length >= oldText.length) {
      // Any typing clears the marked variable
      state._clearMarkedVariable();
      return newValue;
    }

    // Find what was deleted
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;

    // Check if deletion would break a variable
    for (final match in _variableRegex.allMatches(oldText)) {
      final varStart = match.start;
      final varEnd = match.end;

      // Case 1: Backspace at cursor
      if (oldSel.isCollapsed && newSel.isCollapsed) {
        final deletePos = newSel.baseOffset;

        // Check if we're deleting into a variable from the right (backspace)
        if (deletePos >= varStart && deletePos < varEnd) {
          // Is this variable already marked for deletion?
          if (state._markedVariableStart == varStart) {
            // Second backspace - delete the whole variable
            state._clearMarkedVariable();
            final result =
                oldText.substring(0, varStart) + oldText.substring(varEnd);
            return TextEditingValue(
              text: result,
              selection: TextSelection.collapsed(offset: varStart),
            );
          } else {
            // First backspace - mark it red, don't delete
            state._markVariableForDeletion(varStart, varEnd);
            return oldValue; // Keep text unchanged
          }
        }
      }

      // Case 2: Selection delete - check if selection partially overlaps variable
      if (!oldSel.isCollapsed) {
        final selStart = oldSel.start;
        final selEnd = oldSel.end;

        // If selection covers the whole variable, allow deletion
        if (selStart <= varStart && selEnd >= varEnd) {
          state._clearMarkedVariable();
          continue;
        }

        // If selection partially overlaps a variable, expand to include whole variable
        if ((selStart > varStart && selStart < varEnd) ||
            (selEnd > varStart && selEnd < varEnd)) {
          state._clearMarkedVariable();
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

    // Normal deletion outside variables
    state._clearMarkedVariable();
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

/// All trigger-specific variable names for color matching
const _allTriggerVariableNames = [
  '{{threshold}}',
  '{{keyword}}',
  '{{zone.radius}}',
  '{{silent.duration}}',
  '{{signal.threshold}}',
  '{{channel.name}}',
];

/// Custom controller that styles variables with colored text.
/// Supports marking a variable red for pending deletion.
/// Universal variables are green, trigger context variables are amber.
class _VariableTextController extends TextEditingController {
  int? markedStart;
  int? markedEnd;

  _VariableTextController({super.text});

  void setMarkedVariable(int? start, int? end) {
    markedStart = start;
    markedEnd = end;
    notifyListeners();
  }

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

      // Check if this variable is marked for deletion
      final isMarked = markedStart == match.start && markedEnd == match.end;
      final variableText = match.group(0)!;
      final isTriggerContext = _allTriggerVariableNames.contains(variableText);

      // Red if marked, amber if trigger context, green if universal
      final Color color;
      if (isMarked) {
        color = AppTheme.errorRed;
      } else if (isTriggerContext) {
        color = Colors.amber;
      } else {
        color = AppTheme.successGreen;
      }

      // Style the variable
      spans.add(
        TextSpan(
          text: variableText,
          style: style?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            backgroundColor: color.withValues(alpha: 0.15),
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
  final TriggerType? triggerType;

  const VariableTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.hintText = '',
    this.maxLines = 1,
    this.focusNode,
    this.onFocusChange,
    this.triggerType,
  });

  @override
  State<VariableTextField> createState() => VariableTextFieldState();
}

class VariableTextFieldState extends State<VariableTextField> {
  late _VariableTextController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;
  int? _markedVariableStart;

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
      _clearMarkedVariable();
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
    if (!_focusNode.hasFocus) {
      _clearMarkedVariable();
    }
    widget.onFocusChange?.call();
  }

  void _markVariableForDeletion(int start, int end) {
    _markedVariableStart = start;
    _controller.setMarkedVariable(start, end);
    HapticFeedback.lightImpact();
  }

  void _clearMarkedVariable() {
    if (_markedVariableStart != null) {
      _markedVariableStart = null;
      _controller.setMarkedVariable(null, null);
    }
  }

  void _onSelectionChange() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (!selection.isValid) return;

    final cursorPos = selection.baseOffset;

    // Check if cursor/tap is on a variable
    for (final match in _variableRegex.allMatches(text)) {
      if (cursorPos >= match.start && cursorPos <= match.end) {
        // Cursor is on or inside a variable
        if (selection.isCollapsed) {
          // Single tap - mark it for deletion (turns red)
          if (_markedVariableStart != match.start) {
            _markVariableForDeletion(match.start, match.end);
          }
          // Move cursor to end of variable
          if (cursorPos < match.end) {
            _controller.selection = TextSelection.collapsed(offset: match.end);
          }
        }
        return;
      }
    }

    // Cursor moved outside any variable - clear marking
    _clearMarkedVariable();
  }

  /// Insert a variable at current cursor position
  void insertVariable(String variable) {
    final availableVars = getValidVariables(widget.triggerType);
    if (!availableVars.contains(variable)) return;
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
      onChanged: (value) {
        _clearMarkedVariable();
        widget.onChanged(value);
      },
      inputFormatters: [_VariableProtectionFormatter(this)],
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
  final TriggerType? triggerType;
  final bool showDeleteHint;

  const VariableChipPicker({
    super.key,
    this.targetField,
    this.isActive = false,
    this.triggerType,
    this.showDeleteHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final availableVars = getValidVariables(triggerType);
    final universalVars = availableVars
        .where((v) => _universalVariables.contains(v))
        .toList();
    final triggerVars = availableVars
        .where((v) => !_universalVariables.contains(v))
        .toList();

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
            children: universalVars.map((v) => _buildChip(v, false)).toList(),
          ),
          if (triggerVars.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Trigger context:',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: triggerVars.map((v) => _buildChip(v, true)).toList(),
            ),
          ],
          if (showDeleteHint) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Tap a variable in the field to select it, then backspace to delete',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String variable, bool isTriggerSpecific) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    final description = _variableDescriptions[variable];

    return Tooltip(
      message: description ?? displayName,
      child: GestureDetector(
        onTap: isActive && targetField != null
            ? () => targetField!.insertVariable(variable)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? (isTriggerSpecific
                      ? Colors.amber.withValues(alpha: 0.15)
                      : AppTheme.successGreen.withValues(alpha: 0.15))
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? (isTriggerSpecific
                        ? Colors.amber.withValues(alpha: 0.4)
                        : AppTheme.successGreen.withValues(alpha: 0.4))
                  : AppTheme.darkBorder,
            ),
          ),
          child: Text(
            displayName,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? (isTriggerSpecific ? Colors.amber : AppTheme.successGreen)
                  : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
