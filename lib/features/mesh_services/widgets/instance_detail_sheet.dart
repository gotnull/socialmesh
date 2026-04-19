// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared bottom sheet showing a local mesh service instance's details
// with stop + delete actions.
//
// Extracted from the now-removed `MyServicesScreen` so both the SIP Hub
// "Your Services" section and any legacy call site can open the same
// sheet. Purely presentational — business logic (stop/delete) delegates
// to `meshServiceEngineProvider`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_template.dart';
import '../providers/mesh_service_providers.dart';
import 'mesh_service_status_badge.dart';

/// Bottom sheet showing instance details with stop/delete actions.
///
/// Use [show] to present. The sheet pops itself on confirmed stop or
/// delete; callers do not need to coordinate dismissal.
class InstanceDetailSheet extends ConsumerWidget {
  final MeshServiceInstance instance;

  const InstanceDetailSheet({super.key, required this.instance});

  /// Present the sheet via [AppBottomSheet.show].
  static Future<void> show({
    required BuildContext context,
    required MeshServiceInstance instance,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      child: InstanceDetailSheet(instance: instance),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: instance.canonicalType,
      presetId: instance.presetId,
    );
    final accent = resolved.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(resolved.icon, size: 24, color: accent),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instance.title,
                    style: context.titleSmallStyle?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      MeshServiceStatusBadge(status: instance.effectiveStatus),
                      if (instance.remainingDuration != null &&
                          instance.isActive) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          _formatDuration(instance.remainingDuration!, l10n),
                          style: context.bodySmallStyle?.copyWith(
                            color: context.textTertiary,
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

        if (instance.description.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing16),
          Text(
            instance.description,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: AppTheme.spacing24),

        Text(
          l10n.meshServicesActionsLabel.toUpperCase(),
          style: context.bodySmallStyle?.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),

        if (instance.isActive)
          _ActionRow(
            icon: Icons.stop_outlined,
            label: l10n.meshServicesStopAction,
            color: SemanticColors.error,
            onTap: () => _onStop(context, ref),
          ),
        _ActionRow(
          icon: Icons.delete_outline,
          label: l10n.meshServicesDeleteAction,
          color: SemanticColors.error,
          onTap: () => _onDelete(context, ref),
        ),
      ],
    );
  }

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.meshServicesStopConfirm,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.meshServicesCancelAction),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.meshServicesConfirmAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      await haptics.destructive();
      await engine?.stopInstance(instance.instanceId);
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.meshServicesDeleteConfirm,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.meshServicesCancelAction),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.meshServicesConfirmAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      await haptics.destructive();
      await engine?.deleteInstance(instance.instanceId);
    }
  }

  String _formatDuration(Duration duration, dynamic l10n) {
    if (duration.inHours > 0) {
      return l10n.meshServicesDurationHours(duration.inHours) as String;
    }
    return l10n.meshServicesDurationMinutes(duration.inMinutes) as String;
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing10,
            horizontal: AppTheme.spacing4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                label,
                style: context.bodyStyle?.copyWith(
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
