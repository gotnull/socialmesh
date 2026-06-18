// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Help Circle invite consent screen.
///
/// Single confirmation target for both the in-app QR scanner and external /
/// system-camera deep links (`socialmesh://help-circle/{base64}`). Adding the
/// inviter to the local Help Circle is ALWAYS an explicit user tap here - there
/// is no silent auto-add. Gated on the Incident Mode flags; if Help Mode is off
/// the screen explains that and offers no add.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../utils/snackbar.dart';
import '../../../utils/text_sanitizer.dart';
import '../providers/incident_help_trust_provider.dart';

class HelpCircleInviteScreen extends ConsumerStatefulWidget {
  /// Inviter's node number (Meshtastic nodeNum).
  final int nodeNum;

  /// Inviter's long/display name from the invite payload (may be null).
  final String? longName;

  /// Inviter's short name from the invite payload (fallback label).
  final String? shortName;

  const HelpCircleInviteScreen({
    super.key,
    required this.nodeNum,
    this.longName,
    this.shortName,
  });

  @override
  ConsumerState<HelpCircleInviteScreen> createState() =>
      _HelpCircleInviteScreenState();
}

class _HelpCircleInviteScreenState extends ConsumerState<HelpCircleInviteScreen>
    with LifecycleSafeMixin<HelpCircleInviteScreen> {
  bool _adding = false;

  String get _displayName {
    final long = sanitizeExternalText(widget.longName ?? '');
    if (long.isNotEmpty) return long;
    final short = sanitizeExternalText(widget.shortName ?? '');
    if (short.isNotEmpty) return short;
    return '!${widget.nodeNum.toRadixString(16)}';
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    await ref
        .read(incidentHelpTrustProvider.notifier)
        .trust(
          widget.nodeNum,
          displayName: _displayName,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
    if (!mounted) return;
    showSuccessSnackBar(
      context,
      context.l10n.helpModeCircleAddedSnack(_displayName),
    );
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled =
        AppFeatureFlags.isMeshIncidentsEnabled &&
        AppFeatureFlags.isIncidentHelpRequestEnabled;

    if (!enabled) {
      return GlassScaffold(
        title: l10n.helpModeCircleInviteTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverToBoxAdapter(
              child: StatusBanner.warning(
                title: l10n.helpModeCircleInviteTitle,
                subtitle: l10n.helpModeCircleInviteDisabled,
                icon: Icons.health_and_safety_outlined,
              ),
            ),
          ),
        ],
      );
    }

    final alreadyTrusted = ref
        .watch(incidentHelpTrustedIdsProvider)
        .contains(widget.nodeNum);

    return GlassScaffold(
      title: l10n.helpModeCircleInviteTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList.list(
            children: [
              StatusBanner.info(
                title: l10n.helpModeCircleInvitePrompt(_displayName),
                subtitle: l10n.helpModeCircleAddConfirmBody,
                icon: Icons.health_and_safety_outlined,
              ),
              const SizedBox(height: AppTheme.spacing16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Row(
                    children: [
                      NodeAvatar(
                        text: _displayName,
                        color: alreadyTrusted
                            ? AppTheme.successGreen
                            : context.accentColor,
                        size: 44,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_displayName, style: context.titleSmallStyle),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              alreadyTrusted
                                  ? l10n.helpModeCircleTrusted
                                  : '!${widget.nodeNum.toRadixString(16)}',
                              style: context.captionMutedStyle,
                            ),
                          ],
                        ),
                      ),
                      if (alreadyTrusted)
                        Icon(Icons.check_circle, color: AppTheme.successGreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottomNavigationBar: BottomActionBar(
        child: alreadyTrusted
            ? PrimaryGradientButton(
                label: l10n.commonDone,
                icon: Icons.check,
                onPressed: safeNavigatorPop,
              )
            : PrimaryGradientButton(
                label: l10n.helpModeCircleAdd,
                icon: Icons.health_and_safety,
                isLoading: _adding,
                onPressed: _add,
              ),
      ),
    );
  }
}
