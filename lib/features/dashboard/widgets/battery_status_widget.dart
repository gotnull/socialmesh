import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';

/// Battery Status Widget - Shows device battery and connected node batteries
class BatteryStatusContent extends ConsumerWidget {
  const BatteryStatusContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get our device battery
    final myNode = nodes[myNodeNum];
    final myBattery = myNode?.batteryLevel;

    // Get other nodes with battery info
    final nodesWithBattery =
        nodes.values
            .where((n) => n.nodeNum != myNodeNum && n.batteryLevel != null)
            .toList()
          ..sort(
            (a, b) => (a.batteryLevel ?? 0).compareTo(b.batteryLevel ?? 0),
          );

    final lowBatteryNodes = nodesWithBattery
        .where((n) => n.batteryLevel! < 30)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My device battery
          _DeviceBatteryCard(
            label: 'My Device',
            level: myBattery,
            isMain: true,
          ),
          if (lowBatteryNodes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Low Battery Nodes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            ...lowBatteryNodes
                .take(3)
                .map(
                  (node) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _NodeBatteryRow(node: node),
                  ),
                ),
          ],
          if (nodesWithBattery.isNotEmpty && lowBatteryNodes.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'All ${nodesWithBattery.length} nodes have healthy batteries',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceBatteryCard extends StatelessWidget {
  final String label;
  final int? level;
  final bool isMain;

  const _DeviceBatteryCard({
    required this.label,
    required this.level,
    this.isMain = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayLevel = level != null ? (level! > 100 ? 100 : level!) : null;
    final isCharging = level != null && level! > 100;
    final color = _getBatteryColor(displayLevel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain ? color.withValues(alpha: 0.3) : AppTheme.darkBorder,
        ),
      ),
      child: Row(
        children: [
          _BatteryVisual(level: displayLevel, isCharging: isCharging),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      displayLevel != null ? '$displayLevel%' : '--',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: displayLevel != null
                            ? Colors.white
                            : AppTheme.textTertiary,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (isCharging) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 12,
                              color: AppTheme.primaryGreen,
                            ),
                            Text(
                              'Charging',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int? level) {
    if (level == null) return AppTheme.textTertiary;
    if (level >= 50) return AppTheme.primaryGreen;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _BatteryVisual extends StatelessWidget {
  final int? level;
  final bool isCharging;

  const _BatteryVisual({required this.level, required this.isCharging});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return SizedBox(
      width: 48,
      height: 24,
      child: CustomPaint(
        painter: _BatteryPainter(
          level: level ?? 0,
          color: color,
          isCharging: isCharging,
        ),
      ),
    );
  }

  Color _getColor() {
    if (level == null) return AppTheme.textTertiary;
    if (level! >= 50) return AppTheme.primaryGreen;
    if (level! >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _BatteryPainter extends CustomPainter {
  final int level;
  final Color color;
  final bool isCharging;

  _BatteryPainter({
    required this.level,
    required this.color,
    required this.isCharging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppTheme.darkBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()..color = color;

    // Battery body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width - 4, size.height - 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, borderPaint);

    // Battery tip
    final tipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 4, (size.height - 8) / 2, 4, 8),
      const Radius.circular(1),
    );
    canvas.drawRRect(tipRect, Paint()..color = AppTheme.darkBorder);

    // Fill
    if (level > 0) {
      final fillWidth = (size.width - 8) * (level / 100);
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 4, fillWidth, size.height - 8),
        const Radius.circular(2),
      );
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.color != color;
  }
}

class _NodeBatteryRow extends StatelessWidget {
  final dynamic node;

  const _NodeBatteryRow({required this.node});

  @override
  Widget build(BuildContext context) {
    final level = node.batteryLevel as int;
    final color = level >= 20 ? AppTheme.warningYellow : AppTheme.errorRed;

    return Row(
      children: [
        Icon(
          level >= 20 ? Icons.battery_3_bar : Icons.battery_alert,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            node.displayName as String,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
