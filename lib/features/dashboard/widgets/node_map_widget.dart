import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/map_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/mesh_map_widget.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/presence_providers.dart';

/// Dashboard widget showing nodes on a mini map
class NodeMapContent extends ConsumerWidget {
  const NodeMapContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final mapStyle = ref.watch(settingsServiceProvider).maybeWhen(
          data: (settings) {
            final index = settings.mapTileStyleIndex;
            if (index >= 0 && index < MapTileStyle.values.length) {
              return MapTileStyle.values[index];
            }
            return MapTileStyle.dark;
          },
          orElse: () => MapTileStyle.dark,
        );

    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    if (nodesWithPosition.isEmpty) {
      return _buildEmptyState(context);
    }

    // Convert to marker data
    final markerData = nodesWithPosition
        .map(
          (node) => MeshNodeMarkerData.fromNode(
            node,
            presence: presenceConfidenceFor(presenceMap, node),
          ),
        )
        .toList();

    // Calculate center
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final LatLng center;
    final double zoom;
    if (myNode?.hasPosition == true) {
      center = LatLng(myNode!.latitude!, myNode.longitude!);
      zoom = 13.0;
    } else {
      center = calculateNodesCenter(markerData);
      zoom = 12.0;
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
                // Use shared MeshMapWidget with mini node markers
                MeshMapWidget(
                  mapStyle: mapStyle,
                  initialCenter: center,
                  initialZoom: zoom,
                  minZoom: 2,
                  maxZoom: 16,
                  interactive: false,
                  animateTiles: false,
                  onTap: (_, _) => _openFullMap(context),
                  additionalLayers: [
                    // Mini node markers
                    MarkerLayer(
                      markers: nodesWithPosition.map((node) {
                        final isMyNode = node.nodeNum == myNodeNum;
                        return Marker(
                          point: LatLng(node.latitude!, node.longitude!),
                          width: 24,
                          height: 24,
                          child: MiniMeshNodeMarker(
                            node: node,
                            isMyNode: isMyNode,
                            presence: presenceConfidenceFor(presenceMap, node),
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
                      color: context.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${nodesWithPosition.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
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
                      color: context.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: context.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Tap to expand',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textTertiary,
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
                      splashColor: context.accentColor.withValues(alpha: 0.1),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 32,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 8),
          Text(
            'No GPS data',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Nodes will appear when\nthey report position',
            style: TextStyle(fontSize: 11, color: context.textTertiary),
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
