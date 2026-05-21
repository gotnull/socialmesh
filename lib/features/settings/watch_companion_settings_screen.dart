// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/chip_selector.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/app_providers.dart' show settingsServiceProvider;
import '../../services/watch_companion/watch_companion_providers.dart';
import '../../utils/snackbar.dart';

/// On-phone settings surface for the Apple Watch companion. v1 lets the
/// user pick the default quick-send channel index and surfaces the
/// current `WATCH_COMPANION_ENABLED` feature-flag state read-only. No
/// freeform fields, no protocol-specific switches.
class WatchCompanionSettingsScreen extends ConsumerStatefulWidget {
  const WatchCompanionSettingsScreen({super.key});

  /// Number of channel chips rendered in the picker. Meshtastic
  /// supports up to 8 channels (indices 0-7); MeshCore is single-channel
  /// today but the persisted value is still an int so the same picker
  /// works for both. Slice 6's Watch UI picks from the snapshot's live
  /// channel list at send time; this screen just sets the pre-select.
  static const int channelCount = 8;

  @override
  ConsumerState<WatchCompanionSettingsScreen> createState() =>
      _WatchCompanionSettingsScreenState();
}

class _WatchCompanionSettingsScreenState
    extends ConsumerState<WatchCompanionSettingsScreen>
    with LifecycleSafeMixin<WatchCompanionSettingsScreen> {
  int _defaultChannel = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultChannel();
  }

  Future<void> _loadDefaultChannel() async {
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      safeSetState(() {
        _defaultChannel = settings.watchDefaultChannelIndex;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      safeSetState(() => _loading = false);
    }
  }

  Future<void> _setDefaultChannel(int index) async {
    safeSetState(() => _defaultChannel = index);
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      await settings.setWatchDefaultChannelIndex(index);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flags = ref.watch(watchCompanionFeatureFlagsProvider);

    return GlassScaffold(
      title: l10n.watchSettingsTitle,
      slivers: _loading
          ? const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ]
          : [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusSection(context, flagsEnabled: flags.enabled),
                    const SizedBox(height: AppTheme.spacing16),
                    _buildQuickSendSection(context),
                    const SizedBox(height: AppTheme.spacing16),
                    _buildAboutSection(context),
                    const SizedBox(height: AppTheme.spacing16),
                  ]),
                ),
              ),
            ],
    );
  }

  Widget _buildStatusSection(
    BuildContext context, {
    required bool flagsEnabled,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.watchSettingsSectionStatus),
          InfoTable(
            rows: [
              InfoTableRow(
                label: l10n.watchSettingsStatusLabel,
                value: flagsEnabled
                    ? l10n.watchSettingsStatusEnabled
                    : l10n.watchSettingsStatusDisabled,
                icon: Icons.watch_outlined,
                iconColor: flagsEnabled
                    ? context.accentColor
                    : context.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSendSection(BuildContext context) {
    final l10n = context.l10n;
    final options = List<ChipOption<int>>.generate(
      WatchCompanionSettingsScreen.channelCount,
      (i) => ChipOption<int>(
        value: i,
        label: l10n.watchSettingsChannelChipLabel(i),
        icon: Icons.tag,
        color: context.accentColor,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: Text(
            l10n.watchSettingsSectionQuickSend,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing2,
          ),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tag, color: context.textSecondary),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.watchSettingsDefaultChannelTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            l10n.watchSettingsDefaultChannelSubtitle,
                            style: context.bodySmallStyle?.copyWith(
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing16),
                ChipSelector<int>(
                  value: _defaultChannel,
                  options: options,
                  onChanged: _setDefaultChannel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.watchSettingsAboutTitle),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Text(
              l10n.watchSettingsAboutBody,
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
