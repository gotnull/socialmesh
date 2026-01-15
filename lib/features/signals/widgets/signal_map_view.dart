import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/social.dart';
import '../utils/signal_utils.dart';
import 'signal_thumbnail.dart';

/// A map view showing signals with GPS locations
class SignalMapView extends StatefulWidget {
  const SignalMapView({
    required this.signals,
    required this.onSignalTap,
    this.initialCenter,
    this.initialZoom = 10.0,
    this.initialSelectedSignalId,
    super.key,
  });

  final List<Post> signals;
  final void Function(Post signal) onSignalTap;
  final LatLng? initialCenter;
  final double initialZoom;
  final String? initialSelectedSignalId;

  @override
  State<SignalMapView> createState() => _SignalMapViewState();
}

class _SignalMapViewState extends State<SignalMapView> {
  final MapController _mapController = MapController();
  Post? _selectedSignal;
  bool _showSignalList = false;

  /// Programmatically focus on a specific signal: select the preview card
  /// and center/zoom the map to its location.
  void focusOnSignal(Post signal, {double zoom = 15.0}) {
    if (signal.location == null) return;

    setState(() {
      _selectedSignal = signal;
      _showSignalList = false;
    });

    // Animate/map move to the location
    _mapController.move(
      LatLng(signal.location!.latitude, signal.location!.longitude),
      zoom,
    );
  }

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
  void initState() {
    super.initState();
    if (widget.initialSelectedSignalId != null) {
      try {
        _selectedSignal = widget.signals.firstWhere(
          (s) => s.id == widget.initialSelectedSignalId,
        );
      } catch (_) {
        _selectedSignal = null;
      }
    }
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
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) {
              setState(() {
                _selectedSignal = null;
                _showSignalList = false;
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
        // Fit all button (below legend)
        Positioned(
          top:
              16 +
              12 +
              (4 * 16) +
              (3 * 4) +
              12 +
              8, // legend top + padding + 4 items + 3 gaps + padding + spacing
          right: 16,
          child: _MapControlButton(
            icon: Icons.fit_screen,
            tooltip: 'Fit all signals',
            onTap: _fitAllSignals,
          ),
        ),
        // Signal list panel (slides in from left)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: _showSignalList ? 0 : -300,
          top: 0,
          bottom: 0,
          width: 300,
          child: _SignalListPanel(
            signals: _signalsWithLocation,
            selectedSignal: _selectedSignal,
            onSignalSelected: (signal) {
              setState(() {
                _selectedSignal = signal;
                _showSignalList = false;
              });
              // Center map on selected signal
              _mapController.move(
                LatLng(signal.location!.latitude, signal.location!.longitude),
                14.0,
              );
            },
            onClose: () => setState(() => _showSignalList = false),
          ),
        ),
        // Signal count badge (tappable to open list)
        Positioned(
          top: 16,
          left: 16,
          child: IgnorePointer(
            ignoring: _showSignalList,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showSignalList ? 0.0 : 1.0,
              child: GestureDetector(
                onTap: () => setState(() => _showSignalList = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
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

  void _fitAllSignals() {
    final signals = _signalsWithLocation;
    if (signals.isEmpty) return;

    double minLat = signals.first.location!.latitude;
    double maxLat = signals.first.location!.latitude;
    double minLng = signals.first.location!.longitude;
    double maxLng = signals.first.location!.longitude;

    for (final s in signals) {
      final lat = s.location!.latitude;
      final lng = s.location!.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    final cameraFit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(50),
    );

    final camera = cameraFit.fit(_mapController.camera);
    _mapController.move(camera.center, camera.zoom.clamp(4.0, 16.0));
    HapticFeedback.lightImpact();
  }
}

/// Map control button widget
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
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
    final ageColor = getSignalAgeColor(signal.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ageColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with thumbnail and close
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signal thumbnail
                SignalThumbnail(
                  signal: signal,
                  size: 56,
                  borderRadius: 12,
                  borderColor: ageColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                // Signal content
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
                        )
                      else
                        Text(
                          '📡 Signal',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Location name if available
                      if (signal.location?.name != null &&
                          signal.location!.name!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AccentColors.cyan,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                signal.location!.name!,
                                style: TextStyle(
                                  color: AccentColors.cyan,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Hop count
                  if (signal.hopCount != null) ...[
                    _StatChip(
                      icon: Icons.route,
                      label:
                          '${signal.hopCount} ${signal.hopCount == 1 ? 'hop' : 'hops'}',
                      color: signal.hopCount == 0
                          ? Colors.green
                          : signal.hopCount! <= 2
                          ? Colors.amber
                          : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Time ago
                  _StatChip(
                    icon: Icons.access_time,
                    label: formatTimeAgo(signal.createdAt),
                    color: ageColor,
                  ),
                  const Spacer(),
                  // TTL remaining
                  if (signal.expiresAt != null) ...[
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: formatTtlRemaining(signal.expiresAt),
                      color: getTtlColor(signal.expiresAt),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Footer row with additional info
            Row(
              children: [
                // Origin badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: signal.origin == SignalOrigin.mesh
                        ? AccentColors.cyan.withValues(alpha: 0.2)
                        : Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        signal.origin == SignalOrigin.mesh
                            ? Icons.sensors
                            : Icons.cloud,
                        size: 12,
                        color: signal.origin == SignalOrigin.mesh
                            ? AccentColors.cyan
                            : Colors.purple.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        signal.origin == SignalOrigin.mesh ? 'Mesh' : 'Cloud',
                        style: TextStyle(
                          fontSize: 11,
                          color: signal.origin == SignalOrigin.mesh
                              ? AccentColors.cyan
                              : Colors.purple.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Mesh node ID if available
                if (signal.meshNodeId != null)
                  Text(
                    '!${signal.meshNodeId!.toRadixString(16).padLeft(8, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                const Spacer(),
                // Tap to view hint
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap to view',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat chip with icon and label
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

/// Panel showing list of signals on the map
class _SignalListPanel extends StatelessWidget {
  const _SignalListPanel({
    required this.signals,
    required this.selectedSignal,
    required this.onSignalSelected,
    required this.onClose,
  });

  final List<Post> signals;
  final Post? selectedSignal;
  final void Function(Post) onSignalSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Sort by most recent first
    final sortedSignals = List<Post>.from(signals)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: const Border(right: BorderSide(color: Colors.white10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Icon(Icons.list, size: 20, color: AccentColors.cyan),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Signals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${sortedSignals.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white54,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Signal list
          Expanded(
            child: sortedSignals.isEmpty
                ? const Center(
                    child: Text(
                      'No signals',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: sortedSignals.length,
                    itemBuilder: (context, index) {
                      final signal = sortedSignals[index];
                      final isSelected = selectedSignal?.id == signal.id;

                      return _SignalListItem(
                        signal: signal,
                        isSelected: isSelected,
                        onTap: () => onSignalSelected(signal),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Individual signal item in the list
class _SignalListItem extends StatelessWidget {
  const _SignalListItem({
    required this.signal,
    required this.isSelected,
    required this.onTap,
  });

  final Post signal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ageColor = getSignalAgeColor(signal.createdAt);

    return Material(
      color: isSelected
          ? AccentColors.cyan.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AccentColors.cyan : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Age indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ageColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Thumbnail
              SignalThumbnail(
                signal: signal,
                size: 40,
                borderRadius: 8,
                borderColor: ageColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              // Signal info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      signal.content.isNotEmpty ? signal.content : '📡 Signal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (signal.hopCount != null) ...[
                          Icon(Icons.route, size: 12, color: Colors.white38),
                          const SizedBox(width: 3),
                          Text(
                            '${signal.hopCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatTimeAgo(signal.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                        if (signal.expiresAt != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: getTtlColor(signal.expiresAt),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatTtlRemaining(signal.expiresAt, compact: true),
                            style: TextStyle(
                              fontSize: 11,
                              color: getTtlColor(signal.expiresAt),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isSelected ? AccentColors.cyan : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
