import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/map_config.dart';
import '../../../core/theme.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';

/// Dashboard widget showing nodes on a mini map
class NodeMapContent extends ConsumerWidget {
  const NodeMapContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    if (nodesWithPosition.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate center and bounds
    LatLng center;
    double zoom = 12.0;

    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    if (myNode?.hasPosition == true) {
      center = LatLng(myNode!.latitude!, myNode.longitude!);
      zoom = 13.0;
    } else {
      // Average of all positions
      double avgLat = 0, avgLng = 0;
      for (final node in nodesWithPosition) {
        avgLat += node.latitude!;
        avgLng += node.longitude!;
      }
      avgLat /= nodesWithPosition.length;
      avgLng /= nodesWithPosition.length;
      center = LatLng(avgLat, avgLng);
    }

    // Use LayoutBuilder to get proper bounded constraints from parent
    return LayoutBuilder(
      builder: (context, constraints) {
        // If height is unbounded, use aspect ratio instead
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth * 0.6; // 5:3 aspect ratio fallback

        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    minZoom: 2,
                    maxZoom: 16,
                    backgroundColor: AppTheme.darkBackground,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag
                          .none, // Disable interactions in widget
                    ),
                    onTap: (_, _) => _openFullMap(context),
                  ),
                  children: [
                    // Dark map tiles
                    MapConfig.darkTileLayer(),
                    // Node markers
                    MarkerLayer(
                      markers: nodesWithPosition.map((node) {
                        final isMyNode = node.nodeNum == myNodeNum;
                        return Marker(
                          point: LatLng(node.latitude!, node.longitude!),
                          width: 24,
                          height: 24,
                          child: _MiniNodeMarker(
                            node: node,
                            isMyNode: isMyNode,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                // Tap overlay with node count
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.darkBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${nodesWithPosition.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tap to expand hint
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to expand',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tap area
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openFullMap(context),
                      splashColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 32,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'No GPS data',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nodes will appear when\nthey report position',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openFullMap(BuildContext context) {
    Navigator.of(context).pushNamed('/map');
  }
}

/// Compact marker for mini map
class _MiniNodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;

  const _MiniNodeMarker({required this.node, required this.isMyNode});

  @override
  Widget build(BuildContext context) {
    final color = isMyNode
        ? AppTheme.primaryMagenta
        : (node.isOnline ? AppTheme.primaryGreen : AppTheme.textTertiary);

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}
