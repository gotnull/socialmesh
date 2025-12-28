import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../utils/snackbar.dart';
import 'node_selector_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../models/mesh_models.dart';

/// Broadcast address for mesh-wide messages
const int broadcastAddress = 0xFFFFFFFF;

// ===========================================================================
// Quick Message Sheet
// ===========================================================================

/// Sheet content for sending quick messages
/// Used by both native Quick Actions widget and custom widget actions
class QuickMessageSheetContent extends StatefulWidget {
  final WidgetRef ref;
  final int? preSelectedNodeNum;

  const QuickMessageSheetContent({
    super.key,
    required this.ref,
    this.preSelectedNodeNum,
  });

  @override
  State<QuickMessageSheetContent> createState() =>
      _QuickMessageSheetContentState();
}

class _QuickMessageSheetContentState extends State<QuickMessageSheetContent> {
  final _controller = TextEditingController();
  int _selectedPreset = -1;
  bool _isSending = false;
  late int? _selectedNodeNum;

  static const _presets = [
    'On my way',
    'Running late',
    'Check in OK',
    'Need assistance',
    'At destination',
    'Weather alert',
  ];

  @override
  void initState() {
    super.initState();
    _selectedNodeNum = widget.preSelectedNodeNum;
  }

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
        final nodes = _availableNodes;
        final targetName = _selectedNodeNum == null
            ? 'all nodes'
            : nodes
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
              Expanded(
                child: Text(
                  'Quick Message',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: context.textTertiary),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: context.border),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipient selector
              Text(
                'TO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
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
                    color: context.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
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
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_selectedNodeNum == null)
                              Text(
                                'Broadcast to all nodes',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick presets
              Text(
                'QUICK MESSAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
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
                        if (_selectedPreset == index) {
                          _selectedPreset = -1;
                          _controller.clear();
                        } else {
                          _selectedPreset = index;
                          _controller.text = _presets[index];
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accentColor.withValues(alpha: 0.15)
                            : context.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? context.accentColor
                              : context.border,
                        ),
                      ),
                      child: Text(
                        _presets[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Custom message input
              Text(
                'OR TYPE CUSTOM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.border),
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
                onChanged: (_) {
                  if (_selectedPreset != -1) {
                    setState(() => _selectedPreset = -1);
                  }
                },
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
                    disabledBackgroundColor: context.border,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const MeshLoadingIndicator(
                          size: 20,
                          colors: [
                            Colors.black,
                            Colors.black54,
                            Colors.black26,
                          ],
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
// SOS Sheet
// ===========================================================================

/// Sheet content for emergency SOS
/// Used by both native Quick Actions widget and custom widget actions
class SosSheetContent extends StatefulWidget {
  final WidgetRef ref;

  const SosSheetContent({super.key, required this.ref});

  @override
  State<SosSheetContent> createState() => _SosSheetContentState();
}

class _SosSheetContentState extends State<SosSheetContent> {
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
              Text(
                'Emergency SOS',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: context.textTertiary),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: context.border),

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
                    Text(
                      'This will:',
                      style: TextStyle(
                        color: context.textPrimary,
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
                    color: _canSend ? AppTheme.errorRed : context.textTertiary,
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
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
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
                        foregroundColor: SemanticColors.onAccent,
                        disabledBackgroundColor: context.border,
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
                                color: SemanticColors.onAccent,
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
          Text(
            '• ',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Traceroute Sheet
// ===========================================================================

/// Sheet content for traceroute to a node
/// Used by both native Quick Actions widget and custom widget actions
class TracerouteSheetContent extends StatefulWidget {
  final WidgetRef ref;
  final int? preSelectedNodeNum;

  const TracerouteSheetContent({
    super.key,
    required this.ref,
    this.preSelectedNodeNum,
  });

  @override
  State<TracerouteSheetContent> createState() => _TracerouteSheetContentState();
}

class _TracerouteSheetContentState extends State<TracerouteSheetContent> {
  bool _isSending = false;
  late int? _selectedNodeNum;
  String? _selectedNodeName;

  @override
  void initState() {
    super.initState();
    _selectedNodeNum = widget.preSelectedNodeNum;
    if (_selectedNodeNum != null) {
      _updateSelectedNodeName();
    }
  }

  void _updateSelectedNodeName() {
    final nodes = widget.ref.read(nodesProvider);
    final node = nodes[_selectedNodeNum];
    _selectedNodeName =
        node?.longName ??
        node?.shortName ??
        '!${_selectedNodeNum!.toRadixString(16)}';
  }

  void _showNodeSelector() async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Traceroute to',
      allowBroadcast: false,
      initialSelection: _selectedNodeNum,
    );

    if (selection != null && selection.nodeNum != null && mounted) {
      setState(() {
        _selectedNodeNum = selection.nodeNum;
        _updateSelectedNodeName();
      });
    }
  }

  Future<void> _sendTraceroute() async {
    if (_selectedNodeNum == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      final protocol = widget.ref.read(protocolServiceProvider);
      await protocol.sendTraceroute(_selectedNodeNum!);

      if (mounted) {
        Navigator.pop(context);
        showInfoSnackBar(
          context,
          'Traceroute sent to $_selectedNodeName - check messages for response',
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
              Text(
                'Traceroute',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: context.textTertiary),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: context.border),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.accentColor.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Traceroute discovers the path packets take to reach a node through the mesh network.',
                        style: TextStyle(
                          color: context.textSecondary,
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
              Text(
                'TARGET NODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
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
                    color: context.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedNodeNum != null
                          ? context.accentColor.withValues(alpha: 0.5)
                          : context.border,
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
                              : context.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedNodeNum != null
                              ? Icons.person
                              : Icons.person_add_outlined,
                          color: _selectedNodeNum != null
                              ? context.accentColor
                              : context.textTertiary,
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
                                ? context.textPrimary
                                : context.textTertiary,
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
                            : context.textTertiary,
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
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
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
                        disabledBackgroundColor: context.border,
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
