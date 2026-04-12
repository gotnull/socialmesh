// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service option card widget for capability or preset selection.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_template.dart';

/// Displays a canonical service type with an optional preset flavor.
class MeshServiceTemplateCard extends StatelessWidget {
  final MeshServiceType canonicalType;
  final MeshServicePresetId? presetId;
  final VoidCallback onTap;

  const MeshServiceTemplateCard({
    super.key,
    required this.canonicalType,
    this.presetId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: canonicalType,
      presetId: presetId,
    );
    final title = meshServiceDisplayName(
      l10n,
      canonicalType: canonicalType,
      presetId: resolved.presetId,
    );
    final description = meshServiceDisplayDescription(
      l10n,
      canonicalType: canonicalType,
      presetId: resolved.presetId,
    );
    final accent = resolved.accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Icon container — 44×44 with accent tint
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(resolved.icon, size: 22, color: accent),
              ),

              const SizedBox(width: AppTheme.spacing12),

              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      description,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppTheme.spacing8),

              // Public badge + chevron
              if (resolved.isPublic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing6,
                    vertical: AppTheme.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: SemanticColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    l10n.meshServicesVisibilityOpen,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: SemanticColors.success,
                    ),
                  ),
                ),

              const SizedBox(width: AppTheme.spacing8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.textTertiary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
