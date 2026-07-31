// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetDnaViewerSheet — dedicated DNA inspection surface.
//
// Presents the pet's dnaSeed as a large legible genome artefact plus
// a decoded-traits panel. Opened from the pet home screen via the
// "View DNA blueprint" affordance. The pet renderer itself no longer
// carries an inline helix — structural inspection lives here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../models/pet_base_allele.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../providers/pet_providers.dart';
import 'pet_dna_geometry.dart';
import 'pet_dna_painter.dart';
import 'pet_render_model.dart' show PetSigilGeometry;

class PetDnaViewerSheet extends ConsumerWidget {
  /// Provided by `AppBottomSheet.showScrollable`'s builder — the
  /// internal `ListView` must wire through this so the draggable
  /// sheet's drag gestures coordinate with the scroll position.
  final ScrollController? scrollController;

  const PetDnaViewerSheet({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ownPetProvider).value;
    final l10n = context.l10n;
    if (state == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Text(
          l10n.petNoOwnerDescription,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      );
    }
    return _PetDnaViewerBody(state: state, scrollController: scrollController);
  }
}

class _PetDnaViewerBody extends StatefulWidget {
  final PetState state;
  final ScrollController? scrollController;
  const _PetDnaViewerBody({required this.state, this.scrollController});

  @override
  State<_PetDnaViewerBody> createState() => _PetDnaViewerBodyState();
}

