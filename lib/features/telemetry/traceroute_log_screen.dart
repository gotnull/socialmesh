import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing TraceRoute history with hop visualization
class TraceRouteLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const TraceRouteLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodeTraceRouteLogsProvider(nodeNum!))
        : ref.watch(traceRouteLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? 'All Nodes';

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: const Text(
          'TraceRoute Log',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                nodeName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(
              child: logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return _buildEmptyState('No traceroutes recorded yet');
                  }
                  final sortedLogs = logs.reversed.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedLogs.length,
                    itemBuilder: (context, index) {
                      return _TraceRouteCard(
                        log: sortedLogs[index],
                        allNodes: nodes,
                      );
                    },
                  );
                },
                loading: () => const ScreenLoadingIndicator(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use TraceRoute to see network path',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceRouteCard extends StatelessWidget {
  final TraceRouteLog log;
  final Map<int, dynamic> allNodes;

  const _TraceRouteCard({required this.log, required this.allNodes});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');
    final destNode = allNodes[log.targetNode];
    final destName = destNode?.displayName ?? 'Node ${log.targetNode}';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeFormat.format(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
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
                    const Text(
                      'To',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

          // Round trip info
          if (log.response && log.snr != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
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
          Row(
            children: [
              _HopCountChip(
                label: 'Hops →',
                count: log.hopsTowards,
                color: AccentColors.teal,
              ),
              const SizedBox(width: 12),
              _HopCountChip(
                label: 'Hops ←',
                count: log.hopsBack,
                color: AccentColors.purple,
              ),
            ],
          ),

          // Individual hops
          if (log.hops.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Text(
              'Route Path',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...log.hops.asMap().entries.map((entry) {
              final index = entry.key;
              final hop = entry.value;
              final hopNode = allNodes[hop.nodeNum];
              final hopName = hopNode?.displayName ?? 'Node ${hop.nodeNum}';
              final isLast = index == log.hops.length - 1;

              return _HopItem(
                index: index + 1,
                name: hopName,
                snr: hop.snr,
                isLast: isLast,
              );
            }),
          ],
        ],
      ),
    );
  }
}

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

class _HopItem extends StatelessWidget {
  final int index;
  final String name;
  final double? snr;
  final bool isLast;

  const _HopItem({
    required this.index,
    required this.name,
    this.snr,
    this.isLast = false,
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
                  color: AccentColors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AccentColors.blue,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 16,
                  color: AccentColors.blue.withValues(alpha: 0.3),
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
                  Text(
                    name,
                    style: TextStyle(fontSize: 13, color: context.textPrimary),
                  ),
                  if (snr != null)
                    Text(
                      'SNR: ${snr!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
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
