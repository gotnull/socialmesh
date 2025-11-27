import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/app_providers.dart';

class NodeMapScreen extends ConsumerWidget {
  const NodeMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);

    // Filter nodes with positions
    final nodesWithPosition =
        nodes.values.where((node) => node.hasPosition).toList();

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
      appBar: AppBar(
        title: const Text('Node Map'),
      ),
      body: nodesWithPosition.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  const Text('No nodes with position data'),
                ],
              ),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 10.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.protofluff',
                ),
                MarkerLayer(
                  markers: nodesWithPosition.map((node) {
                    return Marker(
                      point: LatLng(node.latitude!, node.longitude!),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showNodeInfo(context, node.displayName),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  void _showNodeInfo(BuildContext context, String nodeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(nodeName)),
    );
  }
}
