// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — GestureDetector is for keyboard dismissal, not user interaction

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../providers/countdown_providers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import 'package:flutter/services.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../map/map_screen.dart';
import '../nodes/node_display_name_resolver.dart';

/// Filter options for traceroute logs
enum _TracerouteFilter { all, responded, noResponse }

/// Screen showing traceroute history with hop visualization and filtering
class TraceRouteLogScreen extends ConsumerStatefulWidget {
  final int? nodeNum;

  const TraceRouteLogScreen({super.key, this.nodeNum});

  /// Canonical route name so we can detect "already showing history" and avoid
  /// pushing a nested duplicate.
  static const String routeName = 'traceroute-history';

  /// Opens the history view, unless one is already on top of the navigation
  /// stack — in which case it's a no-op. Prevents nested duplicate history
  /// views when "View" is tapped repeatedly from traceroute notifications.
  ///
  /// All callers must route through here (rather than pushing the screen
  /// directly) so the route name is set consistently; the guard only works
  /// when the screen the user is currently on was itself opened this way.
  static void open(BuildContext context, {int? nodeNum}) {
    final navigator = Navigator.of(context);
    var alreadyOnHistory = false;
    navigator.popUntil((route) {
      alreadyOnHistory = route.settings.name == routeName;
      return true; // predicate true on the top route ⇒ never actually pops
    });
    if (alreadyOnHistory) return;
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => TraceRouteLogScreen(nodeNum: nodeNum),
      ),
    );
  }

  @override
  ConsumerState<TraceRouteLogScreen> createState() =>
      _TraceRouteLogScreenState();
}

