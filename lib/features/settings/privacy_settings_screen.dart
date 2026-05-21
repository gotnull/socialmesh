// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../services/privacy_consent_service.dart';
import '../../utils/snackbar.dart';

/// Privacy Settings screen with opt-out toggles for Firebase Analytics
/// and Crashlytics. Accessible from Settings > Privacy.
///
/// Each toggle reads/writes via [PrivacyConsentService] and immediately
/// calls the corresponding Firebase SDK method. A confirmation bottom
/// sheet is shown when disabling either service.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen>
    with LifecycleSafeMixin<PrivacySettingsScreen> {
  PrivacyConsentService? _consentService;
  bool _analyticsEnabled = false;
  bool _crashlyticsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadConsentState();
  }

  Future<void> _loadConsentState() async {
    final consent = await ref.read(privacyConsentServiceProvider.future);
    if (!mounted) return;
    safeSetState(() {
      _consentService = consent;
      _analyticsEnabled = consent.isAnalyticsEnabled;
      _crashlyticsEnabled = consent.isCrashlyticsEnabled;
    });
  }

  Future<void> _toggleAnalytics(bool value) async {
    final consent = _consentService;
    if (consent == null) return;

    if (!value) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: context.l10n.privacySettingsDisableAnalyticsTitle,
        message: context.l10n.privacySettingsDisableAnalyticsMessage,
        confirmLabel: context.l10n.privacySettingsDisable,
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
    }

    HapticFeedback.selectionClick();
    await consent.setAnalyticsConsent(value);
    if (!mounted) return;
    safeSetState(() => _analyticsEnabled = value);
    if (mounted) {
      showSuccessSnackBar(
        context,
        value
            ? context.l10n.privacySettingsAnalyticsEnabled
            : context.l10n.privacySettingsAnalyticsDisabled,
      );
    }
  }

  Future<void> _toggleCrashlytics(bool value) async {
    final consent = _consentService;
    if (consent == null) return;

    if (!value) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: context.l10n.privacySettingsDisableCrashTitle,
        message: context.l10n.privacySettingsDisableCrashMessage,
        confirmLabel: context.l10n.privacySettingsDisable,
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
    }

    HapticFeedback.selectionClick();
    await consent.setCrashlyticsConsent(value);
    if (!mounted) return;
    safeSetState(() => _crashlyticsEnabled = value);
    if (mounted) {
      showSuccessSnackBar(
        context,
        value
            ? context.l10n.privacySettingsCrashEnabled
            : context.l10n.privacySettingsCrashDisabled,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.privacySettingsTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: context.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        context.l10n.privacySettingsInfoDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.privacySettingsDataCollection,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),

              // Analytics toggle
              _PrivacyToggleTile(
                icon: Icons.analytics_outlined,
                title: context.l10n.privacySettingsUsageAnalytics,
                subtitle: context.l10n.privacySettingsUsageAnalyticsSubtitle,
                value: _analyticsEnabled,
                onChanged: _consentService != null ? _toggleAnalytics : null,
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Crashlytics toggle
              _PrivacyToggleTile(
                icon: Icons.bug_report_outlined,
                title: context.l10n.privacySettingsCrashReporting,
                subtitle: context.l10n.privacySettingsCrashReportingSubtitle,
                value: _crashlyticsEnabled,
                onChanged: _consentService != null ? _toggleCrashlytics : null,
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Privacy Policy link
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => LegalDocumentSheet.showPrivacy(context),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: context.textSecondary,
                          ),
                          const SizedBox(width: AppTheme.spacing16),
                          Expanded(
                            child: Text(
                              context.l10n.privacySettingsPrivacyPolicy,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: context.textPrimary,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: context.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Third-party services disclosure
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.privacySettingsThirdPartyServices,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              _ThirdPartyInfoTile(
                title: context.l10n.privacySettingsFirebaseTitle,
                categories: context.l10n.privacySettingsFirebaseCategories,
              ),
              _ThirdPartyInfoTile(
                title: context.l10n.privacySettingsRevenueCatTitle,
                categories: context.l10n.privacySettingsRevenueCatCategories,
              ),
              _ThirdPartyInfoTile(
                title: context.l10n.privacySettingsSigilTitle,
                categories: context.l10n.privacySettingsSigilCategories,
              ),

              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Reusable toggle tile for privacy settings.
class _PrivacyToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PrivacyToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: context.textSecondary),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            ThemedSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Read-only info tile for third-party service disclosures.
class _ThirdPartyInfoTile extends StatelessWidget {
  final String title;
  final String categories;

  const _ThirdPartyInfoTile({required this.title, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.cloud_outlined, color: context.textSecondary),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    categories,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
