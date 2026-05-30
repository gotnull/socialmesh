// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — full-screen pre-hub onboarding, no app bar

// Cinematic first-visit onboarding for the Handshake hub.
//
// Nine pages introduce the living, offline, consent-based mesh: welcome,
// what a handshake is (interactive), discovery, private messaging, sketches
// (interactive), play, lightweight signals (interactive), shared services, and
// permissions. A shared drifting-mesh backdrop runs behind every page so the
// whole flow reads as one continuous space the user is entering.
//
// This is separate from the Meshtastic device OnboardingScreen and never
// touches it. It fires once, the first time the user opens the hub.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/haptic_service.dart';
import 'animation/onboarding_backdrop.dart';
import 'handshake_onboarding_models.dart';
import 'widgets/handshake_onboarding_page.dart';
import 'widgets/handshake_permissions_page.dart';

/// Full-screen Handshake onboarding. Pop occurs on completion; the caller
/// persists the "seen" flag is handled here so the flow is self-contained.
class HandshakeOnboardingScreen extends ConsumerStatefulWidget {
  const HandshakeOnboardingScreen({super.key});

  @override
  ConsumerState<HandshakeOnboardingScreen> createState() =>
      _HandshakeOnboardingScreenState();
}

class _HandshakeOnboardingScreenState
    extends ConsumerState<HandshakeOnboardingScreen>
    with LifecycleSafeMixin<HandshakeOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  double _pagePos = 0.0;
  bool _finishing = false;

  static const List<Color> _accents = [
    AccentColors.magenta,
    AccentColors.purple,
    AccentColors.cyan,
    AccentColors.blue,
    AccentColors.pink,
    AccentColors.green,
    AccentColors.orange,
    AccentColors.teal,
    AccentColors.indigo,
  ];

  int get _lastIndex => _accents.length - 1; // 8 (permissions)

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page;
      if (page != null) safeSetState(() => _pagePos = page);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color get _interpolatedAccent {
    final lo = _pagePos.floor().clamp(0, _accents.length - 1);
    final hi = (lo + 1).clamp(0, _accents.length - 1);
    return Color.lerp(_accents[lo], _accents[hi], _pagePos - lo) ??
        _accents[lo];
  }

  List<HandshakeOnboardingPageData> _contentPages(BuildContext context) {
    final l10n = context.l10n;
    return [
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.welcome,
        accent: _accents[0],
        headline: l10n.handshakeOnboardingWelcomeHeadline,
        body: l10n.handshakeOnboardingWelcomeBody,
        tagline: l10n.handshakeOnboardingWelcomeTagline,
        cta: l10n.handshakeOnboardingCtaContinue,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.handshake,
        accent: _accents[1],
        headline: l10n.handshakeOnboardingHandshakeHeadline,
        body: l10n.handshakeOnboardingHandshakeBody,
        highlightTitle: l10n.handshakeOnboardingHandshakeHighlightTitle,
        highlightBody: l10n.handshakeOnboardingHandshakeHighlightBody,
        interactiveHint: l10n.handshakeOnboardingHandshakeHint,
        cta: l10n.handshakeOnboardingCtaGotIt,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.discovery,
        accent: _accents[2],
        headline: l10n.handshakeOnboardingDiscoveryHeadline,
        body: l10n.handshakeOnboardingDiscoveryBody,
        cta: l10n.handshakeOnboardingCtaNext,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.messaging,
        accent: _accents[3],
        headline: l10n.handshakeOnboardingMessagingHeadline,
        body: l10n.handshakeOnboardingMessagingBody,
        features: [
          HandshakeFeature(
            icon: Icons.lock_outline,
            label: l10n.handshakeOnboardingMessagingFeatureEncrypted,
          ),
          HandshakeFeature(
            icon: Icons.add_reaction_outlined,
            label: l10n.handshakeOnboardingMessagingFeatureReactions,
          ),
          HandshakeFeature(
            icon: Icons.cloud_off_outlined,
            label: l10n.handshakeOnboardingMessagingFeatureOffline,
          ),
          HandshakeFeature(
            icon: Icons.hub_outlined,
            label: l10n.handshakeOnboardingMessagingFeatureMesh,
          ),
        ],
        cta: l10n.handshakeOnboardingCtaContinue,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.sketch,
        accent: _accents[4],
        headline: l10n.handshakeOnboardingSketchHeadline,
        body: l10n.handshakeOnboardingSketchBody,
        interactiveHint: l10n.handshakeOnboardingSketchHint,
        cta: l10n.handshakeOnboardingCtaNext,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.games,
        accent: _accents[5],
        headline: l10n.handshakeOnboardingGamesHeadline,
        body: l10n.handshakeOnboardingGamesBody,
        cta: l10n.handshakeOnboardingCtaContinue,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.morse,
        accent: _accents[6],
        headline: l10n.handshakeOnboardingMorseHeadline,
        body: l10n.handshakeOnboardingMorseBody,
        tagline: l10n.handshakeOnboardingMorseTagline,
        interactiveHint: l10n.handshakeOnboardingMorseHint,
        cta: l10n.handshakeOnboardingCtaNext,
      ),
      HandshakeOnboardingPageData(
        visual: HandshakeVisual.services,
        accent: _accents[7],
        headline: l10n.handshakeOnboardingServicesHeadline,
        body: l10n.handshakeOnboardingServicesBody,
        cta: l10n.handshakeOnboardingCtaContinue,
      ),
    ];
  }

  void _onInteract() {
    // Subtle confirm for the hands-on screens (accept / sketch / morse).
    // Kept light because sketch and morse fire it repeatedly.
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
  }

  void _onPrimary() {
    if (_currentIndex >= _lastIndex) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    _pageController.animateToPage(
      _lastIndex,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    safeSetState(() => _finishing = true);
    ref.read(hapticServiceProvider).trigger(HapticType.success);
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setHandshakeOnboardingSeen(true);
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _contentPages(context);
    final accent = _interpolatedAccent;

    final ctas = [
      for (final p in pages) p.cta,
      l10n.handshakeOnboardingCtaEnter,
    ];
    final currentCta = ctas[_currentIndex.clamp(0, ctas.length - 1)];

    return Scaffold(
      backgroundColor: context.background,
      body: Stack(
        children: [
          Positioned.fill(child: OnboardingBackdrop(accent: accent)),
          SafeArea(
            child: Column(
              children: [
                // De-emphasized skip, hidden on the final page.
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex < _lastIndex ? 0.6 : 0.0,
                      child: TextButton(
                        onPressed: _currentIndex < _lastIndex ? _skip : null,
                        child: Text(
                          l10n.handshakeOnboardingSkip,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => safeSetState(() => _currentIndex = i),
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        HandshakeOnboardingPage(
                          data: pages[i],
                          active: _currentIndex == i,
                          onInteract: _onInteract,
                        ),
                      HandshakePermissionsPage(accent: _accents[_lastIndex]),
                    ],
                  ),
                ),
                _PageDots(
                  count: ctas.length,
                  index: _currentIndex,
                  accent: accent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing24,
                    AppTheme.spacing16,
                    AppTheme.spacing24,
                    AppTheme.spacing24,
                  ),
                  child: _PrimaryButton(
                    label: currentCta,
                    accent: accent,
                    loading: _finishing,
                    onTap: _onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact animated page indicator.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.accent,
  });

  final int count;
  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing3),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? accent
                  : context.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.radius5),
            ),
          ),
      ],
    );
  }
}

/// Bottom gradient primary button (mirrors the app's PrimaryGradientButton
/// shape but takes a per-page accent that animates as pages change).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accent, accent.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: AppTheme.spacing16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: AppTheme.spacing20,
                  height: AppTheme.spacing20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      SemanticColors.onAccent,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: SemanticColors.onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