class _TraceRouteLogScreenState extends ConsumerState<TraceRouteLogScreen>
    with LifecycleSafeMixin<TraceRouteLogScreen> {
  String _searchQuery = '';
  _TracerouteFilter _activeFilter = _TracerouteFilter.all;
  bool _isExporting = false;
  bool _isSendingTraceroute = false;
  final TextEditingController _searchController = TextEditingController();

  // Optional per-node filter: seeded from widget.nodeNum, clearable so the user
  // can broaden from a single node to all nodes via the chip's close icon.
  int? _filterNodeNum;

  @override
  void initState() {
    super.initState();
    _filterNodeNum = widget.nodeNum;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendTraceroute() async {
    final nodeNum = _filterNodeNum;
    if (nodeNum == null) return;

    final cooldownRemaining = ref
        .read(countdownProvider.notifier)
        .globalTracerouteRemaining;
    if (_isSendingTraceroute || cooldownRemaining > 0) return;

    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.nodeDetailTracerouteNotConnected);
      return;
    }

    safeSetState(() => _isSendingTraceroute = true);

    final protocol = ref.read(protocolServiceProvider);
    final nodes = ref.read(nodesProvider);
    final displayName =
        nodes[nodeNum]?.displayName ??
        NodeDisplayNameResolver.defaultName(nodeNum);

    try {
      await protocol.sendTraceroute(nodeNum);

      if (!mounted) return;

      safeSetState(() => _isSendingTraceroute = false);

      ref.read(countdownProvider.notifier).startTracerouteCountdown(nodeNum);

      if (context.mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.nodeDetailTracerouteSent(displayName),
        );
      }
    } catch (e) {
      safeSetState(() => _isSendingTraceroute = false);
      if (context.mounted) {
        // Readiness gate (Step 6c).
        if (maybeShowTxBlockedSnackBar(context, e)) {
          return;
        }
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailTracerouteError(e.toString()),
        );
      }
    }
  }

  Widget _buildTracerouteAppBarAction(
    BuildContext context,
    int cooldownRemaining,
    int cooldownTotal,
  ) {
    if (_isSendingTraceroute) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.accentColor,
          ),
        ),
      );
    }
    if (cooldownRemaining > 0) {
      return Tooltip(
        message: context.l10n.nodeDetailTracerouteCooldownTooltip(
          cooldownRemaining,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: cooldownTotal > 0
                        ? cooldownRemaining / cooldownTotal
                        : 0,
                    strokeWidth: 2,
                    color: context.accentColor.withValues(alpha: 0.4),
                    backgroundColor: context.textTertiary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                Text(
                  '$cooldownRemaining',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: _sendTraceroute,
      icon: const Icon(Icons.route),
      tooltip: context.l10n.nodeDetailTracerouteTooltip,
    );
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
    final logsAsync = _filterNodeNum != null
        ? ref.watch(nodeTraceRouteLogsProvider(_filterNodeNum!))
        : ref.watch(traceRouteLogsProvider);
    final cooldownTask = _filterNodeNum != null
        ? ref.watch(activeTracerouteProvider)
        : null;
    final cooldownRemaining = cooldownTask?.remainingSeconds ?? 0;
    final cooldownTotal =
        cooldownTask?.totalSeconds ??
        CountdownNotifier.tracerouteCooldownSeconds;
    final nodes = ref.watch(nodesProvider);
    final node = _filterNodeNum != null ? nodes[_filterNodeNum] : null;
    final nodeName = node?.displayName;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: HelpTourController(
        topicId: 'traceroute_overview',
        stepKeys: const {},
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          titleWidget: _filterNodeNum != null && nodeName != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.telemetryTracerouteTitle,
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
          title: _filterNodeNum == null || nodeName == null
              ? context.l10n.telemetryTracerouteTitle
              : null,
          actions: [
            if (_filterNodeNum != null)
              _buildTracerouteAppBarAction(
                context,
                cooldownRemaining,
                cooldownTotal,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: context.l10n.telemetryTracerouteMoreActions,
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
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        _isExporting
                            ? context.l10n.telemetryExporting
                            : context.l10n.telemetryExportCsv,
                      ),
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
                      const SizedBox(width: AppTheme.spacing12),
                      Text(
                        context.l10n.telemetryClearData,
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(context.l10n.telemetryHelp),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          slivers: [
            // Top padding to push content below the glass app bar
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTheme.spacing8),
            ),
            // Pinned search and filter controls
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    safeSetState(() => _searchQuery = value),
                hintText: context.l10n.telemetrySearchByNodeName,
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _activeFilter,
                  _countForFilter(logsAsync, _TracerouteFilter.all),
                  _countForFilter(logsAsync, _TracerouteFilter.responded),
                  _countForFilter(logsAsync, _TracerouteFilter.noResponse),
                ]),
                filterChips: [
                  StatusFilterChip(
                    label: context.l10n.telemetryFilterAll,
                    count: _countForFilter(logsAsync, _TracerouteFilter.all),
                    isSelected: _activeFilter == _TracerouteFilter.all,
                    onTap: () => safeSetState(
                      () => _activeFilter = _TracerouteFilter.all,
                    ),
                  ),
                  StatusFilterChip(
                    label: context.l10n.telemetryTracerouteFilterResponse,
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
                  StatusFilterChip(
                    label: context.l10n.telemetryTracerouteFilterNoResponse,
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

            // Node filter indicator (when scoped to a single node). Tap the
            // close icon to clear the scope and browse all nodes' traceroutes.
            if (_filterNodeNum != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AccentColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(
                        color: AccentColors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_pin_circle,
                          size: 16,
                          color: AccentColors.purple,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: Text(
                            nodes[_filterNodeNum]?.displayName ??
                                NodeDisplayNameResolver.defaultName(
                                  _filterNodeNum!,
                                ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AccentColors.purple,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            safeSetState(() => _filterNodeNum = null);
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: AccentColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            ? context.l10n.telemetryTracerouteNoData
                            : context.l10n.telemetryTracerouteNoMatch,
                        showClearFilters: logs.isNotEmpty,
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _TraceRouteCard(
                        log: filtered[index],
                        allNodes: nodes,
                        myNodeNum: ref.watch(myNodeNumProvider),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () =>
                  const SliverFillRemaining(child: ScreenLoadingIndicator()),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text(context.l10n.telemetryError(e.toString())),
                ),
              ),
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
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: Icon(
              Icons.route_outlined,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            message,
            style: context.titleSmallStyle?.copyWith(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.telemetryTracerouteEmptyHint,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          if (showClearFilters) ...[
            const SizedBox(height: AppTheme.spacing16),
            TextButton.icon(
              onPressed: () {
                safeSetState(() {
                  _activeFilter = _TracerouteFilter.all;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: Text(context.l10n.telemetryClearAllFilters),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final l10n = context.l10n;
    safeSetState(() => _isExporting = true);

    try {
      final List<TraceRouteLog> logs;
      if (_filterNodeNum != null) {
        logs = await ref.read(
          nodeTraceRouteLogsProvider(_filterNodeNum!).future,
        );
      } else {
        logs = await ref.read(traceRouteLogsProvider.future);
      }

      if (!mounted) return;

      if (logs.isEmpty) {
        showInfoSnackBar(context, l10n.telemetryTracerouteNoExportData);
        return;
      }

      final nodes = ref.read(nodesProvider);
      final buffer = StringBuffer();
      buffer.writeln(
        'timestamp,target_node,target_name,response,hops_forward,hops_back,snr_db,forward_route,forward_snr,return_route,return_snr', // lint-allow: hardcoded-string
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
            .map(
              (h) => h.snr?.toStringAsFixed(1) ?? 'N/A',
            ) // lint-allow: hardcoded-string
            .join(',');

        final returnRoute = returnHops
            .map((h) {
              final n = nodes[h.nodeNum];
              return n?.displayName ??
                  NodeDisplayNameResolver.defaultName(h.nodeNum);
            })
            .join(' > ');
        final returnSnr = returnHops
            .map(
              (h) => h.snr?.toStringAsFixed(1) ?? 'N/A',
            ) // lint-allow: hardcoded-string
            .join(',');

        buffer.writeln(
          '${log.timestamp.toIso8601String()},'
          '${log.targetNode},'
          '"$targetName",' // lint-allow: hardcoded-string
          '${log.response},'
          '${log.hopsTowards},'
          '${log.hopsBack},'
          '${log.snr?.toStringAsFixed(1) ?? ""},'
          '"$forwardRoute","$forwardSnr",' // lint-allow: hardcoded-string
          '"$returnRoute","$returnSnr"', // lint-allow: hardcoded-string
        );
      }

      if (!mounted) return;

      final scope = _filterNodeNum != null ? 'Node' : 'All';
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
        subject: l10n.telemetryTracerouteExportSubject(scope),
        context: context,
      );

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        l10n.telemetryTracerouteExportedCount(logs.length),
      );
    } catch (e) {
      showErrorSnackBar(context, l10n.telemetryExportFailed(e.toString()));
    } finally {
      if (mounted) {
        safeSetState(() => _isExporting = false);
      }
    }
  }

  Future<void> _confirmClearData() async {
    final l10n = context.l10n;
    final scope = _filterNodeNum != null
        ? 'this node'
        : 'all nodes'; // lint-allow: hardcoded-string

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.telemetryTracerouteClearTitle,
      message: l10n.telemetryTracerouteClearMessage(scope),
      confirmLabel: l10n.telemetryTracerouteClearLabel,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = await ref.read(tracerouteRepositoryProvider.future);
      if (_filterNodeNum != null) {
        await repo.deleteRunsForNode(_filterNodeNum!);
        ref.invalidate(nodeTraceRouteLogsProvider(_filterNodeNum!));
      } else {
        await repo.deleteAllRuns();
        ref.invalidate(traceRouteLogsProvider);
      }

      if (!mounted) return;
      safeShowSnackBar(
        l10n.telemetryTracerouteCleared,
        type: SnackBarType.success,
      );
    } catch (e) {
      showErrorSnackBar(context, l10n.telemetryFailedToClear(e.toString()));
    }
  }
}

// ---------------------------------------------------------------------------
// Traceroute card
// ---------------------------------------------------------------------------

/// Whether a traceroute has enough GPS data to render on a map.
///
/// True when any intermediate hop has coordinates, or when the target
/// node has a known position (covers direct connections with 0 hops).
bool _hasMapData(TraceRouteLog log, Map<int, dynamic> allNodes) {
  // Check intermediate hops
  for (final h in log.hops) {
    if (h.latitude != null &&
        h.longitude != null &&
        !(h.latitude == 0.0 && h.longitude == 0.0)) {
      return true;
    }
  }
  // Check stored target position from traceroute time
  if (log.targetLatitude != null &&
      log.targetLongitude != null &&
      !(log.targetLatitude == 0.0 && log.targetLongitude == 0.0)) {
    return true;
  }
  // Check target node position (covers direct connections)
  final target = allNodes[log.targetNode];
  if (target != null && target.hasPosition == true) return true;
  return false;
}

class _TraceRouteCard extends StatelessWidget {
  final TraceRouteLog log;
  final Map<int, dynamic> allNodes;
  final int? myNodeNum;

  const _TraceRouteCard({
    required this.log,
    required this.allNodes,
    required this.myNodeNum,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = AppTimeFormat.dateAndTime(context);
    final destNode = allNodes[log.targetNode];
    final destName =
        destNode?.displayName ??
        NodeDisplayNameResolver.defaultName(log.targetNode);

    final forwardHops = log.hops.where((h) => !h.back).toList();
    final returnHops = log.hops.where((h) => h.back).toList();

    // Resolve our local node's display name for the return-path
    // terminus. Falls back to a localised "You" label when the node
    // table doesn't yet have an entry for the local device.
    final myNode = myNodeNum != null ? allNodes[myNodeNum] : null;
    final myName =
        myNode?.displayName ?? context.l10n.telemetryTracerouteYouLabel;

    // Endpoint SNR rows. Meshtastic's RouteDiscovery appends one
    // extra SNR entry beyond the intermediate-hop list in each
    // direction (target's reception of the query, origin's
    // reception of the reply). Render them as terminal hops so the
    // user can see every per-link SNR including the endpoints.
    final forwardTerminal = log.targetSnrTowards != null
        ? TraceRouteHop(
            nodeNum: log.targetNode,
            name: destName,
            snr: log.targetSnrTowards,
          )
        : null;
    final returnTerminal = log.originSnrBack != null
        ? TraceRouteHop(
            nodeNum: myNodeNum ?? 0,
            name: myName,
            snr: log.originSnrBack,
            back: true,
          )
        : null;

    final hasAnyForward = forwardHops.isNotEmpty || forwardTerminal != null;
    final hasAnyReturn = returnHops.isNotEmpty || returnTerminal != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          const SizedBox(height: AppTheme.spacing12),

          // Destination
          Row(
            children: [
              const Icon(
                Icons.arrow_forward,
                size: 18,
                color: AccentColors.blue,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.telemetryTracerouteTo,
                      style: context.captionStyle?.copyWith(
                        color: SemanticColors.disabled,
                      ),
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

          const SizedBox(height: AppTheme.spacing8),

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
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    'SNR: ${log.snr!.toStringAsFixed(1)} dB', // lint-allow: hardcoded-string
                    style: const TextStyle(
                      fontSize: 13,
                      color: AccentColors.green,
                    ),
                  ),
                ],
              ),
            ),

          // Hop counts (only meaningful when the target responded).
          // Failed traceroutes report 0/0 here; rendering "0 hops" chips
          // makes the card read like a successful direct connection. So
          // suppress the chips and show an explicit failure status row.
          if (log.response)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _HopCountChip(
                  label: context.l10n.telemetryTracerouteHopsForward,
                  count: log.hopsTowards,
                  color: AccentColors.teal,
                ),
                _HopCountChip(
                  label: context.l10n.telemetryTracerouteHopsBack,
                  count: log.hopsBack,
                  color: AccentColors.purple,
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppTheme.errorRed),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.telemetryTracerouteNoResponse,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ),

          // Forward route path
          if (hasAnyForward) ...[
            const SizedBox(height: AppTheme.spacing12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: AppTheme.spacing12),
            _RoutePathSection(
              title: context.l10n.telemetryTracerouteForwardPath,
              icon: Icons.arrow_forward,
              color: AccentColors.teal,
              hops: forwardHops,
              allNodes: allNodes,
              terminusHop: forwardTerminal,
              terminusIcon: Icons.flag,
            ),
          ],

          // Return route path
          if (hasAnyReturn) ...[
            const SizedBox(height: AppTheme.spacing12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: AppTheme.spacing12),
            _RoutePathSection(
              title: context.l10n.telemetryTracerouteReturnPath,
              icon: Icons.arrow_back,
              color: AccentColors.purple,
              hops: returnHops,
              allNodes: allNodes,
              terminusHop: returnTerminal,
              terminusIcon: Icons.smartphone,
            ),
          ],

          // No hops hint for responses with zero hops (direct connection)
          if (log.response &&
              !hasAnyForward &&
              !hasAnyReturn &&
              log.hopsTowards == 0 &&
              log.hopsBack == 0) ...[
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: Text(
                    context.l10n.telemetryTracerouteDirectConnection,
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

          // Show on Map button — visible for direct connections too
          if (log.response && _hasMapData(log, allNodes)) ...[
            const SizedBox(height: AppTheme.spacing12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: AppTheme.spacing8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MapScreen(tracerouteLog: log),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text(context.l10n.tracerouteShowOnMap),
              ),
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
  // Optional endpoint row appended after the numbered intermediates.
  // Renders with [terminusIcon] in the chip instead of a position
  // number so the user can tell the target / local-device apart from
  // an intermediate relay at a glance.
  final TraceRouteHop? terminusHop;
  final IconData? terminusIcon;

  const _RoutePathSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.hops,
    required this.allNodes,
    this.terminusHop,
    this.terminusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasTerminus = terminusHop != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppTheme.spacing6),
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
        const SizedBox(height: AppTheme.spacing8),
        ...hops.asMap().entries.map((entry) {
          final index = entry.key;
          final hop = entry.value;
          final hopNode = allNodes[hop.nodeNum];
          final hopName =
              hop.name ??
              hopNode?.displayName ??
              NodeDisplayNameResolver.defaultName(hop.nodeNum);
          final isLast = index == hops.length - 1 && !hasTerminus;

          return _HopItem(
            index: index + 1,
            name: hopName,
            snr: hop.snr,
            isLast: isLast,
            color: color,
          );
        }),
        if (hasTerminus)
          _HopItem(
            terminusIcon: terminusIcon ?? Icons.flag,
            name:
                terminusHop!.name ??
                allNodes[terminusHop!.nodeNum]?.displayName ??
                NodeDisplayNameResolver.defaultName(terminusHop!.nodeNum),
            snr: terminusHop!.snr,
            isLast: true,
            color: color,
          ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gotResponse ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: gotResponse ? AccentColors.green : AppTheme.errorRed,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            gotResponse
                ? context.l10n.telemetryTracerouteResponseBadge
                : context.l10n.telemetryTracerouteNoResponseBadge,
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
        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
  final int? index;
  final IconData? terminusIcon;
  final String name;
  final double? snr;
  final bool isLast;
  final Color color;

  const _HopItem({
    this.index,
    this.terminusIcon,
    required this.name,
    this.snr,
    this.isLast = false,
    required this.color,
  }) : assert(
         index != null || terminusIcon != null,
         'Either index or terminusIcon must be provided',
       );

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
                  child: terminusIcon != null
                      ? Icon(terminusIcon, size: 14, color: color)
                      : Text(
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
          const SizedBox(width: AppTheme.spacing12),
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
                        context.l10n.telemetryTracerouteHopSnrHeard(
                          snr!.toStringAsFixed(1),
                        ),
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
