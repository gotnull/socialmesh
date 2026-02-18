// SPDX-License-Identifier: GPL-3.0-or-later

// Aether Main Screen — track Meshtastic nodes at altitude.
//
// Enables users to schedule flights with their mesh nodes, track active flights,
// view reception reports, and compete on a leaderboard for longest range contacts.
//
// Layout:
// - Glass app bar with title, schedule button, leaderboard button, overflow menu
// - Stats card, filter chips, searchable flight list (Firestore)
// - Leaderboard: accessible via app bar trophy button as scrollable modal
//
// Firebase-backed with real-time streams and OpenSky Network integration
// for live flight position tracking.

import 'dart:async';
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
import '../../../core/widgets/animated_gold_button.dart';
import '../../../core/widgets/animated_gradient_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../providers/help_providers.dart';
import '../../../core/widgets/search_filter_header.dart';

import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/aether_flight.dart';
import '../providers/aether_providers.dart';
import '../data/airports.dart';
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
    with LifecycleSafeMixin<AetherScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AetherFilter _currentFilter = AetherFilter.all;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFlightDetail(AetherFlight flight) {
    AppLogging.aether(
      'Opening flight detail: ${flight.flightNumber} (${flight.id})',
    );
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
    // Check if connected node already has an active or upcoming flight.
    final myNodeNum = ref.read(myNodeNumProvider);
    AppLogging.aether('Schedule gate: myNodeNum=$myNodeNum');
    if (myNodeNum != null) {
      final nodes = ref.read(nodesProvider);
      final myNode = nodes[myNodeNum];
      AppLogging.aether(
        'Schedule gate: myNode=${myNode?.displayName}, '
        'userId=${myNode?.userId}, nodeNum=${myNode?.nodeNum}',
      );
      if (myNode != null) {
        final nodeId = myNode.userId ?? '!${myNode.nodeNum.toRadixString(16)}';
        final normalizedNodeId = nodeId.trim().toLowerCase().replaceFirst(
          '!',
          '',
        );
        AppLogging.aether(
          'Schedule gate: nodeId=$nodeId, normalized=$normalizedNodeId',
        );

        // Merge both providers: aetherFlightsProvider has a 12h cutoff,
        // aetherActiveFlightsProvider has no cutoff but only isActive.
        // A flight that departed >12h ago only appears in the active provider.
        final recentFlights =
            ref.read(aetherFlightsProvider).asData?.value ?? [];
        final activeFlights =
            ref.read(aetherActiveFlightsProvider).asData?.value ?? [];
        final mergedById = <String, AetherFlight>{};
        for (final f in recentFlights) {
          mergedById[f.id] = f;
        }
        for (final f in activeFlights) {
          mergedById.putIfAbsent(f.id, () => f);
        }
        final flights = mergedById.values.toList();
        AppLogging.aether(
          'Schedule gate: ${recentFlights.length} recent + '
          '${activeFlights.length} active = ${flights.length} merged',
        );
        for (final f in flights) {
          final n = f.nodeId.trim().toLowerCase().replaceFirst('!', '');
          AppLogging.aether(
            'Schedule gate: flight=${f.flightNumber}, '
            'nodeId="${f.nodeId}", normalized="$n", '
            'isPast=${f.isPast}, isActive=${f.isActive}, '
            'match=${n == normalizedNodeId}',
          );
        }

        final conflicting = flights.where((f) {
          final n = f.nodeId.trim().toLowerCase().replaceFirst('!', '');
          return n == normalizedNodeId && !f.isPast;
        });
        AppLogging.aether(
          'Schedule gate: ${conflicting.length} conflicting flights',
        );
        if (conflicting.isNotEmpty) {
          final existing = conflicting.first;
          HapticFeedback.heavyImpact();
          showWarningSnackBar(
            context,
            '${myNode.displayName} already has a flight '
            '(${existing.flightNumber} — ${existing.statusText})',
          );
          return;
        }
      }
    }

    AppLogging.aether('Navigating to schedule flight screen');
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleFlightScreen()),
    );
  }

  void _showInfo() {
    AppLogging.aether('Showing Aether info sheet');
    final accentColor = context.accentColor;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textTertiary;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Aether',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Track Meshtastic nodes at altitude!',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
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

  /// Builds the leaderboard button for the app bar.
  Widget _buildLeaderboardButton(BuildContext context) {
    return AnimatedGoldIconButton(
      icon: Icons.emoji_events,
      tooltip: 'Leaderboard',
      onPressed: _showLeaderboard,
    );
  }

  /// Shows the leaderboard in a scrollable bottom sheet.
  void _showLeaderboard() {
    AppLogging.aether('Showing leaderboard modal');
    HapticFeedback.selectionClick();
    final leaderboardAsync = ref.read(aetherGlobalLeaderboardProvider);
    final reduceMotion = ref.read(reduceMotionEnabledProvider);

    AppBottomSheet.show(
      context: context,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: _LeaderboardModalContent(
          leaderboardAsync: leaderboardAsync,
          reduceMotion: reduceMotion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flightsAsync = ref.watch(aetherFlightsProvider);
    final activeFlightsAsync = ref.watch(aetherActiveFlightsProvider);
    final stats = ref.watch(aetherStatsProvider);
    final user = ref.watch(currentUserProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    final isLoading =
        flightsAsync is AsyncLoading || activeFlightsAsync is AsyncLoading;

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
              _buildLeaderboardButton(context),
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
          ),
          body: _FlightsTabContent(
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
    // Merge Firestore flights (12h window) with active flights so flights
    // that exceed the 12h departure cutoff still appear when active.
    final recentFlights = flightsAsync.value ?? [];
    final activeFlights = activeFlightsAsync.value ?? [];
    final mergedById = <String, AetherFlight>{};
    for (final f in recentFlights) {
      mergedById[f.id] = f;
    }
    for (final f in activeFlights) {
      mergedById.putIfAbsent(f.id, () => f);
    }
    final allFlights = mergedById.values.toList()
      ..sort((a, b) => a.scheduledDeparture.compareTo(b.scheduledDeparture));

    final upcomingCount = allFlights
        .where((f) => !f.isActive && !f.isPast)
        .length;
    final myFlightsCount = user != null
        ? allFlights.where((f) => f.userId == user!.uid).length
        : 0;

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
              allFlights.length,
              stats.activeFlights,
            ]),
            filterChips: [
              SectionFilterChip(
                label: 'All',
                count: allFlights.length,
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
                count: upcomingCount,
                isSelected: currentFilter == AetherFilter.upcoming,
                color: AccentColors.cyan,
                icon: Icons.schedule,
                onTap: () => onFilterChanged(AetherFilter.upcoming),
              ),
              SectionFilterChip(
                label: 'My Flights',
                count: myFlightsCount,
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
    // Show skeleton cards while data is loading for the first time.
    if (isLoading && !flightsAsync.hasValue) {
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

    // Merge recent + active flights (same dedup as build())
    final recentFlights = flightsAsync.value ?? [];
    final activeFlightsList = activeFlightsAsync.value ?? [];
    final mergedById = <String, AetherFlight>{};
    for (final f in recentFlights) {
      mergedById[f.id] = f;
    }
    for (final f in activeFlightsList) {
      mergedById.putIfAbsent(f.id, () => f);
    }
    final allFlights = mergedById.values.toList()
      ..sort((a, b) => a.scheduledDeparture.compareTo(b.scheduledDeparture));

    List<AetherFlight> filteredFlights;

    switch (currentFilter) {
      case AetherFilter.all:
        filteredFlights = allFlights;
        break;
      case AetherFilter.active:
        filteredFlights = allFlights
            .where((f) => f.isActive || f.isInFlight)
            .toList();
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
        final depAirport = lookupAirport(flight.departure);
        final arrAirport = lookupAirport(flight.arrival);
        return flight.flightNumber.toLowerCase().contains(query) ||
            flight.departure.toLowerCase().contains(query) ||
            flight.arrival.toLowerCase().contains(query) ||
            (depAirport?.city.toLowerCase().contains(query) ?? false) ||
            (depAirport?.name.toLowerCase().contains(query) ?? false) ||
            (arrAirport?.city.toLowerCase().contains(query) ?? false) ||
            (arrAirport?.name.toLowerCase().contains(query) ?? false) ||
            (flight.nodeName?.toLowerCase().contains(query) ?? false) ||
            flight.nodeId.toLowerCase().contains(query);
      }).toList();
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
// Leaderboard Modal Content
// =============================================================================

class _LeaderboardModalContent extends StatelessWidget {
  final AsyncValue<List<ReceptionReport>> leaderboardAsync;
  final bool reduceMotion;

  const _LeaderboardModalContent({
    required this.leaderboardAsync,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with trophy icon
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
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

        // Leaderboard content
        Expanded(child: _buildLeaderboardList(context)),
      ],
    );
  }

  Widget _buildLeaderboardList(BuildContext context) {
    return leaderboardAsync.when(
      loading: () => ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => Skeletonizer(
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
      ),
      error: (e, _) => _EmptyState(
        icon: Icons.error_outline,
        title: 'Error Loading Leaderboard',
        subtitle: 'Pull to refresh and try again.',
      ),
      data: (leaderboard) {
        if (leaderboard.isEmpty) {
          return _EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Leaderboard Empty',
            subtitle:
                'Be the first to report a reception from a sky node and claim the top spot!',
          );
        }

        return ListView.builder(
          itemCount: leaderboard.length,
          itemBuilder: (context, index) {
            return _StaggeredListTile(
              index: index,
              reduceMotion: reduceMotion,
              child: _ReportCard(report: leaderboard[index], rank: index + 1),
            );
          },
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
  final bool showActions;

  const _AetherFlightCard({required this.flight, this.showActions = false});

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
          borderWidth:
              ((flight.isActive || flight.isInFlight) && !flight.isPast)
              ? 2
              : 1,
          accentOpacity:
              ((flight.isActive || flight.isInFlight) && !flight.isPast)
              ? 0.6
              : 0.3,
          enableDepthBlend:
              (flight.isActive || flight.isInFlight) && !flight.isPast,
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
                              color: (flight.isActive && !flight.isPast)
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
          if ((flight.isActive || flight.isInFlight) && !flight.isPast) ...[
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
    if (flight.isPast) return context.textTertiary;
    if (flight.isActive || flight.isInFlight) return context.accentColor;
    if (flight.isUpcoming) return AppTheme.warningYellow;
    return context.textSecondary;
  }
}

class _AirportCode extends StatelessWidget {
  final String code;

  const _AirportCode({required this.code});

  @override
  Widget build(BuildContext context) {
    final airport = lookupAirport(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (airport != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                airport.city,
                style: TextStyle(color: context.textSecondary, fontSize: 10),
              ),
            ),
        ],
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
// Report Card
// =============================================================================

/// Rank badge with sparkles for #1 position
class _RankBadge extends StatefulWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge> with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  Timer? _sparkleTimer;
  final List<_Sparkle> _sparkles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    if (widget.rank == 1) {
      _sparkleController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _scheduleNextSparkle();
    }
  }

  @override
  void dispose() {
    if (widget.rank == 1) {
      _sparkleTimer?.cancel();
      _sparkleController.dispose();
    }
    super.dispose();
  }

  void _scheduleNextSparkle() {
    final delay = Duration(milliseconds: 1500 + _random.nextInt(2500));
    _sparkleTimer?.cancel();
    _sparkleTimer = Timer(delay, () {
      if (mounted) {
        _triggerSparkles();
        _scheduleNextSparkle();
      }
    });
  }

  void _triggerSparkles() {
    setState(() {
      _sparkles.clear();
      final count = 3 + _random.nextInt(4);
      for (int i = 0; i < count; i++) {
        final xPos = _random.nextDouble();
        final yPos = _random.nextDouble();
        _sparkles.add(
          _Sparkle(
            xPos: xPos,
            yPos: yPos,
            delay: _random.nextInt(300),
            size: 4 + _random.nextDouble() * 6,
          ),
        );
      }
    });
    _sparkleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rank == 1) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [_buildBadgeContainer(context), ..._buildSparkles()],
        ),
      );
    }

    return _buildBadgeContainer(context);
  }

  Widget _buildBadgeContainer(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.rank <= 3
            ? LinearGradient(
                colors: [
                  _getRankColor(context),
                  _getRankColor(context).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: widget.rank > 3
            ? _getRankColor(context).withValues(alpha: 0.2)
            : null,
      ),
      child: Center(
        child: Text(
          '#${widget.rank}',
          style: TextStyle(
            color: widget.rank <= 3 ? Colors.white : _getRankColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    return _sparkles.map((sparkle) {
      return AnimatedBuilder(
        animation: _sparkleController,
        builder: (context, child) {
          final delayProgress =
              ((_sparkleController.value * 1000 - sparkle.delay) / 500).clamp(
                0.0,
                1.0,
              );

          final opacity = delayProgress < 0.5
              ? delayProgress * 2
              : (1 - delayProgress) * 2;

          final scale = delayProgress < 0.5
              ? 0.5 + delayProgress
              : 1.5 - delayProgress;

          if (opacity <= 0) return const SizedBox.shrink();

          return Positioned(
            left: sparkle.xPos * 40 - sparkle.size / 2,
            top: sparkle.yPos * 40 - sparkle.size / 2,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: _buildSparkleStar(sparkle.size),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildSparkleStar(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: Colors.white)),
    );
  }

  Color _getRankColor(BuildContext context) {
    switch (widget.rank) {
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

/// Sparkle data class shared with AnimatedGoldIconButton
class _Sparkle {
  final double xPos;
  final double yPos;
  final int delay;
  final double size;

  _Sparkle({
    required this.xPos,
    required this.yPos,
    required this.delay,
    required this.size,
  });
}

/// Sparkle painter shared with AnimatedGoldIconButton
class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.3;

    for (int i = 0; i < 8; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi / 4) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReportCard extends StatelessWidget {
  final ReceptionReport report;
  final int rank;

  const _ReportCard({required this.report, required this.rank});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mma');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Rank badge with sparkles for #1
              _RankBadge(rank: rank),
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
                        if (report.reporterNodeName != null ||
                            report.reporterNodeId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.reporterNodeName ??
                                  report.reporterNodeId ??
                                  '',
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
                        const Spacer(),
                        Text(
                          dateFormat.format(report.receivedAt.toLocal()),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
