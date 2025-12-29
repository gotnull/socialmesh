import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/info_table.dart';
import '../../models/world_mesh_node.dart';
import '../../services/world_mesh_map_service.dart';
import '../../utils/snackbar.dart';
import 'services/node_favorites_service.dart';
import 'services/node_history_service.dart';
import 'widgets/node_history_charts.dart';

/// Dedicated analytics screen for deep-dive into a single mesh node.
/// Features live updates, historical trends, favorites, share, and map link.
class NodeAnalyticsScreen extends StatefulWidget {
  final WorldMeshNode node;
  final VoidCallback? onShowOnMap;

  const NodeAnalyticsScreen({super.key, required this.node, this.onShowOnMap});

  @override
  State<NodeAnalyticsScreen> createState() => _NodeAnalyticsScreenState();
}

class _NodeAnalyticsScreenState extends State<NodeAnalyticsScreen> {
  final NodeFavoritesService _favoritesService = NodeFavoritesService();
  final NodeHistoryService _historyService = NodeHistoryService();
  final WorldMeshMapService _meshService = WorldMeshMapService();

  bool _isFavorite = false;
  bool _isLiveWatching = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  List<NodeHistoryEntry> _history = [];
  NodeHistoryStats? _stats;
  WorldMeshNode? _currentNode;

  String get _nodeId => widget.node.nodeNum.toRadixString(16).toUpperCase();
  WorldMeshNode get _node => _currentNode ?? widget.node;

