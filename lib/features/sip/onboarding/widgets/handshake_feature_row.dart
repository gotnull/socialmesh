// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// A centered, wrapping row of capability chips for a page's feature list.
// Degrades cleanly to multiple lines on narrow screens.

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../handshake_onboarding_models.dart';

/// Wrapping row of icon + label capability chips.
class HandshakeFeatureRow extends StatelessWidget {
  const HandshakeFeatureRow({
    super.key,
    required this.accent,
    required this.features,
  });

  final Color accent;
  final List<HandshakeFeature> features;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: [
        for (final feature in features)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(feature.icon, size: 15, color: accent),
                const SizedBox(width: AppTheme.spacing6),
                Text(
                  feature.label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
