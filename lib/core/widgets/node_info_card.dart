// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mesh_models.dart';
import 'app_bottom_sheet.dart';
import '../transport_path.dart';
import '../widgets/gradient_border_container.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import '../l10n/l10n_extension.dart';
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
  final VoidCallback? onTraceroute;
  final VoidCallback? onViewDetails;
  final VoidCallback? onViewHistory;

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
    this.onTraceroute,
    this.onViewDetails,
    this.onViewHistory,
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

  Future<void> _confirmAndExchangePositions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeInfoPositionConfirmTitle,
      message: context.l10n.nodeInfoPositionConfirmMessage(node.displayName),
      confirmLabel: context.l10n.actionSheetSend,
    );
    if (confirmed == true && context.mounted) {
      await _exchangePositions(context, ref);
    }
  }

  Future<void> _confirmShare(BuildContext context) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeInfoShareConfirmTitle,
      message: context.l10n.nodeInfoShareConfirmMessage,
      confirmLabel: context.l10n.nodeInfoShareLocation,
    );
    if (confirmed == true && context.mounted) {
      onShareLocation?.call();
    }
  }

  Future<void> _confirmTraceroute(BuildContext context) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeInfoTracerouteConfirmTitle,
      message: context.l10n.nodeInfoTracerouteConfirmMessage(node.displayName),
      confirmLabel: context.l10n.actionSheetSend,
    );
    if (confirmed == true && context.mounted) {
      onTraceroute?.call();
    }
  }

  Future<void> _exchangePositions(BuildContext context, WidgetRef ref) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestPosition(node.nodeNum);

      if (context.mounted) {
        showInfoSnackBar(
          context,
          context.l10n.positionRequestedFrom(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, context.l10n.failedGeneric('$e'));
      }
    }
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return AppTheme.successGreen;
    if (level > 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _formatLastHeard(BuildContext context, DateTime? lastHeard) {
    final l10n = context.l10n;
    if (lastHeard == null) return l10n.commonNever;
    final diff = DateTime.now().difference(lastHeard);
    if (diff.inMinutes < 1) return l10n.commonJustNow;
    if (diff.inMinutes < 60) {
      return l10n.commonMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.commonHoursAgo(diff.inHours);
    }
    return l10n.commonDaysAgo(diff.inDays);
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
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
              const SizedBox(width: AppTheme.spacing8),
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
                const SizedBox(width: AppTheme.spacing8),
                Icon(Icons.person, size: 14, color: context.accentColor),
              ],
              if (onClose != null) ...[
                const SizedBox(width: AppTheme.spacing8),
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
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.nodeInfoLatitude(
                node.latitude?.toStringAsFixed(4) ??
                    context.l10n.nodeInfoNotAvailable,
              ),
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            Text(
              context.l10n.nodeInfoLongitude(
                node.longitude?.toStringAsFixed(4) ??
                    context.l10n.nodeInfoNotAvailable,
              ),
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _presenceIcon(presence),
                size: 14,
                color: _presenceColor(context, presence),
              ),
              const SizedBox(width: AppTheme.spacing4),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
                        ? node.shortName!.characters
                              .take(2)
                              .toString()
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
              const SizedBox(width: AppTheme.spacing12),
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
                          const SizedBox(width: AppTheme.spacing8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Text(
                              context.l10n.nodeInfoYou,
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
                    const SizedBox(height: AppTheme.spacing4),
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
                          const SizedBox(width: AppTheme.spacing8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
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
                          const SizedBox(width: AppTheme.spacing6),
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
              const SizedBox(width: AppTheme.spacing8),
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
          const SizedBox(height: AppTheme.spacing12),
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
              if (node.viaMqtt)
                NodeStatChip(
                  icon: Icons.cloud,
                  value: classifyTransport(node.viaMqtt).label,
                  color: context.textSecondary,
                ),
              if (node.hopCount != null && node.hopCount! > 0)
                NodeStatChip(
                  icon: Icons.route,
                  value: node.hopCount == 1
                      ? context.l10n.commonHopsSingular(node.hopCount!)
                      : context.l10n.commonHopsPlural(node.hopCount!),
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
                value: _formatLastHeard(context, node.lastHeard),
                color: _presenceColor(context, presence),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Action buttons — all uniform 36×36 icon buttons.
          // Message navigates directly (no confirmation needed).
          // Position and Traceroute send mesh packets and confirm first.
          // Share confirms before opening the system share sheet.
          // Copy, View Details, and View History execute immediately.
          Row(
            children: [
              if (!isMyNode && onMessage != null) ...[
                Tooltip(
                  message: context.l10n.nodeInfoPosition,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: () => _confirmAndExchangePositions(context, ref),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: Center(
                          child: Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoMessage,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.accentColor,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: onMessage,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: const Center(
                          child: Icon(
                            Icons.message,
                            size: 18,
                            color: SemanticColors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (onShareLocation != null) ...[
                if (!isMyNode && onMessage != null)
                  const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoShareLocation,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: () => _confirmShare(context),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                ),
              ],
              if (onCopyCoordinates != null) ...[
                if (onShareLocation != null || (!isMyNode && onMessage != null))
                  const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoCopyCoordinates,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: onCopyCoordinates,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                ),
              ],
              if (onTraceroute != null) ...[
                const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoTraceroute,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: () => _confirmTraceroute(context),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: Center(
                          child: Icon(
                            Icons.route,
                            size: 18,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (onViewDetails != null) ...[
                const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoViewDetails,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: onViewDetails,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: Center(
                          child: Icon(
                            Icons.open_in_new,
                            size: 18,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (onViewHistory != null) ...[
                const SizedBox(width: AppTheme.spacing8),
                Tooltip(
                  message: context.l10n.nodeInfoViewHistory,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      child: InkWell(
                        onTap: onViewHistory,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: Center(
                          child: Icon(
                            Icons.history,
                            size: 18,
                            color: context.textSecondary,
                          ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppTheme.spacing4),
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
