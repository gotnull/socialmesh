// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Instance card widget for the My Services list.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_template.dart';
import '../presentation/mesh_service_presentation.dart';
import 'mesh_service_status_badge.dart';

/// Displays a service instance as a tappable card in the management list.
class MeshServiceInstanceCard extends StatelessWidget {
  final MeshServiceInstance instance;
  final VoidCallback onTap;

  const MeshServiceInstanceCard({
    super.key,
    required this.instance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: instance.canonicalType,
      presetId: instance.presetId,
    );
    final displayName = meshServiceDisplayName(
      l10n,
      canonicalType: instance.canonicalType,
      presetId: instance.presetId,
    );
    final presentation = MeshServicePresentationRegistry.forType(
      instance.canonicalType,
    );
    final accent = resolved.accentColor;
    final isActive = instance.isActive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: isActive
                  ? accent.withValues(alpha: 0.2)
                  : context.border.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isActive ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      resolved.icon,
                      size: 22,
                      color: isActive ? accent : accent.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instance.title,
                          style: context.bodyStyle?.copyWith(
                            color: isActive
                                ? context.textPrimary
                                : context.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Text(
                          presentation.discoveryEyebrow(l10n),
                          style: context.bodySmallStyle?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          displayName,
                          style: context.captionStyle?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(
                        top: AppTheme.spacing6,
                        right: AppTheme.spacing8,
                      ),
                      decoration: const BoxDecoration(
                        color: SemanticColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.textTertiary.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing10),
              presentation.buildLocalSummary(context, l10n, instance),
              const SizedBox(height: AppTheme.spacing10),
              Row(
                children: [
                  MeshServiceStatusBadge(status: instance.effectiveStatus),
                  if (instance.remainingDuration != null &&
                      instance.isActive) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    Icon(Icons.schedule, size: 12, color: context.textTertiary),
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
      ),
    );
  }

  String _formatDuration(Duration duration, dynamic l10n) {
    if (duration.inHours > 0) {
      return l10n.meshServicesDurationHours(duration.inHours) as String;
    }
    return l10n.meshServicesDurationMinutes(duration.inMinutes) as String;
  }
}
