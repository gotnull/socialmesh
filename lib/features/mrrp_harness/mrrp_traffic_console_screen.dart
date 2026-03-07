// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_types.dart';
import 'mrrp_budget_panel_screen.dart';
import 'widgets/mrrp_event_tile.dart';

/// Maximum events to retain in the traffic console.
const _kMaxEvents = 200;

/// Provider for the traffic event stream (session-scoped).
final mrrpTrafficEventsProvider =
    NotifierProvider<_TrafficEventsNotifier, List<MrrpTrafficEvent>>(
      _TrafficEventsNotifier.new,
    );

class _TrafficEventsNotifier extends Notifier<List<MrrpTrafficEvent>> {
  @override
  List<MrrpTrafficEvent> build() => [];

  void add(MrrpTrafficEvent event) {
    final updated = [event, ...state];
    if (updated.length > _kMaxEvents) {
      state = updated.sublist(0, _kMaxEvents);
    } else {
      state = updated;
    }
  }

  void clear() => state = [];
}

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
                  _FilterChip(
                    label: l10n.mrrpHarnessTrafficFilterType,
                    isActive: _filterType != null,
                    onTap: _cycleTypeFilter,
                    displayValue: _filterType?.name,
                  ),
                  _FilterChip(
                    label: l10n.mrrpHarnessTrafficFilterPeer,
                    isActive: _filterPeerId != null,
                    onTap: () => setState(() => _filterPeerId = null),
                    displayValue: _filterPeerId != null
                        ? '0x${_filterPeerId!.toRadixString(16).padLeft(8, '0').toUpperCase()}'
                        : null,
                  ),
                  _FilterChip(
                    label: l10n.mrrpHarnessTrafficFilterService,
                    isActive: _filterServiceId != null,
                    onTap: () => setState(() => _filterServiceId = null),
                    displayValue: _filterServiceId != null
                        ? MrrpServiceId.nameOf(_filterServiceId!)
                        : null,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? displayValue;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(displayValue ?? label),
      avatar: isActive
          ? Icon(Icons.check, size: 16, color: context.accentColor)
          : null,
      onPressed: onTap,
    );
  }
}
