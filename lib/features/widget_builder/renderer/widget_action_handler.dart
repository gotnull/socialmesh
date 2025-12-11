import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/widget_schema.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../../../models/mesh_models.dart';

/// Broadcast address for mesh-wide messages
const int _broadcastAddress = 0xFFFFFFFF;

/// Handles action execution for custom widgets
class WidgetActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  WidgetActionHandler({required this.context, required this.ref});

  /// Static convenience method to handle an action
  static Future<void> handleAction(
    BuildContext context,
    WidgetRef ref,
    ActionSchema action,
  ) async {
    final handler = WidgetActionHandler(context: context, ref: ref);
    await handler.execute(action);
  }

  /// Execute an action from an element's ActionSchema
  Future<void> execute(ActionSchema action) async {
    switch (action.type) {
      case ActionType.none:
        return;

      case ActionType.sendMessage:
        await _handleSendMessage(action);

      case ActionType.shareLocation:
        await _handleShareLocation();

      case ActionType.traceroute:
        await _handleTraceroute(action);

      case ActionType.requestPositions:
        await _handleRequestPositions();

      case ActionType.sos:
        await _handleSos();

      case ActionType.navigate:
        _handleNavigate(action);

      case ActionType.openUrl:
        await _handleOpenUrl(action);

      case ActionType.copyToClipboard:
        // This would need the resolved value from binding
        break;
    }
  }

  Future<void> _handleSendMessage(ActionSchema action) async {
    // Show node selector if required
    int? targetNodeNum;

    if (action.requiresNodeSelection == true) {
      final selection = await NodeSelectorSheet.show(
        context,
        title: 'Send Message To',
        allowBroadcast: true,
        broadcastLabel: 'All Nodes',
        broadcastSubtitle: 'Broadcast to everyone',
      );

      if (selection == null) return;
      targetNodeNum = selection.isBroadcast ? null : selection.nodeNum;
    }

    // Show quick message bottom sheet
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _QuickMessageContent(ref: ref, preSelectedNodeNum: targetNodeNum),
    );
  }

  Future<void> _handleShareLocation() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.sendPositionOnce();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Location shared with mesh');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share location: $e');
      }
    }
  }

  Future<void> _handleTraceroute(ActionSchema action) async {
    // Always show node selector for traceroute
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Traceroute To',
      allowBroadcast: false,
    );

    if (selection == null || selection.nodeNum == null) return;

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.sendTraceroute(selection.nodeNum!);
      if (context.mounted) {
        showInfoSnackBar(
          context,
          'Traceroute sent - check messages for response',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to send traceroute: $e');
      }
    }
  }

  Future<void> _handleRequestPositions() async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Position requests sent to all nodes');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request positions: $e');
      }
    }
  }

  Future<void> _handleSos() async {
    if (!context.mounted) return;
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _SosContent(ref: ref),
    );
  }

  void _handleNavigate(ActionSchema action) {
    if (action.navigateTo == null) return;
    Navigator.of(context).pushNamed(action.navigateTo!);
  }

  Future<void> _handleOpenUrl(ActionSchema action) async {
    if (action.url == null) return;
    final uri = Uri.tryParse(action.url!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ===========================================================================
// Quick Message Content (simplified for widget actions)
// ===========================================================================

class _QuickMessageContent extends StatefulWidget {
  final WidgetRef ref;
  final int? preSelectedNodeNum;

  const _QuickMessageContent({required this.ref, this.preSelectedNodeNum});

  @override
  State<_QuickMessageContent> createState() => _QuickMessageContentState();
}

class _QuickMessageContentState extends State<_QuickMessageContent> {
  final _controller = TextEditingController();
  bool _isSending = false;
  late int? _selectedNodeNum;

  static const _presets = [
    'On my way',
    'Running late',
    'Check in OK',
    'Need assistance',
    'At destination',
  ];

  @override
  void initState() {
    super.initState();
    _selectedNodeNum = widget.preSelectedNodeNum;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final protocol = widget.ref.read(protocolServiceProvider);
      final myNodeNum = widget.ref.read(myNodeNumProvider);
      final targetAddress = _selectedNodeNum ?? _broadcastAddress;
      final messageId = 'quick_${DateTime.now().millisecondsSinceEpoch}';
      final messageText = _controller.text;

      final pendingMessage = Message(
        id: messageId,
        from: myNodeNum ?? 0,
        to: targetAddress,
        text: messageText,
        channel: _selectedNodeNum == null ? 0 : null,
        sent: true,
        status: MessageStatus.pending,
      );
      widget.ref.read(messagesProvider.notifier).addMessage(pendingMessage);

      await protocol.sendMessageWithPreTracking(
        text: messageText,
        to: targetAddress,
        channel: 0,
        wantAck: true,
        messageId: messageId,
        onPacketIdGenerated: (id) {
          widget.ref.read(messagesProvider.notifier).trackPacket(id, messageId);
        },
      );

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Message sent');
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: context.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Quick Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.darkBorder),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick presets
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((preset) {
                  return GestureDetector(
                    onTap: () => setState(() => _controller.text = preset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _controller.text == preset
                            ? context.accentColor.withValues(alpha: 0.15)
                            : AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _controller.text == preset
                              ? context.accentColor
                              : AppTheme.darkBorder,
                        ),
                      ),
                      child: Text(
                        preset,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _controller.text == preset
                              ? context.accentColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Message input
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.accentColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                maxLength: 200,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _controller.text.isNotEmpty && !_isSending
                      ? _sendMessage
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppTheme.darkBorder,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedNodeNum == null ? 'Broadcast' : 'Send',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

// ===========================================================================
// SOS Content (simplified for widget actions)
// ===========================================================================

class _SosContent extends StatefulWidget {
  final WidgetRef ref;

  const _SosContent({required this.ref});

  @override
  State<_SosContent> createState() => _SosContentState();
}

class _SosContentState extends State<_SosContent> {
  bool _isSending = false;
  int _countdown = 5;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() {
        _countdown = 0;
        _canSend = true;
      });
    }
  }

  Future<void> _sendSos() async {
    if (!_canSend || _isSending) return;

    setState(() => _isSending = true);
    HapticFeedback.heavyImpact();

    try {
      final locationService = widget.ref.read(locationServiceProvider);
      double? latitude;
      double? longitude;

      try {
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (_) {}

      final myNodeNum = widget.ref.read(myNodeNumProvider);
      if (myNodeNum == null) throw Exception('No connected node');

      final nodes = widget.ref.read(nodesProvider);
      final myNode = nodes[myNodeNum];
      final myName = myNode?.longName ?? myNode?.shortName ?? 'Unknown';

      final iftttService = widget.ref.read(iftttServiceProvider);
      await iftttService.triggerSosEmergency(
        nodeNum: myNodeNum,
        nodeName: myName,
        latitude: latitude,
        longitude: longitude,
      );

      final protocol = widget.ref.read(protocolServiceProvider);
      final locationText = (latitude != null && longitude != null)
          ? '\nLocation: $latitude, $longitude'
          : '';
      final messageId = 'sos_${DateTime.now().millisecondsSinceEpoch}';
      final messageText = '🆘 EMERGENCY SOS from $myName$locationText';

      final pendingMessage = Message(
        id: messageId,
        from: myNodeNum,
        to: _broadcastAddress,
        text: messageText,
        channel: 0,
        sent: true,
        status: MessageStatus.pending,
      );
      widget.ref.read(messagesProvider.notifier).addMessage(pendingMessage);

      await protocol.sendMessageWithPreTracking(
        text: messageText,
        to: _broadcastAddress,
        channel: 0,
        wantAck: true,
        messageId: messageId,
        onPacketIdGenerated: (id) {
          widget.ref.read(messagesProvider.notifier).trackPacket(id, messageId);
        },
      );

      if (mounted) {
        Navigator.pop(context);
        showErrorSnackBar(context, 'Emergency SOS sent to all nodes');
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send SOS: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: AppTheme.errorRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emergency SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.darkBorder),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Warning
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'This will broadcast an emergency message to ALL nodes and trigger IFTTT webhook.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Countdown
              Text(
                _canSend ? 'Ready to send' : 'Wait $_countdown seconds...',
                style: TextStyle(
                  color: _canSend ? AppTheme.errorRed : AppTheme.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSending
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSend && !_isSending ? _sendSos : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.darkBorder,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _canSend ? 'Send SOS' : '$_countdown',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}
