// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../nodes/node_display_name_resolver.dart';

/// Filter options for traceroute logs
enum _TracerouteFilter { all, responded, noResponse }

/// Screen showing traceroute history with hop visualization and filtering
class TraceRouteLogScreen extends ConsumerStatefulWidget {
  final int? nodeNum;

  const TraceRouteLogScreen({super.key, this.nodeNum});

  @override
  ConsumerState<TraceRouteLogScreen> createState() =>
      _TraceRouteLogScreenState();
}

class _TraceRouteLogScreenState extends ConsumerState<TraceRouteLogScreen>
    with LifecycleSafeMixin<TraceRouteLogScreen> {
  String _searchQuery = '';
  _TracerouteFilter _activeFilter = _TracerouteFilter.all;
  bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TraceRouteLog> _applyFilters(List<TraceRouteLog> logs) {
    var filtered = List<TraceRouteLog>.from(logs);

    // Apply response filter
    switch (_activeFilter) {
      case _TracerouteFilter.all:
        break;
      case _TracerouteFilter.responded:
        filtered = filtered.where((log) => log.response).toList();
      case _TracerouteFilter.noResponse:
        filtered = filtered.where((log) => !log.response).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final nodes = ref.read(nodesProvider);
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        final targetNode = nodes[log.targetNode];
        final targetName =
            targetNode?.displayName ??
            NodeDisplayNameResolver.defaultName(log.targetNode);
        if (targetName.toLowerCase().contains(query)) return true;
        if (log.targetNode.toString().contains(query)) return true;

        // Search hop node names
        for (final hop in log.hops) {
          final hopNode = nodes[hop.nodeNum];
          final hopName =
              hopNode?.displayName ??
              NodeDisplayNameResolver.defaultName(hop.nodeNum);
          if (hopName.toLowerCase().contains(query)) return true;
        }
        return false;
      }).toList();
    }

    // Sort newest first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = widget.nodeNum != null
        ? ref.watch(nodeTraceRouteLogsProvider(widget.nodeNum!))
        : ref.watch(traceRouteLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = widget.nodeNum != null ? nodes[widget.nodeNum] : null;
    final nodeName = node?.displayName;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: HelpTourController(
        topicId: 'traceroute_overview',
        stepKeys: const {},
        child: GlassScaffold(
          titleWidget: widget.nodeNum != null && nodeName != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Traceroute History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Text(
                      nodeName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                )
              : null,
          title: widget.nodeNum == null || nodeName == null
              ? 'Traceroute History'
              : null,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More actions',
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportCsv();
                  case 'clear':
                    _confirmClearData();
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour('traceroute_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  enabled: !_isExporting,
                  child: Row(
                    children: [
                      Icon(
                        _isExporting ? Icons.hourglass_top : Icons.ios_share,
                        size: 20,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Clear Data',
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('Help'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          slivers: [
            // Top padding to push content below the glass app bar
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Pinned search and filter controls
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
                  _countForFilter(logsAsync, _TracerouteFilter.all),
                  _countForFilter(logsAsync, _TracerouteFilter.responded),
                  _countForFilter(logsAsync, _TracerouteFilter.noResponse),
                ]),
                filterChips: [
                  SectionFilterChip(
                    label: 'All',
                    count: _countForFilter(logsAsync, _TracerouteFilter.all),
                    isSelected: _activeFilter == _TracerouteFilter.all,
                    onTap: () => safeSetState(
                      () => _activeFilter = _TracerouteFilter.all,
                    ),
                  ),
                  SectionFilterChip(
                    label: 'Response',
                    count: _countForFilter(
                      logsAsync,
                      _TracerouteFilter.responded,
                    ),
                    isSelected: _activeFilter == _TracerouteFilter.responded,
                    color: AccentColors.green,
                    icon: Icons.check_circle_outline,
                    onTap: () => safeSetState(
                      () => _activeFilter = _TracerouteFilter.responded,
                    ),
                  ),
                  SectionFilterChip(
                    label: 'No Response',
                    count: _countForFilter(
                      logsAsync,
                      _TracerouteFilter.noResponse,
                    ),
                    isSelected: _activeFilter == _TracerouteFilter.noResponse,
                    color: AppTheme.errorRed,
                    icon: Icons.cancel_outlined,
                    onTap: () => safeSetState(
                      () => _activeFilter = _TracerouteFilter.noResponse,
                    ),
                  ),
                ],
              ),
            ),
            logsAsync.when(
              data: (logs) {
                final filtered = _applyFilters(logs);

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: _buildEmptyState(
                        context,
                        logs.isEmpty
                            ? 'No traceroutes recorded yet'
                            : 'No traceroutes match filters',
                        showClearFilters: logs.isNotEmpty,
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _TraceRouteCard(
                        log: filtered[index],
                        allNodes: nodes,
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () =>
                  const SliverFillRemaining(child: ScreenLoadingIndicator()),
              error: (e, _) =>
                  SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  int _countForFilter(
    AsyncValue<List<TraceRouteLog>> logsAsync,
    _TracerouteFilter filter,
  ) {
    return logsAsync.maybeWhen(
      data: (logs) {
        switch (filter) {
          case _TracerouteFilter.all:
            return logs.length;
          case _TracerouteFilter.responded:
            return logs.where((l) => l.response).length;
          case _TracerouteFilter.noResponse:
            return logs.where((l) => !l.response).length;
        }
      },
      orElse: () => 0,
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String message, {
    bool showClearFilters = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.route_outlined,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: context.titleSmallStyle?.copyWith(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Send a traceroute from a node to see network paths',
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          if (showClearFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                safeSetState(() {
                  _activeFilter = _TracerouteFilter.all;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Clear all filters'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    safeSetState(() => _isExporting = true);

    try {
      final List<TraceRouteLog> logs;
      if (widget.nodeNum != null) {
        logs = await ref.read(
          nodeTraceRouteLogsProvider(widget.nodeNum!).future,
        );
      } else {
        logs = await ref.read(traceRouteLogsProvider.future);
      }

      if (!mounted) return;

      if (logs.isEmpty) {
        showInfoSnackBar(context, 'No traceroute data to export');
        return;
      }

      final nodes = ref.read(nodesProvider);
      final buffer = StringBuffer();
      buffer.writeln(
        'timestamp,target_node,target_name,response,hops_forward,hops_back,snr_db,forward_route,forward_snr,return_route,return_snr',
      );

      for (final log in logs) {
        final targetNode = nodes[log.targetNode];
        final targetName =
            targetNode?.displayName ??
            NodeDisplayNameResolver.defaultName(log.targetNode);

        final forwardHops = log.hops.where((h) => !h.back).toList();
        final returnHops = log.hops.where((h) => h.back).toList();

        final forwardRoute = forwardHops
            .map((h) {
              final n = nodes[h.nodeNum];
              return n?.displayName ??
                  NodeDisplayNameResolver.defaultName(h.nodeNum);
            })
            .join(' > ');
        final forwardSnr = forwardHops
            .map((h) => h.snr?.toStringAsFixed(1) ?? 'N/A')
            .join(',');

        final returnRoute = returnHops
            .map((h) {
              final n = nodes[h.nodeNum];
              return n?.displayName ??
                  NodeDisplayNameResolver.defaultName(h.nodeNum);
            })
            .join(' > ');
        final returnSnr = returnHops
            .map((h) => h.snr?.toStringAsFixed(1) ?? 'N/A')
            .join(',');

        buffer.writeln(
          '${log.timestamp.toIso8601String()},'
          '${log.targetNode},'
          '"$targetName",'
          '${log.response},'
          '${log.hopsTowards},'
          '${log.hopsBack},'
          '${log.snr?.toStringAsFixed(1) ?? ""},'
          '"$forwardRoute","$forwardSnr",'
          '"$returnRoute","$returnSnr"',
        );
      }

      if (!mounted) return;

      final scope = widget.nodeNum != null ? 'Node' : 'All';
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'traceroute_export_$timestamp.csv';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;

      await shareFiles(
        [XFile(file.path)],
        subject: 'Socialmesh Traceroute Export ($scope)',
        context: context,
      );

      if (!mounted) return;
      showSuccessSnackBar(context, 'Exported ${logs.length} traceroutes');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Export failed: $e');
    } finally {
      if (mounted) {
        safeSetState(() => _isExporting = false);
      }
    }
  }

  Future<void> _confirmClearData() async {
    final scope = widget.nodeNum != null ? 'this node' : 'all nodes';
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Clear Traceroute Data',
      message:
          'This will permanently delete all traceroute history for $scope. This cannot be undone.',
      confirmLabel: 'Clear',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = await ref.read(tracerouteRepositoryProvider.future);
      if (widget.nodeNum != null) {
        await repo.deleteRunsForNode(widget.nodeNum!);
        ref.invalidate(nodeTraceRouteLogsProvider(widget.nodeNum!));
      } else {
        await repo.deleteAllRuns();
        ref.invalidate(traceRouteLogsProvider);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Traceroute data cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to clear data: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Traceroute card
// ---------------------------------------------------------------------------

class _TraceRouteCard extends StatelessWidget {
  final TraceRouteLog log;
  final Map<int, dynamic> allNodes;

  const _TraceRouteCard({required this.log, required this.allNodes});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');
    final destNode = allNodes[log.targetNode];
    final destName =
        destNode?.displayName ??
        NodeDisplayNameResolver.defaultName(log.targetNode);

    final forwardHops = log.hops.where((h) => !h.back).toList();
    final returnHops = log.hops.where((h) => h.back).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: timestamp + response badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeFormat.format(log.timestamp),
                style: context.bodySmallStyle?.copyWith(
                  color: context.textTertiary,
                ),
              ),
              _ResponseBadge(gotResponse: log.response),
            ],
          ),
          const SizedBox(height: 12),

          // Destination
          Row(
            children: [
              const Icon(
                Icons.arrow_forward,
                size: 18,
                color: AccentColors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To',
                      style: context.captionStyle?.copyWith(color: Colors.grey),
                    ),
                    Text(
                      destName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Overall SNR (packet-level)
          if (log.response && log.snr != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.sensors,
                    size: 16,
                    color: AccentColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SNR: ${log.snr!.toStringAsFixed(1)} dB',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AccentColors.green,
                    ),
                  ),
                ],
              ),
            ),

          // Hop counts
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _HopCountChip(
                label: 'Hops \u2192',
                count: log.hopsTowards,
                color: AccentColors.teal,
              ),
              _HopCountChip(
                label: 'Hops \u2190',
                count: log.hopsBack,
                color: AccentColors.purple,
              ),
            ],
          ),

          // Forward route path
          if (forwardHops.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            _RoutePathSection(
              title: 'Forward Path',
              icon: Icons.arrow_forward,
              color: AccentColors.teal,
              hops: forwardHops,
              allNodes: allNodes,
            ),
          ],

          // Return route path
          if (returnHops.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            _RoutePathSection(
              title: 'Return Path',
              icon: Icons.arrow_back,
              color: AccentColors.purple,
              hops: returnHops,
              allNodes: allNodes,
            ),
          ],

          // No hops hint for responses with zero hops (direct connection)
          if (log.response &&
              forwardHops.isEmpty &&
              returnHops.isEmpty &&
              log.hopsTowards == 0 &&
              log.hopsBack == 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: context.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Direct connection — no intermediate hops',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route path section (forward or return)
// ---------------------------------------------------------------------------

class _RoutePathSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<TraceRouteHop> hops;
  final Map<int, dynamic> allNodes;

  const _RoutePathSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.hops,
    required this.allNodes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...hops.asMap().entries.map((entry) {
          final index = entry.key;
          final hop = entry.value;
          final hopNode = allNodes[hop.nodeNum];
          final hopName =
              hopNode?.displayName ??
              NodeDisplayNameResolver.defaultName(hop.nodeNum);
          final isLast = index == hops.length - 1;

          return _HopItem(
            index: index + 1,
            name: hopName,
            snr: hop.snr,
            isLast: isLast,
            color: color,
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Response badge
// ---------------------------------------------------------------------------

class _ResponseBadge extends StatelessWidget {
  final bool gotResponse;

  const _ResponseBadge({required this.gotResponse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gotResponse
            ? AccentColors.green.withValues(alpha: 0.2)
            : AppTheme.errorRed.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gotResponse ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: gotResponse ? AccentColors.green : AppTheme.errorRed,
          ),
          const SizedBox(width: 4),
          Text(
            gotResponse ? 'Response' : 'No Response',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: gotResponse ? AccentColors.green : AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hop count chip
// ---------------------------------------------------------------------------

class _HopCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _HopCountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual hop item in the route path
// ---------------------------------------------------------------------------

class _HopItem extends StatelessWidget {
  final int index;
  final String name;
  final double? snr;
  final bool isLast;
  final Color color;

  const _HopItem({
    required this.index,
    required this.name,
    this.snr,
    this.isLast = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 16,
                  color: color.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (snr != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${snr!.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
