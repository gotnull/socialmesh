import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';

/// Provider to track discovered nodes for the overlay animation
final discoveredNodesQueueProvider =
    NotifierProvider<DiscoveredNodesNotifier, List<DiscoveredNodeEntry>>(
      DiscoveredNodesNotifier.new,
    );

class DiscoveredNodeEntry {
  final MeshNode node;
  final DateTime discoveredAt;
  final String id;

  DiscoveredNodeEntry({required this.node, required this.discoveredAt})
    : id = '${node.nodeNum}_${discoveredAt.millisecondsSinceEpoch}';
}

class DiscoveredNodesNotifier extends Notifier<List<DiscoveredNodeEntry>> {
  @override
  List<DiscoveredNodeEntry> build() => [];

  void addNode(MeshNode node) {
    final entry = DiscoveredNodeEntry(node: node, discoveredAt: DateTime.now());
    state = [entry, ...state];

    // Remove after display duration
    Future.delayed(const Duration(seconds: 4), () {
      removeNode(entry.id);
    });
  }

  void removeNode(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

/// Overlay widget that shows discovered nodes with rolling animation
class NodeDiscoveryOverlay extends ConsumerWidget {
  final Widget child;

  const NodeDiscoveryOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveredNodes = ref.watch(discoveredNodesQueueProvider);
    final isConnecting =
        ref.watch(autoReconnectStateProvider) ==
            AutoReconnectState.connecting ||
        ref.watch(autoReconnectStateProvider) == AutoReconnectState.scanning;

    // Listen for new node discoveries
    ref.listen<MeshNode?>(nodeDiscoveryNotifierProvider, (previous, next) {
      if (next != null) {
        ref.read(discoveredNodesQueueProvider.notifier).addNode(next);
      }
    });

    return Stack(
      children: [
        child,
        // Node discovery cards overlay - only show during connection or when there are nodes
        if (discoveredNodes.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Column(
                children: [
                  // Optional connecting indicator
                  if (isConnecting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ConnectingIndicator(),
                    ),
                  // Node cards
                  ...discoveredNodes
                      .take(5)
                      .map(
                        (entry) => _AnimatedNodeCard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          onDismiss: () {
                            ref
                                .read(discoveredNodesQueueProvider.notifier)
                                .removeNode(entry.id);
                          },
                        ),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ConnectingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MeshLoadingIndicator(
            size: 14,
            colors: [
              context.accentColor,
              context.accentColor.withValues(alpha: 0.6),
              context.accentColor.withValues(alpha: 0.3),
            ],
          ),
          SizedBox(width: 10),
          Text(
            'Discovering nodes...',
            style: TextStyle(
              color: context.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNodeCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final VoidCallback onDismiss;

  const _AnimatedNodeCard({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNodeCard> createState() => _AnimatedNodeCardState();
}

class _AnimatedNodeCardState extends State<_AnimatedNodeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Start fade out after delay
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.entry.node;
    final longName = node.longName ?? '';
    final shortName = node.shortName ?? '';
    final displayName = longName.isNotEmpty
        ? longName
        : shortName.isNotEmpty
        ? shortName
        : 'Unknown Node';
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0');
    final rssi = node.rssi ?? 0;
    final snr = node.snr ?? 0.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.card.withValues(alpha: 0.98),
              context.surface.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.accentColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Node icon with pulse animation
            _PulsingNodeIcon(shortName: shortName),
            SizedBox(width: 14),
            // Node info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar, color: context.accentColor, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Node Discovered',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,

                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '!$nodeId',
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Signal indicator
            if (snr != 0.0 || rssi != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 12,
                      color: _getSignalColor(rssi),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rssi dBm',
                      style: TextStyle(
                        color: _getSignalColor(rssi),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -60) return context.accentColor;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _PulsingNodeIcon extends StatefulWidget {
  final String shortName;

  const _PulsingNodeIcon({required this.shortName});

  @override
  State<_PulsingNodeIcon> createState() => _PulsingNodeIconState();
}

class _PulsingNodeIconState extends State<_PulsingNodeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.accentColor.withValues(
                  alpha: 0.2 * _pulseAnimation.value,
                ),
                blurRadius: 8 + (4 * _pulseAnimation.value),
                spreadRadius: 1 * _pulseAnimation.value,
              ),
            ],
          ),
          child: Center(
            child: widget.shortName.isNotEmpty
                ? Text(
                    widget.shortName.substring(
                      0,
                      widget.shortName.length.clamp(0, 2),
                    ),
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(Icons.person, color: context.accentColor, size: 22),
          ),
        );
      },
    );
  }
}
