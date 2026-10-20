// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/l10n_extension.dart';
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
      title: context.l10n.gpsStatusTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // GPS Fix Status Card
              _buildStatusCard(
                context,
                hasGpsFix: hasGpsFix,
                satsInView: satsInView,
              ),

              SizedBox(height: AppTheme.spacing16),

              // Position Card
              if (hasGpsFix) ...[
                _buildSectionHeader(
                  context,
                  context.l10n.gpsStatusSectionPosition,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.my_location,
                        label: context.l10n.gpsStatusLatitude,
                        value: context.l10n.gpsStatusLatitudeValue(
                          latitude.toStringAsFixed(6),
                        ),
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.my_location,
                        label: context.l10n.gpsStatusLongitude,
                        value: context.l10n.gpsStatusLongitudeValue(
                          longitude.toStringAsFixed(6),
                        ),
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.terrain,
                        label: context.l10n.gpsStatusAltitude,
                        value: altitude != null
                            ? context.l10n.gpsStatusAltitudeValue(
                                altitude.toString(),
                              )
                            : context.l10n.gpsStatusUnknown,
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.gps_fixed,
                        label: context.l10n.gpsStatusAccuracy,
                        value: gpsAccuracy != null
                            ? context.l10n.gpsStatusAccuracyValue(
                                gpsAccuracy.toString(),
                              )
                            : context.l10n.gpsStatusUnknown,
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.grid_4x4,
                        label: context.l10n.gpsStatusPrecisionBits,
                        value:
                            precisionBits?.toString() ??
                            context.l10n.gpsStatusUnknown,
                        context: context,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppTheme.spacing16),

                // Motion Card
                _buildSectionHeader(
                  context,
                  context.l10n.gpsStatusSectionMotion,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.speed,
                        label: context.l10n.gpsStatusGroundSpeed,
                        value: groundSpeed != null
                            ? context.l10n.gpsStatusGroundSpeedValue(
                                groundSpeed.toString(),
                                (groundSpeed * 3.6).toStringAsFixed(1),
                              )
                            : context.l10n.gpsStatusUnknown,
                        context: context,
                      ),
                      _buildDivider(context),
                      _buildInfoRow(
                        icon: Icons.explore,
                        label: context.l10n.gpsStatusGroundTrack,
                        value: groundTrack != null
                            ? context.l10n.gpsStatusGroundTrackValue(
                                groundTrack.toString(),
                                _getCardinalDirection(context, groundTrack),
                              )
                            : context.l10n.gpsStatusUnknown,
                        context: context,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppTheme.spacing16),

                // Map Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openInMaps(latitude, longitude),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    icon: Icon(Icons.map),
                    label: Text(
                      context.l10n.gpsStatusOpenInMaps,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                // No GPS Fix message
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing32),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.gps_off,
                        size: 64,
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: AppTheme.spacing16),
                      Text(
                        context.l10n.gpsStatusNoGpsFix,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        context.l10n.gpsStatusNoGpsFixMessage,
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

              SizedBox(height: AppTheme.spacing16),

              // Satellites Card
              _buildSectionHeader(
                context,
                context.l10n.gpsStatusSectionSatellites,
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getSatelliteColor(satsInView)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: Icon(
                            Icons.satellite_alt,
                            color: _getSatelliteColor(satsInView),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacing16),
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
                                context.l10n.gpsStatusSatellitesInView,
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
                    SizedBox(height: AppTheme.spacing16),
                    _buildSatelliteBar(satsInView ?? 0, context),
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSatelliteLabel(
                          context,
                          context.l10n.gpsStatusSatNoFix,
                          SemanticColors.disabled,
                        ),
                        _buildSatelliteLabel(
                          context,
                          context.l10n.gpsStatusSatPoor,
                          AppTheme.errorRed,
                        ),
                        _buildSatelliteLabel(
                          context,
                          context.l10n.gpsStatusSatFair,
                          AppTheme.warningYellow,
                        ),
                        _buildSatelliteLabel(
                          context,
                          context.l10n.gpsStatusSatGood,
                          AppTheme.successGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),

              // Last Update
              if (positionTimestamp != null) ...[
                _buildSectionHeader(
                  context,
                  context.l10n.gpsStatusSectionLastUpdate,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: context.accentColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacing14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTimestamp(context, positionTimestamp),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              _timeAgo(context, positionTimestamp),
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

              const SizedBox(height: AppTheme.spacing32),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: hasGpsFix ? AppTheme.successGreen : context.border,
          width: hasGpsFix ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (hasGpsFix ? AppTheme.successGreen : context.textTertiary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius14),
            ),
            child: Icon(
              hasGpsFix ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: hasGpsFix ? AppTheme.successGreen : context.textTertiary,
              size: 28,
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasGpsFix
                      ? context.l10n.gpsStatusFixAcquired
                      : context.l10n.gpsStatusAcquiring,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: hasGpsFix
                        ? AppTheme.successGreen
                        : context.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing4),
                Text(
                  hasGpsFix
                      ? context.l10n.gpsStatusSatellitesCount(satsInView ?? 0)
                      : context.l10n.gpsStatusSearchingSatellites,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
          if (hasGpsFix)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Text(
                context.l10n.gpsStatusActiveBadge,
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
          SizedBox(width: AppTheme.spacing12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.textSecondary),
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
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: sats.clamp(0, 12),
            child: Container(
              decoration: BoxDecoration(
                color: _getSatelliteColor(sats),
                borderRadius: BorderRadius.circular(AppTheme.radius4),
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
            borderRadius: BorderRadius.circular(AppTheme.radius2),
          ),
        ),
        SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }

  Color _getSatelliteColor(int? sats) {
    if (sats == null || sats == 0) return SemanticColors.disabled;
    if (sats < 4) return AppTheme.errorRed;
    if (sats < 6) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }

  String _getCardinalDirection(BuildContext context, double degrees) {
    final directions = [
      context.l10n.gpsStatusCardinalN,
      context.l10n.gpsStatusCardinalNE,
      context.l10n.gpsStatusCardinalE,
      context.l10n.gpsStatusCardinalSE,
      context.l10n.gpsStatusCardinalS,
      context.l10n.gpsStatusCardinalSW,
      context.l10n.gpsStatusCardinalW,
      context.l10n.gpsStatusCardinalNW,
    ];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final isToday =
        timestamp.day == now.day &&
        timestamp.month == now.month &&
        timestamp.year == now.year;

    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    if (isToday) {
      return context.l10n.gpsStatusTodayAt(time);
    }

    return context.l10n.gpsStatusDateAt(
      '${timestamp.day}/${timestamp.month}/${timestamp.year}',
      time,
    );
  }

  String _timeAgo(BuildContext context, DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) {
      return context.l10n.gpsStatusSecondsAgo(diff.inSeconds);
    } else if (diff.inMinutes < 60) {
      return context.l10n.gpsStatusMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return context.l10n.gpsStatusHoursAgo(diff.inHours);
    } else {
      return context.l10n.gpsStatusDaysAgo(diff.inDays);
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
