// SPDX-License-Identifier: GPL-3.0-or-later

// Aether Main Screen — track and discover Meshtastic nodes at altitude.
//
// Enables users to schedule flights with their mesh nodes, track active flights,
// view reception reports, and compete on a leaderboard for longest range contacts.
//
// Layout:
// - Glass app bar with title and gradient action button
// - Tab bar for Flights / Discover / Leaderboard navigation
// - Flights tab: stats card, filter chips, searchable flight list (Firestore)
// - Discover tab: community-shared flights from the Aether API
// - Leaderboard tab: global distance rankings with medals
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
import '../../../core/logging.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animated_gradient_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../providers/help_providers.dart';
import '../../../core/widgets/search_filter_header.dart';

import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/auth_providers.dart';
import '../models/aether_flight.dart';
import '../providers/aether_providers.dart';
import '../services/aether_share_service.dart';
import 'schedule_flight_screen.dart';
import 'aether_flight_detail_screen.dart';
import '../../settings/settings_screen.dart';

// =============================================================================
// Filter Enum (for Flights tab only)
// =============================================================================

/// Filter options for the flights list within the Flights tab.
enum AetherFilter { all, active, upcoming, myFlights }

extension AetherFilterLabel on AetherFilter {
  String get label {
    switch (this) {
      case AetherFilter.all:
        return 'All';
      case AetherFilter.active:
        return 'Active';
      case AetherFilter.upcoming:
        return 'Upcoming';
      case AetherFilter.myFlights:
        return 'My Flights';
    }
  }

  IconData get icon {
    switch (this) {
      case AetherFilter.all:
        return Icons.flight;
      case AetherFilter.active:
        return Icons.flight_takeoff;
      case AetherFilter.upcoming:
        return Icons.schedule;
      case AetherFilter.myFlights:
        return Icons.person_outline;
    }
  }
}

// =============================================================================
// Main Screen
// =============================================================================

/// Main Aether screen — browse and track Meshtastic nodes in the sky.
class AetherScreen extends ConsumerStatefulWidget {
  const AetherScreen({super.key});

  @override
  ConsumerState<AetherScreen> createState() => _AetherScreenState();
}

