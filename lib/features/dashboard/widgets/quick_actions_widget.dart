// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../core/navigation.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/action_sheets.dart';
import '../../../providers/app_providers.dart';
import '../../../core/transport.dart';
import '../../telemetry/traceroute_log_screen.dart';

/// Quick Actions Widget - Common mesh actions at a glance
class QuickActionsContent extends ConsumerStatefulWidget {
  const QuickActionsContent({super.key});

  @override
  ConsumerState<QuickActionsContent> createState() =>
      _QuickActionsContentState();
}

class _QuickActionsContentState extends ConsumerState<QuickActionsContent>
    with LifecycleSafeMixin<QuickActionsContent> {
  int _tracerouteCooldownRemaining = 0;
  Timer? _tracerouteCooldownTimer;
  int? _lastTracerouteTargetNodeNum;

  static const _tracerouteCooldownSeconds = 30;

  @override
  void dispose() {
    _tracerouteCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    final tracerouteEnabled = isConnected && _tracerouteCooldownRemaining <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // First row: Quick actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.send,
                  label: 'Quick\nMessage',
                  enabled: isConnected,
                  onTap: () => _showQuickMessageSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_on,
                  label: 'Share\nLocation',
                  enabled: isConnected,
                  onTap: () => _shareLocation(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tracerouteCooldownRemaining > 0
                    ? _TracerouteCooldownButton(
                        remaining: _tracerouteCooldownRemaining,
                        total: _tracerouteCooldownSeconds,
                      )
                    : _ActionButton(
                        icon: Icons.route,
                        label: 'Traceroute',
                        enabled: tracerouteEnabled,
                        onTap: () => _showTracerouteSheet(context),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh,
                  label: 'Request\nPositions',
                  enabled: isConnected,
                  onTap: () => _requestPositions(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: SOS button
          _SosButton(enabled: isConnected, onTap: () => _showSosSheet(context)),
        ],
      ),
    );
  }

  void _showSosSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SosSheetContent(ref: ref),
    );
  }

  void _showQuickMessageSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: QuickMessageSheetContent(ref: ref),
    );
  }

  void _shareLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.sendPositionOnce();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Location shared with mesh')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to share location: $e')),
      );
    }
  }

  void _showTracerouteSheet(BuildContext context) async {
    final nodes = ref.read(nodesProvider);
    final messenger = ScaffoldMessenger.of(context);

    final resultNodeNum = await AppBottomSheet.show<int>(
      context: context,
      padding: EdgeInsets.zero,
      child: TracerouteSheetContent(ref: ref),
    );

    if (!mounted) return;

    if (resultNodeNum != null) {
      final targetNode = nodes[resultNodeNum];
      final displayName =
          targetNode?.displayName ?? '!${resultNodeNum.toRadixString(16)}';

      _lastTracerouteTargetNodeNum = resultNodeNum;

      safeSetState(() {
        _tracerouteCooldownRemaining = _tracerouteCooldownSeconds;
      });

      _tracerouteCooldownTimer?.cancel();
      _tracerouteCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        safeSetState(() {
          _tracerouteCooldownRemaining--;
          if (_tracerouteCooldownRemaining <= 0) {
            _tracerouteCooldownRemaining = 0;
            timer.cancel();
            _showTracerouteReadySnackBar();
          }
        });
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Traceroute sent to $displayName — check Traceroute History for results',
          ),
        ),
      );
    }
  }

  void _showTracerouteReadySnackBar() {
    if (!mounted) return;
    final targetNodeNum = _lastTracerouteTargetNodeNum;
    if (targetNodeNum == null) return;

    // Use global variant so the snackbar and its "View" action are safe even
    // if this widget is removed from the tree before the user taps.
    showGlobalActionSnackBar(
      'Traceroute results may be ready',
      actionLabel: 'View',
      onAction: () {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => TraceRouteLogScreen(nodeNum: targetNodeNum),
          ),
        );
      },
      type: SnackBarType.success,
      duration: const Duration(seconds: 6),
    );
  }

  void _requestPositions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Position requests sent to all nodes')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to request positions: $e')),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.accentColor : context.textTertiary;

    return BouncyTap(
      onTap: enabled ? onTap : null,
      scaleFactor: 0.95,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.08)
              : context.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? context.accentColor.withValues(alpha: 0.2)
                : context.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Traceroute button replacement shown during cooldown
class _TracerouteCooldownButton extends StatelessWidget {
  final int remaining;
  final int total;

  const _TracerouteCooldownButton({
    required this.remaining,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: remaining / total,
                    strokeWidth: 1.5,
                    color: context.accentColor.withValues(alpha: 0.4),
                    backgroundColor: context.textTertiary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                Text(
                  '$remaining',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Traceroute',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Emergency SOS button widget - prominently displayed
class _SosButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SosButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: enabled ? onTap : null,
      scaleFactor: 0.97,
      enabled: enabled,
      child: PulseAnimation(
        enabled: enabled,
        minScale: 1.0,
        maxScale: 1.02,
        duration: const Duration(milliseconds: 1500),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? AppTheme.errorRed.withValues(alpha: 0.15)
                : context.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppTheme.errorRed.withValues(alpha: 0.4)
                  : context.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emergency,
                size: 16,
                color: enabled ? AppTheme.errorRed : context.textTertiary,
              ),
              SizedBox(width: 6),
              Text(
                'Emergency SOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppTheme.errorRed : context.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
