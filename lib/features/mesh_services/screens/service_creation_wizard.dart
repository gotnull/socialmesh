// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/guided_flow_scaffold.dart';
import '../../../core/widgets/step_choice_card.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_template.dart';
import 'mesh_service_creation_screen.dart';

class ServiceCreationWizard extends ConsumerStatefulWidget {
  const ServiceCreationWizard({super.key});

  @override
  ConsumerState<ServiceCreationWizard> createState() =>
      _ServiceCreationWizardState();
}

class _ServiceCreationWizardState extends ConsumerState<ServiceCreationWizard>
    with LifecycleSafeMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  MeshServiceType? _selectedType;
  MeshServicePresetId? _selectedPreset;

  static const int _totalSteps = 3;

  List<GuidedFlowStep> _buildSteps(AppLocalizations l10n) => [
    GuidedFlowStep(
      title: l10n.serviceWizardStepWhat,
      icon: Icons.edit_note_outlined,
      color: AccentColors.cyan,
    ),
    GuidedFlowStep(
      title: l10n.serviceWizardStepPreset,
      icon: Icons.style_outlined,
      color: AccentColors.orange,
    ),
    GuidedFlowStep(
      title: l10n.serviceWizardStepReview,
      icon: Icons.visibility_outlined,
      color: AppTheme.successGreen,
    ),
  ];

  void _nextStep() {
    ref.haptics.trigger(HapticType.light);
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    ref.haptics.trigger(HapticType.light);
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canAdvance {
    return switch (_currentStep) {
      0 => _selectedType != null,
      _ => true,
    };
  }

  void _selectType(MeshServiceType type) {
    ref.haptics.trigger(HapticType.light);
    setState(() {
      _selectedType = type;
      _selectedPreset = null;
    });
  }

  void _selectPreset(MeshServicePresetId? presetId) {
    ref.haptics.trigger(HapticType.light);
    setState(() => _selectedPreset = presetId);
  }

  void _confirm() {
    final selectedType = _selectedType;
    if (selectedType == null) return;

    ref.haptics.trigger(HapticType.medium);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MeshServiceCreationScreen(
          canonicalType: selectedType,
          presetId: _selectedPreset,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GuidedFlowScaffold(
      title: l10n.serviceWizardTitle,
      steps: _buildSteps(l10n),
      currentStep: _currentStep,
      pageController: _pageController,
      pageBuilder: (context, index) {
        return switch (index) {
          0 => _buildTypeStep(context, l10n),
          1 => _buildPresetStep(context, l10n),
          2 => _buildReviewStep(context, l10n),
          _ => const SizedBox.shrink(),
        };
      },
      bottomBar: BottomActionBar(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text(l10n.guidedFlowBack),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: FilledButton(
                onPressed: _canAdvance
                    ? (_currentStep == _totalSteps - 1 ? _confirm : _nextStep)
                    : null,
                child: Text(
                  _currentStep == _totalSteps - 1
                      ? l10n.guidedFlowContinue
                      : l10n.guidedFlowNext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeStep(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        _StepLead(
          icon: Icons.wifi_tethering_rounded,
          color: AccentColors.cyan,
          title: l10n.serviceWizardWhatTitle,
          subtitle: l10n.serviceWizardWhatSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing16),
        for (final typeDefinition in MeshServiceCatalog.allTypes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: StepChoiceCard(
              icon: typeDefinition.icon,
              title: meshServiceIntentName(l10n, typeDefinition.type),
              description: meshServiceIntentDescription(
                l10n,
                typeDefinition.type,
              ),
              accentColor: typeDefinition.accentColor,
              isSelected: _selectedType == typeDefinition.type,
              onTap: () => _selectType(typeDefinition.type),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetStep(BuildContext context, AppLocalizations l10n) {
    final selectedType = _selectedType;
    if (selectedType == null) {
      return const SizedBox.shrink();
    }

    final presets = MeshServiceCatalog.presetsForType(selectedType);
    final base = MeshServiceCatalog.resolve(canonicalType: selectedType);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        _StepLead(
          icon: base.icon,
          color: base.accentColor,
          title: l10n.serviceWizardPresetTitle,
          subtitle: l10n.serviceWizardPresetSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing16),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: base.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(base.icon, color: base.accentColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meshServiceIntentName(l10n, selectedType),
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      meshServiceIntentDescription(l10n, selectedType),
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        StepChoiceCard(
          icon: base.icon,
          title: l10n.serviceWizardPresetGeneric,
          description: l10n.serviceWizardPresetGenericDescription,
          accentColor: base.accentColor,
          isSelected: _selectedPreset == null,
          onTap: () => _selectPreset(null),
        ),
        for (final preset in presets) ...[
          const SizedBox(height: AppTheme.spacing8),
          StepChoiceCard(
            icon: preset.icon,
            title: meshServicePresetName(l10n, preset.id),
            description: meshServicePresetDescription(l10n, preset.id),
            accentColor: preset.accentColor,
            isSelected: _selectedPreset == preset.id,
            onTap: () => _selectPreset(preset.id),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context, AppLocalizations l10n) {
    final selectedType = _selectedType;
    final resolved = selectedType == null
        ? null
        : MeshServiceCatalog.resolve(
            canonicalType: selectedType,
            presetId: _selectedPreset,
          );
    final previewTitle = selectedType == null
        ? l10n.meshServicesPreviewPlaceholder
        : meshServiceDisplayName(
            l10n,
            canonicalType: selectedType,
            presetId: _selectedPreset,
          );
    final previewDescription = selectedType == null
        ? l10n.meshServicesPreviewCardDescription
        : meshServiceDisplayDescription(
            l10n,
            canonicalType: selectedType,
            presetId: _selectedPreset,
          );

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        _StepLead(
          icon: Icons.remove_red_eye_outlined,
          color: resolved?.accentColor ?? AppTheme.successGreen,
          title: l10n.serviceWizardReviewTitle,
          subtitle: l10n.serviceWizardReviewSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing16),
        _WizardPreviewCard(
          title: previewTitle,
          description: previewDescription,
          icon: resolved?.icon ?? Icons.ios_share_outlined,
          accentColor: resolved?.accentColor ?? AppTheme.successGreen,
          visibilityLabel: l10n.meshServicesVisibilityOpen,
        ),
        const SizedBox(height: AppTheme.spacing16),
        SummaryCard(
          title: l10n.meshServicesPreviewCardTitle,
          titleIcon: Icons.route_outlined,
          accentColor: AppTheme.successGreen,
          rows: [
            SummaryRow(
              label: l10n.serviceWizardReviewType,
              value: selectedType == null
                  ? '—' // lint-allow: hardcoded-string
                  : meshServiceIntentName(l10n, selectedType),
              icon: resolved?.icon,
              iconColor: resolved?.accentColor,
            ),
            SummaryRow(
              label: l10n.serviceWizardReviewPreset,
              value: _selectedPreset == null
                  ? l10n.serviceWizardPresetGeneric
                  : meshServicePresetName(l10n, _selectedPreset!),
              icon: _selectedPreset == null
                  ? Icons.auto_fix_high
                  : resolved?.icon,
              iconColor: resolved?.accentColor,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: AppTheme.warningYellow,
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Text(
                  l10n.serviceWizardReviewMeshHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepLead extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _StepLead({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.headingStyle),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  subtitle,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardPreviewCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String visibilityLabel;

  const _WizardPreviewCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.visibilityLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  title,
                  style: context.bodyStyle?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: SemanticColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  visibilityLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SemanticColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            description,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
