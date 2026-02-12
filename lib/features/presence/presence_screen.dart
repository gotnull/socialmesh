// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../dev/demo/demo_config.dart';

import '../../models/node_encounter.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import '../nodedex/widgets/sigil_painter.dart';

/// Filter options for the Presence screen.
enum PresenceFilter { all, active, fading, inactive, unknown, familiar }

extension PresenceFilterExt on PresenceFilter {
  String get label {
    switch (this) {
      case PresenceFilter.all:
        return 'All';
      case PresenceFilter.active:
        return 'Active';
      case PresenceFilter.fading:
        return 'Seen recently';
      case PresenceFilter.inactive:
        return 'Inactive';
      case PresenceFilter.unknown:
        return 'Unknown';
      case PresenceFilter.familiar:
        return 'Familiar';
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case PresenceFilter.all:
        return AppTheme.primaryBlue;
      case PresenceFilter.active:
        return AppTheme.successGreen;
      case PresenceFilter.fading:
        return AppTheme.warningYellow;
      case PresenceFilter.inactive:
        return context.textSecondary;
      case PresenceFilter.unknown:
        return context.textTertiary;
      case PresenceFilter.familiar:
        return AppTheme.primaryPurple;
    }
  }

  IconData? get icon {
    switch (this) {
      case PresenceFilter.all:
        return null;
      case PresenceFilter.active:
        return null; // Uses status dot via SectionFilterChip
      case PresenceFilter.fading:
        return Icons.circle_outlined;
      case PresenceFilter.inactive:
        return Icons.radio_button_unchecked;
      case PresenceFilter.unknown:
        return Icons.help_outline;
      case PresenceFilter.familiar:
        return Icons.people;
    }
  }

  bool matches(NodePresence presence) {
    switch (this) {
      case PresenceFilter.all:
        return true;
      case PresenceFilter.active:
        return presence.confidence == PresenceConfidence.active;
      case PresenceFilter.fading:
        return presence.confidence == PresenceConfidence.fading;
      case PresenceFilter.inactive:
        return presence.confidence == PresenceConfidence.stale;
      case PresenceFilter.unknown:
        return presence.confidence == PresenceConfidence.unknown;
      case PresenceFilter.familiar:
        return presence.encounter != null && presence.encounter!.isFamiliar;
    }
  }
}

class PresenceScreen extends ConsumerStatefulWidget {
  const PresenceScreen({super.key});

