// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Admin-only playground for the mesh_morph subsystem. Lets a developer
// pick a preset, swap rotation style, toggle animation, and tune the
// painter knobs while watching the live widget render. Not surfaced to
// regular users — entry point is the Admin hub > Diagnostics section.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/mesh_morph/mesh_morph.dart';
import '../../../core/widgets/settings_primitives.dart';

class MeshMorphPreviewScreen extends StatefulWidget {
  const MeshMorphPreviewScreen({super.key});

  @override
  State<MeshMorphPreviewScreen> createState() => _MeshMorphPreviewScreenState();
}

class _MeshMorphPreviewScreenState extends State<MeshMorphPreviewScreen> {
  MeshMorphPresetId _preset = MeshMorphPresetId.icosahedronJourney;
  MorphRotationStyle _rotation = MorphRotationStyle.tumble;
  bool _animate = true;
  int _pointCount = 96;
  double _glow = 0.85;
  double _lineThickness = 0.75;
  double _nodeSize = 0.85;
  MeshShapeId _currentShape = MeshShapeId.cube;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shapeName = shapeById(_currentShape).displayName;

    return GlassScaffold(
      title: l10n.adminMeshMorphTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: AppTheme.spacing8, bottom: 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _StageCard(
                preset: _preset,
                rotation: _rotation,
                animate: _animate,
                pointCount: _pointCount,
                glow: _glow,
                lineThickness: _lineThickness,
                nodeSize: _nodeSize,
                shapeName: shapeName,
                onShapeChanged: (id) {
                  if (mounted && id != _currentShape) {
                    setState(() => _currentShape = id);
                  }
                },
              ),
              SettingsSectionHeader(title: l10n.adminMeshMorphPresetSection),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing4,
                ),
                child: ChipSelector<MeshMorphPresetId>(
                  value: _preset,
                  options: [
                    ChipOption(
                      value: MeshMorphPresetId.icosahedronJourney,
                      label: l10n.adminMeshMorphPresetIcosahedronJourney,
                      icon: Icons.auto_awesome,
                      color: AppTheme.primaryMagenta,
                    ),
                    ChipOption(
                      value: MeshMorphPresetId.vectorballTour,
                      label: l10n.adminMeshMorphPresetVectorballTour,
                      icon: Icons.tour,
                      color: AppTheme.primaryBlue,
                    ),
                    ChipOption(
                      value: MeshMorphPresetId.platonicCircuit,
                      label: l10n.adminMeshMorphPresetPlatonicCircuit,
                      icon: Icons.change_history,
                      color: AppTheme.accentOrange,
                    ),
                    ChipOption(
                      value: MeshMorphPresetId.surfaceFlow,
                      label: l10n.adminMeshMorphPresetSurfaceFlow,
                      icon: Icons.waves,
                      color: Colors.teal,
                    ),
                    ChipOption(
                      value: MeshMorphPresetId.wireframeMarch,
                      label: l10n.adminMeshMorphPresetWireframeMarch,
                      icon: Icons.grid_3x3,
                      color: Colors.deepPurple,
                    ),
                  ],
                  onChanged: (v) => setState(() => _preset = v),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              SettingsSectionHeader(title: l10n.adminMeshMorphRotationSection),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing4,
                ),
                child: ChipSelector<MorphRotationStyle>(
                  value: _rotation,
                  options: [
                    ChipOption(
                      value: MorphRotationStyle.none,
                      label: l10n.adminMeshMorphRotationNone,
                      icon: Icons.stop_circle_outlined,
                      color: Colors.grey,
                    ),
                    ChipOption(
                      value: MorphRotationStyle.spin,
                      label: l10n.adminMeshMorphRotationSpin,
                      icon: Icons.refresh,
                      color: AppTheme.primaryBlue,
                    ),
                    ChipOption(
                      value: MorphRotationStyle.tumble,
                      label: l10n.adminMeshMorphRotationTumble,
                      icon: Icons.threesixty,
                      color: AppTheme.primaryMagenta,
                    ),
                    ChipOption(
                      value: MorphRotationStyle.showcase,
                      label: l10n.adminMeshMorphRotationShowcase,
                      icon: Icons.flash_on,
                      color: AppTheme.accentOrange,
                    ),
                  ],
                  onChanged: (v) => setState(() => _rotation = v),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              SettingsSectionHeader(title: l10n.adminMeshMorphTuningSection),
              SettingsTile(
                icon: Icons.play_circle_outline,
                title: l10n.adminMeshMorphAnimate,
                subtitle: l10n.adminMeshMorphAnimateSub,
                trailing: ThemedSwitch(
                  value: _animate,
                  onChanged: (v) => setState(() => _animate = v),
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              _SliderRow(
                label: l10n.adminMeshMorphPointCountLabel(_pointCount),
                value: _pointCount.toDouble(),
                min: 12,
                max: 216,
                divisions: 17,
                onChanged: (v) => setState(() => _pointCount = v.round()),
              ),
              _SliderRow(
                label: l10n.adminMeshMorphGlowLabel(_glow.toStringAsFixed(2)),
                value: _glow,
                min: 0,
                max: 2,
                divisions: 20,
                onChanged: (v) => setState(() => _glow = v),
              ),
              _SliderRow(
                label: l10n.adminMeshMorphLineThicknessLabel(
                  _lineThickness.toStringAsFixed(2),
                ),
                value: _lineThickness,
                min: 0.25,
                max: 2,
                divisions: 14,
                onChanged: (v) => setState(() => _lineThickness = v),
              ),
              _SliderRow(
                label: l10n.adminMeshMorphNodeSizeLabel(
                  _nodeSize.toStringAsFixed(2),
                ),
                value: _nodeSize,
                min: 0.25,
                max: 2,
                divisions: 14,
                onChanged: (v) => setState(() => _nodeSize = v),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.preset,
    required this.rotation,
    required this.animate,
    required this.pointCount,
    required this.glow,
    required this.lineThickness,
    required this.nodeSize,
    required this.shapeName,
    required this.onShapeChanged,
  });

  final MeshMorphPresetId preset;
  final MorphRotationStyle rotation;
  final bool animate;
  final int pointCount;
  final double glow;
  final double lineThickness;
  final double nodeSize;
  final String shapeName;
  final ValueChanged<MeshShapeId> onShapeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing24,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Column(
        children: [
          Center(
            child: MeshMorphWidget.preset(
              preset,
              size: 320,
              pointCount: pointCount,
              animate: animate,
              glowIntensity: glow,
              lineThickness: lineThickness,
              nodeSize: nodeSize,
              rotationStyle: rotation,
              onShapeChanged: onShapeChanged,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            l10n.adminMeshMorphCurrentShape(shapeName),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.accentColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.accentColor,
              inactiveTrackColor: context.accentColor.withValues(alpha: 0.2),
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
