// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import 'automation_providers.dart';
import 'models/automation.dart';
import 'widgets/trigger_selector.dart';
import 'widgets/action_editor.dart';
import 'widgets/variable_text_field.dart';

/// Screen for creating/editing an automation
class AutomationEditorScreen extends ConsumerStatefulWidget {
  final Automation? automation;

  /// Whether this is creating a new automation (even if automation is provided for pre-filling)
  final bool isNew;

  const AutomationEditorScreen({
    super.key,
    this.automation,
    this.isNew = false,
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
        return 'Alert if no activity from node for ${trigger.silentMinutes} minutes';
      case TriggerType.batteryLow:
        return 'Triggered when battery drops below ${trigger.batteryThreshold}%';
      default:
        return trigger.type.defaultDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: _isEditing ? 'Edit Automation' : 'New Automation',
      actions: [
        if (_isEditing)
          ThemedSwitch(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
      ],
      bottomNavigationBar: _buildSaveButton(),
      slivers: [
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  _buildSectionTitle(context, 'Name'),
                  SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g., Low Battery Alert',
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Description field
                  _buildSectionTitle(context, 'Description (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'What does this automation do?',
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 24),

                  // WHEN (Trigger)
                  _buildSectionTitle(
                    context,
                    'WHEN',
                    icon: Icons.bolt,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 8),
                  TriggerSelector(
                    trigger: _trigger,
                    availableNodes: ref.watch(nodesProvider).values.toList(),
                    onChanged: (trigger) => _updateTrigger(trigger),
                  ),

                  // Flow connector: WHEN -> THEN
                  _buildFlowConnector(context, isFirst: true),

                  // THEN (Actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                        context,
                        'THEN',
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Add Action',
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
                  const SizedBox(height: 8),

                  // Actions list with flow connectors
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
                          onDelete: _actions.length > 1
                              ? () => setState(() => _actions.removeAt(index))
                              : null,
                        ),
                        // Show connector between actions (not after the last one)
                        if (index < _actions.length - 1)
                          _buildFlowConnector(context, stepNumber: index + 2),
                      ],
                    );
                  }),

                  const SizedBox(height: 100), // Space for bottom button
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
    final gradientColors = _isSaving
        ? [
            theme.colorScheme.primary.withValues(alpha: 0.5),
            theme.colorScheme.primary.withValues(alpha: 0.4),
          ]
        : [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BouncyTap(
          onTap: _isSaving ? null : _save,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Saving...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _isEditing ? 'Save Changes' : 'Create Automation',
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
          Icon(icon, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? Colors.grey,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Column(
            children: [
              Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isFirst
                        ? [Colors.amber, AppTheme.successGreen]
                        : [
                            AppTheme.successGreen.withValues(alpha: 0.6),
                            AppTheme.successGreen,
                          ],
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppTheme.successGreen.withValues(alpha: 0.2)
                      : AppTheme.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.successGreen, width: 2),
                ),
                child: Icon(
                  Icons.arrow_downward,
                  size: 14,
                  color: AppTheme.successGreen,
                ),
              ),
              Container(
                width: 2,
                height: 16,
                color: AppTheme.successGreen.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            isFirst ? 'then do...' : 'then...',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (stepNumber != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Step $stepNumber',
                style: TextStyle(
                  color: AppTheme.successGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showWarningSnackBar(context, 'Please enter a name for this automation');
      return;
    }

    // Validate trigger configuration
    final triggerError = _trigger.validate();
    if (triggerError != null) {
      showWarningSnackBar(context, triggerError);
      return;
    }

    // Validate actions
    if (_actions.isEmpty) {
      showWarningSnackBar(context, 'Please add at least one action');
      return;
    }

    for (int i = 0; i < _actions.length; i++) {
      final action = _actions[i];

      // Validate action configuration
      final actionError = action.validate();
      if (actionError != null) {
        showWarningSnackBar(context, 'Action ${i + 1}: $actionError');
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
            'Invalid variables: ${invalidVars.join(", ")}',
          );
          return;
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
              'Create powerful automatic alerts, smart messages, and scheduled actions that run in the background.',
        );
        // User doesn't have premium - their config is preserved so they can try again after purchase
        return;
      }
    }

    safeSetState(() => _isSaving = true);

    final description = _descriptionController.text.trim();

    final automation = Automation(
      id: widget.automation?.id,
      name: name,
      description: description.isNotEmpty ? description : null,
      enabled: _enabled,
      trigger: _trigger,
      actions: _actions,
      createdAt: widget.automation?.createdAt,
      lastTriggered: widget.automation?.lastTriggered,
      triggerCount: widget.automation?.triggerCount ?? 0,
    );

    // Capture provider and navigator before any await
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final navigator = Navigator.of(context);

    try {
      if (_isEditing) {
        await automationsNotifier.updateAutomation(automation);
      } else {
        await automationsNotifier.addAutomation(automation);
      }

      if (!mounted) return;
      navigator.pop();
      showSuccessSnackBar(
        context,
        _isEditing ? 'Automation updated' : 'Automation created',
      );
    } catch (e) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save automation');
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
      padding: const EdgeInsets.all(16),
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
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Add Action',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 20),
                      const SizedBox(width: 8),
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
