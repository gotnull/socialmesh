// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Calm "Join mesh canvases" card shown on the MeshCanvas Mesh tab
// while mesh participation is disabled.
//
// Spec anchor: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.2.
//
// IA invariant: when participation is OFF, the Mesh tab MUST hide
// the channel list entirely (locked decision from spec §5.2) and
// render only this single card. No hero, no PRIMARY COMMONS section,
// no OTHER CHANNELS — those surfaces would invite a tap that triggers
// participation as a side-effect, which is the bug this entire
// feature is built to prevent.
//
// Tapping the CTA flips participation on via
// `setParticipationEnabled(true)`. Presence sharing stays off because
// the notifier's invariants do not auto-enable sharing on
// participation-on. The user opts into presence separately via the
// settings sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_participation_providers.dart';

class CanvasParticipationDisabledCard extends ConsumerWidget {
  const CanvasParticipationDisabledCard({super.key});

  Future<void> _enable(WidgetRef ref) async {
    ref.haptics.itemSelect();
    await ref
        .read(meshCanvasParticipationProvider.notifier)
        .setParticipationEnabled(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accent = context.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius20,
        borderWidth: 1.0,
        accentOpacity: 0.14,
        enableDepthBlend: true,
        depthBlendOpacity: 0.04,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                        width: 0.6,
                      ),
                    ),
                    child: Icon(Icons.share_outlined, size: 20, color: accent),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.meshCanvasParticipationCtaTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                            letterSpacing: 0.2,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing6),
                        Text(
                          l.meshCanvasParticipationCtaBody,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                            height: 1.4,
                            letterSpacing: 0.1,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              PrimaryGradientButton(
                key: const ValueKey('mesh-canvas-participation-enable'),
                label: l.meshCanvasParticipationCtaAction,
                icon: Icons.bolt_outlined,
                onPressed: () => _enable(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
