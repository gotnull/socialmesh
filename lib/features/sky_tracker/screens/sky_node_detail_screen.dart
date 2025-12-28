import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../models/sky_node.dart';
import '../providers/sky_tracker_providers.dart';
import '../services/sky_tracker_service.dart';

/// Detail screen for a sky node with live tracking and report submission
class SkyNodeDetailScreen extends ConsumerStatefulWidget {
  final SkyNode skyNode;

  const SkyNodeDetailScreen({super.key, required this.skyNode});

  @override
  ConsumerState<SkyNodeDetailScreen> createState() =>
      _SkyNodeDetailScreenState();
}

class _SkyNodeDetailScreenState extends ConsumerState<SkyNodeDetailScreen> {
  final _dateFormat = DateFormat('EEEE, MMM d, yyyy');
  final _timeFormat = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(skyNodeReportsProvider(widget.skyNode.id));
    final positionAsync = ref.watch(
      flightPositionProvider(widget.skyNode.flightNumber),
    );

    return Scaffold(
      backgroundColor: context.background,
      body: CustomScrollView(
        slivers: [
          // App bar with flight info
          SliverAppBar(
            backgroundColor: context.card,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(context, positionAsync),
            ),
            title: Text(
              widget.skyNode.flightNumber,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            actions: [
              if (widget.skyNode.isActive)
                IconButton(
                  icon: Icon(Icons.refresh, color: context.accentColor),
                  onPressed: () => ref.invalidate(
                    flightPositionProvider(widget.skyNode.flightNumber),
                  ),
                  tooltip: 'Refresh position',
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live position card
                if (widget.skyNode.isActive)
                  _buildLivePositionCard(context, positionAsync),

                // Flight details
                _buildDetailsCard(context),

                // Report button
                if (widget.skyNode.isActive)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _reportReception(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentColor,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.signal_cellular_alt,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'I Received This Signal!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                // Reports section
                _buildReportsSection(context, reports),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<FlightPositionState> positionAsync,
  ) {
    final positionState = positionAsync.value;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.accentColor.withValues(alpha: 0.3), context.card],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Route visualization
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAirportDisplay(widget.skyNode.departure, 'Departure'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.flight,
                          color: widget.skyNode.isActive
                              ? context.accentColor
                              : context.textTertiary,
                          size: 32,
                        ),
                        if (positionState?.position != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'FL${(positionState!.position!.altitudeFeet / 100).round()}',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildAirportDisplay(widget.skyNode.arrival, 'Arrival'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAirportDisplay(String code, String label) {
    return Column(
      children: [
        Text(
          code,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLivePositionCard(
    BuildContext context,
    AsyncValue<FlightPositionState> positionAsync,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accentColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AnimatedRadar(color: context.accentColor),
              SizedBox(width: 12),
              Text(
                'Live Position',
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (positionAsync.value?.lastFetch != null)
                Text(
                  'Updated ${_getRelativeTime(positionAsync.value!.lastFetch!)}',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
            ],
          ),
          SizedBox(height: 16),
          positionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                children: [
                  Icon(Icons.cloud_off, color: context.textTertiary, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    style: TextStyle(color: context.textTertiary),
                  ),
                ],
              ),
            ),
            data: (positionState) {
              if (positionState.position == null) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: context.textTertiary,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        positionState.error ?? 'Position data unavailable',
                        style: TextStyle(color: context.textTertiary),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _buildPositionRow(
                    context,
                    Icons.height,
                    'Altitude',
                    '${positionState.position!.altitudeFeet.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ft',
                  ),
                  SizedBox(height: 8),
                  _buildPositionRow(
                    context,
                    Icons.speed,
                    'Ground Speed',
                    '${positionState.position!.velocityKnots.round()} kts',
                  ),
                  const SizedBox(height: 8),
                  _buildPositionRow(
                    context,
                    Icons.explore,
                    'Heading',
                    '${positionState.position!.heading.round()}°',
                  ),
                  const SizedBox(height: 8),
                  _buildPositionRow(
                    context,
                    Icons.radar,
                    'Coverage Radius',
                    '~${positionState.position!.coverageRadiusKm.round()} km',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: context.accentColor,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${positionState.position!.latitude.toStringAsFixed(4)}, ${positionState.position!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            color: context.accentColor,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPositionRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.textTertiary),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flight Details',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.schedule,
            'Departure',
            '${_dateFormat.format(widget.skyNode.scheduledDeparture.toLocal())}\n${_timeFormat.format(widget.skyNode.scheduledDeparture.toLocal())}',
          ),
          if (widget.skyNode.scheduledArrival != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.flight_land,
              'Arrival',
              '${_dateFormat.format(widget.skyNode.scheduledArrival!.toLocal())}\n${_timeFormat.format(widget.skyNode.scheduledArrival!.toLocal())}',
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.memory,
            'Node',
            widget.skyNode.nodeName ?? widget.skyNode.nodeId,
          ),
          if (widget.skyNode.userName != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.person, 'Operator', widget.skyNode.userName!),
          ],
          if (widget.skyNode.notes != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.notes, 'Notes', widget.skyNode.notes!),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.signal_cellular_alt,
            'Receptions',
            '${widget.skyNode.receptionCount} reported',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.textTertiary),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsSection(
    BuildContext context,
    AsyncValue<List<ReceptionReport>> reports,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.signal_cellular_alt,
                color: context.accentColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Reception Reports',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reports.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Error loading reports',
              style: TextStyle(color: AppTheme.errorRed),
            ),
            data: (reportList) {
              if (reportList.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.signal_cellular_0_bar,
                          color: context.textTertiary,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No receptions reported yet',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        if (widget.skyNode.isActive) ...[
                          SizedBox(height: 4),
                          Text(
                            'Be the first to receive this signal!',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: reportList
                    .map((report) => _buildReportTile(context, report))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(BuildContext context, ReceptionReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: context.accentColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.reporterName ?? 'Anonymous',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (report.estimatedDistance != null)
                  Text(
                    '${report.estimatedDistance!.round()} km away',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (report.rssi != null || report.snr != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (report.rssi != null)
                  Text(
                    '${report.rssi!.round()} dBm',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (report.snr != null)
                  Text(
                    'SNR ${report.snr!.toStringAsFixed(1)}',
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _reportReception(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReportBottomSheet(skyNode: widget.skyNode),
    );
  }

  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Animated radar icon
class _AnimatedRadar extends StatefulWidget {
  final Color color;

  const _AnimatedRadar({required this.color});

  @override
  State<_AnimatedRadar> createState() => _AnimatedRadarState();
}

class _AnimatedRadarState extends State<_AnimatedRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              color: widget.color,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double progress;

  _RadarPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = 1.0 - ringProgress;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // Draw center dot
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Bottom sheet for reporting a reception
class _ReportBottomSheet extends ConsumerStatefulWidget {
  final SkyNode skyNode;

  const _ReportBottomSheet({required this.skyNode});

  @override
  ConsumerState<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<_ReportBottomSheet> {
  final _notesController = TextEditingController();
  final _rssiController = TextEditingController();
  final _snrController = TextEditingController();
  bool _isSaving = false;
  final DateTime _receivedAt = DateTime.now();

  @override
  void dispose() {
    _notesController.dispose();
    _rssiController.dispose();
    _snrController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in to report')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(skyTrackerServiceProvider);

      // Get user's location if available
      final myNode = ref.read(myNodeNumProvider);
      final nodes = ref.read(nodesProvider);
      final node = myNode != null ? nodes[myNode] : null;

      double? latitude;
      double? longitude;
      double? estimatedDistance;

      if (node?.latitude != null && node?.longitude != null) {
        latitude = node!.latitude;
        longitude = node.longitude;

        // Calculate distance if flight position is available
        final positionAsync = ref.read(
          flightPositionProvider(widget.skyNode.flightNumber),
        );
        final positionState = positionAsync.value;
        if (positionState?.position != null &&
            latitude != null &&
            longitude != null) {
          estimatedDistance = SkyTrackerService.calculateSlantRange(
            latitude,
            longitude,
            node.altitude?.toDouble() ?? 0,
            positionState!.position!.latitude,
            positionState.position!.longitude,
            positionState.position!.altitude,
          );
        }
      }

      await service.createReport(
        skyNodeId: widget.skyNode.id,
        flightNumber: widget.skyNode.flightNumber,
        reporterId: user.uid,
        reporterName: user.displayName,
        latitude: latitude,
        longitude: longitude,
        rssi: _rssiController.text.isNotEmpty
            ? double.tryParse(_rssiController.text)
            : null,
        snr: _snrController.text.isNotEmpty
            ? double.tryParse(_snrController.text)
            : null,
        estimatedDistance: estimatedDistance,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        receivedAt: _receivedAt,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reception reported! 📡'),
            backgroundColor: context.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: context.accentColor),
                SizedBox(width: 12),
                Text(
                  'Report Reception',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'I received a signal from ${widget.skyNode.flightNumber}!',
              style: TextStyle(color: context.textSecondary),
            ),
            SizedBox(height: 24),

            // Signal info (optional)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rssiController,
                    keyboardType: TextInputType.numberWithOptions(signed: true),
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'RSSI (dBm)',
                      labelStyle: TextStyle(color: context.textSecondary),
                      hintText: '-90',
                      hintStyle: TextStyle(color: context.textTertiary),
                      filled: true,
                      fillColor: context.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _snrController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'SNR (dB)',
                      labelStyle: TextStyle(color: context.textSecondary),
                      hintText: '9.5',
                      hintStyle: TextStyle(color: context.textTertiary),
                      filled: true,
                      fillColor: context.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: 'Equipment used, antenna, location details...',
                hintStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
