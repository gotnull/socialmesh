// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/ringtone_presets.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../providers/meshcore_ringtone_preferences.dart';
import '../../../services/audio/rtttl_player.dart';
import '../../../utils/snackbar.dart';

/// Per-MeshCore-notification-channel ringtone picker. Mirrors the
/// Meshtastic-side `RingtoneScreen` UI shape:
///   - Channel selector chip group at the top (Adverts / Activity
///     summary) so the user picks which notification channel they're
///     customising;
///   - Presets list with select + preview play;
///   - Use-system-default action that clears the channel's selection.
///
/// Library search + custom RTTTL editor are deferred to a v2 follow-up
/// (the `PremiumFeature.customRingtones` gate already protects them on
/// the Meshtastic side; same gate will apply here when those land).
class MeshCoreRingtoneScreen extends ConsumerStatefulWidget {
  const MeshCoreRingtoneScreen({super.key});

  @override
  ConsumerState<MeshCoreRingtoneScreen> createState() =>
      _MeshCoreRingtoneScreenState();
}

class _MeshCoreRingtoneScreenState extends ConsumerState<MeshCoreRingtoneScreen>
    with LifecycleSafeMixin<MeshCoreRingtoneScreen> {
  String _selectedChannel = MeshCoreRingtoneChannel.adverts;
  final RtttlPlayer _player = RtttlPlayer();
  int? _previewingIndex;

  @override
  void initState() {
    super.initState();
    AppLogging.notifications('event=meshcore_ringtones.screen.opened');
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _preview(int index, RingtonePreset preset) async {
    try {
      await _player.stop();
      if (!mounted) return;
      safeSetState(() => _previewingIndex = index);
      await _player.play(preset.rtttl);
      if (!mounted) return;
      // Auto-clear once playback completes. RtttlPlayer doesn't surface
      // a "done" callback today; estimate via a fixed 6s clear which
      // covers every preset in the featured list comfortably.
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        if (_previewingIndex == index) {
          safeSetState(() => _previewingIndex = null);
        }
      });
    } catch (e) {
      AppLogging.notifications(
        'event=meshcore_ringtones.preview.failed reason=${e.runtimeType}',
      );
      if (!mounted) return;
      safeSetState(() => _previewingIndex = null);
    }
  }

  Future<void> _stopPreview() async {
    await _player.stop();
    if (!mounted) return;
    safeSetState(() => _previewingIndex = null);
  }

  Future<void> _select(RingtonePreset preset) async {
    final notifier = ref.read(meshCoreRingtonePreferencesProvider.notifier);
    await notifier.setRtttl(_selectedChannel, preset.rtttl);
    if (!mounted) return;
    showSuccessSnackBar(context, context.l10n.meshcoreRingtonesSavedToast);
  }

  Future<void> _clearChannel() async {
    final notifier = ref.read(meshCoreRingtonePreferencesProvider.notifier);
    await notifier.clear(_selectedChannel);
    if (!mounted) return;
    showSuccessSnackBar(context, context.l10n.meshcoreRingtonesClearedToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefsAsync = ref.watch(meshCoreRingtonePreferencesProvider);
    final selectedRtttl = prefsAsync.value?[_selectedChannel];

    return GlassScaffold(
      title: l10n.meshcoreRingtonesTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SectionTitle(title: l10n.meshcoreRingtonesChannelSectionTitle),
              const SizedBox(height: AppTheme.spacing8),
              ChipSelector<String>(
                value: _selectedChannel,
                options: [
                  ChipOption<String>(
                    value: MeshCoreRingtoneChannel.adverts,
                    label: l10n.meshcoreNotificationChannelAdvertsName,
                    icon: Icons.notifications_active_rounded,
                    color: AccentColors.cyan,
                  ),
                  ChipOption<String>(
                    value: MeshCoreRingtoneChannel.batchSummary,
                    label: l10n.meshcoreNotificationChannelBatchSummaryName,
                    icon: Icons.summarize_rounded,
                    color: AppTheme.primaryPurple,
                  ),
                ],
                onChanged: (next) {
                  unawaited(_stopPreview());
                  safeSetState(() => _selectedChannel = next);
                },
              ),
              const SizedBox(height: AppTheme.spacing16),
              if (selectedRtttl == null)
                StatusBanner.info(title: l10n.meshcoreRingtonesUseDefault),
              const SizedBox(height: AppTheme.spacing16),
              SectionTitle(title: l10n.meshcoreRingtonesPresetsSectionTitle),
              const SizedBox(height: AppTheme.spacing8),
              for (int i = 0; i < kFeaturedRingtonePresets.length; i++)
                _buildPresetTile(context, i, selectedRtttl),
              const SizedBox(height: AppTheme.spacing16),
              SettingsTile(
                icon: Icons.restore_rounded,
                iconColor: AppTheme.warningYellow,
                title: l10n.meshcoreRingtonesUseDefault,
                onTap: _clearChannel,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetTile(
    BuildContext context,
    int index,
    String? selectedRtttl,
  ) {
    final preset = kFeaturedRingtonePresets[index];
    final isSelected = selectedRtttl == preset.rtttl;
    final isPlaying = _previewingIndex == index;
    return SettingsTile(
      key: ValueKey('meshcore-ringtone-preset-$index'),
      icon: isSelected ? Icons.check_circle_rounded : Icons.music_note_rounded,
      iconColor: isSelected ? AccentColors.cyan : AccentColors.green,
      title: preset.name,
      subtitle: preset.description,
      trailing: IconButton(
        icon: Icon(
          isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
        ),
        tooltip: isPlaying
            ? context.l10n.meshcoreRingtonesStopTooltip
            : context.l10n.meshcoreRingtonesPreviewTooltip,
        onPressed: () {
          if (isPlaying) {
            unawaited(_stopPreview());
          } else {
            unawaited(_preview(index, preset));
          }
        },
      ),
      onTap: () => _select(preset),
    );
  }
}
