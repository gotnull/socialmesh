// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/map_config.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/datetime_picker_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

// ---------------------------------------------------------------------------
// Filter enum
// ---------------------------------------------------------------------------

enum _PositionFilter { all, today, thisWeek, goodFix, myNode }

extension _PositionFilterLabel on _PositionFilter {
  String get label => switch (this) {
    _PositionFilter.all => 'All',
    _PositionFilter.today => 'Today',
    _PositionFilter.thisWeek => 'This Week',
    _PositionFilter.goodFix => 'Good Fix',
    _PositionFilter.myNode => 'My Node',
  };

  IconData? get icon => switch (this) {
    _PositionFilter.all => null,
    _PositionFilter.today => Icons.today,
    _PositionFilter.thisWeek => Icons.date_range,
    _PositionFilter.goodFix => Icons.satellite_alt,
    _PositionFilter.myNode => Icons.person_pin_circle,
  };
}

/// Minimum satellites for a "good fix" filter.
const int _kGoodFixMinSats = 6;

// ---------------------------------------------------------------------------
// Position history screen with search, filter chips, and map view
// ---------------------------------------------------------------------------

class PositionLogScreen extends ConsumerStatefulWidget {
  const PositionLogScreen({super.key});

  @override
  ConsumerState<PositionLogScreen> createState() => _PositionLogScreenState();
}