  @override
  ConsumerState<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends ConsumerState<PresenceScreen> {
  PresenceFilter _filter = PresenceFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSectionHeaders = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  List<NodePresence> _applyFilter(List<NodePresence> presences) {
    return presences.where((p) => _filter.matches(p)).toList();
  }

  List<NodePresence> _applySearch(List<NodePresence> presences) {
    if (_searchQuery.isEmpty) return presences;
    final query = _searchQuery.toLowerCase();
    return presences.where((p) {
      return p.node.displayName.toLowerCase().contains(query) ||
          (p.node.userId?.toLowerCase().contains(query) ?? false) ||
          p.node.nodeNum.toString().contains(query) ||
          p.confidence.label.toLowerCase().contains(query) ||
          (p.node.role?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int _countForFilter(PresenceFilter filter, List<NodePresence> allPresences) {
    if (filter == PresenceFilter.all) return allPresences.length;
    return allPresences.where((p) => filter.matches(p)).length;
  }

  List<_PresenceSection> _groupPresencesIntoSections(
    List<NodePresence> presences,
  ) {
    final active = presences
        .where((p) => p.confidence == PresenceConfidence.active)
        .toList();
    final fading = presences
        .where((p) => p.confidence == PresenceConfidence.fading)
        .toList();
    final stale = presences
        .where((p) => p.confidence == PresenceConfidence.stale)
        .toList();
    final unknown = presences
        .where((p) => p.confidence == PresenceConfidence.unknown)
        .toList();

    return [
      _PresenceSection('Active', active, AppTheme.successGreen),
      _PresenceSection('Seen Recently', fading, AppTheme.warningYellow),
      _PresenceSection('Inactive', stale, context.textSecondary),
      _PresenceSection('Unknown', unknown, context.textTertiary),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPresences = ref.watch(presenceListProvider);
    final summary = ref.watch(presenceSummaryProvider);
    final showQuietMeshHint = allPresences.length < 3 || DemoConfig.isEnabled;
    final filtered = _applySearch(_applyFilter(allPresences));

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'presence_overview',
        stepKeys: const {},
        child: GlassScaffold(
          title: 'Presence',
          actions: [IcoHelpAppBarButton(topicId: 'presence_overview')],
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Pinned search + filter chips (consistent with Nodes, NodeDex,
            // Timeline, Bug Reports)
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                hintText: 'Search nodes',
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _filter,
                  _showSectionHeaders,
                  allPresences.length,
                  _countForFilter(PresenceFilter.active, allPresences),
                  _countForFilter(PresenceFilter.fading, allPresences),
                  _countForFilter(PresenceFilter.inactive, allPresences),
                  _countForFilter(PresenceFilter.unknown, allPresences),
                  _countForFilter(PresenceFilter.familiar, allPresences),
                ]),
                filterChips: [
                  SectionFilterChip(
                    label: 'All',
                    count: _countForFilter(PresenceFilter.all, allPresences),
                    isSelected: _filter == PresenceFilter.all,
                    color: PresenceFilter.all.color(context),
                    onTap: () => setState(() => _filter = PresenceFilter.all),
                  ),
                  SectionFilterChip(
                    label: 'Active',
                    count: _countForFilter(PresenceFilter.active, allPresences),
                    isSelected: _filter == PresenceFilter.active,
                    color: PresenceFilter.active.color(context),
                    onTap: () =>
                        setState(() => _filter = PresenceFilter.active),
                  ),
                  SectionFilterChip(
                    label: 'Seen recently',
                    count: _countForFilter(PresenceFilter.fading, allPresences),
                    isSelected: _filter == PresenceFilter.fading,
                    color: PresenceFilter.fading.color(context),
                    icon: PresenceFilter.fading.icon,
                    onTap: () =>
                        setState(() => _filter = PresenceFilter.fading),
                  ),
                  SectionFilterChip(
                    label: 'Inactive',
                    count: _countForFilter(
                      PresenceFilter.inactive,
                      allPresences,
                    ),
                    isSelected: _filter == PresenceFilter.inactive,
                    color: PresenceFilter.inactive.color(context),
                    icon: PresenceFilter.inactive.icon,
                    onTap: () =>
                        setState(() => _filter = PresenceFilter.inactive),
                  ),
                  SectionFilterChip(
                    label: 'Unknown',
                    count: _countForFilter(
                      PresenceFilter.unknown,
                      allPresences,
                    ),
                    isSelected: _filter == PresenceFilter.unknown,
                    color: PresenceFilter.unknown.color(context),
                    icon: PresenceFilter.unknown.icon,
                    onTap: () =>
                        setState(() => _filter = PresenceFilter.unknown),
                  ),
                  SectionFilterChip(
                    label: 'Familiar',
                    count: _countForFilter(
                      PresenceFilter.familiar,
                      allPresences,
                    ),
                    isSelected: _filter == PresenceFilter.familiar,
                    color: PresenceFilter.familiar.color(context),
                    icon: PresenceFilter.familiar.icon,
                    onTap: () =>
                        setState(() => _filter = PresenceFilter.familiar),
                  ),
                ],
                trailingControls: [
                  SectionHeadersToggle(
                    enabled: _showSectionHeaders,
                    onToggle: () => setState(
                      () => _showSectionHeaders = !_showSectionHeaders,
                    ),
                  ),
                ],
              ),
            ),

            // Quiet mesh hint
            if (showQuietMeshHint)
              const SliverToBoxAdapter(child: _QuietMeshHint()),

            // Content
            if (allPresences.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(theme),
              ),
            ] else if (filtered.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildNoResultsState(theme),
              ),
            ] else ...[
              // Summary section (only when showing all, no search)
              if (_filter == PresenceFilter.all && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: _buildSummarySection(context, theme, summary),
                ),

              // Activity chart (only when showing all, no search)
              if (_filter == PresenceFilter.all && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: _buildActivityChart(theme, allPresences),
                ),

              // Node list - grouped or flat depending on toggle and filter
              if (_showSectionHeaders &&
                  _filter == PresenceFilter.all &&
                  _searchQuery.isEmpty) ...[
                // Grouped display with sticky section headers
                for (final section in _groupPresencesIntoSections(filtered))
                  if (section.presences.isNotEmpty) ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: SectionHeaderDelegate(
                        title: section.title,
                        count: section.presences.length,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildPresenceCard(theme, section.presences[index]),
                        childCount: section.presences.length,
                      ),
                    ),
                  ],
              ] else ...[
                // Flat list with simple header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      _filter == PresenceFilter.all && _searchQuery.isEmpty
                          ? 'All Nodes'
                          : '${filtered.length} ${filtered.length == 1 ? 'node' : 'nodes'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildPresenceCard(theme, filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
              ],

              // Bottom safe area padding
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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
              Icons.people_outline,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No nodes discovered',
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nodes will appear here as they are discovered',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    final hasActiveSearch = _searchQuery.isNotEmpty;
    final hasActiveFilter = _filter != PresenceFilter.all;

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
              hasActiveSearch ? Icons.search_off : Icons.filter_list_off,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasActiveSearch
                ? 'No nodes match your search'
                : 'No nodes match this filter',
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveSearch || hasActiveFilter
                ? 'Try a different search or filter'
                : 'Nodes will appear here as they are discovered',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (hasActiveFilter && !hasActiveSearch) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _filter = PresenceFilter.all),
              child: const Text('Show all nodes'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    ThemeData theme,
    Map<PresenceConfidence, int> summary,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: PresenceConfidence.values.asMap().entries.map((entry) {
          final status = entry.value;
          final index = entry.key;
          final count = summary[status] ?? 0;
          final color = _statusColor(status);
          final isLast = index == PresenceConfidence.values.length - 1;
          return Expanded(
            child: Container(
              height: 130,
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(77)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(status), color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    count.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityChart(ThemeData theme, List<NodePresence> presences) {
    // Build a simple activity visualization
    final activePresences = presences
        .where((p) => p.confidence != PresenceConfidence.unknown)
        .toList();

    if (activePresences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: context.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: _ActivityTimeline(presences: activePresences),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: AppTheme.successGreen, label: '< 2 min'),
                const SizedBox(width: 24),
                _LegendItem(color: AppTheme.warningYellow, label: '2-10 min'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceCard(ThemeData theme, NodePresence presence) {
    final node = presence.node;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
            ),
          );
        },
        leading: Stack(
          children: [
            SigilAvatar(nodeNum: node.nodeNum, size: 40),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _statusColor(presence.confidence),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          node.displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(presence.confidence),
                      size: 12,
                      color: _statusColor(presence.confidence),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: kPresenceInferenceTooltip,
                      child: Text(
                        presence.lastSeenBucket.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _statusColor(presence.confidence),
                        ),
                      ),
                    ),
                  ],
                ),
                _ConfidenceTierBadge(tier: presence.confidenceTier),
                // Back nearby badge
                if (presence.isBackNearby) const _BackNearbyBadge(),
                // Familiar badge
                if (presence.encounter != null &&
                    presence.encounter!.isFamiliar &&
                    !presence.isBackNearby)
                  const _FamiliarBadge(),
                // Role badge
                if (presence.node.role != null)
                  _RoleBadge(role: presence.node.role!),
              ],
            ),
            // Encounter history
            if (presence.encounter != null) ...[
              const SizedBox(height: 4),
              _EncounterRow(encounter: presence.encounter!),
            ],
            // Extended presence: intent and short status
            if (presence.extendedInfo != null &&
                presence.extendedInfo!.hasData) ...[
              const SizedBox(height: 6),
              _ExtendedPresenceRow(info: presence.extendedInfo!),
            ],
            if (presence.signalQuality != null) ...[
              const SizedBox(height: 8),
              _SignalQualityBar(quality: presence.signalQuality!),
            ],
          ],
        ),
        trailing: null,
      ),
    );
  }

  Color _statusColor(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return AppTheme.successGreen;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  IconData _statusIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.circle;
      case PresenceConfidence.fading:
        return Icons.circle_outlined;
      case PresenceConfidence.stale:
        return Icons.radio_button_unchecked;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }
}

