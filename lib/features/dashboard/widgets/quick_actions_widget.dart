import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
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
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.send,
              label: 'Quick\nMessage',
              enabled: isConnected,
              onTap: () => _showQuickMessageDialog(context, ref),
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
              onTap: () => _showTracerouteDialog(context, ref),
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
    );
  }

  void _showQuickMessageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _QuickMessageDialog(ref: ref),
    );
  }

  void _shareLocation(BuildContext context, WidgetRef ref) async {
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.sendPositionOnce();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location shared with mesh'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share location: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showTracerouteDialog(BuildContext context, WidgetRef ref) {
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);

    // Filter out own node
    final otherNodes = nodes.values
        .where((n) => n.nodeNum != myNodeNum)
        .toList();

    if (otherNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other nodes available for traceroute'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _TracerouteDialog(nodes: otherNodes, ref: ref),
    );
  }

  void _requestPositions(BuildContext context, WidgetRef ref) async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position requests sent to all nodes'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request positions: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
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
    final color = enabled ? AppTheme.primaryGreen : AppTheme.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: enabled
                ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppTheme.primaryGreen.withValues(alpha: 0.2)
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
                  fontFamily: 'Inter',
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMessageDialog extends StatefulWidget {
  final WidgetRef ref;

  const _QuickMessageDialog({required this.ref});

  @override
  State<_QuickMessageDialog> createState() => _QuickMessageDialogState();
}

class _QuickMessageDialogState extends State<_QuickMessageDialog> {
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
        // Online nodes first, then by name
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
      final targetAddress = _selectedNodeNum ?? broadcastAddress;
      await protocol.sendMessage(
        text: _controller.text,
        to: targetAddress,
        channel: 0,
        wantAck: true,
        messageId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to $targetName'),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
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

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppTheme.primaryGreen,
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
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recipient selector
            const Text(
              'TO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showNodePicker(context, nodes),
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
                        color: _selectedNodeNum == null
                            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                            : AppTheme.primaryMagenta.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedNodeNum == null
                            ? Icons.broadcast_on_personal
                            : Icons.person,
                        color: _selectedNodeNum == null
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryMagenta,
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
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            _selectedNodeNum == null
                                ? 'Broadcast to everyone'
                                : 'Direct message',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontFamily: 'Inter',
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

            const SizedBox(height: 20),

            // Quick presets
            const Text(
              'QUICK REPLIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
                fontFamily: 'Inter',
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
                          ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                          : AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Text(
                      _presets[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                        fontFamily: 'Inter',
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
                filled: true,
                fillColor: AppTheme.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGreen),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                counterStyle: TextStyle(
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
                  backgroundColor: AppTheme.primaryGreen,
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
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodePicker(BuildContext context, List<MeshNode> nodes) {
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
                    'Send to',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),
            // Broadcast option
            _buildRecipientTile(
              icon: Icons.broadcast_on_personal,
              iconColor: AppTheme.primaryGreen,
              title: 'All Nodes',
              subtitle: 'Broadcast to everyone on channel',
              isSelected: _selectedNodeNum == null,
              onTap: () {
                setState(() => _selectedNodeNum = null);
                Navigator.pop(context);
              },
            ),
            if (nodes.isNotEmpty) ...[
              const Divider(height: 1, color: AppTheme.darkBorder),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'DIRECT MESSAGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 1,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${nodes.length} nodes',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Node list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  final displayName =
                      node.longName ??
                      node.shortName ??
                      '!${node.nodeNum.toRadixString(16)}';
                  return _buildRecipientTile(
                    icon: Icons.person,
                    iconColor: node.isOnline
                        ? AppTheme.primaryMagenta
                        : AppTheme.textTertiary,
                    title: displayName,
                    subtitle: node.shortName ?? 'Unknown',
                    isSelected: _selectedNodeNum == node.nodeNum,
                    isOnline: node.isOnline,
                    onTap: () {
                      setState(() => _selectedNodeNum = node.nodeNum);
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

  Widget _buildRecipientTile({
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
              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
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
                            color: AppTheme.primaryGreen,
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
                            ? AppTheme.primaryGreen
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TracerouteDialog extends StatefulWidget {
  final List<MeshNode> nodes;
  final WidgetRef ref;

  const _TracerouteDialog({required this.nodes, required this.ref});

  @override
  State<_TracerouteDialog> createState() => _TracerouteDialogState();
}

class _TracerouteDialogState extends State<_TracerouteDialog> {
  int? _selectedNodeNum;
  bool _isSending = false;

  Future<void> _sendTraceroute() async {
    if (_selectedNodeNum == null) return;

    setState(() => _isSending = true);

    try {
      final protocol = widget.ref.read(protocolServiceProvider);
      await protocol.sendTraceroute(_selectedNodeNum!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traceroute sent - check messages for response'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send traceroute: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Traceroute',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a node to trace the route to:',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.nodes.length,
                itemBuilder: (context, index) {
                  final node = widget.nodes[index];
                  final isSelected = _selectedNodeNum == node.nodeNum;
                  final displayName =
                      node.longName ??
                      node.shortName ??
                      '!${node.nodeNum.toRadixString(16)}';

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedNodeNum = node.nodeNum);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: index < widget.nodes.length - 1
                                ? AppTheme.darkBorder.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.darkBorder,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                node.shortName?.substring(0, 1).toUpperCase() ??
                                    '?',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.primaryGreen
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                if (node.shortName != null &&
                                    node.longName != null)
                                  Text(
                                    node.shortName!,
                                    style: TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (node.isOnline)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedNodeNum != null && !_isSending
              ? _sendTraceroute
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppTheme.darkBorder,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Trace',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
        ),
      ],
    );
  }
}
