// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/mrrp_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/protocol/sip/mrrp_counters.dart';
import '../../services/protocol/sip/mrrp_types.dart';

/// Budget & Timing Panel — rate limiter state and protocol metrics.
class MrrpBudgetPanelScreen extends ConsumerWidget {
  const MrrpBudgetPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rateLimiter = ref.watch(sipRateLimiterProvider);
    ref.watch(mrrpCountersEpochProvider);
    final counters = ref.watch(mrrpCountersProvider);

    return GlassScaffold(
      title: l10n.mrrpHarnessBudgetTitle,
      slivers: [
        // --- Budget section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(title: l10n.mrrpHarnessBudget),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Budget gauge
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing12,
                ),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: 1.0 - rateLimiter.usageFraction,
                      backgroundColor: context.surface,
                      color: rateLimiter.isBudgetHigh
                          ? SemanticColors.error
                          : SemanticColors.success,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      l10n.mrrpHarnessBudgetValue(
                        rateLimiter.remainingBytes,
                        rateLimiter.capacity,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CounterRow(
                label: l10n.mrrpHarnessBudgetBlocked,
                value: '${counters.budgetThrottles}',
              ),
            ]),
          ),
        ),

        // --- Traffic counters section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessCountersSectionTraffic,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CounterRow(
                label: l10n.mrrpHarnessCountersReqSent,
                value: '${counters.requestsSent}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersReqRecv,
                value: '${counters.requestsReceived}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersRespSent,
                value: '${counters.responsesSent}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersRespRecv,
                value: '${counters.responsesReceived}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersDirReqSent,
                value: '${counters.serviceDirRequestsSent}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersDirReqRecv,
                value: '${counters.serviceDirRequestsReceived}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersDirRespSent,
                value: '${counters.serviceDirResponsesSent}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersDirRespRecv,
                value: '${counters.serviceDirResponsesReceived}',
              ),
            ]),
          ),
        ),

        // --- Advert cadence section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessBudgetAdvertCadence,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CounterRow(
                label: 'TX', // lint-allow: hardcoded-string
                value: '${counters.serviceAdvertsSent}',
              ),
              _CounterRow(
                label: 'RX', // lint-allow: hardcoded-string
                value: '${counters.serviceAdvertsReceived}',
              ),
              if (counters.lastAdvertSent != null)
                _CounterRow(
                  label: 'Last TX', // lint-allow: hardcoded-string
                  value: _formatTime(counters.lastAdvertSent!),
                ),
              if (counters.lastAdvertReceived != null)
                _CounterRow(
                  label: 'Last RX', // lint-allow: hardcoded-string
                  value: _formatTime(counters.lastAdvertReceived!),
                ),
            ]),
          ),
        ),

        // --- Dedup & Cache section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessCountersSectionDedup,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CounterRow(
                label: l10n.mrrpHarnessCountersDupReq,
                value: '${counters.duplicateRequestsIgnored}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersDupResp,
                value: '${counters.duplicateResponsesIgnored}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersCachedResp,
                value: '${counters.cachedResponsesServed}',
              ),
            ]),
          ),
        ),

        // --- Errors & Rejections section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessCountersSectionErrors,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CounterRow(
                label: l10n.mrrpHarnessCountersErrSent,
                value: '${counters.errorsSent}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersErrRecv,
                value: '${counters.errorsReceived}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersReqTimeouts,
                value: '${counters.requestTimeouts}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersRespTimeouts,
                value: '${counters.responseTimeouts}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersCancellations,
                value: '${counters.requestCancellations}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersPayloadReject,
                value: '${counters.payloadTooLargeRejections}',
              ),
            ]),
          ),
        ),

        // --- Harness Activity section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessCountersSectionHarness,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CounterRow(
                label: l10n.mrrpHarnessCountersHarnessActions,
                value:
                    '${counters.harnessActionsPerformed.values.fold(0, (a, b) => a + b)}',
              ),
              _CounterRow(
                label: l10n.mrrpHarnessCountersSimFaults,
                value:
                    '${counters.simulatedFaultsInjected.values.fold(0, (a, b) => a + b)}',
              ),
            ]),
          ),
        ),

        // --- Latency section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(title: l10n.mrrpHarnessBudgetLatency),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing8,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _buildLatencyRows(context, counters),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLatencyRows(BuildContext context, MrrpCounters counters) {
    final serviceIds = counters.serviceIdsWithLatency;
    if (serviceIds.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          child: Text(
            'No latency data', // lint-allow: hardcoded-string
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
      ];
    }

    final rows = <Widget>[];
    for (final serviceId in serviceIds) {
      final stats = counters.getLatencyStats(serviceId);
      if (stats == null) continue;

      final name = MrrpServiceId.nameOf(serviceId);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
          child: Material(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  _CounterRow(
                    label: 'min', // lint-allow: hardcoded-string
                    value:
                        '${stats.min.inMilliseconds}ms', // lint-allow: hardcoded-string
                  ),
                  _CounterRow(
                    label: 'max', // lint-allow: hardcoded-string
                    value:
                        '${stats.max.inMilliseconds}ms', // lint-allow: hardcoded-string
                  ),
                  _CounterRow(
                    label: 'avg', // lint-allow: hardcoded-string
                    value:
                        '${stats.average.inMilliseconds}ms', // lint-allow: hardcoded-string
                  ),
                  _CounterRow(
                    label: 'last', // lint-allow: hardcoded-string
                    value:
                        '${stats.last.inMilliseconds}ms', // lint-allow: hardcoded-string
                  ),
                  _CounterRow(
                    label: 'count', // lint-allow: hardcoded-string
                    value: '${stats.count}',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final String value;

  const _CounterRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace', // lint-allow: hardcoded-string
            ),
          ),
        ],
      ),
    );
  }
}
