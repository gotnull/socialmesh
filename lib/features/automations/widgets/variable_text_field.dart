// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/automation.dart';

/// Universal variables available in all automations
const _universalVariables = [
  '{{node.name}}',
  '{{node.num}}',
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
  TriggerType.detectionSensor: ['{{sensor.name}}', '{{sensor.state}}'],
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
  '{{node.num}}': 'node.num',
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
  '{{sensor.name}}': 'sensor.name',
  '{{sensor.state}}': 'sensor.state',
};

/// Variable descriptions for tooltips
Map<String, String> _variableDescriptions(BuildContext context) => {
  '{{node.name}}': context.l10n.automationVariableDescNodeName,
  '{{node.num}}': context.l10n.automationVariableDescNodeNum,
  '{{battery}}': context.l10n.automationVariableDescBattery,
  '{{location}}': context.l10n.automationVariableDescLocation,
  '{{message}}': context.l10n.automationVariableDescMessage,
  '{{time}}': context.l10n.automationVariableDescTime,
  '{{threshold}}': context.l10n.automationVariableDescThreshold,
  '{{keyword}}': context.l10n.automationVariableDescKeyword,
  '{{zone.radius}}': context.l10n.automationVariableDescZoneRadius,
  '{{silent.duration}}': context.l10n.automationVariableDescSilentDuration,
  '{{signal.threshold}}': context.l10n.automationVariableDescSignalThreshold,
  '{{channel.name}}': context.l10n.automationVariableDescChannelName,
  '{{sensor.name}}': context.l10n.automationVariableDescSensorName,
  '{{sensor.state}}': context.l10n.automationVariableDescSensorState,
};

/// Variable category icons for the picker sheet
const _variableIcons = {
  '{{node.name}}': Icons.person_outline,
  '{{node.num}}': Icons.tag,
  '{{battery}}': Icons.battery_std,
  '{{location}}': Icons.location_on_outlined,
  '{{message}}': Icons.chat_bubble_outline,
  '{{time}}': Icons.schedule,
  '{{threshold}}': Icons.tune,
  '{{keyword}}': Icons.text_fields,
  '{{zone.radius}}': Icons.radar,
  '{{silent.duration}}': Icons.timer_outlined,
  '{{signal.threshold}}': Icons.signal_cellular_alt,
  '{{channel.name}}': Icons.forum_outlined,
  '{{sensor.name}}': Icons.sensors,
  '{{sensor.state}}': Icons.toggle_on_outlined,
};

/// Regex to match all valid variables (universal + trigger-specific)
final _variableRegex = RegExp(
  r'\{\{(node\.name|node\.num|battery|location|message|time|threshold|keyword|zone\.radius|silent\.duration|signal\.threshold|channel\.name|sensor\.name|sensor\.state)\}\}',
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
  '{{sensor.name}}',
  '{{sensor.state}}',
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
        color = AppTheme.warningYellow;
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
  final int maxLength;
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
    this.maxLength = 500,
    this.focusNode,
    this.onFocusChange,
    this.triggerType,
  });

  @override
  State<VariableTextField> createState() => VariableTextFieldState();
}

