// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetOnboardingSheet — three-page welcome flow shown on first launch
// of the pet home screen. Visually aligned with the main onboarding
// flow: Ico the mesh-brain advisor narrates each page via a sci-fi
// speech bubble, ShaderMask gradient titles, glowing gradient page
// indicators, and a full-width gradient primary button. Dismissal or
// "Got it" both flip the completion flag so the sheet is never
// re-shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/widgets/advisor_speech_bubble.dart';
import '../../../core/widgets/mesh_node_brain.dart';
import '../providers/pet_providers.dart';

class PetOnboardingSheet extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const PetOnboardingSheet({super.key, this.scrollController});

  @override
  ConsumerState<PetOnboardingSheet> createState() => _PetOnboardingSheetState();
}

class _PetOnboardingSheetState extends ConsumerState<PetOnboardingSheet>
    with LifecycleSafeMixin {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_PetOnboardingPage> _pages(AppLocalizations l10n) => [
    _PetOnboardingPage(
      title: l10n.petOnboardingPage1Title,
      advisorText: l10n.petOnboardingPage1Body,
      mood: MeshBrainMood.inviting,
      accent: AccentColors.pink,
    ),
    _PetOnboardingPage(
      title: l10n.petOnboardingPage2Title,
      advisorText: l10n.petOnboardingPage2Body,
      mood: MeshBrainMood.speaking,
      accent: AccentColors.yellow,
    ),
    _PetOnboardingPage(
      title: l10n.petOnboardingPage3Title,
      advisorText: l10n.petOnboardingPage3Body,
      mood: MeshBrainMood.curious,
      accent: AccentColors.sky,
      showHelpHint: true,
    ),
  ];

  Future<void> _finish() async {
    await markPetOnboardingCompleted(ref);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _next(int total) {
    if (_page >= total - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages(l10n);
    final isLast = _page == pages.length - 1;
    final accent = pages[_page].accent;

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: Column(
        children: [
          // Skip button — top-right, mirrors main onboarding.
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isLast ? 0.0 : 1.0,
                    child: TextButton(
                      onPressed: isLast ? null : _finish,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing12,
                          vertical: AppTheme.spacing4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.petOnboardingSkip,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) =>
                  _PetOnboardingPageView(page: pages[i], isActive: i == _page),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _GradientPageDots(count: pages.length, active: _page, accent: accent),
          const SizedBox(height: AppTheme.spacing20),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing24,
            ),
            child: _GradientActionButton(
              label: isLast ? l10n.petOnboardingFinish : l10n.petOnboardingNext,
              accent: accent,
              onPressed: () => _next(pages.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetOnboardingPage {
  final String title;
  final String advisorText;
  final MeshBrainMood mood;
  final Color accent;
  final bool showHelpHint;

  const _PetOnboardingPage({
    required this.title,
    required this.advisorText,
    required this.mood,
    required this.accent,
    this.showHelpHint = false,
  });
}

class _PetOnboardingPageView extends StatelessWidget {
  final _PetOnboardingPage page;
  final bool isActive;

  const _PetOnboardingPageView({required this.page, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MeshNodeBrain(
            size: 88,
            mood: page.mood,
            colors: [
              page.accent,
              Color.lerp(page.accent, AppTheme.primaryMagenta, 0.5) ??
                  page.accent,
              Color.lerp(page.accent, AppTheme.graphBlue, 0.5) ?? page.accent,
            ],
            glowIntensity: 0.9,
            lineThickness: 0.6,
            nodeSize: 0.9,
          ),
          AdvisorSpeechBubble(
            key: ValueKey('pet_onboarding_speech_${page.title}'),
            text: page.advisorText,
            accentColor: page.accent,
            typewriterEffect: isActive,
            typingSpeed: 25,
          ),
          if (page.showHelpHint) ...[
            const SizedBox(height: AppTheme.spacing12),
            _HelpIconHint(accent: page.accent),
          ],
          const SizedBox(height: AppTheme.spacing20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.9),
                Colors.white,
              ],
            ).createShader(bounds),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPageDots extends StatelessWidget {
  final int count;
  final int active;
  final Color accent;

  const _GradientPageDots({
    required this.count,
    required this.active,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.7)],
                  )
                : null,
            color: isActive ? null : context.border,
            borderRadius: BorderRadius.circular(AppTheme.radius5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// A small visual hint — a styled help-icon chip + label — used on page
/// 3 of the pet onboarding to point users at the help sheet they can
/// open from the pet home screen. Replaces the plain "?" character in
/// body copy with a proper chip so the reference is visually unmistakable.
class _HelpIconHint extends StatelessWidget {
  final Color accent;
  const _HelpIconHint({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.18),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.help_outline, size: 16, color: accent),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          context.l10n.petOnboardingHelpHint,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _GradientActionButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accent,
                Color.lerp(accent, AppTheme.primaryPurple, 0.5) ?? accent,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
