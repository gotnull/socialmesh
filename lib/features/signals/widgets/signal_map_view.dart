import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/social.dart';
import 'signal_thumbnail.dart';

/// A map view showing signals with GPS locations
class SignalMapView extends StatefulWidget {
  const SignalMapView({
    required this.signals,
    required this.onSignalTap,
    this.initialCenter,
    this.initialZoom = 10.0,
    super.key,
  });

  final List<Post> signals;
  final void Function(Post signal) onSignalTap;
  final LatLng? initialCenter;
  final double initialZoom;

  @override
  State<SignalMapView> createState() => _SignalMapViewState();
}

class _SignalMapViewState extends State<SignalMapView> {
  final MapController _mapController = MapController();
  Post? _selectedSignal;

  List<Post> get _signalsWithLocation =>
      widget.signals.where((s) => s.location != null).toList();

  LatLng? get _center {
    if (widget.initialCenter != null) return widget.initialCenter;

    final withLocation = _signalsWithLocation;
    if (withLocation.isEmpty) return null;

    // Calculate center from all signals
    double totalLat = 0;
    double totalLng = 0;
    for (final signal in withLocation) {
      totalLat += signal.location!.latitude;
      totalLng += signal.location!.longitude;
    }
    return LatLng(
      totalLat / withLocation.length,
      totalLng / withLocation.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    if (center == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No signals with location',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Signals will appear here when they include GPS coordinates',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            minZoom: 3,
            maxZoom: 18,
            onTap: (_, _) {
              setState(() {
                _selectedSignal = null;
              });
            },
            backgroundColor: const Color(0xFF1a1a2e),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'mesh.social.app',
            ),
            MarkerLayer(
              markers: _signalsWithLocation.map((signal) {
                final isSelected = _selectedSignal?.id == signal.id;
                final markerSize = isSelected ? 48.0 : 36.0;

                return Marker(
                  point: LatLng(
                    signal.location!.latitude,
                    signal.location!.longitude,
                  ),
                  width: markerSize,
                  height: markerSize,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSignal = signal;
                      });
                    },
                    child: SignalMapMarker(
                      signal: signal,
                      size: markerSize,
                      isSelected: isSelected,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Legend
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendItem(color: Colors.green, label: '< 5 min'),
                const SizedBox(height: 4),
                _LegendItem(color: Colors.amber, label: '< 30 min'),
                const SizedBox(height: 4),
                _LegendItem(color: Colors.orange, label: '< 2 hrs'),
                const SizedBox(height: 4),
                _LegendItem(color: Colors.red.shade300, label: '> 2 hrs'),
              ],
            ),
          ),
        ),
        // Signal count badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AccentColors.cyan.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors, color: AccentColors.cyan, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_signalsWithLocation.length} on map',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Selected signal preview
        if (_selectedSignal != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _SignalPreviewCard(
              signal: _selectedSignal!,
              onTap: () => widget.onSignalTap(_selectedSignal!),
              onClose: () {
                setState(() {
                  _selectedSignal = null;
                });
              },
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _SignalPreviewCard extends StatelessWidget {
  const _SignalPreviewCard({
    required this.signal,
    required this.onTap,
    required this.onClose,
  });

  final Post signal;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AccentColors.cyan.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Signal thumbnail
            SignalThumbnail(signal: signal),
            const SizedBox(width: 12),
            // Signal info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (signal.content.isNotEmpty)
                    Text(
                      signal.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (signal.hopCount != null) ...[
                        Icon(
                          Icons.route,
                          color: Colors.grey.shade500,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${signal.hopCount} hops',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.access_time,
                        color: Colors.grey.shade500,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(signal.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Close button
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              color: Colors.grey.shade500,
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
