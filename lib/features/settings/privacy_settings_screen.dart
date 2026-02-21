// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: 'Disable Usage Analytics?',
        message:
            'Usage analytics help us understand how the app is used and '
            'identify issues. No personal messages or location data are '
            'collected.\n\n'
            'You can re-enable this at any time.',
        confirmLabel: 'Disable',
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
        value ? 'Usage analytics enabled' : 'Usage analytics disabled',
      );
    }
  }

  Future<void> _toggleCrashlytics(bool value) async {
    final consent = _consentService;
    if (consent == null) return;

    if (!value) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: 'Disable Crash Reporting?',
        message:
            'Crash reports help us fix bugs faster. No personal messages '
            'or location data are included in crash reports.\n\n'
            'You can re-enable this at any time.',
        confirmLabel: 'Disable',
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
        value ? 'Crash reporting enabled' : 'Crash reporting disabled',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Privacy',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: context.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Socialmesh collects minimal data to improve app '
                        'stability and performance. You can control what is '
                        'shared below.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'DATA COLLECTION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Analytics toggle
              _PrivacyToggleTile(
                icon: Icons.analytics_outlined,
                title: 'Usage Analytics',
                subtitle:
                    'Helps us understand which features are used most. '
                    'No message content or precise location is collected.',
                value: _analyticsEnabled,
                onChanged: _consentService != null ? _toggleAnalytics : null,
              ),

              const SizedBox(height: 4),

              // Crashlytics toggle
              _PrivacyToggleTile(
                icon: Icons.bug_report_outlined,
                title: 'Crash Reporting',
                subtitle:
                    'Automatically sends crash data when the app encounters '
                    'an error. Helps us fix bugs faster.',
                value: _crashlyticsEnabled,
                onChanged: _consentService != null ? _toggleCrashlytics : null,
              ),

              const SizedBox(height: 24),

              // Privacy Policy link
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => LegalDocumentSheet.showPrivacy(context),
                    borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Privacy Policy',
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
              const SizedBox(height: 24),

              // Third-party services disclosure
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'THIRD-PARTY SERVICES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _ThirdPartyInfoTile(
                title: 'Firebase (Google)',
                categories: 'Crash reports, usage analytics (if opted in)',
              ),
              _ThirdPartyInfoTile(
                title: 'RevenueCat',
                categories: 'Purchase identifiers, subscription status',
              ),
              _ThirdPartyInfoTile(
                title: 'Sigil API (Socialmesh)',
                categories: 'Hashed node identifiers for artwork generation',
              ),

              const SizedBox(height: 32),
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
        borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
        borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
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
