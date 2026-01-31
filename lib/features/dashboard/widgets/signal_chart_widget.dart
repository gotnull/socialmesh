// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import 'dashboard_widget.dart';

/// Signal Strength Chart Widget - Real-time signal quality visualization
class SignalChartContent extends ConsumerWidget {
  const SignalChartContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rssiAsync = ref.watch(currentRssiProvider);
    final snrAsync = ref.watch(currentSnrProvider);
    final channelUtilAsync = ref.watch(currentChannelUtilProvider);

    final rssi = rssiAsync.value;
    final snr = snrAsync.value;
    final channelUtil = channelUtilAsync.value;

    if (rssi == null && snr == null) {
      return const WidgetEmptyState(
        icon: Icons.signal_cellular_off,
        message: 'No signal data available',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Signal bars visualization
          _SignalBars(rssi: rssi ?? -100),
          const SizedBox(height: 16),
          // Metrics row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'RSSI',
                  value: rssi != null ? '${rssi}dBm' : '--',
                  quality: _getRssiQuality(rssi),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'SNR',
                  value: snr != null ? '${snr.toStringAsFixed(1)}dB' : '--',
                  quality: _getSnrQuality(snr),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Ch. Util',
                  value: channelUtil != null
                      ? '${channelUtil.toStringAsFixed(0)}%'
                      : '--',
                  quality: _getUtilQuality(channelUtil),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _getRssiQuality(int? rssi) {
  if (rssi == null) return 'unknown';
  if (rssi >= -60) return 'excellent';
  if (rssi >= -75) return 'good';
  if (rssi >= -85) return 'fair';
  return 'poor';
}

String _getSnrQuality(double? snr) {
  if (snr == null) return 'unknown';
  if (snr >= 7) return 'excellent';
  if (snr >= 0) return 'good';
  if (snr >= -7) return 'fair';
  return 'poor';
}

String _getUtilQuality(double? util) {
  if (util == null) return 'unknown';
  if (util <= 25) return 'excellent';
  if (util <= 50) return 'good';
  if (util <= 75) return 'fair';
  return 'poor';
}

class _SignalBars extends StatelessWidget {
  final int rssi;

  const _SignalBars({required this.rssi});

  @override
  Widget build(BuildContext context) {
    // Convert RSSI to 0-5 bars
    final bars = _rssiToBars(rssi);

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (index) {
          final isActive = index < bars;
          final height = 16.0 + (index * 8);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: height,
              decoration: BoxDecoration(
                color: isActive
                    ? _getBarColor(bars)
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _rssiToBars(int rssi) {
    if (rssi >= -50) return 5;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  Color _getBarColor(int bars) {
    if (bars >= 4) return AccentColors.green;
    if (bars >= 2) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String quality;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor(context, quality);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(BuildContext context, String quality) {
    switch (quality) {
      case 'excellent':
      case 'good':
        return AccentColors.green;
      case 'fair':
        return AppTheme.warningYellow;
      case 'poor':
        return AppTheme.errorRed;
      default:
        return context.textTertiary;
    }
  }
}
