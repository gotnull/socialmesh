// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas participation settings sheet.
//
// Spec anchor: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.5.
//
// Canonical inner-settings pattern: SettingsSectionHeader +
// SettingsTile + ThemedSwitch — same primitives as
// `lib/features/settings/mqtt_config_screen.dart`. Surfaced from the
// MeshCanvas overview app bar via [showCanvasParticipationSettingsSheet].
//
// Two sections:
//   - PARTICIPATION: two toggles.
//       1. Mesh participation — flips
//          `meshCanvasParticipationProvider`. Toggling this off
//          forces presence sharing off (invariant enforced by the
//          notifier; the UI mirrors).
//       2. Share my presence — flips
//          `meshCanvasPresenceSharingEnabledProvider`. Visually
//          disabled while participation is off, with a small tooltip
//          line explaining why.
//   - ABOUT: two action rows.
//       1. What is MeshCanvas? — opens the canonical help sheet.
//       2. Replay onboarding — re-opens the first-run onboarding
//          sheet regardless of the persisted `onboardingSeen` value.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_participation_providers.dart';
import 'canvas_help_sheet.dart';
import 'canvas_participation_onboarding_sheet.dart';

/// Open the MeshCanvas participation settings sheet.
Future<void> showCanvasParticipationSettingsSheet({
  required BuildContext context,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.92,
    title: context.l10n.meshCanvasParticipationSettingsTitle,
    builder: (controller) =>
        _CanvasParticipationSettingsSheet(scrollController: controller),
  );
}

class _CanvasParticipationSettingsSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _CanvasParticipationSettingsSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accent = context.accentColor;
    // Cheap boolean selectors — they return false during AsyncLoading
    // which matches the conservative default we want for the sheet.
    final participation = ref.watch(meshCanvasParticipationEnabledProvider);
    final sharing = ref.watch(meshCanvasPresenceSharingEnabledProvider);
    final notifier = ref.read(meshCanvasParticipationProvider.notifier);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      children: [
        SettingsSectionHeader(
          title: l.meshCanvasParticipationSectionParticipation,
        ),
        SettingsTile(
          icon: Icons.share_outlined,
          iconColor: participation ? accent : null,
          title: l.meshCanvasParticipationToggleParticipationTitle,
          subtitle: l.meshCanvasParticipationToggleParticipationBody,
          trailing: ThemedSwitch(
            key: const ValueKey('mesh-canvas-settings-participation-switch'),
            value: participation,
            onChanged: (next) {
              ref.haptics.itemSelect();
              notifier.setParticipationEnabled(next);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.visibility_outlined,
          iconColor: sharing ? accent : null,
          title: l.meshCanvasParticipationTogglePresenceTitle,
          subtitle: participation
              ? l.meshCanvasParticipationTogglePresenceBody
              : l.meshCanvasParticipationTogglePresenceDisabledTooltip,
          trailing: ThemedSwitch(
            key: const ValueKey('mesh-canvas-settings-presence-switch'),
            value: sharing,
            // Disabled (null onChanged) when participation is off.
            // Notifier defence-in-depth rejects the combo too.
            onChanged: participation
                ? (next) {
                    ref.haptics.itemSelect();
                    notifier.setPresenceSharingEnabled(next);
                  }
                : null,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(title: l.meshCanvasParticipationSectionAbout),
        SettingsTile(
          key: const ValueKey('mesh-canvas-settings-help'),
          icon: Icons.help_outline_rounded,
          title: l.meshCanvasParticipationAboutHelp,
          onTap: () {
            ref.haptics.buttonTap();
            showCanvasHelpSheet(context: context);
          },
        ),
        SettingsTile(
          key: const ValueKey('mesh-canvas-settings-replay-onboarding'),
          icon: Icons.refresh_outlined,
          title: l.meshCanvasParticipationAboutReplayOnboarding,
          onTap: () {
            ref.haptics.buttonTap();
            showCanvasParticipationOnboardingSheet(context: context);
          },
        ),
      ],
    );
  }
}
