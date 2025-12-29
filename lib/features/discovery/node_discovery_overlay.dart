import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
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
        // Apple TV style angled cards - positioned at bottom
        if (discoveredNodes.isNotEmpty)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 200,
                child: _AppleTVCardCarousel(
                  entries: discoveredNodes.take(6).toList(),
                  onDismiss: (id) {
                    ref
                        .read(discoveredNodesQueueProvider.notifier)
                        .removeNode(id);
                  },
                ),
              ),
            ),
          ),
        // Connecting indicator at top
        if (isConnecting && discoveredNodes.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Center(child: _ConnectingIndicator()),
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

/// Apple TV style angled card carousel
class _AppleTVCardCarousel extends StatelessWidget {
  final List<DiscoveredNodeEntry> entries;
  final void Function(String id) onDismiss;

  const _AppleTVCardCarousel({required this.entries, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < entries.length; i++)
          _AppleTVCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            index: i,
            totalCards: entries.length,
            onDismiss: () => onDismiss(entries[i].id),
          ),
      ],
    );
  }
}

class _AppleTVCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final int index;
  final int totalCards;
  final VoidCallback onDismiss;

  const _AppleTVCard({
    super.key,
    required this.entry,
    required this.index,
    required this.totalCards,
    required this.onDismiss,
  });

  @override
  State<_AppleTVCard> createState() => _AppleTVCardState();
}

class _AppleTVCardState extends State<_AppleTVCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _perspectiveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Stagger the animation based on index
    final delay = widget.index * 100;

    // Cards sweep in from the right at an angle
    _slideAnimation = Tween<double>(begin: 400.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Rotation: starts tilted, settles to final angle
    _rotationAnimation =
        Tween<double>(
          begin: 0.4, // Start more rotated
          end: 0.0,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _perspectiveAnimation = Tween<double>(begin: 0.15, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
      ),
    );

    // Start animation with stagger
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });

    // Start exit animation after display duration
    Future.delayed(Duration(milliseconds: 3500 + delay), () {
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

    // Calculate position offset based on index for stacking effect
    final horizontalOffset = widget.index * 25.0;
    final verticalOffset = widget.index * -8.0;
    final baseRotation = widget.index * 0.03;
    final depthScale = 1.0 - (widget.index * 0.05);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Combine animated values with base values
        final currentSlide = _slideAnimation.value + horizontalOffset;
        final currentRotation = _rotationAnimation.value + baseRotation;
        final currentScale = _scaleAnimation.value * depthScale;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..leftTranslateByVector3(Vector3(currentSlide, verticalOffset, 0))
            ..rotateY(currentRotation)
            ..rotateZ(_perspectiveAnimation.value * 0.1)
            ..scaleByVector3(Vector3.all(currentScale)),
          child: Opacity(
            opacity: _fadeAnimation.value * (1.0 - widget.index * 0.1),
            child: child,
          ),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.card,
              context.surface.withValues(alpha: 0.95),
              context.card.withValues(alpha: 0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.accentColor.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(-5, 5),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 25,
              offset: const Offset(5, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _GlowingNodeAvatar(shortName: shortName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.accentColor.withValues(alpha: 0.3),
                                  context.accentColor.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_tethering,
                                  color: context.accentColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'DISCOVERED',
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Node ID
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '!$nodeId',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                // Signal strength
                if (rssi != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getSignalColor(
                        rssi,
                        context,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getSignalColor(
                          rssi,
                          context,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSignalIcon(rssi),
                          size: 12,
                          color: _getSignalColor(rssi, context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rssi dBm',
                          style: TextStyle(
                            color: _getSignalColor(rssi, context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSignalColor(int rssi, BuildContext context) {
    if (rssi >= -60) return AccentColors.green;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_4_bar;
    if (rssi >= -75) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }
}

class _GlowingNodeAvatar extends StatefulWidget {
  final String shortName;

  const _GlowingNodeAvatar({required this.shortName});

  @override
  State<_GlowingNodeAvatar> createState() => _GlowingNodeAvatarState();
}

class _GlowingNodeAvatarState extends State<_GlowingNodeAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                context.accentColor.withValues(
                  alpha: 0.3 * _glowAnimation.value,
                ),
                context.accentColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: context.accentColor.withValues(
                  alpha: 0.3 * _glowAnimation.value,
                ),
                blurRadius: 12 + (6 * _glowAnimation.value),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(Icons.person, color: context.accentColor, size: 24),
            ),
          ),
        );
      },
    );
  }
}
