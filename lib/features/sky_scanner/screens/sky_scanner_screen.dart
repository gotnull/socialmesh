// SPDX-License-Identifier: GPL-3.0-or-later

// Sky Scanner Main Screen — track and discover Meshtastic nodes at altitude.
//
// Enables users to schedule flights with their mesh nodes, track active flights,
// view reception reports, and compete on a leaderboard for longest range contacts.
//
// Layout:
// - Glass app bar with title and help action
// - Pinned stats summary card (active flights, scheduled, reports, distance record)
// - Segmented filter control (All, Active, Upcoming, My Flights)
// - Search bar for flight/airport/node filtering
// - Scrollable flight list with staggered animations
//
// Firebase-backed with real-time streams and OpenSky Network integration
// for live flight position tracking.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/auth_providers.dart';

import '../models/sky_node.dart';
import '../providers/sky_scanner_providers.dart';
import 'schedule_flight_screen.dart';
import 'sky_node_detail_screen.dart';

// =============================================================================
// Filter Enum
// =============================================================================

/// Filter options for the sky scanner flight list.
enum SkyScannerFilter { all, active, upcoming, myFlights, reports }

extension SkyScannerFilterLabel on SkyScannerFilter {
  String get label {
    switch (this) {
      case SkyScannerFilter.all:
        return 'All';
      case SkyScannerFilter.active:
        return 'Active';
      case SkyScannerFilter.upcoming:
        return 'Upcoming';
      case SkyScannerFilter.myFlights:
        return 'My Flights';
      case SkyScannerFilter.reports:
        return 'Reports';
    }
  }

  IconData get icon {
    switch (this) {
      case SkyScannerFilter.all:
        return Icons.flight;
      case SkyScannerFilter.active:
        return Icons.flight_takeoff;
      case SkyScannerFilter.upcoming:
        return Icons.schedule;
      case SkyScannerFilter.myFlights:
        return Icons.person_outline;
      case SkyScannerFilter.reports:
        return Icons.signal_cellular_alt;
    }
  }
}

// =============================================================================
// Main Screen
// =============================================================================

/// Main Sky Scanner screen — browse and track Meshtastic nodes in the sky.
class SkyScannerScreen extends ConsumerStatefulWidget {
  const SkyScannerScreen({super.key});

  @override
  ConsumerState<SkyScannerScreen> createState() => _SkyScannerScreenState();
}

