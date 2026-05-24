// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — pre-auth gate screen, no navigation chrome
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/legal/legal_constants.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/remote_legal_versions_provider.dart';
import '../../providers/terms_acceptance_provider.dart';
import '../../services/haptic_service.dart';

/// Full-screen terms and privacy acceptance gate.
///
/// Shown when:
/// - First launch (user has never accepted terms), or
/// - Terms or privacy version has been bumped since last acceptance.
///
/// The user must tap "I Agree" to proceed. "Not Now" exits the app
/// gracefully on Android or shows an explanation on iOS (App Store
/// does not allow force-quitting).
///
/// Design: no dark patterns — both buttons are clearly visible, no
/// pre-checked boxes, plain-English summary.
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen>
    with LifecycleSafeMixin {
  bool _accepting = false;
  bool _showDeclineExplanation = false;

  /// Whether this is a version-bump re-acceptance (vs first-ever acceptance).
  bool get _isUpdate {
    final termsState = ref.read(termsAcceptanceProvider).asData?.value;
    if (termsState == null) return false;
    return termsState.hasAccepted && termsState.needsAcceptance;
  }

  String get _title => _isUpdate
      ? context.l10n.legalAcceptanceTitleUpdate
      : context.l10n.legalAcceptanceTitleInitial;

  String get _subtitle => _isUpdate
      ? context.l10n.legalAcceptanceSubtitleUpdate
      : context.l10n.legalAcceptanceSubtitleInitial;

  Future<void> _handleAgree() async {
    if (_accepting) return;

    safeSetState(() => _accepting = true);

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.success);

    if (!mounted) return;
    final notifier = ref.read(termsAcceptanceProvider.notifier);
    final appInit = ref.read(appInitProvider.notifier);

    await notifier.accept();

    if (!mounted) return;

    // Re-run app initialisation so _AppRouter rebuilds.
    // initialize() will see onboarding done, terms now accepted,
    // and advance to needsScanner or ready as appropriate.
    //
    // Analytics and Crashlytics consent is collected separately via
    // PrivacyChoiceSheet, surfaced post-onboarding by MainShell. Terms
    // acceptance no longer implicitly enables telemetry.
    appInit.initialize();
  }

  void _handleDecline() {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.warning);

    if (Platform.isAndroid) {
      // Android allows graceful exit
      SystemNavigator.pop();
    } else {
      // iOS App Store policy: cannot force-quit.
      // Show an explanation instead.
      safeSetState(() => _showDeclineExplanation = true);
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
    // Watch the provider so the widget rebuilds when the async state
    // transitions from loading → data (needed for _isUpdate / _title).
    ref.watch(termsAcceptanceProvider);

    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    if (_showDeclineExplanation) {
      return _buildDeclineExplanation(context, theme, bottomPadding);
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

                    // App icon
                    _buildAppIcon(context),
                    const SizedBox(height: AppTheme.spacing24),

                    // Title
                    Semantics(
                      header: true,
                      child: Text(
                        _title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // Subtitle / summary
                    Semantics(
                      label: context.l10n.legalAcceptanceTermsSummarySemantics,
                      child: Text(
                        _subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // Document links
                    _buildDocumentLinks(context, theme),

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

  Widget _buildAppIcon(BuildContext context) {
    return Semantics(
      label: context.l10n.legalAcceptanceAppIconSemantics,
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
          Icons.shield_outlined,
          color: Colors.white,
          size: 40,
          semanticLabel: context.l10n.legalAcceptanceLegalShieldSemantics,
        ),
      ),
    );
  }

  Widget _buildDocumentLinks(BuildContext context, ThemeData theme) {
    final effective = ref.watch(effectiveLegalVersionsProvider).asData?.value;
    final termsV = effective?.termsVersion ?? LegalConstants.termsVersion;
    final privacyV = effective?.privacyVersion ?? LegalConstants.privacyVersion;

    return Column(
      children: [
        // Terms of Service link
        Semantics(
          button: true,
          label: context.l10n.legalAcceptanceViewTermsSemantics,
          child: _DocumentLinkTile(
            icon: Icons.description_outlined,
            title: context.l10n.legalAcceptanceTermsOfService,
            subtitle: context.l10n.legalAcceptanceTermsEffective(
              _formatDate(termsV),
            ),
            onTap: _openTerms,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Privacy Policy link
        Semantics(
          button: true,
          label: context.l10n.legalAcceptanceViewPrivacySemantics,
          child: _DocumentLinkTile(
            icon: Icons.privacy_tip_outlined,
            title: context.l10n.legalAcceptancePrivacyPolicy,
            subtitle: context.l10n.legalAcceptancePrivacyEffective(
              _formatDate(privacyV),
            ),
            onTap: _openPrivacy,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Agree button
        Semantics(
          button: true,
          label: context.l10n.legalAcceptanceAgreeSemantics,
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _accepting ? null : _handleAgree,
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
              child: _accepting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : Text(
                      context.l10n.legalAcceptanceAgreeButton,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Decline button
        Semantics(
          button: true,
          label: context.l10n.legalAcceptanceDeclineSemantics,
          child: SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _accepting ? null : _handleDecline,
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius14),
                ),
              ),
              child: Text(
                context.l10n.legalAcceptanceDeclineButton,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),

        // Fine print
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            label: context.l10n.legalAcceptanceFinePrintSemantics,
            child: Text(
              context.l10n.legalAcceptanceFinePrint,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// iOS-only explanation shown when the user taps "Not Now".
  /// Since iOS does not allow force-quitting, we show a non-functional
  /// state explaining terms must be accepted to use the app.
  Widget _buildDeclineExplanation(
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
                semanticLabel: context.l10n.legalAcceptanceInformationSemantics,
              ),
              const SizedBox(height: AppTheme.spacing24),
              Semantics(
                header: true,
                child: Text(
                  context.l10n.legalAcceptanceDeclineTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                context.l10n.legalAcceptanceDeclineBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              Semantics(
                button: true,
                label: context.l10n.legalAcceptanceGoBackSemantics,
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      safeSetState(() => _showDeclineExplanation = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                      ),
                    ),
                    child: Text(
                      context.l10n.legalAcceptanceReviewButton,
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

  /// Formats a YYYY-MM-DD version string into a human-readable date.
  String _formatDate(String version) {
    final parts = version.split('-');
    if (parts.length != 3) return version;

    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final year = parts[0];

    if (month == null || day == null) return version;

    final months = [
      context.l10n.legalAcceptanceDateFormatJanuary,
      context.l10n.legalAcceptanceDateFormatFebruary,
      context.l10n.legalAcceptanceDateFormatMarch,
      context.l10n.legalAcceptanceDateFormatApril,
      context.l10n.legalAcceptanceDateFormatMay,
      context.l10n.legalAcceptanceDateFormatJune,
      context.l10n.legalAcceptanceDateFormatJuly,
      context.l10n.legalAcceptanceDateFormatAugust,
      context.l10n.legalAcceptanceDateFormatSeptember,
      context.l10n.legalAcceptanceDateFormatOctober,
      context.l10n.legalAcceptanceDateFormatNovember,
      context.l10n.legalAcceptanceDateFormatDecember,
    ];

    if (month < 1 || month > 12) return version;

    return '${months[month - 1]} $day, $year';
  }
}

/// Tappable tile that shows a legal document name with a chevron.
class _DocumentLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocumentLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: context.accentColor, size: 24),
              const SizedBox(width: AppTheme.spacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
