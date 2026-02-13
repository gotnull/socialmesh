// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socialmesh/core/logging.dart';

import '../../../core/constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/aether_flight.dart';
import '../providers/aether_providers.dart';
import '../services/aether_service.dart';

/// Detail screen for an Aether flight with live tracking and report submission
class AetherFlightDetailScreen extends ConsumerStatefulWidget {
  final AetherFlight flight;

  const AetherFlightDetailScreen({super.key, required this.flight});

  @override
  ConsumerState<AetherFlightDetailScreen> createState() =>
      _AetherFlightDetailScreenState();
}

class _AetherFlightDetailScreenState
    extends ConsumerState<AetherFlightDetailScreen>
    with LifecycleSafeMixin {
  final _dateFormat = DateFormat('EEEE, MMM d, yyyy');
  final _timeFormat = DateFormat('h:mm a');
  bool _isSharing = false;
  String? _shareId;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(aetherFlightReportsProvider(widget.flight.id));
    final positionAsync = ref.watch(
      aetherFlightPositionProvider(widget.flight.flightNumber),
    );

    return GlassScaffold(
      title: widget.flight.flightNumber,
      actions: [
        if (widget.flight.isActive)
          IconButton(
            icon: Icon(Icons.refresh, color: context.accentColor),
            onPressed: () => ref.invalidate(
              aetherFlightPositionProvider(widget.flight.flightNumber),
            ),
            tooltip: 'Refresh position',
          ),
        _isSharing
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.accentColor,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.share, color: context.accentColor),
                onPressed: () => _shareFlight(context),
                tooltip: 'Share flight',
              ),
      ],
      slivers: [
        // Route header - always visible, no collapse
        SliverToBoxAdapter(child: _buildRouteHeader(context, positionAsync)),
        // Content
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live position card
              if (widget.flight.isActive)
                _buildLivePositionCard(context, positionAsync)
              else
                const SizedBox(height: 16),

              // Flight details
              _buildDetailsCard(context),

              // Report button
              if (widget.flight.isActive)
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
    );
  }

  Widget _buildRouteHeader(
    BuildContext context,
    AsyncValue<FlightPositionState> positionAsync,
  ) {
    final positionState = positionAsync.value;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(bottom: BorderSide(color: context.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAirportDisplay(widget.flight.departure, 'Departure'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.flight,
                  color: widget.flight.isActive
                      ? context.accentColor
                      : context.textTertiary,
                  size: 32,
                ),
                if (positionState?.position != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'FL${(positionState!.position!.altitudeFeet / 100).round()}',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildAirportDisplay(widget.flight.arrival, 'Arrival'),
        ],
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
                            fontFamily: AppTheme.fontFamily,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            '${_dateFormat.format(widget.flight.scheduledDeparture.toLocal())}\n${_timeFormat.format(widget.flight.scheduledDeparture.toLocal())}',
          ),
          if (widget.flight.scheduledArrival != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.flight_land,
              'Arrival',
              '${_dateFormat.format(widget.flight.scheduledArrival!.toLocal())}\n${_timeFormat.format(widget.flight.scheduledArrival!.toLocal())}',
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.memory,
            'Node',
            widget.flight.nodeName ?? widget.flight.nodeId,
          ),
          if (widget.flight.userName != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.person, 'Operator', widget.flight.userName!),
          ],
          if (widget.flight.notes != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.notes, 'Notes', widget.flight.notes!),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.signal_cellular_alt,
            'Receptions',
            '${widget.flight.receptionCount} reported',
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
                        if (widget.flight.isActive) ...[
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
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: _ReportBottomSheet(flight: widget.flight),
    );
  }

  Future<void> _shareFlight(BuildContext _) async {
    HapticFeedback.mediumImpact();

    AppLogging.aether('_shareFlight() called in flight detail screen');
    AppLogging.aether('Flight: ${widget.flight.flightNumber}');
    AppLogging.aether('Already shared? ${_shareId != null}');

    // If already shared, just copy / share the existing URL
    if (_shareId != null) {
      final url = AppUrls.shareFlightUrl(_shareId!);
      AppLogging.aether('Using cached share ID: $_shareId');
      AppLogging.aether('Generated URL: $url');
      await _showShareOptions(url);
      return;
    }

    AppLogging.aether('Starting new share operation...');
    safeSetState(() => _isSharing = true);

    try {
      final shareService = ref.read(aetherShareServiceProvider);
      AppLogging.aether('Calling shareService.shareFlight()...');
      final result = await shareService.shareFlight(widget.flight);

      AppLogging.aether('Share completed successfully');
      AppLogging.aether('Result ID: ${result.id}');
      AppLogging.aether('Result URL: ${result.url}');

      if (!mounted) return;

      safeSetState(() {
        _shareId = result.id;
        _isSharing = false;
      });

      await _showShareOptions(result.url);
    } catch (e) {
      AppLogging.aether('Share failed with error: $e');
      AppLogging.aether('Error type: ${e.runtimeType}');
      safeSetState(() => _isSharing = false);
      if (mounted) {
        showErrorSnackBar(context, 'Could not share flight: $e');
      }
    }
  }

  Future<void> _showShareOptions(String url) async {
    final flight = widget.flight;
    final text =
        '${flight.flightNumber} '
        '${flight.departure} -> ${flight.arrival}\n'
        'Track this Meshtastic flight on Aether:\n$url';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        showSuccessSnackBar(context, 'Flight link copied to clipboard');
      }
    }
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

