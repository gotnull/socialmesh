// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — GestureDetector is for keyboard dismissal, not user interaction
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_gating.dart';
import '../../services/haptic_service.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import 'automation_providers.dart';
import 'automation_summary.dart';
import 'models/automation.dart';
import 'models/condition_node.dart';
import 'widgets/condition_editor.dart';
import 'widgets/trigger_selector.dart';
import 'widgets/action_editor.dart';
import 'widgets/variable_text_field.dart';

/// Screen for creating/editing an automation
class AutomationEditorScreen extends ConsumerStatefulWidget {
  final Automation? automation;

  /// Whether this is creating a new automation (even if automation is provided for pre-filling)
  final bool isNew;

  /// When true, the editor does not persist to the repository on save.
  /// Instead it pops with the edited [Automation] as the navigation result.
  /// Used by the import screen's "Edit First" flow.
  final bool draftMode;

  const AutomationEditorScreen({
    super.key,
    this.automation,
    this.isNew = false,
    this.draftMode = false,
  });

  @override
  ConsumerState<AutomationEditorScreen> createState() =>
      _AutomationEditorScreenState();
}

class _AutomationEditorScreenState extends ConsumerState<AutomationEditorScreen>
    with LifecycleSafeMixin<AutomationEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late AutomationTrigger _trigger;
  late List<AutomationAction> _actions;
  late List<AutomationCondition>? _conditions;
  // Preserve branch structure and condition tree through editing (Phase 3).
  // Phase 4: these are now authorable in the editor UI.
  List<AutomationAction>? _thenActions;
  List<AutomationAction>? _elseActions;
  ConditionNode? _conditionTree;

  /// Whether the user has modified conditions via the UI (Phase 4).
  /// When true, we rebuild conditionTree from _conditions on save.
  /// When false, we preserve the original conditionTree as-is.
  bool _conditionsModified = false;

  /// Whether the ELSE branch section is visible in the UI.
  bool _hasElseBranch = false;
  late bool _enabled;
  bool _isSaving = false;

  bool get _isEditing => widget.automation != null && !widget.isNew;

  @override
  void initState() {
    super.initState();
    final automation = widget.automation;
    _nameController = TextEditingController(text: automation?.name ?? '');
    _descriptionController = TextEditingController(
      text: automation?.description ?? '',
    );
    _trigger =
        automation?.trigger ??
        const AutomationTrigger(type: TriggerType.messageReceived);
    _actions = List.from(
      automation?.actions ??
          [const AutomationAction(type: ActionType.pushNotification)],
    );
    _conditions = automation?.conditions != null
        ? List<AutomationCondition>.from(automation!.conditions!)
        : null;
    _thenActions = automation?.thenActions != null
        ? List<AutomationAction>.from(automation!.thenActions!)
        : null;
    _elseActions = automation?.elseActions != null
        ? List<AutomationAction>.from(automation!.elseActions!)
        : null;
    _conditionTree = automation?.conditionTree;
    _hasElseBranch = _elseActions != null && _elseActions!.isNotEmpty;
    _enabled = automation?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Update trigger and also update action configs when trigger type changes
  void _updateTrigger(AutomationTrigger newTrigger) {
    final oldType = _trigger.type;
    final newType = newTrigger.type;

    // If trigger type changed, update name, description, and actions with new default text
    if (oldType != newType) {
      final newDefaultText = newType.defaultMessageText;
      final newDisplayName = newType.displayName;
      final newDefaultDesc = _getDescriptionForTrigger(newTrigger);

      // Collect all possible default values from any trigger type
      final allDefaultMessages = TriggerType.values
          .map((t) => t.defaultMessageText)
          .toSet();
      final allDisplayNames = TriggerType.values
          .map((t) => t.displayName)
          .toSet();
      final allDefaultDescriptions = TriggerType.values
          .map((t) => t.defaultDescription)
          .toSet();
      final allAlertNames = TriggerType.values
          .map((t) => '${t.displayName} Alert')
          .toSet();

      // Update Name field if it matches any default trigger pattern
      final currentName = _nameController.text.trim();
      if (currentName.isEmpty ||
          allDisplayNames.contains(currentName) ||
          allAlertNames.contains(currentName)) {
        _nameController.text = '$newDisplayName Alert';
      }

      // Update Description field if it matches any default pattern or is a generic description
      final currentDesc = _descriptionController.text.trim();
      final shouldUpdateDesc =
          currentDesc.isEmpty ||
          allDefaultMessages.contains(currentDesc) ||
          allDefaultDescriptions.contains(currentDesc) ||
          // Also match if description starts with common automation description patterns
          currentDesc.startsWith('Triggered when') ||
          currentDesc.startsWith('Alert when') ||
          currentDesc.startsWith('Alert if') ||
          currentDesc.startsWith('Notify when') ||
          // Match duration-based descriptions
          RegExp(
            r'Alert if no activity from node for \d+ minutes',
          ).hasMatch(currentDesc) ||
          // Match battery threshold descriptions
          RegExp(
            r'Notify when a node battery drops below \d+%',
          ).hasMatch(currentDesc) ||
          RegExp(
            r'Triggered when battery drops below \d+%',
          ).hasMatch(currentDesc);

      if (shouldUpdateDesc) {
        _descriptionController.text = newDefaultDesc;
      }

      // Update actions with new default values
      final updatedActions = _actions.map((action) {
        final newConfig = Map<String, dynamic>.from(action.config);
        var changed = false;

        // Update messageText for sendMessage/sendToChannel
        if (action.type == ActionType.sendMessage ||
            action.type == ActionType.sendToChannel) {
          final messageText = newConfig['messageText'] as String?;
          if (messageText == null ||
              messageText.isEmpty ||
              allDefaultMessages.contains(messageText)) {
            newConfig['messageText'] = newDefaultText;
            changed = true;
          }
        }

        // Update notification title/body if they match any defaults
        if (action.type == ActionType.pushNotification) {
          final title = newConfig['notificationTitle'] as String?;
          final body = newConfig['notificationBody'] as String?;

          // Update title if it matches any default trigger name patterns
          if (title == null ||
              title.isEmpty ||
              allDisplayNames.contains(title) ||
              allAlertNames.contains(title)) {
            newConfig['notificationTitle'] = newDisplayName;
            changed = true;
          }

          // Update body if it matches any default message text
          if (body == null ||
              body.isEmpty ||
              allDefaultMessages.contains(body) ||
              allDisplayNames.contains(body)) {
            newConfig['notificationBody'] = newDefaultText;
            changed = true;
          }
        }

        return changed ? action.copyWith(config: newConfig) : action;
      }).toList();

      // Update all state in a single setState call
      setState(() {
        _trigger = newTrigger;
        _actions = updatedActions;
      });
    } else {
      // Config change within same trigger type
      // Check if we should update description for config value changes
      final currentDesc = _descriptionController.text.trim();

      if (newType == TriggerType.nodeSilent) {
        // Update if description matches the pattern "Alert if no activity..."
        if (currentDesc.startsWith('Alert if no activity') ||
            RegExp(
              r'Alert if no activity from node for \d+ minutes',
            ).hasMatch(currentDesc)) {
          _descriptionController.text = _getDescriptionForTrigger(newTrigger);
        }
      } else if (newType == TriggerType.batteryLow) {
        // Update if description matches battery threshold pattern
        if (currentDesc.startsWith('Triggered when battery drops below') ||
            currentDesc.startsWith('Notify when a node battery drops below') ||
            RegExp(
              r'Triggered when battery drops below \d+%',
            ).hasMatch(currentDesc) ||
            RegExp(
              r'Notify when a node battery drops below \d+%',
            ).hasMatch(currentDesc)) {
          _descriptionController.text = _getDescriptionForTrigger(newTrigger);
        }
      }

      setState(() {
        _trigger = newTrigger;
      });
    }
  }

  /// Get description text for a trigger, with config values interpolated
  String _getDescriptionForTrigger(AutomationTrigger trigger) {
    switch (trigger.type) {
      case TriggerType.nodeSilent:
        return context.l10n.automationEditorDescSilent(trigger.silentMinutes);
      case TriggerType.batteryLow:
        return context.l10n.automationEditorDescBatteryLow(
          '${trigger.batteryThreshold}',
        );
      default:
        return trigger.type.defaultDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: _isEditing
          ? context.l10n.automationEditorTitleEdit
          : context.l10n.automationEditorTitleNew,
      actions: [
        if (_isEditing) ...[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.automationEditorDeleteTooltip,
            onPressed: _deleteAutomation,
          ),
          ThemedSwitch(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ],
      ],
      bottomNavigationBar: _buildSaveButton(),
      slivers: [
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  _buildSectionTitle(
                    context,
                    context.l10n.automationEditorNameLabel,
                  ),
                  SizedBox(height: AppTheme.spacing8),
                  TextField(
                    maxLength: 100,
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.l10n.automationEditorNameHint,
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      counterText: '',
                    ),
                  ),

                  SizedBox(height: AppTheme.spacing16),

                  // Description field
                  _buildSectionTitle(
                    context,
                    context.l10n.automationEditorDescriptionLabel,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  TextField(
                    maxLength: 500,
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.l10n.automationEditorDescriptionHint,
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      counterText: '',
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // WHEN (Trigger)
                  _buildSectionTitle(
                    context,
                    context.l10n.automationEditorWhen,
                    icon: Icons.bolt,
                    color: AppTheme.warningYellow,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  TriggerSelector(
                    trigger: _trigger,
                    availableNodes: ref.watch(nodesProvider).values.toList(),
                    onChanged: (trigger) => _updateTrigger(trigger),
                  ),

                  // Flow connector: WHEN -> IF
                  _buildFlowConnector(
                    context,
                    isFirst: true,
                    label: context.l10n.automationEditorIfDescription,
                    topColor: AppTheme.warningYellow,
                    bottomColor: AccentColors.cyan,
                    dotColor: AccentColors.cyan,
                  ),

                  // IF (Conditions) — Phase 4
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                        context,
                        context.l10n.automationEditorIf,
                        icon: Icons.filter_alt,
                        color: AccentColors.cyan,
                      ),
                      BouncyTap(
                        onTap: _addCondition,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AccentColors.cyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: AccentColors.cyan,
                              ),
                              const SizedBox(width: AppTheme.spacing4),
                              Text(
                                context.l10n.automationEditorAddCondition,
                                style: TextStyle(
                                  color: AccentColors.cyan,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),

                  // Conditions list
                  if (_conditions == null || _conditions!.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing16,
                        horizontal: AppTheme.spacing16,
                      ),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(color: context.border),
                      ),
                      child: Text(
                        context.l10n.automationEditorNoConditions,
                        style: TextStyle(
                          color: SemanticColors.muted,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing4,
                        horizontal: AppTheme.spacing12,
                      ),
                      decoration: BoxDecoration(
                        color: AccentColors.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        context.l10n.automationEditorConditionsAll,
                        style: TextStyle(
                          color: AccentColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    ..._conditions!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final condition = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacing8,
                        ),
                        child: ConditionEditor(
                          condition: condition,
                          onChanged: (updated) {
                            setState(() {
                              _conditions![index] = updated;
                              _conditionsModified = true;
                            });
                          },
                          onDelete: () {
                            setState(() {
                              _conditions!.removeAt(index);
                              if (_conditions!.isEmpty) _conditions = null;
                              _conditionsModified = true;
                            });
                          },
                        ),
                      );
                    }),
                  ],

                  // Flow connector: IF -> THEN
                  _buildFlowConnector(
                    context,
                    label: context.l10n.automationEditorThenDo,
                    topColor: AccentColors.cyan,
                    bottomColor: AppTheme.successGreen,
                    dotColor: AppTheme.successGreen,
                  ),

                  // THEN (Actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                        context,
                        context.l10n.automationEditorThen,
                        icon: Icons.play_arrow,
                        color: AppTheme.successGreen,
                      ),
                      BouncyTap(
                        onTap: _addAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppTheme.spacing4),
                              Text(
                                context.l10n.automationEditorAddAction,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),

                  // Actions list with flow connectors
                  if (_actions.isEmpty)
                    BouncyTap(
                      onTap: _addAction,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacing24,
                          horizontal: AppTheme.spacing16,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          border: Border.all(color: context.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bolt_outlined,
                              size: 32,
                              color: SemanticColors.disabled,
                            ),
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              context.l10n.automationEditorNoActions,
                              style: TextStyle(
                                color: SemanticColors.disabled,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing4),
                            Text(
                              context.l10n.automationEditorNoActionsHint,
                              style: TextStyle(
                                color: SemanticColors.disabled,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._actions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final action = entry.value;
                      // Get nodes and channels for action editor
                      final nodes = ref.watch(nodesProvider);
                      final channels = ref.watch(channelsProvider);
                      final myNodeNum = ref.watch(myNodeNumProvider);
                      return Column(
                        children: [
                          ActionEditor(
                            action: action,
                            index: index,
                            totalActions: _actions.length,
                            triggerType: _trigger.type,
                            availableNodes: nodes.values.toList(),
                            availableChannels: channels,
                            myNodeNum: myNodeNum,
                            onChanged: (updated) {
                              setState(() {
                                _actions[index] = updated;
                              });
                            },
                            onDelete: () =>
                                setState(() => _actions.removeAt(index)),
                          ),
                          // Show connector between actions (not after the last one)
                          if (index < _actions.length - 1)
                            _buildFlowConnector(
                              context,
                              stepNumber: index + 2,
                              topColor: AppTheme.successGreen,
                              bottomColor: AppTheme.successGreen,
                              dotColor: AppTheme.successGreen,
                            ),
                        ],
                      );
                    }),

                  // ELSE section — Phase 4
                  if (_hasElseBranch) ...[
                    _buildFlowConnector(
                      context,
                      label: context.l10n.automationEditorElseDescription,
                      topColor: AppTheme.successGreen,
                      bottomColor: AppTheme.errorRed,
                      dotColor: AppTheme.errorRed,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle(
                          context,
                          context.l10n.automationEditorElse,
                          icon: Icons.alt_route,
                          color: AppTheme.errorRed,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BouncyTap(
                              onTap: _addElseAction,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppTheme.errorRed,
                                    ),
                                    const SizedBox(width: AppTheme.spacing4),
                                    Text(
                                      context.l10n.automationEditorAddAction,
                                      style: TextStyle(
                                        color: AppTheme.errorRed,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            BouncyTap(
                              onTap: _removeElseBranch,
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: SemanticColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    if (_elseActions == null || _elseActions!.isEmpty)
                      BouncyTap(
                        onTap: _addElseAction,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing24,
                            horizontal: AppTheme.spacing16,
                          ),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                            border: Border.all(color: context.border),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.alt_route,
                                size: 32,
                                color: SemanticColors.disabled,
                              ),
                              const SizedBox(height: AppTheme.spacing8),
                              Text(
                                context.l10n.automationEditorNoActions,
                                style: TextStyle(
                                  color: SemanticColors.disabled,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacing4),
                              Text(
                                context.l10n.automationEditorNoActionsHint,
                                style: TextStyle(
                                  color: SemanticColors.disabled,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._elseActions!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final action = entry.value;
                        final nodes = ref.watch(nodesProvider);
                        final channels = ref.watch(channelsProvider);
                        final myNodeNum = ref.watch(myNodeNumProvider);
                        return Column(
                          children: [
                            ActionEditor(
                              action: action,
                              index: index,
                              totalActions: _elseActions!.length,
                              triggerType: _trigger.type,
                              availableNodes: nodes.values.toList(),
                              availableChannels: channels,
                              myNodeNum: myNodeNum,
                              onChanged: (updated) {
                                setState(() {
                                  _elseActions![index] = updated;
                                });
                              },
                              onDelete: () =>
                                  setState(() => _elseActions!.removeAt(index)),
                            ),
                            if (index < _elseActions!.length - 1)
                              _buildFlowConnector(
                                context,
                                stepNumber: index + 2,
                                topColor: AppTheme.errorRed,
                                bottomColor: AppTheme.errorRed,
                                dotColor: AppTheme.errorRed,
                              ),
                          ],
                        );
                      }),
                  ] else ...[
                    // "Add ELSE actions" button when no ELSE branch exists
                    const SizedBox(height: AppTheme.spacing16),
                    Center(
                      child: BouncyTap(
                        onTap: _enableElseBranch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                            border: Border.all(
                              color: SemanticColors.muted.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alt_route,
                                size: 16,
                                color: SemanticColors.muted,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                context.l10n.automationEditorAddElseActions,
                                style: TextStyle(
                                  color: SemanticColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Summary preview — Phase 4
                  const SizedBox(height: AppTheme.spacing24),
                  _buildSummaryPreview(context),

                  const SizedBox(
                    height: AppTheme.spacing100,
                  ), // Space for bottom button
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the save button
  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    final canSave = !_isSaving && _actions.isNotEmpty;
    final gradientColors = !canSave
        ? [
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.colorScheme.primary.withValues(alpha: 0.2),
          ]
        : [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ];

    return BottomActionBar(
      horizontalPadding: AppTheme.spacing16,
      child: BouncyTap(
        onTap: canSave ? _save : null,
        child: AnimatedOpacity(
          opacity: canSave ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing10),
                      Text(
                        context.l10n.automationEditorSaving,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _isEditing
                        ? context.l10n.automationEditorSaveChanges
                        : context.l10n.automationEditorCreateAutomation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    IconData? icon,
    Color? color,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? SemanticColors.disabled),
          const SizedBox(width: AppTheme.spacing6),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? SemanticColors.disabled,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Builds a flow connector with a line and optional step indicator
  Widget _buildFlowConnector(
    BuildContext context, {
    bool isFirst = false,
    int? stepNumber,
    String? label,
    Color? topColor,
    Color? bottomColor,
    Color? dotColor,
  }) {
    final top = topColor ?? AppTheme.successGreen;
    final bottom = bottomColor ?? AppTheme.successGreen;
    final dot = dotColor ?? AppTheme.successGreen;
    final connectorLabel =
        label ??
        (isFirst
            ? context.l10n.automationEditorThenDo
            : context.l10n.automationEditorThen2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: AppTheme.spacing18),
          Column(
            children: [
              Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top.withValues(alpha: 0.6), bottom],
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dot.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: dot, width: 2),
                ),
                child: Icon(Icons.arrow_downward, size: 14, color: dot),
              ),
              Container(
                width: 2,
                height: 16,
                color: bottom.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(width: AppTheme.spacing12),
          Text(
            connectorLabel,
            style: TextStyle(
              color: SemanticColors.muted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (stepNumber != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: dot.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius10),
              ),
              child: Text(
                context.l10n.automationEditorStepNumber(stepNumber),
                style: TextStyle(
                  color: dot,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
          ],
        ],
      ),
    );
  }

  void _addAction() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ActionTypeSelector(
        onSelect: (type) {
          Navigator.pop(context);
          setState(() {
            _actions.add(AutomationAction(type: type));
          });
        },
      ),
    );
  }

  void _addCondition() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ConditionTypeSelector(
        onSelect: (type) {
          Navigator.pop(context);
          setState(() {
            _conditions ??= [];
            _conditions!.add(AutomationCondition(type: type));
            _conditionsModified = true;
          });
        },
      ),
    );
  }

  void _enableElseBranch() {
    setState(() {
      _hasElseBranch = true;
      _elseActions ??= [];
    });
  }

  void _removeElseBranch() {
    setState(() {
      _hasElseBranch = false;
      _elseActions = null;
    });
  }

  void _addElseAction() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ActionTypeSelector(
        onSelect: (type) {
          Navigator.pop(context);
          setState(() {
            _elseActions ??= [];
            _elseActions!.add(AutomationAction(type: type));
          });
        },
      ),
    );
  }

  Widget _buildSummaryPreview(BuildContext context) {
    // Build a temporary automation for summary generation
    final tempAutomation = Automation(
      name: _nameController.text.trim(),
      trigger: _trigger,
      actions: _actions,
      conditions: _conditions,
      thenActions: _actions.isNotEmpty ? _actions : null,
      elseActions: _hasElseBranch ? _elseActions : null,
    );
    final summary = AutomationSummary.build(tempAutomation, context.l10n);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: SemanticColors.muted),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SemanticColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAutomation() async {
    final automation = widget.automation;
    if (automation == null) return;

    ref.read(hapticServiceProvider).trigger(HapticType.warning);

    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.automationScreenDeleteTitle,
      message: l10n.automationScreenDeleteMessage(automation.name),
      confirmLabel: l10n.automationScreenDelete,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final automationsNotifier = ref.read(automationsProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showLoadingSnackBar(
      context,
      l10n.automationScreenDeleting(automation.name),
    );

    try {
      await automationsNotifier.deleteAutomation(automation.id);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      navigator.pop();
      showGlobalSuccessSnackBar(l10n.automationScreenDeleted(automation.name));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        showErrorSnackBar(context, l10n.automationEditorDeleteError);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showWarningSnackBar(context, context.l10n.automationEditorValidateName);
      return;
    }

    // Validate trigger configuration
    final triggerError = _trigger.validate();
    if (triggerError != null) {
      showWarningSnackBar(context, triggerError);
      return;
    }

    // Validate THEN actions (must have at least one)
    if (_actions.isEmpty) {
      showWarningSnackBar(
        context,
        context.l10n.automationEditorValidateThenActions,
      );
      return;
    }

    // Validate ELSE branch — if open, must have actions
    if (_hasElseBranch && (_elseActions == null || _elseActions!.isEmpty)) {
      showWarningSnackBar(
        context,
        context.l10n.automationEditorValidateElseActions,
      );
      return;
    }

    // Validate individual THEN actions
    for (int i = 0; i < _actions.length; i++) {
      final action = _actions[i];

      // Validate action configuration
      final actionError = action.validate();
      if (actionError != null) {
        showWarningSnackBar(
          context,
          context.l10n.automationActionError(i + 1, actionError),
        );
        return;
      }

      // Validate variables in text fields
      final fieldsToValidate = <String>[
        action.messageText ?? '',
        action.notificationTitle ?? '',
        action.notificationBody ?? '',
      ];

      for (final field in fieldsToValidate) {
        final invalidVars = validateVariables(field);
        if (invalidVars.isNotEmpty) {
          showErrorSnackBar(
            context,
            context.l10n.automationEditorInvalidVars(invalidVars.join(', ')),
          );
          return;
        }
      }
    }

    // Validate individual ELSE actions (if present)
    if (_hasElseBranch && _elseActions != null) {
      for (int i = 0; i < _elseActions!.length; i++) {
        final action = _elseActions![i];
        final actionError = action.validate();
        if (actionError != null) {
          showWarningSnackBar(
            context,
            context.l10n.automationActionError(i + 1, actionError),
          );
          return;
        }

        final fieldsToValidate = <String>[
          action.messageText ?? '',
          action.notificationTitle ?? '',
          action.notificationBody ?? '',
        ];

        for (final field in fieldsToValidate) {
          final invalidVars = validateVariables(field);
          if (invalidVars.isNotEmpty) {
            showErrorSnackBar(
              context,
              context.l10n.automationEditorInvalidVars(invalidVars.join(', ')),
            );
            return;
          }
        }
      }
    }

    // Check premium before saving (new automations only)
    // Editing existing automations is always allowed to not break user's workflows
    if (!_isEditing) {
      final hasPremium = ref.read(
        hasFeatureProvider(PremiumFeature.automations),
      );

      if (!hasPremium) {
        showPremiumInfoSheet(
          context: context,
          ref: ref,
          feature: PremiumFeature.automations,
          customDescription:
              'Create powerful automatic alerts, smart messages, and scheduled actions that run in the background.', // lint-allow: hardcoded-string
        );
        // User doesn't have premium - their config is preserved so they can try again after purchase
        return;
      }
    }

    safeSetState(() => _isSaving = true);

    final description = _descriptionController.text.trim();

    // Phase 4 model construction:
    // - conditionTree: rebuild from UI conditions if modified, else preserve original
    // - thenActions: set to _actions when conditions or ELSE exist (branch mode)
    // - elseActions: set when ELSE branch is active
    // - actions: always set to _actions for backward compatibility (legacy field)
    final hasConditions = _conditions != null && _conditions!.isNotEmpty;
    final hasElse =
        _hasElseBranch && _elseActions != null && _elseActions!.isNotEmpty;
    final isBranchMode = hasConditions || hasElse;

    // Determine conditionTree
    ConditionNode? finalConditionTree;
    if (_conditionsModified) {
      // User edited conditions via UI — rebuild tree as flat ALL group
      finalConditionTree = hasConditions
          ? ConditionNode.fromLegacyConditions(_conditions)
          : null;
    } else {
      // No UI edits — preserve original tree untouched
      finalConditionTree = _conditionTree;
    }

    final automation = Automation(
      id: widget.automation?.id,
      name: name,
      description: description.isNotEmpty ? description : null,
      enabled: _enabled,
      trigger: _trigger,
      actions: _actions,
      conditions: _conditions,
      conditionTree: finalConditionTree,
      thenActions: isBranchMode ? _actions : _thenActions,
      elseActions: hasElse ? _elseActions : null,
      createdAt: widget.automation?.createdAt,
      lastTriggered: widget.automation?.lastTriggered,
      triggerCount: widget.automation?.triggerCount ?? 0,
    );

    // Capture provider and navigator before any await
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final navigator = Navigator.of(context);

    // Draft mode: return the automation without persisting (used by import staging)
    if (widget.draftMode) {
      navigator.pop(automation);
      return;
    }

    try {
      if (_isEditing) {
        await automationsNotifier.updateAutomation(automation);
      } else {
        await automationsNotifier.addAutomation(automation);
      }

      if (!mounted) return;
      navigator.pop(automation);
      showSuccessSnackBar(
        context,
        _isEditing
            ? context.l10n.automationEditorUpdated
            : context.l10n.automationEditorCreated,
      );
    } catch (e) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, context.l10n.automationEditorSaveError);
      }
    }
  }
}

/// Bottom sheet for selecting action type
class _ActionTypeSelector extends StatelessWidget {
  final void Function(ActionType type) onSelect;

  const _ActionTypeSelector({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: SemanticColors.muted,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
          Text(
            context.l10n.automationEditorAddAction,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: AppTheme.spacing16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActionType.values.map((type) {
              return BouncyTap(
                onTap: () => onSelect(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 20),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(type.displayName),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

/// Bottom sheet for selecting condition type
class _ConditionTypeSelector extends StatelessWidget {
  final void Function(ConditionType type) onSelect;

  const _ConditionTypeSelector({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: SemanticColors.muted,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
          Text(
            context.l10n.automationEditorSelectConditionType,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: AppTheme.spacing16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ConditionType.values.map((type) {
              return BouncyTap(
                onTap: () => onSelect(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 20, color: AccentColors.cyan),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(type.localizedName(context.l10n)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
