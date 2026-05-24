// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/settings_primitives.dart';
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
              FieldGroupCard(
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
              const SizedBox(height: AppTheme.spacing16),
              SettingsSectionHeader(
                title: context.l10n.privacySettingsDataCollection,
              ),
              SettingsTile(
                icon: Icons.analytics_outlined,
                title: context.l10n.privacySettingsUsageAnalytics,
                subtitle: context.l10n.privacySettingsUsageAnalyticsSubtitle,
                trailing: ThemedSwitch(
                  value: _analyticsEnabled,
                  onChanged: _consentService != null ? _toggleAnalytics : null,
                ),
              ),
              SettingsTile(
                icon: Icons.bug_report_outlined,
                title: context.l10n.privacySettingsCrashReporting,
                subtitle: context.l10n.privacySettingsCrashReportingSubtitle,
                trailing: ThemedSwitch(
                  value: _crashlyticsEnabled,
                  onChanged: _consentService != null
                      ? _toggleCrashlytics
                      : null,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              SettingsTile(
                icon: Icons.description_outlined,
                title: context.l10n.privacySettingsPrivacyPolicy,
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                ),
                onTap: () => LegalDocumentSheet.showPrivacy(context),
              ),
              const SizedBox(height: AppTheme.spacing16),
              SettingsSectionHeader(
                title: context.l10n.privacySettingsThirdPartyServices,
              ),
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: context.l10n.privacySettingsFirebaseTitle,
                subtitle: context.l10n.privacySettingsFirebaseCategories,
              ),
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: context.l10n.privacySettingsRevenueCatTitle,
                subtitle: context.l10n.privacySettingsRevenueCatCategories,
              ),
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: context.l10n.privacySettingsSigilTitle,
                subtitle: context.l10n.privacySettingsSigilCategories,
              ),
              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }
}