/// Maximum length for notes field
const int _maxReportNotesLength = 500;

/// Bottom sheet for reporting a reception.
///
/// Auto-detects RSSI, SNR, location, and distance from the mesh — no
/// manual input required. The user just taps "Submit" to confirm.
class _ReportBottomSheet extends ConsumerStatefulWidget {
  final AetherFlight flight;

  const _ReportBottomSheet({required this.flight});

  @override
  ConsumerState<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<_ReportBottomSheet>
    with LifecycleSafeMixin {
  final _notesController = TextEditingController();
  bool _isSaving = false;
  final DateTime _receivedAt = DateTime.now();
  bool _showNotes = false;

  // Auto-detected values
  double? _detectedRssi;
  double? _detectedSnr;
  double? _latitude;
  double? _longitude;
  double? _estimatedDistance;
  String? _reporterNodeId;

  @override
  void initState() {
    super.initState();
    _autoDetectSignalData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Look up the flight's node in the mesh to get RSSI/SNR automatically.
  void _autoDetectSignalData() {
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);

    // Find the flight's node by matching nodeId.
    final flightNodeId = widget.flight.nodeId.replaceAll('!', '').toLowerCase();
    MeshNode? flightNode;
    for (final node in nodes.values) {
      final nodeHex =
          node.userId?.replaceAll('!', '').toLowerCase() ??
          node.nodeNum.toRadixString(16).toLowerCase();
      if (nodeHex == flightNodeId) {
        flightNode = node;
        break;
      }
    }

    // Get signal data from the flight's node.
    if (flightNode != null) {
      _detectedRssi = flightNode.rssi?.toDouble();
      _detectedSnr = flightNode.snr?.toDouble();
    }

    // Get reporter's location from their own node.
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    if (myNode != null) {
      _reporterNodeId = myNode.userId ?? '!${myNode.nodeNum.toRadixString(16)}';
      if (myNode.latitude != null && myNode.longitude != null) {
        _latitude = myNode.latitude;
        _longitude = myNode.longitude;
      }
    }

    // Calculate distance if we have both positions.
    if (_latitude != null && _longitude != null) {
      final positionAsync = ref.read(
        aetherFlightPositionProvider(widget.flight.flightNumber),
      );
      final positionState = positionAsync.value;
      if (positionState?.position != null) {
        _estimatedDistance = AetherService.calculateSlantRange(
          _latitude!,
          _longitude!,
          myNode?.altitude?.toDouble() ?? 0,
          positionState!.position!.latitude,
          positionState.position!.longitude,
          positionState.position!.altitude,
        );
      }
    }
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppLogging.aether('Submit report: user not signed in');
      showSignInRequiredSnackBar(
        context,
        'Sign in to submit a reception report',
      );
      return;
    }

    AppLogging.aether(
      'Submit report: starting for ${widget.flight.flightNumber}',
    );
    AppLogging.aether('  user: ${user.uid} (${user.displayName})');
    AppLogging.aether('  reporterNodeId: $_reporterNodeId');
    AppLogging.aether('  rssi: $_detectedRssi, snr: $_detectedSnr');
    AppLogging.aether('  lat/lon: $_latitude, $_longitude');
    AppLogging.aether('  estimatedDistance: $_estimatedDistance');
    AppLogging.aether('  receivedAt: $_receivedAt');

    safeSetState(() => _isSaving = true);

    try {
      final service = ref.read(aetherServiceProvider);

      final report = await service.createReport(
        flightId: widget.flight.id,
        flightNumber: widget.flight.flightNumber,
        reporterId: user.uid,
        reporterName: user.displayName,
        reporterNodeId: _reporterNodeId,
        latitude: _latitude,
        longitude: _longitude,
        rssi: _detectedRssi,
        snr: _detectedSnr,
        estimatedDistance: _estimatedDistance,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        receivedAt: _receivedAt,
      );

      AppLogging.aether('Submit report: success, id=${report.id}');

      if (mounted) {
        HapticFeedback.mediumImpact();
      }
      safeNavigatorPop();
      safeShowSnackBar('Reception reported!');
    } catch (e, st) {
      AppLogging.aether('Submit report: FAILED - $e');
      AppLogging.aether('Stack trace: $st');
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSignalData = _detectedRssi != null || _detectedSnr != null;
    final hasLocation = _latitude != null && _longitude != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: context.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Report Reception',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'I received a signal from ${widget.flight.flightNumber}!',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 24),

            // Auto-detected signal info (read-only)
            if (hasSignalData)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sensors, color: context.accentColor, size: 20),
                    const SizedBox(width: 12),
                    if (_detectedRssi != null) ...[
                      Text(
                        'RSSI ',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_detectedRssi!.toInt()} dBm',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_detectedRssi != null && _detectedSnr != null)
                      const SizedBox(width: 16),
                    if (_detectedSnr != null) ...[
                      Text(
                        'SNR ',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_detectedSnr!.toStringAsFixed(1)} dB',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            if (hasSignalData) const SizedBox(height: 12),

            // Auto-detected distance
            if (_estimatedDistance != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      color: context.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Estimated distance ',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${_estimatedDistance!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            if (_estimatedDistance != null) const SizedBox(height: 12),

            // Location status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation ? Icons.location_on : Icons.location_off,
                    color: hasLocation
                        ? context.accentColor
                        : context.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasLocation
                        ? 'Location auto-detected'
                        : 'Location unavailable',
                    style: TextStyle(
                      color: hasLocation
                          ? context.textPrimary
                          : context.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Optional notes — matches NodeDex _UserNoteCard pattern
            if (!_showNotes)
              Center(
                child: GestureDetector(
                  onTap: () => safeSetState(() => _showNotes = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Add Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _notesController.clear();
                          safeSetState(() => _showNotes = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Remove',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    maxLength: _maxReportNotesLength,
                    autofocus: true,
                    scrollPadding: const EdgeInsets.all(80),
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    style: TextStyle(fontSize: 14, color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Equipment, antenna, location details...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: context.textTertiary,
                      ),
                      filled: true,
                      fillColor: context.background,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.border.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.border.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.accentColor.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      counterStyle: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

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