class _AetherScreenState extends ConsumerState<AetherScreen>
    with LifecycleSafeMixin<AetherScreen>, SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AetherFilter _currentFilter = AetherFilter.all;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _openFlightDetail(AetherFlight flight) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AetherFlightDetailScreen(flight: flight),
      ),
    );
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
            Text('Aether', style: TextStyle(color: textPrimary)),
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

  /// Builds the gradient-animated action button for scheduling flights.
  /// Matches the Signals "Go Active" button pattern for consistency.
  Widget _buildScheduleFlightButton(BuildContext context) {
    final gradientColors = AccentColors.gradientFor(context.accentColor);
    final gradient = LinearGradient(
      colors: [gradientColors[0], gradientColors[1]],
    );

    return Tooltip(
      message: 'Schedule Flight',
      child: BouncyTap(
        onTap: _scheduleFlight,
        child: AnimatedGradientBackground(
          gradient: gradient,
          animate: true,
          enabled: true,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
            child: const Icon(
              Icons.flight_takeoff,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flightsAsync = ref.watch(aetherFlightsProvider);
    final activeFlightsAsync = ref.watch(aetherActiveFlightsProvider);
    final leaderboardAsync = ref.watch(aetherGlobalLeaderboardProvider);
    final discoveryAsync = ref.watch(aetherDiscoveryProvider);
    final stats = ref.watch(aetherStatsProvider);
    final user = ref.watch(currentUserProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    final discoveryTotal = discoveryAsync.value?.total ?? 0;

    final isLoading =
        flightsAsync is AsyncLoading ||
        activeFlightsAsync is AsyncLoading ||
        leaderboardAsync is AsyncLoading;

    return HelpTourController(
      topicId: 'aether_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const BackButton(),
            centerTitle: true,
            title: Text(
              'Aether',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              _buildScheduleFlightButton(context),
              const SizedBox(width: 4),
              AppBarOverflowMenu<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'info':
                      _showInfo();
                    case 'help':
                      ref
                          .read(helpProvider.notifier)
                          .startTour('aether_overview');
                    case 'settings':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'About Aether',
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Help',
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Settings',
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: context.accentColor,
                  indicatorWeight: 3,
                  labelColor: context.accentColor,
                  unselectedLabelColor: context.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flight, size: 16),
                          const SizedBox(width: 4),
                          const Text('Flights'),
                          const SizedBox(width: 4),
                          _TabBadge(count: stats.totalScheduled),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.explore_outlined, size: 16),
                          const SizedBox(width: 4),
                          const Text('Discover'),
                          const SizedBox(width: 4),
                          _TabBadge(count: discoveryTotal),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, size: 16),
                          const SizedBox(width: 4),
                          const Text('Board'),
                          const SizedBox(width: 4),
                          _TabBadge(count: stats.totalReports),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Flights Tab (Firestore — your flights)
              _FlightsTabContent(
                flightsAsync: flightsAsync,
                activeFlightsAsync: activeFlightsAsync,
                stats: stats,
                user: user,
                reduceMotion: reduceMotion,
                isLoading: isLoading,
                searchController: _searchController,
                searchQuery: _searchQuery,
                currentFilter: _currentFilter,
                onSearchChanged: (value) {
                  safeSetState(() => _searchQuery = value);
                },
                onFilterChanged: (filter) {
                  HapticFeedback.selectionClick();
                  safeSetState(() => _currentFilter = filter);
                },
                onScheduleFlight: _scheduleFlight,
                onOpenDetail: _openFlightDetail,
              ),
              // Discover Tab (Aether API — community flights)
              _DiscoverTabContent(
                reduceMotion: reduceMotion,
                onScheduleFlight: _scheduleFlight,
              ),
              // Leaderboard Tab
              _LeaderboardTabContent(
                leaderboardAsync: leaderboardAsync,
                reduceMotion: reduceMotion,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab Badge
// =============================================================================

/// Tab badge showing count
class _TabBadge extends StatelessWidget {
  final int count;

  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

// =============================================================================
// Flights Tab Content
// =============================================================================

class _FlightsTabContent extends StatelessWidget {
  final AsyncValue<List<AetherFlight>> flightsAsync;
  final AsyncValue<List<AetherFlight>> activeFlightsAsync;
  final AetherStats stats;
  final dynamic user;
  final bool reduceMotion;
  final bool isLoading;
  final TextEditingController searchController;
  final String searchQuery;
  final AetherFilter currentFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AetherFilter> onFilterChanged;
  final VoidCallback onScheduleFlight;
  final void Function(AetherFlight) onOpenDetail;

  const _FlightsTabContent({
    required this.flightsAsync,
    required this.activeFlightsAsync,
    required this.stats,
    required this.user,
    required this.reduceMotion,
    required this.isLoading,
    required this.searchController,
    required this.searchQuery,
    required this.currentFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onScheduleFlight,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Stats summary card
        SliverToBoxAdapter(
          child: Skeletonizer(
            enabled: isLoading,
            effect: AppSkeletonConfig.effect(context),
            child: _StatsCard(stats: stats),
          ),
        ),

        // Pinned search + filter controls
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            textScaler: MediaQuery.textScalerOf(context),
            searchController: searchController,
            searchQuery: searchQuery,
            hintText: 'Search flights, airports, nodes...',
            onSearchChanged: onSearchChanged,
            rebuildKey: Object.hashAll([
              currentFilter,
              stats.totalScheduled,
              stats.activeFlights,
            ]),
            filterChips: [
              SectionFilterChip(
                label: 'All',
                count: stats.totalScheduled,
                isSelected: currentFilter == AetherFilter.all,
                onTap: () => onFilterChanged(AetherFilter.all),
              ),
              SectionFilterChip(
                label: 'Active',
                count: stats.activeFlights,
                isSelected: currentFilter == AetherFilter.active,
                color: Colors.green,
                onTap: () => onFilterChanged(AetherFilter.active),
              ),
              SectionFilterChip(
                label: 'Upcoming',
                count: 0,
                isSelected: currentFilter == AetherFilter.upcoming,
                color: AccentColors.cyan,
                icon: Icons.schedule,
                onTap: () => onFilterChanged(AetherFilter.upcoming),
              ),
              SectionFilterChip(
                label: 'My Flights',
                count: 0,
                isSelected: currentFilter == AetherFilter.myFlights,
                color: AccentColors.purple,
                icon: Icons.person_outline,
                onTap: () => onFilterChanged(AetherFilter.myFlights),
              ),
            ],
          ),
        ),

        // Flight list content
        _buildFlightsList(context),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildFlightsList(BuildContext context) {
    final allFlights = flightsAsync.value ?? [];
    List<AetherFlight> filteredFlights;

    switch (currentFilter) {
      case AetherFilter.all:
        filteredFlights = allFlights;
        break;
      case AetherFilter.active:
        filteredFlights = allFlights.where((f) => f.isActive).toList();
        break;
      case AetherFilter.upcoming:
        filteredFlights = allFlights
            .where((f) => !f.isActive && !f.isPast)
            .toList();
        break;
      case AetherFilter.myFlights:
        if (user == null) {
          return SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.person_outline,
              title: 'Sign In Required',
              subtitle: 'Sign in to view and manage your scheduled flights.',
            ),
          );
        }
        filteredFlights = allFlights
            .where((f) => f.userId == user.uid)
            .toList();
        break;
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredFlights = filteredFlights.where((flight) {
        return flight.flightNumber.toLowerCase().contains(query) ||
            flight.departure.toLowerCase().contains(query) ||
            flight.arrival.toLowerCase().contains(query) ||
            (flight.nodeName?.toLowerCase().contains(query) ?? false) ||
            flight.nodeId.toLowerCase().contains(query);
      }).toList();
    }

    // Only show skeletons if we're loading AND we had data before (not first visit)
    // This prevents a skeleton flash on first visit when there's no data
    final hasExistingData =
        flightsAsync.hasValue && flightsAsync.value!.isNotEmpty;
    if (isLoading && hasExistingData && filteredFlights.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Skeletonizer(
            enabled: true,
            effect: AppSkeletonConfig.effect(context),
            child: _AetherFlightCard(
              flight: AetherFlight(
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

    if (AppLogging.forceEmptyStates || filteredFlights.isEmpty) {
      // For the main "all" view with no search, show animated empty state
      if (currentFilter == AetherFilter.all && searchQuery.isEmpty) {
        return SliverFillRemaining(
          child: AnimatedEmptyState(
            config: AnimatedEmptyStateConfig(
              icons: const [
                Icons.flight_takeoff_outlined,
                Icons.flight_land_outlined,
                Icons.airplanemode_active,
                Icons.radar,
                Icons.public,
                Icons.leaderboard_outlined,
              ],
              taglines: const [
                'No flights scheduled yet.\nBe the first to share your airborne journey!',
                'Track Meshtastic nodes at altitude.\nSee how far your signal reaches from the sky.',
                'Compete on the leaderboard.\nLongest range contacts earn top spots.',
                'Schedule your next flight.\nShare your departure and arrival airports.',
              ],
              titlePrefix: 'No ',
              titleKeyword: 'flights',
              titleSuffix: ' in the air',
              actionLabel: 'Schedule Flight',
              actionIcon: Icons.flight_takeoff,
              onAction: onScheduleFlight,
              actionEnabled: true,
            ),
          ),
        );
      }

      // For filtered/search results, show simpler contextual empty state
      return SliverFillRemaining(
        child: _EmptyState(
          icon: currentFilter.icon,
          title: _getEmptyTitle(),
          subtitle: _getEmptySubtitle(),
          showAction: currentFilter == AetherFilter.myFlights,
          actionLabel: 'Schedule Flight',
          onAction: onScheduleFlight,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final flight = filteredFlights[index];
        return _StaggeredListTile(
          index: index,
          reduceMotion: reduceMotion,
          child: _AetherFlightCard(
            flight: flight,
            showLiveTracking: flight.isActive,
            showActions: currentFilter == AetherFilter.myFlights,
          ),
        );
      }, childCount: filteredFlights.length),
    );
  }

  String _getEmptyTitle() {
    switch (currentFilter) {
      case AetherFilter.all:
        return 'No Flights Found';
      case AetherFilter.active:
        return 'No Active Flights';
      case AetherFilter.upcoming:
        return 'No Upcoming Flights';
      case AetherFilter.myFlights:
        return 'No Flights Scheduled';
    }
  }

  String _getEmptySubtitle() {
    if (searchQuery.isNotEmpty) {
      return 'No results match "$searchQuery".\nTry a different search term.';
    }
    switch (currentFilter) {
      case AetherFilter.all:
        return 'No flights scheduled yet.\nBe the first to share your journey!';
      case AetherFilter.active:
        return 'No Meshtastic nodes currently in the air.\nBe the first to schedule one!';
      case AetherFilter.upcoming:
        return 'No flights scheduled yet.\nPlan your next airborne test!';
      case AetherFilter.myFlights:
        return "You haven't scheduled any flights yet.\nTap the button above to add one!";
    }
  }
}

// =============================================================================
// Leaderboard Tab Content
// =============================================================================

// =============================================================================
// Discover Tab Content (Aether API)
// =============================================================================

/// Filter options for the Discover tab.
enum _DiscoverFilter { all, active, completed }

class _DiscoverTabContent extends ConsumerStatefulWidget {
  final bool reduceMotion;
  final VoidCallback onScheduleFlight;

  const _DiscoverTabContent({
    required this.reduceMotion,
    required this.onScheduleFlight,
  });

  @override
  ConsumerState<_DiscoverTabContent> createState() =>
      _DiscoverTabContentState();
}

class _DiscoverTabContentState extends ConsumerState<_DiscoverTabContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _DiscoverFilter _filter = _DiscoverFilter.all;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(aetherDiscoveryProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    ref.read(aetherDiscoveryProvider.notifier).search(value);
  }

  void _onFilterChanged(_DiscoverFilter filter) {
    HapticFeedback.selectionClick();
    setState(() => _filter = filter);

    bool? activeOnly;
    if (filter == _DiscoverFilter.active) activeOnly = true;
    if (filter == _DiscoverFilter.completed) activeOnly = false;

    ref.read(aetherDiscoveryProvider.notifier).filterByActive(activeOnly);
  }

  @override
  Widget build(BuildContext context) {
    final discoveryAsync = ref.watch(aetherDiscoveryProvider);
    final apiStatsAsync = ref.watch(aetherApiStatsProvider);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // API stats summary
        SliverToBoxAdapter(
          child: apiStatsAsync.when(
            data: (stats) => _ApiStatsCard(stats: stats),
            loading: () => Skeletonizer(
              enabled: true,
              effect: AppSkeletonConfig.effect(context),
              child: _ApiStatsCard(
                stats: const AetherApiStats(
                  totalFlights: 0,
                  activeFlights: 0,
                  uniqueDepartures: 0,
                  uniqueArrivals: 0,
                  uniqueFlightNumbers: 0,
                  totalReceptions: 0,
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),

        // Pinned search + filter controls
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            textScaler: MediaQuery.textScalerOf(context),
            searchController: _searchController,
            searchQuery: _searchQuery,
            hintText: 'Search community flights...',
            onSearchChanged: _onSearchChanged,
            rebuildKey: Object.hashAll([
              _filter,
              discoveryAsync.value?.total ?? 0,
            ]),
            filterChips: [
              SectionFilterChip(
                label: 'All',
                count: discoveryAsync.value?.total ?? 0,
                isSelected: _filter == _DiscoverFilter.all,
                onTap: () => _onFilterChanged(_DiscoverFilter.all),
              ),
              SectionFilterChip(
                label: 'In Flight',
                count: 0,
                isSelected: _filter == _DiscoverFilter.active,
                color: Colors.green,
                icon: Icons.flight_takeoff,
                onTap: () => _onFilterChanged(_DiscoverFilter.active),
              ),
              SectionFilterChip(
                label: 'Completed',
                count: 0,
                isSelected: _filter == _DiscoverFilter.completed,
                color: context.textTertiary,
                icon: Icons.flight_land,
                onTap: () => _onFilterChanged(_DiscoverFilter.completed),
              ),
            ],
          ),
        ),

        // Flight list
        discoveryAsync.when(
          data: (state) {
            if (state.flights.isEmpty) {
              if (state.error != null) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Connection Error',
                    subtitle:
                        'Could not reach the Aether API.\nCheck your internet connection and try again.',
                  ),
                );
              }
              return SliverFillRemaining(
                child: AnimatedEmptyState(
                  config: AnimatedEmptyStateConfig(
                    icons: const [
                      Icons.explore_outlined,
                      Icons.public,
                      Icons.flight,
                      Icons.radar,
                      Icons.language,
                      Icons.travel_explore,
                    ],
                    taglines: const [
                      'No community flights yet.\nBe the first to share yours!',
                      'Discover Meshtastic nodes at altitude.\nShared flights from around the world.',
                      'The community feed is waiting.\nSchedule a flight and share it here.',
                    ],
                    titlePrefix: 'No ',
                    titleKeyword: 'shared flights',
                    titleSuffix: ' yet',
                    actionLabel: 'Schedule Flight',
                    actionIcon: Icons.flight_takeoff,
                    onAction: widget.onScheduleFlight,
                    actionEnabled: true,
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // Show a loading indicator at the bottom when paginating
                if (index == state.flights.length) {
                  if (state.isLoadingMore) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                    );
                  }
                  // Bottom padding
                  return const SizedBox(height: 32);
                }

                final flight = state.flights[index];
                return _StaggeredListTile(
                  index: index,
                  reduceMotion: widget.reduceMotion,
                  child: _AetherFlightCard(
                    flight: flight,
                    showLiveTracking: flight.isActive,
                  ),
                );
              }, childCount: state.flights.length + 1),
            );
          },
          loading: () => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Skeletonizer(
                enabled: true,
                effect: AppSkeletonConfig.effect(context),
                child: _AetherFlightCard(
                  flight: AetherFlight(
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
          ),
          error: (error, _) => SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.cloud_off,
              title: 'Connection Error',
              subtitle: 'Could not reach the Aether API.\n$error',
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// API Stats Card (for Discover tab)
// =============================================================================

class _ApiStatsCard extends StatelessWidget {
  final AetherApiStats stats;

  const _ApiStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 1,
        accentOpacity: 0.3,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.flight,
              value: NumberFormat.compact().format(stats.totalFlights),
              label: 'Shared',
              color: context.accentColor,
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.flight_takeoff,
              value: stats.activeFlights.toString(),
              label: 'In Flight',
              color: Colors.green,
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.public,
              value: stats.uniqueDepartures.toString(),
              label: 'Airports',
              color: AccentColors.cyan,
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.signal_cellular_alt,
              value: NumberFormat.compact().format(stats.totalReceptions),
              label: 'Receptions',
              color: AccentColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Leaderboard Tab Content
// =============================================================================

class _LeaderboardTabContent extends StatelessWidget {
  final AsyncValue<List<ReceptionReport>> leaderboardAsync;
  final bool reduceMotion;
  final bool isLoading;

  const _LeaderboardTabContent({
    required this.leaderboardAsync,
    required this.reduceMotion,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header with trophy icon
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AccentColors.gradientFor(context.accentColor),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distance Leaderboard',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Global rankings by reception distance',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Leaderboard content
        _buildLeaderboardList(context),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildLeaderboardList(BuildContext context) {
    return leaderboardAsync.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Skeletonizer(
            enabled: true,
            effect: AppSkeletonConfig.effect(context),
            child: _ReportCard(
              report: ReceptionReport(
                id: 'skeleton_$index',
                aetherFlightId: 'skeleton',
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
}

// =============================================================================
// Stats Card
// =============================================================================

class _StatsCard extends StatelessWidget {
  final AetherStats stats;

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
// Flight Card
// =============================================================================

class _AetherFlightCard extends ConsumerWidget {
  final AetherFlight flight;
  final bool showLiveTracking;
  final bool showActions;

  const _AetherFlightCard({
    required this.flight,
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
            builder: (context) => AetherFlightDetailScreen(flight: flight),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GradientBorderContainer(
          borderRadius: 16,
          borderWidth: flight.isActive ? 2 : 1,
          accentOpacity: flight.isActive ? 0.6 : 0.3,
          enableDepthBlend: flight.isActive,
          depthBlendOpacity: 0.1,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status badge
                  _StatusBadge(flight: flight),
                  const Spacer(),
                  // Flight number
                  Text(
                    flight.flightNumber,
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
                  _AirportCode(code: flight.departure),
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
                              color: flight.isActive
                                  ? context.accentColor
                                  : context.textTertiary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _AirportCode(code: flight.arrival),
                ],
              ),
              const SizedBox(height: 12),
              // Info row
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: context.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(flight.scheduledDeparture.toLocal()),
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
                      flight.nodeName ?? flight.nodeId,
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
              if (flight.receptionCount > 0) ...[
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
                      '${flight.receptionCount} reception${flight.receptionCount != 1 ? 's' : ''}',
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
              if (showLiveTracking && flight.isActive) ...[
                const SizedBox(height: 12),
                _LiveTrackingIndicator(callsign: flight.flightNumber),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AetherFlight flight;

  const _StatusBadge({required this.flight});

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
          if (flight.isActive) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            flight.statusText,
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
    if (flight.isActive) return context.accentColor;
    if (flight.isPast) return context.textTertiary;
    if (flight.isUpcoming) return AppTheme.warningYellow;
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
    final positionAsync = ref.watch(aetherFlightPositionProvider(callsign));

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
  final bool showAction;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
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
            if (showAction && actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
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
