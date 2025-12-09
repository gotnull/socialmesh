import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/map_config.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Position history screen with filtering and map view
class PositionLogScreen extends ConsumerStatefulWidget {
  const PositionLogScreen({super.key});

  @override
  ConsumerState<PositionLogScreen> createState() => _PositionLogScreenState();
}

class _PositionLogScreenState extends ConsumerState<PositionLogScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  int? _minAltitude;
  int? _maxAltitude;
  int? _minSatellites;
  bool _showMap = false;

  List<PositionLog> _filterLogs(List<PositionLog> logs) {
    return logs.where((log) {
      // Date filter
      if (_startDate != null && log.timestamp.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null &&
          log.timestamp.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }

      // Altitude filter
      if (_minAltitude != null &&
          (log.altitude == null || log.altitude! < _minAltitude!)) {
        return false;
      }
      if (_maxAltitude != null &&
          (log.altitude == null || log.altitude! > _maxAltitude!)) {
        return false;
      }

      // Satellites filter
      if (_minSatellites != null &&
          (log.satsInView == null || log.satsInView! < _minSatellites!)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _startDate != null ||
      _endDate != null ||
      _minAltitude != null ||
      _maxAltitude != null ||
      _minSatellites != null;

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _minAltitude = null;
      _maxAltitude = null;
      _minSatellites = null;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: context.accentColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range),
                title: const Text('Date Range'),
                subtitle: _startDate != null && _endDate != null
                    ? Text(
                        '${DateFormat.MMMd().format(_startDate!)} - ${DateFormat.MMMd().format(_endDate!)}',
                      )
                    : const Text('All dates'),
                onTap: () async {
                  Navigator.pop(context);
                  await _selectDateRange();
                },
              ),

              // Min satellites
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.satellite_alt),
                title: const Text('Minimum Satellites'),
                subtitle: Text(_minSatellites?.toString() ?? 'No minimum'),
                trailing: DropdownButton<int?>(
                  value: _minSatellites,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    ...[4, 6, 8, 10, 12].map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v+')),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _minSatellites = v);
                    setSheetState(() {});
                  },
                ),
              ),

              // Altitude range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.terrain),
                title: const Text('Altitude Range (m)'),
                subtitle: _minAltitude != null || _maxAltitude != null
                    ? Text(
                        '${_minAltitude ?? 'Any'} - ${_maxAltitude ?? 'Any'}',
                      )
                    : const Text('All altitudes'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Min',
                          isDense: true,
                        ),
                        controller: TextEditingController(
                          text: _minAltitude?.toString() ?? '',
                        ),
                        onChanged: (v) {
                          setState(() => _minAltitude = int.tryParse(v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Max',
                          isDense: true,
                        ),
                        controller: TextEditingController(
                          text: _maxAltitude?.toString() ?? '',
                        ),
                        onChanged: (v) {
                          setState(() => _maxAltitude = int.tryParse(v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(positionLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Position History'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'List view' : 'Map view',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (logs) {
          final filtered = _filterLogs(logs)
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasActiveFilters
                        ? 'No positions match filters'
                        : 'No position history',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                  ],
                ],
              ),
            );
          }

          if (_showMap) {
            return _PositionMapView(logs: filtered, nodes: nodes);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final log = filtered[index];
              final prevLog = index < filtered.length - 1
                  ? filtered[index + 1]
                  : null;
              final distance = prevLog != null
                  ? _calculateDistance(
                      log.latitude,
                      log.longitude,
                      prevLog.latitude,
                      prevLog.longitude,
                    )
                  : null;

              final nodeName =
                  nodes[log.nodeNum]?.displayName ??
                  '!${log.nodeNum.toRadixString(16).toUpperCase()}';

              return _PositionCard(
                log: log,
                nodeName: nodeName,
                distanceFromPrev: distance,
              );
            },
          );
        },
      ),
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

class _PositionMapView extends StatefulWidget {
  final List<PositionLog> logs;
  final Map<int, dynamic> nodes;

  const _PositionMapView({required this.logs, required this.nodes});

  @override
  State<_PositionMapView> createState() => _PositionMapViewState();
}

class _PositionMapViewState extends State<_PositionMapView> {
  final MapController _mapController = MapController();
  bool _showTrail = true;
  int? _selectedNodeNum;

  List<int> get _nodeNums => widget.logs.map((l) => l.nodeNum).toSet().toList();

