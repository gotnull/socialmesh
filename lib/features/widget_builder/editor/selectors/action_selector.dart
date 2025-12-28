import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../models/widget_schema.dart';

/// Visual action selector with guided configuration
class ActionSelector extends StatefulWidget {
  final ActionSchema? currentAction;
  final void Function(ActionSchema?) onSelect;

  const ActionSelector({super.key, this.currentAction, required this.onSelect});

  /// Show as bottom sheet and return selected action
  static Future<ActionSchema?> show({
    required BuildContext context,
    ActionSchema? currentAction,
  }) {
    return AppBottomSheet.show<ActionSchema>(
      context: context,
      child: _ActionSelectorSheet(currentAction: currentAction),
    );
  }

  @override
  State<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends State<ActionSelector> {
  @override
  Widget build(BuildContext context) {
    final hasAction =
        widget.currentAction != null &&
        widget.currentAction!.type != ActionType.none;

    return InkWell(
      onTap: () async {
        final result = await ActionSelector.show(
          context: context,
          currentAction: widget.currentAction,
        );
        widget.onSelect(result);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.background,
          borderRadius: BorderRadius.circular(8),
          border: hasAction
              ? Border.all(color: context.accentColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              hasAction ? Icons.touch_app : Icons.add_circle_outline,
              size: 20,
              color: hasAction ? context.accentColor : context.textSecondary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAction
                        ? _getActionLabel(widget.currentAction!)
                        : 'Add tap action...',
                    style: TextStyle(
                      color: hasAction
                          ? context.textPrimary
                          : context.textSecondary,
                      fontWeight: hasAction
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  if (hasAction)
                    Text(
                      _getActionDescription(widget.currentAction!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (hasAction)
              IconButton(
                onPressed: () => widget.onSelect(null),
                icon: Icon(Icons.close, size: 18, color: context.textSecondary),
                visualDensity: VisualDensity.compact,
              )
            else
              Icon(Icons.chevron_right, color: context.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(ActionSchema action) {
    switch (action.type) {
      case ActionType.sendMessage:
        return 'Send Message';
      case ActionType.shareLocation:
        return 'Share Location';
      case ActionType.traceroute:
        return 'Traceroute';
      case ActionType.requestPositions:
        return 'Request Positions';
      case ActionType.sos:
        return 'SOS Alert';
      case ActionType.navigate:
        return 'Navigate to ${action.navigateTo ?? 'screen'}';
      case ActionType.openUrl:
        return 'Open URL';
      case ActionType.copyToClipboard:
        return 'Copy to Clipboard';
      default:
        return 'No action';
    }
  }

  String _getActionDescription(ActionSchema action) {
    switch (action.type) {
      case ActionType.sendMessage:
        return action.requiresNodeSelection == true
            ? 'Pick node, then send'
            : 'Quick message sheet';
      case ActionType.shareLocation:
        return 'Share your current GPS';
      case ActionType.traceroute:
        return action.requiresNodeSelection == true
            ? 'Pick node to trace'
            : 'Trace route to node';
      case ActionType.requestPositions:
        return 'Request all node positions';
      case ActionType.sos:
        return 'Emergency alert';
      case ActionType.navigate:
        return 'Open ${action.navigateTo ?? 'another screen'}';
      case ActionType.openUrl:
        return action.url ?? 'External link';
      case ActionType.copyToClipboard:
        return 'Copy bound value';
      default:
        return '';
    }
  }
}

/// Bottom sheet for selecting and configuring actions
class _ActionSelectorSheet extends StatefulWidget {
  final ActionSchema? currentAction;

  const _ActionSelectorSheet({this.currentAction});

  @override
  State<_ActionSelectorSheet> createState() => _ActionSelectorSheetState();
}

class _ActionSelectorSheetState extends State<_ActionSelectorSheet> {
  ActionType? _selectedType;
  bool _requiresNodeSelection = false;
  bool _requiresChannelSelection = false;
  String? _navigateTo;
  String? _url;
  String? _label;

  @override
  void initState() {
    super.initState();
    if (widget.currentAction != null) {
      _selectedType = widget.currentAction!.type;
      _requiresNodeSelection =
          widget.currentAction!.requiresNodeSelection ?? false;
      _requiresChannelSelection =
          widget.currentAction!.requiresChannelSelection ?? false;
      _navigateTo = widget.currentAction!.navigateTo;
      _url = widget.currentAction!.url;
      _label = widget.currentAction!.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.touch_app, size: 20, color: accentColor),
            SizedBox(width: 8),
            Text(
              'What should happen when tapped?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose an action for this element',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        SizedBox(height: 20),

        // Action categories
        _buildSectionLabel('MESSAGING'),
        const SizedBox(height: 8),
        _buildActionTile(
          type: ActionType.sendMessage,
          icon: Icons.send,
          title: 'Send Message',
          description: 'Open message composer to send a message',
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          type: ActionType.shareLocation,
          icon: Icons.location_on,
          title: 'Share Location',
          description: 'Share your current GPS position',
          color: Colors.green,
        ),

        const SizedBox(height: 16),
        _buildSectionLabel('NETWORK'),
        const SizedBox(height: 8),
        _buildActionTile(
          type: ActionType.traceroute,
          icon: Icons.timeline,
          title: 'Traceroute',
          description: 'Trace the route to a node',
          color: Colors.orange,
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          type: ActionType.requestPositions,
          icon: Icons.refresh,
          title: 'Request Positions',
          description: 'Ask all nodes to report their position',
          color: Colors.purple,
        ),

        const SizedBox(height: 16),
        _buildSectionLabel('EMERGENCY'),
        const SizedBox(height: 8),
        _buildActionTile(
          type: ActionType.sos,
          icon: Icons.warning_amber,
          title: 'SOS Alert',
          description: 'Send emergency alert to all nodes',
          color: Colors.red,
        ),

        // Configuration options based on selected type
        if (_selectedType != null) ...[
          const SizedBox(height: 20),
          _buildConfigSection(accentColor),
        ],

        const SizedBox(height: 20),

        // Confirm button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedType != null ? _confirm : null,
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              disabledBackgroundColor: context.border,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _selectedType != null ? 'Add Action' : 'Select an action',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActionTile({
    required ActionType type,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : context.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : context.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Options',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildTypeSpecificOptions(),
        ],
      ),
    );
  }

  List<Widget> _buildTypeSpecificOptions() {
    switch (_selectedType) {
      case ActionType.sendMessage:
        return [
          _buildCheckbox(
            label: 'Show node picker first',
            subtitle: 'Let user choose which node to message',
            value: _requiresNodeSelection,
            onChanged: (v) => setState(() => _requiresNodeSelection = v),
          ),
          const SizedBox(height: 8),
          _buildCheckbox(
            label: 'Show channel picker',
            subtitle: 'Let user choose which channel',
            value: _requiresChannelSelection,
            onChanged: (v) => setState(() => _requiresChannelSelection = v),
          ),
        ];
      case ActionType.traceroute:
        return [
          _buildCheckbox(
            label: 'Show node picker first',
            subtitle: 'Let user choose which node to trace',
            value: _requiresNodeSelection,
            onChanged: (v) => setState(() => _requiresNodeSelection = v),
          ),
        ];
      default:
        return [
          Text(
            'No additional options',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ];
    }
  }

  Widget _buildCheckbox({
    required String label,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: context.accentColor,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    if (_selectedType == null) return;

    final action = ActionSchema(
      type: _selectedType!,
      requiresNodeSelection: _requiresNodeSelection ? true : null,
      requiresChannelSelection: _requiresChannelSelection ? true : null,
      navigateTo: _navigateTo,
      url: _url,
      label: _label,
    );

    Navigator.pop(context, action);
  }
}