class _SignalQualityBar extends StatelessWidget {
  final double quality;

  const _SignalQualityBar({required this.quality});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.signal_cellular_alt, size: 12, color: context.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: quality,
              minHeight: 4,
              backgroundColor: context.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                quality > 0.6
                    ? AppTheme.successGreen
                    : quality > 0.3
                    ? AppTheme.warningYellow
                    : AppTheme.errorRed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(quality * 100).toInt()}%',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final List<NodePresence> presences;

  const _ActivityTimeline({required this.presences});

  @override
  Widget build(BuildContext context) {
    // Create a timeline showing when nodes were last heard
    // Group into time buckets: <1min, 1-2min, 2-5min, 5-10min, 10-15min
    final buckets = <int, List<NodePresence>>{};
    for (var i = 0; i < 5; i++) {
      buckets[i] = [];
    }

    for (final presence in presences) {
      final minutes = presence.timeSinceLastHeard?.inMinutes ?? 999;
      int bucket;
      if (minutes < 1) {
        bucket = 0;
      } else if (minutes < 2) {
        bucket = 1;
      } else if (minutes < 5) {
        bucket = 2;
      } else if (minutes < 10) {
        bucket = 3;
      } else {
        bucket = 4;
      }
      buckets[bucket]!.add(presence);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        final count = buckets[index]!.length;
        final maxCount = presences.length.clamp(1, 10);
        final height = count > 0
            ? (count / maxCount * 48).clamp(8.0, 48.0)
            : 4.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      count.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getBucketColor(context, index),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: height),
                    decoration: BoxDecoration(
                      color: _getBucketColor(
                        context,
                        index,
                      ).withAlpha(count > 0 ? 200 : 51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Color _getBucketColor(BuildContext context, int bucket) {
    if (bucket < 2) return AppTheme.successGreen;
    if (bucket < 4) return AppTheme.warningYellow;
    return context.textTertiary;
  }
}

/// Displays extended presence info (intent + short status)
class _ExtendedPresenceRow extends StatelessWidget {
  const _ExtendedPresenceRow({required this.info});

  final ExtendedPresenceInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Intent icon and label
        if (info.intent != PresenceIntent.unknown) ...[
          Icon(
            PresenceIntentIcons.iconFor(info.intent),
            size: 12,
            color: context.accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            info.intent.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        // Short status
        if (info.shortStatus != null && info.shortStatus!.isNotEmpty) ...[
          if (info.intent != PresenceIntent.unknown) ...[
            const SizedBox(width: 6),
            Text(
              '·',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              info.shortStatus!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Subtle badge showing confidence tier.
class _ConfidenceTierBadge extends StatelessWidget {
  const _ConfidenceTierBadge({required this.tier});

  final ConfidenceTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _tierColor(context).withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _tierColor(context).withAlpha(51)),
      ),
      child: Text(
        tier.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _tierColor(context),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _tierColor(BuildContext context) {
    switch (tier) {
      case ConfidenceTier.strong:
        return AppTheme.successGreen;
      case ConfidenceTier.moderate:
        return AppTheme.warningYellow;
      case ConfidenceTier.weak:
        return context.textTertiary;
    }
  }
}

/// Displays encounter history for a node.
class _EncounterRow extends StatelessWidget {
  const _EncounterRow({required this.encounter});

  final NodeEncounter encounter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Row(
      children: [
        Icon(
          encounter.isFamiliar ? Icons.people : Icons.person_outline,
          size: 12,
          color: context.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          encounter.encounterSummary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '·',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          encounter.relationshipAgeText(now),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Subtle hint banner for quiet/small meshes.
class _QuietMeshHint extends StatelessWidget {
  const _QuietMeshHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering, size: 16, color: context.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mesh is quiet right now — nodes appear as they come online.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge for familiar nodes (>5 encounters).
class _FamiliarBadge extends StatelessWidget {
  const _FamiliarBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(51)),
      ),
      child: Text(
        'Familiar',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.primaryPurple,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Badge for nodes that reappeared after >48h absence.
class _BackNearbyBadge extends StatelessWidget {
  const _BackNearbyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.accentOrange.withAlpha(51)),
      ),
      child: Text(
        'Back nearby',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.accentOrange,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Badge showing node role.
class _PresenceSection {
  final String title;
  final List<NodePresence> presences;
  final Color color;

  const _PresenceSection(this.title, this.presences, this.color);
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryPurple.withAlpha(51)),
      ),
      child: Text(
        role,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.primaryPurple,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