class _PositionLogScreenState extends ConsumerState<PositionLogScreen>
    with LifecycleSafeMixin<PositionLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _PositionFilter _activeFilter = _PositionFilter.all;

  // Optional custom date range (applied when user picks via DatePickerSheet).
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool _showMap = false;
  MapTileStyle _mapStyle = MapTileStyle.dark;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final index = settings.mapTileStyleIndex;
    if (!mounted) return;
    if (index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() => _mapStyle = MapTileStyle.values[index]);
    }
  }

  // -----------------------------------------------------------------------
  // Filtering
  // -----------------------------------------------------------------------

  List<PositionLog> _filterLogs(List<PositionLog> logs) {
    final now = DateTime.now();

    return logs.where((log) {
      // ---- enum-based filter ----
      switch (_activeFilter) {
        case _PositionFilter.today:
          final startOfDay = DateTime(now.year, now.month, now.day);
          if (log.timestamp.isBefore(startOfDay)) return false;
        case _PositionFilter.thisWeek:
          final startOfWeek = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1));
          if (log.timestamp.isBefore(startOfWeek)) return false;
        case _PositionFilter.goodFix:
          if (log.satsInView == null || log.satsInView! < _kGoodFixMinSats) {
            return false;
          }
        case _PositionFilter.myNode:
          final myNodeNum = ref.read(myNodeNumProvider);
          if (myNodeNum == null || log.nodeNum != myNodeNum) return false;
        case _PositionFilter.all:
          break;
      }

      // ---- optional custom date range ----
      if (_customStartDate != null &&
          log.timestamp.isBefore(_customStartDate!)) {
        return false;
      }
      if (_customEndDate != null &&
          log.timestamp.isAfter(_customEndDate!.add(const Duration(days: 1)))) {
        return false;
      }

      // ---- text search by node name ----
      if (_searchQuery.isNotEmpty) {
        final nodes = ref.read(nodesProvider);
        final nodeName =
            nodes[log.nodeNum]?.displayName ??
            '!${log.nodeNum.toRadixString(16).toUpperCase()}';
        if (!nodeName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _activeFilter != _PositionFilter.all ||
      _customStartDate != null ||
      _customEndDate != null ||
      _searchQuery.isNotEmpty;

  void _clearFilters() {
    HapticFeedback.selectionClick();
    safeSetState(() {
      _activeFilter = _PositionFilter.all;
      _customStartDate = null;
      _customEndDate = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // -----------------------------------------------------------------------
  // Date range picker (uses DatePickerSheet, not banned Material dialogs)
  // -----------------------------------------------------------------------

  Future<void> _selectDateRange() async {
    final start = await DatePickerSheet.show(
      context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: 'Start Date',
    );
    if (!mounted || start == null) return;

    final end = await DatePickerSheet.show(
      context,
      initialDate: _customEndDate ?? start,
      firstDate: start,
      lastDate: DateTime.now(),
      title: 'End Date',
    );
    if (!mounted || end == null) return;

    safeSetState(() {
      _customStartDate = start;
      _customEndDate = end;
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // -----------------------------------------------------------------------
  // Filter chips
  // -----------------------------------------------------------------------

  List<Widget> _buildFilterChips(
    BuildContext context,
    List<PositionLog> allLogs,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final myNodeNum = ref.watch(myNodeNumProvider);

    final todayCount = allLogs
        .where((l) => !l.timestamp.isBefore(startOfDay))
        .length;
    final weekCount = allLogs
        .where((l) => !l.timestamp.isBefore(startOfWeek))
        .length;
    final goodFixCount = allLogs
        .where((l) => l.satsInView != null && l.satsInView! >= _kGoodFixMinSats)
        .length;
    final myNodeCount = myNodeNum != null
        ? allLogs.where((l) => l.nodeNum == myNodeNum).length
        : 0;

    return [
      SectionFilterChip(
        label: _PositionFilter.all.label,
        count: allLogs.length,
        isSelected: _activeFilter == _PositionFilter.all,
        onTap: () {
          HapticFeedback.selectionClick();
          safeSetState(() => _activeFilter = _PositionFilter.all);
        },
      ),
      SectionFilterChip(
        label: _PositionFilter.today.label,
        count: todayCount,
        isSelected: _activeFilter == _PositionFilter.today,
        icon: _PositionFilter.today.icon,
        color: AccentColors.cyan,
        onTap: () {
          HapticFeedback.selectionClick();
          safeSetState(() => _activeFilter = _PositionFilter.today);
        },
      ),
      SectionFilterChip(
        label: _PositionFilter.thisWeek.label,
        count: weekCount,
        isSelected: _activeFilter == _PositionFilter.thisWeek,
        icon: _PositionFilter.thisWeek.icon,
        color: AccentColors.purple,
        onTap: () {
          HapticFeedback.selectionClick();
          safeSetState(() => _activeFilter = _PositionFilter.thisWeek);
        },
      ),
      SectionFilterChip(
        label: _PositionFilter.goodFix.label,
        count: goodFixCount,
        isSelected: _activeFilter == _PositionFilter.goodFix,
        icon: _PositionFilter.goodFix.icon,
        color: AccentColors.green,
        onTap: () {
          HapticFeedback.selectionClick();
          safeSetState(() => _activeFilter = _PositionFilter.goodFix);
        },
      ),
      if (myNodeNum != null)
        SectionFilterChip(
          label: _PositionFilter.myNode.label,
          count: myNodeCount,
          isSelected: _activeFilter == _PositionFilter.myNode,
          icon: _PositionFilter.myNode.icon,
          color: AppTheme.primaryMagenta,
          onTap: () {
            HapticFeedback.selectionClick();
            safeSetState(() => _activeFilter = _PositionFilter.myNode);
          },
        ),
    ];
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(positionLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: 'Position',
        actions: [
          // Date range selector
          IconButton(
            icon: Badge(
              isLabelVisible:
                  _customStartDate != null || _customEndDate != null,
              child: const Icon(Icons.date_range),
            ),
            tooltip: 'Date range',
            onPressed: _selectDateRange,
          ),
          // Map / list toggle
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'List view' : 'Map view',
            onPressed: () {
              HapticFeedback.selectionClick();
              safeSetState(() => _showMap = !_showMap);
            },
          ),
        ],
        slivers: [
          logsAsync.when(
            loading: () =>
                const SliverFillRemaining(child: ScreenLoadingIndicator()),
            error: (e, s) =>
                SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            data: (logs) {
              final filtered = _filterLogs(logs)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              // Build the list of slivers for the data state
              return SliverMainAxisGroup(
                slivers: [
                  // Pinned search + filter chips
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: SearchFilterHeaderDelegate(
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      onSearchChanged: (value) =>
                          safeSetState(() => _searchQuery = value),
                      hintText: 'Search by node name',
                      textScaler: MediaQuery.textScalerOf(context),
                      rebuildKey: Object.hashAll([
                        _activeFilter,
                        _customStartDate,
                        _customEndDate,
                        logs.length,
                        _searchQuery,
                      ]),
                      filterChips: _buildFilterChips(context, logs),
                    ),
                  ),

                  // Date range indicator (when custom range is active)
                  if (_customStartDate != null || _customEndDate != null)
                    SliverToBoxAdapter(
                      child: _DateRangeBanner(
                        startDate: _customStartDate,
                        endDate: _customEndDate,
                        onClear: () {
                          HapticFeedback.selectionClick();
                          safeSetState(() {
                            _customStartDate = null;
                            _customEndDate = null;
                          });
                        },
                      ),
                    ),

                  // Empty state
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasActiveFilters
                                  ? 'No positions match filters'
                                  : 'No position history',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: context.textSecondary),
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.filter_alt_off,
                                  size: 18,
                                ),
                                label: const Text('Clear all filters'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  // Map view
                  else if (_showMap)
                    SliverFillRemaining(
                      child: _PositionMapView(
                        logs: filtered,
                        nodes: nodes,
                        mapStyle: _mapStyle,
                      ),
                    )
                  // List view
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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

// ---------------------------------------------------------------------------
// Date range banner — shown below filter chips when a custom range is active
// ---------------------------------------------------------------------------

class _DateRangeBanner extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onClear;

  const _DateRangeBanner({this.startDate, this.endDate, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    final label = startDate != null && endDate != null
        ? '${fmt.format(startDate!)} – ${fmt.format(endDate!)}'
        : startDate != null
        ? 'From ${fmt.format(startDate!)}'
        : 'Until ${fmt.format(endDate!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, size: 16, color: context.accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.accentColor,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 16, color: context.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map view (preserved from original)
// ---------------------------------------------------------------------------

class _PositionMapView extends StatefulWidget {
  final List<PositionLog> logs;
  final Map<int, dynamic> nodes;
  final MapTileStyle mapStyle;

  const _PositionMapView({
    required this.logs,
    required this.nodes,
    required this.mapStyle,
  });

  @override
  State<_PositionMapView> createState() => _PositionMapViewState();
}

class _PositionMapViewState extends State<_PositionMapView> {
  final MapController _mapController = MapController();
  bool _showTrail = true;
  int? _selectedNodeNum;
  double _currentZoom = 14.0;

  List<int> get _nodeNums => widget.logs.map((l) => l.nodeNum).toSet().toList();

  List<PositionLog> get _filteredLogs => _selectedNodeNum == null
      ? widget.logs
      : widget.logs.where((l) => l.nodeNum == _selectedNodeNum).toList();

  void _fitAllPositions() {
    final lats = widget.logs.map((l) => l.latitude).toList();
    final lons = widget.logs.map((l) => l.longitude).toList();
    if (lats.isNotEmpty) {
      final bounds = LatLngBounds(
        LatLng(lats.reduce(math.min), lons.reduce(math.min)),
        LatLng(lats.reduce(math.max), lons.reduce(math.max)),
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: context.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No positions to display',
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
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
        MeshMapWidget(
          mapController: _mapController,
          mapStyle: widget.mapStyle,
          initialCenter: center,
          initialZoom: _currentZoom,
          onPositionChanged: (camera, hasGesture) {
            if (camera.zoom != _currentZoom) {
              setState(() => _currentZoom = camera.zoom);
            }
          },
          additionalLayers: [
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
                    color: context.card,
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
                  color: context.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    _showTrail ? Icons.timeline : Icons.timeline_outlined,
                    color: _showTrail
                        ? Theme.of(context).colorScheme.primary
                        : context.textSecondary,
                  ),
                  tooltip: 'Toggle trail',
                  onPressed: () => setState(() => _showTrail = !_showTrail),
                ),
              ),

              const SizedBox(height: 8),

              // Zoom controls
              MapZoomControls(
                currentZoom: _currentZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                showFitAll: true,
                onZoomIn: () {
                  final newZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
                onZoomOut: () {
                  final newZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
                onFitAll: _fitAllPositions,
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
              color: context.card.withValues(alpha: 0.9),
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
    const colors = [
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

// ---------------------------------------------------------------------------
// Stat item (map overlay)
// ---------------------------------------------------------------------------

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
        Icon(icon, size: 20, color: context.textTertiary),
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

// ---------------------------------------------------------------------------
// Position card (list view)
// ---------------------------------------------------------------------------

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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: node name + date
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

// ---------------------------------------------------------------------------
// Metric chip
// ---------------------------------------------------------------------------

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
        color: (color ?? context.textTertiary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? context.textTertiary),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