  List<PositionLog> get _filteredLogs => _selectedNodeNum == null
      ? widget.logs
      : widget.logs.where((l) => l.nodeNum == _selectedNodeNum).toList();

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      return const Center(child: Text('No positions to display'));
    }

    // Calculate bounds
    final lats = logs.map((l) => l.latitude).toList();
    final lons = logs.map((l) => l.longitude).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min);
    final maxLon = lons.reduce(math.max);

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    // Group logs by node for trails
    final nodeTrails = <int, List<LatLng>>{};
    for (final log in logs) {
      nodeTrails.putIfAbsent(log.nodeNum, () => []);
      nodeTrails[log.nodeNum]!.add(LatLng(log.latitude, log.longitude));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 14),
          children: [
            MapConfig.tileLayerForStyle(MapTileStyle.dark),

            // Draw trails
            if (_showTrail)
              PolylineLayer(
                polylines: nodeTrails.entries.map((entry) {
                  final color = _getNodeColor(entry.key);
                  return Polyline(
                    points: entry.value,
                    strokeWidth: 3,
                    color: color.withValues(alpha: 0.7),
                  );
                }).toList(),
              ),

            // Draw markers for positions
            MarkerLayer(
              markers: logs.map((log) {
                final color = _getNodeColor(log.nodeNum);
                return Marker(
                  point: LatLng(log.latitude, log.longitude),
                  width: 12,
                  height: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Controls
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              // Node filter
              if (_nodeNums.length > 1)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedNodeNum,
                      hint: const Text('All nodes'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All nodes'),
                        ),
                        ..._nodeNums.map((n) {
                          final name =
                              widget.nodes[n]?.displayName ??
                              '!${n.toRadixString(16).toUpperCase()}';
                          return DropdownMenuItem(value: n, child: Text(name));
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedNodeNum = v),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Toggle trail
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    _showTrail ? Icons.timeline : Icons.timeline_outlined,
                    color: _showTrail
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.textSecondary,
                  ),
                  tooltip: 'Toggle trail',
                  onPressed: () => setState(() => _showTrail = !_showTrail),
                ),
              ),
            ],
          ),
        ),

        // Stats overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Points',
                  value: '${logs.length}',
                  icon: Icons.location_on,
                ),
                _StatItem(
                  label: 'Nodes',
                  value: '${nodeTrails.length}',
                  icon: Icons.device_hub,
                ),
                _StatItem(
                  label: 'Distance',
                  value: _formatDistance(_calculateTotalDistance(logs)),
                  icon: Icons.straighten,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getNodeColor(int nodeNum) {
    final colors = [
      AppTheme.primaryMagenta,
      AppTheme.primaryPurple,
      AppTheme.primaryBlue,
      AccentColors.cyan,
      AccentColors.green,
      AccentColors.orange,
    ];
    return colors[nodeNum % colors.length];
  }

  double _calculateTotalDistance(List<PositionLog> logs) {
    if (logs.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < logs.length; i++) {
      const r = 6371000.0;
      final lat1 = logs[i - 1].latitude * math.pi / 180;
      final lat2 = logs[i].latitude * math.pi / 180;
      final dLat = (logs[i].latitude - logs[i - 1].latitude) * math.pi / 180;
      final dLon = (logs[i].longitude - logs[i - 1].longitude) * math.pi / 180;
      final a =
          math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) *
              math.cos(lat2) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      total += r * c;
    }
    return total;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppTheme.textTertiary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  final PositionLog log;
  final String nodeName;
  final double? distanceFromPrev;

  const _PositionCard({
    required this.log,
    required this.nodeName,
    this.distanceFromPrev,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nodeName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  dateFormat.format(log.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Coordinates
            Row(
              children: [
                _MetricChip(
                  icon: Icons.gps_fixed,
                  value:
                      '${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Metrics row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.schedule,
                  value: timeFormat.format(log.timestamp),
                ),
                if (log.altitude != null)
                  _MetricChip(icon: Icons.terrain, value: '${log.altitude}m'),
                if (log.satsInView != null)
                  _MetricChip(
                    icon: Icons.satellite_alt,
                    value: '${log.satsInView} sats',
                  ),
                if (log.speed != null)
                  _MetricChip(icon: Icons.speed, value: '${log.speed} km/h'),
                if (distanceFromPrev != null)
                  _MetricChip(
                    icon: Icons.straighten,
                    value: distanceFromPrev! < 1000
                        ? '${distanceFromPrev!.toStringAsFixed(0)}m'
                        : '${(distanceFromPrev! / 1000).toStringAsFixed(2)}km',
                    color: AppTheme.primaryBlue,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _MetricChip({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.textTertiary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
