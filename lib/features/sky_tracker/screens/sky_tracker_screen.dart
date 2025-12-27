import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../models/sky_node.dart';
import '../providers/sky_tracker_providers.dart';
import 'schedule_flight_screen.dart';
import 'sky_node_detail_screen.dart';

/// Main Sky Tracker screen - browse and track Meshtastic nodes in the sky
class SkyTrackerScreen extends ConsumerStatefulWidget {
  const SkyTrackerScreen({super.key});

  @override
  ConsumerState<SkyTrackerScreen> createState() => _SkyTrackerScreenState();
}

class _SkyTrackerScreenState extends ConsumerState<SkyTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _scheduleFlight() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScheduleFlightScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(skyTrackerStatsProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Row(
          children: [
            Icon(
              Icons.flight,
              color: context.accentColor,
              size: 24,
            ),
            SizedBox(width: 8),
            const Text(
              'Sky Tracker',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: context.textSecondary),
            onPressed: _showInfo,
            tooltip: 'About Sky Tracker',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.accentColor,
          labelColor: context.accentColor,
          unselectedLabelColor: context.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flight_takeoff, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Active${stats.activeFlights > 0 ? ' (${stats.activeFlights})' : ''}',
                  ),
                ],
              ),
            ),
            const Tab(text: 'Upcoming'),
            const Tab(text: 'Reports'),
            const Tab(text: 'My Flights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveFlightsTab(),
          _UpcomingFlightsTab(),
          _ReportsTab(),
          _MyFlightsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduleFlight,
        backgroundColor: context.accentColor,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text(
          'Schedule Flight',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Row(
          children: [
            Icon(Icons.flight, color: context.accentColor),
            SizedBox(width: 8),
            Text(
              'Sky Tracker',
              style: TextStyle(color: context.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Meshtastic nodes at altitude!',
              style: TextStyle(
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.flight_takeoff,
              'Schedule your flight with your node',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.radar,
              'Ground stations watch for your signal',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.celebration,
              'Report receptions & set range records!',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: context.accentColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'At 35,000ft, LoRa can reach 400+ km!',
                      style: TextStyle(
                        color: context.accentColor,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: TextStyle(color: context.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.textTertiary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Active flights tab
class _ActiveFlightsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFlights = ref.watch(activeFlightsProvider);

    return activeFlights.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, 'Failed to load active flights'),
      data: (flights) {
        if (flights.isEmpty) {
          return _buildEmpty(
            context,
            icon: Icons.flight_takeoff,
            title: 'No Active Flights',
            subtitle:
                'No Meshtastic nodes currently in the air.\nBe the first to schedule one!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeFlightsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flights.length,
            itemBuilder: (context, index) => _SkyNodeCard(
              skyNode: flights[index],
              showLiveTracking: true,
            ),
          ),
        );
      },
    );
  }
}

/// Upcoming flights tab
class _UpcomingFlightsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skyNodes = ref.watch(skyNodesProvider);

    return skyNodes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, 'Failed to load flights'),
      data: (nodes) {
        // Filter to upcoming only (not active, not past)
        final upcoming =
            nodes.where((n) => !n.isActive && !n.isPast).toList();

        if (upcoming.isEmpty) {
          return _buildEmpty(
            context,
            icon: Icons.schedule,
            title: 'No Upcoming Flights',
            subtitle: 'No flights scheduled yet.\nPlan your next airborne test!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(skyNodesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: upcoming.length,
            itemBuilder: (context, index) => _SkyNodeCard(
              skyNode: upcoming[index],
            ),
          ),
        );
      },
    );
  }
}

/// Reception reports tab (leaderboard)
class _ReportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(recentReportsProvider);

    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, 'Failed to load reports'),
      data: (reports) {
        if (reports.isEmpty) {
          return _buildEmpty(
            context,
            icon: Icons.signal_cellular_alt,
            title: 'No Reports Yet',
            subtitle:
                'Be the first to receive a signal from a sky node\nand report it here!',
          );
        }

        // Sort by distance (longest first) for leaderboard effect
        final sorted = List<ReceptionReport>.from(reports)
          ..sort((a, b) {
            final aD = a.estimatedDistance ?? 0;
            final bD = b.estimatedDistance ?? 0;
            return bD.compareTo(aD);
          });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(recentReportsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _ReportCard(
              report: sorted[index],
              rank: index + 1,
            ),
          ),
        );
      },
    );
  }
}

