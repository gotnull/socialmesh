import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/app_providers.dart';

class GpsStatusScreen extends ConsumerWidget {
  const GpsStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    // GPS data from node
    final latitude = myNode?.latitude;
    final longitude = myNode?.longitude;
    final altitude = myNode?.altitude;
    final satsInView = myNode?.satsInView;
    final gpsAccuracy = myNode?.gpsAccuracy;
    final groundSpeed = myNode?.groundSpeed;
    final groundTrack = myNode?.groundTrack;
    final precisionBits = myNode?.precisionBits;
    final positionTimestamp = myNode?.positionTimestamp;

    final hasGpsFix =
        latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;

    return GlassScaffold(
      title: 'GPS Status',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // GPS Fix Status Card
              _buildStatusCard(
                context,
                hasGpsFix: hasGpsFix,
                satsInView: satsInView,
              ),

              SizedBox(height: 16),

              // Position Card
              if (hasGpsFix) ...[
                _buildSectionHeader(context, 'Position'),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.my_location,
                        label: 'Latitude',
                        value: '${latitude.toStringAsFixed(6)}°',
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.my_location,
                        label: 'Longitude',
                        value: '${longitude.toStringAsFixed(6)}°',
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.terrain,
                        label: 'Altitude',
                        value: altitude != null ? '${altitude}m' : 'Unknown',
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.gps_fixed,
                        label: 'Accuracy',
                        value: gpsAccuracy != null
                            ? '±${gpsAccuracy}m'
                            : 'Unknown',
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.grid_4x4,
                        label: 'Precision Bits',
                        value: precisionBits?.toString() ?? 'Unknown',
                        context: context,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Motion Card
                _buildSectionHeader(context, 'Motion'),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.speed,
                        label: 'Ground Speed',
                        value: groundSpeed != null
                            ? '$groundSpeed m/s (${(groundSpeed * 3.6).toStringAsFixed(1)} km/h)'
                            : 'Unknown',
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.explore,
                        label: 'Ground Track',
                        value: groundTrack != null
                            ? '$groundTrack° ${_getCardinalDirection(groundTrack)}'
                            : 'Unknown',
                        context: context,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Map Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openInMaps(latitude, longitude),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.map),
                    label: const Text(
                      'Open in Maps',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                // No GPS Fix message
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.gps_off,
                        size: 64,
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No GPS Fix',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The device has not acquired a GPS position yet. '
                        'Make sure the device has a clear view of the sky.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),

              // Satellites Card
              _buildSectionHeader(context, 'Satellites'),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getSatelliteColor(
                              satsInView,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.satellite_alt,
                            color: _getSatelliteColor(satsInView),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                satsInView?.toString() ?? '0',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: _getSatelliteColor(satsInView),
                                ),
                              ),
                              Text(
                                'Satellites in View',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSatelliteBar(satsInView ?? 0, context),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSatelliteLabel(context, 'No Fix', Colors.grey),
                        _buildSatelliteLabel(
                          context,
                          'Poor',
                          AppTheme.errorRed,
                        ),
                        _buildSatelliteLabel(
                          context,
                          'Fair',
                          AppTheme.warningYellow,
                        ),
                        _buildSatelliteLabel(
                          context,
                          'Good',
                          AppTheme.successGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Last Update
              if (positionTimestamp != null) ...[
                _buildSectionHeader(context, 'Last Update'),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: context.accentColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTimestamp(positionTimestamp),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              _timeAgo(positionTimestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required bool hasGpsFix,
    int? satsInView,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasGpsFix ? AppTheme.successGreen : context.border,
          width: hasGpsFix ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (hasGpsFix ? AppTheme.successGreen : context.textTertiary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasGpsFix ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: hasGpsFix ? AppTheme.successGreen : context.textTertiary,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasGpsFix ? 'GPS Fix Acquired' : 'Acquiring GPS...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: hasGpsFix
                        ? AppTheme.successGreen
                        : context.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  hasGpsFix
                      ? '${satsInView ?? 0} satellites in view'
                      : 'Searching for satellites...',
                  style: TextStyle(fontSize: 14, color: context.textTertiary),
                ),
              ],
            ),
          ),
          if (hasGpsFix)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.accentColor, size: 20),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildSatelliteBar(int sats, BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: sats.clamp(0, 12),
            child: Container(
              decoration: BoxDecoration(
                color: _getSatelliteColor(sats),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(flex: (12 - sats).clamp(0, 12), child: const SizedBox()),
        ],
      ),
    );
  }

  Widget _buildSatelliteLabel(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
      ],
    );
  }

  Color _getSatelliteColor(int? sats) {
    if (sats == null || sats == 0) return Colors.grey;
    if (sats < 4) return AppTheme.errorRed;
    if (sats < 6) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }

  String _getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final isToday =
        timestamp.day == now.day &&
        timestamp.month == now.month &&
        timestamp.year == now.year;

    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'Today at $time';
    }

    return '${timestamp.day}/${timestamp.month}/${timestamp.year} $time';
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  void _openInMaps(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
