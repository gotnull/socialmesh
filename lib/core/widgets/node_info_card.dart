// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mesh_models.dart';
import '../widgets/gradient_border_container.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import '../theme.dart';

/// Reusable node information card widget
/// Displays node details with actions like messaging, position exchange, etc.
class NodeInfoCard extends ConsumerWidget {
  final MeshNode node;
  final bool isMyNode;
  final VoidCallback? onClose;
  final VoidCallback? onMessage;
  final double? distanceFromMe;
  final double? bearingFromMe;
  final VoidCallback? onShareLocation;
  final VoidCallback? onCopyCoordinates;

  /// If true, shows a compact version without action buttons
  final bool compact;

  const NodeInfoCard({
    super.key,
    required this.node,
    this.isMyNode = false,
    this.onClose,
    this.onMessage,
    this.distanceFromMe,
    this.bearingFromMe,
    this.onShareLocation,
    this.onCopyCoordinates,
    this.compact = false,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${km.round()}km';
    }
  }

  String _formatBearing(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return '${bearing.round()}° ${directions[index]}';
  }

  Future<void> _exchangePositions(BuildContext context, WidgetRef ref) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestPosition(node.nodeNum);

      if (context.mounted) {
        showInfoSnackBar(
          context,
          'Position requested from ${node.displayName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    }
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return AppTheme.successGreen;
    if (level > 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _formatLastHeard(DateTime? lastHeard) {
    if (lastHeard == null) return 'Never';
    final diff = DateTime.now().difference(lastHeard);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
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

  IconData _presenceIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.wifi;
      case PresenceConfidence.fading:
        return Icons.wifi_tethering;
      case PresenceConfidence.stale:
        return Icons.wifi_off;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return _buildCompact(context, ref);
    }
    return _buildFull(context, ref);
  }

  Widget _buildCompact(BuildContext context, WidgetRef ref) {
    final presenceMap = ref.watch(presenceMapProvider);
    final presence = presenceConfidenceFor(presenceMap, node);
    final lastHeardAge = lastHeardAgeFor(presenceMap, node);
    return GradientBorderContainer(
      borderRadius: 12,
      borderWidth: 2,
      accentOpacity: 0.4,
      backgroundColor: context.card.withAlpha(230),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(node.avatarColor ?? 0xFF42A5F5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  node.displayName,
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMyNode) ...[
                const SizedBox(width: 8),
                Icon(Icons.person, size: 14, color: context.accentColor),
              ],
              if (onClose != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: context.textTertiary,
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
          if (node.hasPosition) ...[
            const SizedBox(height: 8),
            Text(
              'Lat: ${node.latitude?.toStringAsFixed(4) ?? 'N/A'}°',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            Text(
              'Lon: ${node.longitude?.toStringAsFixed(4) ?? 'N/A'}°',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _presenceIcon(presence),
                size: 14,
                color: _presenceColor(context, presence),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: kPresenceInferenceTooltip,
                child: Text(
                  presenceStatusText(presence, lastHeardAge),
                  style: TextStyle(
                    color: _presenceColor(context, presence),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context, WidgetRef ref) {
    final presenceMap = ref.watch(presenceMapProvider);
    final presence = presenceConfidenceFor(presenceMap, node);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Node avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (node.shortName != null && node.shortName!.isNotEmpty)
                        ? node.shortName!
                              .substring(0, math.min(2, node.shortName!.length))
                              .toUpperCase()
                        : '??',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: SemanticColors.onBrand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyNode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          node.userId ?? '!${node.nodeNum.toRadixString(16)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                        if (distanceFromMe != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDistance(distanceFromMe!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.accentColor,
                            ),
                          ),
                        ],
                        if (bearingFromMe != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatBearing(bearingFromMe!),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Close button
              if (onClose != null)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: context.textTertiary,
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (node.batteryLevel != null)
                NodeStatChip(
                  icon: Icons.battery_full,
                  value: '${node.batteryLevel}%',
                  color: _getBatteryColor(node.batteryLevel!),
                ),
              if (node.snr != null)
                NodeStatChip(
                  icon: Icons.signal_cellular_alt,
                  value: '${node.snr} dB',
                  color: context.textSecondary,
                ),
              if (node.altitude != null)
                NodeStatChip(
                  icon: Icons.terrain,
                  value: '${node.altitude}m',
                  color: context.textSecondary,
                ),
              if (node.hardwareModel != null)
                NodeStatChip(
                  icon: Icons.memory,
                  value: node.hardwareModel!,
                  color: context.textSecondary,
                ),
              // Last heard
              NodeStatChip(
                icon: Icons.access_time,
                value: _formatLastHeard(node.lastHeard),
                color: _presenceColor(context, presence),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons: all in a single row — flexible text buttons
          // followed by fixed-size icon buttons. Flexible ensures the text
          // buttons shrink gracefully on narrow devices (Nothing Phone,
          // older iPhones, small Androids) without render overflow.
          // Position and Message are hidden for our own node since they
          // serve no purpose there.
          Row(
            children: [
              if (!isMyNode && onMessage != null) ...[
                Flexible(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _exchangePositions(context, ref),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text(
                        'Position',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.accentColor,
                        side: BorderSide(
                          color: context.accentColor.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text(
                        'Message',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentColor,
                        foregroundColor: SemanticColors.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (onShareLocation != null) ...[
                if (!isMyNode && onMessage != null) const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Material(
                    color: context.background,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onShareLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Icon(
                          Icons.share,
                          size: 18,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (onCopyCoordinates != null) ...[
                if (onShareLocation != null || (!isMyNode && onMessage != null))
                  const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Material(
                    color: context.background,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onCopyCoordinates,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Icon(
                          Icons.copy,
                          size: 18,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat chip for displaying node statistics
class NodeStatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const NodeStatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
