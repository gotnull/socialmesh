// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Status badge widget for mesh service instances.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/mesh_service_instance.dart';

/// Small badge showing the lifecycle status of a service instance.
///
/// Mirrors the tier badge pattern used in Mesh Explorer peer tiles.
class MeshServiceStatusBadge extends StatelessWidget {
  final MeshServiceStatus status;

  const MeshServiceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      MeshServiceStatus.active => (
        l10n.meshServicesStatusActive,
        SemanticColors.success,
      ),
      MeshServiceStatus.stopped => (
        l10n.meshServicesStatusStopped,
        SemanticColors.disabled,
      ),
      MeshServiceStatus.expired => (
        l10n.meshServicesStatusExpired,
        SemanticColors.warning,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
