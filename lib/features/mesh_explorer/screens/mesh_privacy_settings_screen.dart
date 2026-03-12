// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh privacy settings screen for Mesh Explorer.
///
/// Provides toggles for visibility, sharing, and cache management.
/// All defaults are safe (anonymous, opt-in).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../utils/snackbar.dart';
import '../../../services/haptic_service.dart';
import '../../../providers/sip_providers.dart';

/// Screen for managing Mesh Explorer privacy settings.
class MeshPrivacySettingsScreen extends ConsumerStatefulWidget {
  const MeshPrivacySettingsScreen({super.key});

  @override
  ConsumerState<MeshPrivacySettingsScreen> createState() =>
      _MeshPrivacySettingsScreenState();
}

class _MeshPrivacySettingsScreenState
    extends ConsumerState<MeshPrivacySettingsScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discoverable = ref.watch(meshPrivacyDiscoverableProvider);
    final profileSharing = ref.watch(meshPrivacyProfileSharingProvider);
    final dmAvailable = ref.watch(meshPrivacyDmAvailableProvider);

    return GlassScaffold(
      title: l10n.meshExplorerPrivacyTitle,
      slivers: [
        // Visibility section
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.meshExplorerPrivacySectionVisibility,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: _PrivacyToggle(
              title: l10n.meshExplorerPrivacyDiscoverable,
              subtitle: l10n.meshExplorerPrivacyDiscoverableSub,
              icon: Icons.visibility_outlined,
              value: discoverable,
              onChanged: (v) {
                ref
                    .read(meshPrivacyDiscoverableProvider.notifier)
                    .setEnabled(v);
              },
            ),
          ),
        ),

        // Sharing section
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.meshExplorerPrivacySectionSharing,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Column(
              children: [
                _PrivacyToggle(
                  title: l10n.meshExplorerPrivacyProfileSharing,
                  subtitle: l10n.meshExplorerPrivacyProfileSharingSub,
                  icon: Icons.person_outline,
                  value: profileSharing,
                  onChanged: (v) {
                    ref
                        .read(meshPrivacyProfileSharingProvider.notifier)
                        .setEnabled(v);
                  },
                ),
                Divider(
                  height: 1,
                  color: context.border.withValues(alpha: 0.15),
                ),
                _PrivacyToggle(
                  title: l10n.meshExplorerPrivacyDmAvailable,
                  subtitle: l10n.meshExplorerPrivacyDmAvailableSub,
                  icon: Icons.chat_bubble_outline,
                  value: dmAvailable,
                  onChanged: (v) {
                    ref
                        .read(meshPrivacyDmAvailableProvider.notifier)
                        .setEnabled(v);
                  },
                ),
              ],
            ),
          ),
        ),

        // Actions section
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.meshExplorerPrivacySectionActions,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: _ClearCacheAction(
              title: l10n.meshExplorerPrivacyClearCache,
              subtitle: l10n.meshExplorerPrivacyClearCacheSub,
              onTap: () => _clearCache(context),
            ),
          ),
        ),

        // Bottom spacer
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing24)),
      ],
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final haptics = ref.read(hapticServiceProvider);
    final discovery = ref.read(sipDiscoveryProvider);
    await haptics.trigger(HapticType.heavy);
    discovery?.clearPeerCache();
    if (!context.mounted) return;
    showSuccessSnackBar(context, context.l10n.meshExplorerPrivacyCacheCleared);
  }
}

/// A single toggle row in the privacy screen.
class _PrivacyToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.bodyStyle?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  subtitle,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          ThemedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Clear cache action row.
class _ClearCacheAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ClearCacheAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 22,
                color: SemanticColors.error.withValues(alpha: 0.8),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.bodyStyle?.copyWith(
                        color: SemanticColors.error.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
