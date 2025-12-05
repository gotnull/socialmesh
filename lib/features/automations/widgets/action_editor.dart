import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../models/automation.dart';
import 'variable_text_field.dart';

/// Widget for editing an action
class ActionEditor extends StatefulWidget {
  final AutomationAction action;
  final void Function(AutomationAction action) onChanged;
  final VoidCallback? onDelete;
  final int? index;
  final int? totalActions;

  const ActionEditor({
    super.key,
    required this.action,
    required this.onChanged,
    this.onDelete,
    this.index,
    this.totalActions,
  });

  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  late TextEditingController _webhookEventController;
  late TextEditingController _shortcutNameController;

  // Global keys to access VariableTextField state
  final _messageFieldKey = GlobalKey<VariableTextFieldState>();
  final _notificationTitleFieldKey = GlobalKey<VariableTextFieldState>();
  final _notificationBodyFieldKey = GlobalKey<VariableTextFieldState>();

  // Track which field is currently focused
  VariableTextFieldState? _activeField;

  @override
  void initState() {
    super.initState();
    _webhookEventController = TextEditingController(
      text: widget.action.webhookEventName ?? '',
    );
    _shortcutNameController = TextEditingController(
      text: widget.action.shortcutName ?? '',
    );
  }

  void _updateActiveField() {
    setState(() {
      // Check each field's focus state
      final messageField = _messageFieldKey.currentState;
      final titleField = _notificationTitleFieldKey.currentState;
      final bodyField = _notificationBodyFieldKey.currentState;

      if (messageField?.hasFocus ?? false) {
        _activeField = messageField;
      } else if (titleField?.hasFocus ?? false) {
        _activeField = titleField;
      } else if (bodyField?.hasFocus ?? false) {
        _activeField = bodyField;
      } else {
        _activeField = null;
      }
    });
  }

  @override
  void didUpdateWidget(ActionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action.type != widget.action.type) {
      _webhookEventController.text = widget.action.webhookEventName ?? '';
      _shortcutNameController.text = widget.action.shortcutName ?? '';
      _activeField = null;
    }
  }

  @override
  void dispose() {
    _webhookEventController.dispose();
    _shortcutNameController.dispose();
    super.dispose();
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
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageConfig(BuildContext context, {required bool toChannel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          VariableTextField(
            key: _messageFieldKey,
            value: widget.action.messageText ?? '',
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'messageText': value},
                ),
              );
            },
            onFocusChange: _updateActiveField,
            labelText: 'Message',
            hintText: 'Tap variables below to insert',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          VariableChipPicker(targetField: _activeField),
        ],
      ),
    );
  }

  Widget _buildNotificationConfig(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          VariableTextField(
            key: _notificationTitleFieldKey,
            value: widget.action.notificationTitle ?? '',
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'notificationTitle': value},
                ),
              );
            },
            onFocusChange: _updateActiveField,
            labelText: 'Title',
            hintText: 'Tap variables below to insert',
          ),
          const SizedBox(height: 8),
          VariableTextField(
            key: _notificationBodyFieldKey,
            value: widget.action.notificationBody ?? '',
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'notificationBody': value},
                ),
              );
            },
            onFocusChange: _updateActiveField,
            labelText: 'Body',
            hintText: 'Tap variables below to insert',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          VariableChipPicker(targetField: _activeField),
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
