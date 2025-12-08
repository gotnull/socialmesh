import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../models/mesh_models.dart';
import '../models/automation.dart';
import 'variable_text_field.dart';

/// Widget for editing an action
class ActionEditor extends StatefulWidget {
  final AutomationAction action;
  final void Function(AutomationAction action) onChanged;
  final VoidCallback? onDelete;
  final int? index;
  final int? totalActions;
  final TriggerType? triggerType;
  final List<MeshNode> availableNodes;
  final List<ChannelConfig> availableChannels;
  final int? myNodeNum;

  const ActionEditor({
    super.key,
    required this.action,
    required this.onChanged,
    this.onDelete,
    this.index,
    this.totalActions,
    this.triggerType,
    this.availableNodes = const [],
    this.availableChannels = const [],
    this.myNodeNum,
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

  // Track which field is currently focused (or was last focused)
  VariableTextFieldState? _activeField;
  VariableTextFieldState? _lastActiveField;

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
    // Check each field's focus state
    final messageField = _messageFieldKey.currentState;
    final titleField = _notificationTitleFieldKey.currentState;
    final bodyField = _notificationBodyFieldKey.currentState;

    VariableTextFieldState? newActive;
    if (messageField?.hasFocus ?? false) {
      newActive = messageField;
    } else if (titleField?.hasFocus ?? false) {
      newActive = titleField;
    } else if (bodyField?.hasFocus ?? false) {
      newActive = bodyField;
    }

    // Only update if a field is focused (don't clear on blur)
    // This allows chip taps to work even when field briefly loses focus
    if (newActive != null) {
      setState(() {
        _activeField = newActive;
        _lastActiveField = newActive;
      });
    } else {
      // Keep lastActiveField for chip insertion, but update active for styling
      setState(() {
        _activeField = null;
      });
    }
  }

  /// Get the field to insert variables into (current or last focused)
  VariableTextFieldState? get _insertTargetField =>
      _activeField ?? _lastActiveField;

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
    // Get available nodes excluding self
    final nodes =
        widget.availableNodes
            .where((n) => n.nodeNum != widget.myNodeNum)
            .toList()
          ..sort((a, b) {
            // Online nodes first, then by name
            if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
            final aName = a.longName ?? a.shortName ?? '';
            final bName = b.longName ?? b.shortName ?? '';
            return aName.compareTo(bName);
          });

    final channels = widget.availableChannels;

    // Determine selected target display name
    String targetDisplay;
    if (toChannel) {
      final selectedChannelIndex = widget.action.targetChannelIndex;
      if (selectedChannelIndex != null) {
        final channel = channels.firstWhere(
          (c) => c.index == selectedChannelIndex,
          orElse: () =>
              ChannelConfig(index: selectedChannelIndex, name: '', psk: []),
        );
        targetDisplay = channel.name.isEmpty
            ? (selectedChannelIndex == 0
                  ? 'Primary'
                  : 'Channel $selectedChannelIndex')
            : channel.name;
      } else {
        targetDisplay = 'Select channel';
      }
    } else {
      final selectedNodeNum = widget.action.targetNodeNum;
      if (selectedNodeNum != null) {
        final node = nodes.firstWhere(
          (n) => n.nodeNum == selectedNodeNum,
          orElse: () => MeshNode(nodeNum: selectedNodeNum),
        );
        targetDisplay = node.displayName;
      } else {
        targetDisplay = 'Select node';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target selector (node or channel)
          const Text(
            'TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => toChannel
                ? _showChannelPicker(context, channels)
                : _showNodePicker(context, nodes),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      toChannel ? Icons.forum : Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          targetDisplay,
                          style: TextStyle(
                            color:
                                (toChannel
                                        ? widget.action.targetChannelIndex
                                        : widget.action.targetNodeNum) !=
                                    null
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          toChannel ? 'Channel message' : 'Direct message',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message text field - use default text from trigger type if empty
          VariableTextField(
            key: _messageFieldKey,
            value:
                widget.action.messageText ??
                widget.triggerType?.defaultMessageText ??
                '',
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
            triggerType: widget.triggerType,
          ),
          const SizedBox(height: 8),
          VariableChipPicker(
            targetField: _insertTargetField,
            isActive: _insertTargetField != null,
            triggerType: widget.triggerType,
            showDeleteHint: _insertTargetField != null,
          ),
        ],
      ),
    );
  }

  void _showNodePicker(BuildContext context, List<MeshNode> nodes) {
    if (nodes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No nodes available')));
      return;
    }

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Select Node',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${nodes.length} nodes',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Node list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  final isSelected =
                      widget.action.targetNodeNum == node.nodeNum;
                  return _buildTargetTile(
                    context: context,
                    icon: Icons.person,
                    iconColor: node.isOnline
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.textTertiary,
                    title: node.displayName,
                    subtitle:
                        node.shortName ?? '!${node.nodeNum.toRadixString(16)}',
                    isSelected: isSelected,
                    isOnline: node.isOnline,
                    onTap: () {
                      widget.onChanged(
                        widget.action.copyWith(
                          config: {
                            ...widget.action.config,
                            'targetNodeNum': node.nodeNum,
                          },
                        ),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showChannelPicker(BuildContext context, List<ChannelConfig> channels) {
    if (channels.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No channels available')));
      return;
    }

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Select Channel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${channels.length} channels',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Channel list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isSelected =
                      widget.action.targetChannelIndex == channel.index;
                  final channelName = channel.name.isEmpty
                      ? (channel.index == 0
                            ? 'Primary'
                            : 'Channel ${channel.index}')
                      : channel.name;
                  return _buildTargetTile(
                    context: context,
                    icon: Icons.forum,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: channelName,
                    subtitle: channel.index == 0
                        ? 'Default channel'
                        : 'Channel ${channel.index}',
                    isSelected: isSelected,
                    onTap: () {
                      widget.onChanged(
                        widget.action.copyWith(
                          config: {
                            ...widget.action.config,
                            'targetChannelIndex': channel.index,
                          },
                        ),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isOnline = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(child: Icon(icon, color: iconColor, size: 22)),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.darkSurface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
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
            triggerType: widget.triggerType,
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
            triggerType: widget.triggerType,
          ),
          const SizedBox(height: 8),
          VariableChipPicker(
            targetField: _insertTargetField,
            isActive: _insertTargetField != null,
            triggerType: widget.triggerType,
            showDeleteHint: _insertTargetField != null,
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
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
              hintText: 'Enter exact shortcut name',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: () => _showShortcutHelp(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[300]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Event data (node name, battery, location, etc.) will be passed as JSON input to your shortcut.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[200]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showShortcutHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('Using Shortcuts'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Setting up your shortcut:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHelpStep(
                '1',
                'Add "Get Dictionary from" action\nSelect "Shortcut Input"',
              ),
              _buildHelpStep(
                '2',
                'Add "Get Value for" action\nSet key (e.g., node_name) and select "Dictionary"',
              ),
              _buildHelpStep(
                '3',
                'Use the extracted value in your actions\n(e.g., Send Message, Show Notification)',
              ),
              const SizedBox(height: 16),
              const Text(
                'Available keys in the dictionary:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildKeyItem('node_name', 'Name of the node'),
              _buildKeyItem('node_num', 'Node number'),
              _buildKeyItem('trigger', 'Trigger type (nodeOffline, etc.)'),
              _buildKeyItem('battery', 'Battery % (if available)'),
              _buildKeyItem('latitude', 'GPS latitude (if available)'),
              _buildKeyItem('longitude', 'GPS longitude (if available)'),
              _buildKeyItem('message', 'Message text (if applicable)'),
              _buildKeyItem('timestamp', 'Event timestamp'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: Shortcuts app will briefly open when triggered. This is an iOS limitation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[200],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildKeyItem(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.green[300],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
        ],
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
                      // Pre-populate message text for sendMessage/sendToChannel
                      final config = <String, dynamic>{};
                      if ((type == ActionType.sendMessage ||
                              type == ActionType.sendToChannel) &&
                          widget.triggerType != null) {
                        config['messageText'] =
                            widget.triggerType!.defaultMessageText;
                      }
                      widget.onChanged(
                        AutomationAction(type: type, config: config),
                      );
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