/// My flights tab
class _MyFlightsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return _buildEmpty(
        context,
        icon: Icons.person_outline,
        title: 'Sign In Required',
        subtitle: 'Sign in to schedule and manage your flights.',
      );
    }

    final myFlights = ref.watch(userSkyNodesProvider(user.uid));

    return myFlights.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildError(context, 'Failed to load your flights'),
      data: (flights) {
        if (flights.isEmpty) {
          return _buildEmpty(
            context,
            icon: Icons.flight,
            title: 'No Flights Scheduled',
            subtitle:
                'You haven\'t scheduled any flights yet.\nTap the button below to add one!',
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(userSkyNodesProvider(user.uid)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flights.length,
            itemBuilder: (context, index) => _SkyNodeCard(
              skyNode: flights[index],
              showActions: true,
            ),
          ),
        );
      },
    );
  }
}

/// Sky node card widget
class _SkyNodeCard extends ConsumerWidget {
  final SkyNode skyNode;
  final bool showLiveTracking;
  final bool showActions;

  const _SkyNodeCard({
    required this.skyNode,
    this.showLiveTracking = false,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkyNodeDetailScreen(skyNode: skyNode),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: skyNode.isActive
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border,
            width: skyNode.isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (skyNode.isActive) ...[
                          _PulsingDot(color: _getStatusColor(context)),
                          SizedBox(width: 4),
                        ],
                        Text(
                          skyNode.statusText,
                          style: TextStyle(
                            color: _getStatusColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Flight number
                  Text(
                    skyNode.flightNumber,
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Route
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
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
                            color: context.border,
                          ),
                          Icon(
                            Icons.flight,
                            color: skyNode.isActive
                                ? context.accentColor
                                : context.textTertiary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _AirportCode(code: skyNode.arrival),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: context.textTertiary),
                  SizedBox(width: 4),
                  Text(
                    dateFormat.format(skyNode.scheduledDeparture.toLocal()),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.memory, size: 14, color: context.textTertiary),
                  SizedBox(width: 4),
                  Text(
                    skyNode.nodeName ?? skyNode.nodeId,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Reception count
            if (skyNode.receptionCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 14,
                      color: context.accentColor,
                    ),
                    SizedBox(width: 4),
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
              ),
            // Live tracking
            if (showLiveTracking && skyNode.isActive)
              _LiveTrackingIndicator(callsign: skyNode.flightNumber),
            const SizedBox(height: 16),
          ],
        ),
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

/// Airport code display
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
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Pulsing dot for active flights
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

/// Live tracking indicator
class _LiveTrackingIndicator extends ConsumerWidget {
  final String callsign;

  const _LiveTrackingIndicator({required this.callsign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(flightPositionProvider(callsign));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.accentColor.withValues(alpha: 0.3),
        ),
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
            SizedBox(width: 8),
            Text(
              'Getting live position...',
              style: TextStyle(
                color: context.accentColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        error: (e, _) => Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: context.textTertiary,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Position unavailable',
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        data: (positionState) {
          if (positionState.position == null) {
            return Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: context.textTertiary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  positionState.error ?? 'Position unavailable',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Icon(Icons.radar, color: context.accentColor, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FL${(positionState.position!.altitudeFeet / 100).round()} • ${positionState.position!.velocityKnots.round()} kts',
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

/// Report card widget
class _ReportCard extends StatelessWidget {
  final ReceptionReport report;
  final int rank;

  const _ReportCard({
    required this.report,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getRankColor(context).withValues(alpha: 0.2),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: _getRankColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        report.flightNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (report.reporterName != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '→ ${report.reporterName}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (report.estimatedDistance != null) ...[
                        Icon(
                          Icons.straighten,
                          size: 14,
                          color: context.accentColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${report.estimatedDistance!.round()} km',
                          style: TextStyle(
                            color: context.accentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 12),
                      ],
                      if (report.rssi != null) ...[
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        SizedBox(width: 4),
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
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
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

// Helper builders
Widget _buildEmpty(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: context.textTertiary),
          SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildError(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
