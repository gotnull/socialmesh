// SPDX-License-Identifier: GPL-3.0-or-later
// lint-allow: scaffold — pre-auth gate screen, no navigation chrome
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../providers/age_eligibility_provider.dart';
import '../../providers/app_providers.dart';
import '../../services/haptic_service.dart';

/// Full-screen 16+ age eligibility gate.
///
/// Shown before any other app flow (onboarding, terms, scanner) when the
/// user has not confirmed they are 16+ or when the eligibility policy
/// version has been bumped.
///
/// This is an eligibility affirmation, NOT age verification. No DOB or ID
/// is collected. The user simply confirms they are 16 or older.
class EligibilityGateScreen extends ConsumerStatefulWidget {
  const EligibilityGateScreen({super.key});

  @override
  ConsumerState<EligibilityGateScreen> createState() =>
      _EligibilityGateScreenState();
}

class _EligibilityGateScreenState extends ConsumerState<EligibilityGateScreen>
    with LifecycleSafeMixin {
  bool _confirming = false;

  Future<void> _handleConfirm() async {
    if (_confirming) return;

    safeSetState(() => _confirming = true);

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.success);

    if (!mounted) return;
    final notifier = ref.read(ageEligibilityProvider.notifier);
    await notifier.confirm();

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

  bool _showExitExplanation = false;

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
                        'Ages 16+',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // Body
                    Semantics(
                      label: 'Age eligibility notice',
                      child: Text(
                        'Socialmesh is intended for people aged 16 or older. '
                        'You must confirm you are 16+ to continue.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

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
        child: const Icon(
          Icons.verified_user_outlined,
          color: Colors.white,
          size: 40,
          semanticLabel: 'Age eligibility',
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
          label: 'View Terms of Service',
          child: TextButton(
            onPressed: _openTerms,
            child: Text(
              'Terms',
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
            '\u2022',
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
        ),
        Semantics(
          button: true,
          label: 'View Privacy Policy',
          child: TextButton(
            onPressed: _openPrivacy,
            child: Text(
              'Privacy',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Confirm button
        Semantics(
          button: true,
          label: 'I am 16 or older. Tap to confirm and continue.',
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _confirming ? null : _handleConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
                disabledBackgroundColor: context.accentColor.withValues(
                  alpha: 0.5,
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
                  : const Text(
                      'I Am 16 or Older',
                      style: TextStyle(
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
          label: 'Exit. You must be 16 or older to use Socialmesh.',
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
              child: const Text('Exit', style: TextStyle(fontSize: 16)),
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
                semanticLabel: 'Information',
              ),
              const SizedBox(height: AppTheme.spacing24),
              Semantics(
                header: true,
                child: Text(
                  'Age Confirmation Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'You must confirm you are 16 or older to use Socialmesh. '
                'You can confirm whenever you are ready.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              Semantics(
                button: true,
                label: 'Go back to confirm your age',
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
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
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
