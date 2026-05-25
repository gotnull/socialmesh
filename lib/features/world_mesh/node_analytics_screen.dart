// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/info_table.dart';
import '../../models/world_mesh_node.dart';
import '../../models/presence_confidence.dart';
import '../../services/world_mesh_map_service.dart';
import '../../utils/share_utils.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
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

    if (!mounted) return;
    final l10n = context.l10n;
    setState(() => _isRefreshing = true);
    try {
      final freshNode = await _meshService.fetchNode(widget.node.nodeNum);
      if (!mounted) return;
      if (freshNode != null) {
        setState(() => _currentNode = freshNode);
        await _recordVisit();
        if (!mounted) return;
        showSuccessSnackBar(context, l10n.nodeAnalyticsDataUpdated);
      } else {
        showErrorSnackBar(context, l10n.nodeAnalyticsNodeNotFound);
      }
    } catch (e) {
      showErrorSnackBar(context, l10n.nodeAnalyticsRefreshFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final l10n = context.l10n;
    HapticFeedback.mediumImpact();
    if (_isFavorite) {
      await _favoritesService.removeFavorite(_nodeId);
      if (mounted) {
        showSuccessSnackBar(context, l10n.nodeAnalyticsRemovedFromFavorites);
      }
    } else {
      await _favoritesService.addFavorite(_node);
      if (mounted) {
        showSuccessSnackBar(context, l10n.nodeAnalyticsAddedToFavorites);
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
      showSuccessSnackBar(context, context.l10n.nodeAnalyticsLiveWatchEnabled);
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      showSuccessSnackBar(context, context.l10n.nodeAnalyticsLiveWatchDisabled);
    }
  }

  Future<void> _clearHistory() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.nodeAnalyticsClearHistoryTitle,
      message: l10n.nodeAnalyticsClearHistoryMessage,
      confirmLabel: l10n.nodeAnalyticsClearConfirm,
      isDestructive: true,
    );

    if (confirmed == true) {
      await _historyService.clearHistory(_nodeId);
      await _loadHistory();
      if (mounted) {
        showSuccessSnackBar(context, l10n.nodeAnalyticsHistoryCleared);
      }
    }
  }

  void _shareNode() {
    AppBottomSheet.showRaw<void>(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.nodeAnalyticsShareNodeTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: AppTheme.spacing20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppTheme.spacing10),
                decoration: BoxDecoration(
                  color: AccentColors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(Icons.link, color: AccentColors.blue),
              ),
              title: Text(
                context.l10n.nodeAnalyticsShareLink,
                style: TextStyle(color: context.textPrimary),
              ),
              subtitle: Text(
                context.l10n.nodeAnalyticsShareLinkSubtitle,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareNodeAsLink();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppTheme.spacing10),
                decoration: BoxDecoration(
                  color: AccentColors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(Icons.text_snippet, color: AccentColors.green),
              ),
              title: Text(
                context.l10n.nodeAnalyticsShareDetails,
                style: TextStyle(color: context.textPrimary),
              ),
              subtitle: Text(
                context.l10n.nodeAnalyticsShareDetailsSubtitle,
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
    final l10n = context.l10n;
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        showActionSnackBar(
          context,
          l10n.nodeAnalyticsSignInToShare,
          actionLabel: l10n.nodeAnalyticsSignIn,
          onAction: () => Navigator.pushNamed(context, '/account'),
          type: SnackBarType.info,
        );
      }
      return;
    }

    final node = _node;

    // Capture share position before async gap
    final sharePosition = getSafeSharePosition(context);

    // Create a shareable record in Firestore
    final lastSeenAge = node.lastSeen != null
        ? DateTime.now().difference(node.lastSeen!)
        : null;
    final statusText = presenceStatusText(node.presenceConfidence, lastSeenAge);

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('shared_nodes')
          .add({
            'nodeId': _nodeId,
            'name': node.displayName,
            'description': '${node.role} • ${node.hwModel} • $statusText',
            'createdBy': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

      final shareUrl = AppUrls.shareNodeUrl(docRef.id);

      await Share.share(
        l10n.nodeAnalyticsShareText(node.displayName, shareUrl),
        subject: l10n.nodeAnalyticsShareSubject(node.displayName),
        sharePositionOrigin: sharePosition,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.nodeAnalyticsShareFailed(e.toString()));
      }
    }
  }

  void _shareNodeAsText() {
    final node = _node;
    final buffer = StringBuffer();
    buffer.writeln(
      context.l10n.nodeAnalyticsShareDetailHeader(node.displayName),
    );
    buffer.writeln(context.l10n.nodeAnalyticsShareDetailId(_nodeId));
    buffer.writeln(context.l10n.nodeAnalyticsShareDetailRole(node.role));
    buffer.writeln(context.l10n.nodeAnalyticsShareDetailHardware(node.hwModel));

    if (node.batteryLevel != null) {
      buffer.writeln(
        node.batteryLevel! > 100
            ? context.l10n.nodeAnalyticsShareDetailBatteryCharging
            : context.l10n.nodeAnalyticsShareDetailBatteryLevel(
                '${node.batteryLevel}',
              ),
      );
    }

    if (node.latitude != 0 && node.longitude != 0) {
      buffer.writeln(
        context.l10n.nodeAnalyticsShareDetailLocation(
          '${node.latitudeDecimal.toStringAsFixed(5)}, ${node.longitudeDecimal.toStringAsFixed(5)}',
        ),
      );
      buffer.writeln(
        'Map: https://www.google.com/maps?q=${node.latitudeDecimal},${node.longitudeDecimal}', // lint-allow: hardcoded-string
      );
    }

    buffer.writeln('');
    final lastSeenAge = node.lastSeen != null
        ? DateTime.now().difference(node.lastSeen!)
        : null;
    buffer.writeln(
      context.l10n.nodeAnalyticsShareDetailStatus(
        presenceStatusText(node.presenceConfidence, lastSeenAge),
      ),
    );
    buffer.writeln(
      context.l10n.nodeAnalyticsShareDetailNeighbors(
        '${node.neighbors?.length ?? 0}',
      ),
    );
    buffer.writeln(
      context.l10n.nodeAnalyticsShareDetailGateways('${node.seenBy.length}'),
    );

    shareText(
      buffer.toString(),
      subject: context.l10n.nodeAnalyticsShareSubject(node.displayName),
      context: context,
    );
  }

  void _showOnMap() {
    Navigator.pop(context);
    widget.onShowOnMap?.call();
  }

  void _exportHistory() {
    if (_history.isEmpty) {
      showErrorSnackBar(context, context.l10n.nodeAnalyticsNoHistoryToExport);
      return;
    }

    AppBottomSheet.showRaw<void>(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.nodeAnalyticsExportHistoryTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.nodeAnalyticsExportRecordCount(_history.length),
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAsJson();
                    },
                    icon: Icon(Icons.code, size: 18),
                    label: Text(context.l10n.nodeAnalyticsExportJson),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportAsCsv();
                    },
                    icon: Icon(Icons.table_chart, size: 18),
                    label: Text(context.l10n.nodeAnalyticsExportCsv),
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
            const SizedBox(height: AppTheme.spacing16),
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
              'presenceConfidence': entry.presenceConfidence.name,
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
    shareText(
      jsonString,
      subject: context.l10n.nodeAnalyticsExportJsonSubject(node.displayName),
      context: context,
    );
    showSuccessSnackBar(context, context.l10n.nodeAnalyticsJsonShared);
  }

  void _exportAsCsv() {
    final node = _node;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,presenceConfidence,batteryLevel,voltage,channelUtil,airUtilTx,neighborCount,gatewayCount,latitude,longitude', // lint-allow: hardcoded-string
    );

    for (final entry in _history) {
      buffer.writeln(
        [
          dateFormat.format(entry.timestamp),
          entry.presenceConfidence.name,
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

    shareText(
      buffer.toString(),
      subject: context.l10n.nodeAnalyticsExportCsvSubject(node.displayName),
      context: context,
    );
    showSuccessSnackBar(context, context.l10n.nodeAnalyticsCsvShared);
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

    return GlassScaffold(
      titleWidget: AutoScrollText(
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
          tooltip: context.l10n.nodeAnalyticsShareTooltip,
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
          tooltip: _isLiveWatching
              ? context.l10n.nodeAnalyticsStopWatching
              : context.l10n.nodeAnalyticsWatchLive,
          onPressed: _isRefreshing ? null : _toggleLiveWatching,
        ),
        // Favorite toggle
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.star : Icons.star_border,
            color: _isFavorite ? const Color(0xFFFFD700) : null,
          ),
          tooltip: _isFavorite
              ? context.l10n.nodeAnalyticsRemoveFavoriteTooltip
              : context.l10n.nodeAnalyticsAddFavoriteTooltip,
          onPressed: _toggleFavorite,
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Status card
              _buildStatusCard(node),
              const SizedBox(height: AppTheme.spacing16),

              // Quick actions
              _buildQuickActions(node),
              const SizedBox(height: AppTheme.spacing24),

              // Device info section
              _buildSectionHeader(context.l10n.nodeAnalyticsSectionDeviceInfo),
              const SizedBox(height: AppTheme.spacing8),
              _buildDeviceInfoTable(node),
              const SizedBox(height: AppTheme.spacing24),

              // Metrics section
              _buildSectionHeader(
                context.l10n.nodeAnalyticsSectionDeviceMetrics,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildMetricsTable(node),
              const SizedBox(height: AppTheme.spacing24),

              // Network section
              _buildSectionHeader(context.l10n.nodeAnalyticsSectionNetwork),
              const SizedBox(height: AppTheme.spacing8),
              _buildNetworkSection(node),
              const SizedBox(height: AppTheme.spacing24),

              // Charts section
              _buildSectionHeader(context.l10n.nodeAnalyticsSectionTrends),
              const SizedBox(height: AppTheme.spacing8),
              NodeHistoryCharts(
                history: _history,
                accentColor: context.accentColor,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // History section
              _buildHistorySectionHeader(),
              const SizedBox(height: AppTheme.spacing8),
              _buildHistorySection(),
              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(WorldMeshNode node) {
    final lastSeenAge = node.lastSeen != null
        ? DateTime.now().difference(node.lastSeen!)
        : null;
    final statusColor = _presenceColor(context, node.presenceConfidence);
    final statusText = presenceStatusText(node.presenceConfidence, lastSeenAge);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                _presenceIcon(node.presenceConfidence),
                color: statusColor,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
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
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (_isLiveWatching) ...[
                      const SizedBox(width: AppTheme.spacing12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AccentColors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                        ),
                        child: Text(
                          context.l10n.nodeAnalyticsBadgeLive,
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
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  '!$_nodeId', // lint-allow: hardcoded-string
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                if (node.role != 'UNKNOWN') ...[
                  SizedBox(height: AppTheme.spacing2),
                  Text(
                    _formatRole(node.role),
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
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
              Clipboard.setData(
                ClipboardData(text: '!$_nodeId'),
              ); // lint-allow: hardcoded-string
              showSuccessSnackBar(
                context,
                context.l10n.nodeAnalyticsNodeIdCopied,
              );
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
              label: Text(context.l10n.nodeAnalyticsShowOnMap),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.accentColor,
                side: BorderSide(
                  color: context.accentColor.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (hasLocation && widget.onShowOnMap != null)
          SizedBox(width: AppTheme.spacing12),
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
            label: Text(
              _isRefreshing
                  ? context.l10n.nodeAnalyticsRefreshing
                  : context.l10n.nodeAnalyticsRefreshNow,
            ),
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
          context.l10n.nodeAnalyticsSectionHistory,
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
                label: Text(context.l10n.nodeAnalyticsExport),
                style: TextButton.styleFrom(
                  foregroundColor: context.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: _clearHistory,
                icon: Icon(Icons.delete_outline, size: 16),
                label: Text(context.l10n.nodeAnalyticsClear),
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
          label: context.l10n.nodeAnalyticsLongName,
          value: node.longName.isNotEmpty ? node.longName : '—',
        ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsShortName,
          value: node.shortName.isNotEmpty && node.shortName != '????'
              ? node.shortName
              : nodeIdHex.substring(0, 4).toUpperCase(),
        ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsRole,
          value: node.role != 'UNKNOWN' ? _formatRole(node.role) : '—',
        ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsHardware,
          value: node.hwModel.isNotEmpty && node.hwModel != 'UNKNOWN'
              ? node.hwModel
              : '—',
        ),
        if (node.latitude != 0 && node.longitude != 0) ...[
          InfoTableRow(
            label: context.l10n.nodeAnalyticsLatitude,
            value: node.latitudeDecimal.toStringAsFixed(6),
          ),
          InfoTableRow(
            label: context.l10n.nodeAnalyticsLongitude,
            value: node.longitudeDecimal.toStringAsFixed(6),
          ),
          if (node.altitude != null)
            InfoTableRow(
              label: context.l10n.nodeAnalyticsAltitudeRowLabel,
              value: context.l10n.nodeAnalyticsAltitude('${node.altitude}'),
            ),
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
          label: context.l10n.nodeAnalyticsBattery,
          value: node.batteryLevel != null
              ? (node.batteryLevel! > 100
                    ? context.l10n.nodeAnalyticsCharging
                    : '${node.batteryLevel}%')
              : context.l10n.nodeAnalyticsUnknown,
        ),
        if (node.voltage != null)
          InfoTableRow(
            label: context.l10n.nodeAnalyticsVoltage,
            value: '${node.voltage!.toStringAsFixed(2)}V',
          ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsChannelUtilization,
          value: node.chUtil != null
              ? '${node.chUtil!.toStringAsFixed(1)}%'
              : context.l10n.nodeAnalyticsUnknown,
        ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsAirTimeTx,
          value: node.airUtilTx != null
              ? '${node.airUtilTx!.toStringAsFixed(1)}%'
              : context.l10n.nodeAnalyticsUnknown,
        ),
        InfoTableRow(
          label: context.l10n.nodeAnalyticsUptime,
          value: _formatUptime(node.uptime),
        ),
      ],
    );
  }

  Widget _buildNetworkSection(WorldMeshNode node) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neighbors
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: context.textTertiary),
                    SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.nodeAnalyticsDirectNeighbors(
                        node.neighbors?.length ?? 0,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing12),
                if (node.neighbors == null || node.neighbors!.isEmpty)
                  Text(
                    context.l10n.nodeAnalyticsNoNeighborData,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.router, size: 16, color: context.textTertiary),
                    SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.nodeAnalyticsSeenByGateways(
                        node.seenBy.length,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing12),
                if (node.seenBy.isEmpty)
                  Text(
                    context.l10n.nodeAnalyticsNoGatewayData,
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
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio, size: 12, color: color),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            nodeId.length > 8 ? '${nodeId.substring(0, 8)}…' : nodeId,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          if (snr != null) ...[
            const SizedBox(width: AppTheme.spacing6),
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
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.router, size: 12, color: context.accentColor),
          SizedBox(width: AppTheme.spacing6),
          Text(
            gateway.length > 12 ? '${gateway.substring(0, 12)}…' : gateway,
            style: TextStyle(
              fontSize: 11,
              color: context.accentColor,
              fontFamily: AppTheme.fontFamily,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: _history.isEmpty
          ? Column(
              children: [
                Icon(Icons.history, size: 40, color: context.textTertiary),
                SizedBox(height: AppTheme.spacing12),
                Text(
                  context.l10n.nodeAnalyticsNoHistoryYet,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing4),
                Text(
                  context.l10n.nodeAnalyticsVisitAgain,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
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
                        context.l10n.nodeAnalyticsRecords,
                        '${_history.length}',
                        Icons.data_array,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context.l10n.nodeAnalyticsUptimeStat,
                        _stats != null
                            ? '${_stats!.uptimePercent.toStringAsFixed(0)}%'
                            : '--',
                        Icons.timer,
                      ),
                    ),
                    if (_stats?.avgBattery != null)
                      Expanded(
                        child: _buildStatItem(
                          context.l10n.nodeAnalyticsAvgBattery,
                          '${_stats!.avgBattery!.toStringAsFixed(0)}%',
                          Icons.battery_std,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing16),
                Container(height: 1, color: context.border),
                SizedBox(height: AppTheme.spacing16),
                // Time info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.nodeAnalyticsFirstSeen,
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
                          context.l10n.nodeAnalyticsLastUpdate,
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
        SizedBox(height: AppTheme.spacing4),
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
          style: context.captionStyle?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }

  String _formatUptime(int? seconds) {
    if (seconds == null) return context.l10n.nodeAnalyticsUnknown;
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
    if (diff.inDays > 0) {
      return context.l10n.nodeAnalyticsTimeDaysAgo(diff.inDays);
    }
    if (diff.inHours > 0) {
      return context.l10n.nodeAnalyticsTimeHoursAgo(diff.inHours);
    }
    if (diff.inMinutes > 0) {
      return context.l10n.nodeAnalyticsTimeMinutesAgo(diff.inMinutes);
    }
    return context.l10n.nodeAnalyticsTimeJustNow;
  }

  Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  IconData _presenceIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.wifi;
      case PresenceConfidence.fading:
        return Icons.wifi_1_bar;
      case PresenceConfidence.stale:
        return Icons.wifi_off;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
  }
}
