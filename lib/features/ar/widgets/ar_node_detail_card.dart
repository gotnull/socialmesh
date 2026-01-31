// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:socialmesh/core/theme.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ar_engine.dart';

/// Detailed node information card shown when a node is selected
class ARNodeDetailCard extends StatelessWidget {
  final ARWorldNode node;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final bool isFavorite;

  const ARNodeDetailCard({
    super.key,
    required this.node,
    required this.onClose,
    required this.onNavigate,
    required this.onFavorite,
    required this.onShare,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final meshNode = node.node;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getThreatColor(node.threatLevel).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getThreatColor(node.threatLevel).withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(meshNode),

          const Divider(
            color: Color(0xFF00E5FF),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),

          // Stats grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    'DISTANCE',
                    _formatDistance(node.worldPosition.distance),
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatColumn(
                    'BEARING',
                    '${node.worldPosition.bearing.round()}°',
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  child: _buildStatColumn(
                    'ELEVATION',
                    '${node.worldPosition.elevation.toStringAsFixed(1)}°',
                  ),
                ),
              ],
            ),
          ),

          // Detail rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (meshNode.batteryLevel != null)
                  _buildDetailRow(
                    Icons.battery_std,
                    'Battery',
                    '${meshNode.batteryLevel}%',
                    meshNode.batteryLevel! < 20
                        ? const Color(0xFFFF1744)
                        : null,
                  ),
                if (meshNode.snr != null)
                  _buildDetailRow(
                    Icons.signal_cellular_alt,
                    'SNR',
                    '${meshNode.snr!.toStringAsFixed(1)} dB',
                  ),
                if (meshNode.rssi != null)
                  _buildDetailRow(Icons.wifi, 'RSSI', '${meshNode.rssi} dBm'),
                if (meshNode.altitude != null)
                  _buildDetailRow(
                    Icons.terrain,
                    'Altitude',
                    '${meshNode.altitude}m',
                  ),
                if (meshNode.lastHeard != null)
                  _buildDetailRow(
                    Icons.access_time,
                    'Last Heard',
                    _formatTimeAgo(meshNode.lastHeard!),
                  ),
                if (node.isMoving)
                  _buildDetailRow(
                    Icons.speed,
                    'Speed',
                    '${node.velocity.length.toStringAsFixed(1)} m/s',
                    const Color(0xFF00FF88),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (node.isNew) _buildBadge('NEW', const Color(0xFF00FF88)),
                if (node.isMoving)
                  _buildBadge('MOVING', const Color(0xFF448AFF)),
                if (node.threatLevel == ARThreatLevel.warning)
                  _buildBadge('WARNING', const Color(0xFFFFAB00)),
                if (node.threatLevel == ARThreatLevel.critical)
                  _buildBadge('CRITICAL', const Color(0xFFFF1744)),
                if (node.threatLevel == ARThreatLevel.offline)
                  _buildBadge('OFFLINE', const Color(0xFF757575)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navigate',
                    onTap: onNavigate,
                  ),
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  icon: isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? const Color(0xFFFFAB00) : null,
                  onTap: onFavorite,
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.share,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onShare();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic meshNode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Node icon with threat color
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getThreatColor(node.threatLevel).withValues(alpha: 0.2),
              border: Border.all(
                color: _getThreatColor(node.threatLevel),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                meshNode.shortName?.substring(
                      0,
                      math.min(2, meshNode.shortName?.length ?? 0),
                    ) ??
                    '??',
                style: TextStyle(
                  color: _getThreatColor(node.threatLevel),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meshNode.longName ?? meshNode.shortName ?? 'Unknown Node',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '!${meshNode.nodeNum.toRadixString(16).toUpperCase()}',
                  style: TextStyle(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                    fontSize: 12,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
            fontSize: 10,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, [
    Color? valueColor,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? Colors.white54, size: 20),
      ),
    );
  }

  Color _getThreatColor(ARThreatLevel level) {
    switch (level) {
      case ARThreatLevel.normal:
        return const Color(0xFF00E5FF);
      case ARThreatLevel.info:
        return const Color(0xFF00FF88);
      case ARThreatLevel.warning:
        return const Color(0xFFFFAB00);
      case ARThreatLevel.critical:
        return const Color(0xFFFF1744);
      case ARThreatLevel.offline:
        return const Color(0xFF757575);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s ago';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }
}
