import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../models/mesh_models.dart';

class NodeMapScreen extends ConsumerStatefulWidget {
  const NodeMapScreen({super.key});

  @override
  ConsumerState<NodeMapScreen> createState() => _NodeMapScreenState();
}

class _NodeMapScreenState extends ConsumerState<NodeMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);

    // Filter nodes with positions
    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    // Calculate center point
    LatLng center = const LatLng(37.7749, -122.4194); // Default: San Francisco
    if (nodesWithPosition.isNotEmpty) {
      double avgLat = 0;
      double avgLng = 0;
      for (final node in nodesWithPosition) {
        avgLat += node.latitude!;
        avgLng += node.longitude!;
      }
      center = LatLng(
        avgLat / nodesWithPosition.length,
        avgLng / nodesWithPosition.length,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          'Node Map (${nodesWithPosition.length})',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () => _centerOnNodes(nodesWithPosition),
            tooltip: 'Center on nodes',
          ),
        ],
      ),
      body: nodesWithPosition.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.location_off,
                      size: 40,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No nodes with position data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nodes with GPS will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 10.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.protofluff',
                ),
                MarkerLayer(
                  markers: nodesWithPosition.map((node) {
                    return Marker(
                      point: LatLng(node.latitude!, node.longitude!),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _showNodeInfo(context, ref, node),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              node.shortName ??
                                  node.nodeNum
                                      .toRadixString(16)
                                      .substring(0, 2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  void _centerOnNodes(List<MeshNode> nodesWithPosition) {
    if (nodesWithPosition.isEmpty) return;

    if (nodesWithPosition.length == 1) {
      // Single node - center on it
      _mapController.move(
        LatLng(
          nodesWithPosition.first.latitude!,
          nodesWithPosition.first.longitude!,
        ),
        14.0,
      );
    } else {
      // Multiple nodes - fit bounds
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLng = double.infinity;
      double maxLng = double.negativeInfinity;

      for (final node in nodesWithPosition) {
        minLat = node.latitude! < minLat ? node.latitude! : minLat;
        maxLat = node.latitude! > maxLat ? node.latitude! : maxLat;
        minLng = node.longitude! < minLng ? node.longitude! : minLng;
        maxLng = node.longitude! > maxLng ? node.longitude! : maxLng;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  void _showNodeInfo(BuildContext context, WidgetRef ref, MeshNode node) {
    final myNodeNum = ref.read(myNodeNumProvider);
    final isMyNode = node.nodeNum == myNodeNum;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        node.shortName ?? node.nodeNum.toRadixString(16),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        if (isMyNode) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InfoTable(
                rows: [
                  InfoTableRow(
                    icon: Icons.location_on,
                    label: 'Position',
                    value:
                        '${node.latitude!.toStringAsFixed(5)}, ${node.longitude!.toStringAsFixed(5)}',
                  ),
                  if (node.altitude != null)
                    InfoTableRow(
                      icon: Icons.height,
                      label: 'Altitude',
                      value: '${node.altitude}m',
                    ),
                  if (node.distance != null)
                    InfoTableRow(
                      icon: Icons.near_me,
                      label: 'Distance',
                      value: node.distance! < 1000
                          ? '${node.distance!.toInt()} m'
                          : '${(node.distance! / 1000).toStringAsFixed(1)} km',
                    ),
                  if (node.hardwareModel != null)
                    InfoTableRow(
                      icon: Icons.memory,
                      label: 'Hardware',
                      value: node.hardwareModel!,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openInMaps(node),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text(
                        'Open in Maps',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isMyNode
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person,
                                  color: AppTheme.primaryGreen,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Your Device',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                '/messages',
                                arguments: node.nodeNum,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.message, size: 20),
                            label: const Text(
                              'Message',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInMaps(MeshNode node) async {
    final lat = node.latitude!;
    final lng = node.longitude!;
    final label = Uri.encodeComponent(node.displayName);

    // Try Apple Maps first on iOS, then fall back to Google Maps
    final appleMapsUrl = Uri.parse('maps://?q=$label&ll=$lat,$lng');
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
    } else if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }
}