  @override
  void initState() {
    super.initState();
    _currentNode = widget.node;
    _loadFavoriteStatus();
    _loadHistory();
    _recordVisit();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await _favoritesService.isFavorite(_nodeId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory(_nodeId);
    final stats = await _historyService.getStats(_nodeId);
    if (mounted) {
      setState(() {
        _history = history;
        _stats = stats;
      });
    }
  }

  Future<void> _recordVisit() async {
    await _historyService.recordSnapshot(
      _nodeId,
      NodeHistoryEntry.fromNode(_node),
    );
    await _loadHistory();
  }

  Future<void> _fetchLiveData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      final freshNode = await _meshService.fetchNode(widget.node.nodeNum);
      if (!mounted) return;
      if (freshNode != null) {
        setState(() => _currentNode = freshNode);
        await _recordVisit();
        if (!mounted) return;
        showSuccessSnackBar(context, 'Node data updated');
      } else {
        showErrorSnackBar(context, 'Node not found in mesh');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to refresh: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.mediumImpact();
    if (_isFavorite) {
      await _favoritesService.removeFavorite(_nodeId);
      if (mounted) {
        showSuccessSnackBar(context, 'Removed from favorites');
      }
    } else {
      await _favoritesService.addFavorite(_node);
      if (mounted) {
        showSuccessSnackBar(context, 'Added to favorites');
      }
    }
    await _loadFavoriteStatus();
  }

  void _toggleLiveWatching() {
    HapticFeedback.lightImpact();
    setState(() {
      _isLiveWatching = !_isLiveWatching;
    });

    if (_isLiveWatching) {
      // Fetch immediately, then every 30 seconds
      _fetchLiveData();
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _fetchLiveData();
      });
      showSuccessSnackBar(context, 'Live watching enabled (updates every 30s)');
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      showSuccessSnackBar(context, 'Live watching disabled');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 12),
            Text(
              'Clear History',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'This will delete all historical data for this node. This action cannot be undone.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory(_nodeId);
      await _loadHistory();
      if (mounted) {
        showSuccessSnackBar(context, 'History cleared');
      }
    }
  }

  void _shareNode() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Node',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AccentColors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.link, color: AccentColors.blue),
              ),
              title: Text(
                'Share Link',
                style: TextStyle(color: context.textPrimary),
              ),
              subtitle: Text(
                'Rich preview in iMessage, Slack, etc.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareNodeAsLink();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AccentColors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.text_snippet, color: AccentColors.green),
              ),
              title: Text(
                'Share Details',
                style: TextStyle(color: context.textPrimary),
              ),
              subtitle: Text(
                'Full technical info as text',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareNodeAsText();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareNodeAsLink() async {
    final node = _node;

    // Create a shareable record in Firestore
    final docRef = await FirebaseFirestore.instance.collection('shared_nodes').add({
      'nodeId': _nodeId,
      'name': node.displayName,
      'description':
          '${node.role} • ${node.hwModel} • ${node.isOnline ? "Online" : "Offline"}',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final shareUrl = AppUrls.shareNodeUrl(docRef.id);

    Share.share(
      'Check out ${node.displayName} on Socialmesh!\n$shareUrl',
      subject: 'Mesh Node: ${node.displayName}',
    );
  }

  void _shareNodeAsText() {
    final node = _node;
    final buffer = StringBuffer();
    buffer.writeln('🛰️ Mesh Node: ${node.displayName}');
    buffer.writeln('ID: !$_nodeId');
    buffer.writeln('Role: ${node.role}');
    buffer.writeln('Hardware: ${node.hwModel}');

    if (node.batteryLevel != null) {
      buffer.writeln(
        'Battery: ${node.batteryLevel! > 100 ? "Charging" : "${node.batteryLevel}%"}',
      );
    }

    if (node.latitude != 0 && node.longitude != 0) {
      buffer.writeln(
        'Location: ${node.latitudeDecimal.toStringAsFixed(5)}, ${node.longitudeDecimal.toStringAsFixed(5)}',
      );
      buffer.writeln(
        'Map: https://www.google.com/maps?q=${node.latitudeDecimal},${node.longitudeDecimal}',
      );
    }

    buffer.writeln('');
    buffer.writeln(
      'Status: ${node.isOnline
          ? "Online"
          : node.isIdle
          ? "Idle"
          : "Offline"}',
    );
    buffer.writeln('Neighbors: ${node.neighbors?.length ?? 0}');
    buffer.writeln('Gateways: ${node.seenBy.length}');

    Share.share(buffer.toString(), subject: 'Mesh Node: ${node.displayName}');
  }

  void _showOnMap() {
    Navigator.pop(context);
    widget.onShowOnMap?.call();
  }

  void _exportHistory() {
    if (_history.isEmpty) {
      showErrorSnackBar(context, 'No history data to export');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${_history.length} records',
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAsJson();
                    },
                    icon: Icon(Icons.code, size: 18),
                    label: const Text('JSON'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAsCsv();
                    },
                    icon: Icon(Icons.table_chart, size: 18),
                    label: const Text('CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _exportAsJson() {
    final node = _node;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final data = {
      'nodeId': _nodeId,
      'nodeName': node.displayName,
      'exportedAt': dateFormat.format(DateTime.now()),
      'records': _history
          .map(
            (entry) => {
              'timestamp': dateFormat.format(entry.timestamp),
              'isOnline': entry.isOnline,
              'batteryLevel': entry.batteryLevel,
              'voltage': entry.voltage,
              'channelUtil': entry.channelUtil,
              'airUtilTx': entry.airUtilTx,
              'neighborCount': entry.neighborCount,
              'gatewayCount': entry.gatewayCount,
              'latitude': entry.latitude,
              'longitude': entry.longitude,
            },
          )
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    Share.share(jsonString, subject: 'Node ${node.displayName} History (JSON)');
    showSuccessSnackBar(context, 'JSON data shared');
  }

  void _exportAsCsv() {
    final node = _node;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,isOnline,batteryLevel,voltage,channelUtil,airUtilTx,neighborCount,gatewayCount,latitude,longitude',
    );

    for (final entry in _history) {
      buffer.writeln(
        [
          dateFormat.format(entry.timestamp),
          entry.isOnline ? '1' : '0',
          entry.batteryLevel?.toString() ?? '',
          entry.voltage?.toStringAsFixed(2) ?? '',
          entry.channelUtil?.toStringAsFixed(2) ?? '',
          entry.airUtilTx?.toStringAsFixed(2) ?? '',
          entry.neighborCount.toString(),
          entry.gatewayCount.toString(),
          entry.latitude?.toStringAsFixed(6) ?? '',
          entry.longitude?.toStringAsFixed(6) ?? '',
        ].join(','),
      );
    }

    Share.share(
      buffer.toString(),
      subject: 'Node ${node.displayName} History (CSV)',
    );
    showSuccessSnackBar(context, 'CSV data shared');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _meshService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: AutoScrollText(
          node.longName.isNotEmpty ? node.longName : node.shortName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share node info',
            onPressed: _shareNode,
          ),
          // Live watch toggle
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isLiveWatching ? Icons.sensors : Icons.sensors_off,
                    color: _isLiveWatching ? AccentColors.green : null,
                  ),
            tooltip: _isLiveWatching ? 'Stop watching' : 'Watch live',
            onPressed: _isRefreshing ? null : _toggleLiveWatching,
          ),
          // Favorite toggle
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? const Color(0xFFFFD700) : null,
            ),
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _buildStatusCard(node),
            const SizedBox(height: 16),

            // Quick actions
            _buildQuickActions(node),
            const SizedBox(height: 24),

            // Device info section
            _buildSectionHeader('Device Info'),
            const SizedBox(height: 8),
            _buildDeviceInfoTable(node),
            const SizedBox(height: 24),

            // Metrics section
            _buildSectionHeader('Device Metrics'),
            const SizedBox(height: 8),
            _buildMetricsTable(node),
            const SizedBox(height: 24),

            // Network section
            _buildSectionHeader('Network'),
            const SizedBox(height: 8),
            _buildNetworkSection(node),
            const SizedBox(height: 24),

            // Charts section
            _buildSectionHeader('Trends'),
            const SizedBox(height: 8),
            NodeHistoryCharts(
              history: _history,
              accentColor: context.accentColor,
            ),
            const SizedBox(height: 24),

            // History section
            _buildHistorySectionHeader(),
            const SizedBox(height: 8),
            _buildHistorySection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(WorldMeshNode node) {
    final statusColor = node.isOnline
        ? AccentColors.green
        : (node.isIdle ? AppTheme.warningYellow : context.textTertiary);
    final statusText = node.isOnline
        ? 'Online'
        : (node.isIdle ? 'Idle' : 'Offline');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Center(
              child: Icon(
                node.isOnline
                    ? Icons.wifi
                    : (node.isIdle ? Icons.wifi_1_bar : Icons.wifi_off),
                color: statusColor,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (_isLiveWatching) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AccentColors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AccentColors.green,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '!$_nodeId',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (node.role != 'UNKNOWN') ...[
                  SizedBox(height: 2),
                  Text(
                    _formatRole(node.role),
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          // Copy button
          IconButton(
            icon: Icon(Icons.copy, size: 20),
            color: context.textTertiary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '!$_nodeId'));
              showSuccessSnackBar(context, 'Node ID copied');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(WorldMeshNode node) {
    final hasLocation = node.latitude != 0 && node.longitude != 0;

    return Row(
      children: [
        // Show on map button
        if (hasLocation && widget.onShowOnMap != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showOnMap,
              icon: Icon(Icons.map, size: 18),
              label: const Text('Show on Map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.accentColor,
                side: BorderSide(
                  color: context.accentColor.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (hasLocation && widget.onShowOnMap != null) SizedBox(width: 12),
        // Refresh button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isRefreshing ? null : _fetchLiveData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh Now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.accentColor,
              side: BorderSide(
                color: context.accentColor.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildHistorySectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        Row(
          children: [
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: _exportHistory,
                icon: Icon(Icons.download, size: 16),
                label: const Text('Export'),
                style: TextButton.styleFrom(
                  foregroundColor: context.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: _clearHistory,
                icon: Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: context.textTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceInfoTable(WorldMeshNode node) {
    final nodeIdHex = node.nodeNum.toRadixString(16).padLeft(8, '0');
    return InfoTable(
      rows: [
        InfoTableRow(
          label: 'Long Name',
          value: node.longName.isNotEmpty ? node.longName : '—',
        ),
        InfoTableRow(
          label: 'Short Name',
          value: node.shortName.isNotEmpty && node.shortName != '????'
              ? node.shortName
              : nodeIdHex.substring(0, 4).toUpperCase(),
        ),
        InfoTableRow(
          label: 'Role',
          value: node.role != 'UNKNOWN' ? _formatRole(node.role) : '—',
        ),
        InfoTableRow(
          label: 'Hardware',
          value: node.hwModel.isNotEmpty && node.hwModel != 'UNKNOWN'
              ? node.hwModel
              : '—',
        ),
        if (node.latitude != 0 && node.longitude != 0) ...[
          InfoTableRow(
            label: 'Latitude',
            value: node.latitudeDecimal.toStringAsFixed(6),
          ),
          InfoTableRow(
            label: 'Longitude',
            value: node.longitudeDecimal.toStringAsFixed(6),
          ),
          if (node.altitude != null)
            InfoTableRow(label: 'Altitude', value: '${node.altitude}m'),
        ],
      ],
    );
  }

  String _formatRole(String role) {
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  Widget _buildMetricsTable(WorldMeshNode node) {
    return InfoTable(
      rows: [
        InfoTableRow(
          label: 'Battery',
          value: node.batteryLevel != null
              ? (node.batteryLevel! > 100
                    ? 'Charging'
                    : '${node.batteryLevel}%')
              : 'Unknown',
        ),
        if (node.voltage != null)
          InfoTableRow(
            label: 'Voltage',
            value: '${node.voltage!.toStringAsFixed(2)}V',
          ),
        InfoTableRow(
          label: 'Channel Utilization',
          value: node.chUtil != null
              ? '${node.chUtil!.toStringAsFixed(1)}%'
              : 'Unknown',
        ),
        InfoTableRow(
          label: 'Air Time TX',
          value: node.airUtilTx != null
              ? '${node.airUtilTx!.toStringAsFixed(1)}%'
              : 'Unknown',
        ),
        InfoTableRow(label: 'Uptime', value: _formatUptime(node.uptime)),
      ],
    );
  }

  Widget _buildNetworkSection(WorldMeshNode node) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neighbors
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: context.textTertiary),
                    SizedBox(width: 8),
                    Text(
                      'Direct Neighbors (${node.neighbors?.length ?? 0})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (node.neighbors == null || node.neighbors!.isEmpty)
                  Text(
                    'No neighbor data available',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: node.neighbors!.entries.map((e) {
                      return _buildNeighborChip(e.key, e.value.snr);
                    }).toList(),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: context.border),
          // Gateways
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.router, size: 16, color: context.textTertiary),
                    SizedBox(width: 8),
                    Text(
                      'Seen by Gateways (${node.seenBy.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (node.seenBy.isEmpty)
                  Text(
                    'No gateway data available',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: node.seenBy.keys.map((gateway) {
                      return _buildGatewayChip(gateway);
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeighborChip(String nodeId, double? snr) {
    final color = snr != null
        ? (snr > 5
              ? AccentColors.green
              : (snr > 0 ? AppTheme.warningYellow : AppTheme.errorRed))
        : context.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            nodeId.length > 8 ? '${nodeId.substring(0, 8)}…' : nodeId,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          if (snr != null) ...[
            const SizedBox(width: 6),
            Text(
              '${snr.toStringAsFixed(1)}dB',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGatewayChip(String gateway) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.router, size: 12, color: context.accentColor),
          SizedBox(width: 6),
          Text(
            gateway.length > 12 ? '${gateway.substring(0, 12)}…' : gateway,
            style: TextStyle(
              fontSize: 11,
              color: context.accentColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(16),
      child: _history.isEmpty
          ? Column(
              children: [
                Icon(Icons.history, size: 40, color: context.textTertiary),
                SizedBox(height: 12),
                Text(
                  'No historical data yet',
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  'Visit this node again to build history',
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            )
          : Column(
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Records',
                        '${_history.length}',
                        Icons.data_array,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Uptime',
                        _stats != null
                            ? '${_stats!.uptimePercent.toStringAsFixed(0)}%'
                            : '--',
                        Icons.timer,
                      ),
                    ),
                    if (_stats?.avgBattery != null)
                      Expanded(
                        child: _buildStatItem(
                          'Avg Battery',
                          '${_stats!.avgBattery!.toStringAsFixed(0)}%',
                          Icons.battery_std,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Container(height: 1, color: context.border),
                SizedBox(height: 16),
                // Time info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'First seen',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(_history.first.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Last update',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(_history.last.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: context.textTertiary),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.accentColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.textTertiary),
        ),
      ],
    );
  }

  String _formatUptime(int? seconds) {
    if (seconds == null) return 'Unknown';
    final duration = Duration(seconds: seconds);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
