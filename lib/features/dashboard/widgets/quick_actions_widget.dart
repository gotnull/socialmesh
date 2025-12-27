import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/action_sheets.dart';
import '../../../providers/app_providers.dart';
import '../../../core/transport.dart';

/// Quick Actions Widget - Common mesh actions at a glance
class QuickActionsContent extends ConsumerWidget {
  const QuickActionsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

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
                  onTap: () => _showQuickMessageSheet(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_on,
                  label: 'Share\nLocation',
                  enabled: isConnected,
                  onTap: () => _shareLocation(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.route,
                  label: 'Traceroute',
                  enabled: isConnected,
                  onTap: () => _showTracerouteSheet(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh,
                  label: 'Request\nPositions',
                  enabled: isConnected,
                  onTap: () => _requestPositions(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: SOS button
          _SosButton(
            enabled: isConnected,
            onTap: () => _showSosSheet(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSosSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SosSheetContent(ref: ref),
    );
  }

  void _showQuickMessageSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: QuickMessageSheetContent(ref: ref),
    );
  }

  void _shareLocation(BuildContext context, WidgetRef ref) async {
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.sendPositionOnce();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Location shared with mesh');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to share location: $e');
      }
    }
  }

  void _showTracerouteSheet(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: TracerouteSheetContent(ref: ref),
    );
  }

  void _requestPositions(BuildContext context, WidgetRef ref) async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Position requests sent to all nodes');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request positions: $e');
      }
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
