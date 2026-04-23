// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetOnboardingSheet — three-card welcome flow shown on first launch
// of the pet home screen. Explains the core Tamagotchi loop in plain
// terms so the user arrives at the action buttons already knowing
// what they do. Dismissal or "Got it" both flip the completion flag
// — a dismissed sheet is not re-shown (the user saw it; we trust
// them to open the ? icon if they want the details later).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
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

  List<_OnboardingCard> _cards(AppLocalizations l10n) => [
    _OnboardingCard(
      icon: Icons.pets,
      iconColor: AccentColors.pink,
      title: l10n.petOnboardingPage1Title,
      body: l10n.petOnboardingPage1Body,
    ),
    _OnboardingCard(
      icon: Icons.notifications_active_outlined,
      iconColor: AccentColors.yellow,
      title: l10n.petOnboardingPage2Title,
      body: l10n.petOnboardingPage2Body,
    ),
    _OnboardingCard(
      icon: Icons.visibility_outlined,
      iconColor: AccentColors.sky,
      title: l10n.petOnboardingPage3Title,
      body: l10n.petOnboardingPage3Body,
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cards = _cards(l10n);
    final isLast = _page == cards.length - 1;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _OnboardingCardView(card: cards[i]),
          ),
        ),
        _PageDots(count: cards.length, active: _page),
        const SizedBox(height: AppTheme.spacing16),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            0,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          child: Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.petOnboardingSkip,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => _next(cards.length),
                style: FilledButton.styleFrom(
                  backgroundColor: context.accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                    vertical: AppTheme.spacing12,
                  ),
                ),
                child: Text(
                  isLast ? l10n.petOnboardingFinish : l10n.petOnboardingNext,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingCard {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  const _OnboardingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}

class _OnboardingCardView extends StatelessWidget {
  final _OnboardingCard card;
  const _OnboardingCardView({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: card.iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(card.icon, size: 48, color: card.iconColor),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            card.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int active;
  const _PageDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          width: isActive ? AppTheme.spacing20 : AppTheme.spacing8,
          height: AppTheme.spacing8,
          decoration: BoxDecoration(
            color: isActive
                ? context.accentColor
                : context.textTertiary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radius4),
          ),
        );
      }),
    );
  }
}
