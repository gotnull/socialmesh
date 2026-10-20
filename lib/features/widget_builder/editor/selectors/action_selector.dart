// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/gradient_border_container.dart';
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
        if (!mounted) return;
        widget.onSelect(result);
      },
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: GradientBorderContainer(
        borderRadius: 8,
        borderWidth: 2,
        accentOpacity: hasAction ? 0.5 : 0.0,
        backgroundColor: context.background,
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Row(
          children: [
            Icon(
              hasAction ? Icons.touch_app : Icons.add_circle_outline,
              size: 20,
              color: hasAction ? context.accentColor : context.textSecondary,
            ),
            SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAction
                        ? _getActionLabel(widget.currentAction!)
                        : context.l10n.widgetBuilderAddTapAction,
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
        return context.l10n.widgetBuilderActionSendMessage;
      case ActionType.shareLocation:
        return context.l10n.widgetBuilderActionShareLocation;
      case ActionType.traceroute:
        return context.l10n.widgetBuilderActionTraceroute;
      case ActionType.requestPositions:
        return context.l10n.widgetBuilderActionRequestPositions;
      case ActionType.sos:
        return context.l10n.widgetBuilderActionSosAlert;
      case ActionType.navigate:
        return context.l10n.widgetBuilderActionNavigateLabel;
      case ActionType.openUrl:
        return context.l10n.widgetBuilderActionOpenUrl;
      case ActionType.copyToClipboard:
        return context.l10n.widgetBuilderActionCopyToClipboard;
      default:
        return context.l10n.widgetBuilderActionNoAction;
    }
  }

  String _getActionDescription(ActionSchema action) {
    switch (action.type) {
      case ActionType.sendMessage:
        return action.requiresNodeSelection == true
            ? context.l10n.widgetBuilderPickNodeThenSend
            : context.l10n.widgetBuilderQuickMessageSheet;
      case ActionType.shareLocation:
        return context.l10n.widgetBuilderActionShareLocationDesc;
      case ActionType.traceroute:
        return action.requiresNodeSelection == true
            ? context.l10n.widgetBuilderPickNodeToTrace
            : context.l10n.widgetBuilderTraceRouteToNode;
      case ActionType.requestPositions:
        return context.l10n.widgetBuilderActionRequestPositionsDesc;
      case ActionType.sos:
        return context.l10n.widgetBuilderActionSosAlertDesc;
      case ActionType.navigate:
        return action.navigateTo ?? '';
      case ActionType.openUrl:
        return action.url ?? '';
      case ActionType.copyToClipboard:
        return context.l10n.widgetBuilderActionCopyToClipboard;
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
            SizedBox(width: AppTheme.spacing8),
            Text(
              context.l10n.widgetBuilderWhatShouldHappen,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.widgetBuilderChooseAction,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        SizedBox(height: AppTheme.spacing20),

        // Action categories
        _buildSectionLabel(context.l10n.widgetBuilderSectionMessaging),
        const SizedBox(height: AppTheme.spacing8),
        _buildActionTile(
          type: ActionType.sendMessage,
          icon: Icons.send,
          title: context.l10n.widgetBuilderActionSendMessageLabel,
          description: context.l10n.widgetBuilderActionSendMessageDesc,
          color: AccentColors.blue,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildActionTile(
          type: ActionType.shareLocation,
          icon: Icons.location_on,
          title: context.l10n.widgetBuilderActionShareLocationLabel,
          description: context.l10n.widgetBuilderActionShareLocationDesc,
          color: AppTheme.successGreen,
        ),

        const SizedBox(height: AppTheme.spacing16),
        _buildSectionLabel(context.l10n.widgetBuilderSectionNetwork),
        const SizedBox(height: AppTheme.spacing8),
        _buildActionTile(
          type: ActionType.traceroute,
          icon: Icons.timeline,
          title: context.l10n.widgetBuilderActionTracerouteLabel,
          description: context.l10n.widgetBuilderActionTracerouteDesc,
          color: AccentColors.orange,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildActionTile(
          type: ActionType.requestPositions,
          icon: Icons.refresh,
          title: context.l10n.widgetBuilderActionRequestPositionsLabel,
          description: context.l10n.widgetBuilderActionRequestPositionsDesc,
          color: AccentColors.purple,
        ),

        const SizedBox(height: AppTheme.spacing16),
        _buildSectionLabel(context.l10n.widgetBuilderSectionEmergency),
        const SizedBox(height: AppTheme.spacing8),
        _buildActionTile(
          type: ActionType.sos,
          icon: Icons.warning_amber,
          title: context.l10n.widgetBuilderActionSosAlert,
          description: context.l10n.widgetBuilderActionSosAlertDesc,
          color: AppTheme.errorRed,
        ),

        // Configuration options based on selected type
        if (_selectedType != null) ...[
          const SizedBox(height: AppTheme.spacing20),
          _buildConfigSection(accentColor),
        ],

        const SizedBox(height: AppTheme.spacing20),

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
              _selectedType != null
                  ? context.l10n.widgetBuilderAddAction
                  : context.l10n.widgetBuilderSelectAnAction,
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
      borderRadius: BorderRadius.circular(AppTheme.radius10),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : context.background,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(
            color: isSelected ? color : context.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: AppTheme.spacing12),
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
    return GradientBorderContainer(
      borderRadius: 10,
      borderWidth: 2,
      accentOpacity: 0.3,
      backgroundColor: accentColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 16, color: accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.widgetBuilderOptions,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
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
            label: context.l10n.widgetBuilderShowNodePickerFirst,
            subtitle: context.l10n.widgetBuilderShowNodePickerFirstDesc,
            value: _requiresNodeSelection,
            onChanged: (v) => setState(() => _requiresNodeSelection = v),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _buildCheckbox(
            label: context.l10n.widgetBuilderShowChannelPicker,
            subtitle: context.l10n.widgetBuilderShowChannelPickerDesc,
            value: _requiresChannelSelection,
            onChanged: (v) => setState(() => _requiresChannelSelection = v),
          ),
        ];
      case ActionType.traceroute:
        return [
          _buildCheckbox(
            label: context.l10n.widgetBuilderShowNodePickerTrace,
            subtitle: context.l10n.widgetBuilderShowNodePickerTraceDesc,
            value: _requiresNodeSelection,
            onChanged: (v) => setState(() => _requiresNodeSelection = v),
          ),
        ];
      default:
        return [
          Text(
            context.l10n.widgetBuilderNoAdditionalOptions,
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
      borderRadius: BorderRadius.circular(AppTheme.radius8),
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
