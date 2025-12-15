import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../../core/transport.dart';
import '../../../models/mesh_models.dart';

/// Broadcast address for mesh-wide messages
const int broadcastAddress = 0xFFFFFFFF;

/// Quick Actions Widget - Common mesh actions at a glance
class QuickActionsContent extends ConsumerWidget {
  const QuickActionsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // First row: Quick actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.send,
                  label: 'Quick\nMessage',
                  enabled: isConnected,
                  onTap: () => _showQuickMessageSheet(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_on,
                  label: 'Share\nLocation',
                  enabled: isConnected,
                  onTap: () => _shareLocation(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.route,
                  label: 'Traceroute',
                  enabled: isConnected,
                  onTap: () => _showTracerouteSheet(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh,
                  label: 'Request\nPositions',
                  enabled: isConnected,
                  onTap: () => _requestPositions(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: SOS button
          _SosButton(
            enabled: isConnected,
            onTap: () => _showSosSheet(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSosSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _SosSheetContent(ref: ref),
    );
  }

  void _showQuickMessageSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _QuickMessageSheetContent(ref: ref),
    );
  }

  void _shareLocation(BuildContext context, WidgetRef ref) async {
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

  void _showTracerouteSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _TracerouteSheetContent(ref: ref),
    );
  }

  void _requestPositions(BuildContext context, WidgetRef ref) async {
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.accentColor : AppTheme.textTertiary;

    return BouncyTap(
      onTap: enabled ? onTap : null,
      scaleFactor: 0.95,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 72,
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.08)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? context.accentColor.withValues(alpha: 0.2)
                : AppTheme.darkBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Emergency SOS button widget - prominently displayed
class _SosButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SosButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: enabled ? onTap : null,
      scaleFactor: 0.97,
      enabled: enabled,
      child: PulseAnimation(
        enabled: enabled,
        minScale: 1.0,
        maxScale: 1.02,
        duration: const Duration(milliseconds: 1500),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? AppTheme.errorRed.withValues(alpha: 0.15)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppTheme.errorRed.withValues(alpha: 0.4)
                  : AppTheme.darkBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emergency,
                size: 20,
                color: enabled ? AppTheme.errorRed : AppTheme.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Emergency SOS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppTheme.errorRed : AppTheme.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SOS BOTTOM SHEET
// ===========================================================================

class _SosSheetContent extends StatefulWidget {
  final WidgetRef ref;

  const _SosSheetContent({required this.ref});

  @override
  State<_SosSheetContent> createState() => _SosSheetContentState();
}

class _SosSheetContentState extends State<_SosSheetContent> {
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
      // Get current location if available
      final locationService = widget.ref.read(locationServiceProvider);
      double? latitude;
      double? longitude;

      try {
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (_) {
        // Location not available, continue without it
      }

      // Get my node info
      final myNodeNum = widget.ref.read(myNodeNumProvider);
      if (myNodeNum == null) {
        throw Exception('No connected node');
      }
      final nodes = widget.ref.read(nodesProvider);
      final myNode = nodes[myNodeNum];
      final myName = myNode?.longName ?? myNode?.shortName ?? 'Unknown';

      // Trigger IFTTT SOS webhook
      final iftttService = widget.ref.read(iftttServiceProvider);
      await iftttService.triggerSosEmergency(
        nodeNum: myNodeNum,
        nodeName: myName,
        latitude: latitude,
        longitude: longitude,
      );

      // Broadcast SOS message to all nodes
      final protocol = widget.ref.read(protocolServiceProvider);
      final locationText = (latitude != null && longitude != null)
          ? '\nLocation: $latitude, $longitude'
          : '';
      final messageId = 'sos_${DateTime.now().millisecondsSinceEpoch}';
      final messageText = '🆘 EMERGENCY SOS from $myName$locationText';

      // Add message to provider for UI display (optimistic)
      final pendingMessage = Message(
        id: messageId,
        from: myNodeNum,
        to: broadcastAddress,
        text: messageText,
        channel: 0,
        sent: true,
        status: MessageStatus.pending,
      );
      widget.ref.read(messagesProvider.notifier).addMessage(pendingMessage);

      // Pre-track before sending to avoid race condition
      await protocol.sendMessageWithPreTracking(
        text: messageText,
        to: broadcastAddress,
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

        // Content
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint(
                      'Broadcast an emergency message to ALL nodes',
                    ),
                    _buildBulletPoint(
                      'Include your current location if available',
                    ),
                    _buildBulletPoint('Trigger IFTTT webhook (if configured)'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Countdown / Ready state
              Center(
                child: Text(
                  _canSend
                      ? 'Ready to send emergency alert'
                      : 'Please wait $_countdown seconds...',
                  style: TextStyle(
                    color: _canSend ? AppTheme.errorRed : AppTheme.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.emergency, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _canSend ? 'Send SOS' : '$_countdown',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// QUICK MESSAGE BOTTOM SHEET
// ===========================================================================

class _QuickMessageSheetContent extends StatefulWidget {
  final WidgetRef ref;

  const _QuickMessageSheetContent({required this.ref});

  @override
  State<_QuickMessageSheetContent> createState() =>
      _QuickMessageSheetContentState();
}

class _QuickMessageSheetContentState extends State<_QuickMessageSheetContent> {
  final _controller = TextEditingController();
  int _selectedPreset = -1;
  bool _isSending = false;
  int? _selectedNodeNum; // null means broadcast to all

  static const _presets = [
    'On my way',
    'Running late',
    'Check in OK',
    'Need assistance',
    'At destination',
    'Weather alert',
  ];

  List<MeshNode> get _availableNodes {
    final nodes = widget.ref.read(nodesProvider);
    final myNodeNum = widget.ref.read(myNodeNumProvider);
    return nodes.values.where((n) => n.nodeNum != myNodeNum).toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        final aName = a.longName ?? a.shortName ?? '';
        final bName = b.longName ?? b.shortName ?? '';
        return aName.compareTo(bName);
      });
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
      final targetAddress = _selectedNodeNum ?? broadcastAddress;
      final messageId = 'quick_${DateTime.now().millisecondsSinceEpoch}';
      final messageText = _controller.text;

      // Add message to provider for UI display (optimistic)
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

      // Send via protocol
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
        final targetName = _selectedNodeNum == null
            ? 'all nodes'
            : _availableNodes
                      .firstWhere(
                        (n) => n.nodeNum == _selectedNodeNum,
                        orElse: () => MeshNode(nodeNum: _selectedNodeNum!),
                      )
                      .longName ??
                  'node';
        showSuccessSnackBar(context, 'Sent to $targetName');
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send: $e');
      }
    }
  }

  void _showNodeSelector() async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Send to',
      allowBroadcast: true,
      initialSelection: _selectedNodeNum,
      broadcastLabel: 'All Nodes',
      broadcastSubtitle: 'Broadcast to everyone on channel',
    );

    if (selection != null && mounted) {
      setState(() {
        _selectedNodeNum = selection.isBroadcast ? null : selection.nodeNum;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _availableNodes;
    final selectedName = _selectedNodeNum == null
        ? 'All Nodes'
        : nodes
                  .firstWhere(
                    (n) => n.nodeNum == _selectedNodeNum,
                    orElse: () => MeshNode(nodeNum: _selectedNodeNum!),
                  )
                  .longName ??
              nodes
                  .firstWhere(
                    (n) => n.nodeNum == _selectedNodeNum,
                    orElse: () => MeshNode(nodeNum: _selectedNodeNum!),
                  )
                  .shortName ??
              '!${_selectedNodeNum!.toRadixString(16)}';

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
              // Recipient selector
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
                onTap: _showNodeSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedNodeNum == null
                              ? Icons.broadcast_on_personal
                              : Icons.person,
                          color: context.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _selectedNodeNum == null
                                  ? 'Broadcast to everyone'
                                  : 'Direct message',
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick presets
              const Text(
                'QUICK REPLIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(_presets.length, (index) {
                  final isSelected = _selectedPreset == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPreset = index;
                        _controller.text = _presets[index];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accentColor.withValues(alpha: 0.15)
                            : AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? context.accentColor
                              : AppTheme.darkBorder,
                        ),
                      ),
                      child: Text(
                        _presets[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? context.accentColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Custom message input
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
                  counterStyle: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() => _selectedPreset = -1),
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
// TRACEROUTE BOTTOM SHEET
// ===========================================================================

class _TracerouteSheetContent extends StatefulWidget {
  final WidgetRef ref;

  const _TracerouteSheetContent({required this.ref});

  @override
  State<_TracerouteSheetContent> createState() =>
      _TracerouteSheetContentState();
}

class _TracerouteSheetContentState extends State<_TracerouteSheetContent> {
  int? _selectedNodeNum;
  bool _isSending = false;
  String? _selectedNodeName;

  void _showNodeSelector() async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Select Target Node',
      allowBroadcast: false,
      initialSelection: _selectedNodeNum,
    );

    if (selection != null && !selection.isBroadcast && mounted) {
      final nodes = widget.ref.read(nodesProvider);
      final node = nodes[selection.nodeNum];
      setState(() {
        _selectedNodeNum = selection.nodeNum;
        _selectedNodeName =
            node?.longName ??
            node?.shortName ??
            '!${selection.nodeNum!.toRadixString(16)}';
      });
    }
  }

  Future<void> _sendTraceroute() async {
    if (_selectedNodeNum == null) return;

    setState(() => _isSending = true);

    try {
      final protocol = widget.ref.read(protocolServiceProvider);
      await protocol.sendTraceroute(_selectedNodeNum!);

      if (mounted) {
        Navigator.pop(context);
        showInfoSnackBar(
          context,
          'Traceroute sent - check messages for response',
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send traceroute: $e');
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
                child: Icon(Icons.route, color: context.accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Traceroute',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanation
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Traceroute discovers the path packets take to reach a node through the mesh network.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Node selector
              const Text(
                'TARGET NODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showNodeSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedNodeNum != null
                          ? context.accentColor.withValues(alpha: 0.5)
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedNodeNum != null
                              ? context.accentColor.withValues(alpha: 0.15)
                              : AppTheme.darkBorder.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedNodeNum != null
                              ? Icons.person
                              : Icons.person_add_outlined,
                          color: _selectedNodeNum != null
                              ? context.accentColor
                              : AppTheme.textTertiary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedNodeNum != null
                              ? _selectedNodeName ?? 'Selected'
                              : 'Tap to select a node',
                          style: TextStyle(
                            color: _selectedNodeNum != null
                                ? Colors.white
                                : AppTheme.textTertiary,
                            fontSize: 15,
                            fontWeight: _selectedNodeNum != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        color: _selectedNodeNum != null
                            ? context.accentColor
                            : AppTheme.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
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
                      onPressed: _selectedNodeNum != null && !_isSending
                          ? _sendTraceroute
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.route, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Trace',
                                  style: TextStyle(
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
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}
