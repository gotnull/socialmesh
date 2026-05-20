// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/glyph_provider.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/meshcore_contact_selector_sheet.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../models/mesh_models.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/presence_confidence.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../providers/presence_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../../services/audio/rtttl_library_service.dart';
import '../../../services/audio/rtttl_player.dart';
import '../../../utils/snackbar.dart';
import '../models/automation.dart';
import 'variable_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_banner.dart';

// Protocol-agnostic adapter for the action-editor's channel picker.
// The Meshtastic side passes its `ChannelConfig` directly; the
// MeshCore side maps each `MeshCoreChannel` to one of these so the
// picker only depends on the index + display name.
class MeshCoreChannelOption {
  final int index;
  final String name;

  const MeshCoreChannelOption({required this.index, required this.name});
}

/// Widget for editing an action
class ActionEditor extends ConsumerStatefulWidget {
  final AutomationAction action;
  final void Function(AutomationAction action) onChanged;
  final VoidCallback? onDelete;
  final int? index;
  final int? totalActions;
  final TriggerType? triggerType;
  final List<MeshNode> availableNodes;
  final List<ChannelConfig> availableChannels;
  final int? myNodeNum;
  // Trigger's protocol scope. When `meshcore` the node picker reads
  // MeshCore contacts and the channel picker reads MeshCore channel
  // names instead of the Meshtastic-provider lists threaded through
  // `availableNodes` / `availableChannels`. Defaults to `any` so
  // existing call sites that don't yet plumb the filter behave like
  // before.
  final TriggerProtocolFilter protocolFilter;
  // MeshCore channels are passed separately so the Meshtastic
  // channel list stays the legacy `availableChannels` parameter.
  // When the editor branches on protocolFilter==meshcore it shows
  // these instead.
  final List<MeshCoreChannelOption> availableMeshCoreChannels;
  // Parallel for contacts. Used when `protocolFilter==meshcore` to
  // resolve the picked `targetNodeNum` (a pubkey-prefix int written
  // by the contact selector) back to a name + hex prefix for the
  // target tile label. Without this the tile shows "Select Node"
  // even after the user picked a contact.
  final List<MeshCoreContact> availableMeshCoreContacts;

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
    this.protocolFilter = TriggerProtocolFilter.any,
    this.availableMeshCoreChannels = const [],
    this.availableMeshCoreContacts = const [],
  });

  @override
  ConsumerState<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends ConsumerState<ActionEditor>
    with LifecycleSafeMixin<ActionEditor> {
  late TextEditingController _webhookEventController;
  late TextEditingController _webhookUrlController;
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
    _webhookUrlController = TextEditingController(
      text: widget.action.webhookUrl ?? '',
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
      _webhookUrlController.text = widget.action.webhookUrl ?? '';
      _shortcutNameController.text = widget.action.shortcutName ?? '';
      _activeField = null;
    }
  }

  @override
  void dispose() {
    _webhookEventController.dispose();
    _webhookUrlController.dispose();
    _shortcutNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          // Action header
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(
                    widget.action.type.icon,
                    color: AppTheme.successGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: BouncyTap(
                    onTap: () => _showActionTypePicker(context),
                    child: Row(
                      children: [
                        Text(
                          widget.action.type.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        const Icon(
                          Icons.unfold_more,
                          size: 16,
                          color: SemanticColors.disabled,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: SemanticColors.disabled,
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
        return _buildSoundConfig(context);

      case ActionType.vibrate:
      case ActionType.logEvent:
      case ActionType.updateWidget:
      case ActionType.glyphPattern:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageConfig(BuildContext context, {required bool toChannel}) {
    final presenceMap = ref.watch(presenceMapProvider);
    // Get available nodes excluding self
    final nodes =
        widget.availableNodes
            .where((n) => n.nodeNum != widget.myNodeNum)
            .toList()
          ..sort((a, b) {
            // Active nodes first, then by name
            final aActive = presenceConfidenceFor(presenceMap, a).isActive;
            final bActive = presenceConfidenceFor(presenceMap, b).isActive;
            if (aActive != bActive) return aActive ? -1 : 1;
            final aName = a.longName ?? a.shortName ?? '';
            final bName = b.longName ?? b.shortName ?? '';
            return aName.compareTo(bName);
          });

    final channels = widget.availableChannels;
    final isMeshCore = widget.protocolFilter == TriggerProtocolFilter.meshcore;
    final meshCoreChannels = widget.availableMeshCoreChannels;

    // Determine selected target display name. The MeshCore branch
    // looks up names from `availableMeshCoreChannels` so the picker
    // and the surface label agree.
    String targetDisplay;
    if (toChannel) {
      final selectedChannelIndex = widget.action.targetChannelIndex;
      if (selectedChannelIndex != null) {
        if (isMeshCore) {
          final channel = meshCoreChannels
              .where((c) => c.index == selectedChannelIndex)
              .firstOrNull;
          targetDisplay = (channel?.name.isNotEmpty ?? false)
              ? channel!.name
              : context.l10n.automationActionChannelIndex(selectedChannelIndex);
        } else {
          final channel = channels.firstWhere(
            (c) => c.index == selectedChannelIndex,
            orElse: () =>
                ChannelConfig(index: selectedChannelIndex, name: '', psk: []),
          );
          targetDisplay = channel.name.isEmpty
              ? (selectedChannelIndex == 0
                    ? context.l10n.automationActionPrimary
                    : context.l10n.automationActionChannelIndex(
                        selectedChannelIndex,
                      ))
              : channel.name;
        }
      } else {
        targetDisplay = context.l10n.automationActionSelectChannel;
      }
    } else {
      final selectedNodeNum = widget.action.targetNodeNum;
      if (selectedNodeNum != null) {
        if (isMeshCore) {
          // MeshCore branch: `targetNodeNum` is the contact's
          // pubkey-prefix int (`meshCoreSenderIdFromKey`). Resolve
          // back to the contact's display name; fall back to the
          // hex prefix so the tile never goes blank even if the
          // contact list hasn't loaded yet.
          final contact = widget.availableMeshCoreContacts
              .where(
                (c) => meshCoreSenderIdFromKey(c.publicKey) == selectedNodeNum,
              )
              .firstOrNull;
          targetDisplay =
              contact?.name ??
              '!${selectedNodeNum.toRadixString(16).padLeft(8, '0')}';
        } else {
          final node = nodes.firstWhere(
            (n) => n.nodeNum == selectedNodeNum,
            orElse: () => MeshNode(nodeNum: selectedNodeNum),
          );
          targetDisplay = node.displayName;
        }
      } else {
        targetDisplay = context.l10n.automationActionSelectNodePlaceholder;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target selector (node or channel)
          Text(
            context.l10n.automationActionTo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          GestureDetector(
            onTap: () => toChannel
                ? (isMeshCore
                      ? _showMeshCoreChannelPicker(context, meshCoreChannels)
                      : _showChannelPicker(context, channels))
                : _showNodePicker(context, nodes),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
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
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      toChannel ? Icons.forum : Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing12),
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
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          toChannel
                              ? context.l10n.automationActionChannelMessage
                              : context.l10n.automationActionDirectMessage,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Message text field - use default text from trigger type if empty
          VariableTextField(
            maxLength: 500,
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
            labelText: context.l10n.automationActionMessageLabel,
            hintText: context.l10n.automationActionVariableHint,
            maxLines: 2,
            triggerType: widget.triggerType,
          ),
          const SizedBox(height: AppTheme.spacing8),
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

  Future<void> _showNodePicker(
    BuildContext context,
    List<MeshNode> nodes,
  ) async {
    // MeshCore-pinned automations target a MeshCore contact, not a
    // Meshtastic node. The selected contact's pubkey-prefix int
    // (`meshCoreSenderIdFromKey(c.publicKey)`) is written into
    // `targetNodeNum`; Slice D's `_sendMeshCoreContactMessage`
    // helper reads it back the same way to dispatch the wire frame.
    if (widget.protocolFilter == TriggerProtocolFilter.meshcore) {
      final selection = await MeshCoreContactSelectorSheet.show(
        context,
        title: context.l10n.meshcoreContactSelectorTitle,
        initialSelection: widget.action.targetNodeNum,
      );
      if (selection != null) {
        widget.onChanged(
          widget.action.copyWith(
            config: {
              ...widget.action.config,
              'targetNodeNum': selection.nodeNumPrefix,
            },
          ),
        );
      }
      return;
    }

    final selection = await NodeSelectorSheet.show(
      context,
      title: context.l10n.automationTriggerSelectNode,
      allowBroadcast: false,
      initialSelection: widget.action.targetNodeNum,
    );

    if (selection != null && selection.nodeNum != null) {
      widget.onChanged(
        widget.action.copyWith(
          config: {...widget.action.config, 'targetNodeNum': selection.nodeNum},
        ),
      );
    }
  }

  void _showChannelPicker(BuildContext context, List<ChannelConfig> channels) {
    if (channels.isEmpty) {
      showWarningSnackBar(context, context.l10n.automationActionNoChannels);
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 16, 0),
              child: Row(
                children: [
                  Text(
                    context.l10n.automationActionSelectChannelTitle,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.automationActionDone,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.automationActionChannelsCount(channels.length),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
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
                            ? context.l10n.automationActionPrimary
                            : context.l10n.automationActionChannelIndex(
                                channel.index,
                              ))
                      : channel.name;
                  return _buildTargetTile(
                    context: context,
                    icon: Icons.forum,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: channelName,
                    subtitle: channel.index == 0
                        ? context.l10n.automationActionDefaultChannel
                        : context.l10n.automationActionChannelIndex(
                            channel.index,
                          ),
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

  // MeshCore counterpart of `_showChannelPicker`. Iterates the
  // protocol-agnostic `MeshCoreChannelOption` list (already adapted
  // from `MeshCoreChannel` at the call site) so the picker layout
  // stays identical to the Meshtastic side and the `targetChannelIndex`
  // selection writes the same int Slice D's
  // `_sendMeshCoreChannelMessage` helper reads back.
  void _showMeshCoreChannelPicker(
    BuildContext context,
    List<MeshCoreChannelOption> channels,
  ) {
    if (channels.isEmpty) {
      showWarningSnackBar(context, context.l10n.automationActionNoChannels);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 16, 0),
              child: Row(
                children: [
                  Text(
                    context.l10n.automationActionSelectChannelTitle,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.automationActionDone,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.automationActionChannelsCount(channels.length),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isSelected =
                      widget.action.targetChannelIndex == channel.index;
                  final channelName = channel.name.isNotEmpty
                      ? channel.name
                      : context.l10n.automationActionChannelIndex(
                          channel.index,
                        );
                  return _buildTargetTile(
                    context: context,
                    icon: Icons.forum,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: channelName,
                    subtitle: context.l10n.automationActionChannelIndex(
                      channel.index,
                    ),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                              color: context.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textTertiary,
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

  Widget _buildSoundConfig(BuildContext context) {
    final selectedSound = widget.action.soundName;
    final hasSound = selectedSound != null && selectedSound.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationActionSoundSection,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          GestureDetector(
            onTap: () => _showSoundPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AccentColors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: AccentColors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSound
                              ? selectedSound
                              : context.l10n.automationActionSelectSound,
                          style: TextStyle(
                            color: hasSound
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          hasSound
                              ? context.l10n.automationActionRtttlRingtone
                              : context.l10n.automationActionTapToChoose,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
                ],
              ),
            ),
          ),
          if (hasSound) ...[
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewSound(context),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(context.l10n.automationActionPreview),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AccentColors.orange,
                      side: BorderSide(
                        color: AccentColors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SoundPickerSheet(
        currentRtttl: widget.action.soundRtttl,
        onSelect: (item) {
          widget.onChanged(
            widget.action.copyWith(
              config: {
                ...widget.action.config,
                'soundRtttl': item.rtttl,
                'soundName': item.formattedTitle,
              },
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _previewSound(BuildContext context) async {
    final rtttl = widget.action.soundRtttl;
    if (rtttl == null || rtttl.isEmpty) return;

    final player = RtttlPlayer();
    try {
      showLoadingSnackBar(
        context,
        context.l10n.automationActionPlayingSound(
          widget.action.soundName ?? '',
        ),
      );
      await player.play(rtttl);
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.automationActionPlaySoundFailed('$e'),
        );
      }
    } finally {
      await player.dispose();
    }
  }

  Widget _buildNotificationConfig(BuildContext context) {
    final hasCustomSound =
        widget.action.notificationSoundName != null &&
        widget.action.notificationSoundName!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing12,
        0,
        AppTheme.spacing12,
        AppTheme.spacing12,
      ),
      child: Column(
        children: [
          VariableTextField(
            maxLength: 100,
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
            labelText: context.l10n.automationActionTitleLabel,
            hintText: context.l10n.automationActionVariableHint,
            triggerType: widget.triggerType,
          ),
          const SizedBox(height: AppTheme.spacing8),
          VariableTextField(
            maxLength: 500,
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
            labelText: context.l10n.automationActionBodyLabel,
            hintText: context.l10n.automationActionVariableHint,
            maxLines: 2,
            triggerType: widget.triggerType,
          ),
          SizedBox(height: AppTheme.spacing8),
          VariableChipPicker(
            targetField: _insertTargetField,
            isActive: _insertTargetField != null,
            triggerType: widget.triggerType,
            showDeleteHint: _insertTargetField != null,
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Custom sound option
          GestureDetector(
            onTap: () => _showNotificationSoundPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hasCustomSound
                          ? AccentColors.orange.withValues(alpha: 0.15)
                          : context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: hasCustomSound
                          ? AccentColors.orange
                          : context.textTertiary,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCustomSound
                              ? widget.action.notificationSoundName!
                              : context.l10n.automationActionCustomSound,
                          style: TextStyle(
                            color: hasCustomSound
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          hasCustomSound
                              ? context.l10n.automationActionPlaysAfter
                              : context.l10n.automationActionSystemDefault,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCustomSound)
                    IconButton(
                      onPressed: () {
                        widget.onChanged(
                          widget.action.copyWith(
                            config: {
                              ...widget.action.config,
                              'notificationSoundRtttl': null,
                              'notificationSoundName': null,
                            },
                          ),
                        );
                      },
                      icon: Icon(Icons.close, size: 18),
                      color: context.textTertiary,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: context.textSecondary,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SoundPickerSheet(
        currentRtttl: widget.action.notificationSoundRtttl,
        onSelect: (item) {
          widget.onChanged(
            widget.action.copyWith(
              config: {
                ...widget.action.config,
                'notificationSoundRtttl': item.rtttl,
                'notificationSoundName': item.formattedTitle,
              },
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildWebhookConfig(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing12, 0, 12, 12),
      child: Column(
        children: [
          TextField(
            maxLength: 100,
            controller: _webhookEventController,
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'webhookEventName': value},
                ),
              );
            },
            decoration: InputDecoration(
              labelText: context.l10n.automationActionWebhookEventName,
              hintText: context.l10n.automationActionIftttHint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              counterText: '',
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          TextField(
            maxLength: 500,
            controller: _webhookUrlController,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'webhookUrl': value},
                ),
              );
            },
            decoration: InputDecoration(
              labelText: context.l10n.automationActionWebhookUrlLabel,
              hintText: context.l10n.automationActionWebhookUrlHint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              counterText: '',
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: SemanticColors.disabled,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.automationActionWebhookHelp,
                    style: TextStyle(color: SemanticColors.muted, fontSize: 12),
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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            maxLength: 100,
            controller: _shortcutNameController,
            onChanged: (value) {
              widget.onChanged(
                widget.action.copyWith(
                  config: {...widget.action.config, 'shortcutName': value},
                ),
              );
            },
            decoration: InputDecoration(
              labelText: context.l10n.automationActionShortcutNameLabel,
              hintText: context.l10n.automationActionShortcutNameHint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: () => _showShortcutHelp(context),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          StatusBanner.info(
            title: context.l10n.automationActionShortcutDataInfo,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showShortcutHelp(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppTheme.warningYellow),
                SizedBox(width: AppTheme.spacing8),
                Text(
                  context.l10n.automationActionShortcutHelpTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.automationActionShortcutSetup,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildHelpStep('1', context.l10n.automationActionShortcutStep1),
            _buildHelpStep('2', context.l10n.automationActionShortcutStep2),
            _buildHelpStep('3', context.l10n.automationActionShortcutStep3),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.automationActionShortcutKeysTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacing8),
            _buildKeyItem(
              'node_name',
              context.l10n.automationActionShortcutKeyNodeName,
            ),
            _buildKeyItem(
              'node_num',
              context.l10n.automationActionShortcutKeyNodeNum,
            ),
            _buildKeyItem(
              'trigger',
              context.l10n.automationActionShortcutKeyTrigger,
            ),
            _buildKeyItem(
              'battery',
              context.l10n.automationActionShortcutKeyBattery,
            ),
            _buildKeyItem(
              'latitude',
              context.l10n.automationActionShortcutKeyLatitude,
            ),
            _buildKeyItem(
              'longitude',
              context.l10n.automationActionShortcutKeyLongitude,
            ),
            _buildKeyItem(
              'message',
              context.l10n.automationActionShortcutKeyMessage,
            ),
            _buildKeyItem(
              'timestamp',
              context.l10n.automationActionShortcutKeyTimestamp,
            ),
            const SizedBox(height: AppTheme.spacing16),
            StatusBanner.warning(
              title: context.l10n.automationActionShortcutIosNote,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.spacing24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.automationActionGotIt),
              ),
            ),
          ],
        ),
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
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
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
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius4),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 11,
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.successGreen,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SemanticColors.disabled),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionTypePicker(BuildContext context) {
    AppBottomSheet.showScrollable<void>(
      context: context,
      title: context.l10n.automationActionChangeType,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ActionType.values
              .where((type) {
                // Hide glyphPattern on non-Nothing phones
                if (type == ActionType.glyphPattern) {
                  return ref.watch(glyphServiceProvider).isSupported;
                }
                return true;
              })
              .map((type) {
                final isSelected = type == widget.action.type;
                return BouncyTap(
                  onTap: () {
                    Navigator.of(context).pop();
                    if (type != widget.action.type) {
                      _webhookEventController.text = '';
                      _webhookUrlController.text = '';
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
                          : context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.border,
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
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          type.localizedName(context.l10n),
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
              })
              .toList(),
        ),
      ),
    );
  }
}

class _SoundPickerSheet extends StatefulWidget {
  final String? currentRtttl;
  final void Function(RtttlLibraryItem) onSelect;

  const _SoundPickerSheet({required this.currentRtttl, required this.onSelect});

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet>
    with StatefulLifecycleSafeMixin<_SoundPickerSheet> {
  final _searchController = TextEditingController();
  final _rtttlLibraryService = RtttlLibraryService();
  RtttlPlayer? _player;
  String? _playingRtttl;
  List<RtttlLibraryItem> _suggestions = [];
  List<RtttlLibraryItem> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await _rtttlLibraryService.getSuggestions();
    if (!mounted) return;
    safeSetState(() {
      _suggestions = suggestions;
      _isLoading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      safeSetState(() {
        _searchResults = [];
      });
    } else {
      final results = await _rtttlLibraryService.search(query);
      if (!mounted) return;
      safeSetState(() {
        _searchResults = results;
      });
    }
  }

  Future<void> _playPreview(RtttlLibraryItem item) async {
    // Stop any currently playing sound
    await _player?.dispose();

    safeSetState(() {
      _playingRtttl = item.rtttl;
    });

    _player = RtttlPlayer();
    try {
      await _player!.play(item.rtttl);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.automationActionPlayFailed('$e'),
        );
      }
    } finally {
      safeSetState(() {
        _playingRtttl = null;
      });
      await _player?.dispose();
      _player = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _searchController.text.isNotEmpty
        ? _searchResults
        : _suggestions;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: SemanticColors.muted,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AccentColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(Icons.library_music, color: AccentColors.orange),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Text(
                  context.l10n.automationActionSelectSound,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              maxLength: 100,
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: context.l10n.automationActionSearchSounds,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
            ),
          ),
          // Category label
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  _searchController.text.isEmpty
                      ? context.l10n.automationActionSuggestions
                      : context.l10n.automationActionSearchResults,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(width: AppTheme.spacing8),
                Text(
                  context.l10n.automationActionSoundsCount(displayItems.length),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
          // Sound list
          Expanded(
            child: _isLoading
                ? const ScreenLoadingIndicator()
                : displayItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: SemanticColors.muted,
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Text(
                          context.l10n.automationActionNoSoundsFound,
                          style: TextStyle(color: SemanticColors.muted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
                      final isSelected = item.rtttl == widget.currentRtttl;
                      final isPlaying = item.rtttl == _playingRtttl;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: BouncyTap(
                          onTap: () => widget.onSelect(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AccentColors.orange.withValues(alpha: 0.15)
                                  : context.card,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AccentColors.orange
                                    : context.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AccentColors.orange.withValues(
                                            alpha: 0.2,
                                          )
                                        : context.background,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius10,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.music_note,
                                    color: isSelected
                                        ? AccentColors.orange
                                        : context.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: AppTheme.spacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.formattedTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? AccentColors.orange
                                              : context.textPrimary,
                                        ),
                                      ),
                                      if (item.subtitle != null)
                                        Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.textTertiary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _playPreview(item),
                                  icon: isPlaying
                                      ? LoadingIndicator(size: 20)
                                      : Icon(
                                          Icons.play_circle_outline,
                                          color: isSelected
                                              ? AccentColors.orange
                                              : context.textSecondary,
                                        ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AccentColors.orange,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