class VariableTextFieldState extends State<VariableTextField>
    with SingleTickerProviderStateMixin {
  late _VariableTextController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;
  int? _markedVariableStart;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -4, end: 2), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
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
    if (widget.value != _controller.text && !_hasFocus) {
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
    _shakeController.dispose();
    _controller.removeListener(_onSelectionChange);
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
      if (!_focusNode.hasFocus) {
        _markedVariableStart = null;
        _controller.setMarkedVariable(null, null);
      }
    });
    widget.onFocusChange?.call();

    // When gaining focus, check if cursor landed on a variable.
    // _onSelectionChange may have fired before focus was established,
    // so re-check now that focus is confirmed.
    if (_focusNode.hasFocus) {
      _onSelectionChange();
    }
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
    if (!_focusNode.hasFocus) return;

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

    final text = _controller.text;
    final selection = _controller.selection;

    int insertAt = text.length;
    if (selection.isValid && selection.isCollapsed) {
      insertAt = selection.baseOffset;
    } else if (selection.isValid) {
      insertAt = selection.end;
    }

    // Add trailing space so cursor isn't immediately on the variable (which would mark it red)
    final insertText = '$variable ';
    final newText =
        text.substring(0, insertAt) + insertText + text.substring(insertAt);

    // Enforce maxLength — don't insert if it would exceed the limit
    if (newText.length > widget.maxLength) {
      _triggerShake();
      return;
    }

    HapticFeedback.lightImpact();
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: insertAt + insertText.length,
    );

    widget.onChanged(newText);
    _focusNode.requestFocus();
  }

  bool get hasFocus => _hasFocus;

  @override
  Widget build(BuildContext context) {
    final invalidVars = validateVariables(widget.value);
    final hasError = invalidVars.isNotEmpty;

    final currentLength = _controller.text.length;
    final isNearLimit = currentLength > widget.maxLength * 0.8;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: TextField(
        maxLength: widget.maxLength,
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (value) {
          _clearMarkedVariable();
          widget.onChanged(value);
          setState(() {}); // Refresh counter
        },
        inputFormatters: [_VariableProtectionFormatter(this)],
        minLines: widget.maxLines,
        maxLines: widget.maxLines > 1 ? 5 : 1,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: AppTheme.errorRed),
                )
              : null,
          focusedBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: AppTheme.errorRed, width: 2),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          errorText: hasError
              ? 'Invalid: ${invalidVars.join(", ")}'
              : null, // lint-allow: hardcoded-string
          counterText: _hasFocus || isNearLimit
              ? '$currentLength / ${widget.maxLength}'
              : '',
          counterStyle: TextStyle(
            fontSize: 11,
            color: currentLength >= widget.maxLength
                ? AppTheme.errorRed
                : isNearLimit
                ? AppTheme.warningYellow
                : SemanticColors.muted,
          ),
        ),
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

  /// Number of quick-access chips to show inline before the "All" button
  static const _quickChipCount = 4;

  @override
  Widget build(BuildContext context) {
    final availableVars = getValidVariables(triggerType);
    final quickVars = availableVars.take(_quickChipCount).toList();
    final hasMore = availableVars.length > _quickChipCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...quickVars.map((v) => _buildChip(context, v)),
            if (hasMore)
              GestureDetector(
                onTap: isActive && targetField != null
                    ? () => _showVariablePickerSheet(context, availableVars)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15)
                        : context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(
                      color: isActive
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4)
                          : context.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.data_object,
                        size: 13,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : SemanticColors.disabled,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        context.l10n.automationVariableAllVariables,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : SemanticColors.disabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (showDeleteHint) ...[
          const SizedBox(height: AppTheme.spacing6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 12, color: SemanticColors.muted),
              const SizedBox(width: AppTheme.spacing4),
              Expanded(
                child: Text(
                  context.l10n.automationVariableDeleteHint,
                  style: TextStyle(color: SemanticColors.muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showVariablePickerSheet(
    BuildContext context,
    List<String> availableVars,
  ) {
    HapticFeedback.lightImpact();
    final universalVars = availableVars
        .where((v) => _universalVariables.contains(v))
        .toList();
    final triggerVars = availableVars
        .where((v) => !_universalVariables.contains(v))
        .toList();

    AppBottomSheet.showScrollable(
      context: context,
      title: context.l10n.automationVariablePickerTitle,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (scrollController) => _VariablePickerSheetContent(
        universalVars: universalVars,
        triggerVars: triggerVars,
        scrollController: scrollController,
        isActive: isActive,
        onSelect: (variable) {
          Navigator.pop(context);
          if (targetField != null) {
            targetField!.insertVariable(variable);
          }
        },
      ),
    );
  }

  Widget _buildChip(BuildContext context, String variable) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    final isTriggerSpecific = _allTriggerVariableNames.contains(variable);

    return GestureDetector(
      onTap: isActive && targetField != null
          ? () => targetField!.insertVariable(variable)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isTriggerSpecific
                    ? AppTheme.warningYellow.withValues(alpha: 0.15)
                    : AppTheme.successGreen.withValues(alpha: 0.15))
              : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(
            color: isActive
                ? (isTriggerSpecific
                      ? AppTheme.warningYellow.withValues(alpha: 0.4)
                      : AppTheme.successGreen.withValues(alpha: 0.4))
                : context.border,
          ),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive
                ? (isTriggerSpecific
                      ? AppTheme.warningYellow
                      : AppTheme.successGreen)
                : SemanticColors.disabled,
          ),
        ),
      ),
    );
  }
}

/// Searchable content for the variable picker bottom sheet
class _VariablePickerSheetContent extends StatefulWidget {
  final List<String> universalVars;
  final List<String> triggerVars;
  final ScrollController scrollController;
  final bool isActive;
  final ValueChanged<String> onSelect;

  const _VariablePickerSheetContent({
    required this.universalVars,
    required this.triggerVars,
    required this.scrollController,
    required this.isActive,
    required this.onSelect,
  });

  @override
  State<_VariablePickerSheetContent> createState() =>
      _VariablePickerSheetContentState();
}

class _VariablePickerSheetContentState
    extends State<_VariablePickerSheetContent> {
  String _search = '';

  List<String> _filter(BuildContext context, List<String> vars) {
    if (_search.isEmpty) return vars;
    final query = _search.toLowerCase();
    final descriptions = _variableDescriptions(context);
    return vars.where((v) {
      final display = (_variableDisplayNames[v] ?? v).toLowerCase();
      final desc = (descriptions[v] ?? '').toLowerCase();
      return display.contains(query) || desc.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUniversal = _filter(context, widget.universalVars);
    final filteredTrigger = _filter(context, widget.triggerVars);
    final hasResults =
        filteredUniversal.isNotEmpty || filteredTrigger.isNotEmpty;

    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: TextField(
            maxLength: 50,
            onChanged: (v) => setState(() => _search = v),
            autofocus: false,
            decoration: InputDecoration(
              hintText: context.l10n.automationVariableSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                borderSide: BorderSide(color: context.border),
              ),
              filled: true,
              fillColor: context.background,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Expanded(
          child: hasResults
              ? ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  children: [
                    if (filteredUniversal.isNotEmpty) ...[
                      _buildSectionHeader(
                        context,
                        context.l10n.automationVariableSectionUniversal,
                      ),
                      ...filteredUniversal.map(
                        (v) => _buildVariableTile(context, v, false),
                      ),
                    ],
                    if (filteredTrigger.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing12),
                      _buildSectionHeader(
                        context,
                        context.l10n.automationVariableSectionTrigger,
                      ),
                      ...filteredTrigger.map(
                        (v) => _buildVariableTile(context, v, true),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 32,
                        color: SemanticColors.disabled,
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        context.l10n.automationVariableNoMatch,
                        style: TextStyle(
                          color: SemanticColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppTheme.spacing6,
        top: AppTheme.spacing4,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SemanticColors.muted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildVariableTile(
    BuildContext context,
    String variable,
    bool isTriggerSpecific,
  ) {
    final displayName = _variableDisplayNames[variable] ?? variable;
    final description = _variableDescriptions(context)[variable] ?? '';
    final icon = _variableIcons[variable] ?? Icons.code;
    final accentColor = isTriggerSpecific
        ? AppTheme.warningYellow
        : AppTheme.successGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onSelect(variable);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11,
                            color: SemanticColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: accentColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
