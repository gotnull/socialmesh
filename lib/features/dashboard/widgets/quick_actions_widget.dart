import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
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
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionButton(
            icon: Icons.send,
            label: 'Quick\nMessage',
            enabled: isConnected,
            onTap: () => _showQuickMessageDialog(context, ref),
          ),
          _ActionButton(
            icon: Icons.location_on,
            label: 'Share\nLocation',
            enabled: isConnected,
            onTap: () => _shareLocation(context, ref),
          ),
          _ActionButton(
            icon: Icons.route,
            label: 'Traceroute',
            enabled: isConnected,
            onTap: () => _showTracerouteDialog(context, ref),
          ),
          _ActionButton(
            icon: Icons.refresh,
            label: 'Request\nPositions',
            enabled: isConnected,
            onTap: () => _requestPositions(context, ref),
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
          width: 72,
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

  static const _presets = [
    'On my way',
    'Running late',
    'Check in OK',
    'Need assistance',
    'At destination',
    'Weather alert',
  ];

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
      await protocol.sendMessage(
        text: _controller.text,
        to: broadcastAddress,
        channel: 0,
        wantAck: true,
        messageId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent: ${_controller.text}'),
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
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Quick Broadcast',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send to all nodes on primary channel',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
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
          TextField(
            controller: _controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Or type custom message...',
              hintStyle: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              filled: true,
              fillColor: AppTheme.darkBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primaryGreen),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            maxLength: 200,
            onChanged: (_) => setState(() {}),
          ),
        ],
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
          onPressed: _controller.text.isNotEmpty && !_isSending
              ? _sendMessage
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.black,
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
                  'Send',
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
