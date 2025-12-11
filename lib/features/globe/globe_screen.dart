import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/mesh_globe.dart';
import '../../core/widgets/node_info_card.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Screen showing the 3D mesh globe with node positions
class GlobeScreen extends ConsumerStatefulWidget {
  /// Optional node number to focus on initially
  final int? initialNodeNum;

  const GlobeScreen({super.key, this.initialNodeNum});

  @override
  ConsumerState<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends ConsumerState<GlobeScreen> {
  final GlobalKey<MeshGlobeState> _globeKey = GlobalKey();
  MeshNode? _selectedNode;
  bool _showConnections = true;

  @override
  void initState() {
    super.initState();
    // Focus on initial node after a short delay to let globe initialize
    if (widget.initialNodeNum != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _focusOnNode(widget.initialNodeNum!);
      });
    }
  }

  void _focusOnNode(int nodeNum) {
    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];
    if (node != null && node.hasPosition) {
      _globeKey.currentState?.rotateToNode(node);
      setState(() {
        _selectedNode = node;
      });
    }
  }

  void _onNodeSelected(MeshNode node) {
    setState(() {
      _selectedNode = node;
    });
    _globeKey.currentState?.rotateToNode(node);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final nodesList = nodes.values.where((n) => n.hasPosition).toList();
    final myNodeNum = ref.watch(myNodeNumProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Mesh Globe'),
        actions: [
          // Toggle connections
          IconButton(
            icon: Icon(
              _showConnections ? Icons.link : Icons.link_off,
              color: _showConnections
                  ? context.accentColor
                  : AppTheme.textTertiary,
            ),
            onPressed: () {
              setState(() {
                _showConnections = !_showConnections;
              });
            },
            tooltip: _showConnections ? 'Hide connections' : 'Show connections',
          ),
          // Reset view
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              _globeKey.currentState?.rotateToLocation(0, 0);
              setState(() {
                _selectedNode = null;
              });
            },
            tooltip: 'Reset view',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Globe
          Positioned.fill(
            child: MeshGlobe(
              key: _globeKey,
              nodes: nodesList,
              showConnections: _showConnections,
              onNodeSelected: _onNodeSelected,
              autoRotateSpeed: _selectedNode == null ? 0.2 : 0.0,
              baseColor: const Color(0xFF16213e),
              dotColor: const Color(0xFF4a5568),
              markerColor: context.accentColor,
              connectionColor: context.accentColor.withAlpha(150),
            ),
          ),

          // Node list overlay
          Positioned(
            left: 16,
            top: 16,
            bottom: 100,
            width: 200,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withAlpha(200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.public,
                          size: 16,
                          color: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${nodesList.length} nodes',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.darkBorder),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: nodesList.length,
                      itemBuilder: (context, index) {
                        final node = nodesList[index];
                        final isSelected =
                            _selectedNode?.nodeNum == node.nodeNum;
                        final isMyNode = node.nodeNum == myNodeNum;
                        final nodeColor = Color(node.avatarColor ?? 0xFF42A5F5);

                        return InkWell(
                          onTap: () => _onNodeSelected(node),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: isSelected
                                ? context.accentColor.withAlpha(30)
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: nodeColor,
                                    shape: BoxShape.circle,
                                    boxShadow: node.isOnline
                                        ? [
                                            BoxShadow(
                                              color: nodeColor.withAlpha(100),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    node.displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? context.accentColor
                                          : AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontFamily: 'JetBrainsMono',
                                      fontWeight: isMyNode
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMyNode)
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: context.accentColor,
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
          ),

          // Selected node info panel - using shared NodeInfoCard in compact mode
          if (_selectedNode != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: NodeInfoCard(
                node: _selectedNode!,
                isMyNode: _selectedNode!.nodeNum == myNodeNum,
                compact: true,
              ),
            ),

          // Empty state
          if (nodesList.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public,
                    size: 64,
                    color: AppTheme.textTertiary.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No nodes with GPS',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nodes with position data will appear here',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
