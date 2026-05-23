// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas first-run participation onboarding sheet.
//
// Spec anchor: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.1.
//
// Surfaces via [showCanvasParticipationOnboardingSheet] when the
// MeshCanvas overview screen mounts with `onboardingSeen == false`.
// Explains the three participation tiers (Local sandbox, Mesh
// canvases, optional Presence) in three icon + title + body rows,
// then offers two CTAs anchored to the sheet footer:
//
//   - "Explore locally" (outline, secondary) → chooseLocalOnly().
//     Persists onboardingSeen=true with participation + sharing off.
//   - "Join MeshCanvas" (filled gradient, primary) → joinMeshCanvas().
//     Persists onboardingSeen=true + participation=true; sharing
//     stays off until the user enables it in the settings sheet (per
//     spec §5.5 — keeps the first-run flow cleanest).
//
// Sheet uses AppBottomSheet.showScrollable (content-heavy variant).
// Title + footer are pinned by AppBottomSheet itself; the body is
// the three explainer rows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_participation_providers.dart';

/// Show the MeshCanvas first-run onboarding sheet. Returns when the
/// sheet dismisses. The notifier mutation (chooseLocalOnly or
/// joinMeshCanvas) is performed BEFORE the pop so the host screen
/// rebuilds with the correct state on the next frame.
Future<void> showCanvasParticipationOnboardingSheet({
  required BuildContext context,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    // Sheet height hugs the content (three explainer rows + intro +
    // footer buttons). The body shrink-wraps; bumping initialChildSize
    // higher leaves dead vertical space below the last row, which
    // reads as unfinished design rather than content-heavy.
    initialChildSize: 0.62,
    minChildSize: 0.5,
    maxChildSize: 0.85,
    title: context.l10n.meshCanvasOnboardingTitle,
    // Footer pins the action row at the sheet bottom so both CTAs sit
    // exactly above the home indicator. Buttons share identical
    // height + radius + typography so the pair reads as a balanced
    // primary/secondary action — never a "one big, one small".
    footer: const _CanvasParticipationOnboardingFooter(),
    builder: (controller) =>
        _CanvasParticipationOnboardingSheet(scrollController: controller),
  );
}

class _CanvasParticipationOnboardingSheet extends StatelessWidget {
  final ScrollController scrollController;

  const _CanvasParticipationOnboardingSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // SingleChildScrollView + Column eagerly builds every row so widget
    // tests + accessibility scanners see all three explainers even when
    // one would otherwise be off-viewport. ListView's lazy SliverList
    // would skip the third row at the current sheet height. The
    // scrollable wrapper still handles short-screen overflow.
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        0,
        AppTheme.spacing24,
        AppTheme.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.meshCanvasOnboardingIntro,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
              height: 1.4,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          _OnboardingRow(
            icon: Icons.smartphone_outlined,
            title: l.meshCanvasOnboardingRowLocalTitle,
            body: l.meshCanvasOnboardingRowLocalBody,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _OnboardingRow(
            icon: Icons.share_outlined,
            title: l.meshCanvasOnboardingRowMeshTitle,
            body: l.meshCanvasOnboardingRowMeshBody,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _OnboardingRow(
            icon: Icons.visibility_outlined,
            title: l.meshCanvasOnboardingRowPresenceTitle,
            body: l.meshCanvasOnboardingRowPresenceBody,
          ),
        ],
      ),
    );
  }
}

/// Pinned footer: balanced action pair. Both buttons share the same
/// height, border radius, typography, and weight so they read as a
/// secondary/primary CHOICE — never "one big, one small". The
/// secondary button is a flat surface fill (not an outline) because
/// outline buttons next to filled gradient buttons always read
/// lighter visually regardless of equal padding.
class _CanvasParticipationOnboardingFooter extends ConsumerWidget {
  const _CanvasParticipationOnboardingFooter();

  Future<void> _chooseLocal(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    ref.haptics.itemSelect();
    await ref.read(meshCanvasParticipationProvider.notifier).chooseLocalOnly();
    if (!navigator.mounted) return;
    navigator.pop();
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    ref.haptics.itemSelect();
    await ref.read(meshCanvasParticipationProvider.notifier).joinMeshCanvas();
    if (!navigator.mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _SecondaryActionButton(
            key: const ValueKey('mesh-canvas-onboarding-explore'),
            label: l.meshCanvasOnboardingActionExplore,
            icon: Icons.smartphone_outlined,
            onPressed: () => _chooseLocal(context, ref),
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: PrimaryGradientButton(
            key: const ValueKey('mesh-canvas-onboarding-join'),
            label: l.meshCanvasOnboardingActionJoin,
            icon: Icons.share_outlined,
            onPressed: () => _join(context, ref),
          ),
        ),
      ],
    );
  }
}

/// Secondary action whose footprint matches [PrimaryGradientButton]
/// exactly — same vertical padding (spacing16), same border radius
/// (radius16), same font size (15 / w700). The fill is a faint card
/// surface instead of the accent gradient so it reads as the calmer
/// option without shrinking the touch target.
class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _SecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: context.border.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: context.textPrimary),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single explainer row: leading icon avatar + title + body. The icon
/// sits inside a faint accent-tinted square so the rows read as a
/// triad of clearly-bounded cards without adding card chrome.
class _OnboardingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 0.6,
            ),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  letterSpacing: 0.2,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                body,
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
    );
  }
}
