// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../services/privacy_consent_service.dart';

// One-shot privacy choice prompt.
//
// Shown to the user after onboarding (post-frame from MainShell) when no
// explicit consent decision has been recorded yet. Offers three options:
//
// - Keep diagnostics off:    analytics=false, crashlytics=false
// - Crash reports only:      analytics=false, crashlytics=true
// - Help improve SocialMesh: analytics=true,  crashlytics=true
//
// All three options mark the user as having made an explicit choice, so
// the prompt is never shown again. The user can change their selection at
// any time via Settings -> Privacy. Swiping the sheet down without picking
// an option behaves the same as "Keep diagnostics off" - the privacy-safe
// default - and still marks the choice as made so the prompt does not
// re-appear. Each option carries a neutral tag (max privacy / balanced /
// most helpful) so the user can read the tradeoff without the app
// moralizing the choice.
class PrivacyChoiceSheet {
  PrivacyChoiceSheet._();

  /// Shows the sheet if the user has not yet made a consent decision.
  ///
  /// Safe to call during startup: uses [addPostFrameCallback] and resolves
  /// a [ProviderContainer] from [navigatorKey] so the call survives even
  /// if the calling widget is disposed before the frame settles.
  static void showIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final container = _containerOrNull();
      if (container == null) return;

      final consentAsync = container.read(privacyConsentServiceProvider);
      final consent = consentAsync.asData?.value;
      if (consent == null) {
        Future<void>.delayed(const Duration(milliseconds: 500), _tryShow);
        return;
      }

      if (consent.hasMadeChoice) {
        AppLogging.privacy('prompt skipped; user has already chosen');
        return;
      }

      _present(container, consent);
    });
  }

  static void _tryShow() {
    final container = _containerOrNull();
    if (container == null) return;
    final consent = container.read(privacyConsentServiceProvider).asData?.value;
    if (consent == null) return;
    if (consent.hasMadeChoice) return;
    _present(container, consent);
  }

  static ProviderContainer? _containerOrNull() {
    final context = navigatorKey.currentContext;
    if (context == null) return null;
    return ProviderScope.containerOf(context, listen: false);
  }

  static Future<void> _present(
    ProviderContainer container,
    PrivacyConsentService consent,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    AppLogging.privacy('prompt shown');

    final result = await AppBottomSheet.show<_PrivacyChoiceResult>(
      context: context,
      isDismissible: true,
      child: const _PrivacyChoicePanel(),
    );

    if (result == null) {
      AppLogging.privacy(
        'prompt dismissed without explicit selection; defaulting to off',
      );
      await consent.recordChoice(analytics: false, crashlytics: false);
      return;
    }

    AppLogging.privacy('prompt resolved with option=${result.name}');
    await consent.recordChoice(
      analytics: result.analytics,
      crashlytics: result.crashlytics,
    );
  }
}

/// The three options the user can pick from. Kept private; the public
/// surface is just [PrivacyChoiceSheet.showIfNeeded].
enum _PrivacyChoiceResult {
  off(analytics: false, crashlytics: false),
  crashOnly(analytics: false, crashlytics: true),
  full(analytics: true, crashlytics: true);

  final bool analytics;
  final bool crashlytics;

  const _PrivacyChoiceResult({
    required this.analytics,
    required this.crashlytics,
  });
}

class _PrivacyChoicePanel extends StatelessWidget {
  const _PrivacyChoicePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: sheetContext.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: sheetContext.accentColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            sheetContext.l10n.privacyChoiceTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: sheetContext.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            sheetContext.l10n.privacyChoiceDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: sheetContext.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          _ChoiceCard(
            icon: Icons.lock_outline,
            title: sheetContext.l10n.privacyChoiceOptionOffTitle,
            description: sheetContext.l10n.privacyChoiceOptionOffDescription,
            tag: sheetContext.l10n.privacyChoiceTagMaxPrivacy,
            onTap: () =>
                Navigator.of(sheetContext).pop(_PrivacyChoiceResult.off),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _ChoiceCard(
            icon: Icons.bug_report_outlined,
            title: sheetContext.l10n.privacyChoiceOptionCrashTitle,
            description: sheetContext.l10n.privacyChoiceOptionCrashDescription,
            tag: sheetContext.l10n.privacyChoiceTagBalanced,
            onTap: () =>
                Navigator.of(sheetContext).pop(_PrivacyChoiceResult.crashOnly),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _ChoiceCard(
            icon: Icons.favorite_outline,
            title: sheetContext.l10n.privacyChoiceOptionFullTitle,
            description: sheetContext.l10n.privacyChoiceOptionFullDescription,
            tag: sheetContext.l10n.privacyChoiceTagMostHelpful,
            onTap: () =>
                Navigator.of(sheetContext).pop(_PrivacyChoiceResult.full),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            sheetContext.l10n.privacyChoiceFooter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: sheetContext.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String tag;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: context.textSecondary, size: 22),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.textTertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius6,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