class _PetDnaViewerBodyState extends State<_PetDnaViewerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// User-driven spin (radians). Persists across frames; reset on
  /// dispose. Allows drag-to-rotate without perturbing determinism of
  /// the underlying geometry.
  double _userSpin = 0;

  @override
  void initState() {
    super.initState();
    // 10 s cycle — slower than the pet (5 s) so the DNA reads as a
    // calmer, ceremonial object.
    _controller = AnimationController(
      vsync: this,
      // Slow readable rotation — one full helix turn per 20s. Was 10s,
      // which read as "jittery" at the previous bead count.
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final geometry = PetDnaGeometry.forIdentity(
      dnaSeed: state.dnaSeed,
      stage: state.stage,
      branch: state.branch,
    );
    final palette = PetSigilGeometry.forIdentity(
      dnaSeed: state.dnaSeed,
      stage: state.stage,
      branch: state.branch,
    ).palette;

    return ListView(
      // Wire into the DraggableScrollableSheet's controller so drag
      // gestures on the sheet coordinate with scroll position.
      controller: widget.scrollController,
      // Horizontal padding matches the other content-heavy sheets
      // (device_sheet, nodedex_detail_screen) — `showScrollable`
      // doesn't wrap the builder's child, so the ListView itself owns
      // the gutter.
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.petDnaViewerTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: context.textSecondary),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing12),
        _DnaCanvas(
          geometry: geometry,
          palette: palette,
          controller: _controller,
          userSpin: _userSpin,
          onSpinDelta: (d) => setState(() => _userSpin += d),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petDnaSectionIdentity),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.petInspectRowDnaSeed,
              value: '0x${state.dnaSeed.toRadixString(16).padLeft(8, '0')}',
              icon: Icons.fingerprint,
            ),
            InfoTableRow(
              label: l10n.petInspectRowStage,
              value: _stageLabel(state.stage, l10n),
              icon: Icons.eco_outlined,
            ),
            InfoTableRow(
              label: l10n.petInspectRowBranch,
              value: _branchLabel(state.branch, l10n),
              icon: Icons.account_tree_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petDnaSectionDecoded),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.petDnaTraitSymmetry,
              value: petDnaSymmetryClassLabel(
                geometry.decoded.symmetryVertexCount,
              ),
              icon: Icons.hexagon_outlined,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitStrands,
              value: petDnaStrandConfigLabel(geometry.decoded.strandCount),
              icon: Icons.linear_scale,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitResonance,
              value: '${geometry.decoded.resonance}×',
              icon: Icons.graphic_eq,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitOrbitals,
              value: '${geometry.decoded.orbitalComplexity}',
              icon: Icons.blur_circular_outlined,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitVolatility,
              value: '${geometry.decoded.volatility}',
              icon: Icons.bolt_outlined,
              iconColor: geometry.decoded.volatility > 0
                  ? AccentColors.orange
                  : null,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitAnomaly,
              value: geometry.decoded.anomaly
                  ? l10n.petDnaAnomalyPresent
                  : l10n.petDnaAnomalyAbsent,
              icon: Icons.auto_awesome_outlined,
              iconColor: geometry.decoded.anomaly ? AccentColors.yellow : null,
            ),
            InfoTableRow(
              label: l10n.petDnaTraitSignatureRotation,
              value: '${geometry.decoded.signatureRotationDeg}°',
              icon: Icons.sync_alt,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: l10n.petDnaSectionAlleles),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.petDnaAlleleDominant,
              value:
                  '${geometry.dominantAllele.code}  '
                  '${_alleleName(geometry.dominantAllele, l10n)}',
              icon: Icons.star_outline,
              iconColor: geometry.dominantAllele.archetypeColor,
            ),
            for (final allele in PetBaseAllele.values)
              InfoTableRow(
                label: _alleleName(allele, l10n),
                value: l10n.petDnaAlleleRatioValue(
                  allele.code,
                  (geometry.alleleDistribution.ratio(allele) * 100).round(),
                ),
                icon: Icons.circle,
                iconColor: allele.archetypeColor,
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          l10n.petInspectDeviceLocalNote,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiary,
            fontStyle: FontStyle.italic,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

class _DnaCanvas extends StatelessWidget {
  final PetDnaGeometry geometry;
  final dynamic palette; // PetRenderPalette — avoid widening the import
  final AnimationController controller;
  final double userSpin;
  final ValueChanged<double> onSpinDelta;

  const _DnaCanvas({
    required this.geometry,
    required this.palette,
    required this.controller,
    required this.userSpin,
    required this.onSpinDelta,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Taller canvas so the helix dominates the sheet. The user's
      // brief: the DNA structure must be large and dominate the screen.
      height: 520,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Horizontal drag scrubs the user spin — clockwise positive.
        onHorizontalDragUpdate: (d) {
          // Map pixels to radians — 180 px per full rotation feels
          // responsive without being twitchy.
          onSpinDelta(d.delta.dx / 180 * 3.14159);
        },
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: PetDnaPainter(
                  geometry: geometry,
                  palette: palette,
                  phase: controller.value,
                  userSpin: userSpin,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
      ),
    );
  }
}

String _stageLabel(PetStage stage, dynamic l10n) {
  switch (stage) {
    case PetStage.egg:
      return l10n.petStageEgg as String;
    case PetStage.juvenile:
      return l10n.petStageJuvenile as String;
    case PetStage.adolescent:
      return l10n.petStageAdolescent as String;
    case PetStage.adult:
      return l10n.petStageAdult as String;
    case PetStage.elder:
      return l10n.petStageElder as String;
    case PetStage.dormant:
      return l10n.petStageDormant as String;
  }
}

String _alleleName(PetBaseAllele allele, AppLocalizations l10n) {
  switch (allele) {
    case PetBaseAllele.aurora:
      return l10n.petAlleleAurora;
    case PetBaseAllele.tether:
      return l10n.petAlleleTether;
    case PetBaseAllele.gale:
      return l10n.petAlleleGale;
    case PetBaseAllele.calm:
      return l10n.petAlleleCalm;
  }
}

String _branchLabel(PetBranch branch, dynamic l10n) {
  switch (branch) {
    case PetBranch.unborn:
      return l10n.petBranchUnborn as String;
    case PetBranch.luminous:
      return l10n.petBranchLuminous as String;
    case PetBranch.steady:
      return l10n.petBranchSteady as String;
    case PetBranch.volatile:
      return l10n.petBranchVolatile as String;
    case PetBranch.dimmed:
      return l10n.petBranchDimmed as String;
  }
}
