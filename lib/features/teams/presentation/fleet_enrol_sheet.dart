// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Enrol a radio into a Team's Fleet.
//
// The framing this sheet has to get right: these are radios SocialMesh
// can SEE through the active protocol, not radios the organisation
// owns. Enrolment is the act that creates the organisational
// relationship, and it records metadata only - it never writes to the
// radio.
//
// Non-available candidates stay VISIBLE but disabled. Hiding them would
// leave an admin hunting for a radio that is already enrolled, or
// retired, with no explanation of where it went.
//
// On success the sheet closes and lets the invalidated fleet authority
// refresh the list. Nothing is injected locally, so the server stays the
// source of truth even for the row the admin just created.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../services/license_org/license_org_fleet_service.dart';
import '../../../utils/snackbar.dart';
import '../application/fleet_candidate_source.dart';
import '../application/fleet_enrol_candidates.dart';
import '../application/fleet_failure_message.dart';
import '../application/fleet_providers.dart';

/// Opens the enrol picker. Content-heavy, so `showScrollable`.
Future<void> showFleetEnrolSheet(
  BuildContext context, {
  required String licenseOrgId,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) => _FleetEnrolSheet(
      licenseOrgId: licenseOrgId,
      scrollController: controller,
    ),
  );
}

class _FleetEnrolSheet extends ConsumerStatefulWidget {
  final String licenseOrgId;
  final ScrollController scrollController;

  const _FleetEnrolSheet({
    required this.licenseOrgId,
    required this.scrollController,
  });

  @override
  ConsumerState<_FleetEnrolSheet> createState() => _FleetEnrolSheetState();
}