class _SkyScannerScreenState extends ConsumerState<SkyScannerScreen>
    with LifecycleSafeMixin<SkyScannerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SkyScannerFilter _currentFilter = SkyScannerFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _scheduleFlight() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleFlightScreen()),
    );
  }

  void _showInfo() {
    final cardColor = context.card;
    final accentColor = context.accentColor;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textTertiary;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.radar, color: accentColor),
            const SizedBox(width: 8),
            Text('Sky Scanner', style: TextStyle(color: textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Meshtastic nodes at altitude!',
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.flight_takeoff,
              text: 'Schedule your flight with your node',
              iconColor: textTertiary,
              textColor: textSecondary,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.radar,
              text: 'Ground stations watch for your signal',
              iconColor: textTertiary,
              textColor: textSecondary,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.celebration,
              text: 'Report receptions & set range records!',
              iconColor: textTertiary,
              textColor: textSecondary,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'At 35,000ft, LoRa can reach 400+ km!',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Got it!', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skyNodesAsync = ref.watch(skyNodesProvider);
    final activeFlightsAsync = ref.watch(activeFlightsProvider);
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);
    final stats = ref.watch(skyScannerStatsProvider);
    final user = ref.watch(currentUserProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    final isLoading =
        skyNodesAsync is AsyncLoading ||
        activeFlightsAsync is AsyncLoading ||
        leaderboardAsync is AsyncLoading;

    return HelpTourController(
      topicId: 'sky_scanner_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: GlassScaffold(
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.radar, color: context.accentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Sky Scanner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            // Schedule Flight action button
            TextButton.icon(
              onPressed: _scheduleFlight,
              icon: Icon(Icons.add_circle_outline, color: context.accentColor),
              label: Text(
                'Schedule',
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.info_outline, color: context.textSecondary),
              onPressed: _showInfo,
              tooltip: 'About Sky Scanner',
            ),
            const IcoHelpAppBarButton(topicId: 'sky_scanner_overview'),
          ],
          slivers: [
            // Stats summary card
            SliverToBoxAdapter(
              child: Skeletonizer(
                enabled: isLoading,
                effect: AppSkeletonConfig.effect(context),
                child: _StatsCard(stats: stats),
              ),
            ),

            // Filter chips row
            SliverToBoxAdapter(
              child: _FilterChipRow(
                currentFilter: _currentFilter,
                stats: stats,
                onFilterChanged: (filter) {
                  HapticFeedback.selectionClick();
                  safeSetState(() => _currentFilter = filter);
                },
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _SearchField(
                  controller: _searchController,
                  query: _searchQuery,
                  onChanged: (value) =>
                      safeSetState(() => _searchQuery = value),
                ),
              ),
            ),

            // Content based on filter
            _buildContent(
              context,
              isLoading: isLoading,
              skyNodesAsync: skyNodesAsync,
              activeFlightsAsync: activeFlightsAsync,
              leaderboardAsync: leaderboardAsync,
              user: user,
              reduceMotion: reduceMotion,
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isLoading,
    required AsyncValue<List<SkyNode>> skyNodesAsync,
    required AsyncValue<List<SkyNode>> activeFlightsAsync,
    required AsyncValue<List<ReceptionReport>> leaderboardAsync,
    required dynamic user,
    required bool reduceMotion,
  }) {
    if (_currentFilter == SkyScannerFilter.reports) {
      return _buildLeaderboardContent(context, leaderboardAsync, reduceMotion);
    }

    final allNodes = skyNodesAsync.value ?? [];
    List<SkyNode> filteredNodes;

    switch (_currentFilter) {
      case SkyScannerFilter.all:
        filteredNodes = allNodes;
        break;
      case SkyScannerFilter.active:
        filteredNodes = allNodes.where((n) => n.isActive).toList();
        break;
      case SkyScannerFilter.upcoming:
        filteredNodes = allNodes
            .where((n) => !n.isActive && !n.isPast)
            .toList();
        break;
      case SkyScannerFilter.myFlights:
        if (user == null) {
          return SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.person_outline,
              title: 'Sign In Required',
              subtitle: 'Sign in to view and manage your scheduled flights.',
            ),
          );
        }
        filteredNodes = allNodes.where((n) => n.userId == user.uid).toList();
        break;
      case SkyScannerFilter.reports:
        filteredNodes = [];
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredNodes = filteredNodes.where((node) {
        return node.flightNumber.toLowerCase().contains(query) ||
            node.departure.toLowerCase().contains(query) ||
            node.arrival.toLowerCase().contains(query) ||
            (node.nodeName?.toLowerCase().contains(query) ?? false) ||
            node.nodeId.toLowerCase().contains(query);
      }).toList();
    }

    if (isLoading && filteredNodes.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Skeletonizer(
            enabled: true,
            effect: AppSkeletonConfig.effect(context),
            child: _SkyScannerFlightCard(
              skyNode: SkyNode(
                id: 'skeleton_$index',
                nodeId: '!12345678',
                flightNumber: 'AA1234',
                departure: 'LAX',
                arrival: 'JFK',
                scheduledDeparture: DateTime.now(),
                userId: 'skeleton',
                createdAt: DateTime.now(),
              ),
            ),
          ),
          childCount: 5,
        ),
      );
    }

    if (filteredNodes.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(
          icon: _currentFilter.icon,
          title: _getEmptyTitle(),
          subtitle: _getEmptySubtitle(),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final node = filteredNodes[index];
        return _StaggeredListTile(
          index: index,
          reduceMotion: reduceMotion,
          child: _SkyScannerFlightCard(
            skyNode: node,
            showLiveTracking: node.isActive,
            showActions: _currentFilter == SkyScannerFilter.myFlights,
          ),
        );
      }, childCount: filteredNodes.length),
    );
  }

  /// Builds the global leaderboard content.
  ///
  /// Data is fetched from Firestore sorted by distance descending,
  /// so rankings are globally consistent and persist across app reinstalls.
  Widget _buildLeaderboardContent(
    BuildContext context,
    AsyncValue<List<ReceptionReport>> leaderboardAsync,
    bool reduceMotion,
  ) {
    return leaderboardAsync.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Skeletonizer(
            enabled: true,
            effect: AppSkeletonConfig.effect(context),
            child: _ReportCard(
              report: ReceptionReport(
                id: 'skeleton_$index',
                skyNodeId: 'skeleton',
                flightNumber: 'AA1234',
                reporterId: 'skeleton',
                receivedAt: DateTime.now(),
                createdAt: DateTime.now(),
              ),
              rank: index + 1,
            ),
          ),
          childCount: 5,
        ),
      ),
      error: (e, _) => SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.error_outline,
          title: 'Error Loading Leaderboard',
          subtitle: 'Pull to refresh and try again.',
        ),
      ),
      data: (leaderboard) {
        if (leaderboard.isEmpty) {
          return SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Leaderboard Empty',
              subtitle:
                  'Be the first to receive a signal from a sky node and claim the top spot!',
            ),
          );
        }

        // Leaderboard is already sorted by distance from Firestore
        // Rankings are globally consistent and persist across app reinstalls
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return _StaggeredListTile(
              index: index,
              reduceMotion: reduceMotion,
              child: _ReportCard(report: leaderboard[index], rank: index + 1),
            );
          }, childCount: leaderboard.length),
        );
      },
    );
  }

  String _getEmptyTitle() {
    switch (_currentFilter) {
      case SkyScannerFilter.all:
        return 'No Flights Found';
      case SkyScannerFilter.active:
        return 'No Active Flights';
      case SkyScannerFilter.upcoming:
        return 'No Upcoming Flights';
      case SkyScannerFilter.myFlights:
        return 'No Flights Scheduled';
      case SkyScannerFilter.reports:
        return 'Leaderboard Empty';
    }
  }

  String _getEmptySubtitle() {
    if (_searchQuery.isNotEmpty) {
      return 'No results match "$_searchQuery".\nTry a different search term.';
    }
    switch (_currentFilter) {
      case SkyScannerFilter.all:
        return 'No flights scheduled yet.\nBe the first to share your journey!';
      case SkyScannerFilter.active:
        return 'No Meshtastic nodes currently in the air.\nBe the first to schedule one!';
      case SkyScannerFilter.upcoming:
        return 'No flights scheduled yet.\nPlan your next airborne test!';
      case SkyScannerFilter.myFlights:
        return "You haven't scheduled any flights yet.\nTap the button below to add one!";
      case SkyScannerFilter.reports:
        return 'Be the first to claim the top spot on the global leaderboard!';
    }
  }
}

