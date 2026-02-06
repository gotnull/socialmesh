// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/map_config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_chat_screen.dart';

/// MeshCore Map screen.
///
/// Displays MeshCore contacts with location data on a map.
/// Styled to match the Meshtastic MapScreen but uses MeshCore data.
class MeshCoreMapScreen extends ConsumerStatefulWidget {
  final LatLng? highlightPosition;
  final String? highlightLabel;
  final double highlightZoom;

  const MeshCoreMapScreen({
    super.key,
    this.highlightPosition,
    this.highlightLabel,
    this.highlightZoom = 15.0,
  });

  @override
  ConsumerState<MeshCoreMapScreen> createState() => _MeshCoreMapScreenState();
}

class _MeshCoreMapScreenState extends ConsumerState<MeshCoreMapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitializedMap = false;
  bool _showRepeaters = true;
  bool _showChatNodes = true;
  bool _showOtherNodes = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.highlightPosition != null) {
        _mapController.move(widget.highlightPosition!, widget.highlightZoom);
      }
    });
  }

  double _standardDeviation(List<double> values) {
    if (values.length <= 1) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff = 0.0;
    for (final value in values) {
      final diff = value - mean;
      sumSquaredDiff += diff * diff;
    }
    final variance = sumSquaredDiff / (values.length - 1);
    return sqrt(variance);
  }

  double _zoomFromStdDev(double latStdDev, double lonStdDev) {
    final maxSpread = max(latStdDev, lonStdDev);
    if (maxSpread <= 0) return 13.0;
    final zoom = 10.0 - log(maxSpread * 10 + 1) / ln10 * 3;
    return zoom.clamp(4.0, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final contactsState = ref.watch(meshCoreContactsProvider);

    // Filter contacts with location
    final contactsWithLocation = contactsState.contacts
        .where((c) => c.hasLocation)
        .where((c) {
          // Apply type filters
          if (c.type == 2 && !_showRepeaters) return false; // Repeater
          if (c.type == 1 && !_showChatNodes) return false; // Chat
          if (c.type != 1 && c.type != 2 && !_showOtherNodes) return false;
          return true;
        })
        .toList();

    // Calculate center and zoom
    LatLng center = const LatLng(0, 0);
    double initialZoom = 10.0;
    final hasMapContent =
        contactsWithLocation.isNotEmpty || widget.highlightPosition != null;

    if (contactsWithLocation.isNotEmpty) {
      final allPoints = contactsWithLocation
          .map((c) => LatLng(c.latitude!, c.longitude!))
          .toList();

      if (allPoints.length >= 3) {
        final latValues = allPoints.map((p) => p.latitude).toList();
        final lonValues = allPoints.map((p) => p.longitude).toList();
        final meanLat = latValues.reduce((a, b) => a + b) / latValues.length;
        final meanLon = lonValues.reduce((a, b) => a + b) / lonValues.length;
        final latStdDev = _standardDeviation(latValues);
        final lonStdDev = _standardDeviation(lonValues);

        final filteredPoints = allPoints
            .where(
              (p) =>
                  (p.latitude - meanLat).abs() <= latStdDev * 2 &&
                  (p.longitude - meanLon).abs() <= lonStdDev * 2,
            )
            .toList();

        if (filteredPoints.isNotEmpty) {
          final filteredLatValues = filteredPoints
              .map((p) => p.latitude)
              .toList();
          final filteredLonValues = filteredPoints
              .map((p) => p.longitude)
              .toList();
          final avgLat = filteredLatValues.reduce((a, b) => a + b);
          final avgLon = filteredLonValues.reduce((a, b) => a + b);
          center = LatLng(
            avgLat / filteredPoints.length,
            avgLon / filteredPoints.length,
          );
          final filteredLatStdDev = _standardDeviation(filteredLatValues);
          final filteredLonStdDev = _standardDeviation(filteredLonValues);
          initialZoom = _zoomFromStdDev(filteredLatStdDev, filteredLonStdDev);
        } else {
          center = LatLng(meanLat, meanLon);
          initialZoom = _zoomFromStdDev(latStdDev, lonStdDev);
        }
      } else {
        double avgLat = 0.0;
        double avgLon = 0.0;
        for (final point in allPoints) {
          avgLat += point.latitude;
          avgLon += point.longitude;
        }
        center = LatLng(avgLat / allPoints.length, avgLon / allPoints.length);
        initialZoom = 12.0;
      }
    }

    if (widget.highlightPosition != null) {
      center = widget.highlightPosition!;
      initialZoom = widget.highlightZoom;
    }

    // Initialize map position after first build
    if (!_hasInitializedMap && hasMapContent) {
      _hasInitializedMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(center, initialZoom);
        }
      });
    }

    return GlassScaffold.body(
      leading: const MeshCoreHamburgerMenuButton(),
      title: 'Map',
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        const MeshCoreDeviceStatusButton(),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filter',
        ),
      ],
      body: !isConnected
          ? _buildDisconnectedState()
          : !hasMapContent
          ? _buildEmptyState()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: initialZoom,
                    minZoom: 2.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapTileStyle.dark.url,
                      subdomains: MapTileStyle.dark.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                    ),
                    MarkerLayer(
                      markers: [
                        if (widget.highlightPosition != null)
                          Marker(
                            point: widget.highlightPosition!,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.red[600],
                              size: 34,
                            ),
                          ),
                        ..._buildContactMarkers(contactsWithLocation),
                      ],
                    ),
                  ],
                ),
                _buildLegend(contactsWithLocation.length),
              ],
            ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'MeshCore Disconnected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a MeshCore device to view the map',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Contacts with Location',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacts with GPS coordinates will appear on the map.\n'
              'Make sure your contacts have location sharing enabled.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildContactMarkers(List<MeshCoreContact> contacts) {
    final markers = <Marker>[];

    for (final contact in contacts) {
      if (!contact.hasLocation) continue;

      markers.add(
        Marker(
          point: LatLng(contact.latitude!, contact.longitude!),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showContactInfo(contact),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getContactColor(contact.type),
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
                  child: Icon(
                    _getContactIcon(contact.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Color _getContactColor(int type) {
    switch (type) {
      case 1: // Chat
        return Colors.blue;
      case 2: // Repeater
        return Colors.green;
      case 3: // Room
        return Colors.purple;
      case 4: // Sensor
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getContactIcon(int type) {
    switch (type) {
      case 1: // Chat
        return Icons.person;
      case 2: // Repeater
        return Icons.cell_tower_rounded;
      case 3: // Room
        return Icons.meeting_room;
      case 4: // Sensor
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  Widget _buildLegend(int contactCount) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$contactCount ${contactCount == 1 ? 'contact' : 'contacts'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildLegendItem(Icons.person, 'Chat', Colors.blue),
              _buildLegendItem(
                Icons.cell_tower_rounded,
                'Repeater',
                Colors.green,
              ),
              _buildLegendItem(Icons.meeting_room, 'Room', Colors.purple),
              _buildLegendItem(Icons.sensors, 'Sensor', Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(MeshCoreContact contact) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getContactColor(
                      contact.type,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getContactIcon(contact.type),
                    color: _getContactColor(contact.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name.isNotEmpty ? contact.name : 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.typeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.textTertiary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Location
            _buildInfoRow(
              'Location',
              '${contact.latitude?.toStringAsFixed(5)}, ${contact.longitude?.toStringAsFixed(5)}',
            ),
            _buildInfoRow('Path', contact.pathLabel),
            _buildInfoRow('Public Key', contact.shortPubKeyHex),
            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MeshCoreChatScreen.contact(contact: contact),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Message'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor.withValues(
                        alpha: 0.3,
                      ),
                      foregroundColor: context.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _centerOnContact(contact);
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Center'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.border),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _centerOnContact(MeshCoreContact contact) {
    if (contact.hasLocation) {
      _mapController.move(LatLng(contact.latitude!, contact.longitude!), 15.0);
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: this.context.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Map',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: this.context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterSwitch(
                ctx,
                setSheetState,
                'Chat Nodes',
                Icons.person,
                Colors.blue,
                _showChatNodes,
                (value) {
                  setSheetState(() => _showChatNodes = value);
                  setState(() {});
                },
              ),
              _buildFilterSwitch(
                ctx,
                setSheetState,
                'Repeaters',
                Icons.cell_tower_rounded,
                Colors.green,
                _showRepeaters,
                (value) {
                  setSheetState(() => _showRepeaters = value);
                  setState(() {});
                },
              ),
              _buildFilterSwitch(
                ctx,
                setSheetState,
                'Other Nodes',
                Icons.device_unknown,
                Colors.grey,
                _showOtherNodes,
                (value) {
                  setSheetState(() => _showOtherNodes = value);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSwitch(
    BuildContext ctx,
    StateSetter setSheetState,
    String label,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: context.bodyStyle?.copyWith(color: context.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: context.accentColor,
            activeTrackColor: context.accentColor.withValues(alpha: 0.5),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}