class _FleetEnrolSheetState extends ConsumerState<_FleetEnrolSheet>
    with LifecycleSafeMixin<_FleetEnrolSheet> {
  bool _submitting = false;

  /// Last refusal, shown INSIDE the sheet.
  ///
  /// A snackbar is the wrong surface here: this sheet covers almost the
  /// whole screen, so a root ScaffoldMessenger renders its bar behind
  /// the modal route and the admin sees nothing at all. The failure has
  /// to live next to the action that produced it.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = ref.watch(fleetCandidateSourceProvider(widget.licenseOrgId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.fleetEnrolHeader, style: context.titleStyle),
              const SizedBox(height: AppTheme.spacing6),
              // Visibility is not ownership. This line is the whole
              // reason the header is worded the way it is.
              Text(
                l10n.fleetEnrolHeaderBody,
                style: context.bodySecondaryStyle,
              ),
            ],
          ),
        ),
        Divider(color: context.border, height: 1),
        // Content dissolves under the pinned header instead of being
        // hard-cut mid-card. EdgeFade exists for exactly this - its doc
        // calls it "blending content near static UI elements".
        Expanded(
          child: EdgeFade(
            edges: const {EdgeFadePosition.top},
            fadeSize: AppTheme.spacing16,
            child: _body(context, source),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, FleetCandidateSource source) {
    final l10n = context.l10n;

    switch (source) {
      case FleetCandidateSourceNoProtocol():
        return _notice(context, l10n.fleetEnrolNoProtocol);
      case FleetCandidateSourceLoading():
        return const Center(child: LoadingIndicator());
      case FleetCandidateSourceUnavailable():
        return _notice(context, l10n.fleetEnrolSourceUnavailable);
      case FleetCandidateSourceReady(candidates: final candidates):
        if (candidates.isEmpty) {
          return _notice(context, l10n.fleetEnrolNoCandidates);
        }
        return ListView(
          // Wired into the sheet's controller, or drag-to-dismiss
          // breaks.
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing32,
          ),
          children: [
            // Scrolls WITH the list rather than pinned above it. Pinned,
            // it left rounded cards sliding underneath and slicing in
            // half against its edge. The list is scrolled back to the
            // top when this appears, so it is still seen.
            if (_error != null) ...[
              StatusBanner(type: StatusBannerType.error, title: _error!),
              const SizedBox(height: AppTheme.spacing12),
            ],
            StatusBanner(
              type: StatusBannerType.info,
              title: l10n.fleetEnrolBoundaryNote,
            ),
            const SizedBox(height: AppTheme.spacing12),
            for (final candidate in candidates)
              _CandidateTile(
                candidate: candidate,
                enabled: candidate.isEnrollable && !_submitting,
                onTap: () => _enrol(candidate),
              ),
          ],
        );
    }
  }

  static Widget _notice(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Text(
          message,
          style: context.bodySecondaryStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _enrol(FleetEnrolCandidate candidate) async {
    final rawIdentity = candidate.rawIdentity;
    if (rawIdentity == null || _submitting) return;

    final l10n = context.l10n;
    setState(() {
      _submitting = true;
      // Cleared on each attempt so a stale refusal never sits above a
      // request that is currently in flight.
      _error = null;
    });

    final result = await ref
        .read(fleetMutationControllerProvider(widget.licenseOrgId).notifier)
        .enroll(
          transport: candidate.transport,
          rawIdentity: rawIdentity,
          label: candidate.displayName.isEmpty ? null : candidate.displayName,
          lastKnownHardware: candidate.observedHardware,
          lastKnownFirmware: candidate.observedFirmware,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case FleetMutationSuccess(created: final created):
        // Close and let the invalidated authority refresh the list. The
        // candidate snapshot may be stale by now - another admin could
        // have enrolled the same radio - so the server's answer, not a
        // locally injected row, is what the admin ends up looking at.
        safeNavigatorPop();
        showSuccessSnackBar(
          context,
          created ? l10n.fleetAddedSnack : l10n.fleetAlreadyAddedSnack,
        );
      case FleetMutationFailure(reason: final reason):
        // The candidate list is rebuilt from the authority on every
        // frame, so a state that changed while the sheet was open
        // (another admin retiring the radio, say) corrects itself
        // without the sheet holding its own copy.
        setState(() => _error = fleetFailureMessage(l10n, reason));
        // The banner sits at the top of the list, so bring it into view
        // rather than leaving the admin looking at an unchanged screen
        // further down.
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
    }
  }
}

class _CandidateTile extends StatelessWidget {
  final FleetEnrolCandidate candidate;
  final bool enabled;
  final VoidCallback onTap;

  const _CandidateTile({
    required this.candidate,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stateLabel = switch (candidate.state) {
      FleetCandidateState.available => l10n.fleetCandidateAvailable,
      FleetCandidateState.alreadyInFleet => l10n.fleetCandidateAlreadyInFleet,
      FleetCandidateState.retiredInFleet => l10n.fleetCandidateRetired,
      FleetCandidateState.unsupported => l10n.fleetCandidateIdentityUnavailable,
    };

    return Opacity(
      // Non-available candidates stay legible rather than hidden: an
      // admin looking for a radio needs to see WHY it is not offered.
      opacity: enabled ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Material(
          color: Colors.transparent, // lint-allow: no-hardcoded-color
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing12,
              ),
              // Centred: the three lines are a fixed metadata block, not
              // wrapping copy, and the action applies to the whole row.
              // SettingsTile reserves CrossAxisAlignment.start for a
              // subtitle that can actually wrap.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                candidate.displayName.isEmpty
                                    ? (candidate.transportIdentity ?? '')
                                    : candidate.displayName,
                                style: context.bodyStyle,
                              ),
                            ),
                            if (candidate.isLocalDevice) ...[
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                l10n.fleetCandidateLocalDevice,
                                style: context.captionMutedStyle,
                              ),
                            ],
                          ],
                        ),
                        if (candidate.transportIdentity != null) ...[
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            candidate.transportIdentity!,
                            style: context.captionMutedStyle,
                          ),
                        ],
                        const SizedBox(height: AppTheme.spacing6),
                        Text(stateLabel, style: context.bodySmallStyle),
                        if (candidate.state ==
                            FleetCandidateState.unsupported) ...[
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            l10n.fleetCandidateIdentityUnavailableHelp,
                            style: context.captionMutedStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: AppTheme.spacing12),
                    Icon(
                      Icons.add_circle_outline,
                      size: AppTheme.spacing24,
                      color: context.accentColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