// =============================================================================
// Stats Card
// =============================================================================

class _StatsCard extends StatelessWidget {
  final SkyScannerStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 1.5,
        accentOpacity: 0.4,
        enableDepthBlend: true,
        depthBlendOpacity: 0.08,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.flight_takeoff,
                value: stats.activeFlights.toString(),
                label: 'Active',
                color: context.accentColor,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _StatItem(
                icon: Icons.schedule,
                value: stats.totalScheduled.toString(),
                label: 'Scheduled',
                color: AppTheme.warningYellow,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _StatItem(
                icon: Icons.signal_cellular_alt,
                value: stats.totalReports.toString(),
                label: 'Reports',
                color: Colors.green.shade400,
              ),
            ),
            _VerticalDivider(),
            Expanded(
              child: _StatItem(
                icon: Icons.straighten,
                value: _formatDistance(stats.longestDistance),
                label: 'Record',
                color: Colors.purple.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km <= 0) return '--';
    if (km >= 1000) return '${(km / 1000).toStringAsFixed(1)}K';
    return '${km.round()}km';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.border.withValues(alpha: 0.3),
    );
  }
}

// =============================================================================
// Filter Chips
// =============================================================================

class _FilterChipRow extends StatelessWidget {
  final SkyScannerFilter currentFilter;
  final SkyScannerStats stats;
  final ValueChanged<SkyScannerFilter> onFilterChanged;

