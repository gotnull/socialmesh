// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../providers/mrrp_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_types.dart';
import 'mrrp_budget_panel_screen.dart';
import 'widgets/mrrp_event_tile.dart';

/// Traffic Console — chronological event stream of all MRRP activity.
class MrrpTrafficConsoleScreen extends ConsumerStatefulWidget {
  const MrrpTrafficConsoleScreen({super.key});

  @override
  ConsumerState<MrrpTrafficConsoleScreen> createState() =>
      _MrrpTrafficConsoleScreenState();
}

class _MrrpTrafficConsoleScreenState
    extends ConsumerState<MrrpTrafficConsoleScreen> {
  int? _filterPeerId;
  MrrpMessageType? _filterType;
  int? _filterServiceId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allEvents = ref.watch(mrrpTrafficEventsProvider);

    // Apply filters.
    final events = allEvents.where((e) {
      if (_filterPeerId != null && e.peerNodeId != _filterPeerId) {
        return false;
      }
      if (_filterType != null && e.msgType != _filterType) return false;
      if (_filterServiceId != null && e.serviceId != _filterServiceId) {
        return false;
      }
      return true;
    }).toList();

    final isEmpty = events.isEmpty;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessTrafficTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: l10n.mrrpHarnessBudgetTitle,
            onPressed: () {
              ref.read(hapticServiceProvider).trigger(HapticType.light);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MrrpBudgetPanelScreen(),
                ),
              );
            },
          ),
        ],
        slivers: [
          // Filter bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing8,
              ),
              child: Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing4,
                children: [
                  StatusFilterChip(
                    label: _filterType != null
                        ? _filterType!.name
                        : l10n.mrrpHarnessTrafficFilterType,
                    icon: Icons.swap_vert,
                    isSelected: _filterType != null,
                    onTap: _cycleTypeFilter,
                  ),
                  StatusFilterChip(
                    label: _filterPeerId != null
                        ? '0x${_filterPeerId!.toRadixString(16).padLeft(8, '0').toUpperCase()}'
                        : l10n.mrrpHarnessTrafficFilterPeer,
                    icon: Icons.person_outline,
                    isSelected: _filterPeerId != null,
                    onTap: () => setState(() => _filterPeerId = null),
                  ),
                  StatusFilterChip(
                    label: _filterServiceId != null
                        ? MrrpServiceId.nameOf(_filterServiceId!)
                        : l10n.mrrpHarnessTrafficFilterService,
                    icon: Icons.extension_outlined,
                    isSelected: _filterServiceId != null,
                    onTap: () => setState(() => _filterServiceId = null),
                  ),
                ],
              ),
            ),
          ),

          // Events or empty state
          if (isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monitor_heart_outlined,
                        size: 64,
                        color: context.textTertiary,
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        l10n.mrrpHarnessTrafficEmpty,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        l10n.mrrpHarnessTrafficEmptyDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                    child: MrrpEventTile(event: events[index]),
                  ),
                  childCount: events.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _cycleTypeFilter() {
    setState(() {
      if (_filterType == null) {
        _filterType = MrrpMessageType.request;
      } else if (_filterType == MrrpMessageType.request) {
        _filterType = MrrpMessageType.response;
      } else if (_filterType == MrrpMessageType.response) {
        _filterType = MrrpMessageType.error;
      } else {
        _filterType = null;
      }
    });
  }
}
