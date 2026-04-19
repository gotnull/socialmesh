// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _filterPeerId;
  MrrpMessageType? _filterType;
  int? _filterServiceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final peerHex =
            e.peerNodeId?.toRadixString(16).padLeft(8, '0').toLowerCase() ?? '';
        final serviceName = MrrpServiceId.nameOf(
          e.serviceId ?? 0,
        ).toLowerCase();
        final typeName = e.msgType.name.toLowerCase();
        if (!peerHex.contains(query) &&
            !serviceName.contains(query) &&
            !typeName.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    final isEmpty = events.isEmpty;

    // Collect unique peers and services from events for dynamic chips.
    final uniquePeers = <int>{};
    final uniqueServices = <int>{};
    for (final e in allEvents) {
      if (e.peerNodeId != null) uniquePeers.add(e.peerNodeId!);
      if (e.serviceId != null) uniqueServices.add(e.serviceId!);
    }

    final noFiltersActive =
        _filterType == null &&
        _filterPeerId == null &&
        _filterServiceId == null;

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
          // Pinned search + filter header (matches NodeDex/Signals pattern)
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchFilterHeaderDelegate(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              hintText: l10n.mrrpHarnessTrafficSearchHint,
              textScaler: MediaQuery.textScalerOf(context),
              rebuildKey: Object.hashAll([
                _filterType,
                _filterPeerId,
                _filterServiceId,
                allEvents.length,
              ]),
              filterChips: [
                // "All" chip — clears all filters
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterAll,
                  icon: Icons.list,
                  isSelected: noFiltersActive,
                  onTap: () => setState(() {
                    _filterType = null;
                    _filterPeerId = null;
                    _filterServiceId = null;
                  }),
                ),
                // Individual type chips
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterRequest,
                  icon: Icons.arrow_upward,
                  isSelected: _filterType == MrrpMessageType.request,
                  color: AccentColors.teal,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.request
                        ? null
                        : MrrpMessageType.request;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterResponse,
                  icon: Icons.arrow_downward,
                  isSelected: _filterType == MrrpMessageType.response,
                  color: AccentColors.indigo,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.response
                        ? null
                        : MrrpMessageType.response;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterError,
                  icon: Icons.error_outline,
                  isSelected: _filterType == MrrpMessageType.error,
                  color: AccentColors.pink,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.error
                        ? null
                        : MrrpMessageType.error;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterCancel,
                  icon: Icons.cancel_outlined,
                  isSelected: _filterType == MrrpMessageType.cancel,
                  color: AccentColors.orange,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.cancel
                        ? null
                        : MrrpMessageType.cancel;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterAdvert,
                  icon: Icons.campaign_outlined,
                  isSelected: _filterType == MrrpMessageType.serviceAdvert,
                  color: AccentColors.yellow,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.serviceAdvert
                        ? null
                        : MrrpMessageType.serviceAdvert;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterDirReq,
                  icon: Icons.folder_outlined,
                  isSelected: _filterType == MrrpMessageType.serviceDirReq,
                  color: AccentColors.cyan,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.serviceDirReq
                        ? null
                        : MrrpMessageType.serviceDirReq;
                  }),
                ),
                StatusFilterChip(
                  label: l10n.mrrpHarnessTrafficFilterDirResp,
                  icon: Icons.folder_open_outlined,
                  isSelected: _filterType == MrrpMessageType.serviceDirResp,
                  color: AccentColors.purple,
                  onTap: () => setState(() {
                    _filterType = _filterType == MrrpMessageType.serviceDirResp
                        ? null
                        : MrrpMessageType.serviceDirResp;
                  }),
                ),
                // Dynamic peer chips from observed events
                for (final peerId in uniquePeers.toList()..sort())
                  StatusFilterChip(
                    label:
                        '0x${peerId.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                    icon: Icons.person_outline,
                    isSelected: _filterPeerId == peerId,
                    color: AccentColors.purple,
                    onTap: () => setState(() {
                      _filterPeerId = _filterPeerId == peerId ? null : peerId;
                    }),
                  ),
                // Dynamic service chips from observed events
                for (final svcId in uniqueServices.toList()..sort())
                  StatusFilterChip(
                    label: MrrpServiceId.nameOf(svcId),
                    icon: Icons.extension_outlined,
                    isSelected: _filterServiceId == svcId,
                    color: AccentColors.blue,
                    onTap: () => setState(() {
                      _filterServiceId = _filterServiceId == svcId
                          ? null
                          : svcId;
                    }),
                  ),
              ],
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
}
