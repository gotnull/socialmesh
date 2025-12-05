import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../models/automation.dart';

/// Widget for editing an action
class ActionEditor extends StatefulWidget {
  final AutomationAction action;
  final void Function(AutomationAction action) onChanged;
  final VoidCallback? onDelete;

  const ActionEditor({
    super.key,
    required this.action,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  late TextEditingController _messageController;
  late TextEditingController _notificationTitleController;
  late TextEditingController _notificationBodyController;
  late TextEditingController _webhookEventController;
  late TextEditingController _shortcutNameController;

  // Track which controller is currently active for variable insertion
  TextEditingController? _lastFocusedController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.action.messageText ?? '',
    );
    _notificationTitleController = TextEditingController(
      text: widget.action.notificationTitle ?? '',
    );
    _notificationBodyController = TextEditingController(
      text: widget.action.notificationBody ?? '',
    );
    _webhookEventController = TextEditingController(
      text: widget.action.webhookEventName ?? '',
    );
    _shortcutNameController = TextEditingController(
      text: widget.action.shortcutName ?? '',
    );
  }

  @override
  void didUpdateWidget(ActionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controllers if the action type changed (not during typing)
    if (oldWidget.action.type != widget.action.type) {
      _messageController.text = widget.action.messageText ?? '';
      _notificationTitleController.text = widget.action.notificationTitle ?? '';
      _notificationBodyController.text = widget.action.notificationBody ?? '';
      _webhookEventController.text = widget.action.webhookEventName ?? '';
      _shortcutNameController.text = widget.action.shortcutName ?? '';
      _lastFocusedController = null;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _webhookEventController.dispose();
    _shortcutNameController.dispose();
    super.dispose();
  }

  /// Insert a variable at cursor position in the active text field
  void _insertVariable(String variable) {
    final controller = _lastFocusedController;
    if (controller == null) return;

    HapticFeedback.lightImpact();

    final text = controller.text;
    final selection = controller.selection;

    // Insert at cursor or append
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, variable)
        : text + variable;

    controller.text = newText;

    // Move cursor after inserted variable
    final newPosition = selection.isValid
        ? selection.start + variable.length
        : newText.length;
    controller.selection = TextSelection.collapsed(offset: newPosition);

    // Determine config key and update action
    String? configKey;
    if (controller == _messageController) {
      configKey = 'messageText';
    } else if (controller == _notificationTitleController) {
      configKey = 'notificationTitle';
    } else if (controller == _notificationBodyController) {
      configKey = 'notificationBody';
    }

    if (configKey != null) {
      widget.onChanged(
        widget.action.copyWith(
          config: {...widget.action.config, configKey: newText},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // Action header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.action.type.icon,
                    color: AppTheme.successGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncyTap(
                    onTap: () => _showActionTypePicker(context),
                    child: Row(
                      children: [
                        Text(
                          widget.action.type.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.unfold_more,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.grey,
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),

          // Action configuration
          _buildActionConfig(context),
        ],
      ),
    );
  }

  Widget _buildActionConfig(BuildContext context) {
    switch (widget.action.type) {
      case ActionType.sendMessage:
        return _buildMessageConfig(context, toChannel: false);

      case ActionType.sendToChannel:
        return _buildMessageConfig(context, toChannel: true);

      case ActionType.pushNotification:
        return _buildNotificationConfig(context);

      case ActionType.triggerWebhook:
        return _buildWebhookConfig(context);

      case ActionType.triggerShortcut:
        return _buildShortcutConfig(context);

      case ActionType.playSound:
      case ActionType.vibrate:
      case ActionType.logEvent:
      case ActionType.updateWidget:
        // No additional config needed
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageConfig(BuildContext context, {required bool toChannel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                setState(() {
                  _lastFocusedController = _messageController;
                });
              }
            },
            child: TextField(
              controller: _messageController,
              onChanged: (value) {
                widget.onChanged(
                  widget.action.copyWith(
                    config: {...widget.action.config, 'messageText': value},
                  ),
                );
              },
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Tap variables below to insert',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          _buildVariableHints(context),
        ],
      ),
    );
  }

  Widget _buildNotificationConfig(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                setState(() {
                  _lastFocusedController = _notificationTitleController;
                });
              }
            },
            child: TextField(
              controller: _notificationTitleController,
              onChanged: (value) {
                widget.onChanged(
                  widget.action.copyWith(
                    config: {
                      ...widget.action.config,
                      'notificationTitle': value,
                    },
                  ),
                );
              },
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Tap variables below to insert',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                setState(() {
                  _lastFocusedController = _notificationBodyController;
                });
              }
            },
            child: TextField(
              controller: _notificationBodyController,
              onChanged: (value) {
                widget.onChanged(
                  widget.action.copyWith(
                    config: {
                      ...widget.action.config,
                      'notificationBody': value,
                    },
                  ),
                );
              },
              decoration: InputDecoration(
                labelText: 'Body',
                hintText: 'Tap variables below to insert',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          _buildVariableHints(context),
        ],
      ),
    );
  }

  Widget _buildWebhookConfig(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: _webhookEventController,
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'webhookEventName': value},
                ),
              );
            },
            decoration: InputDecoration(
              labelText: 'IFTTT Event Name',
              hintText: 'e.g., meshtastic_alert',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uses your IFTTT Webhook key from Settings',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutConfig(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        controller: _shortcutNameController,
        onChanged: (value) {
          widget.onChanged(
            widget.action.copyWith(
              config: {...widget.action.config, 'shortcutName': value},
            ),
          );
        },
        decoration: InputDecoration(
          labelText: 'Shortcut Name',
          hintText: 'e.g., Send Location',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildVariableHints(BuildContext context) {
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
            _lastFocusedController != null
                ? 'Tap a variable to insert:'
                : 'Available variables (tap a field first):',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildVariableChip('{{node.name}}'),
              _buildVariableChip('{{battery}}'),
              _buildVariableChip('{{location}}'),
              _buildVariableChip('{{message}}'),
              _buildVariableChip('{{time}}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariableChip(String variable) {
    final isActive = _lastFocusedController != null;
    return GestureDetector(
      onTap: isActive ? () => _insertVariable(variable) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.successGreen.withValues(alpha: 0.2)
              : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(4),
          border: isActive
              ? Border.all(color: AppTheme.successGreen.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          variable,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: isActive ? AppTheme.successGreen : Colors.amber[300],
          ),
        ),
      ),
    );
  }

  void _showActionTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
              'Change Action Type',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActionType.values.map((type) {
                final isSelected = type == widget.action.type;
                return BouncyTap(
                  onTap: () {
                    Navigator.pop(context);
                    if (type != widget.action.type) {
                      // Reset controllers when type changes
                      _messageController.text = '';
                      _notificationTitleController.text = '';
                      _notificationBodyController.text = '';
                      _webhookEventController.text = '';
                      _shortcutNameController.text = '';
                      widget.onChanged(AutomationAction(type: type));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2)
                          : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 20,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}
