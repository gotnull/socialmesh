import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
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

  const AutomationEditorScreen({super.key, this.automation});

  @override
  ConsumerState<AutomationEditorScreen> createState() =>
      _AutomationEditorScreenState();
}

class _AutomationEditorScreenState
    extends ConsumerState<AutomationEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late AutomationTrigger _trigger;
  late List<AutomationAction> _actions;
  late bool _enabled;

  bool get _isEditing => widget.automation != null;

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

    // If trigger type changed, update actions with new default text
    if (oldType != newType) {
      final oldDefaultText = oldType.defaultMessageText;
      final newDefaultText = newType.defaultMessageText;

      _actions = _actions.map((action) {
        final newConfig = Map<String, dynamic>.from(action.config);
        var changed = false;

        // Update messageText for sendMessage/sendToChannel
        if (action.type == ActionType.sendMessage ||
            action.type == ActionType.sendToChannel) {
          final messageText = newConfig['messageText'] as String?;
          if (messageText == null ||
              messageText.isEmpty ||
              messageText == oldDefaultText) {
            newConfig['messageText'] = newDefaultText;
            changed = true;
          }
        }

        // Update notification title/body if they match old defaults
        if (action.type == ActionType.pushNotification) {
          final title = newConfig['notificationTitle'] as String?;
          final body = newConfig['notificationBody'] as String?;

          if (title == null ||
              title.isEmpty ||
              title == oldType.displayName ||
              title == '${oldType.displayName} Alert') {
            newConfig['notificationTitle'] = newType.displayName;
            changed = true;
          }
          if (body == null || body.isEmpty || body == oldDefaultText) {
            newConfig['notificationBody'] = newDefaultText;
            changed = true;
          }
        }

        return changed ? action.copyWith(config: newConfig) : action;
      }).toList();
    }

    setState(() {
      _trigger = newTrigger;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_isEditing ? 'Edit Automation' : 'New Automation'),
        actions: [
          if (_isEditing)
            ThemedSwitch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              _buildSectionTitle(context, 'Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Low Battery Alert',
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description field
              _buildSectionTitle(context, 'Description (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'What does this automation do?',
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.darkBorder),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BouncyTap(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
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
      backgroundColor: AppTheme.darkSurface,
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
      showAppSnackBar(context, 'Please enter a name for this automation');
      return;
    }

    // Validate all actions for invalid variables
    for (final action in _actions) {
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

    if (_isEditing) {
      await ref.read(automationsProvider.notifier).updateAutomation(automation);
    } else {
      await ref.read(automationsProvider.notifier).addAutomation(automation);
    }

    if (mounted) {
      Navigator.pop(context);
      showAppSnackBar(
        context,
        _isEditing ? 'Automation updated' : 'Automation created',
      );
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
          const SizedBox(height: 16),

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
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
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
