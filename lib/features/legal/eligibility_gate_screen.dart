// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — pre-auth gate screen, no navigation chrome
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/legal/age_group.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../providers/age_eligibility_provider.dart';
import '../../providers/app_providers.dart';
import '../../services/haptic_service.dart';

/// Full-screen age eligibility gate.
///
/// Shown before any other app flow (onboarding, terms, scanner) when the
/// user has not confirmed their age group or when the eligibility policy
/// version has been bumped.
///
/// The user selects one of three age ranges (Under 13 / 13–17 / 18+).
/// - Under 13: app exits (age requirement not met).
/// - 13–17: confirmed as [AgeGroup.teen] — privacy-enhanced defaults apply.
/// - 18+: confirmed as [AgeGroup.adult] — standard app experience.
///
/// This is an eligibility attestation, NOT age verification. No DOB or ID
/// is collected.
class EligibilityGateScreen extends ConsumerStatefulWidget {
  const EligibilityGateScreen({super.key});

  @override
  ConsumerState<EligibilityGateScreen> createState() =>
      _EligibilityGateScreenState();
}

class _EligibilityGateScreenState extends ConsumerState<EligibilityGateScreen>
    with LifecycleSafeMixin {
  AgeGroup? _selectedGroup;
  bool _confirming = false;
  bool _showExitExplanation = false;

  Future<void> _handleConfirm() async {
    final group = _selectedGroup;
    if (group == null || _confirming) return;

    // Under-13 selection is handled as an exit condition.
    if (group == AgeGroup.under13) {
      _handleExit();
      return;
    }

    safeSetState(() => _confirming = true);

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.success);

    if (!mounted) return;
    final notifier = ref.read(ageEligibilityProvider.notifier);
    await notifier.confirm(ageGroup: group);

    if (!mounted) return;

    // Re-run app initialisation so _AppRouter advances past this gate.
    ref.read(appInitProvider.notifier).initialize();
  }

  void _handleExit() {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.warning);

    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      // iOS does not allow force-quitting. Show inert explanation.
      safeSetState(() => _showExitExplanation = true);
    }
  }

  void _openTerms() {
    LegalDocumentSheet.showTerms(context);
  }

  void _openPrivacy() {
    LegalDocumentSheet.showPrivacy(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_showExitExplanation) {
      return _buildExitExplanation(context, theme, bottomPadding);
    }

    return Scaffold(
      backgroundColor: context.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Shield icon
                    _buildIcon(context),
                    const SizedBox(height: AppTheme.spacing24),

                    // Title
                    Semantics(
                      header: true,
                      child: Text(
                        context.l10n.legalEligibilityTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),

                    // Body
                    Semantics(
                      label: context.l10n.legalEligibilityNoticeSemantics,
                      child: Text(
                        context.l10n.legalEligibilityBody,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Age range selector
                    _buildAgeSelector(context, theme),
                    const SizedBox(height: AppTheme.spacing20),

                    // Legal links
                    _buildLegalLinks(context, theme),

                    const Spacer(flex: 3),

                    // Action buttons
                    _buildActionButtons(context, theme),

                    SizedBox(height: bottomPadding > 0 ? bottomPadding : 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.accentColor,
              context.accentColor.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.accentColor.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.verified_user_outlined,
          color: Colors.white,
          size: 40,
          semanticLabel: context.l10n.legalEligibilityIconSemantics,
        ),
      ),
    );
  }

  Widget _buildAgeSelector(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
          child: Text(
            context.l10n.legalEligibilityAgePrompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildAgeOption(
          context,
          theme,
          group: AgeGroup.under13,
          label: context.l10n.legalEligibilityOptionUnder13,
          subtitle: context.l10n.legalEligibilityOptionUnder13Subtitle,
          isDestructive: true,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildAgeOption(
          context,
          theme,
          group: AgeGroup.teen,
          label: context.l10n.legalEligibilityOptionTeen,
          subtitle: context.l10n.legalEligibilityOptionTeenSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildAgeOption(
          context,
          theme,
          group: AgeGroup.adult,
          label: context.l10n.legalEligibilityOptionAdult,
        ),
      ],
    );
  }

  Widget _buildAgeOption(
    BuildContext context,
    ThemeData theme, {
    required AgeGroup group,
    required String label,
    String? subtitle,
    bool isDestructive = false,
  }) {
    final isSelected = _selectedGroup == group;
    final accentColor = isDestructive
        ? const Color(0xFFE53935)
        : context.accentColor;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          safeSetState(() => _selectedGroup = group);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius14),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : context.textTertiary.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1.0,
            ),
            color: isSelected
                ? accentColor.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accentColor : context.textTertiary,
                    width: 2,
                  ),
                  color: isSelected ? accentColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected ? accentColor : context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.8)
                              : context.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: context.l10n.legalEligibilityViewTermsSemantics,
          child: TextButton(
            onPressed: _openTerms,
            child: Text(
              context.l10n.legalEligibilityTermsLink,
              style: TextStyle(
                color: context.accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '\u2022', // lint-allow: hardcoded-string
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
        ),
        Semantics(
          button: true,
          label: context.l10n.legalEligibilityViewPrivacySemantics,
          child: TextButton(
            onPressed: _openPrivacy,
            child: Text(
              context.l10n.legalEligibilityPrivacyLink,
              style: TextStyle(
                color: context.accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    final canContinue = _selectedGroup != null && !_confirming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Continue button — disabled until a selection is made
        Semantics(
          button: true,
          label: context.l10n.legalEligibilityConfirmSemantics,
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: canContinue ? _handleConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
                disabledBackgroundColor: context.accentColor.withValues(
                  alpha: 0.3,
                ),
              ),
              child: _confirming
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : Text(
                      context.l10n.legalEligibilityConfirmButton,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Exit button
        Semantics(
          button: true,
          label: context.l10n.legalEligibilityExitSemantics,
          child: SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _confirming ? null : _handleExit,
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
              ),
              child: Text(
                context.l10n.legalEligibilityExitButton,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// iOS-only explanation when the user taps Exit.
  Widget _buildExitExplanation(
    BuildContext context,
    ThemeData theme,
    double bottomPadding,
  ) {
    return Scaffold(
      backgroundColor: context.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 56,
                color: context.textTertiary,
                semanticLabel:
                    context.l10n.legalEligibilityInformationSemantics,
              ),
              const SizedBox(height: AppTheme.spacing24),
              Semantics(
                header: true,
                child: Text(
                  context.l10n.legalEligibilityExitTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                context.l10n.legalEligibilityExitBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              Semantics(
                button: true,
                label: context.l10n.legalEligibilityGoBackSemantics,
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      safeSetState(() => _showExitExplanation = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                      ),
                    ),
                    child: Text(
                      context.l10n.legalEligibilityGoBackButton,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
