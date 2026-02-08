// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/legal/legal_constants.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../providers/app_providers.dart';
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

  String get _title => _isUpdate ? 'Updated Terms' : 'Terms & Privacy';

  String get _subtitle => _isUpdate
      ? 'We have updated our Terms of Service. Please review and accept the changes to continue using Socialmesh.'
      : 'Before you get started, please review our Terms of Service and Privacy Policy.';

  Future<void> _handleAgree() async {
    if (_accepting) return;

    safeSetState(() => _accepting = true);

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.success);

    final notifier = ref.read(termsAcceptanceProvider.notifier);
    final appInit = ref.read(appInitProvider.notifier);

    await notifier.accept();

    if (!mounted) return;

    // Re-run app initialisation from the terms-accepted state.
    // This will advance past needsTermsAcceptance to the next state
    // (needsScanner or ready).
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
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 16),

                    // Subtitle / summary
                    Semantics(
                      label: 'Terms summary',
                      child: Text(
                        _subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

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
      label: 'Socialmesh app icon',
      excludeSemantics: true,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
          Icons.shield_outlined,
          color: Colors.white,
          size: 40,
          semanticLabel: 'Legal shield',
        ),
      ),
    );
  }

  Widget _buildDocumentLinks(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        // Terms of Service link
        Semantics(
          button: true,
          label: 'View Terms of Service',
          child: _DocumentLinkTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Effective ${_formatDate(LegalConstants.termsVersion)}',
            onTap: _openTerms,
          ),
        ),
        const SizedBox(height: 12),

        // Privacy Policy link
        Semantics(
          button: true,
          label: 'View Privacy Policy',
          child: _DocumentLinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Effective ${_formatDate(LegalConstants.privacyVersion)}',
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
          label:
              'I agree to the Terms of Service and Privacy Policy. Tap to accept and continue.',
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _accepting ? null : _handleAgree,
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                  : const Text(
                      'I Agree',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Decline button
        Semantics(
          button: true,
          label: 'Not now. Decline and exit the app.',
          child: SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _accepting ? null : _handleDecline,
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Not Now', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),

        // Fine print
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            label:
                'By tapping I Agree, you accept our Terms of Service and acknowledge our Privacy Policy.',
            child: Text(
              'By tapping "I Agree", you accept our Terms of Service and acknowledge our Privacy Policy.',
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
                semanticLabel: 'Information',
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Terms Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accepting the Terms of Service and Privacy Policy is required to use Socialmesh. You can review them and accept whenever you are ready.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Semantics(
                button: true,
                label: 'Go back to review and accept the terms',
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Review Terms',
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

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: context.accentColor, size: 24),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
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