  const _FilterChipRow({
    required this.currentFilter,
    required this.stats,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            filter: SkyScannerFilter.all,
            isSelected: currentFilter == SkyScannerFilter.all,
            count: stats.totalScheduled,
            onTap: () => onFilterChanged(SkyScannerFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            filter: SkyScannerFilter.active,
            isSelected: currentFilter == SkyScannerFilter.active,
            count: stats.activeFlights,
            onTap: () => onFilterChanged(SkyScannerFilter.active),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            filter: SkyScannerFilter.upcoming,
            isSelected: currentFilter == SkyScannerFilter.upcoming,
            onTap: () => onFilterChanged(SkyScannerFilter.upcoming),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            filter: SkyScannerFilter.myFlights,
            isSelected: currentFilter == SkyScannerFilter.myFlights,
            onTap: () => onFilterChanged(SkyScannerFilter.myFlights),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            filter: SkyScannerFilter.reports,
            isSelected: currentFilter == SkyScannerFilter.reports,
            count: stats.totalReports,
            onTap: () => onFilterChanged(SkyScannerFilter.reports),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final SkyScannerFilter filter;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.filter,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.5)
                : context.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              size: 16,
              color: isSelected ? accentColor : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              filter.label,
              style: TextStyle(
                color: isSelected ? accentColor : context.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.3)
                      : context.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? accentColor : context.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Search Field
// =============================================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search flights, airports, nodes...',
          hintStyle: TextStyle(color: context.textTertiary),
          prefixIcon: Icon(Icons.search, color: context.textTertiary),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: context.textTertiary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Flight Card
// =============================================================================

class _SkyScannerFlightCard extends ConsumerWidget {
  final SkyNode skyNode;
  final bool showLiveTracking;
  final bool showActions;

  const _SkyScannerFlightCard({
    required this.skyNode,
    this.showLiveTracking = false,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkyNodeDetailScreen(skyNode: skyNode),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GradientBorderContainer(
          borderRadius: 16,
          borderWidth: skyNode.isActive ? 2 : 1,
          accentOpacity: skyNode.isActive ? 0.6 : 0.3,
          enableDepthBlend: skyNode.isActive,
          depthBlendOpacity: 0.1,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status badge
                  _StatusBadge(skyNode: skyNode),
                  const Spacer(),
                  // Flight number
                  Text(
                    skyNode.flightNumber,
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Route visualization
              Row(
                children: [
                  _AirportCode(code: skyNode.departure),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.border,
                                  context.accentColor.withValues(alpha: 0.5),
                                  context.border,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flight,
                              color: skyNode.isActive
                                  ? context.accentColor
                                  : context.textTertiary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _AirportCode(code: skyNode.arrival),
                ],
              ),
              const SizedBox(height: 12),
              // Info row
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: context.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(skyNode.scheduledDeparture.toLocal()),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.memory, size: 14, color: context.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      skyNode.nodeName ?? skyNode.nodeId,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Reception count
              if (skyNode.receptionCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 14,
                      color: context.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${skyNode.receptionCount} reception${skyNode.receptionCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              // Live tracking
              if (showLiveTracking && skyNode.isActive) ...[
                const SizedBox(height: 12),
                _LiveTrackingIndicator(callsign: skyNode.flightNumber),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SkyNode skyNode;

  const _StatusBadge({required this.skyNode});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (skyNode.isActive) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            skyNode.statusText,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    if (skyNode.isActive) return context.accentColor;
    if (skyNode.isPast) return context.textTertiary;
    if (skyNode.isUpcoming) return AppTheme.warningYellow;
    return context.textSecondary;
  }
}

class _AirportCode extends StatelessWidget {
  final String code;

  const _AirportCode({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(
              alpha: 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5),
                blurRadius: 4 + 4 * _controller.value,
                spreadRadius: 1 + _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Live Tracking Indicator
// =============================================================================

class _LiveTrackingIndicator extends ConsumerWidget {
  final String callsign;

  const _LiveTrackingIndicator({required this.callsign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(flightPositionProvider(callsign));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: positionAsync.when(
        loading: () => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Getting live position...',
              style: TextStyle(color: context.accentColor, fontSize: 13),
            ),
          ],
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.cloud_off, color: context.textTertiary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Position unavailable',
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ],
        ),
        data: (positionState) {
          if (positionState.position == null) {
            return Row(
              children: [
                Icon(Icons.cloud_off, color: context.textTertiary, size: 18),
                const SizedBox(width: 8),
                Text(
                  positionState.error ?? 'Position unavailable',
                  style: TextStyle(color: context.textTertiary, fontSize: 13),
                ),
              ],
            );
          }
          return Row(
            children: [
              Icon(Icons.radar, color: context.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FL${(positionState.position!.altitudeFeet / 100).round()} · ${positionState.position!.velocityKnots.round()} kts',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Coverage radius: ~${positionState.position!.coverageRadiusKm.round()} km',
                      style: TextStyle(
                        color: context.accentColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Report Card
// =============================================================================

class _ReportCard extends StatelessWidget {
  final ReceptionReport report;
  final int rank;

  const _ReportCard({required this.report, required this.rank});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: rank <= 3
                      ? LinearGradient(
                          colors: [
                            _getRankColor(context),
                            _getRankColor(context).withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: rank > 3
                      ? _getRankColor(context).withValues(alpha: 0.2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rank <= 3 ? Colors.white : _getRankColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          report.flightNumber,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (report.reporterName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.reporterName!,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (report.estimatedDistance != null) ...[
                          Icon(
                            Icons.straighten,
                            size: 14,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.estimatedDistance!.round()} km',
                            style: TextStyle(
                              color: context.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (report.rssi != null) ...[
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 14,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.rssi!.round()} dBm',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Time
              Text(
                dateFormat.format(report.receivedAt.toLocal()),
                style: TextStyle(color: context.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(BuildContext context) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return context.accentColor;
    }
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 48, color: context.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Info Row (for dialog)
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: textColor, fontSize: 14)),
        ),
      ],
    );
  }
}

// =============================================================================
// Staggered List Tile Animation
// =============================================================================

class _StaggeredListTile extends StatefulWidget {
  final int index;
  final Widget child;
  final bool reduceMotion;

  const _StaggeredListTile({
    required this.index,
    required this.child,
    required this.reduceMotion,
  });

  @override
  State<_StaggeredListTile> createState() => _StaggeredListTileState();
}

class _StaggeredListTileState extends State<_StaggeredListTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (!widget.reduceMotion && !_hasAnimated) {
      final delay = Duration(milliseconds: 50 * (widget.index % 10));
      Future<void>.delayed(delay, () {
        if (mounted && !_hasAnimated) {
          _controller.forward();
          _hasAnimated = true;
        }
      });
    } else {
      _controller.value = 1.0;
      _hasAnimated = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.reduceMotion) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
